import Combine
import Foundation
import SwiftUI
#if canImport(Darwin)
import Darwin
#endif

/// Checks whether an email's domain has any DNS presence at all — a
/// lightweight, on-device signal that catches a made-up or badly mistyped
/// domain (no DNS record whatsoever, like a typo'd or invented name) without
/// claiming to confirm the domain actually accepts mail (that needs an
/// MX-specific lookup) or that any particular mailbox exists there. Uses the
/// standard POSIX resolver (`getaddrinfo`) — public API, no private
/// frameworks, no third-party service, and nothing about the address leaves
/// the device.
enum DomainReachability {
    /// `nil` means "couldn't tell" (timed out, or the check itself failed
    /// for a reason unrelated to the domain) — callers should treat that the
    /// same as "assume it's fine" rather than warning about a real address
    /// over a slow or temporarily blocked DNS lookup.
    static func domainExists(_ domain: String, timeout: Duration = .seconds(4)) async -> Bool? {
        await withTaskGroup(of: Bool?.self) { group in
            group.addTask { await resolve(domain) }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    /// `getaddrinfo` is a blocking call with no built-in cancellation, so a
    /// "timeout" above just means the caller stops waiting on it — this
    /// background thread finishes on its own and is discarded.
    private static func resolve(_ domain: String) async -> Bool? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var hints = addrinfo(
                    ai_flags: 0,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: 0,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )
                var result: UnsafeMutablePointer<addrinfo>?
                let status = getaddrinfo(domain, nil, &hints, &result)
                defer { if let result { freeaddrinfo(result) } }
                continuation.resume(returning: status == 0)
            }
        }
    }
}

/// Drives the debounced "does this domain exist?" check shared by every
/// wizard that asks for an email address — Contact Us, Submit Bug Report,
/// Submit Blog, and Report a Comment. Deliberately advisory only: a
/// negative result shows a dismissible-by-editing warning, never blocks
/// Send, since a false negative (flaky network, VPN, a domain that only has
/// mail servers and no website) would otherwise lock out a real address.
@MainActor
final class EmailDomainChecker: ObservableObject {
    enum State { case idle, checking, likelyValid, likelyInvalid }

    @Published private(set) var state: State = .idle
    private var task: Task<Void, Never>?

    /// Call on every edit to the email field — cancels any in-flight check
    /// for the previous value and starts a new debounce window.
    func check(email: String) {
        task?.cancel()
        guard email.isValidEmailFormat, let domain = email.split(separator: "@").last else {
            state = .idle
            return
        }
        let domainString = String(domain)
        state = .checking
        task = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            let exists = await DomainReachability.domainExists(domainString)
            guard !Task.isCancelled else { return }
            state = exists == false ? .likelyInvalid : .likelyValid
        }
    }
}

/// Shared warning row for every wizard's email field — kept in one place so
/// the wording and styling stay identical everywhere it appears.
struct EmailDomainWarning: View {
    @ObservedObject var checker: EmailDomainChecker

    var body: some View {
        if checker.state == .likelyInvalid {
            Label("This domain doesn't seem to exist — check for a typo?", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
