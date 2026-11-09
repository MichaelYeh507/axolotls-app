//
//  LiveGameTests.swift
//  AxolotlsTests
//
//  Multiplayer game rules. No network: Firebase is replaced by fakes.
//

import Foundation
import Testing
@testable import Axolotls

private let start = Date(timeIntervalSince1970: 1_800_000_000)

private func makeRounds(_ count: Int) -> [GameRoundPlan] {
    (0..<count).map { GameRoundPlan(photoId: "p\($0)", candidateIds: ["owner", "amy", "ben"]) }
}

private func makeSession(status: GameStatus = .lobby, ready: [String] = [], participants: [String] = [],
                         rounds: Int = 0, startedAt: Date? = nil, createdAt: Date = start) -> GameSession {
    var session = GameSession(groupId: "g", hostId: "owner", createdAt: createdAt)
    session.id = "s"
    session.gameStatus = status
    session.readyIds = ready
    session.participantIds = participants
    session.rounds = makeRounds(rounds)
    session.startedAt = startedAt
    return session
}

private func makeGuess(user: String, round: Int, correct: Bool, after seconds: TimeInterval) -> PhotoGuess {
    PhotoGuess(gameSessionId: "s", userId: user, round: round, photoId: "p\(round)", selectedUserId: "x",
               isCorrect: correct,
               answeredAt: start.addingTimeInterval(Double(round) * GameTimeline.roundSeconds + seconds))
}

private final class Clock {
    var date: Date
    init(_ date: Date) { self.date = date }
}

private struct UnusedPhotos: GroupPhotoReading {
    func photos(inGroup groupId: String) async throws -> [GroupPhoto] { [] }
    func imageData(for photo: GroupPhoto, maxSize: Int64) async throws -> Data { Data() }
}

private struct AlbumPhotos: GroupPhotoReading {
    func photos(inGroup groupId: String) async throws -> [GroupPhoto] {
        (0..<2).map {
            GroupPhoto(id: "p\($0)", photoAsset: "p\($0).jpg", groupId: "g", photographerId: "ben", capturedAt: start)
        }
    }
    func imageData(for photo: GroupPhoto, maxSize: Int64) async throws -> Data { Data() }
}

@MainActor
private final class FakeGameService: GameSessionServing {
    var submitted: [PhotoGuess] = []
    var startedRounds: [GameRoundPlan]?

    func roster(groupId: String, photographerIds: Set<String>) async throws -> GameRoster {
        GameRoster(players: [GamePlayer(id: "amy", name: "Amy"), GamePlayer(id: "ben", name: "Ben")], ownerId: nil)
    }
    func joinOrCreateSession(groupId: String, userId: String, now: Date) async throws -> String { "s" }
    func sessionUpdates(groupId: String, sessionId: String) -> AsyncThrowingStream<GameSession, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func guessUpdates(groupId: String, sessionId: String) -> AsyncThrowingStream<[PhotoGuess], Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func setReady(_ isReady: Bool, groupId: String, sessionId: String, userId: String) async throws {}
    func startGame(groupId: String, sessionId: String, userId: String, ownerId: String?,
                   rounds: [GameRoundPlan], startsAt: Date) async throws {
        startedRounds = rounds
    }
    func submit(_ guess: PhotoGuess, groupId: String, sessionId: String) async throws {
        submitted.append(guess)
    }
    func markFinished(groupId: String, sessionId: String, at date: Date) async throws {}
}

struct GameTimelineTests {
    private let timeline = GameTimeline(startedAt: start, roundCount: 10)

    @Test func countsDownBeforeTheStart() {
        #expect(timeline.phase(at: start.addingTimeInterval(-2.5)) == .countdown(secondsLeft: 3))
    }

    @Test func eachPhotoGets15Seconds() {
        #expect(timeline.phase(at: start) == .answering(round: 0, secondsLeft: 15))
        #expect(timeline.phase(at: start.addingTimeInterval(14.5)) == .answering(round: 0, secondsLeft: 1))
        #expect(timeline.phase(at: start.addingTimeInterval(15)) == .result(round: 0))
    }

