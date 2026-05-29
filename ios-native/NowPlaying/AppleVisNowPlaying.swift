import Foundation
import MediaPlayer

// Bridge between the JS podcast player and MPRemoteCommandCenter / Now Playing.
// After prebuild: copy this file into the main Xcode target (ios/AppleVis/).
// Call from JS via NativeModules.AppleVisNowPlaying.

@objc(AppleVisNowPlaying)
class AppleVisNowPlaying: NSObject {

  @objc static func requiresMainQueueSetup() -> Bool { false }

  // Update the Lock Screen / Control Center Now Playing card
  @objc func updateNowPlaying(
    _ title: String,
    artist: String,
    albumTitle: String,
    duration: Double,
    position: Double,
    speed: Double,
    isPlaying: Bool,
    artworkData: NSData?
  ) {
    var info: [String: Any] = [
      MPMediaItemPropertyTitle: title,
      MPMediaItemPropertyArtist: artist,
      MPMediaItemPropertyAlbumTitle: albumTitle,
      MPMediaItemPropertyPlaybackDuration: duration,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
      MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? speed : 0.0,
      MPNowPlayingInfoPropertyDefaultPlaybackRate: speed,
    ]
    if let data = artworkData as Data?,
       let image = UIImage(data: data) {
      info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  // Register remote command handlers and call back into JS
  @objc func setupRemoteCommands(
    _ onPlay: @escaping RCTResponseSenderBlock,
    onPause: @escaping RCTResponseSenderBlock,
    onSkipBackward: @escaping RCTResponseSenderBlock,
    onSkipForward: @escaping RCTResponseSenderBlock,
    onSeek: @escaping RCTResponseSenderBlock,
    skipBackInterval: Double,
    skipForwardInterval: Double
  ) {
    let c = MPRemoteCommandCenter.shared()

    c.playCommand.isEnabled = true
    c.playCommand.addTarget { _ in onPlay([]); return .success }

    c.pauseCommand.isEnabled = true
    c.pauseCommand.addTarget { _ in onPause([]); return .success }

    c.togglePlayPauseCommand.isEnabled = true
    c.togglePlayPauseCommand.addTarget { _ in onPlay([]); return .success }

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
  }

  @objc func clearNowPlaying() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }
}
