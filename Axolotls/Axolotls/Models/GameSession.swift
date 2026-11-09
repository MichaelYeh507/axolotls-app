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
    static let minimumPlayers = 2
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

    var timeline: GameTimeline? {
        startedAt.map { GameTimeline(startedAt: $0, roundCount: rounds.count) }
    }

    //the owner starts if they're playing; otherwise anyone who's ready can
    func canStart(userId: String, ownerId: String?) -> Bool {
        guard gameStatus == .lobby,
              readyIds.count >= Self.minimumPlayers,
              readyIds.contains(userId) else { return false }
        guard let ownerId, readyIds.contains(ownerId) else { return true }
        return userId == ownerId
    }

    //whether someone opening the game should land in this session
    func isActive(at date: Date) -> Bool {
        switch gameStatus {
        case .lobby:
            return date.timeIntervalSince(createdAt) < Self.lobbyLifetime
        case .playing:
            guard let timeline else { return false }
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

//every phone works out the current question from the shared start time,
//so the game keeps going even if the person who started it drops out
struct GameTimeline {
    static let answerSeconds: TimeInterval = 15
    static let resultSeconds: TimeInterval = 3
    static var roundSeconds: TimeInterval { answerSeconds + resultSeconds }

    let startedAt: Date
    let roundCount: Int

    var endsAt: Date { startedAt.addingTimeInterval(Double(roundCount) * Self.roundSeconds) }

    func roundStart(_ round: Int) -> Date {
        startedAt.addingTimeInterval(Double(round) * Self.roundSeconds)
    }

    func phase(at date: Date) -> GamePhase {
        let elapsed = date.timeIntervalSince(startedAt)
        if elapsed < 0 { return .countdown(secondsLeft: Int((-elapsed).rounded(.up))) }
        guard date < endsAt else { return .finished }

        let round = Int(elapsed / Self.roundSeconds)
        let intoRound = elapsed - Double(round) * Self.roundSeconds
        if intoRound < Self.answerSeconds {
            return .answering(round: round, secondsLeft: Int((Self.answerSeconds - intoRound).rounded(.up)))
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
        guard let timeline = session.timeline else { return [] }

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
