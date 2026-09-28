import Foundation
import Combine
import SwiftUI
import UIKit
import Security
import os

@MainActor
final class AuthStore: ObservableObject {
    static weak var current: AuthStore?

    @Published private(set) var user: AuthUser?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published var isOnboarded: Bool
    /// One-shot signal so ContentView can offer the welcome-tour auto-prompt
    /// right after setup finishes — RN did this from onboarding's own "Next"
    /// handler, but Swift's transition to ContentView is state-driven, not
    /// an imperative navigation call, so the signal has to live here instead.
    @Published var justCompletedOnboarding = false

    /// Remember me: the Keychain item holding the member's username and
    /// password, kept only when they turn Remember me on. Separate from the
    /// session item, device-only, never synced.
    private let credentialsKey = "applevis.rememberedSignIn"
    private struct RememberedSignIn: Codable { let username: String; let password: String }

    /// Whether this iPhone signs the member back in by itself.
    var remembersSignIn: Bool { loadRememberedSignIn() != nil }

    private var reSignInContinuation: CheckedContinuation<Bool, Never>?
    private var reSignInShownAt: Date?
    private var isCheckingSession = false

    struct ReSignInPrompt: Identifiable {
        enum Reason { case whileSending, onOpen }
        let id = UUID()
        let reason: Reason
    }

    var isSignedIn: Bool { user != nil }

    private let keychainKey = "applevis.authUser"
    private let onboardedKey = "applevis.onboarded"
    private let hasLaunchedKey = "applevis.hasLaunchedThisInstall"

