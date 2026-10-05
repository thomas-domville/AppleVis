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

    static let currentVersion = "2026.21"

    static let current: [ChangeItem] = [
        ChangeItem(
            systemImage: "text.bubble",
            tag: .fixed,
            title: "Jump to First New Comment Opens Posts Normally",
            description: "Jump to First New Comment now opens a post the same way as choosing it, with the usual Back button, and VoiceOver lands on the first new comment. It used to open a separate view with a Close button."
        ),
        ChangeItem(
            systemImage: "checkmark.circle",
            tag: .improved,
            title: "Mark as Read Syncs with the Website",
            description: "When signed in and online, Mark as Read and Mark All as Read also update your read history on the website."
        ),
        ChangeItem(
            systemImage: "arrow.triangle.2.circlepath",
            tag: .fixed,
            title: "Website Sync Fixes",
            description: "Topics pinned on the website always appear at the top of Forums, and they update when you refresh. When signed in, Home and Forums recognize items you read on the website."
        ),
        ChangeItem(
            systemImage: "globe.europe.africa",
            tag: .improved,
            title: "Submitting Apps From Any Country",
            description: "When you submit an app found in another country's App Store, AppleVis uses the developer's English description when there is one. If the description is only in another language, it's translated into English on your device, with a line saying so. The App Store link now opens in each reader's own country's App Store."
        ),
        ChangeItem(
            systemImage: "exclamationmark.bubble",
            tag: .improved,
            title: "Clearer Messages When a Post Doesn't Go Through",
            description: "When the site turns down a topic, comment, reply, edit, or app submission, AppleVis now tells you which part to fix. VoiceOver reads these messages as soon as they appear. If a post still won't go, Copy Details makes a short note of what went wrong for you to send us. Submit an App also checks the length of version numbers before you send."
        ),
        ChangeItem(
            systemImage: "globe",
            tag: .fixed,
            title: "App Submissions in Other Languages",
            description: "Choosing Not applicable for VoiceOver Performance or Button Labelling no longer stops an app submission when your iPhone isn't set to English."
        ),
        ChangeItem(
            systemImage: "bubble.left.and.text.bubble.right",
            tag: .fixed,
            title: "New Topics Post to Their Forum",
            description: "A new forum topic could close as if it had posted, but never appear. The forum you chose wasn't being sent with it. It is now. Confirmations such as Topic posted are also spoken after the screen closes, so VoiceOver no longer cuts them off. If a topic needs a moderator's approval, the app now says so."
        ),
        ChangeItem(
            systemImage: "checklist.unchecked",
            tag: .improved,
            title: "Clearer About What the Mouse Checked",
            description: "In Ask the Mouse, results the Mouse didn't read are now listed under More From AppleVis, Not Checked. They share words with your question, but the Mouse hasn't confirmed that they answer it."
        ),
        ChangeItem(
            systemImage: "mic",
            tag: .fixed,
            title: "Latest Podcasts and Bug Reports from the Mouse",
            description: "Asking the Mouse for the latest AppleVis podcast now brings the newest episodes, not older ones that happened to match. And questions that name a version, such as VoiceOver bugs in macOS 27, now find related bug reports."
        ),
        ChangeItem(
            systemImage: "magnifyingglass",
            tag: .fixed,
            title: "Better App Answers from the Mouse",
            description: "Asking the Mouse for Mac, Apple Watch, or Apple TV apps of a certain kind, such as Apple Watch fitness apps, found nothing. It now finds them. Questions using short terms such as RPG, GPS, or OCR find the right apps. And when several AppleVis blog posts match, such as yearly Golden Apples winners, the newest comes first."
        ),
        ChangeItem(
            systemImage: "square.and.arrow.up",
            tag: .new,
            title: "Share or Print Help Articles",
            description: "Every Help article now has Share or Print. It shares the article as plain text, to send to another device, a note taker, or a braille embosser. That way, steps such as how to force restart are at hand even when the device they're about isn't responding."
        ),
        ChangeItem(
            systemImage: "list.bullet.rectangle",
            tag: .new,
            title: "Quick Reference in Help",
            description: "Help has a new Quick Reference section, written by AppleVis. It covers VoiceOver and braille on iPhone, iPad, Mac, Apple Watch, and Apple TV, typing, low vision features, image and scene descriptions, the web, everyday tasks, what to do when VoiceOver stops talking, restarting and updating your devices, getting help, and a glossary of terms. Each article links to the Apple page it was checked against. Ask the Mouse can answer from it too."
        ),
        ChangeItem(
            systemImage: "questionmark.bubble",
            tag: .improved,
            title: "When the Mouse Finds No Answer",
            description: "When Ask the Mouse can't find a direct answer but does find related AppleVis results, its reply now says so and points you to the results below it."
        ),
        ChangeItem(
            systemImage: "hand.point.up.braille",
            tag: .improved,
            title: "Braille Command Questions",
            description: "Ask the Mouse now knows Apple's page of common braille display commands for VoiceOver on iPhone and iPad. A question such as What's the braille command for Control Center? gets a link to it under Need More Help."
        ),
        ChangeItem(
            systemImage: "pawprint",
            tag: .accessibility,
            title: "Hear the Mouse Searching",
            description: "With VoiceOver, Ask the Mouse now plays a soft patter and a light tap every second while it searches, so you know it's still working. After a quiet stretch, VoiceOver says Still searching. The searching row also says how long the search has taken."
        ),
        ChangeItem(
            systemImage: "checkmark.circle",
            tag: .improved,
            title: "Mark This Group as Read in Fetch",
            description: "In Fetch, Mark This Group as Read is available on every comment and on the group heading. It marks the post and all its comments as read, matching the website."
        ),
        ChangeItem(
            systemImage: "text.alignleft",
            tag: .fixed,
            title: "Long Comments in Fetch",
            description: "With VoiceOver, a very long comment in Fetch could make swiping right skip the rest of Fetch and land on the tab bar. On screen, long posts and comments now show their first few lines, with Show Full Comment to see the rest. VoiceOver still reads each comment in full, as one item."
        ),
        ChangeItem(
            systemImage: "dog",
            tag: .fixed,
            title: "Only New Comments in Fetch",
            description: "Fetch could list older comments as new, such as one posted two weeks earlier. That happened when someone replied to an earlier comment, or a comment had been removed. Fetch now picks new comments by when they were posted, and the count above them matches what is listed."
        ),
        ChangeItem(
            systemImage: "arrow.clockwise",
            tag: .accessibility,
            title: "Coming Back to Home",
            description: "When you come back to AppleVis after more than five minutes, Home refreshes. VoiceOver now stays where you were and says Home updated, followed by what's new. Before, it moved you to the What's New summary and could read the summary more than once."
        ),
        ChangeItem(
            systemImage: "sparkles",
            tag: .fixed,
            title: "What's New Summary on Home",
            description: "Activating the What's New summary on Home often seemed to do nothing. It now goes somewhere useful in each view. In All, it takes you to the item you last opened. In New, it goes to the first unread item. In Fetch, it goes to the first post. In Nibbles, it goes to the start of Nibbles."
        ),
        ChangeItem(
            systemImage: "checkmark.circle",
            tag: .improved,
            title: "Done Button in Settings",
            description: "Settings now opens on top of Profile, with Done at the top right of every Settings screen. Done closes Settings and takes you back to what you were doing, so you no longer need to choose Back several times."
        ),
        ChangeItem(
            systemImage: "text.badge.checkmark",
            tag: .improved,
            title: "Clearer Wording for New",
            description: "Home's New view and summary used to say since your last visit. That wasn't accurate, because anything you haven't read stays in New until you open it or mark it as read. They now say you haven't read it yet."
        ),
        ChangeItem(
            systemImage: "airpods",
            tag: .improved,
            title: "AirPods Skip Forward and Back",
            description: "A double press on AirPods now skips forward, and a triple press skips back, by the amounts set in Settings > Podcasts. Before, a triple press went back to the start of the episode. To get the old behaviour, change Headphone Controls in Settings > Podcasts."
        ),
        ChangeItem(
            systemImage: "play.rectangle",
            tag: .new,
            title: "Open Player on Play",
            description: "A new setting in Settings > Podcasts opens the player when you play an episode from a list. It is off by default. You can always open the player from the mini player at the bottom of the screen."
        ),
        ChangeItem(
            systemImage: "lock.iphone",
            tag: .fixed,
            title: "Episode Length on the Lock Screen",
            description: "The Lock Screen and Control Center now show how long a podcast episode is, instead of zero seconds. The time shown also updates after you skip. Skipping forward just after an episode starts no longer takes you back to the beginning."
        ),
        ChangeItem(
            systemImage: "hand.point.up.braille",
            tag: .accessibility,
            title: "Finding the Player with VoiceOver",
            description: "The mini player now reads as a button that opens the player. The first few times you play an episode from a list, VoiceOver says that the player is at the bottom of the screen."
        ),
    ]

    static let archivedFrom2026_20: [ChangeItem] = [
        ChangeItem(
            systemImage: "checkmark.bubble",
            tag: .fixed,
            title: "Fetch Remembers What You've Read",
            description: "On a busy topic, comments you had marked as read could come back in Fetch with the new ones. Fetch now always loads the latest comments."
        ),
        ChangeItem(
            systemImage: "dog",
            tag: .fixed,
            title: "No More 0 New Comments in Fetch",
            description: "Fetch and New no longer list a post with 0 new comments. A post that was only edited is left out. And a new comment is now counted, even when another comment on the post was removed."
        ),
        ChangeItem(
            systemImage: "person.crop.circle.badge.checkmark",
            tag: .new,
            title: "Ask the Mouse Gets to Know You",
            description: "Tell the Mouse which devices and features you use in About Me. When a question doesn't say, it leads with the answer for your setup. Past Conversations keeps your last 10 conversations, so you can read one again or carry on from it. About Me stays on this device."
        ),
        ChangeItem(
            systemImage: "sparkle.magnifyingglass",
            tag: .improved,
            title: "Smarter Ask the Mouse Answers",
            description: "When a question is too vague, such as How do I turn it off?, the Mouse asks what you mean and offers a few choices. For a question like Why don't I get notifications?, it checks your AppleVis settings, without changing them. Guides that answered your questions well are read first next time. A saved answer now says when a guide or discussion it came from has changed, and offers to ask again."
        ),
        ChangeItem(
            systemImage: "text.bubble",
            tag: .improved,
            title: "Ask the Mouse Understands More Questions",
            description: "Ask the Mouse now finds apps for the Mac, Apple Watch, and Apple TV, not just iPhone and iPad. Questions about one app, such as Instagram, find the right app entry. News questions can be answered from AppleVis blog posts. It also understands voice over written as two words, brail, and British spellings, follow-up questions like And on the Mac?, and questions asked in other languages."
        ),
        ChangeItem(
            systemImage: "hand.raised",
            tag: .improved,
            title: "Clearer App Privacy Details",
            description: "Privacy details now explain more clearly what AppleVis handles, what stays on your device, and what can be sent or synced. App Store privacy declarations were also updated for the app and Share Extension."
        ),
        ChangeItem(
            systemImage: "trophy",
            tag: .improved,
            title: "Golden Apples and Member Favorites in Ask the Mouse",
            description: "When you ask the Mouse for apps, AppleVis Golden Apple winners, honorable mentions, and nominees from 2019 on now say so and come first among equally good matches, followed by the apps members have talked about most. Each app shows how many member comments it has. For questions answered in the forums, the Mouse now prefers a discussion members have actually replied to."
        ),
        ChangeItem(
            systemImage: "signpost.right",
            tag: .new,
            title: "Ask the Mouse Always Has Somewhere to Send You",
            description: "For any question about an Apple device, Need More Help? now offers Search Apple Support, and the Mouse can link to the right page from Apple's user guides for iPhone, iPad, Apple Watch, Mac, AirPods, and Apple TV. When the Mouse couldn't answer, signed-in members can choose Suggest This Topic to AppleVis to send just the question to the editorial team, so missing guides get written."
        ),
        ChangeItem(
            systemImage: "books.vertical",
            tag: .improved,
            title: "Ask the Mouse Knows Where to Look",
            description: "For common subjects like VoiceOver gestures, braille, and keyboards, the Mouse now always reads AppleVis's essential guide on the subject. It also checks the Bug Tracker when something isn't working, reads what members say about an app you name, and uses podcast transcripts. When AppleVis doesn't have the answer, it can point you to Apple's guide for your device, a Be My Eyes help page, or Hadley's free VoiceOver lessons."
        ),
        ChangeItem(
            systemImage: "arrow.up.forward.square",
            tag: .improved,
            title: "Ask the Mouse Points You Further",
            description: "When AppleVis doesn't have the answer, Need More Help? can now offer Apple's own guide on the subject, such as Apple's list of braille display commands. Search the Web uses a clearer search the Mouse writes for you, and shows what it will search for. Questions that have nothing to do with Apple, accessibility, or AppleVis get a friendly note instead of a search."
        ),
        ChangeItem(
            systemImage: "text.magnifyingglass",
            tag: .improved,
            title: "Ask the Mouse Finds the Right Guide",
            description: "The Mouse now searches every way of wording your question at once, and reads the guides that actually mention what you asked about, so a question like What does a three-finger double tap do? finds the complete gesture list. Answers come in the Mouse's own warm voice, with when each source was posted, and other sources are listed newest first, each saying whether it agrees. When it finds only something close, like a Mac shortcut for an iPhone question, it tells you that honestly instead of passing it off as the answer."
        ),
        ChangeItem(
            systemImage: "checkmark.circle",
            tag: .improved,
            title: "Marking Things as Read in Fetch",
            description: "In Fetch, Mark This Group as Read, on an item's heading or its last comment, clears the post and all its new comments. VoiceOver says Group marked as read, then moves to the next group, even far down the list. It used to be left in the wrong place."
        ),
        ChangeItem(
            systemImage: "rectangle.split.3x1",
            tag: .accessibility,
            title: "Home's Views Are Separate Items Again",
            description: "With VoiceOver, All, New, Fetch, and Nibbles at the top of Home are separate items again. Swipe right to move from one to the next, and double-tap to choose one. Choosing a view still tells you what it shows."
        ),
    ]

    static let archivedFrom2026_19: [ChangeItem] = [
        ChangeItem(
            systemImage: "bubble.left.and.text.bubble.right",
            tag: .improved,
            title: "Start the Conversation",
            description: "A forum topic with no replies yet now shows its Community Discussion section, like every other page. Wherever there are no comments yet, a friendly line says so, with a button to be the first to comment or reply."
        ),
        ChangeItem(
            systemImage: "gauge.with.dots.needle.67percent",
            tag: .new,
            title: "Listening Speed for Listen to Fetch",
            description: "Listen to Fetch now reads in the voice and speed you chose for VoiceOver or Spoken Content. To change it, use Listening Speed in Fetch and choose Slow, Normal, Fast, Faster, or Fastest. If you change it while listening, the current sentence starts again at the new speed."
        ),
        ChangeItem(
            systemImage: "text.alignleft",
            tag: .fixed,
            title: "No More Empty Stop in Fetch",
            description: "After a post with no new comments, VoiceOver used to stop on an empty item with a click. That empty item is gone."
        ),
        ChangeItem(
            systemImage: "character.cursor.ibeam",
            tag: .improved,
            title: "Question and Search Lengths",
            description: "Questions to the Mouse can be up to 300 characters, and searches in Discover and the App Directory up to 150. When you're close to the limit, VoiceOver says how many characters are left. Anything longer is shortened, and you're told. When Apple Intelligence can't plan a search, the Mouse now sends only your question's main words to the AppleVis website, never the whole question."
        ),
        ChangeItem(
            systemImage: "text.magnifyingglass",
            tag: .improved,
            title: "Ask the Mouse Answers More Questions",
            description: "When the best parts of a guide don't answer your question, the Mouse now reads the rest of the guide and its comments, a part at a time. Answers with steps are numbered, and each step is read on its own. You Might Also Ask suggests questions to ask next. The first answer comes sooner, and if Apple Intelligence can't answer, the Mouse tells you why. On screen, the answer appears as it's written."
        ),
        ChangeItem(
            systemImage: "bubble.left.and.text.bubble.right",
            tag: .improved,
            title: "Ask the Mouse Gets a Friendlier Look",
            description: "Ask the Mouse now looks more like a chat with the Mouse. The whole Mouse greets you with a little hop, your question sits in a small bubble, and each answer appears in a speech bubble with the Mouse beside it. While searching, the Mouse holds what it's looking through, such as a book for Help. Sources and results have icons for their type, the Mouse cheers when an answer helped, and saved answers show the Mouse's face. None of it changes what VoiceOver reads, and it all stays still with Reduce Motion on."
        ),
        ChangeItem(
            systemImage: "list.bullet.indent",
            tag: .accessibility,
            title: "Headings Reach Back to the Top of Home's Lists",
            description: "In Home's All and New views, once you'd scrolled far down, the Headings rotor couldn't go back up to the Latest Activity or New Activity heading. It now can, from anywhere in the list. That heading was also always in English, and now appears in your language. Reported directly."
        ),
        ChangeItem(
            systemImage: "text.line.first.and.arrowtriangle.forward",
            tag: .accessibility,
            title: "Read Long Mouse Answers a Part at a Time",
            description: "With VoiceOver, a long Ask the Mouse answer, such as the answer to What's new?, was one long item. Swipe up or down on it to choose Ungroup Answer, and each paragraph, or each sentence of a single long paragraph, becomes its own item. That's easier to follow, especially on a braille display. Group Answer joins it back together. Short answers stay as one item. Requested directly."
        ),
        ChangeItem(
            systemImage: "text.magnifyingglass",
            tag: .new,
            title: "Ask the Mouse Answers From Every Result",
            description: "Results under More From AppleVis now each come with a line saying what that page tells you about your question, so you don't have to open every guide to find out. Pages that don't answer it are left out, and pages that say the same thing are listed together. If the main answer comes up empty but a result has it, that becomes the answer. Commands and gestures are copied exactly, guides written for an older iOS are marked, and opening a guide from an answer takes you straight to the paragraph it came from. You can also tell the Mouse whether an answer helped, and the same question asked again within an hour is answered straight away. Requested directly."
        ),
        ChangeItem(
            systemImage: "arrow.counterclockwise",
            tag: .improved,
            title: "Start Over Is Right After Ask",
            description: "In Ask the Mouse, Start a New Conversation was at the very bottom, after every answer, and sounded like it started a forum topic. It's now called Start Over and sits right after Ask. It clears the answers on screen so your next question starts fresh, and keeps your saved answers and recent questions. Each recent question can now be removed on its own, and recent questions sync with your other devices through iCloud when Saved Items sync is on. Suggested directly."
        ),
        ChangeItem(
            systemImage: "globe",
            tag: .new,
            title: "Choose the Search Engine for Search the Web",
            description: "Search the Web in Ask the Mouse always used DuckDuckGo. Settings > General now has Web Search, where you can choose DuckDuckGo, Google, Bing, or Ecosia. Results open the way your Web Links setting says: in AppleVis or in your default browser. Requested directly."
        ),
        ChangeItem(
            systemImage: "bookmark",
            tag: .new,
            title: "Copy, Share, and Save Mouse Answers",
            description: "Each Ask the Mouse answer now has actions: Copy Answer, Copy Answer with Sources, Share Answer, Open Source, Save Answer, and Ask a Follow-Up. With VoiceOver, swipe up or down on the answer. Otherwise, touch and hold it. Saved answers appear in For You > Saved under Mouse Answers and sync with iCloud. Apps in an answer can be saved and shared too, and Need More Help? is now a heading, so you can jump to Ask in the Forums. Requested directly."
        ),
        ChangeItem(
            systemImage: "person.2.wave.2",
            tag: .improved,
            title: "Ask the Mouse Includes Members' Tips",
            description: "When the Mouse answers from a guide, it now also reads members' comments on that guide, where people often add tips or note what's changed. For questions about Apple devices or people's experiences, it also reads a matching forum discussion. Help and guides come first, and when part of an answer comes from members, the Mouse says so. Suggested directly."
        ),
        ChangeItem(
            systemImage: "questionmark.bubble",
            tag: .fixed,
            title: "Ask the Mouse Shows Only Related Results",
            description: "Asking the Mouse what's new in the app also listed forum topics and podcasts under More From AppleVis that had nothing to do with the question. Questions about the app's What's New, your settings, or your saved items are now answered from the app alone. For other questions, More From AppleVis only lists results whose titles or descriptions match what you asked. Reported directly."
        ),
        ChangeItem(
            systemImage: "switch.2",
            tag: .accessibility,
            title: "View Switchers Now Say What Each View Shows",
            description: "With VoiceOver, the switchers like All, New, Fetch, and Nibbles on Home were read one option at a time, such as \"All, 1 of 4, selected\". Their descriptions and swipe up or down to change views never came through. Each switcher is now one item: you hear its name, the current choice, and a short description, and swipe up or down to change it. This covers Home, Nibbles' Past Week and Past Month, Card Density, Web Links, and the Platform choice in Submit an App. Reported directly."
        ),
        ChangeItem(
            systemImage: "bubble.left.and.bubble.right",
            tag: .fixed,
            title: "Nibbles Picks This Week's Busiest Discussions",
            description: "Nibbles chose its popular discussions by how many comments each topic had ever received, so a long-running topic with one new comment could outrank a new one with dozens this week. It now picks the topics with the most comments during the week or month you're viewing. Past Week is also chosen on its own, instead of being cut down from the month's list. Each discussion shows how many new comments it had. Reported directly."
        ),
        ChangeItem(
            systemImage: "iphone",
            tag: .fixed,
            title: "Submit an App Records the iOS You Tested On",
            description: "The iOS Version field on an app entry is the iOS it was tested on, but Submit an App filled it in with the oldest iOS the app supports. It's now called iOS Version Tested and is filled in with your device's iOS version. You can change it if you tested on another device. Reported directly."
        ),
        ChangeItem(
            systemImage: "list.number",
            tag: .fixed,
            title: "Nibbles' Summary Matches the Order You Read It",
            description: "The summary at the top of Nibbles listed what's inside in a different order from the sections below it: discussions came third and blog posts last. It now follows the sections: apps, podcast episodes, blog posts, guides, then discussions. The blog post count also no longer includes the App Pick of the Month, which has its own section. Reported directly."
        ),
        ChangeItem(
            systemImage: "checkmark.circle.badge.xmark",
            tag: .fixed,
            title: "Mark as Read Clears Items From New Right Away",
            description: "In New, using Mark as Read from an item's touch-and-hold menu didn't remove the item until Home reloaded. With VoiceOver, some items also listed Mark as Read twice in the Actions rotor, and one of them had the same problem. The item now leaves New straight away, Mark as Read is listed once, and VoiceOver moves to the next item. Reported directly."
        ),
        ChangeItem(
            systemImage: "checkmark.circle",
            tag: .improved,
            title: "Mark Fetch Items and Comments as Read",
            description: "In Fetch, Mark as Read on an item's heading now removes the item straight away, and VoiceOver moves to the next item instead of losing its place. It's also in the touch-and-hold menu. A new Mark Read Up to Here, on each comment, marks that comment and the ones before it as read, so only newer comments stay. Swipe right on a comment to use it, or find it in the Actions rotor. Suggested directly."
        ),
        ChangeItem(
            systemImage: "list.bullet.indent",
            tag: .accessibility,
            title: "Headings Reach Every Item in Fetch",
            description: "In Fetch, VoiceOver's Headings rotor only found items near where you were, so you had to swipe up or down before you could jump to an item further away. It now lists every item in Fetch and goes straight to the one you choose. Reported directly."
        ),
    ]

    static let archivedFrom2026_18: [ChangeItem] = [
        ChangeItem(
            systemImage: "questionmark.bubble",
            tag: .new,
            title: "Ask the Mouse",
            description: "Ask a question in your own words, and the Mouse answers from Help, AppleVis guides, the App Directory, and the rest of AppleVis. Ask how to do something, find a fully accessible app, or look for a discussion. Answers say where they came from, and the Mouse can take you to the right screen or, with your OK, change a setting for you. If it can't find something, it suggests asking the community in the Forums. Find it on Home next to Post, at the top of Help, above Discover search results, or say \"Ask the AppleVis Mouse\" to Siri. It needs Apple Intelligence and runs on your device. Requested directly."
        ),
        ChangeItem(
            systemImage: "magnifyingglass",
            tag: .improved,
            title: "Help Search Reads Whole Articles",
            description: "Searching in Help used to look only at article titles and summaries, so something mentioned inside an article couldn't be found. It now searches the full text of every article."
        ),
        ChangeItem(
            systemImage: "magnifyingglass.circle",
            tag: .improved,
            title: "Spotlight Finds Help and Your Saved Items",
            description: "iOS Search now finds AppleVis Help articles, so searching for a setting such as Trim Silence brings up the article that explains it. Everything you've saved or followed is found too, even if you saved it on another device. Choose a result to open it in AppleVis. Requested directly."
        ),
        ChangeItem(
            systemImage: "text.below.photo",
            tag: .improved,
            title: "Home's Views Now Say What They Show",
            description: "Each of Home's views, All, New, Fetch, and Nibbles, now has a short description under the picker, such as \"Only what's changed since your last visit.\" With VoiceOver, you hear it as a hint on the picker and again when you switch views. In other languages, the names All and New were also shown in English. They're now translated."
        ),
        ChangeItem(
            systemImage: "sparkles",
            tag: .improved,
            title: "Mouse Recap Is Now Nibbles",
            description: "Mouse Recap has a new name: Nibbles. It's still the Mouse's bite-sized roundup of the best new apps, podcasts, discussions, guides, and blog posts from the past week or month. You'll find it at the top of Home, right after Fetch. The Mouse nibbles, and Goldie fetches."
        ),
        ChangeItem(
            systemImage: "newspaper",
            tag: .new,
            title: "Fetch: Everything New, Ready to Read",
            description: "Home has a new view called Fetch, right after New. Goldie the golden retriever fetches everything new, with each post followed by its new comments in full. Swipe straight through to read it all without opening anything, or double-tap a comment to open it in its thread. With VoiceOver, the Headings rotor jumps from item to item. Listen to Fetch reads everything aloud, and you can pause, skip a comment, or move between items. Suggested directly."
        ),
        ChangeItem(
            systemImage: "face.smiling",
            tag: .new,
            title: "Meet the Mouse and Goldie",
            description: "The Mouse, who guides you through the Welcome Tour and gives Nibbles its name, is now a little character you can see. You'll find the Mouse in each chapter of the tour, at the top of Nibbles, and on a few empty screens in For You. Goldie the golden retriever, the friend behind the Golden Retriever Bark sound, joins the Mouse on the first Setup screen. When you preview Mouse Squeak or Golden Retriever Bark in Setup, that character hops. With VoiceOver, each picture is described once and skipped after that, so it adds no extra swipes. With Reduce Motion on, both stay still."
        ),
        ChangeItem(
            systemImage: "text.bubble",
            tag: .improved,
            title: "Guideline Reminders Catch More Unkind Wording",
            description: "The guideline reminders missed some strong language, such as other forms of the f-word and censored spellings. These now need changing before you post, like other strong language. Milder crude words, and put-downs aimed at another member, now get a friendly reminder while you write. You can still post, but it's worth rewording. Strong disagreement about an app or a product is still welcome. Just mentioning your own website or podcast, like \"I was editing my website,\" no longer counts as self-promotion."
        ),
        ChangeItem(
            systemImage: "key",
            tag: .new,
            title: "Remember Me When You Sign In",
            description: "The sign-in screen has a new Remember me switch. The AppleVis website signs you out about every three weeks. With Remember me on, the app signs you back in for you, so you stay signed in. Your password is kept securely in your iPhone's Keychain, only on that iPhone, and it's removed when you sign out. If you change your password in the app, it's updated too. Suggested directly."
        ),
        ChangeItem(
            systemImage: "plus.circle",
            tag: .improved,
            title: "The Add Button Is Now Called Post",
            description: "The plus button at the top of Home and Forums, which starts a new topic or app entry, is now called Post instead of Add. It matches the AppleVis website, and with VoiceOver, Add could sound like Ad. Suggested directly."
        ),
        ChangeItem(
            systemImage: "person.badge.key",
            tag: .fixed,
            title: "Signing In Again Is Now Easy",
            description: "For your security, the AppleVis website signs you out about every three weeks. The app didn't notice, so a reply, a post, or an app submission could fail with a confusing error. Now the app asks you to sign in again, and what you were sending goes through afterwards. Nothing you wrote is lost. When you open the app after a few weeks away, it checks too, so you can sign in before you start writing. Reported directly."
        ),
        ChangeItem(
            systemImage: "arrow.clockwise",
            tag: .fixed,
            title: "NEW Badges on Home Keep Up with New Comments",
            description: "Home sometimes showed an older copy of the latest activity, for up to half an hour for forum topics and several hours for blog posts, podcasts, and app entries. Pulling down to refresh didn't help. So a topic could get new comments without showing a NEW badge, while the items around it did. Home now always gets the latest activity, and uses the saved copy only when you're offline. Reported directly."
        ),
        ChangeItem(
            systemImage: "sparkles",
            tag: .new,
            title: "Smarter Guideline Reminders with Apple Intelligence",
            description: "On iPhones with Apple Intelligence, guideline reminders are now double-checked before you see them. Apple Intelligence reads your whole draft and skips a reminder that clearly doesn’t fit, like a tone reminder on a friendly thank-you. It never adds reminders, and the checks for strong language and images always apply. It all happens on your iPhone. You can turn it off in Settings > Intelligence > Smarter Guideline Reminders. Suggested directly."
        ),
        ChangeItem(
            systemImage: "checkmark.bubble",
            tag: .improved,
            title: "Fewer Unneeded Guideline Reminders",
            description: "The guideline reminders you see while writing were checked against a month of real AppleVis posts, and most false alarms are gone. Friendly or excited posts no longer get tone or punctuation reminders. Asking several questions about one subject no longer counts as several topics. Mentioning a survey is fine; only asking people to take one needs approval. Sharing an email address on purpose, like a developer’s TestFlight contact, gets a gentle note instead of a privacy warning. Reported directly."
        ),
        ChangeItem(
            systemImage: "clock.arrow.circlepath",
            tag: .fixed,
            title: "App Entries Show When the Latest Comment Came In",
            description: "An app entry's page said its most recent comment was from when the entry itself was last edited. A comment from a few hours ago could show as 2 weeks ago, even though Home showed it as new. The page now shows when the newest comment really came in. Saving or following an app entry also records its real latest activity. Reported directly."
        ),
        ChangeItem(
            systemImage: "text.cursor",
            tag: .fixed,
            title: "Forms Move VoiceOver to Each New Step",
            description: "In Contact Us, when you went from writing your message to the preview, VoiceOver focus didn't move to the preview heading. The same could happen in Submit an App, Submit a Blog Post, Submit a Podcast, Submit a Bug Report, when reporting a post or comment, and in the account security steps. The keyboard now closes first, and VoiceOver moves to the new step's heading. In Contact Us, the bug report tips on the message step were also read twice. They're now one item. The type you chose and the line under it are also one item now. Focus also moves almost at once now, instead of after a pause of 2 to 3 seconds. Reported directly."
        ),
        ChangeItem(
            systemImage: "arrow.uturn.backward",
            tag: .fixed,
            title: "Closing a Form Returns You to Where You Were",
            description: "After you sent or cancelled Contact AppleVis, VoiceOver went to the top of the screen instead of the Contact AppleVis button. VoiceOver now goes back to the button you used. This works from Profile, Discover, and Help. It also works for the Submit buttons in Discover, and for Replay Welcome Tour in Profile. Reported directly."
        ),
        ChangeItem(
            systemImage: "chevron.backward",
            tag: .improved,
            title: "Back Is Now Next to Cancel in Forms",
            description: "In Contact AppleVis, the Submit forms, reporting a post or comment, and the account security steps, Back was below Cancel. With VoiceOver, you had to swipe past the title and Next to reach it. Back is now right next to Cancel at the top of the screen. Swiping goes Cancel, Back, the title, then Next. Cancel stays in the same place on every step. Reported directly."
        ),
        ChangeItem(
            systemImage: "doc.text",
            tag: .improved,
            title: "Better File Import for Blog Drafts",
            description: "In Submit a Blog Post, Import File now works with plain text, Markdown, Rich Text, and web page files. A note under Import lists them. Web pages come in as readable text, not HTML tags, and links keep their addresses. Rich Text keeps its links too. Text files from older Windows and Mac apps now import instead of failing. Files that don't import well, like spreadsheets and code, can no longer be chosen. For a Word or Pages document, export it as Rich Text first, or copy the text and use Paste. Suggested directly."
        ),
        ChangeItem(
            systemImage: "xmark.circle",
            tag: .fixed,
            title: "Cancel Works on Every Step of Submit a Blog Post",
            description: "On the first and last steps of Submit a Blog Post, Cancel did nothing. Then, when you went Back to step 2, you were asked whether to discard your submission, even though you hadn't just chosen Cancel. Cancel now asks right away on every step. Reported directly."
        ),
        ChangeItem(
            systemImage: "arrow.up.arrow.down",
            tag: .improved,
            title: "Your Email Comes After the Description in Bug Reports",
            description: "In Submit a Bug Report, the email box sat between the title and the description. It now comes after the description, so the title and description are together. Reported directly."
        ),
        ChangeItem(
            systemImage: "number",
            tag: .improved,
            title: "Clearer Help With Your Apple Feedback Number",
            description: "In Submit a Bug Report, the note about the Apple Feedback number was hard to follow. It now explains that AppleVis only accepts bugs you've already reported to Apple, and where your number comes from. A new Open Feedback Assistant button takes you to Apple's website to report the bug. The note now comes before the box, so you hear it first. Reported directly."
        ),
        ChangeItem(
            systemImage: "waveform",
            tag: .improved,
            title: "Submit a Podcast Says Which Audio Files Work",
            description: "In Submit a Podcast, a note before Choose Audio File now says what AppleVis accepts: one MP3, M4A, or WAV file, up to 200 MB. Other formats can no longer be chosen. A file that's too large is caught when you choose it, not after you submit. This also applies to audio shared into AppleVis from another app. For a larger file, share it with a service like Dropbox, then send the link using Contact AppleVis. Reported directly."
        ),
        ChangeItem(
            systemImage: "arrow.right.circle",
            tag: .improved,
            title: "In Submit an App, Next Replaces Review & Submit",
            description: "On step 2 of Submit an App, the button was called Review & Submit, which sounded like it would send your submission. It only took you to the review step. It's now called Next, like the other forms, and its hint says it goes to step 3 so you can check everything first. Nothing is sent until you choose Submit on the review step. Reported directly."
        ),
        ChangeItem(
            systemImage: "app.badge",
            tag: .improved,
            title: "Existing App Entries Open in the App",
            description: "When you submit an app that may already be in the App Directory, the review step lists the matching app entries. Choosing one used to open the AppleVis website in a browser. It now opens the app entry's own page in the app, and when you go back, your submission is still there and VoiceOver returns to the entry you chose. Entries with a similar name can now be opened too, so you can check before continuing. Reported directly."
        ),
    ]

    static let archivedFrom2026_17: [ChangeItem] = [
        ChangeItem(
            systemImage: "hand.thumbsup",
            tag: .new,
            title: "Community Picks: The Apps Members Recommend",
            description: "Discover has a new Community Picks button next to Apps. It shows the apps AppleVis members recommend. Choose Latest to see what people are recommending now, or Most Recommended to see long-time favorites. You can count recommendations from the past month up to all time, and choose a platform. Each app appears once, with how many people recommended it and when it was last recommended. The lists fill in once a small update to the AppleVis website is finished. Suggested directly."
        ),
        ChangeItem(
            systemImage: "character.bubble",
            tag: .fixed,
            title: "The Rest of AppleVis Now Speaks Your Language",
            description: "With the app set to another language, some places were still in English. These included error messages, empty screens, several settings, Mouse Recap, theme and notification sound names, and the messages from Share to AppleVis. They're now translated into all 22 languages. Siri also understands AppleVis phrases in your language, and counts like \"3 replies\" follow your language's own plural rules. In other languages, the monthly Mouse Recap was also treated as a weekly one. It now uses the right heading and shows a full month's worth."
        ),
        ChangeItem(
            systemImage: "book.closed",
            tag: .fixed,
            title: "Cleaner Guide Labels in Mouse Recap",
            description: "Mouse Recap's How-To Corner now has one Guides & Tutorials subheading, and each item no longer repeats Guide or Tutorial in its details. VoiceOver also skips the repeated category label as you move through the list."
        ),
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
            systemImage: "text.alignleft",
            tag: .improved,
            title: "Plainer Wording Throughout the App",
            description: "Help, setup, tips, guideline reminders, and the explanations in each form now use the same plain, short style as the Welcome Tour. Tips, guideline reminders, Home's greeting, and the setup summary were also English in every language. They're now translated too."
        ),
        ChangeItem(
            systemImage: "figure.walk",
            tag: .improved,
            title: "A Clearer, Easier-to-Follow Welcome Tour",
            description: "The AppleVis editorial team rewrote the Welcome Tour in plainer language, with short paragraphs instead of long blocks of text. With VoiceOver or a braille display, each paragraph is now its own stop, so it's easier to pause, go back, or skip ahead. The tour also covers the newest features, like Jump to First New Comment and the podcast Start Over button."
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
            description: "Home only counted new comments on things you'd opened before. Anything you hadn't opened showed no count, and stopped counting as new the next time the app opened. Now everything on Home counts new comments the same way, and the count keeps adding up until you open the item or mark it as read. A topic posted since your last visit shows NEW and its comment count, and the summary at the top only calls something a new topic if it really is. Reported directly."
        ),
        ChangeItem(
            systemImage: "quote.bubble",
            tag: .fixed,
            title: "Apostrophes Now Copy, Share, and Read Aloud Correctly",
            description: "Copying, sharing, or using Read Aloud on a post or comment could turn apostrophes and quotation marks into web codes, and Read Aloud would speak the codes. The same codes could appear in translations, and in VoiceOver on paragraphs with filtered language. This is fixed everywhere, so what you copy, share, or hear matches what's on screen."
        ),
        ChangeItem(
            systemImage: "speaker.slash",
            tag: .fixed,
            title: "Telling VoiceOver to Hush No Longer Triggers a Tone Reminder",
            description: "Writing something like \"shut up, Siri\" or \"I wish VoiceOver would shut up\" used to bring up a reminder about respectful discussion, as if it were aimed at another member. Telling VoiceOver, Siri, a named voice such as Daniel or Samantha, or your phone to shut up no longer does. A \"shut up\" aimed at a person still gets the reminder."
        ),
        ChangeItem(
            systemImage: "doc.text",
            tag: .fixed,
            title: "Editing a Topic, Comment, or Review No Longer Shows Raw HTML",
            description: "Editing a forum topic, comment, review, app entry, blog post, guide, bug report, or podcast episode used to fill the edit box with the page's HTML code, such as <p> tags, instead of your original text. Saving could also change the formatting. Editing now starts from your original text and keeps the post's formatting when you save."
        ),
        ChangeItem(
            systemImage: "list.number",
            tag: .improved,
            title: "Every Wizard Now Matches the Welcome Tour's Step Format",
            description: "Setup, Contact Us, the Submit forms, Report a Comment, and Change Password or Email each had a slightly different step header. Some showed \"Step X of Y\" and some didn't, and the Back button moved around. They now share one step header with the Welcome Tour, Edit Profile, and Bio Assist: a Back button, \"Step X of Y\" where it applies, and a heading that VoiceOver reads once. Requested directly."
        ),
        ChangeItem(
            systemImage: "wand.and.stars",
            tag: .improved,
            title: "Editing and Posting Feel More Alike Now, With a Few New Touches",
            description: "Every edit and compose screen now opens with the same short heading and description, so it's clear what you're about to do. Screens that were missing the Rewrite button now have it, including editing and commenting on app entries, guides, blogs, podcasts, and bug reports. There are also a few small visual touches: the Rewrite button bounces when it finishes, the text box briefly highlights when it changes, and guideline reminders fade in. The Submit forms and Contact Us have the same touches, and their Submit button shows a spinner while sending. Requested directly."
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
        HistorySection(title: "Also in 2026.20", items: ChangeItem.archivedFrom2026_20),
        HistorySection(title: "Also in 2026.19", items: ChangeItem.archivedFrom2026_19),
        HistorySection(title: "Also in 2026.18", items: ChangeItem.archivedFrom2026_18),
        HistorySection(title: "Also in 2026.17", items: ChangeItem.archivedFrom2026_17),
        HistorySection(title: "Also in 2026.16", items: ChangeItem.archivedFrom2026_16),
        HistorySection(title: "Also in 2026.15", items: ChangeItem.archivedFrom2026_15),
        HistorySection(title: "Also in 2026.14", items: ChangeItem.archivedFrom2026_14),
    ]
}
