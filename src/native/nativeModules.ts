import { NativeModules } from 'react-native';
import { logDev } from '../utils/logger';

// ─── Apple Intelligence (Foundation Models) ──────────────────────────────────

/**
 * Returns true when the device supports Apple Intelligence AND the user has
 * enabled it in Settings → Apple Intelligence & Siri.
 *
 * Native side: ios-native/Intelligence/AppleVisIntelligence.swift
 * Requires iOS 26+ (FoundationModels is a public API from iOS 26).
 *
 * Returns false in all cases where AI cannot run:
 *   - Native module not yet built (Expo Go / simulator)
 *   - Device predates iPhone 15 Pro
 *   - User has not enabled Apple Intelligence in Settings
 *   - iOS version < 26.0
 */
export function isAppleIntelligenceAvailable(): boolean {
  return NativeModules.AppleVisIntelligence?.isAvailable ?? false;
}

/**
 * Sends a prompt to the on-device Foundation Models LLM and returns the
 * response text. Returns null when Apple Intelligence is unavailable.
 *
 * Native side: ios-native/Intelligence/AppleVisIntelligence.swift
 * All processing is on-device. No data leaves the device.
 */
export async function runFoundationModel(prompt: string): Promise<string | null> {
  return NativeModules.AppleVisIntelligence?.respond(prompt) ?? null;
}

// ─── Live Activities ──────────────────────────────────────────────────────────

export type PodcastLiveActivityState = {
  episodeTitle: string;
  showTitle: string;
  episodeId: string;
  isPlaying: boolean;
  position: number;       // seconds
  duration: number;       // seconds
  speed?: number;         // default 1.0
  chapterTitle?: string;
};

/**
 * Starts a Live Activity on the Dynamic Island and Lock Screen showing
 * the currently-playing podcast episode with playback controls.
 *
 * Native side (Swift, requires iOS 16.2+, ActivityKit):
 *
 *   import ActivityKit
 *
 *   struct PodcastAttributes: ActivityAttributes {
 *     struct ContentState: Codable, Hashable {
 *       var episodeTitle: String
 *       var showTitle: String
 *       var isPlaying: Bool
 *       var position: Double
 *       var duration: Double
 *     }
 *     var artworkUrl: String?
 *   }
 *
 *   // Start:
 *   let attr  = PodcastAttributes(artworkUrl: state.artworkUrl)
 *   let cs    = PodcastAttributes.ContentState(...)
 *   let activity = try Activity<PodcastAttributes>.request(
 *     attributes: attr,
 *     contentState: cs,
 *     pushType: nil
 *   )
 *
 *   // Update:
 *   await activity.update(using: newContentState)
 *
 *   // End:
 *   await activity.end(dismissalPolicy: .immediate)
 *
 * Info.plist: NSSupportsLiveActivities = YES
 */
export function startPodcastLiveActivity(state: PodcastLiveActivityState): void {
  NativeModules.AppleVisLiveActivityController?.start(state);
}

export function updatePodcastLiveActivity(state: PodcastLiveActivityState): void {
  NativeModules.AppleVisLiveActivityController?.update(state);
}

