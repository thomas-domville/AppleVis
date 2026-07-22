import SwiftUI

/// Shared edit sheet for any user-authored comment/reply/review body text.
struct EditContentSheet: View {
    let title: String
    let initialText: String
    let onSave: (String) async throws -> Void

    @State private var text: String
    @State private var isSaving = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    init(title: String, initialText: String, onSave: @escaping (String) async throws -> Void) {
        self.title = title
        self.initialText = initialText
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $text)
                    .padding()
                if let error {
                    Text(error).foregroundStyle(.red).padding(.horizontal)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving || text == initialText)
                }
            }
        }
    }

    private func save() async {
        isSaving = true; error = nil
        do {
            try await onSave(text)
            dismiss()
        } catch let e as APIError {
            error = e.localizedDescription
        } catch {
            self.error = "Couldn't save changes."
        }
        isSaving = false
    }
}
