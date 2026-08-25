import SwiftUI
import UIKit

/// Uses the real JSON:API `AppEndpoints.submitApp` from Phase 1 — unlike
/// blog/bug/podcast, this one is on solid ground (same endpoint pattern as
/// the rest of the app, no HTML form scraping). Starts with an iTunes search
/// to prefill App Store details, condensed from RN's 6-screen wizard into a
/// single search-then-form flow.
struct SubmitAppView: View {
    /// Legacy's `submit-wizard` had a dedicated confirm/review step before
    /// submit; native previously went straight from the details form to
    /// Submit with nothing to check over first (SUBMIT-010).
    private enum Step { case search, details, review }

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var guidelines = GuidelinesCheckState()
    @StateObject private var intelligence = ComposeIntelligenceState()
    @AccessibilityFocusState private var isStepFocused: Bool
    @AccessibilityFocusState private var isErrorFocused: Bool

    @State private var step: Step = .search
    /// Previously there was no platform state at all and every search
    /// silently searched iOS software only (SUBMIT-003). Now covers all
    /// four `AppPlatform` cases — watchOS was excluded early in this
    /// wizard's life under the assumption "watchOS apps ship bundled in an
    /// iOS entry, not submitted separately," which turned out to be wrong:
    /// `node--watch_directory` is a genuinely separate, submittable content
    /// type, confirmed live against /node/add/watch_directory. Reported
    /// directly.
    @State private var platform: AppPlatform = .ios
    @State private var searchQuery = ""
    @State private var searchResults: [ItunesSearchHit] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedHit: ItunesSearchHit?
    @State private var duplicateMatches: [AppListing] = []
    @State private var exactDuplicateMatches: [AppListing] = []
    @State private var isCheckingDuplicates = false
    @State private var acknowledgedDuplicate = false
    @State private var accessibilityCommentsMinimumAnnounced = false
    /// True once App Name/Version/Category/Minimum OS Version/Price have
    /// been filled from a real iTunes lookup — those fields switch to
    /// read-only display instead of editable text fields, since the API's
    /// values are already correct and an accidental edit could only make
    /// them wrong. False in "Enter Details Manually," the one path with no
    /// API data to trust. Reported directly.
    @State private var isMetadataFromAppStore = false
    /// The App Store's Free/Paid signal — only ever used to seed
    /// `payload.price`'s initial value (see `updatePriceCategory()`); the
    /// actual submitted category stays a freely editable Picker, since the
    /// API can't distinguish "Free With In-App Purchase" or "Requires
    /// Subscription" from plain Free/Paid.
    @State private var appStoreIndicatesFree = true

    @State private var payload = SubmitAppPayload()
    /// Apple TV entries are a completely separate Drupal content type
    /// (`node--tv_directory`, not `node--ios_app_directory`) with its own,
    /// much smaller field set verified against the live "Create Apple TV
    /// App Directory" form — no App Store URL, Version, Device(s) Tested
    /// On, or Developer's Website, a different 14-category taxonomy, and a
    /// 4-option Usability-only scale with no separate VoiceOver/Labelling
    /// questions. Kept as its own payload rather than overloading
    /// `SubmitAppPayload` with tvOS-only fields that don't apply to
    /// iOS/macOS. Reported directly.
    @State private var tvPayload = SubmitTvAppPayload()
    @State private var tvAccessibilityCommentsMinimumAnnounced = false
    /// Apple Watch entries are yet another separate Drupal content type
    /// (`node--watch_directory`) — closer in shape to iOS than Apple TV is
    /// (a real App Store link and version fields), but still its own
    /// payload: no Device(s) Tested On field, and a single Usability
    /// rating instead of split VoiceOver/Labelling questions. Verified
    /// against the live "Create Apple Watch App Directory" form. Reported
    /// directly.
    @State private var watchPayload = SubmitWatchAppPayload()
    @State private var watchAccessibilityCommentsMinimumAnnounced = false
    /// Mac entries are the fourth and last separate Drupal content type
    /// (`node--mac_app_directory`). Closer to iOS in shape (real Version
    /// and OS-version-tested fields, and the full 8-option iOS Usability
    /// vocabulary as a single field), but its App Store link is the only
    /// one of the four that's genuinely optional — a real share of Mac
    /// apps aren't in the Mac App Store at all — with its own
    /// MacUpdate.com fallback link field for that case. Verified against
    /// the live "Create Mac App Directory" form. Discussed and confirmed
    /// directly.
    @State private var macPayload = SubmitMacAppPayload()
    @State private var macAccessibilityCommentsMinimumAnnounced = false
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var submitted = false

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
    //
    // VoiceOver/Labelling's last option is (value, label) rather than a
    // plain string because the live form's own markup is inconsistent for
    // it: `<option value="Not applicable for this app">Not applicable for
    // this app.</option>` — the stored value has no trailing period, but
    // the displayed text does. Submitting the period-included string (what
    // this used to send) doesn't match Drupal's actual allowed value for
    // that option. Verified directly against the live form. Reported
    // directly. Labelling was also missing this option entirely — Drupal
    // has five choices here, this only offered four.
    private let voiceOverOptions: [(value: String, label: String)] =
        AppAccessibilityRatings.voiceOverPerformance + [(AppAccessibilityRatings.notApplicableValue, AppAccessibilityRatings.notApplicableLabel)]
    private let buttonLabellingOptions: [(value: String, label: String)] =
        AppAccessibilityRatings.buttonLabelling + [(AppAccessibilityRatings.notApplicableValue, AppAccessibilityRatings.notApplicableLabel)]
    // AppleVis's real four price categories, verified directly against the
    // live form's field_cost <select> — not a Free/Paid × has-IAP grid the
    // way an earlier version of this screen assumed; "Requires Subscription"
    // is its own category, and there's no "Paid With In-App Purchase" at
    // all. Reported directly.
    private let priceOptions = ["Free", "Free With In-App Purchase", "Paid", "Requires Subscription"]
    // Drupal's three "Device(s) App Was Tested On" checkboxes, in the exact
    // (label, submitted value) pairs verified against the live form —
    // notably iPad's actual value is the literal string "1", not "iPad".
    private let deviceOptions: [(label: String, value: String)] = [
        ("iPhone", "iPhone"), ("iPad", "1"), ("Mac", "mac"),
    ]
    private let usabilityOptions = AppAccessibilityRatings.usabilityIOS

    // Apple TV's real 14-category taxonomy (`field_category_tv`, vocabulary
    // `apple_tb_app_directory`) — verified directly against the live "Create
    // Apple TV App Directory" form. A different, shorter list than iOS's 27
    // categories above; not every iOS category has a TV equivalent.
    private let tvCategories = [
        "Books", "Business", "Catalogs", "Entertainment", "Finance", "Games",
        "Medical", "Music", "Productivity", "Reference", "Social Networking",
        "Travel", "Utilities", "Weather",
    ]
    // Apple TV's Usability field (`field_usability_tv`) is its own 4-option
    // scale — verified directly against the live form. There's no separate
    // VoiceOver Performance or Button Labelling question for TV entries at
    // all, unlike iOS's three-part Accessibility Assessment.
    private let tvUsabilityOptions = AppAccessibilityRatings.usabilitySimpleScale

    // Apple Watch's real 21-category taxonomy (`field_category_watch`,
    // vocabulary `apple_watch_app_directory`) — verified directly against
    // the live "Create Apple Watch App Directory" form. Its own category
    // set, distinct from both iOS's 27 and Apple TV's 14 (e.g. "Sports"
    // here, not "Sports and Activities" the way iOS names it).
    private let watchCategories = [
        "Books", "Business", "Education", "Entertainment", "Finance", "Food and Drink",
        "Games", "Health and Fitness", "Lifestyle", "Medical", "Music", "Navigation",
        "News", "Photo and Video", "Productivity", "Reference", "Social Networking",
        "Sports", "Travel", "Utilities", "Weather",
    ]
    // Apple Watch's Usability field (`field_usability_watch`) uses the same
    // 4-option scale as Apple TV's — verified directly against the live
    // form. No separate VoiceOver Performance/Button Labelling questions
    // for Watch entries either.
    private let watchUsabilityOptions = AppAccessibilityRatings.usabilitySimpleScale

