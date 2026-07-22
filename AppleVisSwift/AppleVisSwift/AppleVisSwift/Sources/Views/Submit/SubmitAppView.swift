import SwiftUI

/// Uses the real JSON:API `AppEndpoints.submitApp` from Phase 1 — unlike
/// blog/bug/podcast, this one is on solid ground (same endpoint pattern as
/// the rest of the app, no HTML form scraping). Starts with an iTunes search
/// to prefill App Store details, condensed from RN's 6-screen wizard into a
/// single search-then-form flow.
struct SubmitAppView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var searchResults: [ItunesSearchHit] = []
    @State private var isSearching = false
    @State private var selectedHit: ItunesSearchHit?

    @State private var payload = SubmitAppPayload()
    @State private var isSubmitting = false
    @State private var error: String?

    private let categories = [
        "Books", "Business", "Catalogs", "Developer Tools", "Education", "Entertainment",
        "Finance", "Food and Drink", "Games", "Graphics and Design", "Health and Fitness",
        "Lifestyle", "Medical", "Music", "Navigation", "News", "Photo and Video",
        "Productivity", "Reference", "Safari Extensions", "Shopping", "Social Networking",
        "Sports and Activities", "Stickers", "Travel", "Utilities", "Weather",
    ]
    private let performanceOptions = ["Excellent", "Good", "Fair", "Poor"]

    private var isValid: Bool {
        !payload.appName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !payload.appStoreUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
        !payload.category.isEmpty
    }

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Submit an App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { Task { await submit() } }
                        .disabled(!isValid || isSubmitting)
                }
            }
        }
    }

    private var searchSection: some View {
        Section("Find the App on the App Store") {
            TextField("Search App Store", text: $searchQuery)
                .onSubmit { Task { await search() } }
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
                    ForEach(performanceOptions, id: \.self) { Text($0).tag($0) }
                }
                Picker("Button Labelling", selection: $payload.buttonLabelling) {
                    Text("Choose…").tag("")
                    ForEach(performanceOptions, id: \.self) { Text($0).tag($0) }
                }
                Picker("Usability", selection: $payload.usabilityNotes) {
                    Text("Choose…").tag("")
                    ForEach(performanceOptions, id: \.self) { Text($0).tag($0) }
                }
            }

            Section("Accessibility Comments") {
                TextEditor(text: $payload.accessibilityComments)
                    .frame(minHeight: 120)
            }

            Section("Short Summary") {
                TextField("One-line summary for the directory listing", text: $payload.shortSummary)
            }

            Section("Additional Comments (optional)") {
                TextEditor(text: $payload.otherComments)
                    .frame(minHeight: 80)
            }
        }
    }

    private func search() async {
        isSearching = true
        searchResults = await ItunesAPI.search(searchQuery)
        isSearching = false
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
            toast.success("App submitted for review")
            dismiss()
        } catch let e as APIError {
            error = e.localizedDescription
        } catch {
            self.error = "Couldn't submit app."
        }
        isSubmitting = false
    }
}
