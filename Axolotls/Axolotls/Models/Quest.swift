//
//  Quest.swift
//  Axolotls
//
//  Part C (Photos). Quests are the photo prompts shown on the Camera screen
//  ("Take a photo with the tallest person in the room").
//
//  Two sources:
//    • groups/{groupId}/quests/{questId}: written for a group (Gemini prompts are
//      Version 2, so nothing writes these yet; add one in the console to test).
//    • BuiltInQuests: a fixed list in the app, so every group has a prompt in Version 1.
//

import Foundation

// MARK: - groups/{groupId}/quests/{questId}

enum QuestSource: String, Codable {
    case bank       // picked from a ready-made list
    case gemini     // written by Gemini for this group (Version 2)
}

/// A timed photo quest stored on a group. Same fields as the Sprint 3 design.
struct Quest: Codable, Identifiable, Hashable {
    var id: String? = nil           // document ID, not stored as a field
    var prompt: String              // prompt
    var checkable: Bool             // checkable  (true = AI can check it; AI checking is cut for V1/V2)
    var order: Int                  // order
    var startsAt: Date              // starts_at
    var endsAt: Date                // ends_at
    var source: QuestSource         // source

    enum CodingKeys: String, CodingKey {
        case prompt, checkable, order, source
        case startsAt = "starts_at"
        case endsAt = "ends_at"
    }

    func isActive(at date: Date) -> Bool { startsAt <= date && date < endsAt }

    /// The quest running at `date`. If several overlap, the lowest `order` wins.
    static func current(in quests: [Quest], at date: Date) -> Quest? {
        quests.filter { $0.isActive(at: date) }.min { $0.order < $1.order }
    }
}

// MARK: - What the Camera shows

/// The prompt on the Camera screen, whichever source it came from.
struct CameraQuest: Equatable {
    enum Source: Equatable {
        case group      // groups/{groupId}/quests
        case builtIn    // BuiltInQuests
    }

    var id: String                  // saved on the photo as quest_id
    var prompt: String              // saved on the photo as quest_prompt
    var endsAt: Date
    var source: Source

    init(id: String, prompt: String, endsAt: Date, source: Source) {
        self.id = id
        self.prompt = prompt
        self.endsAt = endsAt
        self.source = source
    }

    init(quest: Quest) {
        self.init(id: quest.id ?? "quest-\(quest.order)", prompt: quest.prompt, endsAt: quest.endsAt, source: .group)
    }

    /// "1 hr 20 min left", "12 min left", "Less than a minute left".
    func timeLeftText(from now: Date) -> String {
        let seconds = max(0, Int(endsAt.timeIntervalSince(now)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return minutes > 0 ? "\(hours) hr \(minutes) min left" : "\(hours) hr left"
        }
        if minutes > 0 { return "\(minutes) min left" }
        return "Less than a minute left"
    }
}

// MARK: - Built-in prompts (Version 1)

/// A fixed list of prompts so every group has one before Gemini prompts (Version 2).
///
/// Prompts change every `window` (2 hours), counted from when the group was created.
/// The order is shuffled per group with a stable hash of the group's ID, so every
/// member of a group sees the same prompt at the same time without any server.
enum BuiltInQuests {
    static let window: TimeInterval = 2 * 60 * 60

    static let general = [
        "Take a photo of the whole group together",
        "Snap someone mid-laugh",
        "Capture the best outfit here",
        "Take a photo of something blue",
        "Get a picture with someone you just met",
        "Photograph the snacks",
        "Take a photo with the tallest person in the room",
        "Capture a candid moment",
        "Find something that sums up today",
        "Take a photo of the best view",
        "Get a group photo making silly faces",
        "Snap a photo of someone's shoes",
    ]

    static let party = [
        "Take a photo with the tallest person in the room",
        "Capture the dance floor",
        "Snap a photo of the host",
        "Get a photo of the best dance move",
        "Photograph the snack table",
        "Get a group photo with everyone pointing at the camera",
        "Capture someone telling a story",
        "Take a photo of whoever is picking the music",
        "Snap a photo of matching outfits",
        "Find the coziest corner of the party",
        "Take a photo with someone you haven't talked to yet",
        "Capture the best laugh of the night",
    ]

    static let vacation = [
        "Take a photo of a statue",
        "Capture the best view of the day",
        "Photograph a local snack",
        "Take a group photo in front of a landmark",
        "Snap a street sign with a fun name",
        "Capture your ride: train, bus, car or boat",
        "Take a photo of something you've never seen before",
        "Find something the color of the sunset",
        "Photograph the best meal of the trip",
        "Take a photo of a sign pointing somewhere new",
        "Capture someone taking a photo",
        "Snap a souvenir you'd actually buy",
    ]

    /// Group modes are free text for now ("" until the Create Group form has a picker).
    static func modeKey(for mode: String) -> String {
        switch mode.trimmingCharacters(in: .whitespaces).lowercased() {
        case "party": return "party"
        case "travel", "vacation": return "vacation"
        default: return "general"
        }
    }

    static func prompts(forMode mode: String) -> [String] {
        switch modeKey(for: mode) {
        case "party": return party
        case "vacation": return vacation
        default: return general
        }
    }

    static func quest(for group: Group, at date: Date) -> CameraQuest? {
        quest(groupKey: group.id ?? group.name, mode: group.mode,
              startedAt: group.createdAt, endsAt: group.revealAt, at: date)
    }

    /// The built-in quest for a group at `date`, or nil once the event has ended.
    static func quest(groupKey: String, mode: String, startedAt: Date, endsAt: Date, at date: Date) -> CameraQuest? {
        guard date < endsAt else { return nil }
        let prompts = prompts(forMode: mode)
        guard !prompts.isEmpty else { return nil }

        let elapsed = max(0, date.timeIntervalSince(startedAt))
        let windowIndex = Int(elapsed / window)
        let offset = Int(stableHash(groupKey) % UInt64(prompts.count))
        let index = (offset + windowIndex) % prompts.count
        let windowEnd = startedAt.addingTimeInterval(Double(windowIndex + 1) * window)

        return CameraQuest(id: "builtin-\(modeKey(for: mode))-\(index)",
                           prompt: prompts[index],
                           endsAt: min(windowEnd, endsAt),
                           source: .builtIn)
    }

    /// FNV-1a. Swift's `hashValue` changes every launch, so it can't be used to
    /// make two phones agree; this gives the same number everywhere.
    static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
