import SwiftUI

/// Deterministic per-author color, hashed from their name — matches RN's
/// `hashAuthorColor` exactly (same 8-color palette and hash function) so
/// the same author gets the same color here as they did there. Purely a
/// sighted/low-vision visual cue — RN marked the whole avatar+name row
/// `accessibilityElementsHidden`, since VoiceOver already gets the name
/// from the row's own accessibility label.
enum AuthorAvatarColor {
    private static let palette: [Color] = [
        Color(red: 0x3b / 255, green: 0x82 / 255, blue: 0xf6 / 255),
        Color(red: 0x8b / 255, green: 0x5c / 255, blue: 0xf6 / 255),
        Color(red: 0x10 / 255, green: 0xb9 / 255, blue: 0x81 / 255),
        Color(red: 0xf5 / 255, green: 0x9e / 255, blue: 0x0b / 255),
        Color(red: 0xef / 255, green: 0x44 / 255, blue: 0x44 / 255),
        Color(red: 0xec / 255, green: 0x48 / 255, blue: 0x99 / 255),
        Color(red: 0x06 / 255, green: 0xb6 / 255, blue: 0xd4 / 255),
        Color(red: 0x84 / 255, green: 0xcc / 255, blue: 0x16 / 255),
    ]

    static func color(for name: String) -> Color {
        var h: UInt32 = 0
        for scalar in name.unicodeScalars {
            h = (h &* 31 &+ scalar.value) & 0xffff
        }
        return palette[Int(h) % palette.count]
    }
}

/// Circular colored initial — every comment/reply/review row in RN had one
/// of these; Swift had none anywhere, just plain author name text.
struct AuthorAvatarView: View {
    let name: String
    var diameter: CGFloat = 34

    var body: some View {
        Circle()
            .fill(AuthorAvatarColor.color(for: name))
            .frame(width: diameter, height: diameter)
            .overlay {
                Text(String(name.trimmingCharacters(in: .whitespaces).first ?? "?").uppercased())
                    .font(.system(size: diameter * 0.44, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

/// Tappable author name that presents a public profile sheet. Shows plain
/// text (non-interactive) when `authorId` is empty, since there's nothing to
/// look up.
struct AuthorProfileButton: View {
    let name: String
    let authorId: String
    var font: Font = .subheadline
    var showAvatar: Bool = false

    @State private var showProfile = false

    var body: some View {
        if authorId.isEmpty {
            label
        } else {
            Button {
                showProfile = true
            } label: {
                label
            }
            .buttonStyle(.plain)
            .accessibilityLabel(name)
            .accessibilityHint("Double-tap to view profile.")
            .sheet(isPresented: $showProfile) {
                AuthorProfileSheet(authorId: authorId, fallbackName: name)
            }
        }
    }

    @ViewBuilder
    private var label: some View {
        if showAvatar {
            HStack(spacing: 8) {
                AuthorAvatarView(name: name, diameter: 28)
                Text(name).font(font)
            }
        } else {
            Text(name).font(font)
        }
    }
}

private struct AuthorProfileSheet: View {
    let authorId: String
    let fallbackName: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore
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
        .themedList(preferences.colors)
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
