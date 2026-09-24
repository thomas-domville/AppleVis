import SwiftUI
import UIKit

/// Scans recently-posted content across every commentable content type —
/// forum topics/replies, blog posts, guides, podcast episodes, app/TV/Watch/
/// Mac directory entries and reviews, and bug reports — for possible
/// guideline violations. See `GuidelineViolationScanner` for how the scan
/// itself works. A direct row under Profile > Admin (previously nested one
/// level deeper inside a since-removed "Moderator Tools" hub screen that
/// only ever held this one row). Deliberately excluded from Help content,
/// the Welcome Tour, and What's New — this is internal team tooling, not a
/// user-facing feature, and gating on `auth.user?.isAdmin` already means
/// almost nobody would ever see a mention of it anyway. Requested directly.
struct GuidelineViolationCheckView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var scanner = GuidelineViolationScanner()
    @State private var range: GuidelineScanRange = .day
    @State private var showLowSeverity = false
    @AccessibilityFocusState private var isTitleFocused: Bool
    /// Shared by whichever status section is currently showing —
    /// "Scanning…", the error message, or the results summary — since
    /// exactly one of them is ever present at a time. Focus moves here both
    /// when a scan starts and when it finishes, so a VoiceOver user hears
    /// that the scan is running and then hears the result, instead of
    /// tapping Start Scan and getting silence — same pattern as the sibling
    /// App Directory Health Check screen.
    @AccessibilityFocusState private var isStatusFocused: Bool

    /// Medium+High only by default — `GuidelinesChecker` was tuned to be
    /// gentle and advisory for someone's own draft. Run in bulk across
    /// everyone's real, already-posted content, its low-severity rules
    /// (all-caps, excessive punctuation, "me too"-style low-value replies)
    /// would flag a lot of harmless stuff and turn a quick glance into a
    /// wall of noise. Low severity is still there, just tucked behind a
    /// toggle for anyone who wants the fuller picture.
    private var visibleFlags: [GuidelineFlag] {
        showLowSeverity ? scanner.flags : scanner.flags.filter { $0.highestSeverity != .low }
    }

    var body: some View {
        Form {
            Section {
                Text("Scans recent forum topics, blog posts, guides, podcast episodes, app/TV/Watch/Mac directory entries, bug reports, and their comments and replies — against AppleVis's posting guidelines. Not a substitute for judgment: a flag means \"worth a look,\" not \"definitely a violation.\" Longer ranges can take a while, so nothing starts until you tap Start Scan.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)

                // Menu rather than segmented: four options don't fit a
                // segmented control at larger text sizes without truncating.
                Picker("Time Range", selection: $range) {
                    ForEach(GuidelineScanRange.allCases) { r in
                        Text(r.displayName).tag(r)
                    }
                }
                .pickerStyle(.menu)
                .disabled(scanner.isScanning)
                .accessibilityHint(String(localized: "Choose how far back to scan."))

                // Scanning used to start by itself on open and again on
                // every time-range change — fine for a day, but a month-long
                // scan is slow enough that it should only run on purpose.
                // Dimmed (disabled) for the whole scan, so it can't be
                // double-started, and relabeled so VoiceOver reads
                // "Scanning…, dimmed" if focus lands back on it. Requested
                // directly.
                Button {
                    Task { await scanner.scan(range: range) }
                } label: {
                    if scanner.isScanning {
                        Label("Scanning…", systemImage: "hourglass")
                    } else {
                        Label("Start Scan", systemImage: "play.circle")
                    }
                }
                .disabled(scanner.isScanning)
                .accessibilityLabel(scanner.isScanning
                    ? String(localized: "Scanning \(range.displayName)")
                    : String(localized: "Start Scan: \(range.displayName)"))
            }

            if scanner.isScanning {
                Section {
                    HStack {
                        ProgressView()
                        Text("Scanning the \(range.displayName.lowercased())… This can take a minute or more for longer ranges.")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityFocused($isStatusFocused)
                }
            } else if let error = scanner.error {
                Section {
                    Text(error).foregroundStyle(.red)
                        .accessibilityFocused($isStatusFocused)
                    Button("Try Again") { Task { await scanner.scan(range: range) } }
                }
            } else if let scannedRange = scanner.lastScannedRange {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(scanner.scannedItemCount) items scanned")
                            Spacer()
                            Text("\(visibleFlags.count) flagged")
                                .fontWeight(.semibold)
                        }
                        // Breaks the total down so it's clear comments and
                        // replies are included — the old count left them out
                        // entirely, which is what made a busy day read as
                        // "20 items." Also names the range the results came
                        // from, since the picker can be changed afterward.
                        Text("\(scannedRange.displayName): \(scanner.scannedPostCount) posts, \(scanner.scannedCommentCount) comments and replies")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityFocused($isStatusFocused)

                    if scanner.flags.contains(where: { $0.highestSeverity == .low }) {
                        Toggle("Show Low-Severity Items", isOn: $showLowSeverity)
                    }
                }

                if visibleFlags.isEmpty {
                    Section {
                        Text("No flagged content in this range.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(visibleFlags) { flag in
                            NavigationLink {
                                GuidelineFlagDestination(flag: flag)
                            } label: {
                                GuidelineFlagRow(flag: flag)
                            }
                            .modifier(GuidelineFlagActions(flag: flag, onHandled: { scanner.removeFlag(id: flag.id) }))
                        }
                    }
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Guideline Violation Check")
        .navigationBarTitleDisplayMode(.inline)
        // Fires on both transitions: a scan starting (lands on
        // "Scanning…") and finishing (lands on the error or results).
        .onChange(of: scanner.isScanning) { _, _ in
            Task { await retryAccessibilityFocus(into: $isStatusFocused) }
        }
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }
}

/// Routes to the right detail screen for a flag's content kind — every one
/// of these accepts a bare content id and resolves the rest itself (no
/// platform hint needed for app entries or bug reports, both of which
/// already try each of their own possible node types in turn for a
/// platform-less id).
private struct GuidelineFlagDestination: View {
    let flag: GuidelineFlag

    var body: some View {
        switch flag.kind {
        case .forumTopic:     ForumTopicDetailView(topicId: flag.itemId, targetCommentId: flag.commentId)
        case .blogPost:       BlogDetailView(postId: flag.itemId, targetCommentId: flag.commentId)
        case .resource:       ResourceDetailView(resourceId: flag.itemId, targetCommentId: flag.commentId)
        case .podcastEpisode: EpisodeDetailView(episodeId: flag.itemId, targetCommentId: flag.commentId)
        case .appListing:     AppDetailView(appId: flag.itemId, targetCommentId: flag.commentId)
        case .bugReport:      BugDetailView(bugId: flag.itemId, targetCommentId: flag.commentId)
        }
    }
}

private struct GuidelineFlagRow: View {
    let flag: GuidelineFlag

    private var severityConfig: (color: Color, label: String) {
        switch flag.highestSeverity {
        case .high:   return (Color(red: 0.725, green: 0.110, blue: 0.110), String(localized: "High"))
        case .medium: return (Color(red: 0.706, green: 0.325, blue: 0.035), String(localized: "Medium"))
        case .low:    return (Color(red: 0.020, green: 0.412, blue: 0.631), String(localized: "Low"))
        }
    }

    private var ruleNames: String {
        flag.warnings.map(\.rule).joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(severityConfig.label)
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(severityConfig.color, in: Capsule())
                Text(flag.kindLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                RelativeDateLabel(date: flag.createdAt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(flag.itemTitle)
                .font(.subheadline).fontWeight(.semibold)
                .lineLimit(1)

            // Previously folded into the same caption line as the author
            // name ("JohnDoe — Keep AppleVis 13+"), easy to skim right past
            // — which guideline actually triggered the flag is the whole
            // point of looking at one of these. Its own clearly-labeled
            // line now. Requested directly.
            Label("Guideline: \(ruleNames)", systemImage: "exclamationmark.triangle")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(severityConfig.color)
                .lineLimit(2)

            Text("By \(flag.authorName)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(flag.excerpt)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(severityConfig.label) severity. \(flag.kindLabel) by \(flag.authorName), in \(flag.itemTitle). Guideline: \(ruleNames). \(flag.excerpt)"))
    }
}

/// Edit/Unpublish/Delete/Share for a flagged item, as a swipe-action set on
/// the admin list row — reuses the same `ContentActionEndpoints` calls every
/// detail view's own comment/reply/review row already calls, dispatching on
/// `flag.actionTarget` to cover both a root item (node) and a comment/reply/
/// review underneath one. Every viewer of this screen is already an admin
/// (Profile > Admin is `isAdmin`-gated), so unlike `CommentRow`/`ReplyView`
/// there's no separate "own content" case to gate Edit/Delete behind.
/// Requested directly.
private struct GuidelineFlagActions: ViewModifier {
    let flag: GuidelineFlag
    let onHandled: () -> Void

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @State private var showEditSheet = false
    @State private var showUnpublishConfirm = false
    @State private var showDeleteConfirm = false

    /// Root items get the stronger "entire" wording — see the delete
    /// confirmation's `message:` closure for why.
    private var deleteConfirmationTitle: String {
        flag.isRootItem
            ? String(localized: "Delete this entire \(flag.kindLabel.lowercased())?")
            : String(localized: "Delete this \(flag.kindLabel.lowercased())?")
    }

    func body(content: Content) -> some View {
        content
            // Swipe actions are unreachable to a VoiceOver user (their
            // one-finger swipe is already claimed for element navigation) —
            // see VoiceOverAwareSwipeActions's doc comment. The accessibility
            // actions below are the real path for them.
            .voiceOverAwareSwipeActions {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button {
                    showUnpublishConfirm = true
                } label: {
                    Label("Unpublish", systemImage: "eye.slash")
                }
                .tint(.orange)
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
                Button {
                    presentShareSheet()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(.gray)
            }
            .accessibilityAction(named: Text("Edit \(flag.kindLabel)")) { showEditSheet = true }
            .accessibilityAction(named: Text("Unpublish \(flag.kindLabel)")) { showUnpublishConfirm = true }
            .accessibilityAction(named: Text("Delete \(flag.kindLabel)")) { showDeleteConfirm = true }
            .accessibilityAction(named: Text("Share \(flag.kindLabel)")) { presentShareSheet() }
            .confirmationDialog(
                "Unpublish this \(flag.kindLabel.lowercased())?", isPresented: $showUnpublishConfirm, titleVisibility: .visible
            ) {
                Button("Unpublish", role: .destructive) { Task { await unpublish() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This hides it from public view.")
            }
            .confirmationDialog(
                deleteConfirmationTitle, isPresented: $showDeleteConfirm, titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { Task { await delete() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                // A comment/reply/review deletion is already scoped and
                // final enough for the plain title alone, matching
                // CommentRow/ReplyView/DetailActionsMenu's own delete
                // dialogs elsewhere. Deleting a root item from this bulk
                // moderation list is a much bigger blast radius — it takes
                // the whole discussion with it, not just the flagged text —
                // and that wasn't obvious from "Delete this topic?" alone.
                // Requested directly.
                if flag.isRootItem {
                    Text("This permanently removes the entire \(flag.kindLabel.lowercased()) and everything posted underneath it.")
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditContentSheet(title: String(localized: "Edit \(flag.kindLabel)"), initialText: flag.body, isReply: !flag.isRootItem) { newText in
                    try await edit(newText: newText)
                }
            }
    }

    private func edit(newText: String) async throws {
        guard let user = auth.user, let target = flag.actionTarget else { return }
        switch target {
        case .comment(let type, let id):
            try await APIClient.shared.content.editComment(
                commentType: type, commentId: id, newBody: newText, format: drupalDefaultTextFormat, csrfToken: user.csrfToken
            )
        case .node(let type, let id):
            try await APIClient.shared.content.editNode(
                nodeId: id, nodeType: type, title: flag.itemTitle, body: newText, format: drupalDefaultTextFormat, csrfToken: user.csrfToken
            )
        }
        toast.success(String(localized: "\(flag.kindLabel) updated"))
        onHandled()
    }

    private func unpublish() async {
        guard let user = auth.user, let target = flag.actionTarget else { return }
        do {
            switch target {
            case .comment(let type, let id):
                try await APIClient.shared.content.unpublishComment(commentType: type, commentId: id, csrfToken: user.csrfToken)
            case .node(let type, let id):
                try await APIClient.shared.content.unpublishNode(nodeId: id, nodeType: type, csrfToken: user.csrfToken)
            }
            toast.success(String(localized: "\(flag.kindLabel) unpublished"))
            onHandled()
        } catch {
            toast.error(String(localized: "Couldn't unpublish this. Try again."))
        }
    }

    private func delete() async {
        guard let user = auth.user, let target = flag.actionTarget else { return }
        do {
            switch target {
            case .comment(let type, let id):
                try await APIClient.shared.content.deleteComment(commentType: type, commentId: id, csrfToken: user.csrfToken)
            case .node(let type, let id):
                try await APIClient.shared.content.deleteNode(nodeId: id, nodeType: type, csrfToken: user.csrfToken)
            }
            toast.success(String(localized: "\(flag.kindLabel) deleted"))
            onHandled()
        } catch {
            toast.error(String(localized: "Couldn't delete this. Try again."))
        }
    }

    /// Mirrors CommentRow/ReplyView's own "Share Comment" — plain text
    /// (author, body), not a URL, since a comment/reply/review has no
    /// shareable link of its own.
    private func presentShareSheet() {
        let message = "\(flag.authorName) on AppleVis:\n\n\(flag.body.strippingHTMLTags())"
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .present(activityVC, animated: true)
    }
}
