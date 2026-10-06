import SwiftUI

/// Notes to send to AppleVis through the Contact form: guideline review
/// decisions (admins) or Ask the Mouse notes (anyone). Sending them this way
/// replaced exporting a file, which was harder for everyone. Requested
/// directly (2026-10-06).
struct NotesPackage {
    /// The wizard's title, such as "Send Review Notes".
    let title: String
    /// The Contact form's subject. English, for the AppleVis team.
    let subject: String
    /// What will be sent, one line each, shown on the first step.
    let summary: [String]
    /// Whether there's a choice to leave out the text of posts or answers.
    let offersTextChoice: Bool
    /// Builds the message (English, for the team) and the ids it includes.
    let makeMessage: (_ includeText: Bool) -> (text: String, ids: [String])
    /// Marks those ids as sent, so they aren't sent twice.
    let markSent: ([String]) -> Void
}

struct SendNotesWizard: View {
    let package: NotesPackage

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var preferences: PreferencesStore
    @State private var step = 1
    @State private var includeText = true
    @State private var note = ""
    @State private var name = ""
    @State private var email = ""
    @State private var isSending = false
    @State private var error: String?
    @State private var sent = false
    @AccessibilityFocusState private var isStepFocused: Bool
    @AccessibilityFocusState private var isErrorFocused: Bool

    /// Signed-in members' details come from their account.
    private var needsDetails: Bool { !auth.isSignedIn || (auth.user?.email ?? "").isEmpty }
    private var senderName: String { auth.isSignedIn ? (auth.user?.name ?? name) : name }
    private var senderEmail: String { needsDetails ? email : (auth.user?.email ?? "") }
    private var canSend: Bool {
        !isSending && !senderName.trimmingCharacters(in: .whitespaces).isEmpty && senderEmail.isValidEmailFormat
    }

    var body: some View {
        AppNavigationStack {
            Group {
                if sent {
                    ThankYouView(
                        icon: "paperplane.fill",
                        heading: String(localized: "Notes Sent"),
                        message: String(localized: "Thank you. These go to the AppleVis team and help improve the app for everyone."),
                        doneLabel: String(localized: "Done"),
                        onDone: { dismiss() }
                    )
                } else {
                    Form {
                        if step == 1 { whatsIncluded } else { addNote }
                    }
                    .themedList(preferences.colors)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !sent {
                    WizardLeadingToolbar(onCancel: { dismiss() }, onBack: step == 2 ? { step = 1 } : nil)
                }
            }
            .task(id: step) { await retryAccessibilityFocus(into: $isStepFocused) }
        }
    }

    private var whatsIncluded: some View {
        Group {
            Section {
                WizardStepHeader(title: package.title, icon: "paperplane", stepIndex: 1, stepTotal: 2, headerFocus: $isStepFocused)
                Text("These go to the AppleVis team through the Contact form, so the app can be improved for everyone.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("What's Included") {
                ForEach(package.summary, id: \.self) { Text($0) }
            }
            if package.offersTextChoice {
                Section {
                    Toggle("Include the Text", isOn: $includeText)
                        .accessibilityHint(String(localized: "Includes the words behind each note, which makes them much more useful."))
                } footer: {
                    Text("The text makes each note far more useful. It's only seen by the AppleVis team.")
                }
            }
            Section {
                WizardBottomButton(String(localized: "Next")) { step = 2 }
            }
        }
    }

    private var addNote: some View {
        Group {
            Section {
                WizardStepHeader(title: "Add a Note", icon: "text.bubble", stepIndex: 2, stepTotal: 2, headerFocus: $isStepFocused)
                Text("Anything you'd like to add? This is optional.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if needsDetails {
                Section("Your Details") {
                    if !auth.isSignedIn {
                        TextField("Name", text: $name).textContentType(.name)
                    }
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress).textContentType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            }
            Section("Note") {
                TextEditor(text: $note)
                    .frame(minHeight: 100)
                    .accessibilityLabel(String(localized: "Note"))
                    .accessibilityHint(String(localized: "Optional."))
            }
            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .accessibilityFocused($isErrorFocused)
                }
            }
            Section {
                WizardBottomButton(String(localized: "Send"), isEnabled: canSend, isLoading: isSending) {
                    Task { await send() }
                }
            }
        }
    }

    private func send() async {
        let built = package.makeMessage(includeText)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = SiteText.withSenderNote(trimmedNote, built.text)
        isSending = true
        error = nil
        let result = await DrupalFormClient.submitContact(
            name: senderName.trimmingCharacters(in: .whitespaces),
            email: senderEmail.trimmingCharacters(in: .whitespaces),
            subject: package.subject,
            message: message
        )
        isSending = false
        switch result {
        case .ok:
            package.markSent(built.ids)
            SoundPlayer.shared.play(.success)
            sent = true
        case .failure(let message):
            error = message
            await announceWizardFailure(message, focus: $isErrorFocused)
        }
    }
}
