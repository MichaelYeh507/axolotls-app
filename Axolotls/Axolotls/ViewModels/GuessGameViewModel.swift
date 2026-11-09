//
//  GuessGameViewModel.swift
//  Axolotls
//
//  Created by Lily Beerhalter on 11/7/26.
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class GuessGameViewModel {
    enum Stage: Equatable {
        case loading
        case failed(String)
        case noPhotos
        case lobby
        case alreadyStarted
        case countdown(secondsLeft: Int)
        case answering(round: Int, secondsLeft: Int)
        case result(round: Int)
        case finished
    }

    private(set) var gameSession: GameSession?
    private(set) var guesses: [PhotoGuess] = []
    private(set) var players: [GamePlayer] = []
    private(set) var images: [String: UIImage] = [:]   // photo id -> image
    private(set) var failedImageIds: Set<String> = []
    private(set) var isStarting = false
    var actionError: String?

    private let groupId: String
    private let photoService: GroupPhotoReading
    private let gameService: GameSessionServing
    private let now: () -> Date

    private var allPhotos: [GroupPhoto] = []
    private var ownerId: String?
    private(set) var userId: String?
    private var loadError: String?
    private var hasNoPhotos = false
    private var currentTime: Date
    private var localPicks: [Int: String] = [:]         // shows a pick before Firestore confirms it
    private var didMarkFinished = false

    private static let maxImageBytes: Int64 = 10 * 1024 * 1024
    private static let countdownSeconds: TimeInterval = 3

    init(groupId: String, photoService: GroupPhotoReading? = nil, gameService: GameSessionServing? = nil,
         now: @escaping () -> Date = Date.init) {
        self.groupId = groupId
        self.photoService = photoService ?? FirebasePhotoService()
        self.gameService = gameService ?? FirebaseGameSessionService()
        self.now = now
        self.currentTime = now()
    }

    // MARK: - Where the game is

    var stage: Stage {
        if let loadError { return .failed(loadError) }
        if hasNoPhotos { return .noPhotos }
        guard let gameSession, let userId else { return .loading }
        if gameSession.gameStatus == .lobby { return .lobby }
        guard gameSession.participantIds.contains(userId), let timeline = gameSession.timeline else {
            return .alreadyStarted
        }

        switch timeline.phase(at: currentTime) {
        case .countdown(let secondsLeft): return .countdown(secondsLeft: secondsLeft)
        case .answering(let round, let secondsLeft): return .answering(round: round, secondsLeft: secondsLeft)
        case .result(let round): return .result(round: round)
        case .finished: return .finished
        }
    }

    // MARK: - Connecting

    //joins the group's game and stays in sync until the view goes away
    func run(userId: String) async {
        self.userId = userId
        gameSession = nil
        guesses = []
        localPicks = [:]
        loadError = nil
        hasNoPhotos = false
        didMarkFinished = false

        do {
            allPhotos = try await photoService.photos(inGroup: groupId)
            guard !allPhotos.isEmpty else {
                hasNoPhotos = true
                return
            }
            let roster = try await gameService.roster(groupId: groupId,
                                                      photographerIds: Set(allPhotos.map(\.photographerId)))
            players = roster.players
            ownerId = roster.ownerId

            let sessionId = try await gameService.joinOrCreateSession(groupId: groupId, userId: userId, now: now())
            await withTaskGroup(of: Void.self) { tasks in
                tasks.addTask { await self.followSession(sessionId) }
                tasks.addTask { await self.followGuesses(sessionId) }
                tasks.addTask { await self.keepClockRunning() }
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            loadError = error.localizedDescription
        }
    }

    private func followSession(_ sessionId: String) async {
        do {
            for try await session in gameService.sessionUpdates(groupId: groupId, sessionId: sessionId) {
                receive(session: session)
            }
        } catch {
            if !Task.isCancelled { loadError = error.localizedDescription }
        }
    }

    private func followGuesses(_ sessionId: String) async {
        do {
            for try await update in gameService.guessUpdates(groupId: groupId, sessionId: sessionId) {
                receive(guesses: update)
            }
        } catch {
            if !Task.isCancelled { loadError = error.localizedDescription }
        }
    }

    private func keepClockRunning() async {
        while !Task.isCancelled {
            tick()
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
        }
    }

    func receive(session: GameSession) {
        gameSession = session
        currentTime = now()
    }

    func receive(guesses update: [PhotoGuess]) {
        guesses = update
    }

    func tick() {
        currentTime = now()
        guard stage == .finished, !didMarkFinished,
              gameSession?.gameStatus == .playing, let sessionId = gameSession?.id else { return }
        didMarkFinished = true
        let finishedAt = currentTime
        Task { try? await gameService.markFinished(groupId: groupId, sessionId: sessionId, at: finishedAt) }
    }

    // MARK: - Lobby

    var isReady: Bool {
        guard let userId else { return false }
        return gameSession?.readyIds.contains(userId) ?? false
    }

    var canStart: Bool {
        guard let userId else { return false }
        return gameSession?.canStart(userId: userId, ownerId: ownerId) ?? false
    }

    var readyCount: Int { gameSession?.readyIds.count ?? 0 }

    var readyPlayers: [GamePlayer] {
        let readyIds = gameSession?.readyIds ?? []
        return players.filter { readyIds.contains($0.id) }
    }

    //the owner, when they're the only one who can start right now
    var waitingForOwnerName: String? {
        guard let ownerId, ownerId != userId,
              gameSession?.readyIds.contains(ownerId) == true else { return nil }
        return name(for: ownerId)
    }

    func toggleReady() async {
        guard let userId, let sessionId = gameSession?.id else { return }
        do {
            try await gameService.setReady(!isReady, groupId: groupId, sessionId: sessionId, userId: userId)
        } catch {
            actionError = error.localizedDescription
        }
    }

    func start() async {
        guard canStart, let userId, let sessionId = gameSession?.id else { return }
        isStarting = true
        defer { isStarting = false }

        let rounds = GuessGame(photos: allPhotos, players: players).rounds.compactMap { round in
            round.photo.id.map { GameRoundPlan(photoId: $0, candidateIds: round.choices.map(\.id)) }
        }
        do {
            try await gameService.startGame(groupId: groupId, sessionId: sessionId, userId: userId, ownerId: ownerId,
                                            rounds: rounds, startsAt: now().addingTimeInterval(Self.countdownSeconds))
        } catch {
            actionError = error.localizedDescription
        }
    }

    //so someone who walks away from the lobby isn't pulled into the game
    func leaveLobby() {
        guard stage == .lobby, isReady, let userId, let sessionId = gameSession?.id else { return }
        Task { try? await gameService.setReady(false, groupId: groupId, sessionId: sessionId, userId: userId) }
    }

    // MARK: - Playing

    var roundCount: Int { gameSession?.rounds.count ?? 0 }

    func round(at index: Int) -> GuessRound? {
        guard let plan = gameSession?.rounds[safe: index],
              let photo = allPhotos.first(where: { $0.id == plan.photoId }) else { return nil }
        let choices = plan.candidateIds.map { GamePlayer(id: $0, name: name(for: $0)) }
        return GuessRound(photo: photo, choices: choices, guessedPlayerId: pick(forRound: index))
    }

    func pick(forRound index: Int) -> String? {
        localPicks[index] ?? guesses.first { $0.round == index && $0.userId == userId }?.selectedUserId
    }

    //only rounds whose answers have been shown, so the score can't give an answer away
    func myScore(throughRound lastRound: Int) -> Int {
        guesses.filter { $0.userId == userId && $0.isCorrect && $0.round <= lastRound }.count
    }

    func guess(_ player: GamePlayer) async {
        currentTime = now()
        guard case .answering(let index, _) = stage, pick(forRound: index) == nil,
              let round = round(at: index), let photoId = round.photo.id,
              let userId, let sessionId = gameSession?.id else { return }

        localPicks[index] = player.id
        let guess = PhotoGuess(gameSessionId: sessionId, userId: userId, round: index, photoId: photoId,
                               selectedUserId: player.id, isCorrect: player.id == round.answerId,
                               answeredAt: currentTime)
        do {
            try await gameService.submit(guess, groupId: groupId, sessionId: sessionId)
        } catch {
            localPicks[index] = nil
            actionError = error.localizedDescription
        }
    }

    var leaderboard: [LeaderboardEntry] {
        guard let gameSession else { return [] }
        return GameLeaderboard.entries(session: gameSession, guesses: guesses, name: name(for:))
    }

    func name(for userId: String) -> String {
        players.first { $0.id == userId }?.name ?? "Unknown"
    }

    // MARK: - Photos

    //loads every question's photo up front so a slow download doesn't eat into the 15 seconds
    func preloadImages() async {
        let photoIds = Set(gameSession?.rounds.map(\.photoId) ?? [])
        let photos = allPhotos.filter { photo in photo.id.map(photoIds.contains) ?? false }
        await withTaskGroup(of: Void.self) { tasks in
            for photo in photos {
                tasks.addTask { await self.loadImage(for: photo) }
            }
        }
    }

    //loads the picture for a photo, if it isn't already loaded
    func loadImage(for photo: GroupPhoto) async {
        guard let id = photo.id, images[id] == nil else { return }
        failedImageIds.remove(id) // back to the spinner while this attempt runs
        if let data = try? await photoService.imageData(for: photo, maxSize: Self.maxImageBytes),
           let image = UIImage(data: data) {
            images[id] = image
        } else {
            failedImageIds.insert(id)
        }
    }

    func image(for round: GuessRound) -> UIImage? {
        images[round.id]
    }

    func imageFailed(for round: GuessRound) -> Bool {
        failedImageIds.contains(round.id)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
