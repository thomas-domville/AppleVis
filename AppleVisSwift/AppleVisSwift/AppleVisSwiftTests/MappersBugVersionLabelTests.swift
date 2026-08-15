import Testing
@testable import AppleVisSwift

/// TEST-04-style coverage extending the existing `MappersTests` pattern
/// (edge-case-driven tests for a pure parsing function) to
/// `Mappers.bugVersionLabel` — sentinel values, platform-specific prefix
/// parsing, and macOS codename capitalization all have real room for a
/// subtle off-by-one/formatting bug that would only surface as a wrong
/// label on a real bug report.
@Suite("Mappers.bugVersionLabel")
struct MappersBugVersionLabelTests {

    @Test("empty string returns empty label")
    func emptyStringReturnsEmpty() {
        #expect(Mappers.bugVersionLabel("", platform: .ios) == "")
    }

    @Test("the literal sentinel \"unknown\" returns empty label")
    func unknownSentinelReturnsEmpty() {
        #expect(Mappers.bugVersionLabel("unknown", platform: .ios) == "")
    }

    @Test("the literal sentinel \"0\" returns empty label")
    func zeroSentinelReturnsEmpty() {
        #expect(Mappers.bugVersionLabel("0", platform: .macos) == "")
    }

    @Test("a purely numeric value (a stray taxonomy tid, not a real version string) returns empty label")
    func purelyNumericReturnsEmpty() {
        #expect(Mappers.bugVersionLabel("12345", platform: .ios) == "")
    }

    @Test("an ios_ipados_ prefixed value formats as \"iOS/iPadOS X.Y\"")
    func iosPrefixFormatsCorrectly() {
        #expect(Mappers.bugVersionLabel("ios_ipados_17_4", platform: .ios) == "iOS/iPadOS 17.4")
    }

    @Test("a macos_ prefixed value with a version formats as \"macOS Codename X.Y\"")
    func macosPrefixWithVersionFormatsCorrectly() {
        #expect(Mappers.bugVersionLabel("macos_sonoma_14_4", platform: .macos) == "macOS Sonoma 14.4")
    }

    @Test("a macos_ prefixed value with no trailing version segment formats as just \"macOS Codename\"")
    func macosPrefixWithNoVersionFormatsCorrectly() {
        #expect(Mappers.bugVersionLabel("macos_sonoma", platform: .macos) == "macOS Sonoma")
    }

    @Test("a value with no recognized prefix is returned unchanged")
    func unrecognizedPrefixReturnsRawValue() {
        #expect(Mappers.bugVersionLabel("some_other_value", platform: .ios) == "some_other_value")
    }
}
