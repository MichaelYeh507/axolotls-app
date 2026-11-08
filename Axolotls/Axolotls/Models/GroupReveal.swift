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

//default store, backed by UserDefaults so the popup doesn't come back after relaunch.
struct UserDefaultsRevealSeenStore: RevealSeenStore {
    var defaults: UserDefaults = .standard
    private let key = "revealSeenGroupIDs"

    func hasSeen(groupID: String) -> Bool {
        seenIDs.contains(groupID)
    }

    func markSeen(groupID: String) {
        var ids = seenIDs
        ids.insert(groupID)
        defaults.set(Array(ids), forKey: key)
    }

    private var seenIDs: Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
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