    @Test func movesToTheNextPhotoAfterTheAnswerIsShown() {
        #expect(timeline.phase(at: start.addingTimeInterval(18)) == .answering(round: 1, secondsLeft: 15))
    }

    @Test func finishesAfterTheLastPhoto() {
        #expect(timeline.phase(at: start.addingTimeInterval(179.9)) == .result(round: 9))
        #expect(timeline.phase(at: start.addingTimeInterval(180)) == .finished)
    }
}

struct GameStartRuleTests {
    @Test func ownerStartsWhenTheyArePlaying() {
        let session = makeSession(ready: ["owner", "amy"])
        #expect(session.canStart(userId: "owner", ownerId: "owner"))
        #expect(!session.canStart(userId: "amy", ownerId: "owner"))
    }

    @Test func anyoneReadyCanStartWhenTheOwnerIsNotPlaying() {
        let session = makeSession(ready: ["amy", "ben"])
        #expect(session.canStart(userId: "amy", ownerId: "owner"))
        #expect(session.canStart(userId: "ben", ownerId: "owner"))
    }

    @Test func anOwnerWhoIsNotReadyCannotStart() {
        #expect(!makeSession(ready: ["amy", "ben"]).canStart(userId: "owner", ownerId: "owner"))
    }

    @Test func needsTwoReadyPlayers() {
        #expect(!makeSession(ready: ["owner"]).canStart(userId: "owner", ownerId: "owner"))
    }

    @Test func canOnlyStartFromTheLobby() {
        #expect(!makeSession(status: .playing, ready: ["owner", "amy"]).canStart(userId: "owner", ownerId: "owner"))
    }

    @Test func worksWhenTheGroupHasNoOwner() {
        #expect(makeSession(ready: ["amy", "ben"]).canStart(userId: "amy", ownerId: nil))
    }
}

struct GameSessionActivityTests {
    @Test func abandonedLobbyExpires() {
        let lobby = makeSession()
        #expect(lobby.isActive(at: start.addingTimeInterval(60)))
        #expect(!lobby.isActive(at: start.addingTimeInterval(GameSession.lobbyLifetime)))
    }

    @Test func gameIsActiveUntilItsTimelineEnds() {
        let game = makeSession(status: .playing, rounds: 10, startedAt: start)
        #expect(game.isActive(at: start.addingTimeInterval(179)))
        #expect(!game.isActive(at: start.addingTimeInterval(180)))
    }
}

struct GameLeaderboardTests {
    private let session = makeSession(status: .playing, participants: ["amy", "ben", "cat"], rounds: 3, startedAt: start)

    @Test func mostCorrectAnswersWins() {
        let guesses = [makeGuess(user: "ben", round: 0, correct: true, after: 5),
                       makeGuess(user: "ben", round: 1, correct: true, after: 5),
                       makeGuess(user: "amy", round: 0, correct: true, after: 1)]
        #expect(GameLeaderboard.entries(session: session, guesses: guesses) { $0 }.map(\.id) == ["ben", "amy", "cat"])
    }

    @Test func fasterCorrectAnswersBreakTies() {
        let guesses = [makeGuess(user: "amy", round: 0, correct: true, after: 9),
                       makeGuess(user: "ben", round: 0, correct: true, after: 2)]
        #expect(GameLeaderboard.entries(session: session, guesses: guesses) { $0 }.map(\.id) == ["ben", "amy", "cat"])
    }

    @Test func wrongAnswersDoNotScore() {
        let guesses = [makeGuess(user: "amy", round: 0, correct: false, after: 1)]
        #expect(GameLeaderboard.entries(session: session, guesses: guesses) { $0 }.first { $0.id == "amy" }?.score == 0)
    }

    @Test func playersWhoNeverAnsweredStillAppear() {
        #expect(GameLeaderboard.entries(session: session, guesses: []) { $0 }.count == 3)
    }
}

