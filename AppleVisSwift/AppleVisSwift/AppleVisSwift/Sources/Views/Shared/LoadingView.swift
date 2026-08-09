import SwiftUI

/// Localizes a runtime `String` against the catalog the same way a literal
/// passed directly to `Text("...")`/`Button("...")` would — needed anywhere
/// a string arrives through a `String`-typed parameter, since that always
/// resolves to `Text`'s/`Button`'s verbatim `StringProtocol` overload
/// instead of the auto-matching `LocalizedStringKey` one, even when its
/// value is character-for-character identical to a catalog key.
private func localized(_ value: String) -> String {
    String(localized: String.LocalizationValue(value))
}

struct LoadingView: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(localized(message))
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // None of these three shared states ever told VoiceOver anything
        // changed — a user pulling to refresh into an error or empty state
        // (or a screen swapping from a spinner to real content) got no
        // signal short of re-swiping to discover it. `.screenChanged` both
        // re-scans the screen and speaks its argument.
        .onAppear { UIAccessibility.post(notification: .screenChanged, argument: localized(message)) }
    }
}

struct ErrorView: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(localized(message))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await retry() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { UIAccessibility.post(notification: .screenChanged, argument: localized(message)) }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "tray"
    var primaryActionLabel: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryActionLabel: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(localized(title))
                .font(.headline)
            Text(localized(message))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let primaryActionLabel, let primaryAction {
                Button(localized(primaryActionLabel), action: primaryAction)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
            if let secondaryActionLabel, let secondaryAction {
                Button(localized(secondaryActionLabel), action: secondaryAction)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { UIAccessibility.post(notification: .screenChanged, argument: "\(localized(title)). \(localized(message))") }
    }
}
