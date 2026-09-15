import SwiftUI

struct WhatsNewView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    /// Had no focus management at all. Full app-wide focus audit,
    /// requested directly.
    @AccessibilityFocusState private var isHeaderFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                versionHeader
                    .padding()
                    .accessibilityFocused($isHeaderFocused)

                ForEach(ChangeItem.current) { item in
                    ChangeCard(item: item)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }

                ForEach(HistorySection.all) { section in
                    HistorySectionView(section: section)
                        .padding(.bottom, 4)
                }

                Color.clear.frame(height: 40)
            }
        }
        .background(preferences.colors.background)
        .navigationTitle("What's New")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isHeaderFocused) }
    }

    private var versionHeader: some View {
        VStack(spacing: 8) {
            Text("Version \(ChangeItem.currentVersion)")
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
                .accessibilityHidden(true)

            Text("This release is just getting started. Fixes and improvements will appear here as they land.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "What's new in AppleVis version \(ChangeItem.currentVersion)"))
    }
}

// MARK: - Change card

private struct ChangeCard: View {
    let item: ChangeItem

    // `item.title`/`item.description` are String values, not string
    // literals — Text(_ content: String) treats a String argument as
    // already-resolved display text and skips catalog lookup entirely, so
    // every What's New entry (this release and every History section) was
    // silently never being translated, catalog entries or not. Same fix as
    // OnboardingHeader in OnboardingView.swift for the identical problem.
    private var localizedTitle: String { String(localized: String.LocalizationValue(item.title)) }
    private var localizedDescription: String { String(localized: String.LocalizationValue(item.description)) }
    private var localizedTag: String { String(localized: String.LocalizationValue(item.tag.rawValue)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(LocalizedStringKey(item.title))
                            .font(.body).fontWeight(.bold)
                        TagBadge(tag: item.tag)
                    }
                    Text(LocalizedStringKey(item.description))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(localizedTag): \(localizedTitle). \(localizedDescription)"))
    }
}

// MARK: - Tag badge

private struct TagBadge: View {
    let tag: ChangeTag

    var body: some View {
        Text(LocalizedStringKey(tag.rawValue))
            .font(.caption2).fontWeight(.bold)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(tag.foregroundColor)
            .background(tag.backgroundColor, in: RoundedRectangle(cornerRadius: 6))
            .accessibilityHidden(true)
    }
}

// MARK: - History section

private struct HistorySectionView: View {
    let section: HistorySection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey(section.title))
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)

            ForEach(section.items) { item in
                ChangeCard(item: item)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: String.LocalizationValue(section.title)))
    }
}

// MARK: - Data

enum ChangeTag: String {
    case new = "New"
    case improved = "Improved"
    case fixed = "Fixed"

    var backgroundColor: Color {
        switch self {
        case .new:      return Color(red: 0.93, green: 0.99, blue: 0.96)
        case .improved: return Color(red: 0.94, green: 0.96, blue: 1.0)
        case .fixed:    return Color(red: 1.0, green: 0.97, blue: 0.93)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .new:      return Color(red: 0.02, green: 0.37, blue: 0.27)
        case .improved: return Color(red: 0.11, green: 0.30, blue: 0.85)
        case .fixed:    return Color(red: 0.60, green: 0.20, blue: 0.07)
        }
    }
}

struct ChangeItem: Identifiable {
    let id = UUID()
    let systemImage: String
    let tag: ChangeTag
    let title: String
    let description: String

    static let currentVersion = "2026.14"

