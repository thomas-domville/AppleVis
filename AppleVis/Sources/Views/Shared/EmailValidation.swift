import Foundation

extension String {
    /// Format-only email validation — rejects spaces, a missing "@", a
    /// domain with no dot, and unreasonably long input. This can't confirm
    /// the address actually exists: that needs a DNS/MX lookup (no clean
    /// App-Store-safe API for that on iOS) or a paid third-party
    /// verification service (which means sending a user's typed email off-
    /// device to a stranger's API before they've even submitted anything).
    /// A syntactically valid but fake address like
    /// "silly@thereisnoemail.com" will still pass this check — it only
    /// catches malformed input, which is most of what real users actually
    /// get wrong.
    var isValidEmailFormat: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 254, !trimmed.contains(" ") else { return false }
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return false }
        return parts[1].contains(".")
    }
}
