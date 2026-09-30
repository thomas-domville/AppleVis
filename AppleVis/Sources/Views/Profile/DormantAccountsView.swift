import Combine
import SwiftUI

/// How old an account must be to show. The scan always fetches everything
/// 30 days or older (the list's own rule); a longer age just narrows what's
/// shown, instantly, without scanning again. Requested directly.
enum DormantAgeFilter: Int, CaseIterable, Identifiable {
    case thirtyDays = 30
    case ninetyDays = 90
    case sixMonths = 182
    case oneYear = 365

    var id: Self { self }

    var displayName: String {
        switch self {
        case .thirtyDays: return String(localized: "30 Days")
        case .ninetyDays: return String(localized: "90 Days")
        case .sixMonths:  return String(localized: "6 Months")
        case .oneYear:    return String(localized: "1 Year")
        }
    }

    var cutoff: Date {
        Calendar.current.date(byAdding: .day, value: -rawValue, to: Date()) ?? Date()
    }
}

/// Keeps the last "Never Signed In" scan so the list is still there after
/// leaving the screen, like the App Directory Health Check.
@MainActor
final class DormantAccountStore: ObservableObject {
    static let shared = DormantAccountStore()

    @Published private(set) var accounts: [DormantAccount] = []
    @Published var ageFilter: DormantAgeFilter = .thirtyDays
    @Published var burstsOnly = false

    // Delete All Shown
    @Published private(set) var isBulkDeleting = false
    @Published private(set) var bulkDone = 0
    @Published private(set) var bulkTotal = 0
    private var bulkStopRequested = false

    /// The scanned accounts at least as old as the chosen age, and only the
    /// sign-up bursts when that's switched on.
    var visibleAccounts: [DormantAccount] {
        let cutoff = ageFilter.cutoff
        return accounts.filter { $0.createdAt <= cutoff && (!burstsOnly || $0.burstSize > 0) }
    }

    /// A sign-up burst: 3 or more accounts, each created within 30 minutes
    /// of the one before. Tuned against the live list on 2026-09-25 (418
    /// accounts): 10 minutes found almost nothing, while 30 minutes found 6
    /// bursts totalling 34 accounts, the largest 19 on one afternoon, which
    /// looks like a spam wave. Requested directly.
    nonisolated static let burstGap: TimeInterval = 30 * 60
    nonisolated static let burstMinimum = 3

    nonisolated static func markBursts(_ accounts: [DormantAccount]) -> [DormantAccount] {
        let sorted = accounts.sorted { $0.createdAt < $1.createdAt }
        var result: [DormantAccount] = []
        var run: [DormantAccount] = []
        func flush() {
            let size = run.count >= burstMinimum ? run.count : 0
            result += run.map { var a = $0; a.burstSize = size; return a }
            run = []
        }
        for account in sorted {
            if let last = run.last, account.createdAt.timeIntervalSince(last.createdAt) > burstGap {
                flush()
            }
            run.append(account)
        }
        flush()
        return result
    }
    @Published private(set) var isScanning = false
    @Published private(set) var foundSoFar = 0
    @Published private(set) var hasScanned = false
    @Published private(set) var lastScanDate: Date?
    @Published var error: String?

    /// The one rule for this list: created at least this many days ago and
    /// never signed in. Newer accounts are left out, since those people may
    /// still be about to verify their email and sign in. Requested directly.
    static let minimumAgeDays = 30

    func scan(csrfToken: String) async {
        guard !isScanning else { return }
        isScanning = true
        error = nil
        foundSoFar = 0
        defer { isScanning = false }
        do {
            accounts = Self.markBursts(try await APIClient.shared.adminAccounts.dormantAccounts(
                minimumAgeDays: Self.minimumAgeDays, csrfToken: csrfToken
            ) { [weak self] count in self?.foundSoFar = count })
            hasScanned = true
            lastScanDate = Date()
        } catch {
            self.error = String(localized: "Couldn't load the account list. Try again.")
        }
    }

    func remove(id: String) {
        accounts.removeAll { $0.id == id }
    }

