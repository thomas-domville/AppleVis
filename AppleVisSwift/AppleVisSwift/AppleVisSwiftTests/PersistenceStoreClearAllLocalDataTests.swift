import Testing
import Foundation
@testable import AppleVisSwift

/// Regression coverage for ARCH-04/PERS-05: sign-out previously left saved
/// items, followed topics, read/visited state, and notification history
/// fully intact — a shared-device privacy leak, since the next person to
/// sign in inherited the previous user's data. `AuthStore.signOut()`/
/// `handleSessionExpired()` now call `clearAllLocalData()`, the same method
/// Settings > Privacy > "Clear All Local Data" already used; this test
/// exercises `clearAllLocalData()` itself, which both of those call.
@Suite("PersistenceStore.clearAllLocalData")
@MainActor
struct PersistenceStoreClearAllLocalDataTests {

    @Test("clearing local data empties saved items, followed items, notification history, and item visits")
    func clearAllLocalDataEmptiesEverything() {
        let store = PersistenceStore.shared

        store.save(SavedItem(id: "t1", kind: .forumTopic, title: "Test topic", savedAt: .now, lastActivityAt: nil), sync: false)
        store.markFollowed(FollowedItem(id: "t1", kind: .forumTopic, nodeType: "forum_topic", title: "Test topic", followedAt: .now, lastActivityAt: nil, url: ""), sync: false)
        store.recordNotification(NotificationHistoryItem(id: "n1", title: "New reply", body: "Someone replied", receivedAt: .now, kind: .forumTopic, contentId: "t1"))
        store.stampItemVisit(id: "t1", commentCount: 5)

        #expect(!store.savedItems().isEmpty)
        #expect(!store.followedItems().isEmpty)
        #expect(!store.notificationHistory().isEmpty)
        #expect(!store.allItemVisits().isEmpty)

        store.clearAllLocalData()

        #expect(store.savedItems().isEmpty)
        #expect(store.followedItems().isEmpty)
        #expect(store.notificationHistory().isEmpty)
        #expect(store.allItemVisits().isEmpty)
    }
}
