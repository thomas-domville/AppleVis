import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var focusTarget: AnyHashable?

    var body: some View {
        Form {
            Section("App Information") {
                NavigationLink {
                    WhatsNewView()
                        .onDisappear {
                            Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("whatsNew")) }
                        }
                } label: {
                    Label("What's New", systemImage: "sparkles")
                }
                .accessibilityFocused($focusTarget, equals: AnyHashable("whatsNew"))
                .accessibilityLabel(String(localized: "What's New in AppleVis"))
                InfoRow(label: String(localized: "Version"), value: DiagnosticInfo.appVersion)
                InfoRow(label: String(localized: "Build"), value: DiagnosticInfo.buildNumber)
                // Device details, accessibility status, and Copy Support
                // Info used to spill directly into this screen as ten-plus
                // flat rows before anyone had asked for them — moved behind
                // its own button, matching the pattern below for Social
                // Media and Credits. Requested directly.
                NavigationLink {
                    DiagnosticInfoView()
                        .onDisappear {
                            Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("diagnosticInfo")) }
                        }
                } label: {
                    Label("Diagnostic Info", systemImage: "wrench.and.screwdriver")
                }
                .accessibilityFocused($focusTarget, equals: AnyHashable("diagnosticInfo"))
                .accessibilityHint(String(localized: "Device details, accessibility status, and a way to copy support info."))
            }

            Section("Connect With Us") {
                // Previously three separate Link rows — one button to a
                // dedicated screen now, matching the same pattern Discover's
                // RSS Feeds card already uses successfully. Requested
                // directly.
                NavigationLink {
                    SocialLinksView()
                        .onDisappear {
                            Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("socialLinks")) }
                        }
                } label: {
                    Label("Follow AppleVis on Social Media", systemImage: "person.2.wave.2")
                }
                .accessibilityFocused($focusTarget, equals: AnyHashable("socialLinks"))
                .accessibilityHint(String(localized: "See ways to follow AppleVis on X, Facebook, and Mastodon."))

                WebLink(destination: URL(string: "https://www.applevis.com")!) {
                    Label("applevis.com", systemImage: "globe")
                }
                .accessibilityLabel(String(localized: "applevis.com website"))
            }

            Section("Legal & Credits") {
                NavigationLink {
                    CreditsView()
                        .onDisappear {
                            Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("credits")) }
                        }
                } label: {
                    Label("Credits", systemImage: "person.2")
                }
                .accessibilityFocused($focusTarget, equals: AnyHashable("credits"))
                NavigationLink {
                    OpenSourceView()
                        .onDisappear {
                            Task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("openSource")) }
                        }
                } label: {
                    Label("Open Source Licences", systemImage: "doc.text")
                }
                .accessibilityFocused($focusTarget, equals: AnyHashable("openSource"))
                WebLink(destination: URL(string: "https://www.applevis.com/privacy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                WebLink(destination: URL(string: "https://www.applevis.com/terms")!) {
                    Label("Terms of Service", systemImage: "doc.plaintext")
                }
            }

            Section {
                Text("© 2026 AppleVis\napplevis.com")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(String(localized: "Copyright 2026 AppleVis. All rights reserved."))
            }
            .listRowBackground(Color.clear)
        }
        .themedList(preferences.colors)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        // Missing the initial title-focus `.task` its sibling hub screens
        // (SettingsView, ProfileView) both have — reuses the "whatsNew"
        // target already wired to the first row below, the same way
        // ProfileView reuses its own titleFocusID for both initial focus
        // and returning-from-a-subscreen focus. Full app-wide focus audit,
        // requested directly.
        .task { await retryAccessibilityFocus(into: $focusTarget, returningTo: AnyHashable("whatsNew")) }
    }
}
