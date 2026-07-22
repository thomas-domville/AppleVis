import SwiftUI

struct ForYouView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerStore
    @State private var selectedTab: ForYouTab = .queue

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    ForEach(ForYouTab.allCases) { tab in
                        Text(tab.displayName).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Group {
                    switch selectedTab {
                    case .queue:     QueueView()
                    case .saved:     SavedItemsView()
                    case .following: FollowingView()
                    }
                }
            }
            .navigationTitle("For You")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if auth.isSignedIn {
                        NavigationLink(destination: ProfileView()) {
                            Image(systemName: "person.circle")
                        }
                    } else {
                        NavigationLink(destination: SignInView()) {
                            Text("Sign In")
                        }
                    }
                }
            }
        }
    }
}

enum ForYouTab: String, CaseIterable, Identifiable {
    case queue, saved, following

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .queue:     return "Queue"
        case .saved:     return "Saved"
        case .following: return "Following"
        }
    }
}

// MARK: - Queue

struct QueueView: View {
    @EnvironmentObject private var player: PlayerStore

    var body: some View {
        if player.queue.isEmpty {
            EmptyStateView(
                title: "Queue is Empty",
                message: "Add episodes to your queue from any podcast screen.",
                systemImage: "list.bullet"
            )
        } else {
            List {
                if let current = player.currentEpisode {
                    Section("Now Playing") {
                        PodcastEpisodeRow(episode: current)
                    }
                }
                Section("Up Next") {
                    ForEach(player.queue) { episode in
                        PodcastEpisodeRow(episode: episode)
                            .swipeActions {
                                Button("Remove", role: .destructive) {
                                    player.removeFromQueue(id: episode.id)
                                }
                            }
                    }
                    .onMove { source, dest in
                        player.moveInQueue(from: source, to: dest)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
        }
    }
}

// MARK: - Saved Items

struct SavedItemsView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var items: [SavedItem] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var filter: ContentKind? = nil

    var filtered: [SavedItem] {
        guard let f = filter else { return items }
        return items.filter { $0.kind == f }
    }

    var body: some View {
        Group {
            if !auth.isSignedIn {
                EmptyStateView(title: "Sign In Required", message: "Sign in to view your saved items.", systemImage: "bookmark")
            } else if isLoading {
                LoadingView()
            } else if let error {
                ErrorView(message: error) { await load() }
            } else if filtered.isEmpty {
                EmptyStateView(title: "Nothing Saved", message: "Tap the bookmark icon on any item to save it.", systemImage: "bookmark")
            } else {
                savedList
            }
        }
        .task { await load() }
    }

    private var savedList: some View {
        List {
            filterPicker
            ForEach(filtered) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Label(item.kind.displayName, systemImage: item.kind.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.title)
                }
            }
        }
    }

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                FilterChip(title: "All", isSelected: filter == nil) { filter = nil }
                ForEach(ContentKind.allCases, id: \.self) { kind in
                    FilterChip(title: kind.displayName, isSelected: filter == kind) { filter = kind }
                }
            }
            .padding(.horizontal)
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private func load() async {
        guard let user = auth.user else { return }
        isLoading = true
        error = nil
        do {
            items = try await APIClient.shared.account.savedItems(csrfToken: user.csrfToken)
        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = "Couldn't load saved items."
        }
        isLoading = false
    }
}

// MARK: - Following

struct FollowingView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var items: [FollowedItem] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Group {
            if !auth.isSignedIn {
                EmptyStateView(title: "Sign In Required", message: "Sign in to view topics you're following.", systemImage: "bell")
            } else if isLoading {
                LoadingView()
            } else if let error {
                ErrorView(message: error) { await load() }
            } else if items.isEmpty {
                EmptyStateView(title: "Not Following Anything", message: "Follow forum topics to get notified of new replies.", systemImage: "bell")
            } else {
                List(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(item.kind.displayName, systemImage: item.kind.systemImage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.title)
                        if let activity = item.lastActivityAt {
                            RelativeDateLabel(date: activity)
                        }
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let user = auth.user else { return }
        isLoading = true
        error = nil
        do {
            items = try await APIClient.shared.account.followedItems(csrfToken: user.csrfToken)
        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = "Couldn't load followed items."
        }
        isLoading = false
    }
}

// MARK: - Filter chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
