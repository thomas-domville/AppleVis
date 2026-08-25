import SwiftUI

struct QueueView: View {
    /// Set when presented as a sheet (e.g. from the full player, PODCAST-13)
    /// rather than pushed as the Podcasts tab's own root — adds a "Done"
    /// toolbar button, which wouldn't make sense on the persistent tab root
    /// where there's nothing to dismiss back to.
    var isModal: Bool = false
    @EnvironmentObject private var player: PlayerStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @EnvironmentObject private var preferences: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirm = false
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if player.queue.isEmpty {
                    ContentUnavailableView(
                        "Your Queue Is Empty",
                        systemImage: "list.number",
                        description: Text("Add episodes from the Podcasts tab or from any episode detail page.")
                    )
                    .accessibilityFocused($isTitleFocused)
                } else {
                    List {
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
                    .toolbar {
                        EditButton()
                    }
                    .themedList(preferences.colors)
                }
            }
            .navigationTitle("Queue")
            .task { await retryAccessibilityFocus(into: $isTitleFocused) }
            .toolbar {
                if isModal {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
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
            .accessibilityFocused($isTitleFocused)
            .accessibilityAction(named: Text("Queue summary")) {
                let totalSeconds = player.queue.reduce(0.0) { $0 + ($1.duration ?? 0) }
                let duration = totalSeconds > 0 ? ", about \(PodcastDuration.accessibilityLabel(totalSeconds))" : ""
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

    /// Drupal's `duration` is hardcoded to 0, never nil (see
    /// `PodcastAudioMetadataProbe`) — falls back to whatever's already been
    /// resolved and cached elsewhere, read-only; an episode reaching the
    /// queue has already been encountered via a browse row or its detail
    /// page, both of which do trigger a live probe.
    private var displayDuration: TimeInterval? {
        if let duration = episode.duration, duration > 0 { return duration }
        return PersistenceStore.shared.cachedAudioMetadata(episodeId: episode.id)?.duration
    }

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
                    if let duration = displayDuration {
                        Text(PodcastDuration.abbreviated(duration))
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
            (displayDuration.map { String(localized: ", \(PodcastDuration.accessibilityLabel($0))") } ?? "")
        )
        .accessibilityHint(String(localized: "Double-tap to open. Use actions to move or remove."))
        .accessibilityAction(named: Text("Open Episode"), onOpen)
        .modifier(ConditionalAccessibilityAction(isActive: !isFirst, name: "Move Up", action: onMoveUp))
        .modifier(ConditionalAccessibilityAction(isActive: !isLast, name: "Move Down", action: onMoveDown))
        .accessibilityAction(named: Text("Remove from Queue"), onRemove)
    }
}