    /// Deletes each account in turn, removing it from the list as it goes,
    /// so Stop leaves an accurate list behind. One at a time rather than in
    /// parallel, to go easy on the site. Returns how many were deleted and
    /// how many failed.
    func deleteAll(_ targets: [DormantAccount], csrfToken: String, ownId: String) async -> (deleted: Int, failed: Int) {
        guard !isBulkDeleting else { return (0, 0) }
        isBulkDeleting = true
        bulkStopRequested = false
        bulkDone = 0
        bulkTotal = targets.count
        defer { isBulkDeleting = false }
        var deleted = 0, failed = 0
        for account in targets where account.id != ownId {
            if bulkStopRequested { break }
            do {
                try await APIClient.shared.adminAccounts.deleteAccount(id: account.id, csrfToken: csrfToken)
                remove(id: account.id)
                deleted += 1
            } catch {
                failed += 1
            }
            bulkDone += 1
        }
        return (deleted, failed)
    }

    func stopBulkDelete() {
        bulkStopRequested = true
    }

    /// A blocked account stays in the list, marked Blocked, since it still
    /// has never signed in and may later be deleted or unblocked.
    func setBlocked(_ blocked: Bool, id: String) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[index].isBlocked = blocked
    }
}

/// Profile > Admin > Never Signed In: accounts created 30 or more days ago
/// that have never signed in, oldest first, with each one's profile a
/// double tap away and a confirmed Delete. Nothing loads until Start Scan.
/// Admin-only, so it's left out of Help, the Welcome Tour, and What's New.
/// Requested directly.
struct DormantAccountsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @ObservedObject private var store = DormantAccountStore.shared

    @State private var profileAccount: DormantAccount?
    @State private var pendingDelete: DormantAccount?
    /// `profileAccount` is already nil by the time `onDismiss` runs, so the
    /// row to return to is remembered separately.
    @State private var lastProfileId: String?
    @State private var hasFocusedTitle = false
    /// The exact accounts Delete All Shown will remove, captured when it's
    /// tapped, so changing a filter mid-confirmation can't change the list.
    @State private var bulkTargets: [DormantAccount] = []
    @State private var showBulkConfirm = false
    @State private var showBulkFinalConfirm = false
    @AccessibilityFocusState private var isBulkProgressFocused: Bool
    @AccessibilityFocusState private var isTitleFocused: Bool
    @AccessibilityFocusState private var isStatusFocused: Bool
    /// The account VoiceOver returns to after its profile closes, or moves
    /// to after the one before it is deleted.
    @AccessibilityFocusState private var focusedAccountId: String?

    var body: some View {
        Form {
            Section {
                Text("Lists accounts created 30 or more days ago that have never signed in.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

            // Filters first, then Start Scan, so they can be set before
            // scanning. They only narrow the list already found, so they
            // also apply straight away after a scan. Requested directly
            // (2026-09-28).
            Section {
                agePicker
                Toggle("Sign-Up Bursts Only", isOn: $store.burstsOnly)
                    .accessibilityHint(String(localized: "Shows only accounts created in a quick burst, which often means spam."))
                    .onChange(of: store.burstsOnly) { _, _ in announceCount() }
            }

            Section {
                Button {
                    startScan()
                } label: {
                    Label(store.hasScanned ? "Scan Again" : "Start Scan", systemImage: "play.circle")
                }
                .disabled(store.isScanning || store.isBulkDeleting)
            }

            if store.isScanning {
                Section {
                    HStack {
                        ProgressView()
                        Text(store.foundSoFar > 0
                             ? String(localized: "Finding accounts… \(store.foundSoFar) so far")
                             : String(localized: "Finding accounts…"))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityFocused($isStatusFocused)
                }
            } else if let error = store.error {
                Section {
                    Text(error).foregroundStyle(.red)
                        .accessibilityFocused($isStatusFocused)
                    Button("Try Again") { startScan() }
                }
            } else if store.hasScanned {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        // When nothing's found, the message is part of the
                        // summary VoiceOver lands on after a scan, so it's
                        // heard straight away rather than one swipe further
                        // down. Reported directly (2026-09-28).
                        if store.accounts.isEmpty {
                            Text("No accounts to review. Everyone older than 30 days has signed in at least once.")
                                .fontWeight(.semibold)
                        } else if store.visibleAccounts.isEmpty {
                            Text(store.burstsOnly
                                 ? "No accounts match. Choose a shorter age or turn off Sign-Up Bursts Only."
                                 : "No accounts are that old. Choose a shorter age.")
                                .fontWeight(.semibold)
                        }
                        Text(String(localized: "\(store.visibleAccounts.count) accounts"))
                            .fontWeight(.semibold)
                        if let date = store.lastScanDate {
                            Text(String(localized: "Last scan: \(date.formatted(.relative(presentation: .named)))"))
                                .font(.footnote)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityFocused($isStatusFocused)
                }

                if !store.visibleAccounts.isEmpty {
                    bulkDeleteSection

                    Section {
                        ForEach(store.visibleAccounts) { account in
                            row(account)
                        }
                    } footer: {
                        Text("Oldest first. Double-tap an account to review its profile.")
                    }
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Never Signed In")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !hasFocusedTitle else { return }
            hasFocusedTitle = true
            await retryAccessibilityFocus(into: $isTitleFocused)
        }
        .onChange(of: store.isScanning) { _, _ in
            Task { await retryAccessibilityFocus(into: $isStatusFocused) }
        }
        .sheet(item: $profileAccount, onDismiss: restoreFocusAfterProfile) { account in
            AuthorProfileSheet(authorId: account.id, fallbackName: account.displayName)
        }
        .confirmationDialog(
            pendingDelete.map { String(localized: "Delete \($0.displayName)'s account?") } ?? "",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { account in
            Button("Delete Account", role: .destructive) { Task { await delete(account) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This permanently deletes the account. It can't be undone.")
        }
        // Delete All Shown asks twice: once with the count, then a final
        // "are you sure", since it can remove hundreds of accounts at once.
        .confirmationDialog(
            String(localized: "Delete every account shown?"),
            isPresented: $showBulkConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete All Shown", role: .destructive) { showBulkFinalConfirm = true }
            Button("Cancel", role: .cancel) { bulkTargets = [] }
        } message: {
            Text(String(localized: "Accounts to delete: \(bulkTargets.count). This can't be undone."))
        }
        .alert(String(localized: "Are you sure?"), isPresented: $showBulkFinalConfirm) {
            Button("Delete Permanently", role: .destructive) { Task { await deleteAllShown() } }
            Button("Cancel", role: .cancel) { bulkTargets = [] }
        } message: {
            Text("This permanently deletes every account shown. It can't be undone.")
        }
    }

    // MARK: - Delete All Shown

    @ViewBuilder
    private var bulkDeleteSection: some View {
        Section {
            if store.isBulkDeleting {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: Double(store.bulkDone), total: Double(max(store.bulkTotal, 1)))
                    Text(String(localized: "Deleting \(store.bulkDone) of \(store.bulkTotal)…"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityFocused($isBulkProgressFocused)
                Button("Stop", role: .destructive) { store.stopBulkDelete() }
            } else {
                Button(role: .destructive) {
                    bulkTargets = store.visibleAccounts
                    showBulkConfirm = true
                } label: {
                    Label(String(localized: "Delete All Shown (\(store.visibleAccounts.count))"), systemImage: "trash")
                }
            }
        } footer: {
            if !store.isBulkDeleting {
                Text("Deletes every account in the list below, using the age and filter above.")
            }
        }
    }

    private func deleteAllShown() async {
        guard let user = auth.user, !bulkTargets.isEmpty else { return }
        let targets = bulkTargets
        bulkTargets = []
        Task { await retryAccessibilityFocus(into: $isBulkProgressFocused) }
        let result = await store.deleteAll(targets, csrfToken: user.csrfToken, ownId: user.uuid)
        let deletedPhrase = String(localized: "\(result.deleted) accounts")
        if result.failed > 0 {
            let failedPhrase = String(localized: "\(result.failed) accounts")
            toast.error(String(localized: "Deleted \(deletedPhrase). Couldn't delete \(failedPhrase)."))
        } else if result.deleted < targets.count {
            toast.success(String(localized: "Stopped. Deleted \(deletedPhrase)."))
        } else {
            toast.success(String(localized: "Deleted \(deletedPhrase)."))
        }
        await retryAccessibilityFocus(into: $isStatusFocused)
    }

    /// Speaks the new count after a filter changes the list out of view.
    private func announceCount() {
        // Nothing to count until a scan has run.
        guard store.hasScanned else { return }
        let count = store.visibleAccounts.count
        Task {
            // After VoiceOver has spoken the control's new value.
            try? await Task.sleep(for: .milliseconds(700))
            // With nothing left, say why and what to try, not just "0 accounts".
            let message = count > 0 ? String(localized: "\(count) accounts")
                : store.burstsOnly
                    ? String(localized: "No accounts match. Choose a shorter age or turn off Sign-Up Bursts Only.")
                    : String(localized: "No accounts are that old. Choose a shorter age.")
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    // MARK: - Age picker

    /// Narrows the scanned list instantly. A menu picker that also moves
    /// with a VoiceOver swipe up or down, speaking the new age; the new
    /// count is announced too, since the list below changes out of view.
    private var agePicker: some View {
        Picker("Minimum Account Age", selection: $store.ageFilter) {
            ForEach(DormantAgeFilter.allCases) { age in
                Text(age.displayName).tag(age)
            }
        }
        .pickerStyle(.menu)
        .accessibilityValue(Text(store.ageFilter.displayName))
        .accessibilityHint(String(localized: "Shows only accounts at least this old."))
        .accessibilityAdjustableAction { direction in
            let all = DormantAgeFilter.allCases
            guard let index = all.firstIndex(of: store.ageFilter) else { return }
            switch direction {
            case .increment: store.ageFilter = all[min(index + 1, all.count - 1)]
            case .decrement: store.ageFilter = all[max(index - 1, 0)]
            @unknown default: break
            }
        }
        .onChange(of: store.ageFilter) { _, _ in announceCount() }
    }

    // MARK: - Row

    private func row(_ account: DormantAccount) -> some View {
        Button {
            openProfile(account)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                if account.username != account.displayName && !account.username.isEmpty {
                    Text(account.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(detailText(account))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(account))
        .accessibilityHint(String(localized: "Double-tap to view profile."))
        .accessibilityFocused($focusedAccountId, equals: account.id)
        .voiceOverAwareSwipeActions {
            Button(role: .destructive) {
                pendingDelete = account
            } label: {
                Label("Delete Account", systemImage: "trash")
            }
            Button {
                Task { await setBlocked(!account.isBlocked, account) }
            } label: {
                Label(account.isBlocked ? "Unblock Account" : "Block Account",
                      systemImage: account.isBlocked ? "lock.open" : "lock")
            }
            .tint(.orange)
        }
        .accessibilityAction(named: Text(account.isBlocked ? "Unblock Account" : "Block Account")) {
            Task { await setBlocked(!account.isBlocked, account) }
        }
        .accessibilityAction(named: Text("Delete Account")) { pendingDelete = account }
        .modifier(ConditionalAccessibilityAction(isActive: account.websiteURL != nil, name: "Open on Website") {
            if let url = account.websiteURL { UIApplication.shared.open(url) }
        })
        .contextMenu {
            Button {
                openProfile(account)
            } label: {
                Label("View Profile", systemImage: "person.crop.circle")
            }
            if let url = account.websiteURL {
                Link(destination: url) {
                    Label("Open on Website", systemImage: "arrow.up.forward.app")
                }
            }
            Button {
                Task { await setBlocked(!account.isBlocked, account) }
            } label: {
                Label(account.isBlocked ? "Unblock Account" : "Block Account",
                      systemImage: account.isBlocked ? "lock.open" : "lock")
            }
            Button(role: .destructive) {
                pendingDelete = account
            } label: {
                Label("Delete Account", systemImage: "trash")
            }
        }
    }

    /// Exactly how long ago, in calendar years, months, and days (the two
    /// largest that apply), and the date: "1 year, 9 months ago, on
    /// January 3, 2025". The relative wording used before rounded, so an
    /// account 1 year and 9 months old was read as 2 years. Reported
    /// directly (2026-09-30).
    private static func createdText(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date, to: Date())
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.year, .month, .day]
        formatter.maximumUnitCount = 2
        formatter.calendar = Calendar.current
        let age = formatter.string(from: parts) ?? date.formatted(.relative(presentation: .named))
        let day = date.formatted(date: .long, time: .omitted)
        return String(localized: "Created \(age) ago, on \(day)")
    }

    private func detailText(_ account: DormantAccount) -> String {
        var text = String(localized: "\(Self.createdText(account.createdAt)) · Never signed in")
        if account.isBlocked { text = String(localized: "\(text) · Blocked") }
        if account.burstSize > 0 {
            let group = String(localized: "\(account.burstSize) accounts")
            text = String(localized: "\(text) · Sign-up burst of \(group)")
        }
        return text
    }

    private func accessibilityLabel(_ account: DormantAccount) -> String {
        var parts = [account.displayName]
        if account.username != account.displayName && !account.username.isEmpty {
            parts.append(String(localized: "username \(account.username)"))
        }
        parts.append(Self.createdText(account.createdAt))
        parts.append(String(localized: "Never signed in"))
        if account.isBlocked { parts.append(String(localized: "Blocked")) }
        if account.burstSize > 0 {
            let group = String(localized: "\(account.burstSize) accounts")
            parts.append(String(localized: "Part of a sign-up burst of \(group)"))
        }
        return parts.joined(separator: ". ")
    }

    // MARK: - Actions

    private func startScan() {
        guard let token = auth.user?.csrfToken else { return }
        Task { await store.scan(csrfToken: token) }
    }

    /// Back on the account whose profile was just open.
    private func restoreFocusAfterProfile() {
        guard let id = lastProfileId else { return }
        Task { await retryAccessibilityFocus(into: $focusedAccountId, returningTo: id) }
    }

    private func openProfile(_ account: DormantAccount) {
        lastProfileId = account.id
        profileAccount = account
    }

    /// Block is the reversible alternative to Delete, so it doesn't ask
    /// first. The row stays, marked Blocked, and VoiceOver stays on it.
    private func setBlocked(_ blocked: Bool, _ account: DormantAccount) async {
        guard let user = auth.user, account.id != user.uuid else { return }
        do {
            try await APIClient.shared.adminAccounts.setBlocked(blocked, id: account.id, csrfToken: user.csrfToken)
            store.setBlocked(blocked, id: account.id)
            toast.success(blocked ? String(localized: "Account blocked") : String(localized: "Account unblocked"))
        } catch APIError.forbidden {
            toast.error(String(localized: "You don't have permission to change this account."))
        } catch {
            toast.error(blocked
                ? String(localized: "Couldn't block this account. Try again.")
                : String(localized: "Couldn't unblock this account. Try again."))
        }
    }

    private func delete(_ account: DormantAccount) async {
        guard let user = auth.user, account.id != user.uuid else { return }
        let accounts = store.visibleAccounts
        var next: String?
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            if index + 1 < accounts.count {
                next = accounts[index + 1].id
            } else if index > 0 {
                next = accounts[index - 1].id
            }
        }
        do {
            try await APIClient.shared.adminAccounts.deleteAccount(id: account.id, csrfToken: user.csrfToken)
            store.remove(id: account.id)
            toast.success(String(localized: "Account deleted"))
            if let next {
                await retryAccessibilityFocus(into: $focusedAccountId, returningTo: next)
            } else {
                await retryAccessibilityFocus(into: $isStatusFocused)
            }
        } catch APIError.forbidden {
            toast.error(String(localized: "You don't have permission to delete this account."))
        } catch {
            toast.error(String(localized: "Couldn't delete this account. Try again."))
        }
    }
}
