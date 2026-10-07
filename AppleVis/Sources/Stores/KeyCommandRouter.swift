import Foundation
import Combine
import UIKit

/// Backs hardware-keyboard shortcuts (external keyboard on iPad/iPhone),
/// registered as SwiftUI `.commands` in `AppleVisApp`. `.commands` closures
/// only see environment objects, not another view's local `@State`, so tab
/// selection and one-shot actions route through this shared object instead
/// of being wired directly — same role `DeepLinkRouter` plays for Spotlight
/// and universal links.
@MainActor
final class KeyCommandRouter: ObservableObject {
    /// Reached by screens that may sit in a sheet, where an environment
    /// object can't be relied on. Same pattern as `AuthStore.current`.
    static weak var current: KeyCommandRouter?

    @Published var selectedTab = 0
    @Published var showSettings = false
    /// Command-M and Command-Shift-C (Adaptive Experience, 2026-10-06).
    @Published var showAskTheMouse = false
    @Published var showContact = false
    let refreshRequested = PassthroughSubject<Void, Never>()

    init() { Self.current = self }

    // MARK: - Shortcuts that depend on what's on screen

    /// Command-F, Command-N and Command-Shift-S only make sense where there
    /// is a search field, a place to start a topic, or something to save.
    /// Screens register while they're on screen (see
    /// KeyboardCommandTargets.swift), so the shortcut is offered, and
    /// reaches, only the screen that can act on it.
    enum Target: Hashable {
        case search, newTopic, save
    }

    @Published private(set) var targets: [Target: Set<UUID>] = [:]
    let requests = PassthroughSubject<Target, Never>()

    func register(_ target: Target, _ token: UUID) { targets[target, default: []].insert(token) }
    func unregister(_ target: Target, _ token: UUID) { targets[target]?.remove(token) }
    func isAvailable(_ target: Target) -> Bool { !(targets[target]?.isEmpty ?? true) }

    /// Command-F: the search field on screen, or Discover's search when the
    /// screen has none (Home, For You).
    func search() {
        if isAvailable(.search) {
            requests.send(.search)
        } else {
            selectedTab = 1
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                requests.send(.search)
            }
        }
    }

    // MARK: - Opening a screen from anywhere

    /// Something already open over the app (a post being written, a form,
    /// another sheet). A second sheet can't open on top of it, and closing
    /// it could lose someone's work, so the shortcut says so instead.
    static var isShowingSheet: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .presentedViewController != nil
    }

    private func presentIfFree(_ open: () -> Void) {
        guard !Self.isShowingSheet else {
            UIAccessibility.post(notification: .announcement,
                                 argument: String(localized: "Finish or close what's open first, then try again."))
            return
        }
        open()
    }

    func openAskTheMouse() { presentIfFree { showAskTheMouse = true } }
    func openContact() { presentIfFree { showContact = true } }
    func openSettings() { presentIfFree { showSettings = true } }
}
