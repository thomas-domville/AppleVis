import Foundation
import UIKit

// What Ask the Mouse remembers between questions: About Me, past
// conversations, and which pages helped. All of it stays on the device
// (past conversations also sync with iCloud when Saved Items sync is on),
// and none of it is sent to AppleVis. Requested directly (2026-10-01).

/// The devices and features you use, so the Mouse can lead with the answer
/// for your setup when a question doesn't say. Empty until you fill it in.
struct MouseProfile: Codable, Equatable {
    enum Device: String, Codable, CaseIterable, Identifiable {
        case iPhone, iPad, mac, appleWatch, appleTV, visionPro

        var id: String { rawValue }

        /// Apple's product names, the same in every language.
        var name: String {
            switch self {
            case .iPhone: return "iPhone"
            case .iPad: return "iPad"
            case .mac: return "Mac"
            case .appleWatch: return "Apple Watch"
            case .appleTV: return "Apple TV"
            case .visionPro: return "Apple Vision Pro"
            }
        }
    }

    enum Method: String, Codable, CaseIterable, Identifiable {
        case voiceOver, zoom, brailleDisplay, brailleScreenInput, keyboard, switchControl, voiceControl, hearingDevices

        var id: String { rawValue }

        var name: String {
            switch self {
            case .voiceOver: return "VoiceOver"
            case .zoom: return String(localized: "Zoom")
            case .brailleDisplay: return String(localized: "A braille display")
            case .brailleScreenInput: return String(localized: "Braille Screen Input")
            case .keyboard: return String(localized: "A keyboard")
            case .switchControl: return String(localized: "Switch Control")
            case .voiceControl: return String(localized: "Voice Control")
            case .hearingDevices: return String(localized: "Hearing aids or other hearing devices")
            }
        }

        /// For Apple Intelligence only.
        var modelName: String {
            switch self {
            case .voiceOver: return "VoiceOver"
            case .zoom: return "Zoom"
            case .brailleDisplay: return "a braille display"
            case .brailleScreenInput: return "Braille Screen Input"
            case .keyboard: return "a keyboard"
            case .switchControl: return "Switch Control"
            case .voiceControl: return "Voice Control"
            case .hearingDevices: return "hearing devices"
            }
        }
    }

    var devices: Set<Device> = []
    var methods: Set<Method> = []

    var isEmpty: Bool { devices.isEmpty && methods.isEmpty }

    /// "iPhone, Mac. VoiceOver, A braille display", for the About Me row.
    var summary: String {
        let deviceNames = Device.allCases.filter(devices.contains).map(\.name)
        let methodNames = Method.allCases.filter(methods.contains).map(\.name)
        return [deviceNames, methodNames].filter { !$0.isEmpty }
            .map { ListFormatter.localizedString(byJoining: $0) }
            .joined(separator: ". ")
    }

    /// What the plan and the answer are told. Empty when nothing is set.
    var modelText: String {
        guard !isEmpty else { return "" }
        var parts: [String] = []
        if !devices.isEmpty {
            parts.append("uses " + Device.allCases.filter(devices.contains).map(\.name).joined(separator: ", "))
        }
        if !methods.isEmpty {
            parts.append("uses " + Method.allCases.filter(methods.contains).map(\.modelName).joined(separator: ", "))
        }
        return "About the person (from their About Me): " + parts.joined(separator: "; ") + "."
    }

    /// Starting suggestions from this device: its kind, and VoiceOver or
    /// Zoom if either is on now. Nothing is saved until you change it.
    static var suggested: MouseProfile {
        var profile = MouseProfile()
        profile.devices.insert(UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone)
        if UIAccessibility.isVoiceOverRunning { profile.methods.insert(.voiceOver) }
        if UIAccessibility.isSwitchControlRunning { profile.methods.insert(.switchControl) }
        return profile
    }

    private static let key = "mouse.aboutMe.v1"

    static func load() -> MouseProfile {
        guard let data = UserDefaults.standard.data(forKey: key),
              let profile = try? JSONDecoder().decode(MouseProfile.self, from: data) else { return MouseProfile() }
        return profile
    }

    static func save(_ profile: MouseProfile) {
        if profile.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// One conversation with the Mouse: its questions and answers, oldest
/// first, with their sources.
struct MouseConversation: Codable, Identifiable, Hashable {
    let id: String
    var startedAt: Date
    var updatedAt: Date
    var answers: [SavedMouseAnswer]

    var title: String { answers.first?.question ?? "" }

    /// The most answers kept in one conversation.
    static let maxAnswers = 12
}

/// The last 10 conversations, newest first, and when the list last changed.
struct MouseConversationHistory: Codable {
    var conversations: [MouseConversation]
    var updatedAt: Date

    static let maxConversations = 10
    private static let key = "mouse.conversations.v1"

    static func load() -> MouseConversationHistory {
        guard let data = UserDefaults.standard.data(forKey: key),
              let history = try? JSONDecoder().decode(MouseConversationHistory.self, from: data)
        else { return MouseConversationHistory(conversations: [], updatedAt: .distantPast) }
        return history
    }

    static func save(_ history: MouseConversationHistory) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Adds an answer to a conversation, or replaces it if it's already
    /// there (an answer that finished reading its results), and moves that
    /// conversation to the top.
    mutating func record(_ answer: SavedMouseAnswer, in conversationId: String, at date: Date = Date()) {
        var conversation = conversations.first { $0.id == conversationId }
            ?? MouseConversation(id: conversationId, startedAt: date, updatedAt: date, answers: [])
        if let index = conversation.answers.firstIndex(where: { $0.id == answer.id }) {
            conversation.answers[index] = answer
        } else {
            conversation.answers.append(answer)
        }
        conversation.answers = Array(conversation.answers.suffix(MouseConversation.maxAnswers))
        conversation.updatedAt = date
        conversations.removeAll { $0.id == conversationId }
        conversations.insert(conversation, at: 0)
        conversations = Array(conversations.prefix(Self.maxConversations))
        updatedAt = date
    }

    mutating func remove(_ conversationId: String, at date: Date = Date()) {
        conversations.removeAll { $0.id == conversationId }
        updatedAt = date
    }
}

/// Which pages helped with which questions, from "Did this answer your
/// question?". A guide or forum topic that answered a similar question is
/// read first next time; one that didn't is passed over. Kept on the device.
enum MouseSourceFeedback {
    struct Record: Codable, Equatable {
        /// "guide-<id>" or "forum-<id>".
        let sourceId: String
        let words: [String]
        let helpful: Bool
    }

    private static let key = "mouse.sourceFeedback.v1"
    static let maxRecords = 300

    static func record(helpful: Bool, sourceIds: [String], words: [String]) {
        guard !sourceIds.isEmpty, !words.isEmpty else { return }
        var records = load()
        records += Set(sourceIds).map { Record(sourceId: $0, words: words, helpful: helpful) }
        save(Array(records.suffix(maxRecords)))
    }

    /// Helpful answers minus unhelpful ones, for questions sharing at least
    /// two words with this one (one, for a one-word question).
    static func score(_ sourceId: String, words: [String], in records: [Record]? = nil) -> Int {
        let wanted = Set(words)
        guard !wanted.isEmpty else { return 0 }
        let needed = min(2, wanted.count)
        return (records ?? load())
            .filter { $0.sourceId == sourceId && Set($0.words).intersection(wanted).count >= needed }
            .reduce(0) { $0 + ($1.helpful ? 1 : -1) }
    }

    static func load() -> [Record] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([Record].self, from: data) else { return [] }
        return records
    }

    private static func save(_ records: [Record]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
