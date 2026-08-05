import Combine
import Foundation

/// Lightweight, globally observable mirror of ApiHealthMonitor's circuit
/// breaker state, so SwiftUI views can show a "you're seeing saved content"
/// banner without awaiting an actor call. Updated by CachedFetch.swift
/// whenever a fetch's outcome changes a content group's health — this is
/// the piece that was deliberately deferred when the caching layer first
/// went in: the underlying fallback-to-cache behavior worked, but nothing
/// told the user when they were looking at it.
@MainActor
final class NetworkStatusStore: ObservableObject {
    static let shared = NetworkStatusStore()

    @Published private(set) var degradedGroups: Set<ContentGroup> = []

    private init() {}

    func markDegraded(_ group: ContentGroup) {
        degradedGroups.insert(group)
    }

    func markHealthy(_ group: ContentGroup) {
        degradedGroups.remove(group)
    }
}
