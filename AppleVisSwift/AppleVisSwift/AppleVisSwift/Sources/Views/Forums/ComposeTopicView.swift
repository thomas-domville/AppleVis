import SwiftUI

struct ComposeTopicView: View {
    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedCategory: ForumCategory?
    @State private var categories: [ForumCategory] = []
    @State private var isSubmitting = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && !bodyText.trimmingCharacters(in: .whitespaces).isEmpty && selectedCategory != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Topic title", text: $title)
                }
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("Choose…").tag(Optional<ForumCategory>.none)
                        ForEach(categories) { cat in
                            Text(cat.name).tag(Optional(cat))
                        }
                    }
                }
                Section("Body") {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 200)
                }
                if let error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Topic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { Task { await submit() } }
                        .disabled(!isValid || isSubmitting)
                }
            }
            .task { await loadCategories() }
        }
    }

    private func loadCategories() async {
        categories = (try? await APIClient.shared.forums.categories()) ?? []
    }

    private func submit() async {
        guard let user = auth.user, let cat = selectedCategory else { return }
        isSubmitting = true
        error = nil
        do {
            _ = try await APIClient.shared.forums.submitTopic(title: title, body: bodyText, categoryTid: cat.tid, csrfToken: user.csrfToken)
            toast.success("Topic posted")
            dismiss()
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Failed to post topic." }
        isSubmitting = false
    }
}

struct ComposeReplyView: View {
    let topicId: String
    let topicTitle: String
    let onPosted: (ForumReply) -> Void

    @State private var bodyText = ""
    @State private var isSubmitting = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var toast: ToastStore

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Re: \(topicTitle)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                TextEditor(text: $bodyText)
                    .padding()
                if let error {
                    Text(error).foregroundStyle(.red).padding()
                }
            }
            .navigationTitle("Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { Task { await submit() } }
                        .disabled(bodyText.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
        }
    }

    private func submit() async {
        guard let user = auth.user else { return }
        isSubmitting = true
        error = nil
        do {
            let reply = try await APIClient.shared.forums.submitReply(topicId: topicId, body: bodyText, csrfToken: user.csrfToken)
            toast.success("Reply posted")
            onPosted(reply)
            dismiss()
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Failed to post reply." }
        isSubmitting = false
    }
}
