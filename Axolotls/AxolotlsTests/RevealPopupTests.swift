//
//  RevealPopupTests.swift
//  AxolotlsTests
//
//  The "Your photos are ready!" popup should only ever show once per group.
//

import Foundation
import Testing
@testable import Axolotls

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func endedGroup(_ id: String, minutesAgo: Double = 5) -> Group {
    Group(id: id, name: id, description: "", mode: "party", createdAt: now.addingTimeInterval(-86_400),
          revealAt: now.addingTimeInterval(-minutesAgo * 60), joinCode: "123456")
}

private func makeStore() -> FileRevealSeenStore {
    let suite = "RevealPopupTests-\(UUID().uuidString)"
    return FileRevealSeenStore(
        fileURL: FileManager.default.temporaryDirectory.appending(path: "\(suite).json"),
        legacyDefaults: UserDefaults(suiteName: suite)!
    )
}

@MainActor
struct RevealPopupTests {
    @Test func showsAnEndedGroup() {
        let viewModel = GroupRevealViewModel(store: makeStore(), now: { now })
        viewModel.check([endedGroup("trip")])
        #expect(viewModel.readyGroup?.id == "trip")
    }

    @Test func doesNotShowAgainAfterRelaunchEvenIfNoButtonWasTapped() {
        let store = makeStore()
        GroupRevealViewModel(store: store, now: { now }).check([endedGroup("trip")])

        // a fresh view model is what the app gets after being closed and reopened
        let relaunched = GroupRevealViewModel(store: store, now: { now })
        relaunched.check([endedGroup("trip")])
        #expect(relaunched.readyGroup == nil)
    }

    @Test func eachGroupShowsOnceThenTheNext() {
        let store = makeStore()
        let groups = [endedGroup("trip", minutesAgo: 5), endedGroup("party", minutesAgo: 60)]
        let viewModel = GroupRevealViewModel(store: store, now: { now })

        viewModel.check(groups)
        #expect(viewModel.readyGroup?.id == "party")    // ended first
        _ = viewModel.revealAlbumTapped()

        viewModel.check(groups)
        #expect(viewModel.readyGroup?.id == "trip")
        _ = viewModel.guessTapped()

        viewModel.check(groups)
        #expect(viewModel.readyGroup == nil)
    }

    @Test func seenGroupsAreSavedToDisk() {
        let store = makeStore()
        store.markSeen(groupID: "trip")
        let reopened = FileRevealSeenStore(fileURL: store.fileURL, legacyDefaults: store.legacyDefaults)
        #expect(reopened.hasSeen(groupID: "trip"))
        #expect(!reopened.hasSeen(groupID: "party"))
    }

    @Test func keepsGroupsSeenInOlderBuilds() {
        let store = makeStore()
        store.legacyDefaults.set(["trip"], forKey: "revealSeenGroupIDs")
        #expect(store.hasSeen(groupID: "trip"))
    }
}
