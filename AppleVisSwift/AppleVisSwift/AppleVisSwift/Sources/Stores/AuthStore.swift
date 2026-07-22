import Foundation
import Combine
import Security

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var user: AuthUser?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published var isOnboarded: Bool

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
        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = "Sign in failed. Please try again."
        }
        isLoading = false
    }

    func signOut() async {
        guard let u = user else { return }
        try? await APIClient.shared.account.logout(csrfToken: u.csrfToken, logoutToken: u.logoutToken)
        user = nil
        deleteFromKeychain()
    }

    func completeOnboarding() {
        isOnboarded = true
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
