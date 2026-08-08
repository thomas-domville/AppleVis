import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if player.queue.isEmpty && player.currentEpisode == nil {
                    ContentUnavailableView(
                        "Your Queue Is Empty",
                        systemImage: "list.number",
                        description: Text("Add episodes from the Podcasts tab or from any episode detail page.")
                    )
                } else {
                    List {
                        if let current = player.currentEpisode {
                            Section("Now Playing") {
                                NowPlayingQueueCard(episode: current)
                            }
                        }

                        if !player.queue.isEmpty {
                            Section {
                                queueSummaryHeader
                                ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, episode in
                                    QueueRow(
                                        episode: episode,
                                        position: index + 1,
                                        total: player.queue.count,
                                        isFirst: index == 0,
                                        isLast: index == player.queue.count - 1,
                                        onOpen: { deepLinkRouter.pendingContent = (kind: .podcastEpisode, id: episode.id) },
                                        onMoveUp: { moveUp(from: index) },
                                        onMoveDown: { moveDown(from: index) },
                                        onRemove: { player.removeFromQueue(id: episode.id) }
                                    )
                                }
                                .onMove { source, dest in
                                    player.moveInQueue(from: source, to: dest)
                                }
                            } header: {
                                Text("Up Next")
                            } footer: {
                                Text("\(player.queue.count) episode\(player.queue.count == 1 ? "" : "s") in queue")
                            }

                            Button("Clear Queue", role: .destructive) { showClearConfirm = true }
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .toolbar {
                        EditButton()
                    }
                    .themedList(preferences.colors)
                }
            }
            .navigationTitle("Queue")
            .confirmationDialog(
                "Clear the entire queue?", isPresented: $showClearConfirm, titleVisibility: .visible
            ) {
                Button("Clear Queue", role: .destructive) {
                    player.clearQueue()
                    UIAccessibility.post(notification: .announcement, argument: "Queue cleared.")
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all episodes from your queue. Downloaded episodes will not be deleted.")
            }
        }
    }

    private var queueSummaryHeader: some View {
        Text("Up Next (\(player.queue.count))")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
            .accessibilityAction(named: Text("Queue summary")) {
                let totalSeconds = player.queue.reduce(0.0) { $0 + ($1.duration ?? 0) }
                let duration = totalSeconds > 0 ? ", about \(formatDuration(totalSeconds))" : ""
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "\(player.queue.count) episode\(player.queue.count == 1 ? "" : "s") in queue\(duration)."
                )
            }
    }

    private func moveUp(from index: Int) {
        guard index > 0 else { return }
        player.moveInQueue(from: IndexSet(integer: index), to: index - 1)
    }

    private func moveDown(from index: Int) {
        guard index < player.queue.count - 1 else { return }
        player.moveInQueue(from: IndexSet(integer: index), to: index + 2)
    }
}

// MARK: - Now Playing Card

private struct NowPlayingQueueCard: View {
    let episode: PodcastEpisode
    @EnvironmentObject private var player: PlayerStore

    private var progress: Double? {
        guard player.duration > 0 else { return nil }
        return player.position / player.duration
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(episode.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(episode.showTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let p = progress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: p)
                        .tint(Color.accentColor)
                    HStack {
                        Text(formatTime(player.position))
                            .font(.caption2)
                            .monospacedDigit()
                        Spacer()
                        Text(formatTime(player.duration))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)
                }
                .accessibilityLabel(String(localized: "Playback progress: \(Int(p * 100)) percent"))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Now playing: \(episode.title), \(episode.showTitle)"))
    }
}

// MARK: - Queue Row

private struct QueueRow: View {
    let episode: PodcastEpisode
    let position: Int
    let total: Int
    let isFirst: Bool
    let isLast: Bool
    let onOpen: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(position)")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 28, alignment: .trailing)
                .accessibilityHidden(true)

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(episode.title)
                        .font(.subheadline)
                        .lineLimit(2)
                    Text(episode.showTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let duration = episode.duration {
                        Text(formatDuration(duration))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(isFirst)
                .accessibilityHidden(true)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(isLast)
                .accessibilityHidden(true)

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "\(position) of \(total). \(episode.title), \(episode.showTitle)") +
            (episode.duration.map { String(localized: ", \(formatDuration($0))") } ?? "")
        )
        .accessibilityHint(String(localized: "Double-tap to open. Use actions to move or remove."))
        .accessibilityAction(named: Text("Open Episode"), onOpen)
        .modifier(ConditionalAccessibilityAction(isActive: !isFirst, name: "Move Up", action: onMoveUp))
        .modifier(ConditionalAccessibilityAction(isActive: !isLast, name: "Move Down", action: onMoveDown))
        .accessibilityAction(named: Text("Remove from Queue"), onRemove)
    }
}

// MARK: - Helpers

private func formatTime(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    return hours > 0
        ? String(format: "%d:%02d:%02d", hours, minutes, secs)
        : String(format: "%d:%02d", minutes, secs)
}

private func formatDuration(_ seconds: TimeInterval) -> String {
    let mins = Int(seconds) / 60
    let hrs = mins / 60
    let rem = mins % 60
    return hrs > 0 ? "\(hrs)h \(rem)m" : "\(mins)m"
}
