import UIKit
import UserNotifications

/// APNs client-side plumbing: registration, device token capture, notification
/// categories/actions, and tap-through routing into the app.
///
/// Token registration is real (PATCHes `field_push_token`/`field_push_sound`
/// on the user's JSON:API resource — see NotificationEndpoints.swift), the
/// same mechanism the RN app used and confirmed working. What's unverified
/// is whether the server-side sender still assumes an Expo push token; this
/// app registers a raw APNs token instead. Confirm with whoever owns the
/// Drupal send logic.
@MainActor
enum PushNotificationManager {
    /// Set once at launch by `AppleVisApp` so a tapped notification has
    /// somewhere to route to.
    static weak var deepLinkRouter: DeepLinkRouter?

    /// Set once at launch so a device token can be paired with the signed-in
    /// user's UUID/CSRF token whenever both become available.
    static weak var authStore: AuthStore?

    private static var cachedDeviceToken: String?

    static func registerCategories() {
        let viewAction = UNNotificationAction(identifier: "VIEW", title: "View", options: [.foreground])
        let dismissAction = UNNotificationAction(identifier: "DISMISS", title: "Dismiss", options: [.destructive])

        let categories: [UNNotificationCategory] = [
            "forumReply", "mention", "newTopic", "followedTopic",
            "newEpisode", "appUpdate", "newResource", "announcement",
        ].map { id in
            UNNotificationCategory(
                identifier: id, actions: [viewAction, dismissAction],
                intentIdentifiers: [], options: []
            )
        }
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
    }

    /// Requests permission (same prompt as NotificationSettingsView already
    /// triggers) and, once granted, registers for a device token.
    @discardableResult
    static func requestAuthorizationAndRegister() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    static func didRegister(deviceToken: Data) {
        cachedDeviceToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task { await syncRegistration() }
    }

    static func didFailToRegister(_ error: Error) {
        #if DEBUG
        print("Push registration failed: \(error)")
        #endif
    }

    /// Uploads the current device token + chosen notification sound for the
    /// signed-in user. Safe to call opportunistically (sign-in, permission
    /// grant, sound preference change) — it's a no-op until both a token and
    /// a signed-in user are available.
    static func syncRegistration() async {
        guard let token = cachedDeviceToken, let user = authStore?.user else { return }
        let soundFile = (UserDefaults.standard.string(forKey: "notif.sound").flatMap(NotificationSound.init(rawValue:)) ?? .mouseSqueak).pushSoundFile
        try? await APIClient.shared.notifications.registerDeviceToken(
            token, soundFile: soundFile, uuid: user.uuid, csrfToken: user.csrfToken
        )
    }

    /// Best-effort clear before sign-out.
    static func clearRegistration() async {
        guard let user = authStore?.user else { return }
        try? await APIClient.shared.notifications.removeDeviceToken(uuid: user.uuid, csrfToken: user.csrfToken)
    }

    /// Routes a tapped/received notification's payload into the app via the
    /// same `DeepLinkRouter.pendingContent` path Spotlight taps use.
    /// Expected payload shape: `{"kind": "forumTopic", "id": "<uuid>"}`.
    static func handle(userInfo: [AnyHashable: Any]) {
        guard let kindRaw = userInfo["kind"] as? String,
              let id = userInfo["id"] as? String,
              let kind = ContentKind(rawValue: kindRaw) else { return }
        deepLinkRouter?.pendingContent = (kind: kind, id: id)
    }

    /// Records a notification into on-device history (Home's Notification
    /// summary — docs/APPLEVIS_2026_1_MASTER_SPEC.md) whenever one arrives,
    /// whether or not it's ever tapped. `kind`/`id` come from the same
    /// custom payload keys `handle(userInfo:)` reads.
    static func recordHistory(content: UNNotificationContent) {
        let kind = (content.userInfo["kind"] as? String).flatMap(ContentKind.init(rawValue:))
        let contentId = content.userInfo["id"] as? String
        PersistenceStore.shared.recordNotification(NotificationHistoryItem(
            id: UUID().uuidString,
            title: content.title,
            body: content.body,
            receivedAt: Date(),
            kind: kind,
            contentId: kind != nil ? contentId : nil
        ))
    }
}

/// Bridges UIKit app-delegate callbacks (APNs registration, foreground
/// presentation, notification taps) into the SwiftUI app via `@UIApplicationDelegateAdaptor`.
final class AppleVisAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in PushNotificationManager.registerCategories() }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushNotificationManager.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in PushNotificationManager.didFailToRegister(error) }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await MainActor.run {
            PushNotificationManager.recordHistory(content: notification.request.content)
        }
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // Notifications tapped while the app wasn't running/foregrounded
        // never pass through willPresent, so this is also a recording point,
        // not just the tap-to-open route — duplicate entries aren't a
        // concern since willPresent only fires for foreground delivery.
        await MainActor.run {
            PushNotificationManager.recordHistory(content: response.notification.request.content)
        }
        guard response.actionIdentifier != "DISMISS" else { return }
        await MainActor.run {
            PushNotificationManager.handle(userInfo: response.notification.request.content.userInfo)
        }
    }
}
