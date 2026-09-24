import Testing
import Foundation
@testable import AppleVis

/// Community Picks reads a native REST endpoint that was requested from the
/// Drupal developer but isn't live yet (see CommunityPicksEndpoints). These
/// pin the requested contract, so a mismatch shows up here rather than as
/// silently empty rows once the endpoint arrives.
@Suite("Community Picks")
@MainActor
struct CommunityPickTests {

    private func item(_ fields: [String: JSONValue]) -> [String: JSONValue] {
        var base: [String: JSONValue] = [
            "uuid": .string("6f1c2a4e-1b2c-4d5e-8f90-123456789abc"),
            "nid": .number(4321),
            "title": .string("Seeing AI"),
            "type": .string("ios_app_directory"),
            "url": .string("/apps/ios/utilities/seeing-ai"),
            "category": .string("Utilities"),
            "recommendations": .number(12),
            "total_recommendations": .number(75),
            "last_recommended": .number(1_758_000_000),
        ]
        base.merge(fields) { _, new in new }
        return base
    }

    @Test("maps counts, platform, dates, and a full website URL")
    func mapsFields() throws {
        let pick = try #require(Mappers.communityPick(item([:])))
        #expect(pick.app.name == "Seeing AI")
        #expect(pick.app.nid == 4321)
        #expect(pick.app.platform == .ios)
        #expect(pick.app.url == "https://www.applevis.com/apps/ios/utilities/seeing-ai")
        #expect(pick.periodCount == 12)
        #expect(pick.totalCount == 75)
        #expect(pick.lastRecommendedAt == Date(timeIntervalSince1970: 1_758_000_000))
    }

    @Test("reads every platform's Drupal bundle, with or without the node-- prefix")
    func platforms() {
        #expect(Mappers.communityPick(item(["type": .string("mac_app_directory")]))?.app.platform == .macos)
        #expect(Mappers.communityPick(item(["type": .string("watch_directory")]))?.app.platform == .watchos)
        #expect(Mappers.communityPick(item(["type": .string("node--tv_directory")]))?.app.platform == .tvos)
    }

    @Test("drops items without a real UUID, since they could never open")
    func rejectsBadUUID() {
        #expect(Mappers.communityPick(item(["uuid": .string("null")])) == nil)
    }

    @Test("an all-time response without a period count uses the total")
    func missingPeriodCount() throws {
        var fields = item([:])
        fields["recommendations"] = nil
        let pick = try #require(Mappers.communityPick(fields))
        #expect(pick.periodCount == 75)
    }

    @Test("periods start at midnight the right number of months back; All Time has no start")
    func periodStart() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 15)))
        let expected = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 24)))
        #expect(CommunityPicksPeriod.threeMonths.since(now: now, calendar: calendar) == expected)
        #expect(CommunityPicksPeriod.allTime.since(now: now, calendar: calendar) == nil)
    }
}