    // Mac's real 21-category taxonomy (`taxonomy_vocabulary_16`) — verified
    // directly against the live "Create Mac App Directory" form. Its own
    // category names, distinct from iOS's: "Photography"/"Video"/"Sports"
    // here, not iOS's "Photo and Video"/"Sports and Activities" — not a
    // typo, confirmed against the live option text.
    private let macCategories = [
        "Business", "Developer Tools", "Education", "Entertainment", "Finance", "Games",
        "Graphics and Design", "Health and Fitness", "Lifestyle", "Medical", "Music", "News",
        "Photography", "Productivity", "Reference", "Social Networking", "Sports", "Travel",
        "Utilities", "Video", "Weather",
    ]
    // Mac's Usability field (`field_usability`) uses the same real
    // 8-option scale as iOS's — verified directly against the live form —
    // unlike Apple TV/Watch's simpler 4-option scale. Still a single
    // field though: no separate VoiceOver Performance/Button Labelling
    // questions the way iOS has.
    private let macUsabilityOptions = AppAccessibilityRatings.usabilityIOS

    // The accessibility assessment is this form's entire reason for existing —
    // previously only appName/appStoreUrl/category were required, so a
    // submission could reach the server with every accessibility field blank.
    private var accessibilityCommentsLength: Int { payload.accessibilityComments.trimmingCharacters(in: .whitespacesAndNewlines).count }
    private var tvAccessibilityCommentsLength: Int { tvPayload.accessibilityComments.trimmingCharacters(in: .whitespacesAndNewlines).count }
    private var watchAccessibilityCommentsLength: Int { watchPayload.accessibilityComments.trimmingCharacters(in: .whitespacesAndNewlines).count }
    private var macAccessibilityCommentsLength: Int { macPayload.accessibilityComments.trimmingCharacters(in: .whitespacesAndNewlines).count }

    private var isValid: Bool {
        switch platform {
        case .tvos:    return isTvValid
        case .watchos: return isWatchValid
        case .macos:   return isMacValid
        case .ios:     return isIosValid
        }
    }

    private var isIosValid: Bool {
        !payload.appName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !payload.appStoreUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
        !payload.category.isEmpty &&
        !payload.osVersion.trimmingCharacters(in: .whitespaces).isEmpty &&
        // "Description of App" is required server-side — verified against
        // the live form — but was never actually required (or even shown)
        // here, so a manual-entry submission with no App Store description
        // to prefill it could reach Submit with this silently blank.
        !payload.appStoreDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        // "Device(s) App Was Tested On" is a required field on the live
        // form that this wizard never asked for at all — every submission
        // was sending it empty. Reported directly.
        !payload.supportedDevices.isEmpty &&
        !payload.voiceOverPerformance.isEmpty &&
        !payload.buttonLabelling.isEmpty &&
        !payload.usabilityNotes.isEmpty &&
        accessibilityCommentsLength >= 20
    }

    // Apple TV's live form has no App Store URL, Version, Device(s) Tested
    // On, or Developer's Website field at all — those simply don't exist
    // for `node--tv_directory`, so this validation doesn't ask for them.
    private var isTvValid: Bool {
        !tvPayload.appName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !tvPayload.category.isEmpty &&
        !tvPayload.appDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !tvPayload.price.isEmpty &&
        !tvPayload.usability.isEmpty &&
        tvAccessibilityCommentsLength >= 20
    }

    // Apple Watch's live form has a real App Store Link and Version field
    // (unlike Apple TV), plus its own required watchOS Version field, but
    // no Device(s) Tested On and only a single Usability rating.
    private var isWatchValid: Bool {
        !watchPayload.appName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !watchPayload.appStoreUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
        !watchPayload.category.isEmpty &&
        !watchPayload.watchosVersion.trimmingCharacters(in: .whitespaces).isEmpty &&
        !watchPayload.appDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !watchPayload.price.isEmpty &&
        !watchPayload.usability.isEmpty &&
        watchAccessibilityCommentsLength >= 20
    }

    // Mac's live form requires Version, its own "Version Of macOS App Was
    // Tested On," Category, Description, Price, and Usability — but,
    // unlike every other platform, NOT an App Store link: a real share of
    // Mac apps aren't in the Mac App Store at all. Confirmed live.
    private var isMacValid: Bool {
        !macPayload.appName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !macPayload.category.isEmpty &&
        !macPayload.appVersion.trimmingCharacters(in: .whitespaces).isEmpty &&
        !macPayload.osxVersionTested.trimmingCharacters(in: .whitespaces).isEmpty &&
        !macPayload.appDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !macPayload.price.isEmpty &&
        !macPayload.usability.isEmpty &&
        macAccessibilityCommentsLength >= 20
    }

    /// Mirrors Contact's crossing-the-threshold announcement so VoiceOver
    /// users learn the moment they can continue, not just via the toolbar
    /// button's disabled state.
    private func handleAccessibilityCommentsChange(_ newValue: String) {
        let length = newValue.trimmingCharacters(in: .whitespacesAndNewlines).count
        if !accessibilityCommentsMinimumAnnounced && length >= 20 {
            accessibilityCommentsMinimumAnnounced = true
            UIAccessibility.post(notification: .announcement, argument: "Minimum length reached.")
        } else if accessibilityCommentsMinimumAnnounced && length < 20 {
            accessibilityCommentsMinimumAnnounced = false
        }
    }

    private func handleTvAccessibilityCommentsChange(_ newValue: String) {
        let length = newValue.trimmingCharacters(in: .whitespacesAndNewlines).count
        if !tvAccessibilityCommentsMinimumAnnounced && length >= 20 {
            tvAccessibilityCommentsMinimumAnnounced = true
            UIAccessibility.post(notification: .announcement, argument: "Minimum length reached.")
        } else if tvAccessibilityCommentsMinimumAnnounced && length < 20 {
            tvAccessibilityCommentsMinimumAnnounced = false
        }
    }

    private func handleWatchAccessibilityCommentsChange(_ newValue: String) {
        let length = newValue.trimmingCharacters(in: .whitespacesAndNewlines).count
        if !watchAccessibilityCommentsMinimumAnnounced && length >= 20 {
            watchAccessibilityCommentsMinimumAnnounced = true
            UIAccessibility.post(notification: .announcement, argument: "Minimum length reached.")
        } else if watchAccessibilityCommentsMinimumAnnounced && length < 20 {
            watchAccessibilityCommentsMinimumAnnounced = false
        }
    }

