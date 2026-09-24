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

                ForEach(ChangeItem.grouped(ChangeItem.current)) { item in
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

            ForEach(ChangeItem.grouped(section.items)) { item in
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
    case accessibility = "Accessibility"
    case fixed = "Fixed"

    /// Display order for grouped What's New sections: New, then Improved,
    /// then Accessibility, then Fixed last (plain bug fixes are the least
    /// exciting category, so they trail even behind assistive-tech fixes,
    /// which matter more to this app's audience than a generic tag order would).
    var groupOrder: Int {
        switch self {
        case .new:           return 0
        case .improved:      return 1
        case .accessibility: return 2
        case .fixed:         return 3
        }
    }

    var backgroundColor: Color {
        switch self {
        case .new:           return Color(red: 0.93, green: 0.99, blue: 0.96)
        case .improved:      return Color(red: 0.94, green: 0.96, blue: 1.0)
        case .accessibility: return Color(red: 0.96, green: 0.93, blue: 1.0)
        case .fixed:         return Color(red: 1.0, green: 0.97, blue: 0.93)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .new:           return Color(red: 0.02, green: 0.37, blue: 0.27)
        case .improved:      return Color(red: 0.11, green: 0.30, blue: 0.85)
        case .accessibility: return Color(red: 0.42, green: 0.11, blue: 0.75)
        case .fixed:         return Color(red: 0.60, green: 0.20, blue: 0.07)
        }
    }
}

struct ChangeItem: Identifiable {
    let id = UUID()
    let systemImage: String
    let tag: ChangeTag
    let title: String
    let description: String

    static let currentVersion = "2026.17"

    static let current: [ChangeItem] = [
        ChangeItem(
            systemImage: "app.badge.checkmark",
            tag: .fixed,
            title: "App Entries Are Clearer About What Changed on the App Store",
            description: "An app's page always said its description \"may differ\" from the App Store, even when the two were word for word the same, so updating an entry never made the note go away. It now only says so when they really differ, and app pages also mention when the App Store has renamed an app. When you submit an app, the devices it supports are still filled in from the App Store, but you can now untick any it doesn't really support. Reported directly."
        ),
        ChangeItem(
            systemImage: "globe",
            tag: .fixed,
            title: "More of AppleVis Now Speaks Your Language",
            description: "Auto-Translate's own settings and the prompt that offers it were still in English, which is exactly when you'd need them in your own language. They're now translated into all 22 languages, along with everything new in this release. A few translated counts, like how many posts or reports were loaded, could also show jumbled text in some languages. Fixed too."
        ),
        ChangeItem(
            systemImage: "wand.and.stars",
            tag: .improved,
            title: "Rewrite and Translate in More Places",
            description: "Report a Comment's details box now has Rewrite and the offer to translate into English, like every other form that goes to our team. Messaging another member now has Rewrite too. On Submit an App and Submit a Blog Post, Translate used to change only one box even when the other one was the one not in English. It now translates every box that needs it, and the blog pitch box gets its own Rewrite button. Requested directly."
        ),
        ChangeItem(
            systemImage: "backward.end",
            tag: .improved,
            title: "Listened Is Now a Simple Reminder, and Start Over Is Its Own Button",
            description: "The Mark Listened button in a podcast episode's Episode Tools was confusing. It changed its name once pressed, and it also quietly erased your place in the episode. Listened is now a plain on/off switch, just a reminder that you've heard the episode, and it shows as a checkmark in episode lists too. It still turns on by itself when an episode plays to the end, and turning it off now stays off across your devices. Going back to the beginning has its own Start Over button, which appears whenever you have a saved place in the episode. Suggested directly."
        ),
        ChangeItem(
            systemImage: "arrow.down.to.line",
            tag: .accessibility,
            title: "Jump to First New Comment Lands on the Comment Again",
            description: "Using Jump to First New Comment from Home opened the page but left VoiceOver on the title instead of the first new comment. This happened most often with forum topics and app entries, and with anything you hadn't opened before. It now lands right on the first comment you haven't seen, even when it's further down a long thread. Reported directly."
        ),
        ChangeItem(
            systemImage: "character.bubble",
            tag: .fixed,
            title: "Detail Pages and VoiceOver Now Use Your Language Throughout",
            description: "With the app set to another language, parts of every detail page were still in English: section headings like Steps to Reproduce and Episode Notes, the podcast player's buttons, bug status and severity, App Store notices on app entries, and much of what VoiceOver says, like comment numbers, the thread summary when a page opens, and every item's comment count. They're now translated into all 22 languages, and counts use each language's own plural forms instead of adding an English \"s\"."
        ),
        ChangeItem(
            systemImage: "clock.arrow.circlepath",
            tag: .fixed,
            title: "Blog Posts, Episodes, and Guides With New Comments Now Show Up",
            description: "Blog posts, podcast episodes, and guides went by when the post itself was last edited, not when the latest comment came in. A busy post with new comments today could still say \"6 days ago\" and never show up as new on Home. They now go by their latest comment, the same as forum topics and app entries, and Home now brings in anything that just got comments, even older posts. Reported by a beta tester."
        ),
        ChangeItem(
            systemImage: "book",
            tag: .fixed,
            title: "Guides Are Called Guides Everywhere Now",
            description: "A few places still used an old name, Resources, for what AppleVis calls Guides: the New Resources notification switch, a Resources section in search results, and the Guides screen itself. They all say Guides now, matching the website. The Mentions notification switch is also gone for now, since AppleVis doesn't have real mentions. Typing someone's username doesn't notify them. Suggested by a beta tester."
        ),
        ChangeItem(
            systemImage: "paintbrush",
            tag: .improved,
            title: "Setup's Theme Step Is Quicker to Get Through",
            description: "The Choose a Theme step now says up front that it's already set to System, matching your iPhone's Light or Dark Mode, with a Continue button right below instead of past all 15 themes. That's just a couple of swipes with VoiceOver instead of about 20. It also mentions that High Contrast or Midnight can help if you have some vision, marks the default as Recommended, and if Increase Contrast is already on for your iPhone, it starts you on a High Contrast theme. Suggested by a beta tester."
        ),
        ChangeItem(
            systemImage: "arrow.up.forward.square",
            tag: .improved,
            title: "Links That Leave the App Now Say So",
            description: "Links like Sign up for free, Reset Password, Terms of Service, and social media now show a small arrow after their name, and VoiceOver tells you whether they'll open in the app's browser or in your web browser, matching your Web Links setting. Buttons that jump to the App Store or the Settings app say so too. No more landing on a web page without warning. Suggested by a beta tester."
        ),
        ChangeItem(
            systemImage: "link",
            tag: .improved,
            title: "AppleVis Links in Posts Now Open Right in the App",
            description: "When a post or comment links to another forum topic, app entry, guide, blog post, podcast episode, or bug report on AppleVis, tapping it now opens that page right in the app, instead of sending you out to Safari. Links to other websites still open the way they always have."
        ),
        ChangeItem(
            systemImage: "bubble.left.and.text.bubble.right",
            tag: .fixed,
            title: "New Comment Counts on Everything on Home",
            description: "Home only counted new comments on things you'd opened before. Anything you'd never opened just showed nothing — and quietly stopped counting as new the next time the app opened, even if you never looked at Home. Now everything on Home counts new comments the same way, and the count keeps adding up until you open it or mark it as read. A topic posted since your last visit shows NEW plus its comment count, and the summary at the top only calls something a new topic if it really is. Reported directly."
        ),
        ChangeItem(
            systemImage: "quote.bubble",
            tag: .fixed,
            title: "Apostrophes Now Copy, Share, and Read Aloud Correctly",
            description: "Copying, sharing, or using Read Aloud on a post or comment could turn apostrophes and quotation marks into web codes — \"I've\" came out as \"I\", an ampersand, a number, and then \"ve\" — and Read Aloud would actually speak them. The same codes could also reach translations, and VoiceOver on paragraphs where milder language is filtered. Fixed everywhere, so the text you copy, share, or hear matches what's on screen."
        ),
        ChangeItem(
            systemImage: "speaker.slash",
            tag: .fixed,
            title: "Telling VoiceOver to Hush No Longer Triggers a Tone Reminder",
            description: "Writing something like \"shut up, Siri\" or \"I wish VoiceOver would shut up\" used to bring up a reminder about respectful discussion, as if it were aimed at another member. Venting at VoiceOver, Siri, a named voice like Daniel or Samantha, or your phone itself no longer counts — a \"shut up\" aimed at a person still gets the gentle reminder."
        ),
        ChangeItem(
            systemImage: "doc.text",
            tag: .fixed,
            title: "Editing a Topic, Comment, or Review No Longer Shows Raw HTML",
            description: "Editing a Forum Topic, Guide comment, App Entry review, App Entry, Blog Post, Guide, Bug Report, or Podcast Episode used to pre-fill the edit box with the rendered HTML behind the content — literal <p> and <a href=\"...\"> tags — instead of the original text. Saving without cleaning that out could also silently corrupt the formatting, since the edit always saved as Plain Text regardless of the content's real format (Markdown, for many longer posts). Both fixed: editing now starts from the original source text, and saves preserve whichever format the content actually uses. Found while looking into a report of stray HTML showing up while editing a topic."
        ),
        ChangeItem(
            systemImage: "list.number",
            tag: .improved,
            title: "Every Wizard Now Matches the Welcome Tour's Step Format",
            description: "Setup, Contact Us, Submit Bug Report, Submit Blog, Submit an App, Submit a Podcast, Report a Comment, and Change Password/Email each built their step header a little differently — some had a visible \"Step X of Y,\" some didn't; back buttons lived in different places from screen to screen. All of them, plus the Welcome Tour, Edit Profile, Bio Assist, and editors' Refresh App Details screen, now share one step header: Back button, a visible \"Step X of Y\" where relevant, and a heading that announces itself once, clearly, instead of possibly twice. Requested directly."
        ),
        ChangeItem(
            systemImage: "wand.and.stars",
            tag: .improved,
            title: "Editing and Posting Feel More Alike Now, With a Few New Touches",
            description: "Every Edit screen and every compose screen (new topics, replies, and comments on Guides, Blogs, Podcasts, Bug Reports, and App Entries) now opens with the same short heading and description, so it's clearer what you're about to do before you start typing. A few screens that were missing the one-tap Rewrite button (Editing, and commenting on App Entries, Guides, Blogs, Podcasts, and Bug Reports) now have it too. A couple of small touches: the Rewrite button gives a little bounce when it finishes, the text field briefly highlights so it's clear something changed, and a guideline reminder now eases into view instead of popping in abruptly. Submit an App/Blog/Podcast/Bug Report and Contact Us now share these same touches too, plus their Submit button shows a spinner while sending instead of just going dim. Requested directly."
        ),
    ]

    static let archivedFrom2026_16: [ChangeItem] = [
        ChangeItem(
            systemImage: "checkmark.shield",
            tag: .fixed,
            title: "Skip Setup No Longer Skips Past Agreeing to Our Terms",
            description: "Setup's Welcome screen says \"By continuing, you agree to our Terms of Service and Privacy Policy\" above its Get Started button — but Skip Setup, right below, was also reachable from that very first screen, letting someone finish setup and start using the app without ever passing through that agreement. Skip Setup now only appears from the second step onward, and Welcome's button is now Accept and Get Started, so agreeing always comes first. Discussed and requested directly."
        ),
        ChangeItem(
            systemImage: "text.bubble",
            tag: .improved,
            title: "A Clearer Explanation on Our Community Agreement Screen",
            description: "The only place that explained what I Don't Agree actually does was spoken by VoiceOver, not shown on screen — anyone reading the screen visually saw two buttons with no stated consequence for the second one. It now says so in plain text too: declining is fine, AppleVis stays fully browsable without signing in, and we'll ask again the next time you try to sign in. Discussed directly."
        ),
        ChangeItem(
            systemImage: "icloud.and.arrow.down",
            tag: .fixed,
            title: "Reinstalling No Longer Floods Home with False \"New\" Counts",
            description: "Reinstalling AppleVis while signed in — or setting up a new device on the same account — correctly remembered your read history, but forgot when you'd first started using the app. Without that, nearly everything in the feed that hadn't been individually opened before showed up as new all at once, whether it was actually posted yesterday or months ago. Fixed so that's remembered too. Reported directly."
        ),
        ChangeItem(
            systemImage: "clock",
            tag: .new,
            title: "Reading Time in Mouse Recap's How-To Corner",
            description: "Podcast Episode cards show how long the episode runs, and Blog Post cards show an estimated reading time — How-To Corner's guides, tutorials, and articles now show the same estimate, alongside the author, date, and comment count already there. Requested directly."
        ),
        ChangeItem(
            systemImage: "list.bullet.rectangle",
            tag: .accessibility,
            title: "App Entry Comments Now Reachable with the Headings Rotor",
            description: "Every comment on a Forum Topic, Guide, Blog Post, Podcast Episode, and Bug Report is marked as a heading, so VoiceOver's Headings rotor can jump straight from one comment to the next — App Entry reviews were the one place that never had it, so they were reachable only by swiping past everything else on the page. Fixed to match. Reported directly."
        ),
        ChangeItem(
            systemImage: "hand.thumbsup.slash",
            tag: .fixed,
            title: "Removed a Not-Yet-Working Mark as Helpful Action on App Entries",
            description: "App Entry comments had a Mark as Helpful action, in both the VoiceOver Actions rotor and the long-press menu, that only ever showed a \"coming soon\" toast — no real functionality behind it yet. Forums already held this back for the same reason, and it was never added to Guides, Blogs, Podcasts, or Bug Reports either. Removed from App Entries too until that backend work actually lands. Reported directly."
        ),
        ChangeItem(
            systemImage: "arrow.triangle.2.circlepath",
            tag: .fixed,
            title: "App Entry Edits Now Show Up Immediately",
            description: "Editing an App Entry's title or description showed a success message right away, but the About section kept showing the old text until you left the page and came back. The edit itself was always saved; only the screen was stale. Fixed so a confirmed edit shows up immediately. Reported directly."
        ),
        ChangeItem(
            systemImage: "exclamationmark.bubble",
            tag: .new,
            title: "Think a Guideline Reminder Got It Wrong? Tell Us",
            description: "Any guideline reminder or friendly tip shown while composing a topic, reply, comment, or message now has a This Doesn't Seem Right button right next to Got It. It reports the rule, its message, and your draft text straight to our editorial team, so the checker itself can keep improving. Signed in only — dismissing still works exactly as before either way. Requested directly."
        ),
        ChangeItem(
            systemImage: "hand.draw",
            tag: .accessibility,
            title: "For You's Section Picker Announces Your New Selection Again",
            description: "Swiping up or down on For You's section picker (Saved, Following, Recommended, Queue, Downloads) played the change tone but never spoke which section you landed on — switching sections swaps in an entirely different screen underneath, and that swap was interrupting VoiceOver's usual announcement before it could be heard. Every other swipeable picker in the app only re-filters a list, so this was the one place it happened. Fixed by announcing the new selection explicitly instead. Reported directly."
        ),
        ChangeItem(
            systemImage: "arrow.up.arrow.down",
            tag: .fixed,
            title: "App Entry Comments Now Appear in the Right Order",
            description: "Every comment on a Forum Topic, Blog Post, Guide, Podcast Episode, and Bug Report is listed oldest to newest, the same order the website shows them in — App Entry reviews were the one place sorted newest first instead, so a reply could appear well before the comment it was replying to. Verified against a real app entry's live comments and the website's own page: fixed to sort oldest first everywhere, matching every other content type. Reported directly."
        ),
        ChangeItem(
            systemImage: "party.popper",
            tag: .fixed,
            title: "No More Anniversary Popup Right After Reinstalling",
            description: "A brand-new install could open straight into a Happy Anniversary celebration during setup, for an account that had already had its real anniversary earlier in the year — the \"already celebrated this year\" memory lives on the device, so reinstalling erased it and triggered the popup again the moment Home loaded. A fresh install now quietly notes the year without showing the popup, so celebrating picks back up on the account's next genuine anniversary instead. Reported directly."
        ),
    ]

    static let archivedFrom2026_15: [ChangeItem] = [
        ChangeItem(
            systemImage: "person.crop.circle",
            tag: .accessibility,
            title: "Setup Focuses Welcome First",
            description: "Opening AppleVis for the very first time used to send VoiceOver focus straight to Cancel instead of the Welcome heading — every other step in setup already retried focus after Next/Back, but nothing did that for the initial screen itself. It now focuses Welcome first, like every step after it."
        ),
        ChangeItem(
            systemImage: "text.badge.checkmark",
            tag: .accessibility,
            title: "No More Double \"Step X of Y\" in Setup",
            description: "Every step of setup announced its step count twice in a row — once from the progress dots at the top, then again folded into the heading itself (\"Sign In. Step 2 of 9.\"). Headings now just say their own name; the progress dots at the top remain the one place setup announces which step you're on."
        ),
        ChangeItem(
            systemImage: "forward.end",
            tag: .improved,
            title: "A Friendlier Way to Skip Setup",
            description: "Setup's top-right Cancel button didn't actually cancel anything — it just accepted whatever hadn't been set yet and finished, exactly like completing setup normally. It's now a plain Skip Setup link under each step's own content instead, with a note that everything can still be changed later in Settings — gone entirely on the last step, since there's nothing left to skip by then."
        ),
        ChangeItem(
            systemImage: "star",
            tag: .improved,
            title: "Setup Marks Our Recommended Pick",
            description: "New Activity Display, Apple Topics, and Language Filtering each show two options that pick and move on with a single tap rather than a separate Continue step, so there was never a moment to show which one we'd suggest. A small Recommended badge now marks that option on all three."
        ),
        ChangeItem(
            systemImage: "list.bullet.rectangle",
            tag: .accessibility,
            title: "Jump Between Sections in Setup",
            description: "The Choose a Theme step's Accessibility, AppleVis, and Standard groupings, and the Notifications step's Notification Sound section, are now real VoiceOver headings — jump straight to one with the Headings rotor instead of swiping through everything ahead of it."
        ),
        ChangeItem(
            systemImage: "checklist",
            tag: .improved,
            title: "A Shorter Setup",
            description: "Setup no longer asks how much VoiceOver should announce before you've had a chance to actually hear it and judge for yourself — a choice you can't really make well on day one anyway, and one that's still right there in Settings > Accessibility whenever you want it. Setup is now 8 steps instead of 9."
        ),
        ChangeItem(
            systemImage: "bell.badge",
            tag: .new,
            title: "All of Notifications, Not Just Three",
            description: "Setup's Notifications step only ever offered 3 of the app's 8 real notification categories. It now offers all of them — Replies to My Posts, Mentions, and Followed Topics sit in their own My Activity group, dimmed with an explanation if you're continuing as a guest, alongside New Forum Topics, New Podcast Episodes, New App Directory Entries, New Resources, and New Comments."
        ),
        ChangeItem(
            systemImage: "text.bubble",
            tag: .improved,
            title: "A Heads-Up Before the Notification Prompt",
            description: "Setup's Allow Notifications button gave no sense of what iOS's own permission prompt was about to ask, or why. A short note now explains it only sends alerts for what you turned on above, and that you can change it anytime in Settings."
        ),
        ChangeItem(
            systemImage: "speaker.slash",
            tag: .accessibility,
            title: "No More Dead Preview on System Default Sound",
            description: "System Default's own description already says its preview is unavailable — there's no iOS API to play back a device's actual default alert tone — but the VoiceOver Preview action was still offered anyway, silently doing nothing when used. It's gone for just that one sound now, both in setup and in Settings > Notifications, while every other sound keeps it."
        ),
        ChangeItem(
            systemImage: "globe",
            tag: .fixed,
            title: "Notification Sound Names Now Actually Translate",
            description: "Mouse Squeak, Apple Crunch, Golden Retriever Bark, System Default, and each one's description showed up in English no matter what language the app was set to, in both setup and Settings > Notifications — now fixed and translated into all 22 supported languages."
        ),
        ChangeItem(
            systemImage: "checkmark.circle",
            tag: .improved,
            title: "A Friendlier You're All Set Summary",
            description: "Setup's final summary listed things in no particular order, still mentioned VoiceOver Detail Level after that step was removed, never mentioned Show What's New or which notification sound you picked, and read as terse label-value pairs like \"Language: Milder Language Filtered.\" It's now ordered to match the steps you just went through — sign-in status first — covers every choice you actually made, and reads as plain, friendly sentences instead."
        ),
        ChangeItem(
            systemImage: "map",
            tag: .improved,
            title: "A Reassurance on the Tour Prompt",
            description: "The \"Take a quick tour?\" prompt right after setup only said what the tour covered, with no hint that saying no was perfectly fine or where to find it again. It now adds that you can always start it later from Profile > Replay Welcome Tour."
        ),
        ChangeItem(
            systemImage: "1.circle",
            tag: .accessibility,
            title: "No More \"Step 1 of 1\" in the Welcome Tour",
            description: "The Welcome Tour's Welcome and All Set chapters are each just one step, so VoiceOver always announced a trivially true \"step 1 of 1\" there — dropped for just those two chapters, while Home, Discover, For You, and Profile & Settings keep their genuinely useful step counts."
        ),
        ChangeItem(
            systemImage: "globe",
            tag: .fixed,
            title: "Welcome Tour Step Announcements Now Actually Translate",
            description: "Every VoiceOver step announcement in the Welcome Tour — \"Home, step 3 of 8\" and the like, heard on nearly all 28 steps — had never been translated into any of AppleVis's 22 supported languages, only ever existing in English. Fixed and translated into all 22."
        ),
        ChangeItem(
            systemImage: "pause.circle",
            tag: .improved,
            title: "A Real Way to Pause the Welcome Tour",
            description: "Skip Tour used to be the only way out of the Welcome Tour from 25 of its 28 steps — and it reset your progress, even if all you wanted was to step away and come back later. It's now Leave Tour everywhere, offering a real choice: pause and resume right where you left off, or skip the tour completely. The old checkpoint-only Pause Tour option is gone, since this covers every step instead of just 3."
        ),
        ChangeItem(
            systemImage: "text.alignleft",
            tag: .accessibility,
            title: "Welcome Tour Steps Now Read Paragraph by Paragraph",
            description: "Each Welcome Tour step's explanation used to read (or Braille-pan) as one long, unbroken block, the same problem already fixed for forum topics, blog posts, and podcast show notes. It's now split into shorter stops you can pause on, re-read, or skip past — a few more swipes, but no more one continuous wall of speech."
        ),
        ChangeItem(
            systemImage: "globe",
            tag: .fixed,
            title: "The Whole Welcome Tour Now Actually Translates",
            description: "Every step's title and explanation, every button, and the tour's own name showed up in English throughout the entire tour no matter what language the app was set to — the same bug already fixed elsewhere in the app, and in this case, all 28 steps already had full translations sitting unused. Fixed, so all of it displays correctly now."
        ),
        ChangeItem(
            systemImage: "checkmark.seal",
            tag: .fixed,
            title: "Two Welcome Tour Content Corrections",
            description: "The Home chapter's Customize Your Feed step claimed a finer forum filter was \"tucked into\" the Customize Home sheet — it isn't; that filter lives in Settings > Home Feed instead, so the claim is gone until that screen gets its own review. The Profile & Settings overview step's Learn More button also opened a Help article about what the four main tabs do, which the tour itself had already covered in far more depth — and didn't match what that step was actually about. Removed."
        ),
        ChangeItem(
            systemImage: "square.grid.2x2",
            tag: .accessibility,
            title: "Mouse Recap Announces Each Section's Type Once",
            description: "With 3 new apps in a week, VoiceOver announced \"New on the App Scene\" three times in a row — once per app card — instead of once for the whole group. Same fix for Podcast Episode, Blog Post, and Popular Discussion: announced once at the top of their section, with each card's own label still visible on screen but no longer repeated aloud. How-To Corner is unchanged, since its Guide/Tutorial label genuinely differs per item."
        ),
        ChangeItem(
            systemImage: "globe",
            tag: .accessibility,
            title: "Mouse Recap Now Actually Translates",
            description: "Its section titles, kickers like \"Podcast Episode\" and \"Popular Discussion,\" the intro line under each heading, and the Guide/Tutorial/Article labels in How-To Corner were all hardcoded English, so VoiceOver read them in English no matter what language the app was set to. They now follow the app's language like everything else."
        ),
        ChangeItem(
            systemImage: "clock",
            tag: .new,
            title: "Episode Length and Reading Time in Mouse Recap",
            description: "Podcast Episode cards now show how long the episode runs, and Blog Post cards now show an estimated reading time — alongside the author, date, and comment count already there. Requested directly."
        ),
        ChangeItem(
            systemImage: "list.bullet",
            tag: .accessibility,
            title: "Two Fixes for the For You Section Picker",
            description: "Tapping the section picker (Saved, Following, Recommended, Queue, Downloads) to open it spoke its selection twice in a row — \"Apps You've Recommended, 0 items\" once for the picker itself and again for the same row inside the menu. And because changing sections swaps in an entirely different screen underneath, swiping to the next section sometimes let VoiceOver focus drift off the picker entirely instead of staying put and announcing the new selection. Both fixed. Reported directly."
        ),
        ChangeItem(
            systemImage: "text.bubble",
            tag: .accessibility,
            title: "Home Startup Behavior Explains Itself, and Stops Repeating",
            description: "This picker used to say its own value twice in a row on a plain swipe through Settings — a leftover from a persistent VoiceOver override that duplicated what the control already announces natively. Fixed, the same way as the For You section picker above. Its VoiceOver hint also used to just say it \"controls how much spoken announcement Home produces,\" without saying what Quiet, Helpful, or Detailed each actually do — it now spells out the difference for VoiceOver users the same way the on-screen text already does for everyone else. Reported directly."
        ),
        ChangeItem(
            systemImage: "text.bubble",
            tag: .accessibility,
            title: "Every Settings Picker Stops Repeating Itself",
            description: "The same double-announcement fixed above in Home Startup Behavior — VoiceOver saying a setting's value twice in a row on a plain swipe — was actually present in every picker across Settings that supports swipe up/down to change its value: Web Links, Notification Sound, Card Density, Keep Cache For, and all eight pickers in Podcasts (Speed, Skip Back, Skip Forward, Equaliser, Sleep Timer, Resume Rewind, Auto-Download, Auto-Delete). All fixed the same way. Reported directly."
        ),
        ChangeItem(
            systemImage: "sparkles",
            tag: .improved,
            title: "Detailed Is Now Home's Default Welcome",
            description: "Home Startup Behavior now defaults to Detailed instead of Helpful — a plain \"Welcome back\" with no idea what's actually new wasn't pulling its weight as a first impression. Detailed adds an AI-generated summary of what's changed since your last visit, and quietly falls back to the same short welcome Helpful gives when there's nothing new to report, so nothing gets noisier on a quiet day. Change it anytime in Settings > General."
        ),
        ChangeItem(
            systemImage: "text.alignleft",
            tag: .improved,
            title: "Overviews Added to More Settings Screens",
            description: "Sounds & Haptics, Podcasts, Storage & Cache, and Notifications now open with the same kind of plain-language overview General and several other Settings screens already had — what the screen covers, in a sentence or two, before you get into the individual switches and pickers. Requested directly."
        ),
        ChangeItem(
            systemImage: "person.badge.plus",
            tag: .improved,
            title: "Replies to My Posts Now Actually Auto-Follows",
            description: "This preference now does what its description always implied: turn it on, and every new forum topic or app entry you post is automatically followed for you, the same as tapping Follow yourself — no separate step needed. It only applies going forward; anything posted before turning it on isn't touched, since there's nothing to retroactively follow. Forum topics already had their own follow-on-post toggle in the composer, seeded from this preference; app entries get the same treatment now too. Clarified directly after this was found to be misunderstood as just a notification setting rather than a real subscription."
        ),
        ChangeItem(
            systemImage: "line.3.horizontal.decrease.circle",
            tag: .fixed,
            title: "Removed a Confusing Hidden Forum Filter",
            description: "Settings > Home Feed had a second, easy-to-miss forum filter (Recent, New, Unread, Since Last Visit) that silently narrowed which forum topics reached Home's feed before Home's own All/New/Mouse Recap switcher ever saw them — so choosing All in Home could still quietly show only, say, Unread topics, with no visible explanation why. Two of its six options (Following, Saved) were already no-ops here besides. Removed entirely; Home's own All/New switcher is now the one place any content type, forums included, gets filtered. Discussed and requested directly."
        ),
        ChangeItem(
            systemImage: "hand.raised",
            tag: .improved,
            title: "A Leaner Privacy Screen",
            description: "Settings > Privacy had turned into a directory of shortcuts to screens that already have their own home in Settings — Smart Features and iCloud Sync just duplicated the Intelligence and Saved & Sync rows one tap away, and Manage Storage duplicated Storage & Cache. All three removed; the info cards above them already cover the privacy-relevant facts. Filter Profanity and Show What's New on Home also moved out — neither is really a privacy control (one's about how existing content displays, the other's a Home display preference), so both now live in Settings > General instead. Privacy is left with what's actually unique to it: what's collected, and the handful of real data actions. Discussed and requested directly."
        ),
        ChangeItem(
            systemImage: "arrow.uturn.backward",
            tag: .fixed,
            title: "Settings Navigation Could Unexpectedly Kick You Out",
            description: "A few screens deep into Settings — Settings > Help > a tutorial or FAQ, for instance — navigation could get confused and unexpectedly bounce you back out to Home instead of where you tapped. Fixed. Reported directly: double-tapping into a Help article could unexpectedly land back out at Home instead of opening the article."
        ),
        ChangeItem(
            systemImage: "questionmark.circle",
            tag: .improved,
            title: "Help Moved to Profile, About Duplicate Removed",
            description: "Help used to sit a level deeper than it needed to — Profile > Settings > scroll down to Support > Help — despite being reference material people come back to, not a configuration screen. It now lives directly in Profile's About AppleVis section, alongside What's New and About & Credits. Settings > Support's About row was also just a duplicate of the one already in that same Profile section, so it's gone; Settings now holds configuration only. Discussed and requested directly."
        ),
        ChangeItem(
            systemImage: "waveform",
            tag: .accessibility,
            title: "A VoiceOver Performance Heading on App Entries",
            description: "The VoiceOver Performance, Button Labelling, and Usability ratings on an App Entry page used to float between About and Accessibility Comments with no heading of their own — reachable only by swiping past everything else, not by jumping there with the Headings rotor. They now sit under their own VoiceOver Performance heading. Requested directly."
        ),
        ChangeItem(
            systemImage: "text.bubble",
            tag: .accessibility,
            title: "Comment Subjects No Longer Repeat",
            description: "On Guide, Blog, Podcast, and Bug Report comments, a subject line was announced twice in a row — once as part of the comment's header (\"...Subject: X.\"), then again as its own separate stop right below. Forums and App Entries, which use their own comment row, never had this. Fixed here too; the subject is still shown on screen, just not read aloud twice. Reported directly."
        ),
        ChangeItem(
            systemImage: "text.quote",
            tag: .fixed,
            title: "Podcast Transcripts Could Wrongly Say \"No Longer Available\"",
            description: "Tapping Read Transcript could open to \"This item is no longer available\" even when the episode's show notes had a transcript right there the whole time — the sheet could open a beat before the transcript text was actually ready, and gave up instead of waiting. Not tied to any particular episode's transcript; verified against several different ones, all formatted the same way. Fixed so the sheet always waits for the text to be ready before it opens. Reported directly."
        ),
        ChangeItem(
            systemImage: "globe",
            tag: .fixed,
            title: "App Search Now Uses Your Own App Store Region",
            description: "Searching for an app to add to the App Directory, or checking an app's live App Store details, always queried the US App Store no matter where you actually are — a real app that simply isn't sold there (or is exclusive to a different storefront) could turn up zero search results, or even get wrongly flagged as \"Removed\" in App Directory Health Check. Both now check your device's own region first, only falling back to the US store if that comes up empty. Reported directly by a tester in Ireland who couldn't find a real app while trying to submit it."
        ),
        ChangeItem(
            systemImage: "person.2.circle",
            tag: .new,
            title: "A Community Agreement Before You Sign In",
            description: "Before signing in — whether during first-run setup, from Profile, or from Add a Topic and every Submit screen — you'll now see a short Community Agreement explaining how guideline checks work and asking you to agree to follow them. Browsing AppleVis never required this and still doesn't; it only appears right before signing in. Declining just means continuing without an account, and you can review it again anytime you try to sign in later."
        ),
        ChangeItem(
            systemImage: "checkmark.shield",
            tag: .fixed,
            title: "Fewer False Guideline Reminders",
            description: "The gentle reminder shown while composing a topic, reply, or review could fire on things that were never really a problem — a normal reply asking a few quick follow-up questions, criticizing an app or company rather than a person, mentioning \"my podcast player,\" or thanking people who already took a survey. Tightened up several of these checks so the reminder shows up for things that actually need a second look, not ordinary posts. Found while reviewing real flagged content together."
        ),
        ChangeItem(
            systemImage: "doc.plaintext",
            tag: .new,
            title: "Terms of Service and Privacy Policy Shown at Setup",
            description: "The very first screen of setup now links directly to our Terms of Service and Privacy Policy, which continuing past it means agreeing to. Previously these were only reachable as an easy-to-miss link tucked into About and Settings."
        ),
        ChangeItem(
            systemImage: "arrow.counterclockwise",
            tag: .fixed,
            title: "Reinstalling Now Actually Signs You Out",
            description: "Deleting and reinstalling AppleVis brought onboarding back as expected, but silently signed you back in anyway — the Keychain, unlike everything else the app stores, survives an app deletion. A fresh install now clears any leftover sign-in from before, so reinstalling really does mean starting fresh. Reported directly."
        ),
    ]

    /// Stable-sorts into New → Improved → Accessibility → Fixed while
    /// preserving each item's relative (hand-curated, importance-ordered)
    /// position within its own group.
    static func grouped(_ items: [ChangeItem]) -> [ChangeItem] {
        items.enumerated()
            .sorted {
                $0.element.tag.groupOrder != $1.element.tag.groupOrder
                    ? $0.element.tag.groupOrder < $1.element.tag.groupOrder
                    : $0.offset < $1.offset
            }
            .map(\.element)
    }

    static let archivedFrom2026_14: [ChangeItem] = [
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
            tag: .accessibility,
            title: "A Saved-List Tip That Actually Matches What You Saved",
            description: "Another beta-tester catch: saving a forum topic used to trigger a one-time tip titled \"Faster Episode Actions,\" describing swipe-to-delete and mark-as-played — neither of which exists on a saved topic. The tip now matches whatever you actually saved, and VoiceOver users get an accurate version pointing to the Actions rotor instead of a swipe-left instruction that, under VoiceOver, just moves focus to the previous item rather than doing anything useful."
        ),
        ChangeItem(
            systemImage: "bookmark",
            tag: .accessibility,
            title: "A Clearer Nudge for Saving Your First Item",
            description: "The empty For You > Saved screen used to say \"Tap the bookmark icon on any item to save it\" — a beta tester pointed out that VoiceOver never actually says the word \"bookmark\" anywhere in the app, since every Save button and menu item is labeled Save. It now says to save a topic, app, guide, blog post, or episode, matching what every Save control is actually called for every user."
        ),
        ChangeItem(
            systemImage: "globe",
            tag: .fixed,
            title: "Onboarding and What's New Now Actually Translate",
            description: "Every onboarding step's heading and description, and every What's New entry — this release and all of history — showed up in English no matter what language the app was set to. Both are fixed, and the onboarding strings that had never been translatable in the first place are now translated into all 22 supported languages."
        ),
        ChangeItem(
            systemImage: "text.line.first.and.arrowtriangle.forward",
            tag: .accessibility,
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
            tag: .accessibility,
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
            tag: .accessibility,
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
            tag: .accessibility,
            title: "Swipeable Pickers Announce What You Picked",
            description: "Swiping up or down on a picker — For You's section switcher, Home Feed, App Directory's platform filter, and every swipeable setting in Podcasts, Notifications, Storage, and Appearance — previously played only a plain \"value changed\" sound with nothing spoken. VoiceOver now announces the actual selection, like \"Following\" or \"1.5 times,\" every time."
        ),
        ChangeItem(
            systemImage: "scope",
            tag: .accessibility,
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
            tag: .accessibility,
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
        HistorySection(title: "Also in 2026.15", items: ChangeItem.archivedFrom2026_15),
        HistorySection(title: "Also in 2026.14", items: ChangeItem.archivedFrom2026_14),
    ]
}
