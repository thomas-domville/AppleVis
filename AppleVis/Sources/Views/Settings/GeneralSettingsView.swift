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
                // Spells out what each option actually does, not just that
                // the picker "controls spoken announcement" — that generic
                // phrasing left a VoiceOver user with no way to tell Helpful
                // and Detailed apart without also finding and swiping to the
                // caption text below on its own. Reported directly: heard
                // the option name on focus and had no idea what it meant.
                .accessibilityHint(String(localized: "Quiet: nothing spoken. Helpful: a short spoken welcome. Detailed: that same welcome, plus an AI-generated summary of what's new since your last visit."))
                // A persistent .accessibilityValue() here (the PODCAST-06
                // fix, applied the same way in several other Settings
                // pickers) was added so swiping up/down would speak the new
                // option instead of just the "value changed" tone — but for
                // this Form-style Picker, VoiceOver already speaks the
                // selected option as part of its own built-in label/value on
                // every normal focus, so the persistent override piled a
                // second, identical readout on top of that ("Helpful.
                // Helpful."). Swapped for a one-shot announcement fired only
                // right after an adjustment, leaving ordinary focus to the
                // built-in single readout. Reported directly — candidate fix,
                // pending confirmation with VoiceOver before the same swap
                // goes out to the other affected pickers.
                .accessibilityAdjustableAction { direction in
                    guard let idx = HomeStartupBehavior.allCases.firstIndex(of: preferences.homeStartupBehavior) else { return }
                    switch direction {
                    case .increment:
                        preferences.homeStartupBehavior = HomeStartupBehavior.allCases[(idx + 1) % HomeStartupBehavior.allCases.count]
                    case .decrement:
                        preferences.homeStartupBehavior = HomeStartupBehavior.allCases[(idx - 1 + HomeStartupBehavior.allCases.count) % HomeStartupBehavior.allCases.count]
                    @unknown default: break
                    }
                    UIAccessibility.post(notification: .announcement, argument: preferences.homeStartupBehavior.displayName)
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

                // Moved from Settings > Privacy — its underlying key
                // (privacy.signedOutHistory) is a holdover from when this
                // also controlled whether reading history was tracked at
                // all for signed-out users; it doesn't anymore (tracking
                // always happens now), so what's left is purely a Home
                // display preference, not a privacy control. Discussed and
                // requested directly.
                Toggle("Show What's New on Home", isOn: $preferences.showNewActivityIndicators)
                    .accessibilityHint(String(localized: "When on, Home shows a New view, a quick summary, and small badges for content with new activity since your last visit."))
                Text("Reading history is always tracked on-device — this only controls whether Home actually shows what's new because of it. Turning it off doesn't erase anything; it just keeps Home quieter.")
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
                // See Home Startup Behavior above for the full reasoning —
                // a persistent .accessibilityValue() here duplicated what
                // the control already announces natively on plain focus.
                // Swapped for a one-shot announcement fired only right
                // after an adjustment.
                .accessibilityAdjustableAction { direction in
                    guard let idx = WebBrowsingMode.allCases.firstIndex(of: preferences.webBrowsingMode) else { return }
                    switch direction {
                    case .increment:
                        preferences.webBrowsingMode = WebBrowsingMode.allCases[(idx + 1) % WebBrowsingMode.allCases.count]
                    case .decrement:
                        preferences.webBrowsingMode = WebBrowsingMode.allCases[(idx - 1 + WebBrowsingMode.allCases.count) % WebBrowsingMode.allCases.count]
                    @unknown default: break
                    }
                    UIAccessibility.post(notification: .announcement, argument: preferences.webBrowsingMode.displayName)
                }
            }

            Section("Tips") {
                Toggle("AppleVis Tips", isOn: $preferences.helpfulTipsEnabled)
                    .accessibilityHint(String(localized: "Shows short contextual tips and friendly reminders where they can save time."))
                Text("Short, friendly tips that pop up here and there — timed to save you a step, not to nag.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Moved from Settings > Privacy — this controls how existing
            // site content is displayed to you (masked vs. spelled out), not
            // what AppleVis collects or shares, so it's a content-display
            // preference like Web Links or Tips above, not a privacy
            // control. Discussed and requested directly.
            Section("Language Filtering") {
                Toggle("Filter Profanity", isOn: $preferences.filterProfanity)
                    .accessibilityHint(String(localized: "When on, milder language is shown masked, like s star star star, instead of spelled out."))
                Text("AppleVis blocks strong or explicit language from every post and comment, always — this setting doesn't change that. It only controls whether milder language, which the site otherwise allows, is shown masked or spelled out. We keep this on by default to help AppleVis stay welcoming, and to stay within Apple's guidelines for our age rating.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let article = HelpContent.find("community-language-filter") {
                    NavigationLink {
                        HelpArticleDetailView(article: article)
                    } label: {
                        Label("Learn More About Language Filtering", systemImage: "info.circle")
                    }
                }
            }

            Section {
                ResetToDefaultsButton {
                    preferences.homeStartupBehavior = .detailed
                    preferences.welcomeSummaryEnabled = true
                    preferences.showNewActivityIndicators = true
                    preferences.searchAutoFocusEnabled = false
                    preferences.webBrowsingMode = .inApp
                    preferences.helpfulTipsEnabled = true
                    preferences.filterProfanity = true
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("General")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isTitleFocused) }
    }
}
