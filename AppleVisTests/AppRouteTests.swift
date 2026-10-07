import Foundation
import Testing
@testable import AppleVis

/// Links, Siri, Shortcuts and keyboard shortcuts all reach screens through
/// AppRoute; reading a link must be right before anything opens
/// (Adaptive Experience, 2026-10-06).
@MainActor
@Suite("AppleVis links")
struct AppRouteTests {

    private func route(_ string: String) -> AppRoute? { AppRoute(url: URL(string: string)!) }

    @Test("tabs, Contact and Settings have their own links")
    func newDestinations() {
        #expect(route("applevis://home") == .home)
        #expect(route("applevis://discover") == .discover)
        #expect(route("applevis://for-you") == .forYou)
        #expect(route("applevis://contact") == .contact)
        #expect(route("applevis://settings") == .settings)
        #expect(AppRoute.forYou.tab == 2)
        #expect(AppRoute.contact.tab == nil)
    }

    @Test("Siri's Home views and new topic")
    func siriRoutes() {
        #expect(route("applevis://home?view=new") == .homeView(.new, listen: false))
        #expect(route("applevis://home?view=fetch&listen=1") == .homeView(.fetch, listen: true))
        #expect(route("applevis://home?view=fetch") == .homeView(.fetch, listen: false))
        #expect(route("applevis://home?view=nibbles") == .homeView(.mouseRecap, listen: false))
        // Only Fetch can be listened to.
        #expect(route("applevis://home?view=new&listen=1") == .homeView(.new, listen: false))
        #expect(route("applevis://home?view=nonsense") == .home)
        #expect(AppRoute.homeView(.fetch, listen: true).tab == 0)
        #expect(route("applevis://new-topic") == .newTopic)
    }

    @Test("existing links read the same as before")
    func existingLinks() {
        #expect(route("applevis://ask?q=How%20do%20I%20scroll") == .askTheMouse(question: "How do I scroll"))
        #expect(route("applevis://ask") == .askTheMouse(question: ""))
        #expect(route("applevis://forums?filter=unread") == .forums(filter: .unread))
        #expect(route("applevis://forums?filter=nonsense") == .forums(filter: .recent))
        #expect(route("applevis://saved") == .savedItems)
        #expect(route("applevis://search?q=braille") == .search(query: "braille"))
        #expect(route("applevis://whats-new") == .whatsNew)
        #expect(route("applevis://podcasts?action=resume") == .podcast(.resume))
        #expect(route("applevis://podcasts?action=playLatest") == .podcast(.playLatest))
        #expect(route("applevis://submit-bug") == .submitBug)
        #expect(route("applevis://submit-app?url=https://apps.apple.com/app/id1") == .submitApp(url: "https://apps.apple.com/app/id1"))
    }

    @Test("recognised links with nothing to open do nothing, and stay in the app")
    func emptyLinksAreIgnored() {
        #expect(route("applevis://search") == .ignored)
        #expect(route("applevis://search?q=%20%20") == .ignored)
        #expect(route("applevis://podcasts") == .ignored)
    }

    @Test("unknown or foreign links are refused")
    func unknownLinks() {
        #expect(route("applevis://nowhere") == nil)
        #expect(route("https://www.applevis.com/forum") == nil)
        #expect(route("otherapp://contact") == nil)
    }
}
