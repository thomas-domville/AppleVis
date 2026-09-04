import Foundation
import Translation
import os

/// On-device reading-side translation — blog/forum/app/podcast/guide/bug
/// content, comments, and Help articles translated into the reader's chosen
/// language via Apple's `Translation` framework (iOS 17.4+, no Apple
/// Intelligence hardware requirement). This is the opposite direction from
/// `IntelligenceService.translateToEnglish` (which helps someone *writing* a
/// non-English draft translate it to English before posting, on the
/// separate, hardware-gated FoundationModels stack) — the two are
/// independent features that happen to both be called "translation."
///
/// Apple's `Translation` framework has no free-standing session initializer
/// — a working `TranslationSession` is only ever handed to a SwiftUI view's
/// `.translationTask(_:action:)` closure, so (unlike `IntelligenceService`,
/// a stateless enum) this has to be a singleton that a hidden view at the
/// app root keeps alive and feeds requests through. Everything here runs
/// entirely on-device; nothing is sent to a server.
///
/// Not build-verified in this environment (no Xcode/macOS available where
/// this was written) — the `.translationTask` binding and continuation
/// bridging below follow Apple's documented WWDC23 usage pattern, but need
/// a real-device pass before being trusted, same as any new binary/protocol
/// code in this codebase.
@MainActor
final class TranslationCoordinator: ObservableObject {
    static let shared = TranslationCoordinator()

    enum Availability {
        case installed
        case downloadable
        case unsupported
    }

    /// Bound to the hidden `.translationTask` modifier mounted once at the
    /// app root (see `AppleVisApp.swift`). Changing this tears down the old
    /// session and asks SwiftUI to mint a new one for the new language pair.
    @Published private(set) var configuration: TranslationSession.Configuration?

    private var currentSession: TranslationSession?
    private var currentTargetLanguageCode: String?
    private var sessionWaiters: [CheckedContinuation<TranslationSession, Never>] = []

    /// A second, independent session for the one reverse-direction need in
    /// the app: translating a search query (any language, auto-detected)
    /// INTO English so it can match AppleVis's English-indexed content.
    /// Every other method above always translates FROM English, so this
    /// can't share `configuration`/`session(for:)`'s single-active-pair
    /// bookkeeping — it needs its own `.translationTask` mount point (see
    /// `AppleVisApp.swift`) bound to `reverseConfiguration` instead.
    @Published private(set) var reverseConfiguration: TranslationSession.Configuration?
    private var reverseSession: TranslationSession?
    private var reverseSessionWaiters: [CheckedContinuation<TranslationSession, Never>] = []

    private init() {}

