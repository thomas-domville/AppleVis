// WidgetKit extension for AppleVis.
// After prebuild, in Xcode: File > New > Target > Widget Extension
// Name it "AppleVisWidget", copy this file into that target.
// Set App Group to group.com.applevis.app in both targets.

import AppIntents
import WidgetKit
import SwiftUI

private let sharedDefaults = UserDefaults(suiteName: "group.com.applevis.app")

// MARK: - Shared UserDefaults data model

struct WidgetData {
  static var nowPlayingTitle: String    { sharedDefaults?.string(forKey: "nowPlayingTitle")      ?? "" }
  static var nowPlayingShow: String     { sharedDefaults?.string(forKey: "nowPlayingShow")       ?? "" }
  static var nowPlayingProgress: Double { sharedDefaults?.double(forKey: "nowPlayingProgress")   ?? 0 }
  static var isPlaying: Bool            { sharedDefaults?.bool(forKey: "isPlaying")              ?? false }
  static var unreadCount: Int           { sharedDefaults?.integer(forKey: "unreadForumCount")    ?? 0 }
  static var savedCount: Int            { sharedDefaults?.integer(forKey: "savedItemCount")      ?? 0 }
}

// MARK: - Timeline entries

struct ContinueListeningEntry: TimelineEntry {
  let date: Date
  let title: String
  let show: String
  let progress: Double
  let isPlaying: Bool
}

struct UnreadEntry: TimelineEntry {
  let date: Date
  let unreadCount: Int
}

// MARK: - Providers

struct ContinueListeningProvider: TimelineProvider {
  func placeholder(in context: Context) -> ContinueListeningEntry {
    ContinueListeningEntry(date: .now, title: "AppleVis Podcast", show: "AppleVis", progress: 0.3, isPlaying: false)
  }
  func getSnapshot(in context: Context, completion: @escaping (ContinueListeningEntry) -> Void) {
    completion(placeholder(in: context))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<ContinueListeningEntry>) -> Void) {
    let entry = ContinueListeningEntry(
      date: .now,
      title:     WidgetData.nowPlayingTitle.isEmpty ? "Nothing playing" : WidgetData.nowPlayingTitle,
      show:      WidgetData.nowPlayingShow,
      progress:  WidgetData.nowPlayingProgress,
      isPlaying: WidgetData.isPlaying
    )
    completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
  }
}

struct UnreadProvider: TimelineProvider {
  func placeholder(in context: Context) -> UnreadEntry {
    UnreadEntry(date: .now, unreadCount: 3)
  }
  func getSnapshot(in context: Context, completion: @escaping (UnreadEntry) -> Void) {
    completion(placeholder(in: context))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<UnreadEntry>) -> Void) {
    let entry = UnreadEntry(date: .now, unreadCount: WidgetData.unreadCount)
    completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
  }
}

// MARK: - iOS 17+ interactive intent

@available(iOS 17.0, *)
struct WidgetTogglePlayPauseIntent: AppIntent {
  static var title: LocalizedStringResource = "Toggle AppleVis Podcast Playback"
  // Opens the app so the player can actually control the audio session.
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    let action = WidgetData.isPlaying ? "pause" : "play"
    await UIApplication.shared.open(URL(string: "applevis://podcasts?action=\(action)")!)
    return .result()
  }
}

// MARK: - Widget views

struct ContinueListeningWidgetView: View {
  let entry: ContinueListeningEntry
  @Environment(\.widgetFamily) var family

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Image(systemName: "radio.fill")
          .foregroundColor(.blue)
          .font(.title3)
          .widgetAccentable() // tinted widget: uses user's accent color
        Spacer()
        // iOS 17+: interactive play/pause button
        if #available(iOS 17.0, *), family == .systemSmall || family == .systemMedium {
          Button(intent: WidgetTogglePlayPauseIntent()) {
            Image(systemName: entry.isPlaying ? "pause.fill" : "play.fill")
              .font(.title3)
              .foregroundColor(.blue)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(entry.isPlaying ? "Pause" : "Play")
        }
      }
      Spacer()
      if !entry.title.isEmpty && entry.title != "Nothing playing" {
        Text(entry.title)
          .font(.caption.weight(.semibold))
          .lineLimit(2)
          .widgetAccentable()
        if !entry.show.isEmpty && family != .accessoryCircular {
          Text(entry.show)
            .font(.caption2)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
        if family != .accessoryCircular {
          ProgressView(value: entry.progress)
            .progressViewStyle(.linear)
            .tint(.blue)
        }
      } else {
        Text("Tap to listen")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding(10)
    .containerBackground(.fill, for: .widget)
    .widgetURL(URL(string: "applevis://podcasts"))
    .accessibilityLabel(
      entry.title.isEmpty || entry.title == "Nothing playing"
        ? "AppleVis. Nothing playing. Tap to open podcasts."
        : "AppleVis. \(entry.title) by \(entry.show). \(Int(entry.progress * 100))% played. \(entry.isPlaying ? "Playing." : "Paused.")"
    )
  }
}

