import XCTest

/// Diagnostic test for a reported bug: signing in with a site_editor account
/// ("Snorlax") does not unlock Edit/Unpublish/Delete on forum topics/comments
/// the way the editor role should allow. Drives the real, live app against
/// the real, live AppleVis backend (no mock seam exists for auth/roles), so
/// it only asserts what it can actually observe at run time.
final class SnorlaxEditorPermissionsUITests: XCTestCase {
    /// Pulled from the environment rather than hardcoded so this file is
    /// safe to commit to a public repo. Set both before running this test —
    /// e.g. `SNORLAX_TEST_USERNAME=... SNORLAX_TEST_PASSWORD=... xcodebuild test ...`,
    /// or add them under Xcode's own Scheme > Test > Arguments > Environment
    /// Variables (stored per-user under xcuserdata, which is gitignored, so
    /// they never land in source control that way either).
    private var username: String!
    private var password: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let username = ProcessInfo.processInfo.environment["SNORLAX_TEST_USERNAME"], !username.isEmpty,
              let password = ProcessInfo.processInfo.environment["SNORLAX_TEST_PASSWORD"], !password.isEmpty else {
            throw XCTSkip("Set SNORLAX_TEST_USERNAME and SNORLAX_TEST_PASSWORD (environment variables, or Xcode Scheme > Test > Environment Variables) to run this test.")
        }
        self.username = username
        self.password = password
    }

    /// Several onboarding/menu labels carry an appended accessibility hint
    /// after a comma (e.g. "Yes, Remember on This Device, Home can show
    /// what's new..."), so an exact `app.buttons["..."]` subscript misses
    /// them - match on prefix instead.
    private func tap(_ app: XCUIApplication, startingWith prefix: String, timeout: TimeInterval = 10) -> Bool {
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", prefix)).firstMatch
        guard button.waitForExistence(timeout: timeout) else { return false }
        button.tap()
        return true
    }

    func testSiteEditorSeesTopicActionsMenu() throws {
        let app = XCUIApplication()
        app.launch()

        // Fresh simulator install has no persisted onboarded state - walk
        // through the first-run flow before the tab bar exists. iOS Keychain
        // items survive `simctl uninstall` (matching real-device behavior),
        // so if a prior run left Snorlax's session cached, OnboardingView's
        // nextStep() (OnboardingView.swift:83-85) auto-skips the sign-in and
        // "signed out history" steps the instant SignInStep appears - the
        // exact steps offered varies by whether that cache exists, so tap
        // whichever known onboarding button is currently on screen rather
        // than assuming a fixed step sequence.
        if tap(app, startingWith: "Get Started", timeout: 5) {
            let onboardingLabels = [
                "Skip for Now", "Yes, Remember on This Device", "No, Don't Remember",
                "Continue", "Skip", "Start Exploring",
            ]
            var guardCount = 0
            while !app.tabBars.buttons["Home"].exists && guardCount < 10 {
                guardCount += 1
                guard let matched = onboardingLabels.first(where: {
                    app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", $0)).firstMatch.waitForExistence(timeout: 3)
                }) else {
                    print("=== ONBOARDING DUMP (iteration \(guardCount)) ===\n\(app.debugDescription)\n=== END DUMP ===")
                    XCTFail("Onboarding: no known button found to advance past iteration \(guardCount).")
                    return
                }
                _ = tap(app, startingWith: matched, timeout: 3)
            }
        }

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10), "Tab bar never appeared after onboarding.")

        // Dismiss the "Take a quick tour?" alert that fires ~2.5s after
        // onboarding completes, if it shows up.
        _ = tap(app, startingWith: "Maybe Later", timeout: 4)

        XCTAssertTrue(tap(app, startingWith: "Profile and Settings"), "Profile toolbar button not found.")

        // Keychain persists across runs on the same simulator, so a prior
        // successful run leaves Snorlax already signed in here - only run
        // the sign-in flow if the signed-out entry point is present.
        if tap(app, startingWith: "Sign in to your AppleVis account", timeout: 6) {
            let usernameField = app.textFields["Username or email address"]
            XCTAssertTrue(usernameField.waitForExistence(timeout: 10), "Sign In sheet did not appear.")
            usernameField.tap()
            usernameField.typeText(username)

            let passwordField = app.secureTextFields["Password"]
            XCTAssertTrue(passwordField.exists)
            passwordField.tap()
            passwordField.typeText(password)

            XCTAssertTrue(tap(app, startingWith: "Sign In"), "Sign In submit button not found.")

            // Sign-in makes two network round trips after the login call
            // itself (resolveUuid, then resolveRoles) before the sheet
            // dismisses - give it real time on a live network.
            let cancelButton = app.buttons["Cancel"]
            let signedInWait = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: cancelButton)
            wait(for: [signedInWait], timeout: 25)

            if app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "sign in")).firstMatch.exists
                || app.textFields["Username or email address"].exists {
                let errorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "sign in")).firstMatch.label
                XCTFail("Sign-in did not complete - still on the Sign In sheet after 25s. Error text: \(errorText)")
                return
            }
        }

        // Force a genuinely fresh sign-in (not a Keychain-restored session)
        // so resolveUuid() actually runs - AuthStore.refreshRoles() only
        // re-fetches roles for an *already-known* uuid and never retries
        // uuid resolution itself, so a prior failed resolveUuid() can never
        // self-heal on relaunch/foreground alone.
        if tap(app, startingWith: "Sign Out", timeout: 6) {
            _ = tap(app, startingWith: "Sign Out", timeout: 6) // confirmation dialog's destructive button
            XCTAssertTrue(tap(app, startingWith: "Sign in to your AppleVis account", timeout: 10), "Signed-out Profile entry point not found after Sign Out.")

            let usernameField = app.textFields["Username or email address"]
            XCTAssertTrue(usernameField.waitForExistence(timeout: 10), "Sign In sheet did not appear after sign-out.")
            usernameField.tap()
            usernameField.typeText(username)

            let passwordField = app.secureTextFields["Password"]
            passwordField.tap()
            passwordField.typeText(password)

            XCTAssertTrue(tap(app, startingWith: "Sign In"), "Sign In submit button not found on fresh sign-in.")

            let cancelButton = app.buttons["Cancel"]
            let signedInWait = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: cancelButton)
            wait(for: [signedInWait], timeout: 25)
        }

        // Direct read of Sources/Views/Profile/ProfileView.swift:98's combined
        // accessibility label - it appends ", Administrator" iff
        // AuthUser.isAdmin is true. This is the ground truth for whether the
        // app resolved Snorlax's roles into an editor/admin state at all,
        // independent of any specific screen's button wiring.
        let statusElement = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Signed in as"))
            .firstMatch
        XCTAssertTrue(statusElement.waitForExistence(timeout: 10), "Could not find the \"Signed in as ...\" status row on Profile - sign-in state unclear.")
        let statusLabel = statusElement.label
        print("=== PROFILE STATUS LABEL: \(statusLabel) ===")

        XCTAssertTrue(
            statusLabel.contains("Administrator"),
            "AuthUser.isAdmin is FALSE for Snorlax: Profile shows \"\(statusLabel)\" (no \", Administrator\" suffix). " +
            "Per Sources/Models/User.swift, isAdmin requires roles to contain \"site_editor\" or \"site_admin\" - " +
            "either the account lacks that server-side role, or AccountEndpoints.resolveRoles silently failed " +
            "(see the do/catch in AccountEndpoints.signIn that swallows resolveUuid/resolveRoles errors, " +
            "logged only to AppLog.auth which this test cannot see)."
        )

        // Secondary, screen-level confirmation: with isAdmin true, the
        // per-topic "Topic actions" menu should also be unlocked in practice.
        // Switching tabs works regardless of whether Profile is still pushed
        // on Home's own navigation stack - no need to pop it first.
        XCTAssertTrue(app.tabBars.buttons["Discover"].waitForExistence(timeout: 10))
        // The sign-in toast/animation can still be settling right after the
        // credential check above, which occasionally swallows this first
        // tap - retry a couple of times rather than fail outright on it.
        for _ in 0..<3 where app.tabBars.buttons["Home"].isSelected {
            app.tabBars.buttons["Discover"].tap()
            Thread.sleep(forTimeInterval: 1)
        }

        if !tap(app, startingWith: "Forums", timeout: 15) {
            print("=== DISCOVER SCREEN DUMP ===\n\(app.debugDescription)\n=== END DUMP ===")
            XCTFail("Forums hub card not found on Discover.")
            return
        }

        let topicRow = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "comment")).firstMatch
        XCTAssertTrue(topicRow.waitForExistence(timeout: 20), "No forum topic row found to open.")
        topicRow.tap()

        let topicActions = app.buttons["Topic actions"]
        var foundTopicActions = topicActions.waitForExistence(timeout: 8)
        if !foundTopicActions && app.navigationBars["Forums"].exists {
            // First tap sometimes only highlights the row (state Selected)
            // without the NavigationLink push completing - retry once.
            topicRow.tap()
            foundTopicActions = topicActions.waitForExistence(timeout: 12)
        }
        if !foundTopicActions {
            print("=== POST-TAP SCREEN DUMP ===\n\(app.debugDescription)\n=== END DUMP ===")
        }
        XCTAssertTrue(foundTopicActions, "\"Topic actions\" menu did not appear on the topic detail screen for Snorlax.")

        guard foundTopicActions else { return }
        topicActions.tap()

        XCTAssertTrue(app.buttons["Edit Topic"].waitForExistence(timeout: 5), "Edit Topic missing from admin Topic actions menu.")
        XCTAssertTrue(app.buttons["Unpublish Topic"].exists, "Unpublish Topic missing from admin Topic actions menu.")
        XCTAssertTrue(app.buttons["Delete Topic"].exists, "Delete Topic missing from admin Topic actions menu.")
    }
}
