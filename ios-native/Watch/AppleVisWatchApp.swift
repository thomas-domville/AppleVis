// watchOS app for AppleVis.
// After prebuild, in Xcode: File > New > Target > watchOS App
// Name it "AppleVisWatch". Copy this file into that target.
// Add WatchConnectivity.framework to the watch target.

import SwiftUI
import WatchKit
import WatchConnectivity

// MARK: - App entry point

@main
struct AppleVisWatchApp: App {
  @StateObject private var model = WatchModel()

  var body: some Scene {
    WindowGroup {
      ContentView().environmentObject(model)
    }
  }
}

// MARK: - Root view

struct ContentView: View {
  @EnvironmentObject var model: WatchModel

  var body: some View {
    NavigationStack {
      List {
        // Now Playing section
        Section("Now Playing") {
          if let ep = model.nowPlaying {
            NowPlayingRow(episode: ep, isPlaying: model.isPlaying) {
              model.sendAction(model.isPlaying ? "pause" : "play")
            }
          } else {
            Label("Nothing playing", systemImage: "radio").font(.caption)
          }
        }

        // Quick actions
        Section("Quick Actions") {
          Button {
            model.sendAction("skipBack")
          } label: {
            Label("Skip Back 15s", systemImage: "gobackward.15")
          }
          Button {
            model.sendAction("skipForward")
          } label: {
            Label("Skip Forward 30s", systemImage: "goforward.30")
          }
        }

        // Forum summary
        Section("Forums") {
          if model.unreadCount > 0 {
            Label("\(model.unreadCount) unread topics", systemImage: "bubble.left.and.bubble.right.fill")
              .font(.caption)
          } else {
            Label("All caught up", systemImage: "checkmark.circle").font(.caption)
          }
        }
      }
      .navigationTitle("AppleVis")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(action: model.requestState) {
            Image(systemName: "arrow.clockwise")
          }
        }
      }
    }
    .onAppear { model.requestState() }
  }
}

// MARK: - Now Playing row

struct NowPlayingRow: View {
  let episode: WatchEpisode
  let isPlaying: Bool
  let onToggle: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(episode.title).font(.headline).lineLimit(2)
      Text(episode.showTitle).font(.caption).foregroundColor(.secondary)
      HStack(spacing: 12) {
        Button(action: onToggle) {
          Image(systemName: isPlaying ? "pause.fill" : "play.fill")
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)

        ProgressView(value: episode.progress)
          .tint(.blue)
      }
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Data model

struct WatchEpisode: Identifiable, Codable {
  let id: String
  let title: String
  let showTitle: String
  let progress: Double  // 0.0 – 1.0
}

// MARK: - WatchConnectivity model

@MainActor
final class WatchModel: NSObject, ObservableObject, WCSessionDelegate {
  @Published var nowPlaying: WatchEpisode? = nil
  @Published var isPlaying: Bool = false
  @Published var unreadCount: Int = 0

  private let session = WCSession.default

  override init() {
    super.init()
    if WCSession.isSupported() {
      session.delegate = self
      session.activate()
    }
  }

  func sendAction(_ action: String) {
    guard session.isReachable else { return }
    session.sendMessage(["action": action], replyHandler: nil)
  }

  func requestState() {
    guard session.isReachable else { return }
    session.sendMessage(["action": "requestState"], replyHandler: { reply in
      Task { @MainActor in self.applyState(reply) }
    })
  }

  private func applyState(_ msg: [String: Any]) {
    if let title = msg["episodeTitle"] as? String,
       let show = msg["showTitle"] as? String,
       let id = msg["episodeId"] as? String,
       let progress = msg["progress"] as? Double {
      nowPlaying = WatchEpisode(id: id, title: title, showTitle: show, progress: progress)
    }
    if let playing = msg["isPlaying"] as? Bool { isPlaying = playing }
    if let unread = msg["unreadCount"] as? Int { unreadCount = unread }
  }

  // MARK: WCSessionDelegate

  nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}

  nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    Task { @MainActor in self.applyState(message) }
  }
}
