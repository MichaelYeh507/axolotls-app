//
//  GuessGameViewModel.swift
//  Axolotls
//
//  Created by Lily Beerhalter on 11/7/26.
//

import Foundation
import Observation
import UIKit
import FirebaseFirestore

@MainActor
@Observable
final class GuessGameViewModel {
    enum State {
        case loading
        case failed(String)
        case noPhotos
        case playing
        case finished
    }

    private(set) var state: State = .loading
    private(set) var game = GuessGame(photos: [], players: [])
    private(set) var players: [GamePlayer] = []
    private(set) var images: [String: UIImage] = [:]   // photo id -> image

    private let groupId: String
    private let photoService = FirebasePhotoService()
    private var allPhotos: [GroupPhoto] = []

    init(groupId: String) {
        self.groupId = groupId
    }

    // MARK: - Loading

    //loads the album and the people in the group, then starts a game
    func load() async {
        state = .loading
        do {
            allPhotos = try await photoService.photos(inGroup: groupId)
            players = try await loadPlayers(photographerIds: Set(allPhotos.map(\.photographerId)))
            startGame()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    //everyone active in the group, plus anyone who took a photo but has since left
    private func loadPlayers(photographerIds: Set<String>) async throws -> [GamePlayer] {
        let memberships = try await Firestore.app
            .collection("membership")
            .whereField("group_id", isEqualTo: groupId)
            .getDocuments()
            .documents
            .map { try $0.data(as: Membership.self) }

        let memberIds = memberships
            .filter { $0.membershipStatus == "active" }
            .map(\.userId)
        let userIds = Set(memberIds).union(photographerIds)

        var result: [GamePlayer] = []
        for userId in userIds {
            let snapshot = try await Firestore.app.collection("users").document(userId).getDocument()
            let name = (try? snapshot.data(as: UserProfile.self))?.displayName ?? "Unknown"
            result.append(GamePlayer(id: userId, name: name))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    //loads the picture for a photo, if it isn't already loaded
    func loadImage(for photo: GroupPhoto) async {
        guard let id = photo.id, images[id] == nil else { return }
        if let data = try? await photoService.imageData(for: photo), let image = UIImage(data: data) {
            images[id] = image
        }
    }

    func image(for round: GuessRound) -> UIImage? {
        images[round.id]
    }

    // MARK: - Playing

    func guess(_ player: GamePlayer) {
        game.guess(player.id)
    }

    func next() {
        game.next()
        if game.isFinished { state = .finished }
    }

    //new random set of photos (and people) from the same album
    func playAgain() {
        startGame()
    }

    func name(for userId: String) -> String {
        players.first { $0.id == userId }?.name ?? "Unknown"
    }

    private func startGame() {
        game = GuessGame(photos: allPhotos, players: players)
        state = game.isEmpty ? .noPhotos : .playing
    }
}
