import Testing
@testable import AppleVis

/// Regression coverage for PODCAST-10: duration was formatted five different,
/// inconsistent ways across five files ("2:15:00" vs "2h 15m" vs "2 hr 15
/// min" for the same value). Covers the hour/minute/second boundary cases
/// the audit specifically called out.
@Suite("PodcastDuration formatting")
struct PodcastDurationTests {

    @Test("colon: under an hour omits the hours component")
    func colonUnderAnHour() {
        #expect(PodcastDuration.colon(65) == "1:05")
        #expect(PodcastDuration.colon(59) == "0:59")
    }

    @Test("colon: an hour or more includes the hours component, zero-padded")
    func colonOverAnHour() {
        #expect(PodcastDuration.colon(3665) == "1:01:05")
        #expect(PodcastDuration.colon(3600) == "1:00:00")
    }

    @Test("colon: exact minute/hour boundaries")
    func colonBoundaries() {
        #expect(PodcastDuration.colon(60) == "1:00")
        #expect(PodcastDuration.colon(0) == "0:00")
    }

    @Test("colon: negative input clamps to zero instead of producing a negative time")
    func colonClampsNegative() {
        #expect(PodcastDuration.colon(-5) == "0:00")
    }

    @Test("abbreviated: under an hour shows minutes only")
    func abbreviatedUnderAnHour() {
        let result = PodcastDuration.abbreviated(45 * 60)
        #expect(result.contains("45"))
        #expect(!result.contains(":"))
    }

    @Test("abbreviated: an hour or more shows both components")
    func abbreviatedOverAnHour() {
        let result = PodcastDuration.abbreviated(2 * 3600 + 15 * 60)
        #expect(result.contains("2"))
        #expect(result.contains("15"))
    }
}
