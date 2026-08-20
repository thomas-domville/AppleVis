import Testing
@testable import AppleVis

/// Regression coverage for CARD-01/CARD-03/FORUM-03: duplicate and
/// out-of-order VoiceOver actions on content rows/detail screens, including
/// an admin who also owns a forum topic seeing two indistinguishable
/// "Edit Topic" entries. Exercises `ContentActionsModifier.canonicalActions`
/// — a hand-maintained mirror of the real `.contextMenu` +
/// `.accessibilityAction` chain, see the doc comment on that function — across
/// every permission permutation.
@Suite("ContentActionsModifier action ordering")
struct ContentActionsOrderingTests {

    private static let allBoolCombos: [(hasNewCount: Bool, supportsFollow: Bool, isSignedIn: Bool, hasUrl: Bool, isOwnTopic: Bool, isAdmin: Bool)] = {
        var combos: [(Bool, Bool, Bool, Bool, Bool, Bool)] = []
        for a in [false, true] {
            for b in [false, true] {
                for c in [false, true] {
                    for d in [false, true] {
                        for e in [false, true] {
                            for f in [false, true] {
                                combos.append((a, b, c, d, e, f))
                            }
                        }
                    }
                }
            }
        }
        return combos
    }()

    @Test("never produces a duplicate action, for any permission combination")
    func noDuplicatesAcrossAllPermutations() {
        for combo in Self.allBoolCombos {
            let actions = ContentActionsModifier.canonicalActions(
                hasNewCount: combo.hasNewCount, supportsFollow: combo.supportsFollow,
                isSignedIn: combo.isSignedIn, hasUrl: combo.hasUrl,
                isOwnTopic: combo.isOwnTopic, isAdmin: combo.isAdmin
            )
            #expect(Set(actions).count == actions.count, "duplicate action for \(combo)")
        }
    }

    @Test("an admin who also owns the topic gets only the admin Edit/Delete, not both")
    func ownerAdminOverlapPrefersAdminActions() {
        let actions = ContentActionsModifier.canonicalActions(
            hasNewCount: false, supportsFollow: true, isSignedIn: true, hasUrl: true,
            isOwnTopic: true, isAdmin: true
        )
        #expect(!actions.contains(.editTopic))
        #expect(!actions.contains(.deleteTopic))
        #expect(actions.contains(.editContent))
        #expect(actions.contains(.deleteContent))
    }

    @Test("a non-admin owner gets owner-flavored Edit/Delete Topic, not the generic admin actions")
    func nonAdminOwnerGetsOwnerActions() {
        let actions = ContentActionsModifier.canonicalActions(
            hasNewCount: false, supportsFollow: true, isSignedIn: true, hasUrl: true,
            isOwnTopic: true, isAdmin: false
        )
        #expect(actions.contains(.editTopic))
        #expect(actions.contains(.deleteTopic))
        #expect(!actions.contains(.editContent))
        #expect(!actions.contains(.unpublish))
        #expect(!actions.contains(.deleteContent))
    }

    @Test("save is always offered")
    func saveAlwaysPresent() {
        for combo in Self.allBoolCombos {
            let actions = ContentActionsModifier.canonicalActions(
                hasNewCount: combo.hasNewCount, supportsFollow: combo.supportsFollow,
                isSignedIn: combo.isSignedIn, hasUrl: combo.hasUrl,
                isOwnTopic: combo.isOwnTopic, isAdmin: combo.isAdmin
            )
            #expect(actions.contains(.save))
        }
    }

    @Test("follow only appears when supported and signed in")
    func followGatedOnSupportAndSignIn() {
        #expect(ContentActionsModifier.canonicalActions(
            hasNewCount: false, supportsFollow: true, isSignedIn: true, hasUrl: false,
            isOwnTopic: false, isAdmin: false
        ).contains(.follow))
        #expect(!ContentActionsModifier.canonicalActions(
            hasNewCount: false, supportsFollow: true, isSignedIn: false, hasUrl: false,
            isOwnTopic: false, isAdmin: false
        ).contains(.follow))
        #expect(!ContentActionsModifier.canonicalActions(
            hasNewCount: false, supportsFollow: false, isSignedIn: true, hasUrl: false,
            isOwnTopic: false, isAdmin: false
        ).contains(.follow))
    }

    @Test("share and open-in-browser only appear together, and only with a url")
    func shareAndBrowserGatedTogetherOnUrl() {
        for combo in Self.allBoolCombos {
            let actions = ContentActionsModifier.canonicalActions(
                hasNewCount: combo.hasNewCount, supportsFollow: combo.supportsFollow,
                isSignedIn: combo.isSignedIn, hasUrl: combo.hasUrl,
                isOwnTopic: combo.isOwnTopic, isAdmin: combo.isAdmin
            )
            #expect(actions.contains(.share) == combo.hasUrl)
            #expect(actions.contains(.openInBrowser) == combo.hasUrl)
        }
    }

    @Test("destructive actions always sort after every non-destructive action")
    func destructiveActionsSortLast() {
        let destructive: Set<ContentAction> = [.deleteTopic, .deleteContent]
        for combo in Self.allBoolCombos {
            let actions = ContentActionsModifier.canonicalActions(
                hasNewCount: combo.hasNewCount, supportsFollow: combo.supportsFollow,
                isSignedIn: combo.isSignedIn, hasUrl: combo.hasUrl,
                isOwnTopic: combo.isOwnTopic, isAdmin: combo.isAdmin
            )
            guard let firstDestructiveIndex = actions.firstIndex(where: { destructive.contains($0) }) else { continue }
            let precedingActions = actions[..<firstDestructiveIndex]
            #expect(precedingActions.allSatisfy { !destructive.contains($0) }, "destructive action appeared before a non-destructive one for \(combo)")
        }
    }

    @Test("mark-as-read, when present, is always first")
    func markAsReadIsAlwaysFirstWhenPresent() {
        for combo in Self.allBoolCombos where combo.hasNewCount {
            let actions = ContentActionsModifier.canonicalActions(
                hasNewCount: combo.hasNewCount, supportsFollow: combo.supportsFollow,
                isSignedIn: combo.isSignedIn, hasUrl: combo.hasUrl,
                isOwnTopic: combo.isOwnTopic, isAdmin: combo.isAdmin
            )
            #expect(actions.first == .markAsRead)
        }
    }
}
