import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var player: PlayerStore

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
                                ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, episode in
                                    QueueRow(
                                        episode: episode,
                                        position: index + 1,
                                        isFirst: index == 0,
                                        isLast: index == player.queue.count - 1,
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
                        }
                    }
                    .toolbar {
                        EditButton()
                    }
                }
            }
            .navigationTitle("Queue")
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
                        .foregroundStyle(.accent)
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
                        .tint(.accent)
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
                .accessibilityLabel("Playback progress: \(Int(p * 100)) percent")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Now playing: \(episode.title), \(episode.showTitle)")
    }
}

// MARK: - Queue Row

private struct QueueRow: View {
    let episode: PodcastEpisode
    let position: Int
    let isFirst: Bool
    let isLast: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(position)")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
                .accessibilityHidden(true)

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

            Spacer()

            VStack(spacing: 2) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(isFirst)
                .accessibilityLabel("Move up")

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(isLast)
                .accessibilityLabel("Move down")

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove from queue")
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Position \(position): \(episode.title), \(episode.showTitle)")
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
