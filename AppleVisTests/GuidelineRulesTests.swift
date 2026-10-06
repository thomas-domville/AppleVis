import Foundation
import Testing
@testable import AppleVis

/// The built-in rules file is what every member falls back to, so every
/// build must prove it's complete and valid (2026-10-06).
@Suite("Guideline rules file")
struct GuidelineRulesTests {

    @Test("the built-in rules file loads, with every pattern compiling")
    func builtInLoads() {
        let rules = GuidelineRules.builtIn
        #expect(rules.version >= 1)
        for key in GuidelineRules.requiredPatterns {
            #expect(!rules.patterns(key).isEmpty, "missing \(key)")
        }
        for key in GuidelineRules.requiredLists {
            #expect(!rules.list(key).isEmpty, "missing \(key)")
        }
    }

    @Test("a damaged or incomplete download is ignored")
    func badDownloadsAreRejected() throws {
        #expect(GuidelineRules(data: Data("not json".utf8), source: "test") == nil)
        let url = try #require(Bundle.main.url(forResource: "guideline-rules", withExtension: "json"))
        var doc = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var patterns = try #require(doc["patterns"] as? [String: Any])
        patterns["advertising"] = ["(unclosed"]
        doc["patterns"] = patterns
        let broken = try JSONSerialization.data(withJSONObject: doc)
        #expect(GuidelineRules(data: broken, source: "test") == nil, "a pattern that won't compile must be refused")
    }

    @Test("Apple Intelligence gets a description for every judgement-call rule")
    func meaningsForSecondOpinions() {
        for id in ["tone-medium", "tone-low", "personal-info", "self-promotion", "advertising",
                   "press-release", "ai-disclosure", "multi-topic", "excessive-punctuation", "all-caps"] {
            #expect(GuidelineRules.current.meaning(forRule: id) != nil, "no meaning for \(id)")
        }
    }
}
