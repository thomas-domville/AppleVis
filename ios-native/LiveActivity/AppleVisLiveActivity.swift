// Live Activity + Dynamic Island for podcast playback.
// After prebuild, in Xcode: File > New > Target > Widget Extension
// Check "Include Live Activity". Name it "AppleVisLiveActivity".
// Copy this file into that target.

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Attributes (written once when activity starts)

public struct AppleVisPodcastAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var isPlaying: Bool
    var positionSeconds: Double
    var durationSeconds: Double
    var speed: Double
    var chapterTitle: String
  }
  public var episodeTitle: String
  public var showTitle: String
  public var episodeId: String
}

// MARK: - Helpers

private func formatTime(_ seconds: Double) -> String {
  let m = Int(seconds) / 60
  let s = Int(seconds) % 60
  return String(format: "%d:%02d", m, s)
}

// MARK: - Lock Screen expanded view

struct LiveActivityLockScreenView: View {
  let context: ActivityViewContext<AppleVisPodcastAttributes>
  private var progress: Double {
    guard context.state.durationSeconds > 0 else { return 0 }
    return context.state.positionSeconds / context.state.durationSeconds
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Image(systemName: "radio.fill").foregroundColor(.blue)
        VStack(alignment: .leading, spacing: 1) {
          Text(context.attributes.episodeTitle)
            .font(.caption.weight(.semibold)).lineLimit(1)
          Text(context.attributes.showTitle)
            .font(.caption2).foregroundColor(.secondary).lineLimit(1)
        }
        Spacer()
        Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
          .foregroundColor(.primary)
      }
      if !context.state.chapterTitle.isEmpty {
        Text(context.state.chapterTitle)
          .font(.caption2).foregroundColor(.blue).lineLimit(1)
      }
      ProgressView(value: progress)
        .progressViewStyle(.linear)
        .tint(.blue)
      HStack {
        Text(formatTime(context.state.positionSeconds)).font(.caption2).foregroundColor(.secondary)
        Spacer()
        Text(formatTime(context.state.durationSeconds)).font(.caption2).foregroundColor(.secondary)
      }
    }
    .padding()
    .activityBackgroundTint(.black.opacity(0.7))
  }
}

// MARK: - Live Activity widget

@available(iOS 16.2, *)
struct AppleVisLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: AppleVisPodcastAttributes.self) { context in
      LiveActivityLockScreenView(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "radio.fill").foregroundColor(.blue).padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(alignment: .leading, spacing: 2) {
            Text(context.attributes.episodeTitle)
              .font(.caption.bold()).lineLimit(1)
            Text(context.attributes.showTitle)
              .font(.caption2).foregroundColor(.secondary).lineLimit(1)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
            .foregroundColor(.primary).padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
          let progress = context.state.durationSeconds > 0
            ? context.state.positionSeconds / context.state.durationSeconds : 0
          ProgressView(value: progress).progressViewStyle(.linear).tint(.blue).padding(.horizontal)
        }
      } compactLeading: {
        Image(systemName: "radio.fill").foregroundColor(.blue).font(.caption)
      } compactTrailing: {
        Image(
          systemName: context.state.isPlaying ? "waveform" : "pause.circle.fill"
        ).foregroundColor(.blue).font(.caption)
      } minimal: {
        Image(systemName: "radio.fill").foregroundColor(.blue)
      }
      .keylineTint(.blue)
    }
  }
}
