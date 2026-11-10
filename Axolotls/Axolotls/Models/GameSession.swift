//
//  GameSession.swift
//  Axolotls
//
//  Mirrors groups/{groupId}/game_sessions/{id} and its guesses from the Sprint 3
//  data design, plus the rules for the live multiplayer game.
//

import Foundation
import FirebaseFirestore

enum GameStatus: String, Codable {
    case lobby, playing, finished
}

//one question: the photo and the people to pick from
struct GameRoundPlan: Codable, Hashable {
    var photoId: String
    var candidateIds: [String]

    enum CodingKeys: String, CodingKey {
        case photoId = "photo_id"
        case candidateIds = "candidate_ids"
    }
}

struct GameSession: Codable, Identifiable {
    static let minimumPlayers = 1
    static let lobbyLifetime: TimeInterval = 30 * 60

    @DocumentID var id: String?
    var groupId: String
    var hostId: String
    var participantIds: [String] = []
    var readyIds: [String] = []
    var gameStatus: GameStatus = .lobby
    var rounds: [GameRoundPlan] = []
    var currentRound = 0                // kept for the Sprint 3 schema; phones use the timeline instead
    var createdAt: Date
    var startedAt: Date? = nil
    var finishedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case hostId = "host_id"
        case participantIds = "participant_ids"
        case readyIds = "ready_ids"
        case gameStatus = "game_status"
        case rounds
        case currentRound = "current_round"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
    }

    //the guesses let a round end early once every player has locked in
    func timeline(guesses: [PhotoGuess] = []) -> GameTimeline? {
        startedAt.map {
            GameTimeline(startedAt: $0, roundCount: rounds.count, participantIds: participantIds, guesses: guesses)
        }
    }

    //anyone who's ready can start the game
    func canStart(userId: String) -> Bool {
        gameStatus == .lobby
            && readyIds.count >= Self.minimumPlayers
            && readyIds.contains(userId)
    }

    //whether someone opening the game should land in this session
    func isActive(at date: Date) -> Bool {
        switch gameStatus {
        case .lobby:
            return date.timeIntervalSince(createdAt) < Self.lobbyLifetime
        case .playing:
            // without guesses this is the longest the game can run
            guard let timeline = timeline() else { return false }
            return date < timeline.endsAt
        case .finished:
            return false
        }
    }
}

//one player's answer. The document ID "{round}_{userId}" allows one guess per round.
struct PhotoGuess: Codable {
    var gameSessionId: String
    var userId: String
    var round: Int
    var photoId: String
    var selectedUserId: String
    var isCorrect: Bool
    var answeredAt: Date

    enum CodingKeys: String, CodingKey {
        case gameSessionId = "game_session_id"
        case userId = "user_id"
        case round
        case photoId = "photo_id"
        case selectedUserId = "selected_user_id"
        case isCorrect = "is_correct"
        case answeredAt = "answered_at"
    }

    var documentId: String { "\(round)_\(userId)" }
}

enum GamePhase: Equatable {
    case countdown(secondsLeft: Int)
    case answering(round: Int, secondsLeft: Int)
    case result(round: Int)
    case finished
}

//every phone works out the current question from the shared start time and the
//shared guesses, so the game keeps going even if the person who started it drops out.
//A round's answer time ends at the 15 second deadline, or as soon as every player
//has locked in; later rounds shift earlier to match.
struct GameTimeline {
    static let answerSeconds: TimeInterval = 15
    static let resultSeconds: TimeInterval = 3
    static var roundSeconds: TimeInterval { answerSeconds + resultSeconds }

    let startedAt: Date
    let roundCount: Int
    private let roundStarts: [Date]
    private let answerEnds: [Date]

    init(startedAt: Date, roundCount: Int, participantIds: [String] = [], guesses: [PhotoGuess] = []) {
        self.startedAt = startedAt
        self.roundCount = roundCount

        let players = Set(participantIds)
        var starts: [Date] = []
        var ends: [Date] = []
        var cursor = startedAt
        for round in 0..<max(roundCount, 0) {
            let deadline = cursor.addingTimeInterval(Self.answerSeconds)
            let roundGuesses = guesses.filter { $0.round == round && players.contains($0.userId) }
            var end = deadline
            if !players.isEmpty, Set(roundGuesses.map(\.userId)) == players,
               let lastLockIn = roundGuesses.map(\.answeredAt).max() {
                // clamped so a phone with a wrong clock can't push the round outside its window
                end = min(max(lastLockIn, cursor), deadline)
            }
            starts.append(cursor)
            ends.append(end)
            cursor = end.addingTimeInterval(Self.resultSeconds)
        }
        roundStarts = starts
        answerEnds = ends
    }

    var endsAt: Date {
        answerEnds.last?.addingTimeInterval(Self.resultSeconds) ?? startedAt
    }

    func roundStart(_ round: Int) -> Date {
        roundStarts.indices.contains(round)
            ? roundStarts[round]
            : startedAt.addingTimeInterval(Double(round) * Self.roundSeconds)
    }

    func phase(at date: Date) -> GamePhase {
        let elapsed = date.timeIntervalSince(startedAt)
        if elapsed < 0 { return .countdown(secondsLeft: Int((-elapsed).rounded(.up))) }
        guard date < endsAt, let round = roundStarts.lastIndex(where: { $0 <= date }) else { return .finished }

        if date < answerEnds[round] {
            // the timer always counts down to the deadline, even if everyone may lock in sooner
            let deadline = roundStarts[round].addingTimeInterval(Self.answerSeconds)
            return .answering(round: round, secondsLeft: Int(deadline.timeIntervalSince(date).rounded(.up)))
        }
        return .result(round: round)
    }
}

struct LeaderboardEntry: Identifiable, Equatable {
    let id: String      // user id
    let name: String
    let score: Int
    let correctAnswerSeconds: TimeInterval
}

enum GameLeaderboard {
    //most correct answers first; ties go to whoever answered correctly fastest
    static func entries(session: GameSession, guesses: [PhotoGuess],
                        name: (String) -> String) -> [LeaderboardEntry] {
        guard let timeline = session.timeline(guesses: guesses) else { return [] }

        return session.participantIds.map { userId in
            let correct = guesses.filter { $0.userId == userId && $0.isCorrect }
            let seconds = correct.reduce(0) { total, guess in
                total + guess.answeredAt.timeIntervalSince(timeline.roundStart(guess.round))
            }
            return LeaderboardEntry(id: userId, name: name(userId), score: correct.count,
                                    correctAnswerSeconds: seconds)
        }
        .sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.correctAnswerSeconds != $1.correctAnswerSeconds {
                return $0.correctAnswerSeconds < $1.correctAnswerSeconds
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
