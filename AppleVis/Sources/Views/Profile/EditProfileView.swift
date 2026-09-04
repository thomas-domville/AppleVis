import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss

    @State private var realName = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var interests = ""
    @State private var homepage = ""
    @State private var twitter = ""
    @State private var facebook = ""
    @State private var mastodon = ""
    @State private var owns = ""
    @State private var timezone = ""
    @State private var allowsContact = true

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showCountryPicker = false
    @State private var showBioAssist = false
    @State private var showDevicesPicker = false
    @State private var showTimeZonePicker = false
    @AccessibilityFocusState private var isErrorFocused: Bool
    /// Had no initial-load focus at all. Full app-wide focus audit,
    /// requested directly.
    @AccessibilityFocusState private var isIntroFocused: Bool

    /// Same gate ContactView's Rewrite button uses — bio-drafting is the
    /// same category of "AI helps with what you're writing" feature, not a
    /// distinct setting of its own.
    private var bioAssistAvailable: Bool {
        preferences.composeRewriteEnabled && IntelligenceService.isAvailable
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Profile information is public. Your username and AppleVis ID cannot be changed here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isIntroFocused)
                }

                Section("Public Identity") {
                    LabeledContent("Username") {
                        Text(auth.user?.name ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Username: \(auth.user?.name ?? "unknown")"))

                    // Labeled "Real Name" here until now — the site's own
                    // account edit form actually calls this field "Display
                    // Name" (field_profile_realname), confirmed directly
                    // against a saved copy of the live form.
                    LabeledContent("Display Name") {
                        TextField("Optional", text: $realName)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                    }
                    .accessibilityElement(children: .combine)
                }

                Section("About You") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Bio")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if bioAssistAvailable {
                                Button {
                                    showBioAssist = true
                                } label: {
                                    Label("Help Me Write This", systemImage: "sparkles")
                                        .font(.caption)
                                }
                                .accessibilityHint(String(localized: "Answer a few questions and get a draft bio you can edit."))
                            }
                        }
                        TextEditor(text: $bio)
                            .frame(minHeight: 80)
                            .accessibilityLabel(String(localized: "Bio text editor"))
                    }

                    LabeledContent("Location") {
                        Button {
                            showCountryPicker = true
                        } label: {
                            Text(location.isEmpty ? "Not Set" : location)
                                .foregroundStyle(location.isEmpty ? .secondary : .primary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Location: \(location.isEmpty ? "not set" : location)"))
                    .accessibilityHint(String(localized: "Double-tap to choose your country. City-level location is not collected."))

                    LabeledContent("Interests") {
                        TextField("e.g. VoiceOver, Braille", text: $interests)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityElement(children: .combine)

                    LabeledContent("Apple Products Owned") {
                        Button {
                            showDevicesPicker = true
                        } label: {
                            Text(owns.isEmpty ? "Not Set" : owns)
                                .foregroundStyle(owns.isEmpty ? .secondary : .primary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Apple Products Owned: \(owns.isEmpty ? "not set" : owns)"))
                    .accessibilityHint(String(localized: "Double-tap to choose which Apple products you use."))
                }

                Section("Links") {
                    LabeledContent("Website") {
                        TextField("https://", text: $homepage)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .accessibilityElement(children: .combine)

                    LabeledContent("X / Twitter") {
                        TextField("@username", text: $twitter)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .accessibilityElement(children: .combine)

                    LabeledContent("Facebook") {
                        TextField("Optional", text: $facebook)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .accessibilityElement(children: .combine)

                    LabeledContent("Mastodon") {
                        TextField("@you@instance", text: $mastodon)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .accessibilityElement(children: .combine)
                }

                Section("Account Settings") {
                    LabeledContent("Time Zone") {
                        Button {
                            showTimeZonePicker = true
                        } label: {
                            Text(timezone.isEmpty ? "Not Set" : displayTimeZone(timezone))
                                .foregroundStyle(timezone.isEmpty ? .secondary : .primary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Time Zone: \(timezone.isEmpty ? "not set" : displayTimeZone(timezone))"))
                    .accessibilityHint(String(localized: "Double-tap to choose your time zone."))

                    Toggle(isOn: $allowsContact) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Allow Other Members to Contact Me")
                            Text("Lets other signed-in members send you a private message without seeing your email address. Site staff can still reach you either way.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityHint(String(localized: "Lets other signed-in members send you a private message without seeing your email address. Site staff can still reach you either way."))
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                            .accessibilityFocused($isErrorFocused)
                    }
                }
            }
            .themedList(preferences.colors)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveProfile() }
                        .disabled(isSaving)
                }
            }
            .disabled(isSaving || isLoading)
            .overlay {
                if isSaving {
                    ProgressView("Saving…")
                        .padding(20)
                        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 12))
                } else if isLoading {
                    ProgressView("Loading…")
                }
            }
        }
        .task {
            await loadCurrentProfile()
            await retryAccessibilityFocus(into: $isIntroFocused)
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(selection: $location)
        }
        .sheet(isPresented: $showBioAssist) {
            BioAssistSheet { draft in bio = draft }
        }
        .sheet(isPresented: $showDevicesPicker) {
            DevicesPickerSheet(owns: $owns)
        }
        .sheet(isPresented: $showTimeZonePicker) {
            TimeZonePickerSheet(selection: $timezone)
        }
    }

    /// "America/New_York" -> "New York" — the identifier's region prefix is
    /// implicit from grouping in the picker, so it's redundant to repeat it
    /// here.
    private func displayTimeZone(_ identifier: String) -> String {
        identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? identifier
    }

    /// Previously never called at all — every field always started blank,
    /// even for a user who already had a bio/location/etc. set, forcing a
    /// full retype for any small edit.
    private func loadCurrentProfile() async {
        guard let user = auth.user else { isLoading = false; return }
        do {
            let fields = try await APIClient.shared.account.fetchProfileFields(uuid: user.uuid, csrfToken: user.csrfToken)
            realName = fields.realName ?? ""
            bio = fields.bio ?? ""
            location = fields.location ?? ""
            interests = fields.interests ?? ""
            homepage = fields.homepage ?? ""
            twitter = fields.twitter ?? ""
            facebook = fields.facebook ?? ""
            mastodon = fields.mastodon ?? ""
            owns = fields.owns ?? ""
            timezone = fields.timezone ?? ""
            allowsContact = fields.allowsContact ?? true
        } catch {
            errorMessage = "Couldn't load your current profile. You can still make changes below."
            isErrorFocused = true
        }
        isLoading = false
    }

    private func saveProfile() {
        guard let user = auth.user else { return }
        isSaving = true
        errorMessage = nil
        let fields = ProfileUpdateFields(
            realName: realName.isEmpty ? nil : realName,
            bio: bio.isEmpty ? nil : bio,
            location: location.isEmpty ? nil : location,
            interests: interests.isEmpty ? nil : interests,
            homepage: homepage.isEmpty ? nil : homepage,
            twitter: twitter.isEmpty ? nil : twitter,
            facebook: facebook.isEmpty ? nil : facebook,
            mastodon: mastodon.isEmpty ? nil : mastodon,
            owns: owns.isEmpty ? nil : owns,
            timezone: timezone.isEmpty ? nil : timezone,
            allowsContact: allowsContact
        )
        Task {
            do {
                try await APIClient.shared.account.updateProfile(
                    uuid: user.uuid,
                    csrfToken: user.csrfToken,
                    fields: fields
                )
                toast.success(String(localized: "Profile saved"))
                dismiss()
            } catch let error as APIError {
                errorMessage = error.localizedDescription
                isErrorFocused = true
            } catch {
                errorMessage = "Couldn't save your profile. Try again."
                isErrorFocused = true
            }
            isSaving = false
        }
    }
}

/// Country-only location picker — replaces the old free-text field, which
/// let (and implicitly invited) people to type a specific city. A public
/// profile has no reason to know more than roughly where someone is.
private struct CountryPickerSheet: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var query = ""

    /// Built once from Foundation's own ISO region list rather than a
    /// hand-maintained array — always current, and localizes automatically
    /// (a French-language device sees French country names).
    private static let allCountries: [String] = {
        Locale.isoRegionCodes
            .compactMap { Locale.current.localizedString(forRegionCode: $0) }
            .sorted()
    }()

    private var filtered: [String] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return Self.allCountries }
        return Self.allCountries.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                countryRow(name: "Not Set", isSelected: selection.isEmpty) {
                    selection = ""
                }
                ForEach(filtered, id: \.self) { country in
                    countryRow(name: country, isSelected: selection == country) {
                        selection = country
                    }
                }
            }
            .themedList(preferences.colors)
            .searchable(text: $query, prompt: "Search Countries")
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func countryRow(name: String, isSelected: Bool, onSelect: @escaping () -> Void) -> some View {
        Button {
            onSelect()
            dismiss()
        } label: {
            HStack {
                Text(name)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Guided bio-writing help — a person types rough notes about themselves,
/// Apple Intelligence turns them into a short draft, and they can accept,
/// discard, or edit it further afterward. Never auto-applied to the real
/// bio field; the draft only replaces it if they explicitly tap "Use This."
private struct BioAssistSheet: View {
    let onUseDraft: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var notes = ""
    @State private var draft = ""
    @State private var isGenerating = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                if draft.isEmpty {
                    Section {
                        Text("Tell me a little about yourself — what you use AppleVis for, your devices or assistive technology, your interests. I'll turn it into a short draft bio you can edit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Section("Your Notes") {
                        TextEditor(text: $notes)
                            .frame(minHeight: 140)
                            .accessibilityLabel(String(localized: "Notes about yourself"))
                    }
                    if let error {
                        Section {
                            Text(error).foregroundStyle(.red)
                        }
                    }
                } else {
                    Section("Draft Bio") {
                        Text(draft)
                    }
                    Section {
                        Text("You can still edit this after using it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .themedList(preferences.colors)
            .navigationTitle("Bio Assist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if draft.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isGenerating ? "Writing…" : "Draft My Bio") { Task { await generate() } }
                            .disabled(isGenerating || notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Try Again") { draft = "" }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use This") {
                            onUseDraft(draft)
                            dismiss()
                        }
                    }
                }
            }
            .disabled(isGenerating)
            .overlay {
                if isGenerating {
                    ProgressView("Writing…")
                        .padding(20)
                        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func generate() async {
        isGenerating = true; error = nil
        if let result = await IntelligenceService.draftBio(from: notes) {
            draft = result
        } else {
            error = "Couldn't generate a draft. Please try again, or write your bio manually."
        }
        isGenerating = false
    }
}

/// "Apple Products Owned" — checkboxes in this app's UI, but Drupal only has
/// a single 255-character plain text field underneath
/// (`field_profile_owns`). Someone may already have typed something
/// free-form into that field directly on applevis.com before ever opening
/// this picker, so `parse`/`serialize` round-trip through an "Other" catch-
/// all rather than silently discarding anything that doesn't match a known
/// checkbox — opening and saving from this picker should never destroy data
/// someone entered on the website.
private struct DevicesPickerSheet: View {
    @Binding var owns: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore

    @State private var checked: Set<String> = []
    @State private var otherText = ""
    /// Leftover "Other" entries that look like a known device typed with
    /// different spacing/punctuation/case (e.g. "Air Pods Pro") rather than
    /// something genuinely custom — offered as an opt-in cleanup rather
    /// than silently rewritten, since this field can hold whatever someone
    /// already typed directly on applevis.com.
    @State private var suggestedCleanups: [(raw: String, match: String)] = []

    private static let knownDevices: [String] = [
        "iPhone",
        "iPad", "iPad mini", "iPad Air", "iPad Pro",
        "Mac", "MacBook", "MacBook Air", "MacBook Pro", "iMac", "Mac mini", "Mac Studio", "Mac Pro",
        "Apple Watch",
        "Apple TV",
        "HomePod", "HomePod mini",
        "AirPods", "AirPods Pro", "AirPods Max",
    ]

    /// Matches the site's own 255-character limit on this field.
    private static let maxLength = 255

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Select the Apple products you use. This is shown on your public profile.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach(Self.knownDevices, id: \.self) { device in
                        deviceRow(device)
                    }
                }
                Section("Other") {
                    TextField("Anything not listed above, separated by commas", text: $otherText)
                        .accessibilityHint(String(localized: "Optional."))
                }
                if !suggestedCleanups.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            // Context grouped separately from the two
                            // buttons below — combining buttons into the
                            // same element as their surrounding text merges
                            // their "button" traits together, making it
                            // ambiguous which one double-tapping the
                            // combined block would activate.
                            VStack(alignment: .leading, spacing: 8) {
                                Label("A Little Tidying?", systemImage: "sparkles")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.accentColor)
                                Text(cleanupMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)

                            HStack {
                                Button("Tidy This Up") { applySuggestedCleanups() }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                Button("No Thanks") { suggestedCleanups = [] }
                                    .buttonStyle(.plain)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .themedList(preferences.colors)
            .navigationTitle("Apple Products Owned")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        owns = Self.serialize(checked: checked, other: otherText)
                        dismiss()
                    }
                }
            }
            .onAppear {
                let parsed = Self.parse(owns)
                checked = parsed.checked
                otherText = parsed.other
                suggestedCleanups = Self.findSuggestedCleanups(in: parsed.leftoverRaw)
            }
        }
    }

    private var cleanupMessage: String {
        if suggestedCleanups.count == 1, let only = suggestedCleanups.first {
            return "Looks like \"\(only.raw)\" in Other is basically \(only.match), already on the list above. Want me to check that box and clear it out of Other so things stay nice and tidy?"
        }
        let matches = suggestedCleanups.map(\.match).joined(separator: ", ")
        return "A few things in Other look like they're already on the list above (\(matches)). Want me to check those boxes and clean up Other for you?"
    }

    private func applySuggestedCleanups() {
        let matchedRaw = Set(suggestedCleanups.map(\.raw))
        for cleanup in suggestedCleanups { checked.insert(cleanup.match) }
        let remaining = otherText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !matchedRaw.contains($0) }
        otherText = remaining.joined(separator: ", ")
        suggestedCleanups = []
    }

    private func deviceRow(_ device: String) -> some View {
        let isOn = checked.contains(device)
        return Button {
            if isOn { checked.remove(device) } else { checked.insert(device) }
        } label: {
            HStack {
                Text(device)
                Spacer()
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isOn ? "Checked" : "Unchecked")
    }

    private static func parse(_ raw: String) -> (checked: Set<String>, other: String, leftoverRaw: [String]) {
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var checked: Set<String> = []
        var leftover: [String] = []
        for part in parts {
            if let match = knownDevices.first(where: { $0.caseInsensitiveCompare(part) == .orderedSame }) {
                checked.insert(match)
            } else {
                leftover.append(part)
            }
        }
        return (checked, leftover.joined(separator: ", "), leftover)
    }

    private static func serialize(checked: Set<String>, other: String) -> String {
        let ordered = knownDevices.filter { checked.contains($0) }
        let otherParts = other.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let joined = (ordered + otherParts).joined(separator: ", ")
        return joined.count > maxLength ? String(joined.prefix(maxLength)) : joined
    }

    /// Lowercases and strips everything but letters/numbers, so "Air Pods
    /// Pro", "Air-Pods Pro", and "AirPods Pro" all normalize the same way —
    /// catches formatting differences the exact-match pass in `parse` above
    /// deliberately doesn't (that pass only merges genuinely identical
    /// text; this one is specifically for suggesting a cleanup, never
    /// applied without the person tapping "Tidy This Up").
    private static func normalize(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func findSuggestedCleanups(in leftover: [String]) -> [(raw: String, match: String)] {
        leftover.compactMap { token in
            let normalizedToken = normalize(token)
            guard let match = knownDevices.first(where: { normalize($0) == normalizedToken }) else { return nil }
            return (token, match)
        }
    }
}

/// Time zone picker for the site's core `timezone` field — grouped by
/// region (Africa, America, Asia, ...) the same way Drupal's own dropdown
/// groups its `<optgroup>`s, built from `TimeZone.knownTimeZoneIdentifiers`
/// rather than a hand-maintained list so it stays current automatically.
private struct TimeZonePickerSheet: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var query = ""
    @AccessibilityFocusState private var isSuggestionFocused: Bool

    /// The device's own time zone — offered as a one-tap suggestion instead
    /// of making someone hunt through ~400 entries for the answer they
    /// almost certainly already know from just looking at their phone.
    private let deviceTimeZoneID = TimeZone.current.identifier

    private static let grouped: [(region: String, zones: [String])] = {
        let all = TimeZone.knownTimeZoneIdentifiers.filter { $0.contains("/") }.sorted()
        var byRegion: [String: [String]] = [:]
        for id in all {
            let region = String(id.split(separator: "/").first ?? "Other")
            byRegion[region, default: []].append(id)
        }
        return byRegion.keys.sorted().map { ($0, byRegion[$0] ?? []) }
    }()

    private var filteredGroups: [(region: String, zones: [String])] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return Self.grouped }
        return Self.grouped.compactMap { group in
            let zones = group.zones.filter { $0.localizedCaseInsensitiveContains(query) }
            return zones.isEmpty ? nil : (group.region, zones)
        }
    }

    private var showDeviceSuggestion: Bool {
        query.isEmpty && selection != deviceTimeZoneID && Self.grouped.contains { $0.zones.contains(deviceTimeZoneID) }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    if showDeviceSuggestion {
                        Section {
                            deviceSuggestionCard
                        }
                    }
                    ForEach(filteredGroups, id: \.region) { group in
                        Section(group.region) {
                            ForEach(group.zones, id: \.self) { zone in
                                zoneRow(zone)
                                    .id(zone)
                            }
                        }
                    }
                }
                .themedList(preferences.colors)
                .searchable(text: $query, prompt: "Search Time Zones")
                .navigationTitle("Time Zone")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .task {
                    if showDeviceSuggestion {
                        await retryAccessibilityFocus(into: $isSuggestionFocused)
                    } else {
                        // No suggestion to offer (already selected, or the
                        // device's own zone isn't one of the picker's known
                        // identifiers) — scroll to wherever the current
                        // selection already sits, or to the device's own
                        // region, so a manual search starts from somewhere
                        // relevant instead of the very top of Africa.
                        let target = Self.grouped.contains(where: { $0.zones.contains(selection) }) ? selection : deviceTimeZoneID
                        try? await Task.sleep(for: .milliseconds(300))
                        withReduceMotionAwareAnimation { proxy.scrollTo(target, anchor: .top) }
                    }
                }
            }
        }
    }

    private var deviceSuggestionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Grouped into one informational element separate from the
            // button below — combining the button in too would merge its
            // own "button" trait into the same element VoiceOver announces
            // for the context text, making it ambiguous what double-
            // tapping the combined block would actually do.
            VStack(alignment: .leading, spacing: 8) {
                Label("Use Your Device's Time Zone?", systemImage: "location")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                Text("Your device is currently set to \(Self.friendlyLabel(for: deviceTimeZoneID)). Want to use that instead of searching?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityFocused($isSuggestionFocused)

            Button {
                selection = deviceTimeZoneID
                dismiss()
            } label: {
                Text("Use This Time Zone")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private func zoneRow(_ zone: String) -> some View {
        let isSelected = selection == zone
        return Button {
            selection = zone
            dismiss()
        } label: {
            HStack {
                Text(Self.friendlyLabel(for: zone))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static func friendlyLabel(for zone: String) -> String {
        let city = zone.split(separator: "/").dropFirst().joined(separator: " / ").replacingOccurrences(of: "_", with: " ")
        return "\(city) (\(offsetLabel(for: zone)))"
    }

    private static func offsetLabel(for zone: String) -> String {
        guard let tz = TimeZone(identifier: zone) else { return "GMT" }
        let totalMinutes = tz.secondsFromGMT() / 60
        let sign = totalMinutes >= 0 ? "+" : "-"
        let hours = abs(totalMinutes) / 60
        let minutes = abs(totalMinutes) % 60
        return minutes == 0 ? "GMT\(sign)\(hours)" : "GMT\(sign)\(hours):\(String(format: "%02d", minutes))"
    }
}
