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
    /// Off: exactly what the rules caught. On: Apple Intelligence's verdict
    /// on each flag, with the ones it thinks are probably fine listed in
    /// their own section. Always shown after a scan, so the rules-only and
    /// reviewed results can be compared. It used to be a Hide switch that
    /// only appeared once a flag had been cleared, so it often seemed
    /// missing. Requested directly (2026-10-01).
    @State private var showAIReview = false
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
    private var flagsBySeverity: [GuidelineFlag] {
        showLowSeverity ? scanner.flags : scanner.flags.filter { $0.highestSeverity != .low }
    }

    /// The flags that still stand: all of them with the review off.
    private var visibleFlags: [GuidelineFlag] {
        guard showAIReview else { return flagsBySeverity }
        return flagsBySeverity.filter { !scanner.isProbablyFine($0) }
    }

    /// With the review on, the flags Apple Intelligence thinks are fine.
    private var probablyFineFlags: [GuidelineFlag] {
        showAIReview ? flagsBySeverity.filter(scanner.isProbablyFine) : []
    }

    private var probablyFineCount: Int {
        flagsBySeverity.filter(scanner.isProbablyFine).count
    }

    /// Flags with at least one rule Apple Intelligence double-checks.
    private var reviewableCount: Int {
        flagsBySeverity.filter { $0.warnings.contains(where: \.allowsSecondOpinion) }.count
    }

    /// Where the review stands, under the switch.
    private var reviewStatus: String {
        if scanner.isReviewing {
            return "Apple Intelligence is double-checking flags: \(scanner.reviewedCount) of \(scanner.reviewTotal)"
        }
        if reviewableCount == 0 {
            return "None of these flags are the kind Apple Intelligence double-checks. Strong language, links, images, and high-severity flags always stand as the rules found them."
        }
        if probablyFineCount == 0 {
            return "Apple Intelligence checked \(reviewableCount) flags and agrees with all of them."
        }
        return "Apple Intelligence checked \(reviewableCount) flags and thinks \(probablyFineCount) are probably fine."
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
                        VStack(alignment: .leading, spacing: 2) {
                            if scanner.isStopping {
                                Text("Stopping…")
                            } else {
                                Text("Scanning the \(range.displayName.lowercased())… This can take a minute or more for longer ranges.")
                            }
                            // Shows a long scan is moving. Requested directly.
                            if scanner.itemsCheckedSoFar > 0 {
                                Text("Items checked so far: \(scanner.itemsCheckedSoFar)")
                                    .font(.footnote)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityFocused($isStatusFocused)

                    // Ends a long scan early and keeps what it's checked so
                    // far. Requested directly.
                    Button(role: .destructive) {
                        scanner.stop()
                    } label: {
                        Label("Stop Scan", systemImage: "stop.circle")
                    }
                    .disabled(scanner.isStopping)
                    .accessibilityHint(String(localized: "Stops the scan and shows what's been found so far."))
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
                        // When nothing's found, the message is part of the
                        // summary VoiceOver lands on after a scan, so it's
                        // heard straight away rather than one swipe further
                        // down. Reported directly (2026-09-28).
                        if flagsBySeverity.isEmpty {
                            Text("No flagged content in this range.")
                                .fontWeight(.semibold)
                        } else if visibleFlags.isEmpty {
                            Text("Apple Intelligence thinks every flag is probably fine.")
                                .fontWeight(.semibold)
                        }
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
                        if scanner.lastScanWasStopped {
                            Text("Stopped early. These results cover only what was checked before you stopped.")
                                .font(.caption)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityFocused($isStatusFocused)

                    if scanner.flags.contains(where: { $0.highestSeverity == .low }) {
                        Toggle("Show Low-Severity Items", isOn: $showLowSeverity)
                    }

                    // Apple Intelligence's second look, on supported devices.
                    if IntelligenceService.isAvailable {
                        if !flagsBySeverity.isEmpty {
                            Toggle("Apple Intelligence Review", isOn: $showAIReview)
                                .accessibilityHint("Off shows everything the rules caught. On shows Apple Intelligence's verdict on each flag, and lists the ones it thinks are probably fine separately.")
                                .onChange(of: showAIReview) { _, on in
                                    let message = on
                                        ? "Apple Intelligence Review on. \(visibleFlags.count) flagged, \(probablyFineFlags.count) probably fine."
                                        : "Showing what the rules caught. \(visibleFlags.count) flagged."
                                    UIAccessibility.post(notification: .announcement, argument: message)
                                }
                            HStack {
                                if scanner.isReviewing { ProgressView() }
                                Text(reviewStatus)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(scanner.isReviewing ? .updatesFrequently : [])
                        }
                    } else {
                        Text("Apple Intelligence isn't available on this device, so this shows what the rules caught.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !visibleFlags.isEmpty {
                    Section {
                        ForEach(visibleFlags) { flag in
                            flagLink(flag)
                        }
                    } header: {
                        if showAIReview {
                            Text("Still Flagged (\(visibleFlags.count))")
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                }

                // The false flags, by Apple Intelligence's reading, kept
                // in view rather than hidden.
                if !probablyFineFlags.isEmpty {
                    Section {
                        ForEach(probablyFineFlags) { flag in
                            flagLink(flag)
                        }
                    } header: {
                        Text("Apple Intelligence Thinks These Are Fine (\(probablyFineFlags.count))")
                            .accessibilityAddTraits(.isHeader)
                    } footer: {
                        Text("Read in context, these look fine. Give them a quick look before moving on.")
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

    private func flagLink(_ flag: GuidelineFlag) -> some View {
        NavigationLink {
            GuidelineFlagDestination(flag: flag)
        } label: {
            GuidelineFlagRow(flag: flag, opinions: showAIReview ? (scanner.opinions[flag.id] ?? [:]) : [:])
        }
        .modifier(GuidelineFlagActions(flag: flag, onHandled: { scanner.removeFlag(id: flag.id) }))
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

/// How much of a flagged item the row shows. Comments are usually short,
/// so they're shown and read in full; posts, which can be very long, get a
/// longer preview. Anything cut short offers Read Full Text. Rows used to
/// stop at 300 characters for everything. Requested directly (2026-09-28).
extension GuidelineFlag {
    var previewLimit: Int { isRootItem ? 500 : 2000 }
    var fullText: String { body.strippingHTMLTags().trimmingCharacters(in: .whitespacesAndNewlines) }
    var previewText: String { String.excerpt(from: body, limit: previewLimit) }
    var isPreviewShortened: Bool { fullText.count > previewLimit }
}

/// The whole flagged text on its own screen, one paragraph per element so
/// VoiceOver can move through a long post a paragraph at a time.
private struct GuidelineFlagFullText: View {
    let flag: GuidelineFlag
    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var isTitleFocused: Bool

    /// A paragraph holding one of the flag's lines, marked in Read Full
    /// Text. Requested directly (2026-10-01).
    private func isFlagged(_ paragraph: String) -> Bool {
        flag.triggers.values.contains { line in
            let start = String(line.replacingOccurrences(of: "…", with: "").prefix(40))
            return !start.isEmpty && paragraph.contains(start)
        }
    }

    private var paragraphs: [String] {
        flag.fullText.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(flag.itemTitle)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isTitleFocused)
                    Text("\(flag.kindLabel) by \(flag.authorName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        let flagged = isFlagged(paragraph)
                        Text(paragraph)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(flagged ? 6 : 0)
                            .background(flagged ? Color.orange.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                            .accessibilityLabel(flagged ? "Flagged text. \(paragraph)" : paragraph)
                    }
                }
                .padding()
            }
            .navigationTitle("Full Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await retryAccessibilityFocus(into: $isTitleFocused) }
        }
    }
}

private struct GuidelineFlagRow: View {
    let flag: GuidelineFlag
    /// Apple Intelligence's verdict on each context-dependent rule, by rule id.
    var opinions: [String: IntelligenceService.GuidelineSecondOpinion] = [:]

    /// One line per judged rule, named when the flag has more than one.
    private var opinionLines: [(id: String, text: String, isFine: Bool)] {
        flag.warnings.compactMap { warning in
            guard let opinion = opinions[warning.id] else { return nil }
            let verdict = opinion.isRealConcern
                ? "Apple Intelligence agrees: \(opinion.reason)"
                : "Apple Intelligence thinks this is probably fine: \(opinion.reason)"
            return (warning.id, flag.warnings.count > 1 ? "\(warning.rule): \(verdict)" : verdict, !opinion.isRealConcern)
        }
    }

    /// The line behind each rule, named by rule when there's more than one.
    private var triggerLines: [(id: String, text: String)] {
        flag.warnings.compactMap { warning in
            guard let line = flag.triggers[warning.id] else { return nil }
            let quoted = "\u{201C}\(line)\u{201D}"
            return (warning.id, flag.warnings.count > 1 ? "\(warning.rule): \(quoted)" : "Flagged text: \(quoted)")
        }
    }

    private var opinionText: String? {
        let lines = opinionLines.map(\.text)
        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    private var severityConfig: (color: Color, label: String) {
        switch flag.highestSeverity {
        case .high:   return (Color(red: 0.725, green: 0.110, blue: 0.110), String(localized: "High"))
        case .medium: return (Color(red: 0.706, green: 0.325, blue: 0.035), String(localized: "Medium"))
        case .low:    return (Color(red: 0.020, green: 0.412, blue: 0.631), String(localized: "Low"))
        }
    }

    /// Said before the post's text, so it's clear where the flagged line
    /// ends and the post begins: "Full text" when VoiceOver reads all of
    /// it, "Preview" when it's cut short and Read Full Text has the rest.
    /// Requested directly (2026-10-01).
    private var previewWord: String {
        flag.isPreviewShortened ? "Preview" : "Full text"
    }

    /// The flagged lines as VoiceOver reads them, before the preview.
    private var triggerLinesSpoken: String {
        triggerLines.map { $0.text + ". " }.joined()
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

            // The line in question, so a long post's problem is easy to
            // find, followed by the preview. Requested directly (2026-10-01).
            ForEach(triggerLines, id: \.id) { line in
                Label(line.text, systemImage: "text.quote")
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .padding(6)
                    .background(severityConfig.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            }

            Text(flag.authorIsEditorial ? "By \(flag.authorName), Editorial Team" : "By \(flag.authorName)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // On screen it's always a few lines, so always "Preview".
            // VoiceOver reads the whole preview, so it hears "Full text"
            // when nothing was cut (see `previewWord`).
            Text("Preview")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(flag.previewText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(flag.isRootItem ? 4 : 8)

            ForEach(opinionLines, id: \.id) { line in
                Label(line.text, systemImage: line.isFine ? "checkmark.seal" : "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(severityConfig.label) severity. \(flag.kindLabel) by \(flag.authorName)\(flag.authorIsEditorial ? ", Editorial Team" : ""), in \(flag.itemTitle). Guideline: \(ruleNames). \(triggerLinesSpoken)\(previewWord): \(flag.previewText)") + (opinionText.map { " " + $0 } ?? ""))
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
    @State private var showFullText = false

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
                if flag.isPreviewShortened {
                    Button {
                        showFullText = true
                    } label: {
                        Label("Read Full Text", systemImage: "doc.plaintext")
                    }
                    .tint(.indigo)
                }
            } trailing: {
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
            .modifier(ConditionalAccessibilityAction(isActive: flag.isPreviewShortened, name: "Read Full Text") { showFullText = true })
            .accessibilityAction(named: Text("Edit \(flag.kindLabel)")) { showEditSheet = true }
            .accessibilityAction(named: Text("Unpublish \(flag.kindLabel)")) { showUnpublishConfirm = true }
            .accessibilityAction(named: Text("Delete \(flag.kindLabel)")) { showDeleteConfirm = true }
            .accessibilityAction(named: Text("Share \(flag.kindLabel)")) { presentShareSheet() }
            .sheet(isPresented: $showFullText) { GuidelineFlagFullText(flag: flag) }
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

    /// A full moderation record, not just the post: severity, every rule it
    /// matched with the checker's explanation, where it was posted and when,
    /// a link to the exact comment or post, then the text. It used to share
    /// only "Name on AppleVis:" and the body, so whoever received it
    /// couldn't tell why it was flagged or find it. Kept in English, like
    /// the rule names on this screen, since it's usually sent to the
    /// editorial team. Requested directly.
    private func presentShareSheet() {
        let message = shareText
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .present(activityVC, animated: true)
    }

    private var shareText: String {
        func severityName(_ severity: GuidelineWarning.Severity) -> String {
            switch severity {
            case .high:   return "High"
            case .medium: return "Medium"
            case .low:    return "Low"
            }
        }
        var lines = ["AppleVis guideline check: \(severityName(flag.highestSeverity))"]
        let byRank = flag.warnings.sorted { $0.severity.sortOrder < $1.severity.sortOrder }
        lines += byRank.map { "\($0.rule) (\(severityName($0.severity))): \($0.message)" }
        lines.append("")
        let when = flag.createdAt.formatted(date: .long, time: .shortened)
        lines.append(flag.isRootItem
            ? "\(flag.kindLabel) \"\(flag.itemTitle)\" by \(flag.authorName), \(when)"
            : "Comment by \(flag.authorName) in \"\(flag.itemTitle)\", \(when)")
        if let url = flag.url {
            lines.append(url)
        }
        lines.append("")
        lines.append(flag.body.strippingHTMLTags())
        return lines.joined(separator: "\n")
    }
}
