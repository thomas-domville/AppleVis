import Testing
import Foundation
@testable import AppleVis

/// Pins the sign-up burst rule used by Profile > Admin > Never Signed In:
/// 3 or more accounts, each created within 30 minutes of the one before.
@Suite("Never Signed In sign-up bursts")
@MainActor
struct DormantAccountBurstTests {

    private func account(_ id: String, minutes: Double) -> DormantAccount {
        DormantAccount(
            id: id, uid: 1, username: id, displayName: id,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000 + minutes * 60),
            isBlocked: false
        )
    }

    private func sizes(_ accounts: [DormantAccount]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: DormantAccountStore.markBursts(accounts).map { ($0.id, $0.burstSize) })
    }

    @Test("three accounts within 30 minutes of each other form a burst")
    func threeMakeABurst() {
        let result = sizes([account("a", minutes: 0), account("b", minutes: 20), account("c", minutes: 45)])
        #expect(result == ["a": 3, "b": 3, "c": 3])
    }

    @Test("two close accounts aren't a burst")
    func twoIsNotABurst() {
        let result = sizes([account("a", minutes: 0), account("b", minutes: 5), account("c", minutes: 500)])
        #expect(result.values.allSatisfy { $0 == 0 })
    }

    @Test("a gap over 30 minutes splits bursts, and input order doesn't matter")
    func gapSplits() {
        let result = sizes([
            account("d", minutes: 100), account("a", minutes: 0), account("c", minutes: 20),
            account("b", minutes: 10), account("e", minutes: 110), account("f", minutes: 120),
            account("g", minutes: 1000),
        ])
        #expect(result == ["a": 3, "b": 3, "c": 3, "d": 3, "e": 3, "f": 3, "g": 0])
    }
}
