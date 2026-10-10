import Foundation

/// How-To Library: using the AppleVis app itself (2026-10-08). Short
/// "How do I…" and "Where is…" answers for every everyday task, with the
/// app's real screen, button, and action names. The longer overview
/// articles elsewhere in Help still explain each area in full; these point
/// to them. Admin tools are deliberately left out. Help is translated while
/// the app runs.
extension HelpContent {
    static let howToUsingAppleVis = HelpSection(
        id: "howto-using-applevis",
        title: "How To: Using AppleVis",
        icon: "questionmark.app",
        description: "Where everything is in AppleVis, and how to do each thing: reading, posting, apps, the Podcast, search, your account, and more.",
        articles: [
            // MARK: Where things are
            HelpArticle(
                id: "howto-app-where",
                title: "Where Is Everything in AppleVis?",
                summary: "A map of the four tabs and Profile and Settings.",
                content: [
                    .heading("Home"),
                    .body("What's new on AppleVis. Choose All, New, Fetch, or Nibbles at the top. Customize Home is at the top left. Post and Ask the Mouse are at the top right."),
                    .heading("Discover"),
                    .body("Everything else: search, Forums, the Blog, Guides, the Podcast, the App Directory, Community Picks, the Bug Tracker, Be My Eyes, RSS Feeds, and Contribute."),
                    .heading("For You"),
                    .body("Only what you chose to keep: Saved, Following, Recommended, Queue, and Downloads."),
                    .heading("Profile and Settings"),
                    .body("The Profile and Settings button is at the top right of Home, Discover, and For You. It holds your account, Settings, Help, What's New, Replay Welcome Tour, and Contact AppleVis."),
                    .tip("With VoiceOver, use the Headings rotor to move between the parts of each screen."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Main Tabs and Navigation", type: .guide, destination: .article("start-tabs"))]
            ),
            HelpArticle(
                id: "howto-app-version",
                title: "How Do I Find Which Version of AppleVis I Have?",
                summary: "Useful when you report a problem.",
                content: [
                    .steps([
                        "Open Profile and Settings.",
                        "Find Version, near the bottom. It shows the version and the build number.",
                    ]),
                    .tip("When you send a Bug Report through Contact AppleVis, you can include the version and your device details automatically."),
                ],
                contentType: .tutorial
            ),

            // MARK: Reading what's new
            HelpArticle(
                id: "howto-app-see-new",
                title: "How Do I See Only What's New?",
                summary: "New posts and comments you haven't read yet.",
                content: [
                    .steps([
                        "Open Home.",
                        "At the top, choose New.",
                    ]),
                    .body("An item stays in New until you open it or mark it as read. The number on the Home tab is how many items are in New."),
                    .tip("With VoiceOver, the New Items rotor moves through everything in New."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Home and What's New", type: .guide, destination: .article("home-whats-new"))]
            ),
            HelpArticle(
                id: "howto-app-mark-read",
                title: "How Do I Mark Something as Read?",
                summary: "Clear an item's new badge without opening it.",
                content: [
                    .steps([
                        "Find the item on Home.",
                        "Swipe on it, or touch and hold it. With VoiceOver, use the Actions rotor.",
                        "Choose Mark as Read.",
                    ]),
                    .body("To clear everything at once, choose Mark All as Read on Home. When you're signed in, the website is updated too."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-fetch",
                title: "How Do I Read Every New Post and Comment in One Place?",
                summary: "Fetch: each new post with its new comments, without opening anything.",
                content: [
                    .steps([
                        "Open Home.",
                        "At the top, choose Fetch.",
                        "Swipe through. Each item starts with a heading, followed by the post and each new comment in full.",
                        "When you've finished an item, choose Mark This Group as Read.",
                    ]),
                    .tip("With VoiceOver, set the rotor to Headings to move from item to item."),
                    .tip("With VoiceOver, a soft end-of-page sound and Last comment tell you you've reached the end of an item. Mark This Group as Read is in the Actions rotor right there."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Fetch", type: .guide, destination: .article("home-fetch"))]
            ),
            HelpArticle(
                id: "howto-app-listen-fetch",
                title: "How Do I Have AppleVis Read New Posts Aloud?",
                summary: "Listen to Fetch reads everything new, item by item.",
                content: [
                    .steps([
                        "Open Home, then choose Fetch.",
                        "Choose Listen to Fetch.",
                        "Use the buttons to pause, skip a comment, or move to the next or previous item.",
                        "Choose Stop Listening when you're done.",
                    ]),
                    .body("Listening Speed sets how fast it reads. My Settings uses your VoiceOver or Spoken Content voice and speed."),
                    .tip("You can also say \"Hey Siri, listen to AppleVis Fetch\"."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-nibbles",
                title: "How Do I Get a Weekly or Monthly Summary?",
                summary: "Nibbles sums up new apps, episodes, discussions, guides, and blog posts.",
                content: [
                    .steps([
                        "Open Home.",
                        "At the top, choose Nibbles.",
                        "Choose Past Week or Past Month.",
                    ]),
                    .body("Choose Share Nibbles to send the summary to someone. Pull down to refresh it with the very latest posts."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-left-off",
                title: "How Do I Go Back to Where I Left Off?",
                summary: "Home remembers the last item you opened.",
                content: [
                    .body("When you open AppleVis, Home returns you to where you left off."),
                    .body("If you've moved away, choose the summary at the top of Home while All is showing. It takes you to the item you last opened."),
                    .tip("With VoiceOver, use the Pick Up Where You Left Off action on the greeting at the top of Home."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-first-new-comment",
                title: "How Do I Jump to the First New Comment?",
                summary: "Skip straight past the comments you've already read.",
                content: [
                    .steps([
                        "Find the item on Home. It shows a count, such as 3 NEW.",
                        "Swipe on it, or touch and hold it. With VoiceOver, use the Actions rotor.",
                        "Choose Jump to First New Comment.",
                    ]),
                    .body("The item opens on the first comment you haven't seen. Back returns you to Home."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-last-comment",
                title: "How Do I Jump to the Latest Comment?",
                summary: "Go straight to the end of a long discussion.",
                content: [
                    .steps([
                        "Open the topic, post, app, or episode.",
                        "Move to the Community Discussion heading.",
                        "Choose Jump to Last Comment, just after it.",
                    ]),
                ],
                contentType: .tutorial
            ),

            // MARK: Forums and posting
            HelpArticle(
                id: "howto-app-browse-forums",
                title: "How Do I Browse the Forums?",
                summary: "Recent, new, and unread topics, by category.",
                content: [
                    .steps([
                        "Open Discover, then Forums.",
                        "Choose Filter Forums to change what's shown.",
                        "Under Show, choose Recent, New, Unread, Since Last Visit, Following, or Saved.",
                        "Choose Apple Related or Non-Apple Related, and a category, to narrow it further.",
                    ]),
                    .body("Pinned topics always appear at the top."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Forums and Following", type: .guide, destination: .article("community-forums"))]
            ),
            HelpArticle(
                id: "howto-app-new-topic",
                title: "How Do I Start a New Forum Topic?",
                summary: "Ask a question or begin a discussion.",
                content: [
                    .steps([
                        "Sign in, if you haven't already.",
                        "On Home, choose Post at the top right, then New Topic.",
                        "Choose a category.",
                        "Write a clear title, then your post in Body.",
                        "Leave Follow This Topic on to hear about replies.",
                        "Choose Post.",
                    ]),
                    .tip("Choose Rewrite for help with the wording. You can also say \"Hey Siri, start a new AppleVis topic\"."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Post a Topic, Reply, or Comment", type: .tutorial, destination: .article("tutorial-post"))]
            ),
            HelpArticle(
                id: "howto-app-reply",
                title: "How Do I Reply to a Topic or a Comment?",
                summary: "Reply to the whole discussion, or to one person.",
                content: [
                    .steps([
                        "Open the topic, post, app, or episode.",
                        "To reply to the discussion, choose Add Comment at the bottom of the screen.",
                        "To reply to one person, touch and hold their comment, or use the Actions rotor, and choose Reply to this Comment.",
                        "Add a subject if you like, then write your reply and choose Post.",
                    ]),
                    .body("A reply to someone's comment is linked to it. In AppleVis it shows Replying to and their name, which takes you to their comment, and the website shows In reply to. This works on forum topics, app entries, blog posts, guides, podcast episodes, and bug reports."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-summarize",
                title: "How Do I Get a Summary of a Long Discussion?",
                summary: "A few sentences instead of every comment.",
                content: [
                    .steps([
                        "Open the forum topic or app.",
                        "Choose Summarize Discussion on a topic, or Summarize Community Discussion on an app.",
                    ]),
                    .note("This needs Apple Intelligence. Without it, the button isn't shown."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-follow",
                title: "How Do I Follow a Topic?",
                summary: "Keep up with new replies.",
                content: [
                    .steps([
                        "Open the topic, or find it in a list.",
                        "Choose Follow. In a list, swipe on it, touch and hold it, or use the Actions rotor.",
                    ]),
                    .body("Followed items are in For You > Following. To be notified about them, turn on Followed Topics in AppleVis Settings > Notifications."),
                    .tip("To stop following, choose Follow again, or swipe on the item in For You > Following."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-replies-notify",
                title: "How Do I Get Notified When Someone Replies to Me?",
                summary: "Replies to My Posts follows what you post for you.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then Notifications.",
                        "Turn on Replies to My Posts and Followed Topics.",
                    ]),
                    .body("New topics and app entries you post from then on are followed automatically, so you hear about replies."),
                    .note("Notifications must also be allowed for AppleVis in iPhone Settings."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Notifications", type: .guide, destination: .article("settings-notifications"))]
            ),
            HelpArticle(
                id: "howto-app-message",
                title: "How Do I Send a Private Message to Another Member?",
                summary: "Write to someone without sharing your email address.",
                content: [
                    .steps([
                        "Choose the member's name, on any post or comment, to open their profile.",
                        "Choose Contact, followed by their name.",
                        "Write your message, then choose Send Message.",
                    ]),
                    .body("If there's no Contact button, that member has turned messages off. Your email address isn't shared unless they reply."),
                    .tip("To turn off messages to you, open Edit Profile and turn off Allow Other Members to Contact Me."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-share",
                title: "How Do I Share a Topic, App, or Episode?",
                summary: "Send a link to someone.",
                content: [
                    .steps([
                        "Open it, or find it in a list.",
                        "Choose Share. On an open item, it's in the actions menu at the top right. In a list, swipe on it, touch and hold it, or use the Actions rotor.",
                        "Choose how to send it.",
                    ]),
                    .body("To share a single comment, touch and hold it, or use the Actions rotor, and choose Share Comment."),
                ],
                contentType: .tutorial
            ),

            // MARK: Saving and For You
            HelpArticle(
                id: "howto-app-save",
                title: "How Do I Save Something to Read Later?",
                summary: "A private bookmark for any topic, app, post, or episode.",
                content: [
                    .steps([
                        "Open it, or find it in a list.",
                        "Choose Save. In a list, swipe on it, touch and hold it, or use the Actions rotor.",
                    ]),
                    .body("Saved items are in For You > Saved. Saving doesn't notify you about replies. Follow does that."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Save, Follow, Download, and Recommend: What\u{2019}s the Difference?", type: .faq, destination: .article("foryou-save-follow-download-faq"))]
            ),
            HelpArticle(
                id: "howto-app-find-saved",
                title: "Where Are My Saved Items?",
                summary: "For You > Saved, with a filter by type.",
                content: [
                    .steps([
                        "Open For You.",
                        "Choose Saved in the section picker at the top.",
                        "Use the filter to show one type, such as Forum Topics or Mouse Answers.",
                    ]),
                    .body("To remove one, swipe on it, or use the Actions rotor. Unsave All removes them all from Saved. It doesn't delete the original posts."),
                ],
                contentType: .tutorial
            ),

            // MARK: Apps
            HelpArticle(
                id: "howto-app-check-app",
                title: "How Do I Check Whether an App Is Accessible?",
                summary: "Read what members say in the App Directory.",
                content: [
                    .steps([
                        "Open Discover, then App Directory.",
                        "Choose a platform, such as iPhone and iPad.",
                        "Search apps by name, or choose a category.",
                        "Open the app to read its ratings and every member's accessibility comment.",
                    ]),
                    .body("With Apple Intelligence, Accessibility Consensus sums up what members report in one paragraph."),
                    .tip("You can also ask the Mouse, such as \"Is the Starbucks app accessible?\""),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "App Directory", type: .guide, destination: .article("content-apps"))]
            ),
            HelpArticle(
                id: "howto-app-comment-app",
                title: "How Do I Leave an Accessibility Comment on an App?",
                summary: "Tell others how well an app works for you.",
                content: [
                    .steps([
                        "Sign in, if you haven't already.",
                        "Open the app in the App Directory.",
                        "Choose Add Comment at the bottom of the screen.",
                        "Describe how the app works with VoiceOver, braille, Zoom, or whatever you use, then choose Post.",
                    ]),
                    .body("Subject is optional. Left blank, your comment's first few words are used."),
                    .body("If the app isn't in the directory yet, you can add it with Submit an App, in Discover > Contribute."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Submitting an App Entry", type: .guide, destination: .article("community-submit-app"))]
            ),
            HelpArticle(
                id: "howto-app-recommend",
                title: "How Do I Recommend an App?",
                summary: "A public thumbs-up for an app you vouch for.",
                content: [
                    .steps([
                        "Sign in, if you haven't already.",
                        "Open the app, or find it in a list.",
                        "Choose Recommend. In a list, swipe on it, touch and hold it, or use the Actions rotor.",
                    ]),
                    .body("Apps you recommend are in For You > Recommended. To take a recommendation back, choose Recommend again, or choose I No Longer Recommend This App in For You."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-community-picks",
                title: "How Do I See the Apps Members Recommend?",
                summary: "Community Picks: newest or most recommended.",
                content: [
                    .steps([
                        "Open Discover, then find App Directory.",
                        "Choose Community Picks.",
                        "Choose Latest or Most Recommended, a period, and a platform.",
                    ]),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Community Picks", type: .guide, destination: .article("discover-community-picks"))]
            ),

            // MARK: The Podcast
            HelpArticle(
                id: "howto-app-play-episode",
                title: "How Do I Play an AppleVis Podcast Episode?",
                summary: "Find an episode, play it, and control playback.",
                content: [
                    .steps([
                        "Open Discover, then Podcast.",
                        "Choose an episode, then Play.",
                        "Use the mini player at the bottom of the screen to pause, skip, or open the full player.",
                    ]),
                    .body("Speed and Sleep Timer are on the episode's page and in the full player. With VoiceOver, a two-finger double tap plays and pauses from anywhere in AppleVis."),
                    .tip("Say \"Hey Siri, play the latest AppleVis podcast\" or \"Hey Siri, resume my AppleVis podcast\"."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Play and Queue Podcast Episodes", type: .tutorial, destination: .article("tutorial-podcast"))]
            ),
            HelpArticle(
                id: "howto-app-download-episode",
                title: "How Do I Download an Episode to Listen Offline?",
                summary: "Keep an episode on this device.",
                content: [
                    .steps([
                        "Open the episode.",
                        "In Episode Tools, choose Download.",
                    ]),
                    .body("Downloaded episodes are in For You > Downloads. To remove one, choose Downloaded on its page, or swipe on it in Downloads."),
                    .tip("Auto-Download and Auto-Delete, in AppleVis Settings > Podcast, can do this for you."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-queue",
                title: "How Do I Build and Reorder My Podcast Queue?",
                summary: "Line up episodes to play one after another.",
                content: [
                    .steps([
                        "Open an episode, and in Episode Tools choose Add to Queue, or Play Next to put it first.",
                        "Open For You, then Queue, to see what's lined up.",
                        "To reorder, use Move Up and Move Down. With VoiceOver, they're in the Actions rotor.",
                        "To remove one, choose Remove from Queue. Clear Queue removes them all.",
                    ]),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-sleep-timer",
                title: "How Do I Set a Podcast Sleep Timer?",
                summary: "Stop playing after a while, or at the end of the episode.",
                content: [
                    .steps([
                        "Open the episode that's playing, or the full player.",
                        "Choose Sleep Timer.",
                        "Choose how long, or End of Episode.",
                    ]),
                    .body("To cancel it, choose Sleep Timer again, then Turn Off."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-transcript",
                title: "How Do I Read an Episode's Transcript?",
                summary: "Read along, or search what was said.",
                content: [
                    .steps([
                        "Open the episode.",
                        "In Episode Tools, choose Transcript.",
                    ]),
                    .body("Choose Share Transcript to send it or save it. Not every episode has a transcript."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-chapters",
                title: "How Do I Skip to a Chapter in an Episode?",
                summary: "Move straight to the part you want.",
                content: [
                    .steps([
                        "Open the episode.",
                        "Move to the Chapters heading, and choose a chapter.",
                    ]),
                    .tip("With VoiceOver, the Chapters rotor moves between them."),
                    .note("Only episodes with chapters show this heading."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-start-over",
                title: "How Do I Start an Episode from the Beginning?",
                summary: "AppleVis remembers your place, so this starts it again.",
                content: [
                    .steps([
                        "Open the episode.",
                        "In Episode Tools, choose Start Over.",
                    ]),
                    .body("Listened, next to it, marks an episode as heard. It doesn't change your place."),
                ],
                contentType: .tutorial
            ),

            // MARK: Search, Help, and the Mouse
            HelpArticle(
                id: "howto-app-search",
                title: "How Do I Search AppleVis?",
                summary: "Forums, apps, guides, blog posts, episodes, and bugs at once.",
                content: [
                    .steps([
                        "Open Discover.",
                        "Type in the search field at the top. With a keyboard, press Command-F.",
                        "Results are grouped by type. With VoiceOver, use the Headings rotor to move between groups.",
                    ]),
                    .tip("Say \"Hey Siri, search AppleVis\" to search without opening the app first."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Using Search", type: .guide, destination: .article("search-overview"))]
            ),
            HelpArticle(
                id: "howto-app-help",
                title: "How Do I Search Help, or Print an Article?",
                summary: "Find any Help article, and share or emboss it.",
                content: [
                    .steps([
                        "Open Profile and Settings, then Help.",
                        "Type in Search help. It searches the text of every article. For a VoiceOver gesture or braille command, such as three-finger double-tap, a Quick Answer above the articles gives the exact command and the article it's from.",
                        "In an article, choose Share or Print to send it as text, or to print or emboss it.",
                    ]),
                    .body("Help works without a connection, so it's there when you need it most."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-ask-mouse",
                title: "How Do I Ask the Mouse a Question?",
                summary: "Ask in your own words, and get an answer from AppleVis.",
                content: [
                    .steps([
                        "On Home, choose Ask the Mouse at the top right. With a keyboard, press Command-M.",
                        "Type your question, or choose a suggestion.",
                        "Choose Ask. VoiceOver moves to the answer when it's ready.",
                    ]),
                    .note("Ask the Mouse needs Apple Intelligence."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Ask the Mouse", type: .guide, destination: .article("smart-ask-the-mouse"))]
            ),
            HelpArticle(
                id: "howto-app-known-bug",
                title: "How Do I Check Whether an Accessibility Bug Is Already Known?",
                summary: "The AppleVis Bug Tracker, with workarounds.",
                content: [
                    .steps([
                        "Open Discover, then Bug Tracker.",
                        "Choose iOS / iPadOS Bugs or macOS Bugs.",
                        "Type a word in the search field to narrow the list.",
                        "Open a bug report for its details and any workaround.",
                    ]),
                    .body("On an active bug, Report to Apple opens Feedback Assistant so you can add your own report."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Bug Tracker", type: .guide, destination: .article("discover-bug-tracker"))]
            ),
            HelpArticle(
                id: "howto-app-be-my-eyes",
                title: "How Do I Call a Be My Eyes Volunteer from AppleVis?",
                summary: "Quick links to Be My Eyes.",
                content: [
                    .steps([
                        "Open Discover.",
                        "Go to Be My Eyes.",
                        "Choose Call a Volunteer, Be My AI, or Service Directory.",
                    ]),
                    .body("Be My Eyes opens to that feature. If it isn't installed, its App Store page opens."),
                ],
                contentType: .tutorial
            ),

            // MARK: Contributing
            HelpArticle(
                id: "howto-app-contribute",
                title: "How Do I Contribute to AppleVis?",
                summary: "Submit an app, a bug, a blog post, or a podcast.",
                content: [
                    .steps([
                        "Sign in, if you haven't already.",
                        "Open Discover, then go to Contribute.",
                        "Choose Submit an App, Submit a Bug Report, Submit a Blog Post, or Submit a Podcast.",
                        "Follow the short guided steps.",
                    ]),
                    .body("An app entry appears in the App Directory straight away. Blog posts, bug reports, and podcasts are reviewed by the AppleVis team before they're published."),
                    .tip("You can also share an App Store link, some text, or a podcast episode into AppleVis from another app, and the right form opens."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Share Into AppleVis", type: .guide, destination: .article("smart-share"))]
            ),

            // MARK: Account
            HelpArticle(
                id: "howto-app-change-password",
                title: "How Do I Change My AppleVis Password?",
                summary: "Without leaving the app.",
                content: [
                    .steps([
                        "Open Profile and Settings, then choose your name to open My Account.",
                        "Choose Change Password.",
                        "Enter your current password, then your new one twice.",
                        "Check it, then choose Save Changes.",
                    ]),
                    .tip("Forgotten your password? Choose Forgot your password? on the sign-in screen."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-change-email",
                title: "How Do I Change My AppleVis Email Address?",
                summary: "Update the address AppleVis writes to.",
                content: [
                    .steps([
                        "Open Profile and Settings, then choose your name to open My Account.",
                        "Choose Change Email Address.",
                        "Enter your current password, then your new email address.",
                        "Check it, then choose Save Changes.",
                    ]),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-delete-account",
                title: "How Do I Delete My AppleVis Account?",
                summary: "Permanently remove your account and what you've posted.",
                content: [
                    .steps([
                        "Open Profile and Settings, then choose your name to open My Account.",
                        "Choose Delete Account.",
                        "Read what will be removed, and turn on I understand this is permanent and cannot be reversed.",
                        "Choose Delete My Account Permanently, then confirm.",
                    ]),
                    .warning("This removes your account, your posts and comments, your saved and followed items, and your profile. It can't be undone. If you only want a break, sign out instead."),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-contact",
                title: "How Do I Contact the AppleVis Team?",
                summary: "Questions, feedback, suggestions, and problems with the app.",
                content: [
                    .steps([
                        "Open Profile and Settings, then choose Contact AppleVis. With a keyboard, press Command-Shift-C.",
                        "Choose Bug Report, Feedback, Suggestion, or General Enquiry.",
                        "Write your message, and check your name and email address.",
                        "Check it, then choose Send Message.",
                    ]),
                    .body("For a problem with the app, choose Bug Report and turn on Include app and device info. That adds your AppleVis version and device details."),
                    .tip("You can also say \"Hey Siri, report a problem with AppleVis\"."),
                ],
                contentType: .tutorial
            ),

            // MARK: Making it work for you
            HelpArticle(
                id: "howto-app-own-language",
                title: "How Do I Read AppleVis in My Own Language?",
                summary: "Translate posts and comments on your device.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then Content Translation.",
                        "Turn on Auto-Translate Content.",
                    ]),
                    .body("Posts, comments, and Help are translated on your device. Choose Show Original to see the English."),
                    .note("The app's own buttons and headings already follow your iPhone's language."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Writing Help and Translation", type: .guide, destination: .article("community-writing-tools"))]
            ),
            HelpArticle(
                id: "howto-app-sync",
                title: "How Do I Keep AppleVis the Same on All My Devices?",
                summary: "iCloud sync for saved items, your queue, and more.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then Saved & Sync.",
                        "Turn on Enable iCloud Sync.",
                        "Choose what to sync, such as Saved Items, Podcast Position, and Read History.",
                    ]),
                    .note("Do the same on each device, signed in to the same Apple Account."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Privacy and Sync", type: .guide, destination: .article("settings-privacy-sync"))]
            ),
            HelpArticle(
                id: "howto-app-free-space",
                title: "How Do I Free Up Space Used by AppleVis?",
                summary: "Clear downloads and cached content.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then Storage & Cache.",
                        "Check how much space downloads and the cache use.",
                        "Choose Clear Cached Content, or Clear Downloaded Episodes.",
                    ]),
                    .body("Clearing the cache keeps your saved items and downloads. Keep Cache For sets how long cached content stays."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Storage and Cache", type: .guide, destination: .article("settings-storage-cache"))]
            ),
            HelpArticle(
                id: "howto-app-detail-level",
                title: "How Do I Make VoiceOver Say Less in AppleVis Lists?",
                summary: "VoiceOver Detail Level: Simple, Normal, or All.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then Accessibility.",
                        "Choose VoiceOver Detail Level.",
                        "Choose Simple for just the title, Normal for the title, author, and comments, or All for every detail.",
                    ]),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "VoiceOver Basics", type: .guide, destination: .article("accessibility-voiceover"))]
            ),
            HelpArticle(
                id: "howto-app-ai-off",
                title: "How Do I Turn Off the AI Features in AppleVis?",
                summary: "Choose which Apple Intelligence features to keep.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then Intelligence.",
                        "Turn off any feature you don't want, such as AI Summaries or Rewrite.",
                    ]),
                    .body("Everything else in AppleVis works the same without them."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Apple Intelligence Features", type: .guide, destination: .article("smart-apple-intelligence"))]
            ),
            HelpArticle(
                id: "howto-app-tips",
                title: "How Do I Turn Off AppleVis Tips?",
                summary: "The short tips that appear now and then.",
                content: [
                    .steps([
                        "Open AppleVis Settings, then General.",
                        "Turn off AppleVis Tips.",
                    ]),
                ],
                contentType: .tutorial
            ),
            HelpArticle(
                id: "howto-app-siri",
                title: "What Can I Ask Siri to Do in AppleVis?",
                summary: "Phrases that work without opening the app.",
                content: [
                    .bullets([
                        "\"Hey Siri, what's new on AppleVis\"",
                        "\"Hey Siri, listen to AppleVis Fetch\"",
                        "\"Hey Siri, open AppleVis Nibbles\"",
                        "\"Hey Siri, search AppleVis\"",
                        "\"Hey Siri, ask the AppleVis Mouse\"",
                        "\"Hey Siri, resume my AppleVis podcast\"",
                        "\"Hey Siri, play the latest AppleVis podcast\"",
                        "\"Hey Siri, start a new AppleVis topic\"",
                        "\"Hey Siri, contact AppleVis\"",
                    ]),
                    .body("AppleVis Settings > Siri & Shortcuts lists every phrase."),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "Siri and Spotlight", type: .guide, destination: .article("smart-siri-widgets"))]
            ),
            HelpArticle(
                id: "howto-app-keyboard",
                title: "Can I Use AppleVis with a Keyboard?",
                summary: "Shortcuts for the things you do most.",
                content: [
                    .bullets([
                        "Command-F moves to the search field.",
                        "Command-M opens Ask the Mouse.",
                        "Command-Shift-C opens Contact AppleVis.",
                        "Command-Comma opens Settings.",
                    ]),
                ],
                contentType: .tutorial,
                relatedLinks: [RelatedLink(label: "AppleVis Keyboard Shortcuts", type: .guide, destination: .article("ref-applevis-keyboard"))]
            ),
        ]
    )
}