    private func handleMacAccessibilityCommentsChange(_ newValue: String) {
        let length = newValue.trimmingCharacters(in: .whitespacesAndNewlines).count
        if !macAccessibilityCommentsMinimumAnnounced && length >= 20 {
            macAccessibilityCommentsMinimumAnnounced = true
            UIAccessibility.post(notification: .announcement, argument: "Minimum length reached.")
        } else if macAccessibilityCommentsMinimumAnnounced && length < 20 {
            macAccessibilityCommentsMinimumAnnounced = false
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if submitted {
                    ThankYouView(
                        icon: "app.badge",
                        heading: "App submitted!",
                        message: "Thanks for documenting this app's accessibility. The AppleVis team will review your submission before it appears in the directory.",
                        doneLabel: "Done",
                        onDone: { dismiss() }
                    )
                } else if !auth.isSignedIn {
                    signInRequiredView
                } else if !hasAgreedToBeforeYouBegin {
                    beforeYouBeginView
                } else {
                    Form {
                        switch step {
                        case .search:
                            searchSection
                        case .details:
                            switch platform {
                            case .tvos:    tvDetailsSection
                            case .watchos: watchDetailsSection
                            case .macos:   macDetailsSection
                            case .ios:     detailsSection
                            }
                        case .review:
                            switch platform {
                            case .tvos:    tvReviewSection
                            case .watchos: watchReviewSection
                            case .macos:   macReviewSection
                            case .ios:     reviewSection
                            }
                        }
                        if let error {
                            Section {
                                Text(error)
                                    .foregroundStyle(.red)
                                    .accessibilityAddTraits(.isHeader)
                                    .accessibilityFocused($isErrorFocused)
                            }
                        }
                    }
                    .themedList(preferences.colors)
                }
            }
            .navigationTitle("Submit an App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !submitted {
                // Previously showed "Back" (not "Cancel") on every step past
                // search, leaving no way to actually leave the wizard from
                // Details or Review without stepping backward through every
                // screen first. Cancel now stays put regardless of step;
                // step-backward navigation moved to its own in-content
                // button below, matching the Welcome Tour's existing Back
                // convention. Reported directly.
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { requestCancel() }
                }
                if auth.isSignedIn && hasAgreedToBeforeYouBegin {
                    ToolbarItem(placement: .confirmationAction) {
                        if step == .review {
                            Button("Submit") { Task { await submit() } }
                                .disabled(!isValid || isSubmitting || !exactDuplicateMatches.isEmpty)
                        } else if step == .details {
                            Button("Review") { goNext() }
                                .disabled(!isValid)
                        }
                    }
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
            (selectedHit != nil || !payload.appName.isEmpty || !payload.accessibilityComments.isEmpty ||
             !tvPayload.appName.isEmpty || !tvPayload.accessibilityComments.isEmpty ||
             !watchPayload.appName.isEmpty || !watchPayload.accessibilityComments.isEmpty ||
             !macPayload.appName.isEmpty || !macPayload.accessibilityComments.isEmpty)
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
        step = .details
        if let meta = await ItunesAPI.fetchMetadata(appStoreUrl: prefillAppStoreURL, entity: platform.itunesEntity) {
            applyMetadata(meta)
        }
    }

    /// Shared by both search selection and the Share Extension prefill path
    /// — fills every field the App Store can answer for us, and flips
    /// `isMetadataFromAppStore` so the form switches those fields to
    /// read-only display instead of leaving them as editable text a
    /// submitter could accidentally overwrite with something wrong.
    private func applyMetadata(_ meta: ItunesMetadata) {
        if platform == .tvos {
            applyTvMetadata(meta)
            return
        }
        if platform == .watchos {
            applyWatchMetadata(meta)
            return
        }
        if platform == .macos {
            applyMacMetadata(meta)
            return
        }
        payload.appName = meta.appName
        payload.appVersion = meta.version
        payload.category = meta.category
        payload.osVersion = meta.minimumOsVersion
        payload.appStoreDescription = meta.appStoreDescription
        // Pre-selects the devices this app actually supports, per the App
        // Store listing — a helpful default, not a claim about which ones
        // the submitter personally tested, so this stays freely editable
        // afterward rather than read-only like the other App Store fields
        // above. Drupal only offers iPhone/iPad/Mac here; iPod touch and
        // Apple Watch (which deviceFamilies can also return) have no
        // equivalent checkbox on this form, so they're dropped.
        payload.supportedDevices = deviceOptions
            .filter { meta.deviceFamilies.contains($0.label) }
            .map(\.value)
        appStoreIndicatesFree = meta.isFree
        isMetadataFromAppStore = true
        updatePriceCategory()
    }

    /// Apple TV's own field set is much smaller — no version, devices, or
    /// developer site to pull in, and its 14-category taxonomy doesn't line
    /// up 1:1 with iTunes' category names, so the match is best-effort
    /// (case-insensitive) and left blank rather than guessed wrong when
    /// nothing matches.
    private func applyTvMetadata(_ meta: ItunesMetadata) {
        tvPayload.appName = meta.appName
        tvPayload.appDescription = meta.appStoreDescription
        tvPayload.category = tvCategories.first { $0.caseInsensitiveCompare(meta.category) == .orderedSame } ?? ""
        appStoreIndicatesFree = meta.isFree
        isMetadataFromAppStore = true
        updatePriceCategory()
    }

    /// Unlike Apple TV, Apple Watch entries have a real App Store link and
    /// version, so this closely mirrors `applyMetadata`'s iOS branch —
    /// except there's no watchOS-equivalent field on a `software`-entity
    /// iTunes lookup (that's the *iOS* app's own minimum OS version, not
    /// watchOS's), so `watchosVersion` stays blank for the submitter to
    /// fill in themselves, and there's no Device(s) field to pre-select at
    /// all (the live form has none).
    private func applyWatchMetadata(_ meta: ItunesMetadata) {
        watchPayload.appName = meta.appName
        watchPayload.appVersion = meta.version
        watchPayload.category = watchCategories.first { $0.caseInsensitiveCompare(meta.category) == .orderedSame } ?? ""
        watchPayload.appDescription = meta.appStoreDescription
        appStoreIndicatesFree = meta.isFree
        isMetadataFromAppStore = true
        updatePriceCategory()
    }

    /// Mac apps can be found via either of two different iTunes entities
    /// (see `ItunesAPI.fetchMacMetadata`), so unlike the other three, this
    /// doesn't know in advance which one supplied `meta` — it doesn't
    /// matter here, since a `macSoftware` result and a Catalyst
    /// `software` result carry the same fields this form needs. No
    /// Device(s) field to pre-select either way (the live form has none).
    private func applyMacMetadata(_ meta: ItunesMetadata) {
        macPayload.appName = meta.appName
        macPayload.appVersion = meta.version
        macPayload.category = macCategories.first { $0.caseInsensitiveCompare(meta.category) == .orderedSame } ?? ""
        macPayload.appDescription = meta.appStoreDescription
        macPayload.appStoreUrl = meta.appStoreUrl
        appStoreIndicatesFree = meta.isFree
        isMetadataFromAppStore = true
        updatePriceCategory()
    }

    /// Seeds `payload.price`/`tvPayload.price`/`watchPayload.price`/
    /// `macPayload.price` with the App Store's Free-vs-Paid signal — only
    /// ever a starting point. The Picker bound to it stays fully editable
    /// afterward, since the other real categories ("Free With In-App
    /// Purchase," "Requires Subscription") aren't something the iTunes API
    /// can tell us at all.
    private func updatePriceCategory() {
        let seeded = appStoreIndicatesFree ? "Free" : "Paid"
        switch platform {
        case .tvos:    tvPayload.price = seeded
        case .watchos: watchPayload.price = seeded
        case .macos:   macPayload.price = seeded
        case .ios:     payload.price = seeded
        }
    }

    private var searchSection: some View {
        Group {
            Section { WizardStepIndicator(step: 1, total: 3, title: "Find the App", isFocused: $isStepFocused) }
            Section("Platform") {
                Picker("Platform", selection: $platform) {
                    ForEach([AppPlatform.ios, .macos, .tvos, .watchos]) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: platform) { _, _ in
                    searchResults = []
                    Task { await search() }
                }
                .accessibilityHint(String(localized: "Which App Store this app is listed on. Changes what search looks up."))
            }
            searchResultsSection
        }
    }

    private var searchResultsSection: some View {
        Section {
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
                    // Explicit reset, not just the @State default — reachable
                    // after backing out of a real selection, which already
                    // set this true.
                    isMetadataFromAppStore = false
                    appStoreIndicatesFree = true
                    switch platform {
                    case .tvos:
                        tvPayload.appDescription = ""
                    case .watchos:
                        watchPayload.appDescription = ""
                        watchPayload.developerWebsite = ""
                    case .macos:
                        macPayload.appStoreUrl = ""
                        macPayload.appDescription = ""
                        macPayload.developerWebsite = ""
                    case .ios:
                        payload.supportedDevices = []
                        payload.appStoreDescription = ""
                        payload.developerWebsite = ""
                    }
                    // Gives price a sensible starting value — it's still a
                    // fully editable Picker either way.
                    updatePriceCategory()
                    SoundPlayer.shared.play(.pickerTick)
                    step = .details
                    focusStepAfterTransition()
                }
                .font(.caption)
            }
        } header: {
            Text("Find the App on the App Store")
        } footer: {
            // A real, sizable share of Mac apps aren't in the Mac App
            // Store at all (confirmed live against AppleVis's own
            // directory — VMware Fusion, Xcode, 1Password, and others
            // have no App Store link) — called out here rather than
            // leaving "Enter Details Manually" looking like a fallback
            // for a failed search. Discussed and confirmed directly.
            if platform == .macos {
                Text("Not every Mac app is in the Mac App Store. If this app isn't listed here, use Enter Details Manually below.")
            }
        }
    }

    private var detailsSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 2, total: 3, title: "App Details", isFocused: $isStepFocused)
                backButton
            }
            Section {
                if isMetadataFromAppStore {
                    // Filled from a real App Store lookup — shown read-only
                    // rather than as editable text fields, since the API's
                    // values are already correct and an accidental edit
                    // could only make them wrong. Reported directly.
                    WizardReviewRow(label: "App Name", value: payload.appName)
                    WizardReviewRow(label: "App Store URL", value: payload.appStoreUrl)
                    WizardReviewRow(label: "Version", value: payload.appVersion)
                    WizardReviewRow(label: "Category", value: payload.category)
                    WizardReviewRow(label: "Minimum OS Version", value: payload.osVersion)
                } else {
                    // "Enter Details Manually" — no App Store data to trust,
                    // so these stay real input fields.
                    TextField("App Name", text: $payload.appName)
                        .accessibilityHint(String(localized: "Required."))
                    TextField("App Store URL", text: $payload.appStoreUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .accessibilityHint(String(localized: "Required."))
                    TextField("Version", text: $payload.appVersion)
                    Picker("Category", selection: $payload.category) {
                        Text("Choose…").tag("")
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    .accessibilityHint(String(localized: "Required."))
                    TextField("Minimum iOS Version", text: $payload.osVersion)
                        .accessibilityHint(String(localized: "Required."))
                }
            } header: {
                Text("App Details")
            } footer: {
                if isMetadataFromAppStore {
                    Text("Pulled automatically from the App Store listing.")
                }
            }

            // AppleVis's real four price categories (verified live) — not a
            // Free/Paid × has-in-app-purchases grid, so this stays one flat
            // picker rather than a base tier plus a toggle. Pre-seeded from
            // the App Store's Free/Paid signal (updatePriceCategory(), fired
            // from applyMetadata/"Enter Details Manually"), but always
            // editable — the API can tell us Free vs. Paid, but not "Free
            // With In-App Purchase" or "Requires Subscription," so an
            // accurate category still needs someone who's actually used the
            // app. Reported directly.
            Section {
                Picker("Price", selection: $payload.price) {
                    Text("Choose…").tag("")
                    ForEach(priceOptions, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "Required."))
            } header: {
                Text("Price")
            } footer: {
                if isMetadataFromAppStore {
                    Text("Free or Paid was detected from the App Store listing — change it if this app is actually free with in-app purchases or requires a subscription.")
                }
            }

            // Required on the live form (verified directly) but never
            // asked for at all before this — every submission through this
            // wizard was sending it empty. Treated the same as the other
            // App Store-sourced fields above: read-only, taken directly
            // from the listing's supported devices, once a real lookup
            // succeeded. Requested directly — for an iOS app submission
            // specifically, "which devices does the App Store say this
            // runs on" is a reasonable stand-in for "which did you test,"
            // and not worth a manual confirmation step. Manual entry mode
            // has no API data to draw from, so it keeps real toggles.
            Section {
                if isMetadataFromAppStore {
                    WizardReviewRow(
                        label: "Device(s) Tested On",
                        value: deviceOptions.filter { payload.supportedDevices.contains($0.value) }.map(\.label).joined(separator: ", ")
                    )
                } else {
                    ForEach(deviceOptions, id: \.value) { option in
                        Toggle(option.label, isOn: Binding(
                            get: { payload.supportedDevices.contains(option.value) },
                            set: { isOn in
                                if isOn {
                                    if !payload.supportedDevices.contains(option.value) {
                                        payload.supportedDevices.append(option.value)
                                    }
                                } else {
                                    payload.supportedDevices.removeAll { $0 == option.value }
                                }
                            }
                        ))
                    }
                }
            } header: {
                Text("Device(s) Tested On")
            } footer: {
                if isMetadataFromAppStore {
                    Text("Taken from the devices this app supports on the App Store.")
                } else {
                    Text("Required. Select every device you tested this app on.")
                }
            }

            Section {
                if isMetadataFromAppStore {
                    // Server-required, but never shown anywhere in this
                    // wizard before — a submitter had no way to see or
                    // verify what description was about to be sent under
                    // their submission. Reported directly.
                    WizardReviewRow(label: "Description of App", value: payload.appStoreDescription)
                } else {
                    TextEditor(text: $payload.appStoreDescription)
                        .frame(minHeight: 100)
                        .accessibilityLabel(String(localized: "Description of App"))
                        .accessibilityHint(String(localized: "Required."))
                }
            } header: {
                Text("Description of App")
            } footer: {
                if isMetadataFromAppStore {
                    Text("Pulled automatically from the App Store listing.")
                }
            }

            Section {
                TextField("Developer's Website (optional)", text: $payload.developerWebsite)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .accessibilityHint(String(localized: "Optional. The developer's own website, if they have one."))
            } header: {
                Text("Developer's Website")
            }

            Section("Accessibility Assessment") {
                Picker("VoiceOver Performance", selection: $payload.voiceOverPerformance) {
                    Text("Choose…").tag("")
                    ForEach(voiceOverOptions, id: \.value) { Text($0.label).tag($0.value) }
                }
                .accessibilityHint(String(localized: "Required. How well VoiceOver works overall in this app."))
                Picker("Button Labelling", selection: $payload.buttonLabelling) {
                    Text("Choose…").tag("")
                    ForEach(buttonLabellingOptions, id: \.value) { Text($0.label).tag($0.value) }
                }
                .accessibilityHint(String(localized: "Required. Whether buttons and controls have clear, accurate VoiceOver labels."))
                Picker("Usability", selection: $payload.usabilityNotes) {
                    Text("Choose…").tag("")
                    ForEach(usabilityOptions, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "Required. How easy the app is to use as a blind or low-vision user overall."))
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
                    GuidelinesReminderView(
                        warning: warning,
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: nil, body: payload.accessibilityComments, isTopic: false) {
                                    payload.accessibilityComments = result.body
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                }
            }

            Section {
                HStack {
                    Text("Accessibility Comments").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(accessibilityCommentsLength < 20 ? "\(accessibilityCommentsLength) / 20 min" : "\(accessibilityCommentsLength) chars")
                        .font(.caption)
                        .fontWeight(accessibilityCommentsLength < 20 ? .bold : .regular)
                        .foregroundStyle(accessibilityCommentsLength < 20 ? .red : .secondary)
                        .accessibilityLabel(accessibilityCommentsLength < 20 ? String(localized: "\(accessibilityCommentsLength) of 20 minimum characters") : String(localized: "\(accessibilityCommentsLength) characters"))
                }
                TextEditor(text: $payload.accessibilityComments)
                    .frame(minHeight: 120)
                    .accessibilityLabel(String(localized: "Accessibility Comments"))
                    .accessibilityHint(String(localized: "Required. Minimum 20 characters."))
                    .onChange(of: payload.accessibilityComments) { _, newValue in
                        handleAccessibilityCommentsChange(newValue)
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                rewriteButton(text: $payload.accessibilityComments)
            }

            Section("Short Summary") {
                TextField("One-line summary for the directory listing", text: $payload.shortSummary)
                    .accessibilityHint(String(localized: "Shown in the app directory list view, not the full review."))
                    // Non-English detection only, not the full guideline/tone
                    // checker — this is a single line with its own length
                    // gate that a short summary often won't clear anyway,
                    // and a translate offer is the part that actually
                    // matters before it hits the hard block at Submit.
                    // Reported directly.
                    .onChange(of: payload.shortSummary) { _, newValue in
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
            }

            // Was entirely unchecked before — no live guideline/language
            // feedback, and excluded from the Submit-time policy check too.
            // Reported directly.
            Section("Additional Comments (optional)") {
                TextEditor(text: $payload.otherComments)
                    .frame(minHeight: 80)
                    .onChange(of: payload.otherComments) { _, newValue in
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                rewriteButton(text: $payload.otherComments)
            }
        }
    }

    /// Apple TV's own details form — verified directly against the live
    /// "Create Apple TV App Directory" form. No App Store URL, Version,
    /// Device(s) Tested On, or Developer's Website field exists for
    /// `node--tv_directory` at all, and Usability is a single 4-option
    /// scale with no separate VoiceOver Performance/Button Labelling
    /// questions the way iOS has. Reported directly.
    private var tvDetailsSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 2, total: 3, title: "App Details", isFocused: $isStepFocused)
                backButton
            }
            Section {
                if isMetadataFromAppStore {
                    WizardReviewRow(label: "App Name", value: tvPayload.appName)
                } else {
                    TextField("App Name", text: $tvPayload.appName)
                        .accessibilityHint(String(localized: "Required."))
                }
                Picker("Category", selection: $tvPayload.category) {
                    Text("Choose…").tag("")
                    ForEach(tvCategories, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "Required."))
            } header: {
                Text("App Details")
            }

            Section {
                Picker("Price", selection: $tvPayload.price) {
                    Text("Choose…").tag("")
                    ForEach(priceOptions, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "Required."))
            } header: {
                Text("Price")
            } footer: {
                if isMetadataFromAppStore {
                    Text("Free or Paid was detected from the App Store listing — change it if this app is actually free with in-app purchases or requires a subscription.")
                }
            }

            Section {
                if isMetadataFromAppStore {
                    WizardReviewRow(label: "Description of App", value: tvPayload.appDescription)
                } else {
                    TextEditor(text: $tvPayload.appDescription)
                        .frame(minHeight: 100)
                        .accessibilityLabel(String(localized: "Description of App"))
                        .accessibilityHint(String(localized: "Required."))
                }
            } header: {
                Text("Description of App")
            } footer: {
                if isMetadataFromAppStore {
                    Text("Pulled automatically from the App Store listing.")
                }
            }

            Section("Usability") {
                Picker("Usability", selection: $tvPayload.usability) {
                    Text("Choose…").tag("")
                    ForEach(tvUsabilityOptions, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "Required. How accessible this app is on Apple TV overall."))
            }

            if intelligence.showTranslatePrompt {
                Section {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: nil, body: tvPayload.accessibilityComments, isTopic: false) {
                                tvPayload.accessibilityComments = result.body
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
                    GuidelinesReminderView(
                        warning: warning,
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: nil, body: tvPayload.accessibilityComments, isTopic: false) {
                                    tvPayload.accessibilityComments = result.body
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                }
            }

            Section {
                HStack {
                    Text("Accessibility Comments").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(tvAccessibilityCommentsLength < 20 ? "\(tvAccessibilityCommentsLength) / 20 min" : "\(tvAccessibilityCommentsLength) chars")
                        .font(.caption)
                        .fontWeight(tvAccessibilityCommentsLength < 20 ? .bold : .regular)
                        .foregroundStyle(tvAccessibilityCommentsLength < 20 ? .red : .secondary)
                        .accessibilityLabel(tvAccessibilityCommentsLength < 20 ? String(localized: "\(tvAccessibilityCommentsLength) of 20 minimum characters") : String(localized: "\(tvAccessibilityCommentsLength) characters"))
                }
                TextEditor(text: $tvPayload.accessibilityComments)
                    .frame(minHeight: 120)
                    .accessibilityLabel(String(localized: "Accessibility Comments"))
                    .accessibilityHint(String(localized: "Required. Minimum 20 characters."))
                    .onChange(of: tvPayload.accessibilityComments) { _, newValue in
                        handleTvAccessibilityCommentsChange(newValue)
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                rewriteButton(text: $tvPayload.accessibilityComments)
            }

            Section("Other Comments (optional)") {
                TextEditor(text: $tvPayload.otherComments)
                    .frame(minHeight: 80)
                    .onChange(of: tvPayload.otherComments) { _, newValue in
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                rewriteButton(text: $tvPayload.otherComments)
            }
        }
    }

    /// Apple Watch's own details form — verified directly against the live
    /// "Create Apple Watch App Directory" form. Closer to iOS's shape than
    /// Apple TV's: a real App Store URL and Version, plus its own required
    /// watchOS Version — but, like TV, a single Usability scale and no
    /// Device(s) Tested On field. Reported directly.
    private var watchDetailsSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 2, total: 3, title: "App Details", isFocused: $isStepFocused)
                backButton
            }
            Section {
                if isMetadataFromAppStore {
                    WizardReviewRow(label: "App Name", value: watchPayload.appName)
                    WizardReviewRow(label: "App Store URL", value: watchPayload.appStoreUrl)
                    WizardReviewRow(label: "Version", value: watchPayload.appVersion)
                } else {
                    TextField("App Name", text: $watchPayload.appName)
                        .accessibilityHint(String(localized: "Required."))
                    TextField("App Store URL", text: $watchPayload.appStoreUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .accessibilityHint(String(localized: "Required."))
                    TextField("Version", text: $watchPayload.appVersion)
                }
                Picker("Category", selection: $watchPayload.category) {
                    Text("Choose…").tag("")
                    ForEach(watchCategories, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "Required."))
                // Not something a `software`-entity iTunes lookup can
                // answer (that field describes the iOS app's own minimum
                // OS version, not watchOS's) — always a real input,
                // regardless of `isMetadataFromAppStore`.
                TextField("watchOS Version", text: $watchPayload.watchosVersion)
                    .accessibilityHint(String(localized: "Required. The minimum watchOS version this app supports."))
            } header: {
                Text("App Details")
            } footer: {
                if isMetadataFromAppStore {
                    Text("App Name, App Store URL, and Version pulled automatically from the App Store listing.")
                }
            }

            Section {
                Picker("Price", selection: $watchPayload.price) {
                    Text("Choose…").tag("")
                    ForEach(priceOptions, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "Required."))
            } header: {
                Text("Price")
            } footer: {
                if isMetadataFromAppStore {
                    Text("Free or Paid was detected from the App Store listing — change it if this app is actually free with in-app purchases or requires a subscription.")
                }
            }

            Section {
                if isMetadataFromAppStore {
                    WizardReviewRow(label: "Description of App", value: watchPayload.appDescription)
                } else {
                    TextEditor(text: $watchPayload.appDescription)
                        .frame(minHeight: 100)
                        .accessibilityLabel(String(localized: "Description of App"))
                        .accessibilityHint(String(localized: "Required."))
                }
            } header: {
                Text("Description of App")
            } footer: {
                if isMetadataFromAppStore {
                    Text("Pulled automatically from the App Store listing.")
                }
            }

            Section {
                TextField("Developer's Website (optional)", text: $watchPayload.developerWebsite)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .accessibilityHint(String(localized: "Optional. The developer's own website, if they have one."))
            } header: {
                Text("Developer's Website")
            }

            Section("Usability") {
                Picker("Usability", selection: $watchPayload.usability) {
                    Text("Choose…").tag("")
                    ForEach(watchUsabilityOptions, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "Required. How accessible this app is on Apple Watch overall."))
            }

            if intelligence.showTranslatePrompt {
                Section {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: nil, body: watchPayload.accessibilityComments, isTopic: false) {
                                watchPayload.accessibilityComments = result.body
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
                    GuidelinesReminderView(
                        warning: warning,
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: nil, body: watchPayload.accessibilityComments, isTopic: false) {
                                    watchPayload.accessibilityComments = result.body
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                }
            }

            Section {
                HStack {
                    Text("Accessibility Comments").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(watchAccessibilityCommentsLength < 20 ? "\(watchAccessibilityCommentsLength) / 20 min" : "\(watchAccessibilityCommentsLength) chars")
                        .font(.caption)
                        .fontWeight(watchAccessibilityCommentsLength < 20 ? .bold : .regular)
                        .foregroundStyle(watchAccessibilityCommentsLength < 20 ? .red : .secondary)
                        .accessibilityLabel(watchAccessibilityCommentsLength < 20 ? String(localized: "\(watchAccessibilityCommentsLength) of 20 minimum characters") : String(localized: "\(watchAccessibilityCommentsLength) characters"))
                }
                TextEditor(text: $watchPayload.accessibilityComments)
                    .frame(minHeight: 120)
                    .accessibilityLabel(String(localized: "Accessibility Comments"))
                    .accessibilityHint(String(localized: "Required. Minimum 20 characters."))
                    .onChange(of: watchPayload.accessibilityComments) { _, newValue in
                        handleWatchAccessibilityCommentsChange(newValue)
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                rewriteButton(text: $watchPayload.accessibilityComments)
            }

            Section("Other Comments (optional)") {
                TextEditor(text: $watchPayload.otherComments)
                    .frame(minHeight: 80)
                    .onChange(of: watchPayload.otherComments) { _, newValue in
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                rewriteButton(text: $watchPayload.otherComments)
            }
        }
    }

    /// Mac's own details form — verified directly against the live
    /// "Create Mac App Directory" form. Closest to iOS's shape of the
    /// three non-iOS platforms (a real App Store URL, Version, and its own
    /// "Version Of macOS App Was Tested On"), but the App Store URL is the
    /// one field genuinely optional here — a real share of Mac apps aren't
    /// in the Mac App Store at all — with its own MacUpdate.com fallback
    /// link for that case, and a single Usability field (the full
    /// 8-option iOS scale) rather than iOS's split VoiceOver/Labelling
    /// questions. Reported directly, discussed explicitly.
    private var macDetailsSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 2, total: 3, title: "App Details", isFocused: $isStepFocused)
                backButton
            }
            Section {
                if isMetadataFromAppStore {
                    WizardReviewRow(label: "App Name", value: macPayload.appName)
                    WizardReviewRow(label: "App Store URL", value: macPayload.appStoreUrl)
                    WizardReviewRow(label: "Version", value: macPayload.appVersion)
                } else {
                    TextField("App Name", text: $macPayload.appName)
                        .accessibilityHint(String(localized: "Required."))
                    TextField("App Store URL (optional)", text: $macPayload.appStoreUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .accessibilityHint(String(localized: "Optional. Leave blank if this app isn't in the Mac App Store."))
                    TextField("Version", text: $macPayload.appVersion)
                        .accessibilityHint(String(localized: "Required."))
                }
                Picker("Category", selection: $macPayload.category) {
                    Text("Choose…").tag("")
                    ForEach(macCategories, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "Required."))
                TextField("Version Of macOS App Was Tested On", text: $macPayload.osxVersionTested)
                    .accessibilityHint(String(localized: "Required."))
            } header: {
                Text("App Details")
            } footer: {
                if isMetadataFromAppStore {
                    Text("App Name, App Store URL, and Version pulled automatically from the App Store listing.")
                }
            }

            // Only shown when there's no App Store URL — MacUpdate is
            // AppleVis's own fallback reference for a Mac app not in the
            // Mac App Store, and doesn't apply once a real App Store
            // listing is already on file.
            if macPayload.appStoreUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section {
                    TextField("MacUpdate Link (optional)", text: $macPayload.macUpdateUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .accessibilityHint(String(localized: "Optional. A link to this app's MacUpdate.com listing, if it has one."))
                } header: {
                    Text("MacUpdate Link")
                }
            }

            Section {
                Picker("Price", selection: $macPayload.price) {
                    Text("Choose…").tag("")
                    ForEach(priceOptions, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "Required."))
            } header: {
                Text("Price")
            } footer: {
                if isMetadataFromAppStore {
                    Text("Free or Paid was detected from the App Store listing — change it if this app is actually free with in-app purchases or requires a subscription.")
                }
            }

            Section {
                if isMetadataFromAppStore {
                    WizardReviewRow(label: "Description of App", value: macPayload.appDescription)
                } else {
                    TextEditor(text: $macPayload.appDescription)
                        .frame(minHeight: 100)
                        .accessibilityLabel(String(localized: "Description of App"))
                        .accessibilityHint(String(localized: "Required."))
                }
            } header: {
                Text("Description of App")
            } footer: {
                if isMetadataFromAppStore {
                    Text("Pulled automatically from the App Store listing.")
                }
            }

            Section {
                TextField("Developer's Website (optional)", text: $macPayload.developerWebsite)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .accessibilityHint(String(localized: "Optional. The developer's own website, if they have one."))
            } header: {
                Text("Developer's Website")
            }

            Section("Usability") {
                Picker("Usability", selection: $macPayload.usability) {
                    Text("Choose…").tag("")
                    ForEach(macUsabilityOptions, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityHint(String(localized: "Required. How easy the app is to use as a blind or low-vision user overall."))
            }

            if intelligence.showTranslatePrompt {
                Section {
                    TranslatePromptView(isProcessing: intelligence.isProcessing) {
                        Task {
                            if let result = await intelligence.translate(subject: nil, body: macPayload.accessibilityComments, isTopic: false) {
                                macPayload.accessibilityComments = result.body
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
                    GuidelinesReminderView(
                        warning: warning,
                        onDismiss: { guidelines.dismiss() },
                        onRewriteRespectfully: {
                            Task {
                                if let result = await intelligence.rewriteRespectfully(subject: nil, body: macPayload.accessibilityComments, isTopic: false) {
                                    macPayload.accessibilityComments = result.body
                                } else {
                                    toast.error(String(localized: "Couldn't rewrite this. Try again."))
                                }
                            }
                        }
                    )
                }
            }

            Section {
                HStack {
                    Text("Accessibility Comments").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(macAccessibilityCommentsLength < 20 ? "\(macAccessibilityCommentsLength) / 20 min" : "\(macAccessibilityCommentsLength) chars")
                        .font(.caption)
                        .fontWeight(macAccessibilityCommentsLength < 20 ? .bold : .regular)
                        .foregroundStyle(macAccessibilityCommentsLength < 20 ? .red : .secondary)
                        .accessibilityLabel(macAccessibilityCommentsLength < 20 ? String(localized: "\(macAccessibilityCommentsLength) of 20 minimum characters") : String(localized: "\(macAccessibilityCommentsLength) characters"))
                }
                TextEditor(text: $macPayload.accessibilityComments)
                    .frame(minHeight: 120)
                    .accessibilityLabel(String(localized: "Accessibility Comments"))
                    .accessibilityHint(String(localized: "Required. Minimum 20 characters."))
                    .onChange(of: macPayload.accessibilityComments) { _, newValue in
                        handleMacAccessibilityCommentsChange(newValue)
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                rewriteButton(text: $macPayload.accessibilityComments)
            }

            Section("Other Comments (optional)") {
                TextEditor(text: $macPayload.otherComments)
                    .frame(minHeight: 80)
                    .onChange(of: macPayload.otherComments) { _, newValue in
                        guidelines.textChanged(newValue)
                        intelligence.textChanged(
                            newValue,
                            translationEnabled: preferences.composeTranslationEnabled,
                            detectionEnabled: preferences.nonEnglishDetectionEnabled
                        )
                    }
                rewriteButton(text: $macPayload.otherComments)
            }
        }
    }

    /// Was a toolbar button under the overflow "More" menu, scoped only to
    /// Accessibility Comments — easy to miss entirely (this screen's most
    /// useful for exactly the submitters least likely to go digging in an
    /// overflow menu: someone less confident writing in English, or short
    /// on time), and its scope wasn't obvious from a generic toolbar label.
    /// Now sits directly under each field it actually rewrites, matching
    /// this screen's own existing pattern for TranslatePromptView/
    /// GuidelinesReminderView, and extended to Additional Comments, which
    /// never had it at all. Reported directly.
    @ViewBuilder
    private func rewriteButton(text: Binding<String>) -> some View {
        if preferences.composeRewriteEnabled && IntelligenceService.isAvailable {
            Button {
                Task {
                    if let result = await intelligence.rewrite(subject: nil, body: text.wrappedValue, isTopic: false) {
                        text.wrappedValue = result.body
                    } else {
                        toast.error(String(localized: "Couldn't rewrite this. Try again."))
                    }
                }
            } label: {
                Label("Rewrite", systemImage: "wand.and.stars")
            }
            .disabled(text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty || intelligence.isProcessing)
            .accessibilityHint(String(localized: "Uses Apple Intelligence to suggest a clearer rewrite of this text."))
        }
    }

    private func search() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        // Apple's own `tvSoftware` search entity is confirmed dead — it
        // returns zero results for any query, so picking Apple TV here and
        // searching used to silently show "No results" for every app,
        // every time. `searchTvOS` works around this by searching the iOS
        // catalog (which works) and verifying each candidate independently
        // has a real Apple TV build. Reported directly. `searchMacOS`
        // solves a different problem for Mac: a Mac app can be a genuine
        // separate Mac App Store listing OR a Catalyst app sharing its iOS
        // listing, and neither entity's search reliably tells the two
        // apart on its own — see `ItunesAPI.searchMacOS`.
        let results: [ItunesSearchHit]
        switch platform {
        case .tvos:  results = await ItunesAPI.searchTvOS(searchQuery)
        case .macos: results = await ItunesAPI.searchMacOS(searchQuery)
        default:     results = await ItunesAPI.search(searchQuery, entity: platform.itunesEntity)
        }
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
        switch platform {
        case .tvos:
            tvPayload.appName = hit.appName
        case .watchos:
            watchPayload.appName = hit.appName
            watchPayload.appStoreUrl = hit.appStoreUrl
        case .macos:
            macPayload.appName = hit.appName
            macPayload.appStoreUrl = hit.appStoreUrl
        case .ios:
            payload.appName = hit.appName
            payload.appStoreUrl = hit.appStoreUrl
        }
        SoundPlayer.shared.play(.pickerTick)
        step = .details
        focusStepAfterTransition()
        Task {
            // Mac can't fetch with a single fixed entity the way the other
            // three can — `searchMacOS`'s two branches (native Mac App
            // Store vs. Catalyst) need different entities to look the same
            // id back up successfully. `fetchMacMetadata` tries both.
            let meta = platform == .macos
                ? await ItunesAPI.fetchMacMetadata(appStoreUrl: hit.appStoreUrl)
                : await ItunesAPI.fetchMetadata(appStoreUrl: hit.appStoreUrl, entity: platform.itunesEntity)
            if let meta {
                applyMetadata(meta)
            }
        }
    }

    private func goNext() {
        guard step == .details else { return }
        SoundPlayer.shared.play(.pickerTick)
        step = .review
        acknowledgedDuplicate = false
        focusStepAfterTransition()
        // The duplicate-check endpoint only searches `node/ios_app_directory`
        // — it has no way to look up existing Apple TV, Apple Watch, or Mac
        // entries at all, so running it here would only produce misleading
        // iOS-app matches against an entirely different content type.
        // Skipped for all three rather than shown wrong. Reported directly.
        if platform == .ios {
            Task { await checkForDuplicates() }
        }
    }

    private func goBack() {
        SoundPlayer.shared.play(.pickerTick)
        switch step {
        case .review:  step = .details
        case .details: step = .search
        case .search:  break
        }
        focusStepAfterTransition()
    }

    /// Step-backward navigation, separated from the toolbar's Cancel button
    /// (which now always cancels, regardless of step) — matches the Welcome
    /// Tour's existing in-content Back button.
    private var backButton: some View {
        Button {
            goBack()
        } label: {
            Label("Back", systemImage: "chevron.backward")
        }
    }

    private func focusStepAfterTransition() {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            isStepFocused = true
        }
    }

    /// Title-contains lookup against the existing directory before this
    /// submission goes through — legacy warned the submitter and offered
    /// View Existing/Continue Anyway; native had no equivalent check at all
    /// (SUBMIT-004). Non-blocking: the submitter can acknowledge and proceed,
    /// since a title match isn't necessarily the same app.
    private func checkForDuplicates() async {
        isCheckingDuplicates = true
        exactDuplicateMatches = []
        duplicateMatches = []
        let result = try? await APIClient.shared.apps.checkForDuplicate(
            appName: payload.appName,
            appStoreUrl: payload.appStoreUrl,
            platform: platform
        )
        exactDuplicateMatches = result?.exactMatches ?? []
        let exactIds = Set(exactDuplicateMatches.map(\.id))
        duplicateMatches = (result?.matches ?? []).filter { !exactIds.contains($0.id) }
        isCheckingDuplicates = false
    }

    private var reviewSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 3, total: 3, title: "Review & Submit", isFocused: $isStepFocused)
                backButton
            }
            if isCheckingDuplicates {
                Section {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Checking for existing entries…")
                    }
                    .accessibilityElement(children: .combine)
                }
            } else if !exactDuplicateMatches.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Already in App Directory", systemImage: "exclamationmark.octagon.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline.weight(.semibold))
                        Text("This App Store listing appears to already have an AppleVis app entry. To avoid duplication, choose a different app or open the existing entry.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(exactDuplicateMatches) { match in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(match.name)
                                    .font(.caption.weight(.medium))
                                if let url = URL(string: match.url) {
                                    Link("Open Existing Entry", destination: url)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } else if !duplicateMatches.isEmpty && !acknowledgedDuplicate {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Possible duplicate", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline.weight(.semibold))
                        Text(duplicateMatches.count == 1
                            ? "An app entry already in the directory has a similar name:"
                            : "\(duplicateMatches.count) app entries already in the directory have a similar name:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(duplicateMatches) { match in
                            Text(match.name)
                                .font(.caption.weight(.medium))
                        }
                        Button("This is a different app — continue anyway") {
                            acknowledgedDuplicate = true
                        }
                        .font(.caption)
                    }
                }
            }
            Section("From") {
                WizardReviewRow(label: "Posting As", value: auth.user?.name ?? "")
            }
            Section("App") {
                WizardReviewRow(label: "Platform", value: platform.displayName)
                WizardReviewRow(label: "App Name", value: payload.appName)
                WizardReviewRow(label: "App Store URL", value: payload.appStoreUrl)
                WizardReviewRow(label: "Version", value: payload.appVersion)
                WizardReviewRow(label: "Price", value: payload.price)
                WizardReviewRow(label: "Category", value: payload.category)
                WizardReviewRow(label: "Minimum OS Version", value: payload.osVersion)
                WizardReviewRow(
                    label: "Device(s) Tested On",
                    value: deviceOptions.filter { payload.supportedDevices.contains($0.value) }.map(\.label).joined(separator: ", ")
                )
                WizardReviewRow(label: "Description of App", value: payload.appStoreDescription)
                if !payload.developerWebsite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    WizardReviewRow(label: "Developer's Website", value: payload.developerWebsite)
                }
            }
            Section("Accessibility Assessment") {
                WizardReviewRow(label: "VoiceOver Performance", value: payload.voiceOverPerformance)
                WizardReviewRow(label: "Button Labelling", value: payload.buttonLabelling)
                WizardReviewRow(label: "Usability", value: payload.usabilityNotes)
                WizardReviewRow(label: "Accessibility Comments", value: payload.accessibilityComments)
            }
            Section("Additional") {
                WizardReviewRow(label: "Short Summary", value: payload.shortSummary)
                WizardReviewRow(label: "Additional Comments", value: payload.otherComments)
            }
        }
    }

    private var tvReviewSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 3, total: 3, title: "Review & Submit", isFocused: $isStepFocused)
                backButton
            }
            // No duplicate check runs for tvOS submissions (see `goNext()`)
            // — the endpoint it would call can't search Apple TV entries.
            Section("From") {
                WizardReviewRow(label: "Posting As", value: auth.user?.name ?? "")
            }
            Section("App") {
                WizardReviewRow(label: "Platform", value: platform.displayName)
                WizardReviewRow(label: "App Name", value: tvPayload.appName)
                WizardReviewRow(label: "Price", value: tvPayload.price)
                WizardReviewRow(label: "Category", value: tvPayload.category)
                WizardReviewRow(label: "Description of App", value: tvPayload.appDescription)
            }
            Section("Accessibility Assessment") {
                WizardReviewRow(label: "Usability", value: tvPayload.usability)
                WizardReviewRow(label: "Accessibility Comments", value: tvPayload.accessibilityComments)
            }
            if !tvPayload.otherComments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Additional") {
                    WizardReviewRow(label: "Other Comments", value: tvPayload.otherComments)
                }
            }
        }
    }

    private var watchReviewSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 3, total: 3, title: "Review & Submit", isFocused: $isStepFocused)
                backButton
            }
            // No duplicate check runs for watchOS submissions (see
            // `goNext()`) — the endpoint it would call can't search Apple
            // Watch entries.
            Section("From") {
                WizardReviewRow(label: "Posting As", value: auth.user?.name ?? "")
            }
            Section("App") {
                WizardReviewRow(label: "Platform", value: platform.displayName)
                WizardReviewRow(label: "App Name", value: watchPayload.appName)
                WizardReviewRow(label: "App Store URL", value: watchPayload.appStoreUrl)
                WizardReviewRow(label: "Version", value: watchPayload.appVersion)
                WizardReviewRow(label: "watchOS Version", value: watchPayload.watchosVersion)
                WizardReviewRow(label: "Price", value: watchPayload.price)
                WizardReviewRow(label: "Category", value: watchPayload.category)
                WizardReviewRow(label: "Description of App", value: watchPayload.appDescription)
                if !watchPayload.developerWebsite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    WizardReviewRow(label: "Developer's Website", value: watchPayload.developerWebsite)
                }
            }
            Section("Accessibility Assessment") {
                WizardReviewRow(label: "Usability", value: watchPayload.usability)
                WizardReviewRow(label: "Accessibility Comments", value: watchPayload.accessibilityComments)
            }
            if !watchPayload.otherComments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Additional") {
                    WizardReviewRow(label: "Other Comments", value: watchPayload.otherComments)
                }
            }
        }
    }

    private var macReviewSection: some View {
        Group {
            Section {
                WizardStepIndicator(step: 3, total: 3, title: "Review & Submit", isFocused: $isStepFocused)
                backButton
            }
            // No duplicate check runs for Mac submissions (see `goNext()`)
            // — the endpoint it would call can't search Mac entries.
            Section("From") {
                WizardReviewRow(label: "Posting As", value: auth.user?.name ?? "")
            }
            Section("App") {
                WizardReviewRow(label: "Platform", value: platform.displayName)
                WizardReviewRow(label: "App Name", value: macPayload.appName)
                if !macPayload.appStoreUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    WizardReviewRow(label: "App Store URL", value: macPayload.appStoreUrl)
                } else if !macPayload.macUpdateUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    WizardReviewRow(label: "MacUpdate Link", value: macPayload.macUpdateUrl)
                }
                WizardReviewRow(label: "Version", value: macPayload.appVersion)
                WizardReviewRow(label: "Version Of macOS App Was Tested On", value: macPayload.osxVersionTested)
                WizardReviewRow(label: "Price", value: macPayload.price)
                WizardReviewRow(label: "Category", value: macPayload.category)
                WizardReviewRow(label: "Description of App", value: macPayload.appDescription)
                if !macPayload.developerWebsite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    WizardReviewRow(label: "Developer's Website", value: macPayload.developerWebsite)
                }
            }
            Section("Accessibility Assessment") {
                WizardReviewRow(label: "Usability", value: macPayload.usability)
                WizardReviewRow(label: "Accessibility Comments", value: macPayload.accessibilityComments)
            }
            if !macPayload.otherComments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Additional") {
                    WizardReviewRow(label: "Other Comments", value: macPayload.otherComments)
                }
            }
        }
    }

    private func submit() async {
        guard let user = auth.user else { return }
        if platform == .tvos {
            await submitTv(user: user)
            return
        }
        if platform == .watchos {
            await submitWatch(user: user)
            return
        }
        if platform == .macos {
            await submitMac(user: user)
            return
        }
        if !exactDuplicateMatches.isEmpty {
            let message = "This app already appears to exist in the AppleVis App Directory. Please open the existing entry instead of submitting a duplicate."
            error = message
            await announceWizardFailure(message, focus: $isErrorFocused)
            return
        }
        // Previously only Accessibility Comments + Additional Comments —
        // Short Summary and a manually-typed Description of App are just
        // as user-authored, and neither was covered at all, live or at
        // Submit. A description pulled from the App Store isn't included
        // even now: that's Apple's own text, not something being asked of
        // the submitter, so it isn't fair to hold it to this policy.
        // Reported directly.
        var policyParts = [payload.accessibilityComments, payload.otherComments, payload.shortSummary]
        if !isMetadataFromAppStore {
            policyParts.append(payload.appStoreDescription)
        }
        let policyBody = policyParts.joined(separator: "\n\n")
        if let message = ContentSubmissionPolicy.blockingMessage(
            subject: payload.appName,
            body: policyBody
        ) {
            error = message
            await announceWizardFailure(message, focus: $isErrorFocused)
            return
        }
        isSubmitting = true; error = nil
        do {
            _ = try await APIClient.shared.apps.submitApp(payload: payload, csrfToken: user.csrfToken)
            SoundPlayer.shared.play(.success)
            submitted = true
        } catch let e as APIError {
            error = e.localizedDescription
            await announceWizardFailure(e.localizedDescription, focus: $isErrorFocused)
        } catch {
            self.error = "Couldn't submit app."
            await announceWizardFailure("Couldn't submit app.", focus: $isErrorFocused)
        }
        isSubmitting = false
    }

    private func submitTv(user: AuthUser) async {
        var policyParts = [tvPayload.accessibilityComments, tvPayload.otherComments]
        if !isMetadataFromAppStore {
            policyParts.append(tvPayload.appDescription)
        }
        let policyBody = policyParts.joined(separator: "\n\n")
        if let message = ContentSubmissionPolicy.blockingMessage(
            subject: tvPayload.appName,
            body: policyBody
        ) {
            error = message
            await announceWizardFailure(message, focus: $isErrorFocused)
            return
        }
        isSubmitting = true; error = nil
        do {
            _ = try await APIClient.shared.apps.submitTvApp(payload: tvPayload, csrfToken: user.csrfToken)
            SoundPlayer.shared.play(.success)
            submitted = true
        } catch let e as APIError {
            error = e.localizedDescription
            await announceWizardFailure(e.localizedDescription, focus: $isErrorFocused)
        } catch {
            self.error = "Couldn't submit app."
            await announceWizardFailure("Couldn't submit app.", focus: $isErrorFocused)
        }
        isSubmitting = false
    }

    private func submitWatch(user: AuthUser) async {
        var policyParts = [watchPayload.accessibilityComments, watchPayload.otherComments]
        if !isMetadataFromAppStore {
            policyParts.append(watchPayload.appDescription)
        }
        let policyBody = policyParts.joined(separator: "\n\n")
        if let message = ContentSubmissionPolicy.blockingMessage(
            subject: watchPayload.appName,
            body: policyBody
        ) {
            error = message
            await announceWizardFailure(message, focus: $isErrorFocused)
            return
        }
        isSubmitting = true; error = nil
        do {
            _ = try await APIClient.shared.apps.submitWatchApp(payload: watchPayload, csrfToken: user.csrfToken)
            SoundPlayer.shared.play(.success)
            submitted = true
        } catch let e as APIError {
            error = e.localizedDescription
            await announceWizardFailure(e.localizedDescription, focus: $isErrorFocused)
        } catch {
            self.error = "Couldn't submit app."
            await announceWizardFailure("Couldn't submit app.", focus: $isErrorFocused)
        }
        isSubmitting = false
    }

    private func submitMac(user: AuthUser) async {
        var policyParts = [macPayload.accessibilityComments, macPayload.otherComments]
        if !isMetadataFromAppStore {
            policyParts.append(macPayload.appDescription)
        }
        let policyBody = policyParts.joined(separator: "\n\n")
        if let message = ContentSubmissionPolicy.blockingMessage(
            subject: macPayload.appName,
            body: policyBody
        ) {
            error = message
            await announceWizardFailure(message, focus: $isErrorFocused)
            return
        }
        isSubmitting = true; error = nil
        do {
            _ = try await APIClient.shared.apps.submitMacApp(payload: macPayload, csrfToken: user.csrfToken)
            SoundPlayer.shared.play(.success)
            submitted = true
        } catch let e as APIError {
            error = e.localizedDescription
            await announceWizardFailure(e.localizedDescription, focus: $isErrorFocused)
        } catch {
            self.error = "Couldn't submit app."
            await announceWizardFailure("Couldn't submit app.", focus: $isErrorFocused)
        }
        isSubmitting = false
    }
}
