import Foundation
import UserNotifications

/// Catch-up reminders (2026-10-08, requested directly). When someone hasn't
/// opened AppleVis for a week, one gentle notification says what's waiting.
/// A second follows two weeks later if they still haven't opened it, then
/// nothing more until they've been back. Opening the app cancels both and
/// starts again, so regular readers never see one.
///
/// Everything happens on the iPhone; the website isn't involved. Background
/// refresh (BackgroundRefreshTask) updates a waiting reminder with real
/// counts of what's new. Off until the member turns it on, in Settings >
/// Notifications or when offered once on Home.
enum CatchUpReminders {
    static let enabledKey = "notif.catchUpReminders"
    static let category = "catchUp"
    private static let ids = ["catchUp.first", "catchUp.second"]
    private static let firstDelay: TimeInterval = 7 * 24 * 60 * 60
    private static let secondDelay: TimeInterval = 21 * 24 * 60 * 60

    private static let lastOpenedKey = "catchUp.lastOpened"
    private static let openHoursKey = "catchUp.openHours"
    private static let lastMessageKey = "catchUp.lastMessage"
    private static let openDaysKey = "catchUp.openDays"
    static let offeredKey = "catchUp.offered"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    // MARK: - Opening and leaving

    /// The member is here: cancel any waiting reminder, and note the time
    /// of day so reminders can arrive when they usually read.
    static func appBecameActive() {
        let now = Date()
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastOpenedKey)
        var hours = UserDefaults.standard.array(forKey: openHoursKey) as? [Int] ?? []
        hours.append(Calendar.current.component(.hour, from: now))
        UserDefaults.standard.set(Array(hours.suffix(20)), forKey: openHoursKey)
        var days = Set(UserDefaults.standard.stringArray(forKey: openDaysKey) ?? [])
        if days.count < 10 { days.insert(dayStamp(now)) }
        UserDefaults.standard.set(Array(days), forKey: openDaysKey)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// The member is leaving: schedule both reminders, if they're on.
    static func appWentToBackground() {
        guard isEnabled else { return }
        Task { await schedule(newPosts: nil, newEpisodes: nil) }
    }

    /// Called after a background refresh: rewrites the waiting reminders
    /// with what's actually new since the member last opened AppleVis.
    static func update(with items: [FeedItem]) async {
        guard isEnabled, let lastOpened else { return }
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        guard pending.contains(where: { ids.contains($0.identifier) }) else { return }
        let fresh = items.filter { $0.lastActivityAt > lastOpened }
        let episodes = fresh.filter { if case .podcastEpisode = $0 { return true } else { return false } }.count
        await schedule(newPosts: fresh.count - episodes, newEpisodes: episodes)
    }

    /// Turning reminders off removes any already waiting.
    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Offered once on Home, after AppleVis has been opened on three
    /// different days, and never to someone who has already chosen.
    static var shouldOffer: Bool {
        !UserDefaults.standard.bool(forKey: offeredKey) && !isEnabled
            && (UserDefaults.standard.stringArray(forKey: openDaysKey)?.count ?? 0) >= 3
    }

    static func markOffered() { UserDefaults.standard.set(true, forKey: offeredKey) }

    // MARK: - Scheduling

    private static var lastOpened: Date? {
        let stamp = UserDefaults.standard.double(forKey: lastOpenedKey)
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    private static func schedule(newPosts: Int?, newEpisodes: Int?) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let base = lastOpened ?? Date()
        let first = deliveryDate(after: base.addingTimeInterval(firstDelay))
        let second = deliveryDate(after: base.addingTimeInterval(secondDelay))
        center.removePendingNotificationRequests(withIdentifiers: ids)
        for (id, date) in zip(ids, [first, second]) where date > Date() {
            let content = UNMutableNotificationContent()
            content.body = nextMessage(newPosts: newPosts ?? 0, newEpisodes: newEpisodes ?? 0)
            content.sound = .default
            content.categoryIdentifier = category
            content.userInfo = ["route": "catchUp"]
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    /// The member's usual hour for reading AppleVis, kept between 9 in the
    /// morning and 8 in the evening. Late morning until we know.
    private static func deliveryDate(after date: Date) -> Date {
        let hours = (UserDefaults.standard.array(forKey: openHoursKey) as? [Int] ?? []).sorted()
        let usual = hours.isEmpty ? 10 : hours[hours.count / 2]
        let hour = min(max(usual, 9), 20)
        let calendar = Calendar.current
        let sameDay = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        return sameDay >= date ? sameDay : calendar.date(byAdding: .day, value: 1, to: sameDay) ?? sameDay
    }

    private static func dayStamp(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    // MARK: - Messages

    /// A different message each time, never the same one twice in a row.
    /// Counts are used only when background refresh found at least two of
    /// something, so a message never reads "1 posts". iOS already shows
    /// the AppleVis name, so there's no title.
    private static func nextMessage(newPosts: Int, newEpisodes: Int) -> String {
        let options = messages(posts: newPosts >= 2 ? newPosts : 0, episodes: newEpisodes >= 2 ? newEpisodes : 0)
        let last = UserDefaults.standard.string(forKey: lastMessageKey)
        let choices = options.filter { $0 != last }
        let pick = (choices.isEmpty ? options : choices).randomElement() ?? options[0]
        UserDefaults.standard.set(pick, forKey: lastMessageKey)
        return pick
    }

    private static func messages(posts: Int, episodes: Int) -> [String] {
        if posts > 0 && episodes > 0 {
            return [
                String(localized: "Goldie fetched \(posts) posts with new activity and \(episodes) podcast episodes while you were away."),
                String(localized: "Since your last visit: \(posts) posts with new activity and \(episodes) podcast episodes. Have a look when you're ready."),
                String(localized: "The Mouse has been keeping track. \(posts) posts with new activity and \(episodes) podcast episodes are waiting."),
            ]
        }
        if posts > 0 {
            return [
                String(localized: "Goldie's been busy fetching. \(posts) posts with new activity are waiting for you."),
                String(localized: "The Mouse has been tidying up. There are \(posts) posts with new activity to catch up on."),
                String(localized: "The community has been chatting. \(posts) posts have new activity since your last visit."),
            ]
        }
        if episodes > 0 {
            return [
                String(localized: "\(episodes) new podcast episodes are ready whenever you'd like a listen."),
                String(localized: "Goldie found \(episodes) new podcast episodes while you were away."),
            ]
        }
        return [
            String(localized: "There's been plenty happening on AppleVis. Have a look when you're ready."),
            String(localized: "The Mouse saved you a seat. AppleVis is here whenever you're ready."),
            String(localized: "Goldie's waiting by the door with the latest from the community."),
            String(localized: "New topics, apps, and episodes may be waiting. Pop in when you have a moment."),
        ]
    }
}
