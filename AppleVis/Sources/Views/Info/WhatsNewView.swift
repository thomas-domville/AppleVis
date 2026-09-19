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

    static let currentVersion = "2026.15"

    static let current: [ChangeItem] = [
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
            description: "Mouse Squeak, Apple Crunch, Golden Retriever Bark, System Default, and each one's description were built from a code pattern that silently skipped the translation catalog, in both setup and Settings > Notifications. Non-English speakers saw English there no matter how many translations existed — now fixed and translated into all 22 supported languages."
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
            description: "Every step's title and explanation, every button, and the tour's own name were built from a code pattern that silently skipped the translation catalog, the same bug already fixed elsewhere in the app. Non-English speakers saw English throughout the entire tour no matter how many translations existed — and in this case, all 28 steps already had full translations sitting unused. Fixed, so all of it displays correctly now."
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
            description: "This preference now does what its description always implied: turn it on, and every new forum topic or app entry you post is automatically followed for you, the same as tapping Follow yourself — no separate step needed. It only applies going forward; anything posted before turning it on isn't touched, since there's nothing to retroactively follow. Forum topics already had their own follow-on-post toggle in the composer, seeded from this preference; app entries get the same treatment now too. Clarified directly after this was found to be misunderstood as a stateless notification filter rather than a real subscription."
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
            description: "Settings was nested inside a second NavigationStack on top of Profile's own — something SwiftUI doesn't support and can desync in unpredictable ways, especially a few pushes deep (Settings > Help > a tutorial or FAQ, for instance). On top of that, every row in Settings (including Help's own entry) was rebuilding its identity from scratch on every re-render instead of keeping a stable one, which could desync navigation further still. Both fixed — Settings now shares Profile's existing navigation stack instead of starting its own, and every row keeps a consistent identity. Reported directly: double-tapping into a Help article could unexpectedly land back out at Home instead of opening the article."
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
            description: "Tapping Read Transcript could open to \"This item is no longer available\" even when the episode's show notes had a transcript right there the whole time — a timing bug where the transcript sheet could open before the already-extracted text finished being handed to it, sending it down a fallback network lookup that 404s for an ordinary embedded transcript. Not tied to any particular transcription tool (compared a Google Gemini-transcribed episode against a VoicePen one directly — both format identically); this was purely about when the sheet opened relative to the data being ready. Fixed by tying the two together so they can no longer land out of step. Reported directly."
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
            description: "Every onboarding step's heading and description, and every What's New entry — this release and all of history — were being built from a code pattern that silently skipped the translation catalog, so non-English speakers saw English text there no matter how many translations already existed. Both are fixed, and the onboarding strings that had never been translatable in the first place are now translated into all 22 supported languages."
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
        HistorySection(title: "Also in 2026.14", items: ChangeItem.archivedFrom2026_14),
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
            tag: .accessibility,
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
            tag: .accessibility,
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
            tag: .accessibility,
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
            tag: .accessibility,
            title: "Back Button Returns VoiceOver Focus",
            description: "Coming back from a Settings, Profile, Discover, or About screen now lands VoiceOver focus on the row you tapped, instead of somewhere unrelated."
        ),
        ChangeItem(
            systemImage: "arrow.down.to.line",
            tag: .accessibility,
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
            tag: .accessibility,
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
            tag: .accessibility,
            title: "Home Always Greets You First",
            description: "Opening Home with new activity or a reading position to resume used to skip straight past the greeting. VoiceOver focus now always lands on the greeting first, with What's New announced right after — instead of two separate \"welcome\" messages competing with each other."
        ),
        ChangeItem(
            systemImage: "arrow.clockwise",
            tag: .accessibility,
            title: "Pull to Refresh No Longer Repeats Itself",
            description: "Pulling to refresh Home and finding something new used to announce the summary, then say the exact same sentence again a moment later when focus landed on the What's New card. It's said once now."
        ),
        ChangeItem(
            systemImage: "scope",
            tag: .accessibility,
            title: "VoiceOver Focus, Cleaned Up Across the App",
            description: "A full pass on where VoiceOver focus lands when a screen opens: the Now Playing screen, Forums, Write a Review, and several account screens (sign in, edit profile, delete account, member profiles, contact a member) now focus something meaningful instead of nothing. Every multi-step wizard (Submit App/Blog/Bug/Podcast, Contact, Change Password/Email, Report a Comment) now focuses its first step reliably and re-checks focus a few times after each Next/Back, instead of a single guess that could go silent on a slower moment. Podcast and Storage settings no longer jump straight to a control."
        ),
        ChangeItem(
            systemImage: "text.alignleft",
            tag: .accessibility,
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
            tag: .accessibility,
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
                tag: .accessibility,
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
        HistorySection(title: "Also in 2026.10", items: [
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
                tag: .accessibility,
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
    ]
}
