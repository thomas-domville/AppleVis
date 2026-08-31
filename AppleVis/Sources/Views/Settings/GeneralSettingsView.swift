import SwiftUI

/// General AppleVis behavior — moved out of Accessibility, where it had
/// accumulated by historical accident rather than because any of it is
/// actually about VoiceOver, Dynamic Type, or anything else accessibility-
/// specific. A sighted user is just as likely to want Home quieter, tips
/// off, or their regular browser — none of that is an accessibility
/// concern the way VoiceOver Detail Level (left behind in Accessibility)
/// genuinely is. Requested directly.
struct GeneralSettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        Form {
            Section {
                Text("General AppleVis behavior — how Home greets you, what pops up along the way, and how links open. Nothing here is accessibility-specific; iOS's own accessibility settings live in Settings > Accessibility, and AppleVis-only accessibility controls like VoiceOver Detail Level live there too.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityFocused($isTitleFocused)
            }

            Section("Home") {
                Picker("Home Startup Behavior", selection: $preferences.homeStartupBehavior) {
                    ForEach(HomeStartupBehavior.allCases) { behavior in
                        Text(behavior.displayName).tag(behavior)
                    }
                }
                .accessibilityHint(String(localized: "Controls how much spoken announcement Home produces when you open or return to it."))
                .accessibilityAdjustableAction { direction in
                    guard let idx = HomeStartupBehavior.allCases.firstIndex(of: preferences.homeStartupBehavior) else { return }
                    switch direction {
                    case .increment:
                        preferences.homeStartupBehavior = HomeStartupBehavior.allCases[(idx + 1) % HomeStartupBehavior.allCases.count]
                    case .decrement:
                        preferences.homeStartupBehavior = HomeStartupBehavior.allCases[(idx - 1 + HomeStartupBehavior.allCases.count) % HomeStartupBehavior.allCases.count]
                    @unknown default: break
                    }
                }
                Text("What Home says out loud when you open or return to it. Quiet: nothing spoken. Helpful: a short spoken welcome. Detailed: that same welcome, plus an AI-generated summary of what's new since your last visit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Previously declared and shown in Settings but never
                // actually read anywhere — flipping it silently did
                // nothing. Now genuinely independent from Home Startup
                // Behavior above: that controls what's *spoken*, this
                // controls whether the *visual* new-activity card shows up
                // in the Home feed at all. Reported directly.
                Toggle("Welcome Summary", isOn: $preferences.welcomeSummaryEnabled)
                    .accessibilityHint(String(localized: "Shows a dismissable card on Home summarizing new activity since your last visit."))
                Text("The dismissable card on Home listing what's new since you were last here — separate from Home Startup Behavior above, which is about what's spoken, not what's shown.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Search") {
                Toggle("Auto-Focus Search Field", isOn: $preferences.searchAutoFocusEnabled)
                    .accessibilityHint(String(localized: "Automatically focuses and raises the keyboard when you open Search."))
                Text("Raises the keyboard the moment you open Search, so you can start typing right away.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Web Links") {
                Text("Controls what happens when you tap a web link anywhere in the app — App Store pages, social links, legal pages, Open in Browser actions, and more. In-App Browser keeps you here without leaving AppleVis; Default Browser hands the link to Safari (or whatever browser you've set as default), useful for your saved bookmarks, extensions, or signed-in sessions there.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Web Links", selection: $preferences.webBrowsingMode) {
                    ForEach(WebBrowsingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityHint(String(localized: "Controls whether web links open inside AppleVis or in your default browser."))
                .accessibilityAdjustableAction { direction in
                    guard let idx = WebBrowsingMode.allCases.firstIndex(of: preferences.webBrowsingMode) else { return }
                    switch direction {
                    case .increment:
                        preferences.webBrowsingMode = WebBrowsingMode.allCases[(idx + 1) % WebBrowsingMode.allCases.count]
                    case .decrement:
                        preferences.webBrowsingMode = WebBrowsingMode.allCases[(idx - 1 + WebBrowsingMode.allCases.count) % WebBrowsingMode.allCases.count]
                    @unknown default: break
                    }
                }
            }

            Section("Tips") {
                Toggle("AppleVis Tips", isOn: $preferences.helpfulTipsEnabled)
                    .accessibilityHint(String(localized: "Shows short contextual tips and friendly reminders where they can save time."))
                Text("Short, friendly tips that pop up here and there — timed to save you a step, not to nag.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ResetToDefaultsButton {
                    preferences.homeStartupBehavior = .helpful
                    preferences.welcomeSummaryEnabled = true
                    preferences.searchAutoFocusEnabled = false
                    preferences.webBrowsingMode = .inApp
                    preferences.helpfulTipsEnabled = true
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }
}
