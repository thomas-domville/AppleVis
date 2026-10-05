import SwiftUI

/// Editors and admins pin or unpin a forum topic or blog post on the
/// website (Drupal's "Sticky at top of lists"), from a row's actions or the
/// post's own Actions menu. The website and the app then agree: pinned on
/// either shows at the top of the list in both. Requested directly
/// (2026-10-05).
enum PinAction {
    static let pinnableKinds: Set<ContentKind> = [.forumTopic, .blogPost]

    /// Returns true when the website accepted the change.
    @MainActor
    static func set(_ pin: Bool, kind: ContentKind, id: String, user: AuthUser, toast: ToastStore) async -> Bool {
        let nodeType = String(kind.nodeType.dropFirst("node--".count))
        do {
            try await APIClient.shared.content.setPinned(pin, nodeId: id, nodeType: nodeType, csrfToken: user.csrfToken)
            NotificationCenter.default.post(name: .contentPinChanged, object: id, userInfo: ["pinned": pin])
            toast.success(pin ? String(localized: "\(kind.displayName) pinned") : String(localized: "\(kind.displayName) unpinned"))
            return true
        } catch let error as APIError {
            toast.error(error.localizedDescription)
        } catch {
            toast.error(String(localized: "Couldn't change the pin. Try again."))
        }
        return false
    }
}

/// Pin or Unpin in a post's own Actions menu.
struct PinMenuItem: View {
    let kind: ContentKind
    let id: String
    let isPinned: Bool
    let onChange: (Bool) -> Void
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    var body: some View {
        Button {
            guard let user = auth.user else { return }
            Task {
                if await PinAction.set(!isPinned, kind: kind, id: id, user: user, toast: toast) {
                    onChange(!isPinned)
                }
            }
        } label: {
            if isPinned {
                Label("Unpin \(kind.displayName)", systemImage: "pin.slash")
            } else {
                Label("Pin \(kind.displayName)", systemImage: "pin")
            }
        }
    }
}

extension Notification.Name {
    /// Posted with a post's id and `userInfo["pinned"]` when an editor pins
    /// or unpins it, so lists move it straight away.
    static let contentPinChanged = Notification.Name("AppleVis.contentPinChanged")
}
