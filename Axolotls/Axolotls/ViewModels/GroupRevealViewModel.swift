//
//  GroupRevealViewModel.swift
//  Axolotls
//
//  Created by Lily Beerhalter on 11/6/26.
//

import Foundation
import Observation

//where the reveal popup can send you
enum RevealRoute: Hashable {
    case guessPhotoTakers(groupID: String)
    case album(groupID: String)
}

@MainActor
@Observable
final class GroupRevealViewModel {
    //group whose popup is showing, or nil when hidden
    private(set) var readyGroup: Group?

    private let store: RevealSeenStore
    private let now: () -> Date

    init(store: RevealSeenStore? = nil, now: @escaping () -> Date = Date.init) {
        self.store = store ?? UserDefaultsRevealSeenStore()
        self.now = now
    }

    //shows the popup if one of these groups has ended and hasn't been revealed yet.
    func check(_ groups: [Group]) {
        guard readyGroup == nil else { return }
        readyGroup = GroupReveal.nextReady(in: groups, at: now(), store: store)
    }

    //keeps  popup on time while the app is open: sleeps until the next
    //group ends, then checks again. Cancelled automatically by .task.
    func watch(_ groups: [Group]) async {
        check(groups)
        while let next = GroupReveal.nextRevealTime(in: groups, after: now()) {
            let wait = next.timeIntervalSince(now())
            do {
                try await Task.sleep(for: .seconds(max(wait, 0) + 0.5))
            } catch {
                return // view went away
            }
            check(groups)
        }
    }

    //"Guess the Photo Takers" tapped
    func guessTapped() -> RevealRoute? {
        guard let id = dismissPopup() else { return nil }
        return .guessPhotoTakers(groupID: id)
    }

    //"Reveal the Album" tapped
    func revealAlbumTapped() -> RevealRoute? {
        guard let id = dismissPopup() else { return nil }
        return .album(groupID: id)
    }

    //hides the popup and remembers it was shown, so it won't pop up again
    private func dismissPopup() -> String? {
        guard let id = readyGroup?.id else { return nil }
        store.markSeen(groupID: id)
        readyGroup = nil
        return id
    }
}