    init() {
        isOnboarded = UserDefaults.standard.bool(forKey: "applevis.onboarded")
        // The Keychain survives deleting the app — by design, so apps that
        // want that (like a banking app restoring a session after a
        // reinstall) can have it — but UserDefaults doesn't. A user who
        // deletes and reinstalls AppleVis to get a clean slate (onboarding
        // included) still found themselves silently signed back in, because
        // the Keychain entry from the previous install was never touched.
        // A missing hasLaunchedKey sentinel here means either a genuinely
        // first-ever install, or exactly that reinstall case — either way,
        // any Keychain entry found alongside it is leftover from before and
        // gets cleared rather than silently restored. Reported directly.
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            deleteFromKeychain()
            deleteRememberedSignIn()
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
        }
        user = Self.loadFromKeychain()
        AuthStore.current = self
    }

    func signIn(username: String, password: String, rememberMe: Bool = false) async {
        isLoading = true
        error = nil
        do {
            var authUser = try await APIClient.shared.account.signIn(username: username, password: password, rememberMe: rememberMe)
            authUser.signedInAt = Date()
            user = authUser
            saveToKeychain(authUser)
            // Remember me (2026-09-28, requested directly). If the website
            // itself agreed to remember this sign-in, there's no need to
            // keep the password; otherwise the app keeps it, so it can sign
            // back in when the website's ~23-day session ends.
            if rememberMe && !Self.websiteRemembersSignIn() {
                saveRememberedSignIn(RememberedSignIn(username: authUser.name, password: password))
            } else {
                deleteRememberedSignIn()
            }
            // Previously silent — every other confirmation moment (save,
            // follow, submit) plays .success, but signing in itself never
            // did. Reported directly.
            SoundPlayer.shared.play(.success)
            Task { await PushNotificationManager.syncRegistration() }
        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = String(localized: "Couldn't sign in. Try again.")
        }
        isLoading = false
    }

    func signOut() async {
        guard let u = user else { return }
        deleteRememberedSignIn()
        await PushNotificationManager.clearRegistration()
        try? await APIClient.shared.account.logout(csrfToken: u.csrfToken, logoutToken: u.logoutToken)
        SpotlightIndexer.deindexAll()
        user = nil
        deleteFromKeychain()
        clearSessionCookies()
        // ARCH-04/PERS-05: previously only cleared the session itself —
        // saved items, followed topics, read/visited state, and
        // notification history all survived sign-out fully intact, so the
        // next person to sign in on a shared device inherited the prior
        // user's data. Same scoped clear Settings > Privacy's "Clear All
        // Local Data" button already used.
        PersistenceStore.shared.clearAllLocalData()
        RecommendationStore.shared.reset()
        FollowStore.shared.reset()
    }

    /// Independent of whether the server-side logout call above succeeds —
    /// an offline sign-out previously left a fully-valid Drupal session
    /// cookie sitting in the shared cookie jar indefinitely even though the
    /// UI already showed "signed out," since URLSession(.default) persists
    /// cookies to HTTPCookieStorage.shared and nothing ever purged them.
    private func clearSessionCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        for cookie in cookies where cookie.domain.hasSuffix("applevis.com") {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
    }

    /// Called when any request comes back 401 — the server has already
    /// invalidated this session (expired token, revoked on another device,
    /// etc.), so calling the logout endpoint with those same now-invalid
    /// credentials would be pointless. Clears local state only. Previously
    /// a 401 anywhere in the app just surfaced as "Incorrect username or
    /// password" on whatever unrelated action triggered it (e.g. posting a
    /// reply), which is a confusing message for an expired session and left
    /// the stale, no-longer-valid session sitting in the Keychain.
    // MARK: - Expired sessions (2026-09-28)

    /// Called when the website refuses a write. Still signed in: returns a
    /// fresh security token to retry with. Signed out: asks the member to
    /// sign in again and returns the new token, or nil if they don't.
    /// Nil too for a genuine permission problem or when the site can't be
    /// reached, so the original error shows.
    func recoverSession() async -> String? {
        guard let current = user else { return nil }
        switch await APIClient.shared.account.sessionIsActive() {
        case true?:
            guard let fresh = await APIClient.shared.account.sessionToken(), fresh != current.csrfToken else {
                // Same token and still signed in: a real permission change.
                await refreshRoles()
                return nil
            }
            var updated = current
            updated.csrfToken = fresh
            user = updated
            saveToKeychain(updated)
            return fresh
        case false?:
            if let token = await signInQuietly() { return token }
            guard await askToSignInAgain(.whileSending) else { return nil }
            return user?.csrfToken
        case nil:
            return nil
        }
    }

    /// On opening the app: once a sign-in is older than the website keeps
    /// sessions (about 23 days; checked a little early), asks the website
    /// whether it's still signed in, and asks the member to sign in again
    /// before they start writing if it isn't.
    func checkSessionOnOpen() async {
        guard let current = user, !isCheckingSession, reSignInContinuation == nil else { return }
        let age = current.signedInAt.map { Date().timeIntervalSince($0) } ?? .infinity
        guard age > 20 * 24 * 60 * 60 else { return }
        isCheckingSession = true
        defer { isCheckingSession = false }
        if await APIClient.shared.account.sessionIsActive() == false {
            if await signInQuietly() != nil { return }
            _ = await askToSignInAgain(.onOpen)
        }
    }

    /// Before a website form submission (blog, bug report, podcast,
    /// contact). Those use the website's own forms rather than the security
    /// token, so a refusal can't be retried the same way; they're checked
    /// up front instead. True when it's fine to send.
    func ensureSessionForSending() async -> Bool {
        guard user != nil else { return true }
        guard await APIClient.shared.account.sessionIsActive() == false else { return true }
        if await signInQuietly() != nil { return true }
        return await askToSignInAgain(.whileSending)
    }

    /// Remember me: signs back in with the saved password once the website
    /// has ended the session, without asking. Returns the new security token,
    /// or nil if nothing's remembered or it didn't work. If the website turns
    /// the password down (changed on the website), it's forgotten, and the
    /// member is asked to sign in instead.
    private func signInQuietly() async -> String? {
        guard let saved = loadRememberedSignIn() else { return nil }
        do {
            var authUser = try await APIClient.shared.account.signIn(username: saved.username, password: saved.password, rememberMe: true)
            authUser.signedInAt = Date()
            user = authUser
            saveToKeychain(authUser)
            if Self.websiteRemembersSignIn() { deleteRememberedSignIn() }
            return authUser.csrfToken
        } catch APIError.unauthorized, APIError.forbidden, APIError.unknown(statusCode: 400) {
            deleteRememberedSignIn()
            return nil
        } catch {
            return nil
        }
    }

    /// After the member changes their password in the app, so Remember me
    /// keeps working.
    func updateRememberedPassword(_ newPassword: String) {
        guard let saved = loadRememberedSignIn() else { return }
        saveRememberedSignIn(RememberedSignIn(username: saved.username, password: newPassword))
    }

    /// True once the website's own "Remember me" cookie is present, meaning
    /// the website keeps the member signed in by itself.
    private static func websiteRemembersSignIn() -> Bool {
        (HTTPCookieStorage.shared.cookies ?? []).contains { cookie in
            cookie.domain.hasSuffix("applevis.com") && (cookie.name.hasPrefix("PL") || cookie.name.uppercased().hasPrefix("PERSISTENT_LOGIN"))
        }
    }

    private func saveRememberedSignIn(_ signIn: RememberedSignIn) {
        guard let data = try? JSONEncoder().encode(signIn) else { return }
        deleteRememberedSignIn()
        let query: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrAccount as String:    credentialsKey,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String:      data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            AppLog.auth.error("Remember me save failed: OSStatus \(status)")
        }
    }

    private func loadRememberedSignIn() -> RememberedSignIn? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: credentialsKey,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(RememberedSignIn.self, from: data)
    }

    private func deleteRememberedSignIn() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: credentialsKey,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func askToSignInAgain(_ reason: ReSignInPrompt.Reason) async -> Bool {
        guard reSignInContinuation == nil else { return false }
        reSignInShownAt = Date()
        let signedIn = await withCheckedContinuation { continuation in
            reSignInContinuation = continuation
            if !presentReSignIn(reason) {
                reSignInContinuation = nil
                continuation.resume(returning: false)
            }
        }
        // Chose not to sign in: the website has already signed them out,
        // so the app should say so too.
        if !signedIn { handleSessionExpired() }
        return signedIn
    }

    /// Shows the sign-in screen on top of whatever is frontmost. It's
    /// presented from UIKit rather than a SwiftUI sheet at the app's root,
    /// because the write that needed it almost always comes from a screen
    /// that's already a sheet (a Submit form, a reply), and a root sheet
    /// can't appear over that: the sign-in would never show and the write
    /// would wait forever.
    private func presentReSignIn(_ reason: ReSignInPrompt.Reason) -> Bool {
        guard let preferences = PreferencesStore.current,
              let toast = APIClient.toastStore,
              let top = Self.frontmostViewController() else { return false }
        let screen = SignInView(expiredReason: reason)
            .environmentObject(self)
            .environmentObject(toast)
            .environmentObject(preferences)
            .onDisappear { [weak self] in self?.finishReSignIn() }
        top.present(UIHostingController(rootView: screen), animated: !UIAccessibility.isReduceMotionEnabled)
        return true
    }

    private static func frontmostViewController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    /// Called when the sign-in screen closes, signed in or not.
    func finishReSignIn() {
        guard reSignInContinuation != nil else { return }
        let signedIn = (user?.signedInAt ?? .distantPast) > (reSignInShownAt ?? .distantFuture)
        reSignInShownAt = nil
        reSignInContinuation?.resume(returning: signedIn)
        reSignInContinuation = nil
    }

    func handleSessionExpired() {
        guard user != nil else { return }
        deleteRememberedSignIn()
        SpotlightIndexer.deindexAll()
        user = nil
        deleteFromKeychain()
        clearSessionCookies()
        PersistenceStore.shared.clearAllLocalData()
        RecommendationStore.shared.reset()
        FollowStore.shared.reset()
        Task { await PushNotificationManager.clearRegistration() }
    }

    /// Re-fetches this user's current Drupal roles and updates the cached
    /// AuthUser in place. Sign-in only resolves roles once (see
    /// AccountEndpoints.signIn), so a role change made on the site — a
    /// promotion, or just as importantly a demotion — never reaches an
    /// already-signed-in device on its own. Called on foreground and after
    /// a 403 (see APIClient.validateStatus) rather than on every request,
    /// so a stale Edit/Unpublish/Delete button corrects itself within one
    /// foreground cycle instead of requiring a full sign-out/sign-in.
    ///
    /// Also re-attempts uuid resolution when it's still empty: the old
    /// resolveUuid() (before it was fixed to filter on the known numeric
    /// uid — see AccountEndpoints.resolveUuid) always failed, so any account
    /// signed in before that fix has "" cached here permanently. Without
    /// this, such a session could never self-heal — it would guard-return
    /// below forever and require a manual sign-out/sign-in even after the
    /// underlying bug was fixed. Reported directly.
    func refreshRoles() async {
        guard let current = user else { return }
        do {
            var updated = current
            if updated.uuid.isEmpty {
                updated.uuid = try await APIClient.shared.account.resolveUuid(uid: current.uid, csrfToken: current.csrfToken) ?? ""
            }
            guard !updated.uuid.isEmpty else { return }
            let details = try await APIClient.shared.account.resolveAccountDetails(uuid: updated.uuid, csrfToken: current.csrfToken)
            guard details.roles != current.roles || details.email != current.email || updated.uuid != current.uuid else { return }
            updated.roles = details.roles
            updated.email = details.email
            user = updated
            saveToKeychain(updated)
        } catch {
            AppLog.auth.error("Role refresh failed: \(error, privacy: .private)")
        }
    }

    func completeOnboarding() {
        isOnboarded = true
        justCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardedKey)
    }

    // MARK: - Keychain

    private func saveToKeychain(_ user: AuthUser) {
        guard let data = try? JSONEncoder().encode(user) else {
            AppLog.auth.error("Failed to encode AuthUser for Keychain save")
            return
        }
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
        ]
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String:   data,
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            AppLog.auth.error("Keychain save failed: OSStatus \(status)")
        }
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func loadFromKeychain() -> AuthUser? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: "applevis.authUser",
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecSuccess && status != errSecItemNotFound {
                AppLog.auth.error("Keychain load failed: OSStatus \(status)")
            }
            return nil
        }
        do {
            return try JSONDecoder().decode(AuthUser.self, from: data)
        } catch {
            // SEC-07: a corrupted Keychain entry's DecodingError.debugDescription
            // has a narrow but non-zero chance of surfacing a fragment of the
            // decoded AuthUser blob (which carries csrfToken/logoutToken) —
            // .private is the safer default and costs nothing.
            AppLog.auth.error("Failed to decode AuthUser from Keychain: \(error, privacy: .private)")
            return nil
        }
    }
}
