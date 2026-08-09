import Foundation
import Combine
import Security

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var user: AuthUser?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published var isOnboarded: Bool
    /// One-shot signal so ContentView can offer the welcome-tour auto-prompt
    /// right after setup finishes — RN did this from onboarding's own "Next"
    /// handler, but Swift's transition to ContentView is state-driven, not
    /// an imperative navigation call, so the signal has to live here instead.
    @Published var justCompletedOnboarding = false

    var isSignedIn: Bool { user != nil }

    private let keychainKey = "applevis.authUser"
    private let onboardedKey = "applevis.onboarded"

    init() {
        isOnboarded = UserDefaults.standard.bool(forKey: "applevis.onboarded")
        user = Self.loadFromKeychain()
    }

    func signIn(username: String, password: String) async {
        isLoading = true
        error = nil
        do {
            let authUser = try await APIClient.shared.account.signIn(username: username, password: password)
            user = authUser
            saveToKeychain(authUser)
            Task { await PushNotificationManager.syncRegistration() }
        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = "Sign in failed. Please try again."
        }
        isLoading = false
    }

    func signOut() async {
        guard let u = user else { return }
        await PushNotificationManager.clearRegistration()
        try? await APIClient.shared.account.logout(csrfToken: u.csrfToken, logoutToken: u.logoutToken)
        SpotlightIndexer.deindexAll()
        user = nil
        deleteFromKeychain()
        clearSessionCookies()
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
    func handleSessionExpired() {
        guard user != nil else { return }
        SpotlightIndexer.deindexAll()
        user = nil
        deleteFromKeychain()
        clearSessionCookies()
        Task { await PushNotificationManager.clearRegistration() }
    }

    func completeOnboarding() {
        isOnboarded = true
        justCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardedKey)
    }

    // MARK: - Keychain

    private func saveToKeychain(_ user: AuthUser) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String:   data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
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
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(AuthUser.self, from: data)
    }
}
