//
//  GameSessionService.swift
//  Axolotls
//
//  Reads and writes live game sessions in Firestore.
//
//  Firestore: groups/{groupId}.active_game_session_id
//             groups/{groupId}/game_sessions/{id}                  (GameSession)
//             groups/{groupId}/game_sessions/{id}/guesses/{round}_{userId}  (PhotoGuess)
//

import Foundation
import FirebaseFirestore

struct GameRoster {
    var players: [GamePlayer]
}

/// What the game needs from the backend. Tests swap in a fake.
protocol GameSessionServing {
    func roster(groupId: String, photographerIds: Set<String>) async throws -> GameRoster
    func joinOrCreateSession(groupId: String, userId: String, now: Date) async throws -> String
    func sessionUpdates(groupId: String, sessionId: String) -> AsyncThrowingStream<GameSession, Error>
    func guessUpdates(groupId: String, sessionId: String) -> AsyncThrowingStream<[PhotoGuess], Error>
    func setReady(_ isReady: Bool, groupId: String, sessionId: String, userId: String) async throws
    func startGame(groupId: String, sessionId: String, userId: String,
                   rounds: [GameRoundPlan], startsAt: Date) async throws
    func submit(_ guess: PhotoGuess, groupId: String, sessionId: String) async throws
    func markFinished(groupId: String, sessionId: String, at date: Date) async throws
}

final class FirebaseGameSessionService: GameSessionServing {
    private var db: Firestore { .app }

    private func sessionRef(groupId: String, sessionId: String) -> DocumentReference {
        db.collection("groups").document(groupId).collection("game_sessions").document(sessionId)
    }

    //everyone active in the group, plus anyone who took a photo but has since left
    func roster(groupId: String, photographerIds: Set<String>) async throws -> GameRoster {
        let memberships = try await db.collection("membership")
            .whereField("group_id", isEqualTo: groupId)
            .getDocuments()
            .documents
            .map { try $0.data(as: Membership.self) }
            .filter { $0.membershipStatus == "active" }

        var players: [GamePlayer] = []
        for userId in Set(memberships.map(\.userId)).union(photographerIds) {
            let snapshot = try await db.collection("users").document(userId).getDocument()
            let name = (try? snapshot.data(as: UserProfile.self))?.displayName ?? "Unknown"
            players.append(GamePlayer(id: userId, name: name))
        }
        players.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return GameRoster(players: players)
    }

    //a transaction, so two people opening the game together land in the same lobby
    func joinOrCreateSession(groupId: String, userId: String, now: Date) async throws -> String {
        let groupRef = db.collection("groups").document(groupId)
        let sessions = groupRef.collection("game_sessions")
        let newRef = sessions.document()
        let newData = try Firestore.Encoder().encode(GameSession(groupId: groupId, hostId: userId, createdAt: now))

        let sessionId = try await db.runTransaction { transaction, errorPointer -> Any? in
            do {
                let group = try transaction.getDocument(groupRef)
                if let activeId = group.data()?["active_game_session_id"] as? String {
                    let active = try transaction.getDocument(sessions.document(activeId))
                    if let session = try? active.data(as: GameSession.self), session.isActive(at: now) {
                        return activeId
                    }
                }
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            transaction.setData(newData, forDocument: newRef)
            transaction.updateData(["active_game_session_id": newRef.documentID], forDocument: groupRef)
            return newRef.documentID
        }

        guard let sessionId = sessionId as? String else {
            throw NSError(domain: "GameSessionError", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Couldn't open the game. Please try again."])
        }
        return sessionId
    }

    func sessionUpdates(groupId: String, sessionId: String) -> AsyncThrowingStream<GameSession, Error> {
        let ref = sessionRef(groupId: groupId, sessionId: sessionId)
        return AsyncThrowingStream { continuation in
            let listener = ref.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let snapshot, snapshot.exists else { return }
                do {
                    continuation.yield(try snapshot.data(as: GameSession.self))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func guessUpdates(groupId: String, sessionId: String) -> AsyncThrowingStream<[PhotoGuess], Error> {
        let ref = sessionRef(groupId: groupId, sessionId: sessionId).collection("guesses")
        return AsyncThrowingStream { continuation in
            let listener = ref.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let snapshot else { return }
                do {
                    continuation.yield(try snapshot.documents.map { try $0.data(as: PhotoGuess.self) })
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func setReady(_ isReady: Bool, groupId: String, sessionId: String, userId: String) async throws {
        let change = isReady ? FieldValue.arrayUnion([userId]) : FieldValue.arrayRemove([userId])
        try await sessionRef(groupId: groupId, sessionId: sessionId).updateData(["ready_ids": change])
    }

    //a transaction, so the players are exactly who's ready at the moment the game starts
    func startGame(groupId: String, sessionId: String, userId: String,
                   rounds: [GameRoundPlan], startsAt: Date) async throws {
        let ref = sessionRef(groupId: groupId, sessionId: sessionId)
        let encodedRounds = try rounds.map { try Firestore.Encoder().encode($0) }

        _ = try await db.runTransaction { transaction, errorPointer -> Any? in
            do {
                let session = try transaction.getDocument(ref).data(as: GameSession.self)
                guard session.canStart(userId: userId) else { return nil }
                transaction.updateData([
                    "game_status": GameStatus.playing.rawValue,
                    "participant_ids": session.readyIds,
                    "rounds": encodedRounds,
                    "started_at": Timestamp(date: startsAt)
                ], forDocument: ref)
            } catch let error as NSError {
                errorPointer?.pointee = error
            }
            return nil
        }
    }

    func submit(_ guess: PhotoGuess, groupId: String, sessionId: String) async throws {
        try await sessionRef(groupId: groupId, sessionId: sessionId)
            .collection("guesses")
            .document(guess.documentId)
            .setData(Firestore.Encoder().encode(guess))
    }

    func markFinished(groupId: String, sessionId: String, at date: Date) async throws {
        try await sessionRef(groupId: groupId, sessionId: sessionId).updateData([
            "game_status": GameStatus.finished.rawValue,
            "finished_at": Timestamp(date: date)
        ])
    }
}
