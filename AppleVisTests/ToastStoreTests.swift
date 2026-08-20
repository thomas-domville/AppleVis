import Testing
import Foundation
@testable import AppleVis

/// Regression coverage for CONC-02: `show()` spawned an untracked `Task`
/// per call that unconditionally nilled `current` after 3 seconds,
/// regardless of whether `current` still referred to *that specific*
/// toast — a quick Save immediately followed by a Follow meant the first
/// toast's timer fired and cleared the *second* toast early, cutting its
/// VoiceOver-announced duration short. Fixed by comparing the toast's own
/// `id` before clearing. This test waits out the real 3-second dismissal
/// timer rather than mocking it, since the race is specifically about that
/// timer's closure comparing against stale state.
@Suite("ToastStore dismissal")
@MainActor
struct ToastStoreTests {

    @Test("a second toast shown before the first's timer fires survives that timer")
    func secondToastSurvivesFirstToastsTimer() async throws {
        let store = ToastStore()

        store.show("First toast")
        let firstId = store.current?.id

        try await Task.sleep(for: .seconds(1))
        store.show("Second toast")
        let secondId = store.current?.id
        #expect(firstId != secondId)

        // The first toast's timer fires ~3s after its own show() call, i.e.
        // ~2s from here. Wait past that point and confirm the second toast
        // — not nil — is still current.
        try await Task.sleep(for: .seconds(2.5))
        #expect(store.current?.id == secondId)
        #expect(store.current?.message == "Second toast")
    }
}