struct UnreadWidgetView: View {
  let entry: UnreadEntry
  var body: some View {
    VStack(spacing: 4) {
      Image(systemName: "bubble.left.and.bubble.right.fill")
        .foregroundColor(.blue)
        .widgetAccentable()
      Text("\(entry.unreadCount)")
        .font(.title2.bold())
        .widgetAccentable()
      Text("Unread")
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .containerBackground(.fill, for: .widget)
    .widgetURL(URL(string: "applevis://forums?filter=Unread"))
    .accessibilityLabel(
      entry.unreadCount == 0
        ? "AppleVis Forums. No unread topics."
        : "AppleVis Forums. \(entry.unreadCount) unread topic\(entry.unreadCount == 1 ? "" : "s"). Tap to open."
    )
  }
}

// MARK: - Widget definitions

struct ContinueListeningWidget: Widget {
  let kind = "com.applevis.widget.continueListening"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ContinueListeningProvider()) { entry in
      ContinueListeningWidgetView(entry: entry)
    }
    .configurationDisplayName("Continue Listening")
    .description("Resume the latest AppleVis podcast episode.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
  }
}

struct UnreadForumsWidget: Widget {
  let kind = "com.applevis.widget.unreadForums"
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: UnreadProvider()) { entry in
      UnreadWidgetView(entry: entry)
    }
    .configurationDisplayName("Unread Forums")
    .description("Shows your unread AppleVis forum topic count.")
    .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
  }
}

// MARK: - iOS 18 Control Center controls

@available(iOS 18.0, *)
struct PodcastControlProvider: ControlValueProvider {
  var previewValue: Bool { false }
  func currentValue() async throws -> Bool {
    sharedDefaults?.bool(forKey: "isPlaying") ?? false
  }
}

@available(iOS 18.0, *)
struct TogglePodcastControlIntent: SetValueIntent {
  static var title: LocalizedStringResource = "Toggle AppleVis Podcast"
  static var openAppWhenRun: Bool = true

  @Parameter(title: "Playing")
  var value: Bool

  func perform() async throws -> some IntentResult {
    let action = value ? "play" : "pause"
    await UIApplication.shared.open(URL(string: "applevis://podcasts?action=\(action)")!)
    return .result()
  }
}

@available(iOS 18.0, *)
struct AppleVisPodcastControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(
      kind: "com.applevis.control.podcast",
      provider: PodcastControlProvider()
    ) { isPlaying in
      ControlWidgetToggle(
        "AppleVis Podcast",
        isOn: isPlaying,
        action: TogglePodcastControlIntent()
      ) { state in
        Label(
          state ? "Pause" : "Play",
          systemImage: state ? "pause.fill" : "play.fill"
        )
      }
    }
    .displayName("AppleVis Podcast")
    .description("Play or pause the current AppleVis podcast episode.")
  }
}

@available(iOS 18.0, *)
struct OpenForumsControlIntent: AppIntent {
  static var title: LocalizedStringResource = "Open AppleVis Forums"
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult {
    await UIApplication.shared.open(URL(string: "applevis://forums?filter=Unread")!)
    return .result()
  }
}

@available(iOS 18.0, *)
struct ForumsControlProvider: ControlValueProvider {
  var previewValue: Int { 0 }
  func currentValue() async throws -> Int {
    sharedDefaults?.integer(forKey: "unreadForumCount") ?? 0
  }
}

@available(iOS 18.0, *)
struct AppleVisForumsControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(
      kind: "com.applevis.control.forums",
      provider: ForumsControlProvider()
    ) { unreadCount in
      ControlWidgetButton(
        "AppleVis Forums",
        action: OpenForumsControlIntent()
      ) {
        Label(
          unreadCount > 0 ? "\(unreadCount) unread" : "Forums",
          systemImage: "bubble.left.and.bubble.right.fill"
        )
      }
    }
    .displayName("AppleVis Forums")
    .description("Open AppleVis unread forum topics.")
  }
}

// MARK: - Bundle

@main
struct AppleVisWidgetBundle: WidgetBundle {
  var body: some Widget {
    ContinueListeningWidget()
    UnreadForumsWidget()
    if #available(iOS 18.0, *) {
      AppleVisPodcastControl()
      AppleVisForumsControl()
    }
  }
}
