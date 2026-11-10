//
//  GroupReveal.swift
//  Axolotls
//
//  Created by Lily Beerhalter on 11/6/26.
//

import Foundation

//remembers which groups have already shown their reveal popup
protocol RevealSeenStore {
    func hasSeen(groupID: String) -> Bool
    func markSeen(groupID: String)
}

//default store, saved to a file so the popup doesn't come back after relaunch.
//The file is written to disk right away. UserDefaults only saves every few seconds,
//so quitting the app (or stopping it from Xcode) could lose the "seen" mark.
struct FileRevealSeenStore: RevealSeenStore {
    var fileURL: URL = URL.applicationSupportDirectory.appending(path: "revealSeenGroupIDs.json")
    var legacyDefaults: UserDefaults = .standard     // where older builds kept the list
    private static let legacyKey = "revealSeenGroupIDs"

    func hasSeen(groupID: String) -> Bool {
        seenIDs.contains(groupID)
    }

    func markSeen(groupID: String) {
        var ids = seenIDs
        guard ids.insert(groupID).inserted else { return }
        save(ids)
    }

    private var seenIDs: Set<String> {
        let legacy = Set(legacyDefaults.stringArray(forKey: Self.legacyKey) ?? [])
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([String].self, from: data) else { return legacy }
        return legacy.union(saved)
    }

    private func save(_ ids: Set<String>) {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(ids.sorted()).write(to: fileURL, options: .atomic)
        } catch {
            // the popup just shows again next launch; nothing else depends on this
        }
    }
}

enum GroupReveal {
    //if an ended group existed show its popup now
    //if several have ended, the one that ended first goes first
    static func nextReady(in groups: [Group], at date: Date, store: RevealSeenStore) -> Group? {
        groups
            .filter { group in
                guard let id = group.id else { return false }
                return group.revealAt <= date && !store.hasSeen(groupID: id)
            }
            .min { $0.revealAt < $1.revealAt }
    }

    //the soonest reveal time still in the future
    static func nextRevealTime(in groups: [Group], after date: Date) -> Date? {
        groups.map(\.revealAt).filter { $0 > date }.min()
    }
}