@MainActor
struct GuessGameLiveTests {
    private func makeViewModel(service: FakeGameService, clock: Clock) -> GuessGameViewModel {
        GuessGameViewModel(groupId: "g", photoService: UnusedPhotos(), gameService: service, now: { clock.date })
    }

    @Test func staysLoadingUntilASessionArrives() {
        #expect(makeViewModel(service: FakeGameService(), clock: Clock(start)).stage == .loading)
    }

    @Test func emptyAlbumHasNothingToPlay() async {
        let viewModel = makeViewModel(service: FakeGameService(), clock: Clock(start))
        await viewModel.run(userId: "amy")
        #expect(viewModel.stage == .noPhotos)
    }

    /// Connects as "amy" to a game that started at `start`, where "ben" took every photo.
    private func joinStartedGame(service: FakeGameService, clock: Clock,
                                 participants: [String] = ["amy", "ben"]) async -> (GuessGameViewModel, Task<Void, Never>) {
        let viewModel = GuessGameViewModel(groupId: "g", photoService: AlbumPhotos(), gameService: service,
                                           now: { clock.date })
        let connection = Task { await viewModel.run(userId: "amy") }
        while viewModel.players.isEmpty { await Task.yield() }
        viewModel.receive(session: makeSession(status: .playing, participants: participants, rounds: 2, startedAt: start))
        return (viewModel, connection)
    }

    @Test func correctGuessIsSaved() async throws {
        let service = FakeGameService()
        let clock = Clock(start.addingTimeInterval(4))
        let (viewModel, connection) = await joinStartedGame(service: service, clock: clock)
        defer { connection.cancel() }

        await viewModel.guess(GamePlayer(id: "ben", name: "Ben"))

        let saved = try #require(service.submitted.first)
        #expect(saved.isCorrect)
        #expect(saved.round == 0)
        #expect(saved.documentId == "0_amy")
    }

    @Test func wrongGuessIsNotCorrect() async throws {
        let service = FakeGameService()
        let (viewModel, connection) = await joinStartedGame(service: service, clock: Clock(start))
        defer { connection.cancel() }

        await viewModel.guess(GamePlayer(id: "amy", name: "Amy"))

        #expect(try #require(service.submitted.first).isCorrect == false)
    }

    @Test func onlyTheFirstGuessCounts() async {
        let service = FakeGameService()
        let (viewModel, connection) = await joinStartedGame(service: service, clock: Clock(start))
        defer { connection.cancel() }

        await viewModel.guess(GamePlayer(id: "amy", name: "Amy"))
        await viewModel.guess(GamePlayer(id: "ben", name: "Ben"))

        #expect(service.submitted.count == 1)
    }

    @Test func guessAfterTheTimerIsIgnored() async {
        let service = FakeGameService()
        let (viewModel, connection) = await joinStartedGame(service: service, clock: Clock(start.addingTimeInterval(15)))
        defer { connection.cancel() }

        await viewModel.guess(GamePlayer(id: "ben", name: "Ben"))

        #expect(service.submitted.isEmpty)
    }

    @Test func someoneWhoWasNotReadyWaitsForTheNextGame() async {
        let (viewModel, connection) = await joinStartedGame(service: FakeGameService(), clock: Clock(start),
                                                            participants: ["ben", "cat"])
        defer { connection.cancel() }

        #expect(viewModel.stage == .alreadyStarted)
    }

    @Test func leaderboardRanksFromReceivedGuesses() {
        let viewModel = makeViewModel(service: FakeGameService(), clock: Clock(start))
        viewModel.receive(session: makeSession(status: .playing, participants: ["amy", "ben"], rounds: 2, startedAt: start))
        viewModel.receive(guesses: [makeGuess(user: "ben", round: 0, correct: true, after: 2)])
        #expect(viewModel.leaderboard.map(\.id) == ["ben", "amy"])
    }
}
