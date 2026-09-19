import SwiftUI

/// Scans iOS App Directory entries for ones that have been delisted from
/// the App Store, or whose live title no longer matches what AppleVis has
/// on file — see `AppEntryHealthScanner` for how the scan itself works.
/// Two independent scopes rather than one all-or-nothing sweep of the
/// entire directory: Recent Activity (entries added within a chosen
/// window) and By Category (one whole category at a time) — requested
/// directly after the original single full-directory scan was judged too
/// heavy to run casually.
/// Deliberately excluded from Help content, the Welcome Tour, and What's
/// New — this is internal team tooling, not a user-facing feature, and
/// gating on `auth.user?.isAdmin` already means almost nobody would ever
/// see a mention of it anyway. Applies to every item under Profile > Admin.
/// Requested directly.
struct AppEntryHealthCheckView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @StateObject private var scanner = AppEntryHealthScanner()
    @State private var range: AppHealthScanRange = .day
    @State private var selectedCategory: AppCategory?
    /// So "Try Again" repeats whichever of the two scans actually failed,
    /// rather than guessing from whatever the pickers currently show.
    @State private var lastScan: LastScan?

    private enum LastScan {
        case recent(AppHealthScanRange)
        case category(AppCategory)
    }
    @AccessibilityFocusState private var isTitleFocused: Bool
    /// Shared by whichever status section is currently showing — "Checking
    /// the App Directory…", the error message, or the results summary —
    /// since exactly one of them is ever present at a time. Without this,
    /// tapping Start Scan removed the button VoiceOver was focused on and
    /// replaced it with new content nothing ever moved focus to, so a
    /// VoiceOver user got no indication the tap did anything at all — same
    /// for when the scan finishes and the "Checking…" section is itself
    /// swapped out for the results. Reported directly: "double tap on Start
    /// Scan just seems to do nothing."
    @AccessibilityFocusState private var isStatusFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("Checks App Directory entries against the live App Store — either the ones added recently, or one whole category at a time. Both can take a little while, so nothing starts until you tap one of the Start Scan buttons below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

            Section("Recent Activity") {
                Picker("Time Range", selection: $range) {
                    ForEach(AppHealthScanRange.allCases) { r in
                        Text(r.displayName).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(scanner.isScanning)
                .accessibilityHint(String(localized: "Choose how far back to scan."))

                Button {
                    lastScan = .recent(range)
                    Task { await scanner.scanRecent(range: range) }
                } label: {
                    Label("Start Scan", systemImage: "play.circle")
                }
                .disabled(scanner.isScanning)
                .accessibilityLabel(String(localized: "Start Recent Activity Scan: \(range.displayName)"))
            }

            Section("By Category") {
                if scanner.categories.isEmpty {
                    Text("Loading categories…")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(scanner.categories) { category in
                            Text(category.name).tag(Optional(category))
                        }
                    }
                    .disabled(scanner.isScanning)
                }

                Button {
                    guard let selectedCategory else { return }
                    lastScan = .category(selectedCategory)
                    Task { await scanner.scanCategory(selectedCategory) }
                } label: {
                    Label("Start Scan", systemImage: "play.circle")
                }
                .disabled(scanner.isScanning || selectedCategory == nil)
                .accessibilityLabel(String(localized: "Start Category Scan: \(selectedCategory?.name ?? "")"))
            }

            if scanner.isScanning {
                Section {
                    HStack {
                        ProgressView()
                        Text("Checking the App Directory against the App Store…")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityFocused($isStatusFocused)
                }
            } else if let error = scanner.error {
                Section {
                    Text(error).foregroundStyle(.red)
                        .accessibilityFocused($isStatusFocused)
                    Button("Try Again") {
                        Task {
                            switch lastScan {
                            case .recent(let range): await scanner.scanRecent(range: range)
                            case .category(let category): await scanner.scanCategory(category)
                            case nil: break
                            }
                        }
                    }
                }
            } else if scanner.scannedAppCount > 0 {
                Section {
                    HStack {
                        Text("\(scanner.scannedAppCount) apps checked")
                        Spacer()
                        Text("\(scanner.flags.count) flagged")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityFocused($isStatusFocused)
                }

                if scanner.flags.isEmpty {
                    Section {
                        Text("Nothing flagged — every entry matches the App Store.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(scanner.flags) { flag in
                            NavigationLink {
                                AppDetailView(appId: flag.appId, platform: .ios)
                            } label: {
                                AppHealthFlagRow(flag: flag)
                            }
                            .modifier(AppHealthFlagActions(flag: flag, onHandled: { scanner.removeFlag(id: flag.id) }))
                        }
                    }
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("App Directory Health Check")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
        .task { await scanner.loadCategories() }
        // Defaults the category picker to something other than "no
        // selection" the moment the list loads, so the Start Scan button
        // below isn't stuck disabled on first view.
        .onChange(of: scanner.categories) { _, newCategories in
            if selectedCategory == nil {
                selectedCategory = newCategories.first
            }
        }
        // Fires on both transitions this screen has: a scan starting
        // (isScanning false -> true, lands on "Checking…") and finishing
        // (true -> false, lands on whichever of error/results is now
        // showing).
        .onChange(of: scanner.isScanning) { _, _ in
            Task { await retryAccessibilityFocus(into: $isStatusFocused) }
        }
    }
}

private struct AppHealthFlagRow: View {
    let flag: AppHealthFlag

    private var reasonColor: Color {
        switch flag.kind {
        case .removed:      return Color(red: 0.725, green: 0.110, blue: 0.110)
        case .titleChanged: return Color(red: 0.706, green: 0.325, blue: 0.035)
        }
    }

    /// One consolidated statement instead of a separate badge ("Removed")
    /// plus a near-duplicate detail sentence ("No longer found on the App
    /// Store.") right under it — those two used to say almost the same
    /// thing in slightly different words. App name leads (this is
    /// fundamentally "here's an app, here's what's wrong with it," not a
    /// queue to triage by problem type), with this as the one clear
    /// answer to "why is this here." Requested directly.
    private var reason: String {
        switch flag.kind {
        case .removed:
            return String(localized: "Removed — No longer found on the App Store.")
        case .titleChanged(let newTitle):
            return String(localized: "Title Changed — App Store now shows: \(newTitle)")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(flag.appName)
                .font(.subheadline).fontWeight(.semibold)
                .lineLimit(1)
            Text(reason)
                .font(.footnote).fontWeight(.medium)
                .foregroundStyle(reasonColor)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(flag.appName). \(reason)"))
    }
}

/// Edit/Unpublish/Delete for a flagged app entry, as a swipe-action set on
/// the admin list row — every flag here is a root iOS App Directory entry
/// (never a review/comment), so unlike the Guideline Violation Check's
/// equivalent, there's no comment-vs-root branching: it's always
/// `editNode`/`unpublishNode`/`deleteNode` against the one fixed node type,
/// "ios_app_directory". Reuses the exact same `EditNodeSheet`/
/// `EditableNode` the App Entry page's own Edit action already uses —
/// fetches that one app's full detail on demand only when Edit is tapped,
/// since the scan itself only ever loads the lighter `AppListing` shape
/// (deliberately, to keep the batched scan cheap). Every viewer of this
/// screen is already an admin (Profile > Admin is `isAdmin`-gated), so
/// there's no separate "own content" case to gate Edit/Delete behind.
/// Requested directly.
private struct AppHealthFlagActions: ViewModifier {
    let flag: AppHealthFlag
    let onHandled: () -> Void

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @State private var showUnpublishConfirm = false
    @State private var showDeleteConfirm = false
    @State private var editingNode: EditableNode?

    private static let nodeType = "ios_app_directory"

    func body(content: Content) -> some View {
        content
            // Swipe actions are unreachable to a VoiceOver user (their
            // one-finger swipe is already claimed for element navigation) —
            // see VoiceOverAwareSwipeActions's doc comment. The
            // accessibility actions below are the real path for them.
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
                    Task { await beginEdit() }
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.blue)
            }
            .accessibilityAction(named: Text("Edit \(ContentKind.appListing.displayName)")) { Task { await beginEdit() } }
            .accessibilityAction(named: Text("Unpublish \(ContentKind.appListing.displayName)")) { showUnpublishConfirm = true }
            .accessibilityAction(named: Text("Delete \(ContentKind.appListing.displayName)")) { showDeleteConfirm = true }
            .confirmationDialog(
                String(localized: "Unpublish this \(ContentKind.appListing.displayName.lowercased())?"),
                isPresented: $showUnpublishConfirm, titleVisibility: .visible
            ) {
                Button("Unpublish", role: .destructive) { Task { await unpublish() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This hides it from public view.")
            }
            .confirmationDialog(
                String(localized: "Delete this entire \(ContentKind.appListing.displayName.lowercased())?"),
                isPresented: $showDeleteConfirm, titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { Task { await delete() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(String(localized: "This permanently removes the entire \(ContentKind.appListing.displayName.lowercased()) and everything posted underneath it."))
            }
            .sheet(item: $editingNode) { node in
                EditNodeSheet(initialTitle: node.title, initialBody: node.body) { newTitle, newBody in
                    try await saveEdit(title: newTitle, body: newBody)
                }
            }
    }

    private func beginEdit() async {
        guard let detail = try? await APIClient.shared.apps.detail(id: flag.appId, platform: .ios) else {
            toast.error(String(localized: "Couldn't load this app entry. Try again."))
            return
        }
        editingNode = EditableNode(title: detail.name, body: detail.body, nodeTypeSuffix: Self.nodeType)
    }

    private func saveEdit(title: String, body: String) async throws {
        guard let user = auth.user else { return }
        try await APIClient.shared.content.editNode(nodeId: flag.appId, nodeType: Self.nodeType, title: title, body: body, csrfToken: user.csrfToken)
        toast.success(String(localized: "App Entry updated"))
        onHandled()
    }

    private func unpublish() async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.unpublishNode(nodeId: flag.appId, nodeType: Self.nodeType, csrfToken: user.csrfToken)
            toast.success(String(localized: "App Entry unpublished"))
            onHandled()
        } catch {
            toast.error(String(localized: "Couldn't unpublish this. Try again."))
        }
    }

    private func delete() async {
        guard let user = auth.user else { return }
        do {
            try await APIClient.shared.content.deleteNode(nodeId: flag.appId, nodeType: Self.nodeType, csrfToken: user.csrfToken)
            toast.success(String(localized: "App Entry deleted"))
            onHandled()
        } catch {
            toast.error(String(localized: "Couldn't delete this. Try again."))
        }
    }
}
