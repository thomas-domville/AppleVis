import SwiftUI

/// Tappable author name that presents a public profile sheet. Shows plain
/// text (non-interactive) when `authorId` is empty, since there's nothing to
/// look up.
struct AuthorProfileButton: View {
    let name: String
    let authorId: String
    var font: Font = .subheadline

    @State private var showProfile = false

    var body: some View {
        if authorId.isEmpty {
            Text(name).font(font)
        } else {
            Button {
                showProfile = true
            } label: {
                Text(name).font(font)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)
            .accessibilityHint("Double-tap to view profile.")
            .sheet(isPresented: $showProfile) {
                AuthorProfileSheet(authorId: authorId, fallbackName: name)
            }
        }
    }
}

private struct AuthorProfileSheet: View {
    let authorId: String
    let fallbackName: String

    @Environment(\.dismiss) private var dismiss
    @State private var profile: UserEndpoints.PublicProfile?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    LoadingView()
                } else if let error {
                    ErrorView(message: error) { await load() }
                } else if let profile {
                    content(profile)
                }
            }
            .navigationTitle(fallbackName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private func content(_ profile: UserEndpoints.PublicProfile) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.displayName).font(.title3).fontWeight(.semibold)
                    Text("Member since \(profile.memberSince.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            if !profile.location.isEmpty {
                Section("Location") { Text(profile.location) }
            }
            if !profile.bio.isEmpty {
                Section("About") { Text(profile.bio) }
            }
            if !profile.website.isEmpty, let url = URL(string: profile.website) {
                Section("Website") {
                    Link(profile.website, destination: url)
                }
            }
            if let profileUrl = profile.profileUrl, let url = URL(string: profileUrl) {
                Section {
                    Link("View Full Profile on AppleVis", destination: url)
                }
            }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            profile = try await APIClient.shared.users.profile(uuid: authorId)
        } catch let e as APIError {
            error = e.localizedDescription
        } catch {
            self.error = "Couldn't load profile."
        }
        isLoading = false
    }
}
