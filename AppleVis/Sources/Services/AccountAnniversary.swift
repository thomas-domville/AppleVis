import Foundation

/// Detects whether today marks (or has passed, since this only runs when
/// Home actually loads — someone could be away on the real day) an
/// uncelebrated anniversary of the account's creation date, and hands back
/// how many years it's been. `created` is the account's real join date on
/// the site (same value shown as "Member since" on profiles) — nothing to
/// do with when the app was installed.
enum AccountAnniversary {
    /// Returns years-since-joining the first time this year's anniversary
    /// is checked after it has occurred, or nil otherwise (not yet reached
    /// this year, already shown this year, or the join date, joined this
    /// same calendar year, or couldn't be resolved). Marks the year as
    /// shown as a side effect, so calling this again this year always
    /// returns nil even if called repeatedly.
    ///
    /// `isFirstDeviceVisit` should be true on a device's very first Home
    /// load for this sign-in (fresh install, or first sign-in ever) — the
    /// "already shown this year" bookkeeping below lives in local
    /// UserDefaults, which a reinstall wipes, so without this a returning
    /// member whose real anniversary already passed earlier in the year
    /// would get congratulated again the moment they reinstall, right out
    /// of onboarding. In that case the year is still marked consumed so it
    /// won't pop up later this session either — celebrating resumes on the
    /// account's next genuine anniversary.
    @MainActor
    static func checkAndConsume(for user: AuthUser, isFirstDeviceVisit: Bool = false) async -> Int? {
        guard let joinDate = await resolvedJoinDate(for: user) else { return nil }

        let calendar = Calendar.current
        let now = Date()
        let joinYear = calendar.component(.year, from: joinDate)
        let currentYear = calendar.component(.year, from: now)
        guard currentYear > joinYear else { return nil } // Can't celebrate the year you joined.

        let joined = calendar.dateComponents([.month, .day], from: joinDate)
        let today = calendar.dateComponents([.month, .day], from: now)
        guard let jm = joined.month, let jd = joined.day, let tm = today.month, let td = today.day else { return nil }
        let anniversaryHasOccurred = tm > jm || (tm == jm && td >= jd)
        guard anniversaryHasOccurred else { return nil }

        let shownKey = "profile.anniversary.lastYearShown.\(user.uid)"
        let lastShown = UserDefaults.standard.object(forKey: shownKey) as? Int ?? 0
        guard currentYear > lastShown else { return nil }

        UserDefaults.standard.set(currentYear, forKey: shownKey)
        guard !isFirstDeviceVisit else { return nil }
        return currentYear - joinYear
    }

    /// The account creation date never changes once set, so this is cached
    /// locally after the first lookup rather than fetched on every check —
    /// `checkAndConsume` runs once per Home load for the life of the
    /// signed-in session.
    private static func resolvedJoinDate(for user: AuthUser) async -> Date? {
        let cacheKey = "profile.anniversary.joinDate.\(user.uid)"
        if let cached = UserDefaults.standard.object(forKey: cacheKey) as? Double {
            return Date(timeIntervalSince1970: cached)
        }
        guard let profile = try? await APIClient.shared.users.profile(uuid: user.uuid) else { return nil }
        UserDefaults.standard.set(profile.memberSince.timeIntervalSince1970, forKey: cacheKey)
        return profile.memberSince
    }
}
