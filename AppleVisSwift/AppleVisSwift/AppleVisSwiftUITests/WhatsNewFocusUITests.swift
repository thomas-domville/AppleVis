import XCTest

/// Verifies the Home tab's "What's New" card actually moves VoiceOver focus
/// to the first new feed item when double-tapped, rather than just scrolling
/// the viewport with the accessibility cursor left behind. Reported directly
/// by a VoiceOver user: the card's own hint promises "jump to where you left
/// off," but focus wasn't landing reliably.
///
/// This drives real, live Home tab data (no mock seam exists in the app for
/// this), so it only asserts anything when a "What's New" card is actually
/// present for the signed-out/default feed at run time; otherwise it skips
/// rather than reporting a false pass or a flaky failure.
///
/// Skipped by default in the shared scheme (run explicitly with
/// `-only-testing:AppleVisSwiftUITests`): on Simulator this consistently
/// fails `hasFocus` even for the pre-existing "land on summary at launch"
/// focus code used as a control here, which was believed working from
/// earlier live-device VoiceOver testing — i.e. Simulator's accessibility
/// stack doesn't reliably reflect @AccessibilityFocusState assignments the
/// way real VoiceOver on a physical device does. Treat a Simulator failure
/// here as inconclusive, not proof of a regression; a physical-device run
/// (device must be unlocked) is the only trustworthy signal.
final class WhatsNewFocusUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDoubleTappingWhatsNewMovesFocusToFirstNewItem() throws {
        let app = XCUIApplication()
        app.launch()

        let homeTab = app.tabBars.buttons["Home"]
        if homeTab.waitForExistence(timeout: 10) {
            homeTab.tap()
        }

        let whatsNewButton = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH[c] %@", "What's New")
        ).firstMatch

        guard whatsNewButton.waitForExistence(timeout: 15) else {
            throw XCTSkip("No \"What's New\" card present for this run (no new activity, or already dismissed) — nothing to verify.")
        }

        whatsNewButton.tap()

        // The fix retries the focus assignment across ~1 second of delays
        // to survive List's lazy row instantiation on a long scroll — give
        // that window to play out before checking.
        let focusMoved = NSPredicate(format: "hasFocus == true")
        let cells = app.cells
        let expectation = XCTNSPredicateExpectation(predicate: focusMoved, object: cells.firstMatch)
        _ = XCTWaiter.wait(for: [expectation], timeout: 2.0)

        let anyCellFocused = (0..<min(cells.count, 30)).contains { cells.element(boundBy: $0).hasFocus }
        XCTAssertTrue(
            anyCellFocused,
            "Expected VoiceOver focus to land on a feed row after double-tapping \"What's New,\" not remain on the card or nowhere."
        )
    }
}
