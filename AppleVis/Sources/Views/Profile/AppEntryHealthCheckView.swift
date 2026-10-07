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
    /// Shared, so the last results survive leaving this screen. "Try Again"
    /// repeats the scan that actually ran (`scanner.lastScope`), not
    /// whatever the pickers show now.
    @ObservedObject private var scanner = AppEntryHealthScanner.shared
    @State private var range: AppHealthScanRange = .day
    @State private var selectedCategory: AppCategory?
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
    /// The flagged app VoiceOver should land on after coming back from its
    /// App Entry page, or after the previous one is fixed and leaves the list.
    @AccessibilityFocusState private var focusedFlagId: String?
    /// `.task` runs again every time this screen reappears, so coming back
    /// from an App Entry page used to throw VoiceOver back up to the intro
    /// text. Only the first appearance focuses it now. Reported directly.
    @State private var hasFocusedTitle = false
    /// App entries changed on their own page (refreshed, edited,
    /// unpublished, or deleted) while it was open from a row here.
    /// Cleared from the results when you come back. Requested directly.
    @State private var changedAppIds: Set<String> = []

    var body: some View {
        Form {
            Section {
                Text("Checks App Directory entries against the App Store. Scan recent entries or one category.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

            Section("Recent Activity") {
                // A menu picker, not segmented: segmented reads as unrelated
                // buttons with VoiceOver (see AppBrowseView's platform
                // picker). Swipe up or down changes it, with the new range
                // spoken via the explicit value.
                Picker("Time Range", selection: $range) {
                    ForEach(AppHealthScanRange.allCases) { r in
                        Text(r.displayName).tag(r)
                    }
                }
                .pickerStyle(.menu)
                .disabled(scanner.isScanning)
                .accessibilityValue(Text(range.displayName))
                .accessibilityHint(String(localized: "Choose how far back to scan."))
                .accessibilityAdjustableAction { direction in
                    let all = AppHealthScanRange.allCases
                    guard let index = all.firstIndex(of: range) else { return }
                    switch direction {
                    case .increment: range = all[min(index + 1, all.count - 1)]
                    case .decrement: range = all[max(index - 1, 0)]
                    @unknown default: break
                    }
                }

                Button {
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
                        VStack(alignment: .leading, spacing: 2) {
                            if scanner.isStopping {
                                Text("Stopping after the current batch…")
                            } else {
                                Text("Checking the App Directory against the App Store…")
                            }
                            // A big category takes a while; this shows it's
                            // moving. Requested directly.
                            if scanner.detailsTotal > 0 {
                                Text("Apps checked: \(scanner.detailsChecked) of \(scanner.detailsTotal)")
                                    .font(.footnote)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.updatesFrequently)
                    .accessibilityFocused($isStatusFocused)
                    .progressTick(on: scanner.detailsChecked)

                    // Ends a long scan early and keeps what it's found so
                    // far, instead of splitting big categories into batches
                    // by hand. Requested directly.
                    Button(role: .destructive) {
                        scanner.stop()
                    } label: {
                        Label("Stop Scan", systemImage: "stop.circle")
                    }
                    .disabled(scanner.isStopping)
                    .accessibilityHint(String(localized: "Stops after the current batch and shows what's been found so far."))
                }
            } else if let error = scanner.error {
                Section {
                    Text(error).foregroundStyle(.red)
                        .accessibilityFocused($isStatusFocused)
                    Button("Try Again") {
                        Task { await scanner.repeatLastScan() }
                    }
                }
            } else if scanner.scannedAppCount > 0 {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        // When nothing's found, the message is part of the
                        // summary VoiceOver lands on after a scan, so it's
                        // heard straight away rather than one swipe further
                        // down. Reported directly (2026-09-28).
                        if scanner.flags.isEmpty {
                            Text("Nothing flagged — every entry matches the App Store.")
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("\(scanner.scannedAppCount) apps checked")
                            Spacer()
                            Text("\(scanner.flags.count) flagged")
                                .fontWeight(.semibold)
                        }
                        if let lastScanText {
                            Text(lastScanText)
                                .font(.footnote)
                        }
                        if scanner.lastScanWasStopped {
                            Text("Stopped early. These results cover only the apps checked before you stopped.")
                                .font(.footnote)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityFocused($isStatusFocused)
                }

                // Refresh App Details for many entries at once, changing
                // only what's chosen and really different on each.
                // Removed apps have nothing to refresh from. Requested
                // directly (2026-10-02).
                let refreshable = scanner.flags.filter { $0.kind.group != .removed }
                if !refreshable.isEmpty {
                    Section {
                        NavigationLink {
                            AppHealthBulkRefreshView(flags: refreshable) { flag in
                                scanner.removeFlag(id: flag.id)
                            }
                        } label: {
                            Label(String(localized: "Update in Bulk (\(refreshable.count))"), systemImage: "arrow.triangle.2.circlepath.circle")
                        }
                    } footer: {
                        Text("Update several entries from the App Store at once. Each one only changes what's different on the App Store.")
                    }
                }

                if !scanner.flags.isEmpty {
                    // One section per kind of problem, most urgent first:
                    // removed apps usually need action; title changes are
                    // usually a quick refresh; minor differences can wait.
                    ForEach(AppHealthFlag.Group.allCases) { group in
                        let groupFlags = scanner.flags.filter { $0.kind.group == group }
                        if !groupFlags.isEmpty {
                            Section {
                                ForEach(groupFlags) { flag in
                                    flagRow(flag)
                                }
                            } header: {
                                Text(String(localized: "\(Self.groupName(group)) (\(groupFlags.count))"))
                            }
                        }
                    }
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("App Directory Health Check")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !hasFocusedTitle else { return }
            hasFocusedTitle = true
            await retryAccessibilityFocus(into: $isTitleFocused)
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .appEntryChanged)) { note in
            if let id = note.object as? String { changedAppIds.insert(id) }
        }
    }

    private func flagRow(_ flag: AppHealthFlag) -> some View {
        NavigationLink {
            AppDetailView(appId: flag.appId, platform: .ios)
                .onDisappear {
                    if changedAppIds.remove(flag.appId) != nil {
                        handled(flag, announcing: String(localized: "Updated and removed from the list."))
                    } else {
                        Task { await retryAccessibilityFocus(into: $focusedFlagId, returningTo: flag.id) }
                    }
                }
        } label: {
            AppHealthFlagRow(flag: flag)
        }
        .accessibilityFocused($focusedFlagId, equals: flag.id)
        .modifier(AppHealthFlagActions(flag: flag, onHandled: { handled(flag) }))
    }

    static func groupName(_ group: AppHealthFlag.Group) -> String {
        switch group {
        case .removed:              return String(localized: "Removed from the App Store")
        case .titleChanged:         return String(localized: "Title Changed")
        case .detailsOutdated:      return String(localized: "Other Details Out of Date")
        case .minorTitleDifference: return String(localized: "Minor Title Differences")
        }
    }

    /// "Last scan: Past Week, 10 minutes ago", so results kept from an
    /// earlier visit are clearly labelled as such.
    private var lastScanText: String? {
        guard let scope = scanner.lastScope, let date = scanner.lastScanDate else { return nil }
        let when = date.formatted(.relative(presentation: .named))
        return String(localized: "Last scan: \(scope.displayName), \(when)")
    }

    /// Removes a flag that's been fixed, unpublished, or deleted, and moves
    /// VoiceOver to the next one (or the previous, at the end of the list),
    /// so it doesn't land at the top of the screen. With nothing left, it
    /// goes to the results summary. With `announcing`, VoiceOver says that
    /// first and focus moves once it's finished, so the message isn't cut
    /// off by the next row's name.
    private func handled(_ flag: AppHealthFlag, announcing message: String? = nil) {
        let flags = scanner.flags
        var next: String?
        if let index = flags.firstIndex(where: { $0.id == flag.id }) {
            if index + 1 < flags.count {
                next = flags[index + 1].id
            } else if index > 0 {
                next = flags[index - 1].id
            }
        }
        scanner.removeFlag(id: flag.id)
        // Straight on to the next entry. It used to wait for VoiceOver to
        // finish the message first, up to three seconds. With a message, a
        // sound and tap confirm it, and the words are only spoken (after
        // the move) when sounds and haptics are both off. Without one, the
        // action's own toast already plays its sound (2026-10-07).
        let spoken = message.flatMap { ActionCue.play(next == nil ? .success : .markedRead, orSay: $0) }
        Task {
            if let next {
                await moveAccessibilityFocusPromptly(to: next, into: $focusedFlagId, saying: spoken)
            } else {
                await moveAccessibilityFocusPromptly(into: $isStatusFocused, saying: spoken)
            }
        }
    }

}

private struct AppHealthFlagRow: View {
    let flag: AppHealthFlag

    private var reasonColor: Color {
        switch flag.kind {
        case .removed:              return Color(red: 0.725, green: 0.110, blue: 0.110)
        case .titleChanged, .detailsOutdated: return Color(red: 0.706, green: 0.325, blue: 0.035)
        case .minorTitleDifference: return .secondary
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
        let base: String
        switch flag.kind {
        case .removed:
            return String(localized: "Removed — No longer found on the App Store.")
        case .detailsOutdated:
            return String(localized: "Out of Date — \(outdatedText).")
        case .titleChanged(let newTitle):
            base = String(localized: "Title Changed — App Store now shows: \(newTitle)")
        case .minorTitleDifference(let newTitle):
            base = String(localized: "Minor Title Difference — App Store shows: \(newTitle)")
        }
        // Everything else that's out of date rides along, so one row tells
        // the whole story, not just the title. Requested directly.
        guard !flag.outdatedFields.isEmpty else { return base }
        return base + " " + String(localized: "Also out of date: \(outdatedText).")
    }

    /// Only what actually differs, e.g. "Version 3.4 on the App Store, 3.2
    /// on AppleVis. Description".
    private var outdatedText: String {
        flag.outdatedFields.map { Self.summary($0) }.joined(separator: ". ")
    }

    private static func summary(_ field: AppHealthFlag.OutdatedField) -> String {
        switch field.id {
        case "version":
            let new = field.newValue ?? ""
            let old = field.oldValue ?? ""
            return old.isEmpty
                ? String(localized: "Version \(new) on the App Store, none on AppleVis")
                : String(localized: "Version \(new) on the App Store, \(old) on AppleVis")
        case "devices":
            return String(localized: "Supported devices: App Store suggests \(field.newValue ?? "")")
        default:
            return field.label
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
                .lineLimit(5)
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
    // Refresh App Details, the same review-and-choose sheet the App Entry
    // page's admin menu opens. Requested directly.
    @State private var refreshRequest: AppInfoRefreshRequest?
    @State private var refreshDetail: AppDetail?
    @State private var refreshMetadata: ItunesMetadata?
    @State private var selectedFieldIDs: Set<String> = []
    @State private var selectedDevices: Set<String> = []
    @State private var isLoadingRefresh = false
    @State private var isRefreshing = false

    private static let nodeType = "ios_app_directory"

    /// A removed app has nothing on the App Store to refresh from.
    private var canRefresh: Bool {
        if case .removed = flag.kind { return false }
        return true
    }

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
                if canRefresh {
                    Button {
                        Task { await beginRefresh() }
                    } label: {
                        Label("Update from App Store", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .tint(.green)
                }
            }
            .modifier(ConditionalAccessibilityAction(isActive: canRefresh, name: "Update from App Store") {
                Task { await beginRefresh() }
            })
            // Share, Open in App Store, and (for a removed app) Search the
            // App Store: kept out of the swipe set so it stays short, and
            // offered by touch and hold instead. Search helps spot an app
            // that was republished under a new listing, which only needs a
            // new link rather than unpublishing. Requested directly.
            .contextMenu {
                Button {
                    presentShareSheet()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                if let appStoreURL {
                    Link(destination: appStoreURL) {
                        Label("Open in App Store", systemImage: "arrow.up.forward.app")
                    }
                }
                if let searchURL {
                    Link(destination: searchURL) {
                        Label("Search App Store for This Name", systemImage: "magnifyingglass")
                    }
                }
            }
            .accessibilityAction(named: Text("Share")) { presentShareSheet() }
            .modifier(ConditionalAccessibilityAction(isActive: appStoreURL != nil, name: "Open in App Store") {
                if let appStoreURL { UIApplication.shared.open(appStoreURL) }
            })
            .modifier(ConditionalAccessibilityAction(isActive: searchURL != nil, name: "Search App Store for This Name") {
                if let searchURL { UIApplication.shared.open(searchURL) }
            })
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
            .sheet(item: $refreshRequest) { request in
                UpdateAppInfoSheet(
                    diffs: request.diffs,
                    selectedFieldIDs: $selectedFieldIDs,
                    selectedDevices: $selectedDevices,
                    isUpdating: isRefreshing,
                    onConfirm: { Task { await confirmRefresh() } }
                )
            }
            .sheet(item: $editingNode) { node in
                EditNodeSheet(initialTitle: node.title, initialBody: node.body, nodeTypeSuffix: node.nodeTypeSuffix) { newTitle, newBody in
                    try await saveEdit(title: newTitle, body: newBody, format: node.format)
                }
            }
            // Ticks while the App Store is checked before Refresh opens.
            // (2026-10-07)
            .waitingTick(while: isLoadingRefresh, stillWaiting: String(localized: "Still checking the App Store."))
    }

    private func beginEdit() async {
        guard let detail = try? await APIClient.shared.apps.detail(id: flag.appId, platform: .ios) else {
            toast.error(String(localized: "Couldn't load this app entry. Try again."))
            return
        }
        editingNode = EditableNode(title: detail.name, body: detail.rawBody, format: detail.bodyFormat, nodeTypeSuffix: Self.nodeType)
    }

    /// The entry's own App Store link, while the app is still listed.
    private var appStoreURL: URL? {
        if case .removed = flag.kind { return nil }
        return flag.appStoreUrl.flatMap(URL.init)
    }

    /// App Store search for the entry's name, offered only when its listing
    /// is gone.
    private var searchURL: URL? {
        guard case .removed = flag.kind,
              let term = flag.appName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?media=software&term=\(term)")
    }

    /// What was found and where, ready to send to the editorial team. Kept
    /// in English like the Guideline Violation Check's own shared reports.
    private var shareText: String {
        var lines = ["AppleVis App Directory check: \(Self.englishReason(flag.kind))", "App: \(flag.appName)"]
        switch flag.kind {
        case .titleChanged(let newTitle), .minorTitleDifference(let newTitle):
            lines.append("App Store now shows: \(newTitle)")
        case .removed:
            lines.append("No longer found on the App Store.")
        case .detailsOutdated:
            break
        }
        for field in flag.outdatedFields {
            if let new = field.newValue {
                lines.append("Out of date: \(field.englishLabel) (AppleVis: \(field.oldValue ?? "none"); App Store: \(new))")
            } else {
                lines.append("Out of date: \(field.englishLabel)")
            }
        }
        if !flag.appleVisUrl.isEmpty { lines.append("AppleVis: \(flag.appleVisUrl)") }
        if let store = flag.appStoreUrl, !store.isEmpty { lines.append("App Store: \(store)") }
        return lines.joined(separator: "\n")
    }

    private static func englishReason(_ kind: AppHealthFlag.Kind) -> String {
        switch kind {
        case .removed:              return "Removed from the App Store"
        case .titleChanged:         return "Title Changed"
        case .detailsOutdated:      return "Other Details Out of Date"
        case .minorTitleDifference: return "Minor Title Difference"
        }
    }

    private func presentShareSheet() {
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController?
            .present(activityVC, animated: true)
    }

    /// Loads the entry as saved on AppleVis and its live App Store listing,
    /// then opens the same field-by-field sheet as the App Entry page.
    private func beginRefresh() async {
        guard !isLoadingRefresh else { return }
        isLoadingRefresh = true
        defer { isLoadingRefresh = false }
        guard let detail = try? await APIClient.shared.apps.detail(id: flag.appId, platform: .ios, forceRefresh: true),
              let storeUrl = detail.appStoreUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !storeUrl.isEmpty,
              case .found(let metadata) = await ItunesAPI.lookupMetadata(appStoreUrl: storeUrl, english: true)
        else {
            toast.error(String(localized: "Couldn't load the App Store details. Try again."))
            return
        }
        // The same choices as Refresh App Details on the entry's page,
        // including the iOS Version Tested check against this device. Only
        // the scan leaves that out, so it doesn't flag every entry tested
        // on another iOS. Reported directly (2026-10-02).
        let diffs = AppInfoFieldDiff.build(detail: detail, metadata: metadata, testedOnThisDevice: UIDevice.current.systemVersion)
        guard diffs.contains(where: \.changed) else {
            // Says why the entry left the list, since nothing opens.
            toast.success(String(localized: "This app entry already matches the App Store, so it's been cleared from the list."))
            onHandled()
            return
        }
        selectedFieldIDs = Set(diffs.filter { $0.changed && $0.startsSelected }.map(\.id))
        selectedDevices = Set(diffs.first { $0.id == "devices" }?.deviceChoices ?? [])
        refreshDetail = detail
        refreshMetadata = metadata
        refreshRequest = AppInfoRefreshRequest(diffs: diffs)
    }

    private func confirmRefresh() async {
        guard let user = auth.user, let detail = refreshDetail, let metadata = refreshMetadata, !selectedFieldIDs.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await APIClient.shared.apps.updateAppInformation(
                detail: detail, metadata: metadata, includedFields: selectedFieldIDs,
                devices: ["iPhone", "iPad", "Mac"].filter(selectedDevices.contains),
                testedOnIOS: UIDevice.current.systemVersion,
                csrfToken: user.csrfToken
            )
            toast.success(String(localized: "Updated from the App Store"))
            refreshRequest = nil
            onHandled()
        } catch APIError.forbidden {
            toast.error(String(localized: "You don't have permission to refresh this app."))
        } catch APIError.unauthorized {
            toast.error(String(localized: "Please sign in again to refresh this app."))
        } catch {
            toast.error(String(localized: "We couldn't refresh the app details."))
        }
    }

    private func saveEdit(title: String, body: String, format: String) async throws {
        guard let user = auth.user else { return }
        try await APIClient.shared.content.editNode(nodeId: flag.appId, nodeType: Self.nodeType, title: title, body: body, format: format, csrfToken: user.csrfToken)
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
