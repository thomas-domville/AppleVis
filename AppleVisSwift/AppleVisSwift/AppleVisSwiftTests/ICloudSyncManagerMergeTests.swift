import Testing
@testable import AppleVisSwift

/// Test-coverage gap closure (Phase L): `ICloudSyncManager`'s pull/merge
/// logic was previously only exercisable end-to-end against a real
/// `NSUbiquitousKeyValueStore`, with zero automated coverage of the actual
/// merge decision. `reconcileIds(cloud:local:shadow:)` extracts that pure
/// three-way set reconciliation out of `pullSavedItems` (same production
/// logic, unchanged — see its own doc comment) so it can be tested
/// directly.
@Suite("ICloudSyncManager.reconcileIds")
struct ICloudSyncManagerMergeTests {

    @Test("an id present in cloud but not local is added")
    func cloudOnlyIdIsAdded() {
        let result = ICloudSyncManager.reconcileIds(cloud: ["a"], local: [], shadow: [])
        #expect(result.toAdd == ["a"])
        #expect(result.toRemove.isEmpty)
    }

    @Test("an id in the shadow and still local, but no longer in cloud, is removed (a genuine remote deletion)")
    func shadowedIdMissingFromCloudIsRemoved() {
        let result = ICloudSyncManager.reconcileIds(cloud: [], local: ["a"], shadow: ["a"])
        #expect(result.toRemove == ["a"])
        #expect(result.toAdd.isEmpty)
    }

    @Test("an id added locally since the last sync (local but never shadowed) is left alone, not removed")
    func unshadowedLocalIdIsNotRemoved() {
        // This is the specific case the shadow set exists to protect: a
        // user saves an item, then pulls before that save has been pushed
        // to iCloud — the cloud snapshot doesn't have it yet, but it must
        // not be treated as a remote deletion.
        let result = ICloudSyncManager.reconcileIds(cloud: [], local: ["a"], shadow: [])
        #expect(result.toRemove.isEmpty)
        #expect(result.toAdd.isEmpty)
    }

    @Test("an id present in both cloud and local is neither added nor removed")
    func idInBothIsNoOp() {
        let result = ICloudSyncManager.reconcileIds(cloud: ["a"], local: ["a"], shadow: ["a"])
        #expect(result.toAdd.isEmpty)
        #expect(result.toRemove.isEmpty)
    }

    @Test("a mixed set: one addition, one genuine removal, one untouched, one protected-by-unshadowed-local")
    func mixedReconciliation() {
        let result = ICloudSyncManager.reconcileIds(
            cloud: ["new-from-cloud", "unchanged"],
            local: ["unchanged", "deleted-remotely", "added-locally-not-yet-synced"],
            shadow: ["unchanged", "deleted-remotely"]
        )
        #expect(result.toAdd == ["new-from-cloud"])
        #expect(result.toRemove == ["deleted-remotely"])
    }
}
