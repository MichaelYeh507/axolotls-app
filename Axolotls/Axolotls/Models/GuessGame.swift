//
//  GuessGame.swift
//  Axolotls
//
//  Created by Lily Beerhalter on 11/7/26.
//

import Foundation

//someone you can guess as the photo taker
struct GamePlayer: Identifiable, Hashable {
    let id: String      // user id
    let name: String
}

//one photo in the game and the guess made for it
struct GuessRound: Identifiable {
    let photo: GroupPhoto
    let choices: [GamePlayer]          // the buttons shown (max 6, always includes the answer)
    var guessedPlayerId: String? = nil

    var id: String { photo.id ?? photo.photoAsset }
    var answerId: String { photo.photographerId }
    var hasGuessed: Bool { guessedPlayerId != nil }
    var isCorrect: Bool { guessedPlayerId == answerId }
}

//the rules of one game: up to 10 random photos, one guess each
struct GuessGame {
    static let maxRounds = 10
    static let maxChoices = 6

    private(set) var rounds: [GuessRound]
    private(set) var currentIndex = 0

    //picks up to 10 random photos; if there are fewer, uses all of them
    init<R: RandomNumberGenerator>(photos: [GroupPhoto], players: [GamePlayer], using generator: inout R) {
        rounds = photos
            .shuffled(using: &generator)
            .prefix(Self.maxRounds)
            .map { photo in
                GuessRound(photo: photo,
                           choices: Self.choices(for: photo, from: players, using: &generator))
            }
    }

    init(photos: [GroupPhoto], players: [GamePlayer]) {
        var generator = SystemRandomNumberGenerator()
        self.init(photos: photos, players: players, using: &generator)
    }

    //up to 6 people for one photo: the real photographer plus random others.
    //keeps the order of players alphabetical so the answer's spot doesn't give it away
    private static func choices<R: RandomNumberGenerator>(for photo: GroupPhoto, from players: [GamePlayer],
                                                          using generator: inout R) -> [GamePlayer] {
        guard players.count > maxChoices else { return players }

        let others = players
            .filter { $0.id != photo.photographerId }
            .shuffled(using: &generator)
            .prefix(maxChoices - 1)
        let picked = Set(others.map(\.id)).union([photo.photographerId])
        return players.filter { picked.contains($0.id) }
    }

    var isEmpty: Bool { rounds.isEmpty }
    var isFinished: Bool { currentIndex >= rounds.count }
    var current: GuessRound? { isFinished ? nil : rounds[currentIndex] }
    var score: Int { rounds.filter(\.isCorrect).count }
    var roundNumber: Int { min(currentIndex + 1, rounds.count) }

    //locks in a guess for the current photo (only the first guess counts)
    mutating func guess(_ playerId: String) {
        guard !isFinished, !rounds[currentIndex].hasGuessed else { return }
        rounds[currentIndex].guessedPlayerId = playerId
    }

    //moves on to the next photo once the current one has been guessed
    mutating func next() {
        guard let current, current.hasGuessed else { return }
        currentIndex += 1
    }
}
