import SwiftUI
import UIKit

/// A saved Ask the Mouse answer in For You > Saved: the question, the
/// start of the answer, and when it was saved. Opens the whole answer.
struct SavedMouseAnswerRow: View {
    let answer: SavedMouseAnswer
    let onRemoved: () -> Void

    var body: some View {
        NavigationLink {
            SavedMouseAnswerView(answer: answer, onRemoved: onRemoved)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                // The Mouse's face marks it as a Mouse answer at a glance.
                Label {
                    Text("Mouse Answer")
                } icon: {
                    MouseMascotView(pose: .plain, size: 22, style: .face)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                Text(answer.question)
                    .font(.headline)
                Text(answer.answer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(String(localized: "Saved \(answer.savedAt.formatted(date: .abbreviated, time: .omitted))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
        }
        .voiceOverAwareSwipeActions {
            Button {
                MouseAnswerText.presentShareSheet(answer.shareText)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
        } trailing: {
            Button(role: .destructive) {
                unsave()
            } label: {
                Label("Unsave", systemImage: "bookmark.slash")
            }
        }
        .accessibilityAction(named: Text("Unsave Answer")) { unsave() }
        .accessibilityAction(named: Text("Copy Answer with Sources")) { copy(answer.shareText) }
        .accessibilityAction(named: Text("Share Answer")) { MouseAnswerText.presentShareSheet(answer.shareText) }
        .contextMenu {
            Button { copy(answer.answer) } label: { Label("Copy Answer", systemImage: "doc.on.doc") }
            Button { copy(answer.shareText) } label: { Label("Copy Answer with Sources", systemImage: "doc.on.clipboard") }
            Button { MouseAnswerText.presentShareSheet(answer.shareText) } label: { Label("Share Answer", systemImage: "square.and.arrow.up") }
            Button(role: .destructive) { unsave() } label: { Label("Unsave Answer", systemImage: "bookmark.slash") }
        }
    }

    private func unsave() {
        PersistenceStore.shared.unsaveMouseAnswer(id: answer.id)
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Removed from Saved."))
        onRemoved()
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Copied."))
    }
}

/// The whole saved answer, its sources (each opens), and its actions.
struct SavedMouseAnswerView: View {
    let answer: SavedMouseAnswer
    let onRemoved: () -> Void

    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var deepLinkRouter: DeepLinkRouter
    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var isQuestionFocused: Bool

    var body: some View {
        List {
            Section {
                Text(answer.question)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isQuestionFocused)
                Text(answer.answer)
                    .textSelection(.enabled)
                Text(String(localized: "Saved \(answer.savedAt.formatted(date: .abbreviated, time: .omitted))"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !answer.sources.isEmpty {
                Section(String(localized: "Sources")) {
                    ForEach(answer.sources, id: \.self) { source in
                        sourceRow(source)
                    }
                }
            }

            Section {
                Button { copy(answer.answer) } label: { Label("Copy Answer", systemImage: "doc.on.doc") }
                Button { copy(answer.shareText) } label: { Label("Copy Answer with Sources", systemImage: "doc.on.clipboard") }
                Button { MouseAnswerText.presentShareSheet(answer.shareText) } label: { Label("Share Answer", systemImage: "square.and.arrow.up") }
                Button(role: .destructive) {
                    PersistenceStore.shared.unsaveMouseAnswer(id: answer.id)
                    UIAccessibility.post(notification: .announcement, argument: String(localized: "Removed from Saved."))
                    onRemoved()
                    dismiss()
                } label: {
                    Label("Unsave Answer", systemImage: "bookmark.slash")
                }
            } footer: {
                Text("Saved answers stay as they were when you saved them. Sources open the current page.")
            }
        }
        .themedList(preferences.colors)
        .navigationTitle("Mouse Answer")
        .navigationBarTitleDisplayMode(.inline)
        .task { await retryAccessibilityFocus(into: $isQuestionFocused) }
    }

    @ViewBuilder
    private func sourceRow(_ source: SavedMouseAnswer.Source) -> some View {
        let label = VStack(alignment: .leading, spacing: 2) {
            Text(source.kindLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(source.title)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)

        if let kind = source.contentKind, let id = source.contentId {
            Button {
                deepLinkRouter.pendingContent = (kind: kind, id: id)
            } label: {
                label.foregroundStyle(.primary)
            }
        } else if source.kind == .help, let id = source.helpArticleId,
                  let article = MouseKnowledge.allHelpArticles.first(where: { $0.id == id }) {
            NavigationLink { HelpArticleDetailView(article: article) } label: { label }
        } else if source.kind == .whatsNew {
            NavigationLink { WhatsNewView() } label: { label }
        } else {
            label
        }
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Copied."))
    }
}
