import Foundation
import SwiftUI

/// Tracks whether the signed-out user has accepted AppleVis's Community
/// Agreement — a separate concern from `AuthStore`'s authentication state:
/// this is local acknowledgment of the participation guidelines, not an
/// account credential. Gates sign-in (`OnboardingView`'s Community
/// Agreement step, `ProfileView`'s signed-out "Sign in to AppleVis"
/// button), never general app browsing, which stays available regardless
/// of acceptance state. Kept separate from `AuthStore` deliberately:
/// authentication and local participation-policy acknowledgment are
/// different concerns, and this state needs to exist even for someone who
/// never signs in.
@MainActor
final class CommunityAgreementStore: ObservableObject {
    /// Bump this whenever the agreement's substance changes meaningfully —
    /// anyone who accepted an older version is asked again before their
    /// next sign-in.
    static let currentVersion = 1

    @Published private(set) var acceptedVersion: Int

    private let acceptedVersionKey = "applevis.communityAgreementAcceptedVersion"

    var hasAcceptedCurrentVersion: Bool { acceptedVersion >= Self.currentVersion }

    init() {
        acceptedVersion = UserDefaults.standard.integer(forKey: acceptedVersionKey)
    }

    func acceptCurrentVersion() {
        acceptedVersion = Self.currentVersion
        UserDefaults.standard.set(acceptedVersion, forKey: acceptedVersionKey)
    }

    /// Call from any "Sign In" button's action in place of setting a
    /// `showSignIn` flag directly — shows the Community Agreement first if
    /// it hasn't been accepted yet, otherwise signs in immediately. Every
    /// sign-in entry point (Profile, and every Compose/Submit flow that
    /// offers its own inline sign-in prompt) calls this one method instead
    /// of each re-implementing the same accepted-version check, so the gate
    /// can't drift between them. Pair with `.communityAgreementGate(...)`
    /// on the same view for the sheet this presents.
    func requestSignIn(showCommunityAgreement: Binding<Bool>, showSignIn: Binding<Bool>) {
        if hasAcceptedCurrentVersion {
            showSignIn.wrappedValue = true
        } else {
            showCommunityAgreement.wrappedValue = true
        }
    }
}
