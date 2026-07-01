import Foundation
import MediaPlayer
import UIKit

// Bridge between the JS podcast player and MPRemoteCommandCenter / Now Playing.
// After prebuild: copy this file into the main Xcode target (ios/AppleVis/).
// Call from JS via NativeModules.AppleVisNowPlaying.

@objc(AppleVisNowPlaying)
class AppleVisNowPlaying: NSObject {

  @objc static func requiresMainQueueSetup() -> Bool { false }

  // ── Now Playing card ───────────────────────────────────────────────────────
  //
  // artworkURLString: optional HTTPS URL for the episode artwork.
  // The image is fetched asynchronously so the title/artist appear immediately
  // while the artwork loads in the background and is applied as a second update.

  @objc func updateNowPlaying(
    _ title: String,
    artist: String,
    albumTitle: String,
    duration: Double,
    position: Double,
    speed: Double,
    isPlaying: Bool,
    artworkURLString: String?
  ) {
    var info: [String: Any] = [
      MPMediaItemPropertyTitle:                    title,
      MPMediaItemPropertyArtist:                   artist,
      MPMediaItemPropertyAlbumTitle:               albumTitle,
      MPMediaItemPropertyPlaybackDuration:         duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
      MPNowPlayingInfoPropertyPlaybackRate:        isPlaying ? speed : 0.0,
      MPNowPlayingInfoPropertyDefaultPlaybackRate: speed,
    ]
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info

    // Fetch artwork asynchronously so the card appears immediately.
    guard let urlString = artworkURLString,
          let url = URL(string: urlString) else { return }

    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data, let image = UIImage(data: data) else { return }
      DispatchQueue.main.async {
        var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? info
        updated[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
      }
    }.resume()
  }

  // ── Remote command handlers ────────────────────────────────────────────────
  //
  // Registers lock screen / Control Center / CarPlay / AirPods controls.
  // onNextTrack / onPreviousTrack: pass empty arrays [] as placeholder; JS
  // uses them to advance to the next/previous episode.

  @objc func setupRemoteCommands(
    _ onPlay: @escaping RCTResponseSenderBlock,
    onPause: @escaping RCTResponseSenderBlock,
    onTogglePlayPause: @escaping RCTResponseSenderBlock,
    onSkipBackward: @escaping RCTResponseSenderBlock,
    onSkipForward: @escaping RCTResponseSenderBlock,
    onSeek: @escaping RCTResponseSenderBlock,
    onNextTrack: @escaping RCTResponseSenderBlock,
    onPreviousTrack: @escaping RCTResponseSenderBlock,
    skipBackInterval: Double,
    skipForwardInterval: Double
  ) {
    let c = MPRemoteCommandCenter.shared()

    c.playCommand.removeTarget(nil)
    c.pauseCommand.removeTarget(nil)
    c.togglePlayPauseCommand.removeTarget(nil)
    c.skipBackwardCommand.removeTarget(nil)
    c.skipForwardCommand.removeTarget(nil)
    c.changePlaybackPositionCommand.removeTarget(nil)
    c.nextTrackCommand.removeTarget(nil)
    c.previousTrackCommand.removeTarget(nil)

    c.playCommand.isEnabled = true
    c.playCommand.addTarget { _ in onPlay([]); return .success }

    c.pauseCommand.isEnabled = true
    c.pauseCommand.addTarget { _ in onPause([]); return .success }

    c.togglePlayPauseCommand.isEnabled = true
    c.togglePlayPauseCommand.addTarget { _ in onTogglePlayPause([]); return .success }

    c.skipBackwardCommand.isEnabled = true
    c.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipBackInterval)]
    c.skipBackwardCommand.addTarget { _ in onSkipBackward([]); return .success }

    c.skipForwardCommand.isEnabled = true
    c.skipForwardCommand.preferredIntervals = [NSNumber(value: skipForwardInterval)]
    c.skipForwardCommand.addTarget { _ in onSkipForward([]); return .success }

    c.changePlaybackPositionCommand.isEnabled = true
    c.changePlaybackPositionCommand.addTarget { event in
      if let e = event as? MPChangePlaybackPositionCommandEvent {
        onSeek([e.positionTime])
      }
      return .success
    }

    // Next / previous episode — shown on lock screen when a queue exists.
    c.nextTrackCommand.isEnabled = true
    c.nextTrackCommand.addTarget { _ in onNextTrack([]); return .success }

    c.previousTrackCommand.isEnabled = true
    c.previousTrackCommand.addTarget { _ in onPreviousTrack([]); return .success }
  }

  @objc func clearNowPlaying() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    // Disable next/prev so the buttons disappear from the lock screen.
    MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled     = false
    MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = false
  }
}
