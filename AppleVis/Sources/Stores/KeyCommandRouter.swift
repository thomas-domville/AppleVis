import Foundation
import Combine

/// Backs hardware-keyboard shortcuts (external keyboard on iPad/iPhone),
/// registered as SwiftUI `.commands` in `AppleVisApp`. `.commands` closures
/// only see environment objects, not another view's local `@State`, so tab
/// selection and one-shot actions route through this shared object instead
/// of being wired directly — same role `DeepLinkRouter` plays for Spotlight
/// and universal links.
@MainActor
final class KeyCommandRouter: ObservableObject {
    @Published var selectedTab = 0
    @Published var showSettings = false
    let refreshRequested = PassthroughSubject<Void, Never>()
}