    static let current: [ChangeItem] = [
        ChangeItem(
            systemImage: "sparkles",
            tag: .improved,
            title: "A Few Small Visual Touches",
            description: "For sighted and low-vision users: the Save, Follow, and Recommend icons give a small bounce the moment you tap them, switching themes now crossfades between color schemes instead of snapping instantly, and \"NEW\" badges pop in with a little spring as you scroll to them instead of just appearing flat. Purely visual — nothing changes for VoiceOver, Switch Control, or braille, and all of it turns off automatically under Reduce Motion."
        ),
        ChangeItem(
            systemImage: "wrench.and.screwdriver",
            tag: .improved,
            title: "A Tidier About Screen",
            description: "About had grown ten-plus flat rows of device and accessibility info before anyone had asked for it, on top of a Report a Bug/Send Feedback pair that just duplicated Contact AppleVis, already reachable from Profile and Discover. Device details, accessibility status, and Copy Support Info now live behind a single Diagnostic Info button, the redundant duplicate contact buttons are gone, and the confusing \"Type: iPhone\" row (identical to the Device row above it) is gone too — the device's raw hardware identifier now sits next to its name instead of floating on its own. Discover's social media links also now share the same list as About's, instead of a second, independently-maintained copy that had already drifted out of sync."
        ),
        ChangeItem(
            systemImage: "text.badge.checkmark",
            tag: .new,
            title: "Filter the Language You See",
            description: "AppleVis has always blocked strong or explicit language from anything posted through the app — that never changes. New: Settings > Privacy (and a new setup step) can now also mask milder language, which the site otherwise allows, so it shows up as \"s***\" instead of spelled out. On by default, to help AppleVis stay welcoming and stay within Apple's guidelines for our age rating — turn it off anytime if you'd rather see everything exactly as written."
        ),
        ChangeItem(
            systemImage: "flag",
            tag: .new,
            title: "Report a Topic, Entry, or Episode Itself",
            description: "Report has always worked on individual comments and replies, but not on the thing they're replying to — a forum topic's original post, or an app, blog, guide, bug report, or episode entry had no way to flag. Every detail screen's actions menu (top-right corner) now offers Report there too, alongside the existing Save/Follow/Share options."
        ),
        ChangeItem(
            systemImage: "bell.badge",
            tag: .improved,
            title: "A Clearer Choice for What's New on Home",
            description: "Setup used to ask whether to remember your reading history — but that mixed up two separate things: AppleVis always needs to track what you've read for All/New/Recap to work, which is harmless and never leaves your device while signed out, so there was never a good reason to turn it off. What actually varies is whether you want to see it. Setup and Settings > Privacy now ask that directly instead — a New view, a quick summary, and small new-activity badges — and it now applies the same way whether you're signed in or out, not just for guests."
        ),
        ChangeItem(
            systemImage: "exclamationmark.bubble",
            tag: .fixed,
            title: "Posting a Comment, Reply, or Review Works Again",
            description: "Something changed recently on AppleVis's own side that broke posting any new comment, forum reply, app review, or bug report comment from the app — along with creating a new forum topic or submitting a new app, blog post, or podcast. Found and fixed: a text format the app used for every new post stopped being valid on the site, and a couple of fields the site now requires weren't being sent. If posting anything felt broken recently, this is why — it's fixed now."
        ),
        ChangeItem(
            systemImage: "arrowshape.turn.up.left",
            tag: .new,
            title: "Reply to a Specific Comment, For Real This Time",
            description: "AppleVis's website just added its own way to reply to one specific comment instead of the whole thread — a genuine link back to that comment, not just quoted text pasted in. Reply to this Comment in the app now uses that same real connection, so a reply made in the app or on the website shows up correctly in both places, with a Replying to [name] link above it that jumps straight to the original."
        ),
        ChangeItem(
            systemImage: "bell.badge",
            tag: .fixed,
            title: "Follow Syncs With the Website Everywhere, Not Just in For You",
            description: "For You > Following already reflected topics, apps, and episodes followed on the website — but the Follow/Unfollow button on an individual page, and Home's bell badge on forum topic cards, only ever checked what was followed inside this app itself. Follow something on the website (or a second signed-in device) and both now catch up correctly, the same way Recommend's button state already did."
        ),
        ChangeItem(
            systemImage: "map",
            tag: .improved,
            title: "The Welcome Tour Got a Lot Bigger",
            description: "Beta feedback said the Welcome Tour felt too high-level, so it's been rebuilt from a flat set of steps into six chapters — Welcome, Home, Discover, For You, Profile & Settings, and a closing chapter — each covering real depth instead of a single sentence per tab, in wording that works whether you use VoiceOver or not. Home, Discover, and For You each end with a checkpoint offering a chance to explore that screen for real or pause the tour and pick it up again later. Finish the whole thing and you'll get a little confetti to mark it, turned off automatically under Reduce Motion — and you can replay the tour anytime from Profile."
        ),
        ChangeItem(
            systemImage: "party.popper.fill",
            tag: .new,
            title: "A Little Celebration When You Finish",
            description: "Contact Us, Submit Bug Report, Submit Blog, Submit an App, Submit a Podcast, Report a Comment, and Change Password/Email now give their thank-you screen's icon a small bounce on the way in. Submitting a new app to the directory, and reaching You're All Set at the end of setup, go a little further with a brief burst of confetti — genuine milestones, not just routine completions. All of it is purely decorative: nothing changes for VoiceOver, and Reduce Motion turns it off automatically."
        ),
        ChangeItem(
            systemImage: "bell.badge",
            tag: .fixed,
            title: "Follow (and Recommend) Actually Works Now",
            description: "A beta tester and some careful follow-up testing (thank you both) turned up a real bug: tapping Follow on a topic — anywhere in the app — failed with \"You don't have permission to do that.\" It wasn't a permissions problem at all: the request that creates a follow was missing a piece of information the server requires, and it silently accepted the request anyway before failing deep inside itself. Fixed for Follow across every content type, and Recommend This App, which shared the exact same gap."
        ),
        ChangeItem(
            systemImage: "hand.point.left",
            tag: .fixed,
            title: "A Saved-List Tip That Actually Matches What You Saved",
            description: "Another beta-tester catch: saving a forum topic used to trigger a one-time tip titled \"Faster Episode Actions,\" describing swipe-to-delete and mark-as-played — neither of which exists on a saved topic. The tip now matches whatever you actually saved, and VoiceOver users get an accurate version pointing to the Actions rotor instead of a swipe-left instruction that, under VoiceOver, just moves focus to the previous item rather than doing anything useful."
        ),
        ChangeItem(
            systemImage: "bookmark",
            tag: .fixed,
            title: "A Clearer Nudge for Saving Your First Item",
            description: "The empty For You > Saved screen used to say \"Tap the bookmark icon on any item to save it\" — a beta tester pointed out that VoiceOver never actually says the word \"bookmark\" anywhere in the app, since every Save button and menu item is labeled Save. It now says to save a topic, app, guide, blog post, or episode, matching what every Save control is actually called for every user."
        ),
        ChangeItem(
            systemImage: "globe",
            tag: .fixed,
            title: "Onboarding and What's New Now Actually Translate",
            description: "Every onboarding step's heading and description, and every What's New entry — this release and all of history — were being built from a code pattern that silently skipped the translation catalog, so non-English speakers saw English text there no matter how many translations already existed. Both are fixed, and the onboarding strings that had never been translatable in the first place are now translated into all 22 supported languages."
        ),
        ChangeItem(
            systemImage: "text.line.first.and.arrowtriangle.forward",
            tag: .improved,
            title: "Fewer Swipes on Minimum-Length Fields",
            description: "Description, Message, Blog Post Draft, Episode Description, and Accessibility Comments — every field with a character minimum — now combine their label and live counter into a single VoiceOver stop instead of two, and no longer repeat the same requirement a third time in a separate caption below the field."
        ),
        ChangeItem(
            systemImage: "lock.shield",
            tag: .improved,
            title: "Stronger Password Requirements, With a Nudge",
            description: "Changing your AppleVis password now requires at least 8 characters, one number, and one special character — stated right in the field's own label instead of a separate warning line that only appeared after typing too little. A new strength meter (Weak to Very Strong) offers a nudge toward an even harder-to-guess password, but meeting the minimum is still all that's required."
        ),
        ChangeItem(
            systemImage: "arrow.down.to.line",
            tag: .new,
            title: "A Way Forward at the Bottom of Every Step",
            description: "Contact Us, Submit Bug Report, Submit Blog, Submit an App, Submit a Podcast, Report a Comment, and Change Password/Email now have a Next/Submit button at the bottom of every step, matching setup's wizard — not just the top-right corner. A beta tester's own experience prompted this: swiping to the end of a list of choices, as VoiceOver naturally does, used to land on nothing actionable. When a step isn't ready to continue, a short note now explains exactly what's still needed — a specific field, a minimum length, an unchecked box — instead of a silently disabled button."
        ),
        ChangeItem(
            systemImage: "text.below.photo",
            tag: .improved,
            title: "Every Wizard Step Now Explains Itself",
            description: "Contact Us, Submit Bug Report, Submit Blog, Submit an App, Submit a Podcast, and Change Password/Email now show a short description under every step's heading — matching setup's wizard — so VoiceOver users hear what a step wants before reaching its fields. The Sign In Required screen on every Submit wizard, and Submit App's Before You Begin screen, now properly focus their heading too, instead of leaving VoiceOver wherever it last was."
        ),
        ChangeItem(
            systemImage: "envelope.arrow.triangle.branch",
            tag: .new,
            title: "An Easy Way to Update Your Account Email",
            description: "If you're signed in and send a message from a different address than your account email — Contact Us, Submit Bug Report, Submit Blog, or Report a Comment — the thank-you screen now offers a dismissible, opt-in way to update your account email to match. It's only ever a suggestion: dismissing it does nothing, and updating still requires confirming your current password, same as Change Email Address always has."
        ),
        ChangeItem(
            systemImage: "network.badge.shield.half.filled",
            tag: .new,
            title: "A Heads-Up for Made-Up Email Domains",
            description: "Contact Us, Submit Bug Report, Submit Blog, Report a Comment, and Change Email Address now quietly check whether the domain you typed (the part after the @) actually exists on the internet, and show a gentle \"check for a typo?\" note if it doesn't — entirely on-device, nothing about your address is sent anywhere to check it. It's a hint, not a lock: a slow or unusual network never blocks Send, and it can't confirm a specific inbox exists, only that the domain itself is real."
        ),
        ChangeItem(
            systemImage: "envelope.badge.person.crop",
            tag: .new,
            title: "Less Retyping Your Email in Wizards",
            description: "Contact Us, Submit Bug Report, Submit Blog, and Report a Comment now fill in your email automatically when you're signed in, using your account's email instead of asking you to type it again. If you're signed out, your last-typed email is remembered locally on this device for next time. All four also now check for a properly formatted address before letting you continue."
        ),
        ChangeItem(
            systemImage: "waveform.badge.plus",
            tag: .new,
            title: "Clearer Sound Previews for VoiceOver",
            description: "Double-tapping a notification sound to select it also played a preview right away, but VoiceOver's own selection announcement could talk over the clip because of audio ducking, making it hard to actually hear. A new Preview action, in the rotor's Actions category, is now available on both the setup sound picker and Settings > Notifications — it plays the sound on its own, without changing the selection or triggering that announcement."
        ),
        ChangeItem(
            systemImage: "apps.iphone",
            tag: .new,
            title: "Apple Topics or Everything?",
            description: "Setup now asks whether Home and Forums should focus on Apple only or also include other tech topics, like Windows, Android, and assistive technology discussions. Apple-only is the new default — change it from this new setup step, Customize Home, or Settings > Home Feed anytime."
        ),
        ChangeItem(
            systemImage: "checklist",
            tag: .fixed,
            title: "No More Skipped Setup Step",
            description: "Signing in during setup used to silently skip the Reading History step, jumping straight from \"Step 2\" to \"Step 4\" — a gap a beta tester found confusing for VoiceOver users, since the step count had already promised more steps than they got. Every setup step now shows for everyone; ones that only fully apply in certain situations, like Reading History if you ever sign out or VoiceOver Detail Level if you turn VoiceOver on later, explain themselves accordingly instead of disappearing."
        ),
        ChangeItem(
            systemImage: "person.crop.circle",
            tag: .fixed,
            title: "Sign In Focuses Properly During Setup",
            description: "The Sign In step of setup used to send VoiceOver focus straight to the Username field, skipping past the step's own heading and explanation entirely. It now focuses the heading first, like every other setup step."
        ),
        ChangeItem(
            systemImage: "arrow.triangle.2.circlepath",
            tag: .improved,
            title: "A Smarter Refresh for App Details",
            description: "Editors refreshing an app entry from its App Store listing now see exactly what changed — title, description, App Store link, and version — and can leave off anything they don't want touched. Anything that already matches the App Store listing is shown as already matching, instead of being overwritten every time."
        ),
        ChangeItem(
            systemImage: "ellipsis.circle",
            tag: .new,
            title: "A Consistent Actions Menu, Everywhere",
            description: "Every detail page — App Entry, Episode, Blog Post, Guide, and Bug Report, alongside Forum Topic's existing one — now has its own actions menu in the top-right corner, offering a second way to Save, Follow, Comment, Share, and open in your browser. The person who originally posted something can also edit or delete it from there, and editors get the same options plus Unpublish."
        ),
        ChangeItem(
            systemImage: "text.bubble",
            tag: .fixed,
            title: "Consistent Wording on App Entry Pages",
            description: "The line under an app's title used to say \"last reviewed,\" while everywhere else on the same page — the Community Discussion heading, Load More Comments, the Thread overview — already said \"comment.\" It now says \"most recent comment\" too."
        ),
        ChangeItem(
            systemImage: "sparkles",
            tag: .improved,
            title: "A Tidier Mouse Recap",
            description: "Mouse Recap dropped \"In This Recap,\" which just repeated the same counts already in the greeting above it, and every section (Spotlight Feature, New Accessible Apps, Podcasts, Blog, and more) is now a real heading you can jump straight to with VoiceOver's Headings rotor. New app blurbs also stop re-announcing \"In this new app...\" for every single one — something the section header and its intro sentence already say once."
        ),
        ChangeItem(
            systemImage: "text.quote",
            tag: .fixed,
            title: "Read Transcript Works More Reliably",
            description: "Some episodes showed a Read Transcript button that led to \"This item is no longer available\" instead of the actual transcript. It now only appears when there's really a transcript to show, loads it instantly instead of a failed network check first, and returns VoiceOver focus to the button you tapped instead of the top of the page when you're done reading."
        ),
        ChangeItem(
            systemImage: "checkmark.circle",
            tag: .improved,
            title: "Mark as Listened, Not Read",
            description: "Episode Tools now says Mark Listened / Listened instead of the ambiguous Mark Played / Played, and you can tap it again to undo — previously there was no way back once marked, whether by mistake or from iCloud sync. Marking an episode listened also clears its saved resume point, so it won't offer to pick back up partway through something you just said you were done with."
        ),
        ChangeItem(
            systemImage: "hand.draw",
            tag: .fixed,
            title: "Swipeable Pickers Announce What You Picked",
            description: "Swiping up or down on a picker — For You's section switcher, Home Feed, App Directory's platform filter, and every swipeable setting in Podcasts, Notifications, Storage, and Appearance — previously played only a plain \"value changed\" sound with nothing spoken. VoiceOver now announces the actual selection, like \"Following\" or \"1.5 times,\" every time."
        ),
        ChangeItem(
            systemImage: "scope",
            tag: .fixed,
            title: "Discover Focus Fixed After Switching Tabs",
            description: "Switching away from Discover while inside a section like Podcasts, then switching back without going all the way out first, used to yank VoiceOver focus up to the Discover heading instead of leaving it where you actually were. It now only refocuses the heading when you're really back at the Discover hub."
        ),
        ChangeItem(
            systemImage: "ladybug",
            tag: .improved,
            title: "More Useful Bug Reports",
            description: "Contact Us's \"Include app and device info\" toggle for bug reports used to append only your app version and iOS version. It now includes everything About > Support already offers — device model, build number, theme, locale, every accessibility setting like VoiceOver, Reduce Motion, and Dynamic Type, and whether you were signed in and with which role — since so many real bugs turn out to be specific to an assistive technology being on or off, or to being signed out or on a member vs. editor account."
        ),
        ChangeItem(
            systemImage: "text.badge.checkmark",
            tag: .fixed,
            title: "New Comment Count Announced in the Right Place",
            description: "On Forum, Podcast, App, Guide, Blog Post, and Bug Report cards, VoiceOver used to announce \"N new comments\" dead last — after the comment count, the date, and any Saved/Following status — making it easy to lose track of which number it belonged to. It's now spoken right next to the comment count it's describing, with the date and status following after."
        ),
    ]

}

