import Foundation
import SwiftUI
import Testing
@testable import AppleVis

/// Wide or narrow comes from the size class and the width actually
/// available, never the device (Adaptive Experience upgrade, phase 1).
@MainActor
@Suite("Adaptive list and detail")
struct AdaptiveLayoutTests {

    @Test("compact width never shows the item beside the list, however wide")
    func compactStaysStacked() {
        #expect(!AdaptiveLayout.showsDetailBeside(horizontalSizeClass: .compact, width: 1_400))
        #expect(!AdaptiveLayout.showsDetailBeside(horizontalSizeClass: nil, width: 1_400))
    }

    @Test("regular width shows it beside the list only with enough room")
    func regularNeedsRoom() {
        // A narrow Stage Manager window or Split View pane can still report regular.
        #expect(!AdaptiveLayout.showsDetailBeside(horizontalSizeClass: .regular, width: 600))
        #expect(AdaptiveLayout.showsDetailBeside(horizontalSizeClass: .regular, width: AdaptiveLayout.minimumSplitWidth))
        #expect(AdaptiveLayout.showsDetailBeside(horizontalSizeClass: .regular, width: 1_366))
    }

    @Test("the list pane stays between 320 and 440 points")
    func listWidthIsClamped() {
        #expect(AdaptiveLayout.listWidth(for: 700) == 320)
        #expect(AdaptiveLayout.listWidth(for: 1_000) == 360)
        #expect(AdaptiveLayout.listWidth(for: 2_000) == 440)
    }

    @Test("a selection survives being saved and restored")
    func selectionRoundTrips() throws {
        let selection = ContentSelection(kind: .forumTopic, id: "abc-123", focusFirstNewComment: true)
        let data = try JSONEncoder().encode(selection)
        #expect(try JSONDecoder().decode(ContentSelection.self, from: data) == selection)
    }

    @Test("the same item opened two ways is two different selections")
    func firstNewCommentIsPartOfIdentity() {
        let plain = ContentSelection(kind: .forumTopic, id: "abc")
        let atNew = ContentSelection(kind: .forumTopic, id: "abc", focusFirstNewComment: true)
        #expect(plain != atNew)
    }

    @Test("rows can tell which item is showing")
    func selectActionReportsSelection() {
        var chosen: ContentSelection?
        var spokenTitle = ""
        let action = SelectInDetailAction(selectedID: "abc") { chosen = $0; spokenTitle = $1 }
        #expect(action.isSelected("abc"))
        #expect(!action.isSelected("xyz"))
        action(ContentSelection(kind: .appListing, id: "xyz"), title: "VoiceDream Reader")
        #expect(chosen?.id == "xyz")
        #expect(spokenTitle == "VoiceDream Reader")
    }
}
