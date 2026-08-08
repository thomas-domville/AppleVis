import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var realName = ""
    @State private var bio = ""
    @State private var location = ""
    @State private var interests = ""
    @State private var homepage = ""
    @State private var twitter = ""
    @State private var facebook = ""
    @State private var mastodon = ""

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Profile information is public. Your username and AppleVis ID cannot be changed here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Public Identity") {
                    LabeledContent("Username") {
                        Text(auth.user?.name ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Username: \(auth.user?.name ?? "unknown")")

                    LabeledContent("Real Name") {
                        TextField("Optional", text: $realName)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                    }
                    .accessibilityElement(children: .combine)
                }

                Section("About You") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $bio)
                            .frame(minHeight: 80)
                            .accessibilityLabel(String(localized: "Bio text editor"))
                    }

                    LabeledContent("Location") {
                        TextField("Optional", text: $location)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityElement(children: .combine)

                    LabeledContent("Interests") {
                        TextField("e.g. VoiceOver, Braille", text: $interests)
                            .multilineTextAlignment(.trailing)
                    }
                    .accessibilityElement(children: .combine)
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

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
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
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                } else if isLoading {
                    ProgressView("Loading…")
                }
            }
        }
        .task { await loadCurrentProfile() }
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
        } catch {
            errorMessage = "Couldn't load your current profile. You can still make changes below."
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
            mastodon: mastodon.isEmpty ? nil : mastodon
        )
        Task {
            do {
                try await APIClient.shared.account.updateProfile(
                    uuid: user.uuid,
                    csrfToken: user.csrfToken,
                    fields: fields
                )
                toast.success(String(localized: "Profile saved."))
                dismiss()
            } catch let error as APIError {
                errorMessage = error.localizedDescription
            } catch {
                errorMessage = "Could not save profile. Please try again."
            }
            isSaving = false
        }
    }
}