struct HistorySection: Identifiable {
    let id = UUID()
    let title: String
    let items: [ChangeItem]

    static let all: [HistorySection] = [
        HistorySection(title: "Also in 2026.13", items: [
        ChangeItem(
            systemImage: "wifi.slash",
            tag: .new,
            title: "Friendlier Offline Messages",
            description: "AppleVis now lets you know, in plain and friendly language, when you're offline — in Following and Recommended (For You), in search, and before you try to send a message. Contact Us and every Submit wizard now gently hold the Send/Submit button until you're back online, so nothing gets lost typing into thin air."
        ),
        ChangeItem(
            systemImage: "heart.text.square",
            tag: .improved,
            title: "Warmer Wording in Contact Us",
            description: "The declaration you check before sending a message now sounds like us — a genuine confirmation instead of a stiff \"I understand that AppleVis does not accept…\" disclaimer."
        ),
        ChangeItem(
            systemImage: "arrow.right.circle",
            tag: .improved,
            title: "Clearer Navigation in Contact Us",
            description: "The message step's Next button no longer reads \"Continue to Review\" — it's Next everywhere now, like every other wizard in the app. The redundant Change button next to your message type is also gone for signed-in users, since Back already takes you straight there; guests still see it, since it skips a step."
        ),
        ChangeItem(
            systemImage: "wand.and.stars",
            tag: .improved,
            title: "Rewrite Buttons Moved Out of the Overflow Menu",
            description: "Contact Us, Submit a Bug Report, Submit a Podcast, and the forum's New Topic/Reply screens now show their Apple Intelligence Rewrite button directly under the text field it rewrites, instead of hidden behind the toolbar's overflow \"More\" button — matching Submit App and Submit Blog."
        ),
        ChangeItem(
            systemImage: "questionmark.circle",
            tag: .improved,
            title: "General Enquiries in Contact Us",
            description: "The fourth message type in the Contact Us wizard is now General Enquiry — for questions and concerns — instead of Recommendation, which overlapped with the dedicated Submit App/Blog/Podcast wizards."
        ),
        ChangeItem(
            systemImage: "person.crop.circle",
            tag: .improved,
            title: "A Shorter Profile Screen",
            description: "Your profile card now opens a dedicated My Account screen for editing your profile, password, email, and signing out — so the main Profile tab is a quick, three-stop list instead of a long one."
        ),
        ChangeItem(
            systemImage: "text.bubble",
            tag: .improved,
            title: "Clearer Guidance on Submission Forms",
            description: "Fields like a bug report's description or an app's accessibility comments now explain what actually makes a helpful answer, instead of just a character minimum."
        ),
        ChangeItem(
            systemImage: "xmark.circle",
            tag: .fixed,
            title: "Cancel Works From Any Step",
            description: "Submitting a blog post, bug report, app, podcast, contact message, comment report, or changing your password/email now lets you cancel out from any step, not just the first."
        ),
        ChangeItem(
            systemImage: "heart.text.square",
            tag: .improved,
            title: "Warmer Thank-You Messages",
            description: "The confirmation screen after submitting a blog post, bug report, app, podcast, or contact message now sounds like us — genuine thanks, not just a status update."
        ),
        ChangeItem(
            systemImage: "flag",
            tag: .new,
            title: "Report a Comment",
            description: "See something that shouldn't be there? Report any comment or reply with a quick, guided form — it goes straight to the editorial team."
        ),
        ChangeItem(
            systemImage: "hand.tap.fill",
            tag: .new,
            title: "Haptic Feedback",
            description: "AppleVis can now vibrate for the same moments it plays a sound for — saving, signing in, errors, and more. Turn it on or off in Settings > Sounds & Haptics."
        ),
        ChangeItem(
            systemImage: "app.badge",
            tag: .improved,
            title: "Refreshed App Icon and Launch Screen",
            description: "AppleVis now opens with its own mark front and center, matching the icon on your Home Screen."
        ),
        ChangeItem(
            systemImage: "hand.wave",
            tag: .improved,
            title: "A Warmer Home Greeting",
            description: "Home now greets you whether or not you're signed in, with a friendly welcome back for returning visitors."
        ),
        ChangeItem(
            systemImage: "checkmark.shield",
            tag: .fixed,
            title: "Contact and Report Forms Submit More Reliably",
            description: "Messages sent through Contact AppleVis, bug reports, feedback, and suggestions from a signed-in account now go through correctly every time."
        ),
        ChangeItem(
            systemImage: "person.crop.circle",
            tag: .improved,
            title: "Simpler Profile",
            description: "Profile no longer duplicates Saved Items — view and manage everything you've saved from For You."
        ),
        ChangeItem(
            systemImage: "person.text.rectangle",
            tag: .improved,
            title: "Warmer Member Profiles",
            description: "Profiles now show a colorful avatar, your interests, Apple products you use, and your social links, styled to match the rest of the app."
        ),
        ChangeItem(
            systemImage: "envelope",
            tag: .new,
            title: "Message Other Members Privately",
            description: "Send a private message to another AppleVis member from their profile. Your email address stays hidden unless they choose to reply."
        ),
        ChangeItem(
            systemImage: "hand.thumbsup.fill",
            tag: .new,
            title: "Recommend Apps You Love",
            description: "Recommend an app from its App Directory page, an app card's swipe actions, or the long-press menu. See everything you've recommended in For You."
        ),
        ChangeItem(
            systemImage: "lock.rotation",
            tag: .new,
            title: "Change Your Password or Email in the App",
            description: "A short, guided flow lets you update your account password or email address without leaving AppleVis or visiting the website."
        ),
        ChangeItem(
            systemImage: "sparkles",
            tag: .new,
            title: "Help Writing Your Bio",
            description: "Not sure what to write? Answer a couple of quick questions and get a friendly draft bio you can edit or use as-is."
        ),
        ChangeItem(
            systemImage: "globe",
            tag: .improved,
            title: "Easier Location and Time Zone",
            description: "Location is now a simple country picker instead of free text, and Time Zone can be set in one tap using your device's own time zone."
        ),
        ChangeItem(
            systemImage: "apple.logo",
            tag: .new,
            title: "Apple Products Owned",
            description: "Add the Apple devices you use to your profile with a simple checklist, shown to other members on your profile."
        ),
        ChangeItem(
            systemImage: "hand.raised",
            tag: .new,
            title: "Control Who Can Contact You",
            description: "A new Profile setting lets you turn off private messages from other members at any time."
        ),
        ChangeItem(
            systemImage: "party.popper.fill",
            tag: .new,
            title: "Account Anniversary Celebration",
            description: "AppleVis now marks your join-date anniversary with a little confetti, a friendly message, and an option to share the moment."
        ),
        ChangeItem(
            systemImage: "bell",
            tag: .fixed,
            title: "Following Now Shows Everything You Follow",
            description: "The Following tab previously only showed items followed from inside the app. It now shows your complete list, including anything followed on the website."
        ),
        ChangeItem(
            systemImage: "at",
            tag: .fixed,
            title: "Mastodon Handle Now Saves Correctly",
            description: "Your Mastodon handle previously failed to save due to a naming mismatch behind the scenes. It now saves and loads correctly."
        ),
        ChangeItem(
            systemImage: "house",
            tag: .fixed,
            title: "Smoother Home Tab for VoiceOver",
            description: "Home no longer announces its own name twice when swiping through the screen."
        ),
        ChangeItem(
            systemImage: "person.badge.shield.checkmark",
            tag: .improved,
            title: "Editor Permissions Stay Up To Date",
            description: "If your AppleVis role changes, the app now notices automatically instead of requiring a full sign-out and sign-in."
        ),
        ChangeItem(
            systemImage: "mic",
            tag: .new,
            title: "Two New Siri Shortcuts",
            description: "Ask Siri \"What's new on AppleVis\" for a spoken catch-up, or \"Report a bug to AppleVis\" to open straight to the bug report form."
        ),
        ChangeItem(
            systemImage: "arrow.uturn.backward",
            tag: .improved,
            title: "Home Picks Up Where You Left Off",
            description: "When there's nothing new to catch up on, Home now returns VoiceOver focus to the last item you visited instead of starting over at the greeting."
        ),
        ChangeItem(
            systemImage: "slider.horizontal.3",
            tag: .new,
            title: "New General Settings",
            description: "AppleVis Tips, Home Startup Behavior, Welcome Summary, Auto-Focus Search Field, and Web Links now live together in a new Settings > General screen."
        ),
        ChangeItem(
            systemImage: "sparkles",
            tag: .fixed,
            title: "Welcome Summary Setting Actually Works Now",
            description: "The Welcome Summary toggle in Settings previously did nothing. It now correctly controls whether Home shows its new-activity card."
        ),
        ChangeItem(
            systemImage: "bubble.left.and.bubble.right",
            tag: .improved,
            title: "Clearer Home Feed Settings",
            description: "The Forums settings screen is now called Home Feed, with clearer wording distinguishing its forum-topic filter from Home's own All/New/Mouse Recap switcher."
        ),
        ChangeItem(
            systemImage: "hand.draw",
            tag: .improved,
            title: "Swipe to Adjust More Settings",
            description: "Podcast, Notification, and Storage settings, and the Episode Detail equalizer, now support swiping up or down to change the value, in addition to double-tapping to choose from the list."
        ),
        ChangeItem(
            systemImage: "hand.raised",
            tag: .fixed,
            title: "Correct Privacy Policy Link",
            description: "The Privacy Policy link in Settings pointed to a page that no longer exists. It now opens the real page."
        ),
        ChangeItem(
            systemImage: "internaldrive",
            tag: .fixed,
            title: "Storage & Cache VoiceOver Fixes",
            description: "Storage rows no longer read twice, a silent stop between Cached Content and Total is gone, and the Downloaded Episodes/Cached Content color coding works again."
        ),
        ChangeItem(
            systemImage: "icloud",
            tag: .fixed,
            title: "Accurate iCloud \"Last Synced\" Time",
            description: "Last Synced in Settings > Saved & Sync previously only updated when you tapped Sync Now. It now reflects sync that happens automatically in the background too."
        ),
        ChangeItem(
            systemImage: "info.circle",
            tag: .improved,
            title: "Streamlined Profile Legal Links",
            description: "Privacy Policy and Terms of Service no longer appear twice in Profile — they're one tap away in About & Credits."
        ),
        ChangeItem(
            systemImage: "bookmark.slash",
            tag: .improved,
            title: "Faster Access to Bulk Actions in For You",
            description: "Unsave All and Remove All Downloads are now reachable as VoiceOver actions right on the summary at the top of the list, not just as a button after every item."
        ),
        ChangeItem(
            systemImage: "list.bullet",
            tag: .improved,
            title: "For You Section Picker Shows Counts",
            description: "The Saved/Following/Recommended/Queue/Downloads picker in For You now shows how many items are in each section."
        ),
        ChangeItem(
            systemImage: "arrow.left.circle",
            tag: .fixed,
            title: "Back Button Returns VoiceOver Focus",
            description: "Coming back from a Settings, Profile, Discover, or About screen now lands VoiceOver focus on the row you tapped, instead of somewhere unrelated."
        ),
        ChangeItem(
            systemImage: "arrow.down.to.line",
            tag: .fixed,
            title: "\"Jump to First New Comment\" Lands in the Right Place",
            description: "On a long thread, review list, or comment section, jumping to the newest or first new comment could land VoiceOver focus on the wrong entry instead of the actual new one. It now reliably lands on the right comment every time."
        ),
        ChangeItem(
            systemImage: "square.and.arrow.up",
            tag: .improved,
            title: "Clearer Confirmation When Sharing to AppleVis",
            description: "Sharing an app, podcast, or article to AppleVis from another app (like the App Store) now shows a quick confirmation if that app doesn't switch to AppleVis automatically, instead of appearing to do nothing. Either way, your share is waiting the next time you open AppleVis."
        ),
        ChangeItem(
            systemImage: "list.bullet.rectangle",
            tag: .fixed,
            title: "Mouse Recap's Table of Contents, Simplified",
            description: "\"In This Recap\" was a numbered list where each entry took three separate swipes (the number, the title, then the count), for a number that was never a meaningful order. It's now a single plain-language sentence, like \"This recap covers 1 new accessible app and 2 blog posts.\""
        ),
        ChangeItem(
            systemImage: "text.badge.checkmark",
            tag: .improved,
            title: "Jump Straight to a Mouse Recap Section",
            description: "Mouse Recap's section titles (New Accessible Apps, Community Voices, and the rest) are now real VoiceOver headings, so the Headings rotor jumps straight to one instead of swiping through everything ahead of it. Each card's repeated section label (like \"Popular Discussion\" on every discussion) no longer reads out again for every single item."
        ),
        ChangeItem(
            systemImage: "flame",
            tag: .improved,
            title: "Popular Discussions Reflect What's Actually Active",
            description: "Community Voices used to rank and describe topics by their all-time comment count, so a 130-comment topic with only 3 new replies this week could out-rank one that's genuinely buzzing right now. It's now ranked by comments posted within the recap window, and each card says how many of its comments are new (e.g. \"8 new in the past week\") alongside the lifetime total."
        ),
        ChangeItem(
            systemImage: "person.2",
            tag: .fixed,
            title: "Friends of AppleVis, Read Once",
            description: "Be My Eyes' row in Discover's Friends of AppleVis section said \"Friend of AppleVis\" a second time, right after the section header already said it. It's just the name and description now."
        ),
        ChangeItem(
            systemImage: "sun.max",
            tag: .new,
            title: "A Daily Welcome Back",
            description: "Signed in and opening AppleVis for the first time today? Home's greeting now adds a quiet \"Welcome back\" underneath, once per day — it won't repeat if you check back again later the same day."
        ),
        ChangeItem(
            systemImage: "hand.wave.fill",
            tag: .improved,
            title: "Home Always Greets You First",
            description: "Opening Home with new activity or a reading position to resume used to skip straight past the greeting. VoiceOver focus now always lands on the greeting first, with What's New announced right after — instead of two separate \"welcome\" messages competing with each other."
        ),
        ChangeItem(
            systemImage: "arrow.clockwise",
            tag: .fixed,
            title: "Pull to Refresh No Longer Repeats Itself",
            description: "Pulling to refresh Home and finding something new used to announce the summary, then say the exact same sentence again a moment later when focus landed on the What's New card. It's said once now."
        ),
        ChangeItem(
            systemImage: "scope",
            tag: .fixed,
            title: "VoiceOver Focus, Cleaned Up Across the App",
            description: "A full pass on where VoiceOver focus lands when a screen opens: the Now Playing screen, Forums, Write a Review, and several account screens (sign in, edit profile, delete account, member profiles, contact a member) now focus something meaningful instead of nothing. Every multi-step wizard (Submit App/Blog/Bug/Podcast, Contact, Change Password/Email, Report a Comment) now focuses its first step reliably and re-checks focus a few times after each Next/Back, instead of a single guess that could go silent on a slower moment. Podcast and Storage settings no longer jump straight to a control."
        ),
        ChangeItem(
            systemImage: "text.alignleft",
            tag: .improved,
            title: "Long Posts Now Read Paragraph by Paragraph",
            description: "Forum topics, replies, blog posts, bug reports, app descriptions, and podcast show notes previously read (or Braille-panned) as one long, undifferentiated block when there was no heading structure to break it up. Each paragraph is now its own stop, so you can pause, re-read, or skip to a specific one — reading everything continuously still works exactly the same as before."
        ),
        ChangeItem(
            systemImage: "text.quote",
            tag: .fixed,
            title: "Podcast Transcripts Show Up Again",
            description: "Recent episodes' Transcript button wasn't appearing, and the raw transcript text stayed mixed into the show notes instead of being pulled into its own section — recent AppleVis Extra episodes store their notes in a different format behind the scenes, which the app wasn't reading correctly. Transcripts are detected properly again."
        ),
        ChangeItem(
            systemImage: "square.and.arrow.up",
            tag: .new,
            title: "Share a Transcript",
            description: "The Transcript screen now has a Share action of its own, so you can send or quote the actual words instead of only a link back to the episode."
        ),
        ChangeItem(
            systemImage: "scope",
            tag: .improved,
            title: "More VoiceOver Focus Fixes",
            description: "Continuing the focus pass from the last update: About, What's New, Help, RSS Feeds, Credits, Social Media, Open Source Licences, the Transcript screen, Customize Home, editing a topic/post, and For You's Saved/Following/Recommended/Downloads sections all focus something meaningful on their first appearance now instead of leaving VoiceOver wherever it happened to land."
        ),
        ]),
        HistorySection(title: "Also in 2026.11", items: [
            ChangeItem(
                systemImage: "sparkles",
                tag: .new,
                title: "Mouse Recap on Home",
                description: "Home now includes Mouse Recap, a shareable summary of new accessible apps, podcast episodes, popular discussions, guides and tutorials, and blog posts from the past week or past month."
            ),
            ChangeItem(
                systemImage: "arrow.up.forward.app",
                tag: .new,
                title: "Clearer App Store Button on App Pages",
                description: "App pages now include a large Open in App Store button near the top. The button makes clear that downloads and purchases are handled by Apple, not inside AppleVis."
            ),
            ChangeItem(
                systemImage: "dot.radiowaves.left.and.right",
                tag: .new,
                title: "RSS Feeds in Discover",
                description: "Discover now includes an RSS Feeds page. You can copy or share links for the main AppleVis feed, apps, blogs, guides, reviews, forums, Apple-only forum posts, and podcasts."
            ),
            ChangeItem(
                systemImage: "macbook.and.iphone",
                tag: .new,
                title: "More Complete App Directory",
                description: "Mac, Apple Watch, and Apple TV app entries now work more consistently across submitting, browsing, search, app pages, and comments."
            ),
            ChangeItem(
                systemImage: "calendar.badge.clock",
                tag: .new,
                title: "More App Store Details",
                description: "App pages can now show release and update dates, better device support, ratings, screenshots, version details, and other App Store information when available."
            ),
            ChangeItem(
                systemImage: "arrow.triangle.2.circlepath",
                tag: .new,
                title: "Editors Can Refresh App Information",
                description: "When signed in, AppleVis editors can update an app page from its App Store listing. This refreshes the title, description, App Store link, and current version without changing accessibility ratings, comments, reviews, category, price, or tested devices."
            ),
            ChangeItem(
                systemImage: "exclamationmark.triangle",
                tag: .new,
                title: "App Store Availability Notices",
                description: "If an AppleVis app entry has an App Store link that no longer works, the app page now lets you know that the listing may no longer be available."
            ),
            ChangeItem(
                systemImage: "gauge.with.needle",
                tag: .fixed,
                title: "Accessibility Ratings Are Easier to Scan",
                description: "VoiceOver, button labelling, and usability ratings on app pages now show the intended color gauge when the rating matches AppleVis's wording."
            ),
            ChangeItem(
                systemImage: "waveform.badge.plus",
                tag: .new,
                title: "Share Audio Into Podcast Submissions",
                description: "Share an MP3, M4A, or WAV file from Files or another app, choose AppleVis, and the podcast submission form opens with the audio already attached."
            ),
            ChangeItem(
                systemImage: "square.and.pencil",
                tag: .fixed,
                title: "Better Submission Forms",
                description: "Bug reports, blog posts, podcasts, and app submissions now better match what AppleVis needs, with clearer required fields and fewer surprises at the end. Submit App no longer asks for Drupal's hidden short summary, shows supported devices more clearly, and uses Review & Submit before the final submit. Submit Blog now validates email addresses, keeps Cancel available on every step, and leaves blog drafts in the author's own voice."
            ),
            ChangeItem(
                systemImage: "hand.point.up.left",
                tag: .fixed,
                title: "Smoother VoiceOver Focus",
                description: "Many screens now move VoiceOver focus to the new page or field as soon as it opens, including Settings, Profile, Discover sections, app pages, podcasts, forums, and first-time setup."
            ),
            ChangeItem(
                systemImage: "safari",
                tag: .fixed,
                title: "Discover Opens Details Reliably",
                description: "Opening blogs, guides, and other Discover lists now uses the same navigation path as Home, so a detail page appears immediately instead of seeming to stay on the list until Back is pressed."
            ),
            ChangeItem(
                systemImage: "dot.radiowaves.left.and.right",
                tag: .improved,
                title: "Stay Updated Is Easier to Find",
                description: "RSS feeds and social follow links now live together in Discover's Stay Updated section, with RSS first, followed by Mastodon, Facebook, and X."
            ),
            ChangeItem(
                systemImage: "paintbrush",
                tag: .fixed,
                title: "Theme and Text Size Polish",
                description: "More screens, banners, cards, and setup steps now follow your selected theme and text size settings."
            ),
            ChangeItem(
                systemImage: "eye.slash",
                tag: .fixed,
                title: "More Editorial Tools",
                description: "AppleVis editors can now see the right edit, unpublish, and delete actions in more places when signed in."
            ),
        ]),
        HistorySection(title: "Also in 2026.10 - 2026.9", items: [
            ChangeItem(
                systemImage: "person.crop.circle",
                tag: .improved,
                title: "Cleaner For You",
                description: "For You now starts with Saved Items, then Following, Podcast Queue, and Downloads, with a simpler filter picker for saved items."
            ),
            ChangeItem(
                systemImage: "app.badge",
                tag: .new,
                title: "App Icon Badge",
                description: "AppleVis can show a badge count for new activity, based on the notification categories you have turned on."
            ),
            ChangeItem(
                systemImage: "square.grid.2x2",
                tag: .improved,
                title: "Redesigned App Directory",
                description: "The App Directory added platform filters, supported devices, and app pages that can use current App Store details."
            ),
            ChangeItem(
                systemImage: "slider.horizontal.3",
                tag: .improved,
                title: "Better Podcast Episode Pages",
                description: "Podcast episode pages added clearer playback controls, audio enhancements, real durations, chapters, and a Download button on episode cards."
            ),
            ChangeItem(
                systemImage: "plus.circle",
                tag: .new,
                title: "Add and Comment Buttons",
                description: "Home gained an Add button for forum topics and app entries, and detail pages gained a consistent Comment button."
            ),
            ChangeItem(
                systemImage: "dial.medium",
                tag: .new,
                title: "More VoiceOver Navigation",
                description: "New rotor options and card actions make it quicker to jump to new comments, replies to you, and podcast chapters."
            ),
            ChangeItem(
                systemImage: "icloud",
                tag: .improved,
                title: "Expanded iCloud Sync",
                description: "iCloud sync now covers more reading, podcast, saved item, and following state."
            ),
            ChangeItem(
                systemImage: "checkmark.shield",
                tag: .improved,
                title: "Safer Posting",
                description: "AppleVis now gives more guideline reminders, checks for duplicate app submissions, and can sync read status with the website when you are signed in."
            ),
            ChangeItem(
                systemImage: "wrench.and.screwdriver",
                tag: .fixed,
                title: "Reliability Fixes",
                description: "This release fixed repeated VoiceOver card actions, stale sign-in sessions, a duplicate Now Playing card, and a System theme flicker."
            ),
        ]),
        HistorySection(title: "Also in 2026.8 - 2026.7", items: [
            ChangeItem(
                systemImage: "square.and.arrow.up",
                tag: .new,
                title: "Share Into AppleVis",
                description: "Sharing from Safari or another app can open the right AppleVis submission form with the link already filled in."
            ),
            ChangeItem(
                systemImage: "ipad.and.iphone",
                tag: .new,
                title: "Handoff",
                description: "You can pick up a topic or podcast on a nearby iPad or Mac from where you left off on iPhone."
            ),
            ChangeItem(
                systemImage: "keyboard",
                tag: .new,
                title: "iPad Keyboard Shortcuts",
                description: "Hold Command on iPad to see shortcuts for Search, Settings, Forums, Apps, Podcasts, and Resources."
            ),
            ChangeItem(
                systemImage: "sparkles",
                tag: .improved,
                title: "Smarter Apple Features",
                description: "Apple Intelligence, Siri Shortcuts, AirPlay, Spotlight, Lock Screen playback, Voice Boost, Trim Silence, artwork descriptions, and iCloud podcast sync all work more reliably."
            ),
            ChangeItem(
                systemImage: "moon",
                tag: .new,
                title: "Focus Filters",
                description: "AppleVis notification categories now appear in iOS Focus settings."
            ),
        ]),
        HistorySection(title: "Also in 2026.6", items: [
            ChangeItem(
                systemImage: "envelope",
                tag: .new,
                title: "Contact App Support",
                description: "A new support wizard lets you contact the AppleVis team without leaving the app or opening Mail."
            ),
            ChangeItem(
                systemImage: "sparkles",
                tag: .new,
                title: "Apple Intelligence Tools",
                description: "Supported devices can summarize, simplify, and translate text on device."
            ),
            ChangeItem(
                systemImage: "mic",
                tag: .new,
                title: "More Siri Shortcuts",
                description: "Siri can resume your podcast, search AppleVis, or open saved items by voice."
            ),
            ChangeItem(
                systemImage: "music.note",
                tag: .improved,
                title: "Better Podcast Playback",
                description: "Podcast playback gained queue skipping, Lock Screen artwork, Control Center artwork, and clearer Dynamic Island status."
            ),
            ChangeItem(
                systemImage: "questionmark.circle",
                tag: .improved,
                title: "Updated Help and Icon",
                description: "The Help Centre was refreshed, and the app icon can adapt to your Home Screen style on supported iOS versions."
            ),
        ]),
        HistorySection(title: "Also in 2026.5", items: [
            ChangeItem(
                systemImage: "ant",
                tag: .new,
                title: "Submit Bug Reports",
                description: "You can submit a bug report from inside the app with platform, OS version, title, Feedback ID, description, and recognition preference."
            ),
            ChangeItem(
                systemImage: "newspaper",
                tag: .new,
                title: "Submit Blog Posts",
                description: "You can write a blog post, import a text or Markdown file, or paste from the clipboard."
            ),
            ChangeItem(
                systemImage: "mic",
                tag: .new,
                title: "Submit Podcasts",
                description: "You can upload a podcast audio file directly from Files or iCloud Drive."
            ),
            ChangeItem(
                systemImage: "square.grid.2x2",
                tag: .new,
                title: "Submit App Entries",
                description: "You can submit App Directory entries with App Store search and accessibility ratings."
            ),
            ChangeItem(
                systemImage: "square.and.arrow.up",
                tag: .improved,
                title: "Smarter Share Extension",
                description: "Sharing App Store links, podcast URLs, and text files into AppleVis now opens the right wizard automatically."
            ),
            ChangeItem(
                systemImage: "speaker.wave.2",
                tag: .improved,
                title: "Help and Sounds",
                description: "The Help Centre gained guides for submission wizards, and the app sounds were refreshed."
            ),
        ]),
        HistorySection(title: "Also in 2026.4 - 2026.3", items: [
            ChangeItem(
                systemImage: "pencil",
                tag: .new,
                title: "Edit Your Content",
                description: "You can edit and delete your own posts and comments from detail pages inside the app."
            ),
            ChangeItem(
                systemImage: "square.grid.2x2",
                tag: .improved,
                title: "App Pages Redesigned",
                description: "App pages added clearer accessibility ratings, developer contact, App Store links, and supported devices."
            ),
            ChangeItem(
                systemImage: "bubble.left.and.bubble.right",
                tag: .improved,
                title: "Forum Pages Redesigned",
                description: "Forum topics added category headers, reply animations, better Braille reading, author colors, and summaries."
            ),
            ChangeItem(
                systemImage: "book",
                tag: .improved,
                title: "Blog and Guide Pages Redesigned",
                description: "Blog and guide pages now better match the forum design and VoiceOver behavior."
            ),
            ChangeItem(
                systemImage: "house",
                tag: .improved,
                title: "Better Home Welcome",
                description: "The Home welcome flow was redesigned to restore focus and return you to your last-read position."
            ),
        ]),
        HistorySection(title: "Also in 2026.2", items: [
            ChangeItem(
                systemImage: "speaker.wave.2",
                tag: .new,
                title: "More Sound Options",
                description: "A new alert sound was added, and all alert sounds were balanced to a more consistent volume."
            ),
            ChangeItem(
                systemImage: "house",
                tag: .improved,
                title: "Better Welcome Card",
                description: "The Welcome card shows new comment counts and can jump back to your last-read position."
            ),
            ChangeItem(
                systemImage: "eye",
                tag: .improved,
                title: "VoiceOver Detail Levels",
                description: "Simple, Normal, and All now provide clearer differences in how much detail VoiceOver reads."
            ),
            ChangeItem(
                systemImage: "bell.badge",
                tag: .new,
                title: "Follow Forum Topics",
                description: "You can follow forum topics and receive reply notifications."
            ),
            ChangeItem(
                systemImage: "text.bubble",
                tag: .improved,
                title: "More In-App Reading and Comments",
                description: "Blog posts, guides, app comments, forum threads, and redesigned detail pages work more fully inside the app."
            ),
            ChangeItem(
                systemImage: "hand.point.up.left",
                tag: .fixed,
                title: "More Reliable VoiceOver Focus",
                description: "VoiceOver focus now lands more reliably after feed loading and pull-to-refresh."
            ),
            ChangeItem(
                systemImage: "speedometer",
                tag: .fixed,
                title: "Playback Speed Fix",
                description: "Pitch correction now works correctly when changing podcast playback speed."
            ),
        ]),
        HistorySection(title: "Also in 2026.0.1.3 - 2026.0.1.5", items: [
            ChangeItem(
                systemImage: "music.note",
                tag: .improved,
                title: "Refreshed Sounds",
                description: "The welcome tone, notification sounds, and system sounds were refreshed."
            ),
            ChangeItem(
                systemImage: "tray.full",
                tag: .improved,
                title: "Saved and Downloaded Episodes",
                description: "Saved and downloaded episodes gained Queue, Share, Mark as Played, and sorting actions."
            ),
            ChangeItem(
                systemImage: "text.alignleft",
                tag: .improved,
                title: "Better Episode Pages",
                description: "Episode pages gained cleaner About text, live links, full-screen transcripts, and artwork descriptions."
            ),
            ChangeItem(
                systemImage: "bubble.left.and.bubble.right",
                tag: .new,
                title: "Full Detail Pages",
                description: "Forum topics and episodes gained full detail screens with bottom toolbars for quick actions."
            ),
        ]),
        HistorySection(title: "Also in 2026.0.1.1 - 2026.0.1.2", items: [
            ChangeItem(
                systemImage: "bubble.left.and.bubble.right",
                tag: .new,
                title: "Forums Inside the App",
                description: "You can read full forum threads and post replies directly inside AppleVis."
            ),
            ChangeItem(
                systemImage: "square.grid.2x2",
                tag: .new,
                title: "Full App Listings",
                description: "App listings now include all community comments inside the app."
            ),
            ChangeItem(
                systemImage: "book",
                tag: .new,
                title: "Full Guides and Articles",
                description: "Guides and articles can be read completely inside the app."
            ),
            ChangeItem(
                systemImage: "gearshape",
                tag: .improved,
                title: "More Settings",
                description: "Podcast, notification, theme, card size, and VoiceOver detail settings gained working controls and previews."
            ),
            ChangeItem(
                systemImage: "arrow.left",
                tag: .fixed,
                title: "Back Buttons Everywhere",
                description: "Settings, detail pages, and sub-screens now include a Back button."
            ),
            ChangeItem(
                systemImage: "hand.tap",
                tag: .new,
                title: "Magic Tap for Podcasts",
                description: "A two-finger double tap now plays and pauses podcasts."
            ),
        ]),
    ]
}
