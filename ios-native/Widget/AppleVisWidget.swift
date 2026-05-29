// WidgetKit extension for AppleVis.
// After prebuild, in Xcode: File > New > Target > Widget Extension
// Name it "AppleVisWidget", copy this file into that target.
// Set App Group to group.com.applevis.app in both targets.

import WidgetKit
import SwiftUI

private let sharedDefaults = UserDefaults(suiteName: "group.com.applevis.app")

// MARK: - Data model written by the main app into shared UserDefaults

struct WidgetData {
  static var nowPlayingTitle: String { sharedDefaults?.string(forKey: "nowPlayingTitle") ?? "" }
  static var nowPlayingShow: String  { sharedDefaults?.string(forKey: "nowPlayingShow") ?? "" }
  static var nowPlayingProgress: Double { sharedDefaults?.double(forKey: "nowPlayingProgress") ?? 0 }
  static var unreadCount: Int { sharedDefaults?.integer(forKey: "unreadForumCount") ?? 0 }
  static var savedCount: Int { sharedDefaults?.integer(forKey: "savedItemCount") ?? 0 }
}

// MARK: - Timeline entries

struct ContinueListeningEntry: TimelineEntry {
  let date: Date
  let title: String
  let show: String
  let progress: Double
}

struct UnreadEntry: TimelineEntry {
  let date: Date
  let unreadCount: Int
}

// MARK: - Providers

struct ContinueListeningProvider: TimelineProvider {
  func placeholder(in context: Context) -> ContinueListeningEntry {
    ContinueListeningEntry(date: .now, title: "AppleVis Podcast", show: "AppleVis", progress: 0.3)
  }
  func getSnapshot(in context: Context, completion: @escaping (ContinueListeningEntry) -> Void) {
    completion(placeholder(in: context))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<ContinueListeningEntry>) -> Void) {
    let entry = ContinueListeningEntry(
      date: .now,
      title: WidgetData.nowPlayingTitle.isEmpty ? "Nothing playing" : WidgetData.nowPlayingTitle,
      show: WidgetData.nowPlayingShow,
      progress: WidgetData.nowPlayingProgress
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

// MARK: - Widget views

struct ContinueListeningWidgetView: View {
  let entry: ContinueListeningEntry
  @Environment(\.widgetFamily) var family

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Image(systemName: "radio.fill").foregroundColor(.blue).font(.title3)
        Spacer()
      }
      Spacer()
      if !entry.title.isEmpty {
        Text(entry.title).font(.caption.weight(.semibold)).lineLimit(2)
        if family != .accessoryCircular {
          ProgressView(value: entry.progress).progressViewStyle(.linear).tint(.blue)
        }
      } else {
        Text("Tap to listen").font(.caption).foregroundColor(.secondary)
      }
    }
    .padding(10)
    .containerBackground(.fill, for: .widget)
  }
}

struct UnreadWidgetView: View {
  let entry: UnreadEntry
  var body: some View {
    VStack(spacing: 4) {
      Image(systemName: "bubble.left.and.bubble.right.fill").foregroundColor(.blue)
      Text("\(entry.unreadCount)").font(.title2.bold())
      Text("Unread").font(.caption2).foregroundColor(.secondary)
    }
    .containerBackground(.fill, for: .widget)
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
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
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

// MARK: - Bundle

@main
struct AppleVisWidgetBundle: WidgetBundle {
  var body: some Widget {
    ContinueListeningWidget()
    UnreadForumsWidget()
  }
}
