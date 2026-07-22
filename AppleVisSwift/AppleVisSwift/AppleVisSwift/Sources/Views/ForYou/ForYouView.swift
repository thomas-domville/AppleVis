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
                    case .downloads: DownloadsView()
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
    case queue, downloads, saved, following

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .queue:     return "Queue"
        case .downloads: return "Downloads"
        case .saved:     return "Saved"
        case .following: return "Following"
        }
    }
}

// MARK: - Downloads

struct DownloadsView: View {
    @EnvironmentObject private var player: PlayerStore
    @ObservedObject private var downloads = DownloadManager.shared

    var body: some View {
        Group {
            if downloads.downloadedEpisodes.isEmpty && downloads.activeDownloads.isEmpty {
                EmptyStateView(
                    title: "No Downloads",
                    message: "Download episodes for offline playback from any episode's detail page.",
                    systemImage: "arrow.down.circle"
                )
            } else {
                List {
                    if !downloads.activeDownloads.isEmpty {
                        Section("Downloading") {
                            ForEach(Array(downloads.activeDownloads), id: \.self) { id in
                                HStack {
                                    Text(downloads.downloadedEpisodes.first { $0.id == id }?.title ?? "Episode")
                                    Spacer()
                                    ProgressView(value: downloads.progress[id] ?? 0)
                                        .frame(width: 60)
                                }
                            }
                        }
                    }
                    Section {
                        ForEach(downloads.downloadedEpisodes, id: \.id) { meta in
                            Button {
                                Task { await playDownloaded(meta) }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meta.title).foregroundStyle(.primary)
                                    Text(formattedSize(meta.fileSizeBytes))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) { downloads.delete(meta.id) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func playDownloaded(_ meta: DownloadedEpisodeMeta) async {
        let episode = PodcastEpisode(
            id: meta.id, title: meta.title, showTitle: meta.showTitle, audioUrl: "",
            duration: nil, publishedAt: meta.downloadedAt, lastActivityAt: meta.downloadedAt,
            description: "", artworkUrl: nil, transcriptUrl: nil, chapters: [], tags: [],
            commentCount: 0, authorName: "", url: "", isSaved: false, isDownloaded: true, downloadProgress: nil
        )
        await player.load(episode)
    }

    private func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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
        guard auth.isSignedIn else { return }
        items = PersistenceStore.shared.savedItems()
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
        guard auth.isSignedIn else { return }
        items = PersistenceStore.shared.followedItems()
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