export function endPodcastLiveActivity(): void {
  NativeModules.AppleVisLiveActivityController?.end();
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

export type WidgetSnapshot = {
  nowPlayingTitle: string;
  nowPlayingShow: string;
  nowPlayingProgress: number;  // 0.0–1.0
  unreadForumCount: number;
  savedItemCount: number;
};

/**
 * Writes widget data to the shared App Group container so the WidgetKit
 * extension can read it and refresh the home/lock screen widgets.
 *
 * Planned widgets:
 *   • Small  — unread topic count badge
 *   • Medium — latest podcast episode + unread count
 *   • Large  — "What's New" digest (new topics, new episodes, updated apps)
 *   • Lock Screen — unread count or now-playing episode title
 *
 * Native side (Swift, requires WidgetKit + App Group entitlement):
 *
 *   import WidgetKit
 *
 *   // Write to shared container:
 *   let defaults = UserDefaults(suiteName: "group.com.applevis.app")
 *   defaults?.set(snapshot.unreadTopicCount, forKey: "unreadTopicCount")
 *   defaults?.set(snapshot.latestPodcastTitle, forKey: "latestPodcastTitle")
 *
 *   // Tell WidgetKit to reload:
 *   WidgetCenter.shared.reloadAllTimelines()
 *
 * Entitlements: com.apple.security.application-groups = ["group.com.applevis.app"]
 */
export function updateWidgetSnapshot(snapshot: WidgetSnapshot): void {
  NativeModules.AppleVisWidgetDataWriter?.update(snapshot);
}

// ─── Focus Filter ─────────────────────────────────────────────────────────────

export type FocusFilterConfig = {
  /** Which notification types to allow through during this Focus. */
  allowedCategories: ('forumReply' | 'mention' | 'newEpisode' | 'appUpdate')[];
};

/**
 * Registers an App Intent that appears in Settings → Focus → [mode] → App Filters,
 * letting users choose which AppleVis notification categories break through
 * their Focus mode (e.g. allow Mentions but mute everything else).
 *
 * Native side (Swift, requires AppIntents + UserNotifications):
 *
 *   import AppIntents
 *
 *   struct AppleVisFocusFilterIntent: SetFocusFilterIntent {
 *     static var title: LocalizedStringResource = "AppleVis"
 *     static var description = IntentDescription(
 *       "Choose which AppleVis notifications to allow during Focus."
 *     )
 *
 *     @Parameter(title: "Allowed notification categories")
 *     var allowedCategories: [NotificationCategory]
 *
 *     func perform() async throws -> some IntentResult {
 *       // Persist allowedCategories; use in UNUserNotificationCenter delegate
 *       // to filter outgoing notifications.
 *       return .result()
 *     }
 *   }
 *
 * Info.plist: no extra keys needed beyond existing notification entitlements.
 */
export function registerFocusFilter(_config: FocusFilterConfig): void {
  logDev('NativeModules', 'registerFocusFilter — native module not yet built.');
}

// ─── Share Extension ──────────────────────────────────────────────────────────

export type SharedItem = {
  url?: string;
  text?: string;
  title?: string;
};

/**
 * Receives items shared into AppleVis from other apps (Safari, Mail, etc.).
 * The Share Extension target handles the incoming item and deep-links into
 * the main app to save, discuss, or look up the content.
 *
 * Use cases:
 *   • Share a website URL → save it as an AppleVis resource / start a forum topic
 *   • Share text → pre-fill a forum reply
 *   • Share an App Store link → look up the app on AppleVis
 *
 * Native side (Swift — separate Xcode target: NSExtension, NSExtensionPointIdentifier
 *              = com.apple.share-services):
 *
 *   class ShareViewController: UIViewController {
 *     override func viewDidLoad() {
 *       guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
 *             let provider = item.attachments?.first else { return }
 *
 *       if provider.hasItemConformingToTypeIdentifier("public.url") {
 *         provider.loadItem(forTypeIdentifier: "public.url") { url, _ in
 *           // Deep-link: applevis://share?url=...
 *           let appURL = URL(string: "applevis://share?url=\(url)")!
 *           self.extensionContext?.open(appURL)
 *         }
 *       }
 *     }
 *   }
 *
 * The main app handles applevis://share?url= in its URL scheme handler.
 * App Group entitlement needed to pass data between extension and main app.
 */
export function handleIncomingShare(_item: SharedItem): void {
  logDev('NativeModules', 'handleIncomingShare — native module not yet built.', _item);
}

/**
 * Reads and clears the pending App Store URL written by the iOS Share Extension.
 *
 * When the user shares an App Store link from Safari/App Store app, the Share
 * Extension writes the URL to App Group UserDefaults (suite: group.com.applevis.app,
 * key: pendingAppShareURL) before opening the applevis://submit-app?url= deep link.
 * This function is a belt-and-suspenders fallback: called on app foreground to
 * catch any URL that slipped through before the Linking listener was ready.
 *
 * Returns null if no pending URL is waiting.
 *
 * Native side (AppleVisAppShare.swift — ios-native/AppShare/):
 *
 *   @objc func consumePendingURL(
 *     _ resolve: @escaping RCTPromiseResolveBlock,
 *       reject:  @escaping RCTPromiseRejectBlock
 *   ) {
 *     let defaults = UserDefaults(suiteName: "group.com.applevis.app")
 *     let url = defaults?.string(forKey: "pendingAppShareURL")
 *     defaults?.removeObject(forKey: "pendingAppShareURL")
 *     resolve(url)
 *   }
 *
 * Entitlement needed (main app target):
 *   com.apple.security.application-groups = ["group.com.applevis.app"]
 */
export async function consumePendingShareURL(): Promise<string | null> {
  logDev('NativeModules', 'consumePendingShareURL — native module not yet built.');
  return null;
}

// ─── Vision Framework — Image Description ────────────────────────────────────

/**
 * Generates an accessibility description for an image URL using the on-device
 * Vision framework. Result should be set as the image's accessibilityLabel.
 *
 * Use cases:
 *   • Screenshots embedded in forum posts
 *   • App store artwork in the app directory
 *   • Any UIImage the user encounters without an existing alt-text
 *
 * Native side (Swift, requires iOS 15+ VNRecognizeTextRequest / VNGenerateImageFeaturePrintRequest
 *              + iOS 18 Visual Intelligence APIs):
 *
 *   import Vision
 *
 *   func describeImage(url: URL) async throws -> String {
 *     // Download image
 *     let (data, _) = try await URLSession.shared.data(from: url)
 *     guard let cgImage = UIImage(data: data)?.cgImage else { return "" }
 *
 *     // iOS 18+: VNGenerateImageCaptionRequest (if available)
 *     if #available(iOS 18.0, *) {
 *       let request = VNGenerateImageCaptionRequest()
 *       let handler = VNImageRequestHandler(cgImage: cgImage)
 *       try handler.perform([request])
 *       return request.results?.first?.caption ?? ""
 *     }
 *
 *     // Fallback: OCR text recognition for screenshots
 *     let textRequest = VNRecognizeTextRequest()
 *     textRequest.recognitionLevel = .accurate
 *     let textHandler = VNImageRequestHandler(cgImage: cgImage)
 *     try textHandler.perform([textRequest])
 *     let text = textRequest.results?
 *       .compactMap { $0.topCandidates(1).first?.string }
 *       .joined(separator: " ") ?? ""
 *     return text.isEmpty ? "Image" : "Screenshot containing: \(text)"
 *   }
 *
 * Privacy: all processing is on-device. No image data leaves the device.
 * Info.plist: no extra keys needed (Vision is a system framework).
 */
export async function describeImage(_imageUrl: string): Promise<string | null> {
  logDev('NativeModules', 'describeImage — native module not yet built.');
  return null;
}

// ─── Handoff / NSUserActivity ─────────────────────────────────────────────────

export type HandoffActivity = {
  /** Reverse-DNS activity type, must be listed in Info.plist NSUserActivityTypes. */
  activityType: string;
  /** Human-readable title shown on the receiving device. */
  title: string;
  /** Corresponding applevis.com URL — used as Handoff fallback on Mac when app not installed. */
  webpageURL?: string;
  /** Arbitrary key-value payload passed to the receiving device. */
  userInfo?: Record<string, string>;
};

/**
 * Advertises the user's current activity to nearby Apple devices via Handoff.
 * The receiving device shows an app-switcher icon; tapping it opens the app
 * and resumes from where the user left off.
 *
 * Native side (Swift, must run on main thread):
 *
 *   let activity = NSUserActivity(activityType: activity.activityType)
 *   activity.title       = activity.title
 *   activity.isEligibleForHandoff = true
 *   activity.isEligibleForSearch  = true          // also indexes in Spotlight
 *   if let urlStr = activity.webpageURL,
 *      let url   = URL(string: urlStr) {
 *     activity.webpageURL = url
 *   }
 *   activity.userInfo = activity.userInfo as [AnyHashable: Any]?
 *   activity.becomeCurrent()
 *
 * To receive on the destination device, implement in AppDelegate:
 *   func application(_ app, continue userActivity: NSUserActivity, ...) -> Bool
 *   Then deep-link using userActivity.activityType and userActivity.userInfo.
 *
 * Info.plist: NSUserActivityTypes array (already in app.json).
 * Entitlements: com.apple.developer.associated-domains (already in app.json).
 */
export function advertiseHandoff(_activity: HandoffActivity): void {
  logDev('NativeModules', 'advertiseHandoff — native module not yet built.', _activity.activityType);
}

/**
 * Resigns the current NSUserActivity so Handoff no longer shows on nearby devices.
 * Call when the user navigates away from the screen or the app backgrounds.
 *
 * Native side:
 *   currentActivity?.resignCurrent()
 */
export function resignHandoff(): void {
  logDev('NativeModules', 'resignHandoff — native module not yet built.');
}

// ─── Keyboard Shortcuts (iPadOS hardware keyboard) ────────────────────────────

export type KeyboardShortcut = {
  /** The key letter, e.g. "f" for ⌘F. */
  input: string;
  modifierFlags: ('command' | 'shift' | 'alternate' | 'control')[];
  /** Description shown in the keyboard shortcut overlay (hold ⌘). */
  discoverabilityTitle: string;
  /** Identifier used to dispatch the action in JS. */
  identifier: string;
};

/**
 * Registers application-level keyboard shortcuts visible in the iPadOS
 * keyboard shortcut overlay (hold ⌘ while app is in focus).
 *
 * Native side (Swift, UIKeyCommand):
 *
 *   override var keyCommands: [UIKeyCommand]? {
 *     return shortcuts.map { s in
 *       UIKeyCommand(
 *         title: s.discoverabilityTitle,
 *         action: #selector(handleKeyCommand(_:)),
 *         input: s.input,
 *         modifierFlags: s.modifierFlags
 *       )
 *     }
 *   }
 *
 *   @objc func handleKeyCommand(_ command: UIKeyCommand) {
 *     // Send identifier back to JS via event emitter
 *     sendEvent("onKeyCommand", ["identifier": command.title])
 *   }
 *
 * Subscribe to the "onKeyCommand" event on the JS side to handle shortcuts.
 *
 * Default shortcuts to register:
 *   ⌘F  — Search
 *   ⌘R  — Refresh
 *   ⌘1  — Forums tab
 *   ⌘2  — Apps tab
 *   ⌘3  — Podcasts tab
 *   ⌘4  — Resources tab
 *   ⌘,  — Settings
 */
export function registerKeyboardShortcuts(_shortcuts: KeyboardShortcut[]): void {
  logDev('NativeModules', 'registerKeyboardShortcuts — native module not yet built.', _shortcuts.length);
}

// ─── Increase Contrast (iOS Accessibility) ────────────────────────────────────

/**
 * Returns true when the user has enabled "Increase Contrast" in
 * Settings → Accessibility → Display & Text Size.
 *
 * React Native does not expose UIAccessibilityIsHighContrastEnabled() directly.
 *
 * Native side (Swift):
 *   UIAccessibility.isHighContrastEnabled  // iOS 13+
 *   NotificationCenter.default.addObserver(
 *     forName: UIAccessibility.highContrastStatusDidChangeNotification, ...
 *   )
 *
 * Wire as an event emitter so the JS layer can subscribe via a hook.
 */
export async function isIncreaseContrastEnabled(): Promise<boolean> {
  logDev('NativeModules', 'isIncreaseContrastEnabled — native module not yet built.');
  return false;
}

// ─── Natural Language Search Enhancement ─────────────────────────────────────

/**
 * Expands a natural language search query into structured search terms.
 * E.g. "recent VoiceOver tips" → ["VoiceOver", "accessibility", "tips", "tutorial"]
 *
 * Native side (Swift, NaturalLanguage framework):
 *
 *   import NaturalLanguage
 *
 *   func expandQuery(_ query: String) -> [String] {
 *     let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
 *     tagger.string = query
 *     var terms: [String] = []
 *     tagger.enumerateTags(in: query.startIndex..<query.endIndex,
 *                          unit: .word, scheme: .lexicalClass) { tag, range in
 *       if tag != .determiner && tag != .preposition {
 *         terms.append(String(query[range]))
 *       }
 *       return true
 *     }
 *     return terms
 *   }
 *
 * Can also use Foundation Models to suggest related search terms.
 */
export async function expandSearchQuery(_query: string): Promise<string[]> {
  logDev('NativeModules', 'expandSearchQuery — native module not yet built.');
  return [_query];
}

// ─── Spotlight ────────────────────────────────────────────────────────────────

export type SpotlightItem = {
  id: string;
  title: string;
  description: string;
  contentType: 'forumTopic' | 'podcast' | 'app' | 'resource';
  url: string;
};

export function indexSpotlightItems(items: SpotlightItem[]): Promise<void> {
  return NativeModules.AppleVisSpotlight?.index(items) ?? Promise.resolve();
}

export function deindexSpotlightItem(id: string): Promise<void> {
  return NativeModules.AppleVisSpotlight?.deindex(id) ?? Promise.resolve();
}

export function deindexAllSpotlight(): Promise<void> {
  return NativeModules.AppleVisSpotlight?.deindexAll() ?? Promise.resolve();
}

// ─── Now Playing info (lock screen / Control Center) ─────────────────────────

export type NowPlayingInfo = {
  title: string;
  artist: string;
  artworkUrl?: string;
  duration: number;
  elapsedTime: number;
  playbackRate: number;
};

/**
 * Pushes episode metadata to MPNowPlayingInfoCenter so the lock screen,
 * Control Center, and AirPlay receivers display the correct title, show name,
 * artwork and scrubber position.
 *
 * Artwork is fetched asynchronously by the native layer using the URL;
 * passing null skips artwork (title + artist still appear immediately).
 */
export function updateNowPlayingInfo(info: NowPlayingInfo): void {
  NativeModules.AppleVisNowPlaying?.updateNowPlaying(
    info.title,
    info.artist,
    info.artist,              // albumTitle = show name
    info.duration,
    info.elapsedTime,
    info.playbackRate,
    info.playbackRate > 0,    // isPlaying
    info.artworkUrl ?? null,  // native side fetches image async from this URL
  );
}

/** Clears Now Playing info when playback ends or the player is unloaded. */
export function clearNowPlayingInfo(): void {
  NativeModules.AppleVisNowPlaying?.clearNowPlaying();
}

/**
 * Registers MPRemoteCommandCenter handlers so play/pause/skip work from
 * the lock screen, Control Center, AirPods double-tap, and CarPlay.
 * Pass callbacks that call the corresponding player methods.
 */
export function setupRemoteCommands(opts: {
  onPlay:            () => void;
  onPause:           () => void;
  onTogglePlayPause: () => void;
  onSkipBackward:    () => void;
  onSkipForward:     () => void;
  onSeek:            (seconds: number) => void;
  /** Called when the user taps the next-track button (lock screen / AirPods). */
  onNextTrack?:      () => void;
  /** Called when the user taps the previous-track button. */
  onPreviousTrack?:  () => void;
  skipBackInterval:    number;
  skipForwardInterval: number;
}): void {
  NativeModules.AppleVisNowPlaying?.setupRemoteCommands(
    () => opts.onPlay(),
    () => opts.onPause(),
    () => opts.onTogglePlayPause(),
    () => opts.onSkipBackward(),
    () => opts.onSkipForward(),
    ([pos]: number[]) => opts.onSeek(pos),
    () => opts.onNextTrack?.(),
    () => opts.onPreviousTrack?.(),
    opts.skipBackInterval,
    opts.skipForwardInterval,
  );
}

// ─── AudioEffects (AVAudioEngine — voice boost + trim silence) ────────────────

/**
 * Applies voice boost equalisation to enhance speech clarity and
 * normalises volume across episodes. Uses AVAudioEngine with an
 * AVAudioUnitEQ targeting the 300 Hz–4 kHz speech frequency range.
 *
 * Native side: ios-native/AudioEffects/AppleVisAudioEffects.swift
 */
export function setVoiceBoostEnabled(enabled: boolean): void {
  NativeModules.AppleVisAudioEffects?.setVoiceBoost(enabled);
}

/**
 * Enables or disables silence trimming. The native layer monitors the
 * audio level via an AVAudioMixerNode tap; when the signal drops below
 * a threshold for ≥ 200 ms it advances the playback position by 0.5 s.
 *
 * Native side: ios-native/AudioEffects/AppleVisAudioEffects.swift
 */
export function setTrimSilenceEnabled(enabled: boolean): void {
  NativeModules.AppleVisAudioEffects?.setTrimSilence(enabled);
}

// ─── CarPlay ──────────────────────────────────────────────────────────────────

/**
 * Pushes the latest episode list to the CarPlay browsable template so
 * the in-car display reflects current podcast content.
 *
 * Call after the feed loads or refreshes.
 *
 * Native side: ios-native/CarPlay/AppleVisCarPlayDelegate.swift
 */
export type CarPlayEpisodeItem = {
  id: string;
  title: string;
  showTitle: string;
  duration: number;
  isDownloaded: boolean;
};

export function updateCarPlayEpisodes(episodes: CarPlayEpisodeItem[]): void {
  NativeModules.AppleVisCarPlay?.updateEpisodes(episodes);
}

// ─── AirPlay / Audio Route Picker ────────────────────────────────────────────

/**
 * Presents the system AirPlay / Bluetooth audio output route picker sheet.
 * Allows users to switch playback to AirPods, hearing aids, Apple TV, etc.
 *
 * Native side (Swift, AVKit):
 *   AVRoutePickerView — system picker for audio/video output routes.
 *   Works by briefly attaching a hidden AVRoutePickerView to the key window
 *   and triggering its internal UIButton programmatically.
 *
 * iOS only — no-op on Android.
 */
export function showAirPlayPicker(): void {
  NativeModules.AppleVisRoutePicker?.showPicker();
}
