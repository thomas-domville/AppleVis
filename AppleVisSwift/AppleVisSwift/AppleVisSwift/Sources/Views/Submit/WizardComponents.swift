import SwiftUI

/// "Step X of N" indicator shown at the top of each multi-step submission wizard.
struct WizardStepIndicator: View {
    let step: Int
    let total: Int
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Step \(step) of \(total)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(step) of \(total): \(title)")
    }
}

/// A single label/value row on a wizard's final review screen.
struct WizardReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value)
                .font(.body)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value.isEmpty ? "none" : value)")
    }
}
