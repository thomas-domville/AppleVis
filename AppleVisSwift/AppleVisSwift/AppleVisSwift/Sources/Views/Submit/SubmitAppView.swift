import SwiftUI
import UIKit

/// Uses the real JSON:API `AppEndpoints.submitApp` from Phase 1 — unlike
/// blog/bug/podcast, this one is on solid ground (same endpoint pattern as
/// the rest of the app, no HTML form scraping). Starts with an iTunes search
/// to prefill App Store details, condensed from RN's 6-screen wizard into a
/// single search-then-form flow.
struct SubmitAppView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()

    @State private var searchQuery = ""
    @State private var searchResults: [ItunesSearchHit] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedHit: ItunesSearchHit?

    @State private var payload = SubmitAppPayload()
    @State private var isSubmitting = false
    @State private var error: String?

    // "Before You Begin" gate — RN required these two confirmations before
    // a submitter could even reach the form (step 1 of its 5-step wizard).
    // Swift had no equivalent: nothing stopped a developer from submitting
    // their own app, which is against AppleVis's own guidelines.
    @State private var hasAgreedToBeforeYouBegin = false
    @State private var agreedPersonalUse = false
    @State private var agreedNotDeveloper = false
    @State private var showSignIn = false
    @State private var showDiscardConfirm = false

    /// Set when opened from the Share Extension with an App Store URL.
    private let prefillAppStoreURL: String?

    init(prefillAppStoreURL: String? = nil) {
        self.prefillAppStoreURL = prefillAppStoreURL
    }

    private let categories = [
        "Books", "Business", "Catalogs", "Developer Tools", "Education", "Entertainment",
        "Finance", "Food and Drink", "Games", "Graphics and Design", "Health and Fitness",
        "Lifestyle", "Medical", "Music", "Navigation", "News", "Photo and Video",
        "Productivity", "Reference", "Safari Extensions", "Shopping", "Social Networking",
        "Sports and Activities", "Stickers", "Travel", "Utilities", "Weather",
    ]
    // These three were all sharing one made-up "Excellent/Good/Fair/Poor"
    // scale that doesn't match anything on the actual site — submissions
    // sent meaningless values that don't correspond to what the website
    // (and this app's own AppRatingLevel gauge) expect to parse. Restored
    // RN's real per-field option sets exactly.
    private let voiceOverOptions = [
        "VoiceOver reads all page elements.",
        "VoiceOver reads most page elements.",
        "VoiceOver reads a few page elements.",
        "VoiceOver reads no page elements.",
        "Not applicable for this app.",
    ]
    private let buttonLabellingOptions = [
        "All buttons are clearly labeled.",
        "Most buttons are clearly labeled.",
        "Few buttons are clearly labeled.",
        "No buttons are clearly labeled.",
    ]
    private let usabilityOptions = [
        "The app is fully accessible with VoiceOver and is easy to navigate and use.",
        "The app is fully accessible with VoiceOver, but the interface could be easier to navigate and use.",
        "The app is fully accessible with VoiceOver, but the interface makes the app very difficult to use.",
        "The app is fully accessible without the use of VoiceOver",
        "There are some minor accessibility issues with this app, but they are easy to deal with.",
        "There are some accessibility issues with this app, but it can still be used if you are willing to tolerate these issues and learn how to work around them.",
        "Some parts of the app are accessible with VoiceOver, but not enough to make it usable.",
        "The app is totally inaccessible.",
    ]

    private var isValid: Bool {
        !payload.appName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !payload.appStoreUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
        !payload.category.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isSignedIn {
                    signInRequiredView
                } else if !hasAgreedToBeforeYouBegin {
                    beforeYouBeginView
                } else {
                    Form {
                        if selectedHit == nil {
                            searchSection
                        }
                        if selectedHit != nil || !payload.appName.isEmpty {
                            detailsSection
                        }
                        if let error {
                            Section { Text(error).foregroundStyle(.red) }
                        }
                    }
                    .themedList(preferences.colors)
                }
            }
            .navigationTitle("Submit an App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { requestCancel() }
                }
                if auth.isSignedIn && hasAgreedToBeforeYouBegin {
                    if selectedHit != nil && preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
                        ToolbarItem(placement: .secondaryAction) {
                            Button("Rewrite") {
                                Task {
                                    if let result = await intelligence.rewrite(subject: nil, body: payload.accessibilityComments, isTopic: false) {
                                        payload.accessibilityComments = result.body
                                    } else {
                                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                    }
                                }
                            }
                            .disabled(payload.accessibilityComments.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") { Task { await submit() } }
                            .disabled(!isValid || isSubmitting)
                    }
                }
            }
            .confirmationDialog(
                "Discard this submission?",
                isPresented: $showDiscardConfirm, titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { SoundPlayer.shared.play(.screenClose); dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your progress will be discarded.")
            }
        }
        .sheet(isPresented: $showSignIn) { SignInView() }
        .task { await applyPrefillIfNeeded() }
    }

    /// RN showed a full-screen "Sign In Required" blocker before any
    /// submission step was reachable at all. Swift had none — a signed-out
    /// user could fill out the entire form, then `submit()`'s
    /// `guard let user = auth.user else { return }` would silently do
    /// nothing when they tapped Submit, no explanation given.
    private var signInRequiredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Sign In Required")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("You need to be signed in to your AppleVis account to submit an app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign In") { showSignIn = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// RN's step 1 of 5 — two required confirmations before a submitter
    /// could reach the rest of the wizard. Nothing stopped a developer
    /// from self-submitting before this, which is against AppleVis's own
    /// submission guidelines.
    private var beforeYouBeginView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("The AppleVis App Directory is a community resource. Please read and confirm the following before adding an app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                beforeYouBeginRow(
                    checked: $agreedPersonalUse,
                    title: "I have used this app",
                    body: "I have personally used this app and can describe its accessibility — I am not submitting based on the App Store description alone."
                )
                beforeYouBeginRow(
                    checked: $agreedNotDeveloper,
                    title: "I am not the developer",
                    body: "I am not the developer, publisher, or otherwise affiliated with this app. Developers may not submit their own apps per AppleVis guidelines."
                )

                Link(destination: URL(string: "https://www.applevis.com/submitting-app-applevis-community-app-directory-guidelines")!) {
                    Label("Read submission guidelines", systemImage: "arrow.up.forward.square")
                }
                .font(.subheadline).fontWeight(.semibold)
                .accessibilityHint(String(localized: "Opens in Safari."))

                if !canContinueBeforeYouBegin {
                    Text("Confirm both checkboxes to continue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                Button("Continue") {
                    SoundPlayer.shared.play(.articleOpen)
                    hasAgreedToBeforeYouBegin = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canContinueBeforeYouBegin)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .background(preferences.colors.background)
    }

    private var canContinueBeforeYouBegin: Bool { agreedPersonalUse && agreedNotDeveloper }

    private func beforeYouBeginRow(checked: Binding<Bool>, title: String, body: String) -> some View {
        Button {
            SoundPlayer.shared.play(.pickerTick)
            checked.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(checked.wrappedValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 40, height: 40)
                    Image(systemName: checked.wrappedValue ? "checkmark" : "circle")
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(body).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(checked.wrappedValue ? Color.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(body)
        .accessibilityValue(checked.wrappedValue ? "Checked" : "Not checked")
        .accessibilityAddTraits(checked.wrappedValue ? [.isSelected] : [])
    }

    /// RN confirmed before discarding a filled-out form; Swift's Cancel
    /// dismissed immediately with no warning, silently losing a written
    /// accessibility review with one accidental tap.
    private func requestCancel() {
        let hasProgress = hasAgreedToBeforeYouBegin &&
            (selectedHit != nil || !payload.appName.isEmpty || !payload.accessibilityComments.isEmpty)
        if hasProgress {
            showDiscardConfirm = true
        } else {
            SoundPlayer.shared.play(.screenClose)
            dismiss()
        }
    }

    private func applyPrefillIfNeeded() async {
        guard let prefillAppStoreURL, selectedHit == nil else { return }
        selectedHit = ItunesSearchHit(appStoreId: "", appName: "", developerName: "", artworkUrl: "", appStoreUrl: prefillAppStoreURL)
        payload.appStoreUrl = prefillAppStoreURL
        if let meta = await ItunesAPI.fetchMetadata(appStoreUrl: prefillAppStoreURL) {
            payload.appName = meta.appName
            payload.appVersion = meta.version
            payload.price = meta.price
            payload.category = meta.category
            payload.osVersion = meta.minimumOsVersion
            payload.appStoreDescription = meta.appStoreDescription
        }
    }

    private var searchSection: some View {
        Section("Find the App on the App Store") {
            TextField("Search App Store", text: $searchQuery)
                .onSubmit { Task { await search() } }
                .onChange(of: searchQuery) { _, newValue in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        guard !Task.isCancelled else { return }
                        await search()
                    }
                }
            if isSearching {
                ProgressView()
            } else {
                ForEach(searchResults) { hit in
                    Button {
                        select(hit)
                    } label: {
                        HStack {
                            AsyncImage(url: URL(string: hit.artworkUrl)) { $0.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.2) }
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading) {
                                Text(hit.appName).foregroundStyle(.primary)
                                Text(hit.developerName).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Button("Enter Details Manually") {
                    selectedHit = ItunesSearchHit(appStoreId: "", appName: "", developerName: "", artworkUrl: "", appStoreUrl: "")
                }
                .font(.caption)
            }
        }
    }

    private var detailsSection: some View {
        Group {
            Section("App Details") {
                TextField("App Name", text: $payload.appName)
                TextField("App Store URL", text: $payload.appStoreUrl)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                TextField("Version", text: $payload.appVersion)
                TextField("Price (e.g. Free, $2.99)", text: $payload.price)
                Picker("Category", selection: $payload.category) {
                    Text("Choose…").tag("")
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                TextField("Minimum iOS Version", text: $payload.osVersion)
            }

            Section("Accessibility Assessment") {
                Picker("VoiceOver Performance", selection: $payload.voiceOverPerformance) {
                    Text("Choose…").tag("")
                    ForEach(voiceOverOptions, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "How well VoiceOver works overall in this app."))
                Picker("Button Labelling", selection: $payload.buttonLabelling) {
                    Text("Choose…").tag("")
                    ForEach(buttonLabellingOptions, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "Whether buttons and controls have clear, accurate VoiceOver labels."))
                Picker("Usability", selection: $payload.usabilityNotes) {
                    Text("Choose…").tag("")
                    ForEach(usabilityOptions, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "How easy the app is to use as a blind or low-vision user overall."))
            }

            if intelligence.showTranslatePrompt {
                Section {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: nil, body: payload.accessibilityComments, isTopic: false) {
                                payload.accessibilityComments = result.body
                            } else {
                                toast.error(String(localized: "Couldn't translate this. Try again."))
                            }
                        }
                    } onDismiss: {
                        intelligence.dismissTranslatePrompt()
                    }
                }
            }
            if let warning = guidelines.topWarning {
                Section {
                    GuidelinesReminderView(warning: warning) { guidelines.dismiss() }
                }
            }

            Section("Accessibility Comments") {
                TextEditor(text: $payload.accessibilityComments)
                    .frame(minHeight: 120)
                    .onChange(of: payload.accessibilityComments) { _, newValue in
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
            }

            Section("Short Summary") {
                TextField("One-line summary for the directory listing", text: $payload.shortSummary)
                    .accessibilityHint(String(localized: "Shown in the app directory list view, not the full review."))
            }

            Section("Additional Comments (optional)") {
                TextEditor(text: $payload.otherComments)
                    .frame(minHeight: 80)
            }
        }
    }

    private func search() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        let results = await ItunesAPI.search(searchQuery)
        guard !Task.isCancelled else { return }
        searchResults = results
        isSearching = false
        UIAccessibility.post(
            notification: .announcement,
            argument: results.isEmpty
                ? String(localized: "No results")
                : String(localized: "\(results.count) results found")
        )
    }

    private func select(_ hit: ItunesSearchHit) {
        selectedHit = hit
        payload.appName = hit.appName
        payload.appStoreUrl = hit.appStoreUrl
        Task {
            if let meta = await ItunesAPI.fetchMetadata(appStoreUrl: hit.appStoreUrl) {
                payload.appVersion = meta.version
                payload.price = meta.price
                payload.category = meta.category
                payload.osVersion = meta.minimumOsVersion
                payload.appStoreDescription = meta.appStoreDescription
            }
        }
    }

    private func submit() async {
        guard let user = auth.user else { return }
        isSubmitting = true; error = nil
        do {
            _ = try await APIClient.shared.apps.submitApp(payload: payload, csrfToken: user.csrfToken)
            toast.success(String(localized: "App submitted for review"))
            dismiss()
        } catch let e as APIError {
            error = e.localizedDescription
        } catch {
            self.error = "Couldn't submit app."
        }
        isSubmitting = false
    }
}
