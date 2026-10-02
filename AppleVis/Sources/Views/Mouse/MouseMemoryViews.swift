import SwiftUI
import UIKit

/// About Me for Ask the Mouse: the devices and features you use, so the
/// Mouse can lead with the answer for your setup when a question doesn't
/// say. Kept on this device only. Requested directly (2026-10-01).
struct MouseAboutMeView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var profile = MouseProfile.load()
    @AccessibilityFocusState private var isIntroFocused: Bool

    var body: some View {
        List {
            Section {
                Text("Tell me which devices and features you use. When a question doesn't say, I'll lead with the answer for your setup.")
                    .accessibilityFocused($isIntroFocused)
                if profile.isEmpty {
                    Button {
                        profile = MouseProfile.suggested
                        save()
                        UIAccessibility.post(notification: .announcement, argument: String(localized: "Filled in from this device. Change anything that isn't right."))
                    } label: {
                        Label(String(localized: "Fill In from This Device"), systemImage: "wand.and.stars")
                    }
                    .accessibilityHint(String(localized: "Ticks this device, and VoiceOver or Switch Control if one is on now."))
                }
            }

            Section(String(localized: "Your Devices")) {
                ForEach(MouseProfile.Device.allCases) { device in
                    Toggle(device.name, isOn: binding(device))
                }
            }

            Section {
                ForEach(MouseProfile.Method.allCases) { method in
                    Toggle(method.name, isOn: binding(method))
                }
            } header: {
                Text("How You Use Them")
            } footer: {
                Text("About Me stays on this device. It's only used by Apple Intelligence on your device, and is never sent to AppleVis.")
            }

            if !profile.isEmpty {
                Section {
                    Button(String(localized: "Clear About Me"), role: .destructive) {
                        profile = MouseProfile()
                        save()
                        UIAccessibility.post(notification: .announcement, argument: String(localized: "About Me cleared."))
                    }
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("About Me")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isIntroFocused) }
    }

    private func binding(_ device: MouseProfile.Device) -> Binding<Bool> {
        Binding {
            profile.devices.contains(device)
        } set: { isOn in
            if isOn { profile.devices.insert(device) } else { profile.devices.remove(device) }
            save()
        }
    }

    private func binding(_ method: MouseProfile.Method) -> Binding<Bool> {
        Binding {
            profile.methods.contains(method)
        } set: { isOn in
            if isOn { profile.methods.insert(method) } else { profile.methods.remove(method) }
            save()
        }
    }

    private func save() {
        MouseProfile.save(profile)
    }
}

/// Your last 10 conversations with the Mouse. Open one to read it again
/// or carry on from it. Requested directly (2026-10-01).
struct MousePastConversationsView: View {
    @ObservedObject var mouse: AskTheMouse

    @EnvironmentObject private var preferences: PreferencesStore
    @State private var confirmingClear = false
    @AccessibilityFocusState private var focus: String?

    var body: some View {
        List {
            if mouse.conversations.isEmpty {
                Text("No past conversations. Your conversations with the Mouse will be kept here.")
                    .accessibilityFocused($focus, equals: "empty")
            } else {
                Section {
                    ForEach(mouse.conversations) { conversation in
                        NavigationLink(value: MouseRoute.conversation(conversation.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversation.title)
                                    .font(.headline)
                                Text(Self.detail(conversation))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        .accessibilityFocused($focus, equals: conversation.id)
                        .voiceOverAwareSwipeActions {
                            Button(role: .destructive) {
                                remove(conversation)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .accessibilityAction(named: Text("Delete Conversation")) { remove(conversation) }
                        .contextMenu {
                            Button(role: .destructive) { remove(conversation) } label: {
                                Label("Delete Conversation", systemImage: "trash")
                            }
                        }
                    }
                } footer: {
                    Text("Your last 10 conversations. They sync with your other devices when Saved Items sync is on in Settings > Saved & Sync.")
                }
                Section {
                    Button(String(localized: "Clear Past Conversations"), role: .destructive) {
                        confirmingClear = true
                    }
                }
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Past Conversations")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(String(localized: "Clear all past conversations?"), isPresented: $confirmingClear, titleVisibility: .visible) {
            Button(String(localized: "Clear Past Conversations"), role: .destructive) {
                mouse.clearConversations()
                UIAccessibility.post(notification: .announcement, argument: String(localized: "Past conversations cleared."))
            }
        } message: {
            Text("Saved answers are kept.")
        }
        .task { await retryAccessibilityFocus(mouse.conversations.first?.id ?? "empty", into: $focus) }
    }

    /// "3 questions, October 1, 2026"
    static func detail(_ conversation: MouseConversation) -> String {
        let date = conversation.updatedAt.formatted(date: .long, time: .omitted)
        return String(localized: "\(conversation.answers.count) questions, \(date)")
    }

    private func remove(_ conversation: MouseConversation) {
        mouse.removeConversation(conversation.id)
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Conversation deleted."))
    }
}

/// One past conversation: each question, its answer, and its sources, with
/// Continue This Conversation to ask a follow-up.
struct MouseConversationView: View {
    let conversationId: String
    @ObservedObject var mouse: AskTheMouse
    let onContinue: (MouseConversation) -> Void

    @EnvironmentObject private var preferences: PreferencesStore
    @AccessibilityFocusState private var isContinueFocused: Bool

    private var conversation: MouseConversation? {
        mouse.conversations.first { $0.id == conversationId }
    }

    var body: some View {
        List {
            if let conversation {
                Section {
                    Button {
                        onContinue(conversation)
                    } label: {
                        Label(String(localized: "Continue This Conversation"), systemImage: "arrow.turn.down.right")
                    }
                    .accessibilityHint(String(localized: "Reopens it in Ask the Mouse, so your next question follows on from it."))
                    .accessibilityFocused($isContinueFocused)
                }
                ForEach(conversation.answers) { answer in
                    Section {
                        Text(answer.answer)
                            .textSelection(.enabled)
                        ForEach(answer.sources, id: \.self) { source in
                            MouseSourceLink(source: source)
                        }
                    } header: {
                        Text(answer.question)
                            .textCase(nil)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .accessibilityLabel(String(localized: "You asked: \(answer.question)"))
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            } else {
                Text("This conversation was deleted.")
                    .accessibilityFocused($isContinueFocused)
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isContinueFocused) }
    }
}

/// A saved source inside Ask the Mouse, opening its page where it can.
struct MouseSourceLink: View {
    let source: SavedMouseAnswer.Source

    var body: some View {
        if let kind = source.contentKind, let id = source.contentId {
            NavigationLink(value: MouseRoute.saved(kind, id)) { label }
        } else if source.kind == .help, let id = source.helpArticleId {
            NavigationLink(value: MouseRoute.help(id)) { label }
        } else if source.kind == .whatsNew {
            NavigationLink(value: MouseRoute.whatsNew) { label }
        } else {
            label
        }
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "From: \(source.kindLabel)"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(source.title)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
    }
}
