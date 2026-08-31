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
            .accessibilityHint(String(localized: "Double-tap to view profile."))
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
    @EnvironmentObject private var auth: AuthStore
    @State private var profile: UserEndpoints.PublicProfile?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showContactSheet = false

    /// Contacting yourself makes no sense, and Drupal's Contact module needs
    /// a real numeric uid to address the message to — a profile that failed
    /// to resolve one (0 is `PublicProfile`'s "missing" default) has nothing
    /// to send to. Also respects the site's own "Personal contact form"
    /// checkbox (`field.allowsContact`) — someone who's turned that off
    /// shouldn't see a Contact button here either.
    private var canContact: Bool {
        auth.isSignedIn
            && authorId != (auth.user?.uuid ?? "")
            && (profile?.numericUid ?? 0) != 0
            && (profile?.allowsContact ?? true)
    }

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
                headerCard(profile)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            if !profile.location.isEmpty {
                Section("Location") {
                    Label(profile.location, systemImage: "mappin.and.ellipse")
                }
            }
            if !profile.bio.isEmpty {
                Section("About") {
                    // Split into separate accessibility elements (one per
                    // line the person actually typed) rather than one flat
                    // block of Text — matches the same reasoning
                    // SegmentedHTMLView/ReplyCard already apply to comment
                    // bodies: a multi-paragraph bio flattened into a single
                    // element is unpredictable to navigate cell-by-cell on
                    // a Braille display.
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(bioParagraphs(profile.bio).enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph).lineSpacing(4)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            if !profile.website.isEmpty, let url = URL(string: profile.website) {
                Section("Website") {
                    WebLink(destination: url) {
                        Label(profile.website, systemImage: "link")
                    }
                }
            }
            if !profile.interests.isEmpty {
                Section("Interests") {
                    Label(profile.interests, systemImage: "star")
                }
            }
            if !profile.owns.isEmpty {
                Section("Apple Products Owned") {
                    Label(profile.owns, systemImage: "apple.logo")
                }
            }
            if !profile.twitter.isEmpty || !profile.mastodon.isEmpty || !profile.facebook.isEmpty {
                Section("Elsewhere") {
                    if !profile.twitter.isEmpty, let url = twitterURL(profile.twitter) {
                        WebLink(destination: url) {
                            Label("@\(handle(profile.twitter)) on X", systemImage: "at")
                        }
                    }
                    if !profile.mastodon.isEmpty, let url = mastodonURL(profile.mastodon) {
                        WebLink(destination: url) {
                            Label("\(profile.mastodon) on Mastodon", systemImage: "at")
                        }
                    }
                    if !profile.facebook.isEmpty, let url = URL(string: profile.facebook) {
                        WebLink(destination: url) {
                            Label("Facebook", systemImage: "person.2")
                        }
                    }
                }
            }
            if canContact {
                Section {
                    Button {
                        showContactSheet = true
                    } label: {
                        Label("Contact \(profile.displayName)", systemImage: "envelope")
                    }
                    .accessibilityHint(String(localized: "Sends a private message through AppleVis. Your email address is not shared unless they reply."))
                }
            }
            if let profileUrl = profile.profileUrl, let url = URL(string: profileUrl) {
                Section {
                    WebLink(destination: url) {
                        Label("View Full Profile on AppleVis", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
        .themedList(preferences.colors)
        .sheet(isPresented: $showContactSheet) {
            ContactUserSheet(numericUid: profile.numericUid, recipientName: profile.displayName)
        }
    }

    /// Warm header replacing the old plain-text name+date pair — a large
    /// per-author-colored avatar (same hash/palette every comment row
    /// already uses, so this person reads as the same color everywhere they
    /// appear) over a soft tint of that same color.
    private func headerCard(_ profile: UserEndpoints.PublicProfile) -> some View {
        VStack(spacing: 10) {
            AuthorAvatarView(name: profile.displayName, diameter: 72)
            // docs/IMPLEMENTATION_NOTES.md requires the member name be the
            // heading here — was missing the trait entirely (PROFILE-04).
            Text(profile.displayName).font(.title2).fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            // .distantPast is JsonApiNode.parseDrupalDate's sentinel for a
            // missing/malformed "created" field, not a real date —
            // rendering it unconditionally produced a nonsensical "Member
            // since January 1, 1" with no visual "this looks wrong" cue for
            // a VoiceOver user to catch, contradicting
            // IMPLEMENTATION_NOTES.md's own rule to render this "only when
            // the API returns them" (PROFILE-03).
            if profile.memberSince != .distantPast {
                Text("Member since \(profile.memberSince.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                colors: [AuthorAvatarColor.color(for: profile.displayName).opacity(0.18), Color.clear],
                startPoint: .top, endPoint: .bottom
            )
        )
        .accessibilityElement(children: .combine)
    }

    private func bioParagraphs(_ bio: String) -> [String] {
        bio.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func handle(_ raw: String) -> String {
        raw.hasPrefix("@") ? String(raw.dropFirst()) : raw
    }

    private func twitterURL(_ raw: String) -> URL? {
        if raw.lowercased().hasPrefix("http") { return URL(string: raw) }
        return URL(string: "https://x.com/\(handle(raw))")
    }

    /// `field_mastodon_username` stores "@user@instance.social" (or without
    /// the leading @) — there's no single canonical Mastodon host, so the
    /// profile URL has to be built from the instance domain embedded in the
    /// handle itself.
    private func mastodonURL(_ raw: String) -> URL? {
        if raw.lowercased().hasPrefix("http") { return URL(string: raw) }
        let parts = handle(raw).split(separator: "@")
        guard parts.count == 2 else { return nil }
        return URL(string: "https://\(parts[1])/@\(parts[0])")
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

/// Sends a private message to another member via Drupal's Contact module
/// (`UserEndpoints.sendContact`) — the recipient's email is never fetched or
/// shown here; Drupal delivers the message using its own stored address, and
/// the sender's address only reaches the recipient if they reply.
private struct ContactUserSheet: View {
    let numericUid: Int
    let recipientName: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var toast: ToastStore
    @EnvironmentObject private var auth: AuthStore

    @State private var subject = ""
    @State private var message = ""
    @State private var isSending = false
    @State private var error: String?
    @AccessibilityFocusState private var isErrorFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Your message is sent through AppleVis. \(recipientName) will not see your email address unless they choose to reply.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("Subject") {
                    TextField("What's this about?", text: $subject)
                }
                Section("Message") {
                    TextEditor(text: $message)
                        .frame(minHeight: 160)
                        .accessibilityLabel(String(localized: "Message text editor"))
                }
                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                            .accessibilityFocused($isErrorFocused)
                    }
                }
            }
            .themedList(preferences.colors)
            .navigationTitle("Contact \(recipientName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { Task { await send() } }
                        .disabled(isSending
                            || subject.trimmingCharacters(in: .whitespaces).isEmpty
                            || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .disabled(isSending)
            .overlay {
                if isSending {
                    ProgressView("Sending…")
                        .padding(20)
                        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func send() async {
        if let blocking = ContentSubmissionPolicy.blockingMessage(subject: subject, body: message) {
            error = blocking
            isErrorFocused = true
            return
        }
        guard let user = auth.user else { return }
        isSending = true; error = nil
        do {
            try await APIClient.shared.users.sendContact(
                numericUid: numericUid, subject: subject, message: message, csrfToken: user.csrfToken
            )
            toast.success(String(localized: "Message sent"))
            dismiss()
        } catch let e as APIError {
            error = e.localizedDescription
            isErrorFocused = true
        } catch {
            self.error = "Couldn't send your message. Please try again."
            isErrorFocused = true
        }
        isSending = false
    }
}