    /// Called by the app root's `.translationTask` closure whenever a new
    /// session is minted. Resolves anyone currently waiting on a session for
    /// this same target language; a request for a *different* target that
    /// raced in just before `configuration` changed again is left to fail
    /// gracefully and retry (see `session(for:)`) — callers are always
    /// driven by `.task(id:)` keyed on the content-language preference, so a
    /// language switch mid-flight naturally re-issues the request anyway.
    func bind(session: TranslationSession) {
        currentSession = session
        currentTargetLanguageCode = configuration?.target?.languageCode.identifier
        let waiters = sessionWaiters
        sessionWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(returning: session)
        }
    }

    /// Called when the app root's `.translationTask` closure is torn down
    /// (configuration changed again, or the view disappeared) so stale
    /// requests don't wait forever on a session that's never coming.
    func unbind() {
        currentSession = nil
        currentTargetLanguageCode = nil
    }

    /// Counterpart to `bind(session:)`/`unbind()` for the reverse (→English)
    /// session — see `reverseConfiguration`.
    func bindReverse(session: TranslationSession) {
        reverseSession = session
        let waiters = reverseSessionWaiters
        reverseSessionWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(returning: session)
        }
    }

    func unbindReverse() {
        reverseSession = nil
    }

    /// Search-query translation only — auto-detects the query's language
    /// and translates it to English so it can match AppleVis's
    /// English-indexed content. `DiscoverView` tries the existing
    /// FoundationModels-based `IntelligenceService.translateSearchQuery`
    /// first where that's available (newer hardware, LLM-quality result)
    /// and falls back to this for every other device.
    func translateToEnglish(_ text: String) async -> String? {
        guard #available(iOS 17.4, *) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if reverseConfiguration == nil {
            reverseConfiguration = TranslationSession.Configuration(target: Locale.Language(identifier: "en"))
        }
        let session: TranslationSession? = reverseSession ?? (await withCheckedContinuation { (continuation: CheckedContinuation<TranslationSession, Never>) in
            reverseSessionWaiters.append(continuation)
        })
        guard let session else { return nil }
        do {
            return try await session.translate(trimmed).targetText
        } catch {
            AppLog.translation.error("Search query translate failed: \(error, privacy: .private)")
            return nil
        }
    }

    static func availability(for targetLanguageCode: String) async -> Availability {
        guard #available(iOS 17.4, *) else { return .unsupported }
        let status = await LanguageAvailability().status(
            from: Locale.Language(identifier: "en"),
            to: Locale.Language(identifier: targetLanguageCode)
        )
        switch status {
        case .installed: return .installed
        case .supported: return .downloadable
        case .unsupported: return .unsupported
        @unknown default: return .unsupported
        }
    }

    /// Triggers the on-device language-pack download/prepare flow (Apple's
    /// own system UI handles progress) — called once, right when a user
    /// opts in via the launch prompt or Settings, independent of any
    /// specific piece of content.
    @discardableResult
    func prepareLanguagePack(for targetLanguageCode: String) async -> Bool {
        guard #available(iOS 17.4, *), let session = await session(for: targetLanguageCode) else { return false }
        do {
            try await session.prepareTranslation()
            return true
        } catch {
            AppLog.translation.error("Language pack prepare failed: \(error, privacy: .private)")
            return false
        }
    }

    func translate(_ text: String, to targetLanguageCode: String) async -> String? {
        guard #available(iOS 17.4, *) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let session = await session(for: targetLanguageCode) else { return nil }
        do {
            return try await session.translate(trimmed).targetText
        } catch {
            AppLog.translation.error("Translate failed: \(error, privacy: .private)")
            return nil
        }
    }

    /// Batches N strings into one round-trip (a multi-paragraph body, or a
    /// screen's worth of comments) instead of N sequential awaits. Returns
    /// results in the same order/count as `texts`, with `nil` in place of
    /// any request that failed to come back (matched by `clientIdentifier`,
    /// not array position, since the framework doesn't document response
    /// ordering as guaranteed to match request ordering).
    func translateBatch(_ texts: [String], to targetLanguageCode: String) async -> [String?] {
        guard #available(iOS 17.4, *) else { return Array(repeating: nil, count: texts.count) }
        guard let session = await session(for: targetLanguageCode) else { return Array(repeating: nil, count: texts.count) }
        let requests = texts.enumerated().map { index, text in
            TranslationSession.Request(sourceText: text, clientIdentifier: String(index))
        }
        do {
            let responses = try await session.translations(from: requests)
            var results = [String?](repeating: nil, count: texts.count)
            for response in responses {
                guard let id = response.clientIdentifier, let index = Int(id), texts.indices.contains(index) else { continue }
                results[index] = response.targetText
            }
            return results
        } catch {
            AppLog.translation.error("Batch translate failed: \(error, privacy: .private)")
            return Array(repeating: nil, count: texts.count)
        }
    }

    /// Reuses the currently-bound session if it's already targeting the
    /// requested language; otherwise updates `configuration` (which tears
    /// down any existing session and asks SwiftUI to mint a new one via the
    /// app root's `.translationTask`) and suspends until `bind(session:)`
    /// delivers it. Only one language pair is ever active at a time — this
    /// matches the product design (a single `effectiveContentLanguage`
    /// preference), so there's no need to juggle multiple concurrent
    /// sessions for different target languages.
    @available(iOS 17.4, *)
    private func session(for targetLanguageCode: String) async -> TranslationSession? {
        if let currentSession, currentTargetLanguageCode == targetLanguageCode {
            return currentSession
        }
        if configuration?.target?.languageCode.identifier != targetLanguageCode {
            configuration = TranslationSession.Configuration(
                source: Locale.Language(identifier: "en"),
                target: Locale.Language(identifier: targetLanguageCode)
            )
        }
        let session = await withCheckedContinuation { (continuation: CheckedContinuation<TranslationSession, Never>) in
            sessionWaiters.append(continuation)
        }
        return currentTargetLanguageCode == targetLanguageCode ? session : nil
    }
}
