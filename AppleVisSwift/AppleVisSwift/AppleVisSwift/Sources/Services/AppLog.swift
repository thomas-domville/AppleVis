import os

/// This app had zero logging infrastructure anywhere — not even print()
/// beyond a handful of scattered, non-categorized calls — so a corrupted
/// iCloud sync blob, a Keychain write failure, or a persistence decode
/// failure had no trace to debug from, in DEBUG or Release. `os.Logger`
/// output shows up in Console.app/sysdiagnose without needing print()
/// left in Release builds, and categories let it be filtered per subsystem.
enum AppLog {
    static let sync = Logger(subsystem: "com.applevis.AppleVisSwift", category: "sync")
    static let auth = Logger(subsystem: "com.applevis.AppleVisSwift", category: "auth")
    static let persistence = Logger(subsystem: "com.applevis.AppleVisSwift", category: "persistence")
    static let player = Logger(subsystem: "com.applevis.AppleVisSwift", category: "player")
    static let intelligence = Logger(subsystem: "com.applevis.AppleVisSwift", category: "intelligence")
}
