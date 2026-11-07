//
//  CaptureDestination.swift
//  Axolotls
//
//  Part C (Photos). Decides where a photo from the Home capture button goes,
//  following the Sprint 3 user-testing lessons:
//    • in one active group  → straight to the camera for that group
//    • in several           → pick the group first
//    • in none              → nothing to send to yet
//  (The camera button inside a group page always uses that group.)
//

import Foundation

enum CaptureDestination {
    case noGroups
    case single(Group)
    case choose([Group])

    /// Only groups whose event hasn't ended can take new photos. When there's a
    /// choice, the group revealing soonest is listed first.
    static func resolve(from groups: [Group], at date: Date) -> CaptureDestination {
        let open = groups
            .filter { $0.revealAt > date }
            .sorted { $0.revealAt < $1.revealAt }

        switch open.count {
        case 0: return .noGroups
        case 1: return .single(open[0])
        default: return .choose(open)
        }
    }
}
