import Foundation
import Combine
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
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
        }
        user = Self.loadFromKeychain()
        AuthStore.current = self
    }

    func signIn(username: String, password: String) async {
        isLoading = true
        error = nil
        do {
            let authUser = try await APIClient.shared.account.signIn(username: username, password: password)
            user = authUser
            saveToKeychain(authUser)
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
    func handleSessionExpired() {
        guard user != nil else { return }
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
