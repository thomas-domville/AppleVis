import Foundation

extension APIClient {
    var notifications: NotificationEndpoints { NotificationEndpoints(client: self) }
}

/// Push-token registration against Drupal's `user--user` JSON:API resource.
///
/// This isn't a placeholder guess — it's the same `field_push_token` /
/// `field_push_sound` fields the RN app used, PATCHed via the standard
/// JSON:API update pattern already used elsewhere in this file's sibling
/// endpoints (see AccountEndpoints.updateProfile).
///
/// IMPORTANT CAVEAT: the RN app obtained an *Expo* push token (via
/// `Notifications.getExpoPushTokenAsync`), not a raw APNs device token, and
/// whatever server-side code actually sends the push presumably called
/// Expo's push relay (which forwards to APNs using Expo's own credentials).
/// This app registers a raw APNs token instead (no Expo involved). Unless
/// the Drupal send logic is updated to call APNs directly with this app's
/// own APNs Auth Key, tokens registered here won't receive anything even
/// though registration itself succeeds. Confirm with whoever owns the
/// Drupal push-sending code before relying on this.
struct NotificationEndpoints {
    let client: APIClient

    func registerDeviceToken(_ token: String, soundFile: String, uuid: String, csrfToken: String) async throws {
        try await client.jsonAPIUpdate(
            "user/user/\(uuid)", type: "user--user", id: uuid,
            attributes: [
                "field_push_token": AnyEncodable(token),
                "field_push_sound": AnyEncodable(soundFile),
            ],
            headers: ["X-CSRF-Token": csrfToken]
        )
    }

    func updatePushSound(_ soundFile: String, uuid: String, csrfToken: String) async throws {
        try await client.jsonAPIUpdate(
            "user/user/\(uuid)", type: "user--user", id: uuid,
            attributes: ["field_push_sound": AnyEncodable(soundFile)],
            headers: ["X-CSRF-Token": csrfToken]
        )
    }

    /// Best-effort clear before sign-out, so the server stops targeting this device.
    func removeDeviceToken(uuid: String, csrfToken: String) async throws {
        try await client.jsonAPIUpdate(
            "user/user/\(uuid)", type: "user--user", id: uuid,
            attributes: [
                "field_push_token": AnyEncodable(""),
                "field_push_sound": AnyEncodable(""),
            ],
            headers: ["X-CSRF-Token": csrfToken]
        )
    }
}
