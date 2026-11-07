//
//  QuestService.swift
//  Axolotls
//
//  Part C (Photos). Finds the prompt to show on the Camera: the group's own
//  active quest if it has one, otherwise the built-in prompt for this time.
//

import Foundation
import FirebaseFirestore

/// What the Camera needs to show a prompt. Tests swap in a fake.
protocol QuestProviding {
    func currentQuest(for group: Group, at date: Date) async -> CameraQuest?
}

final class QuestService: QuestProviding {
    private let db: Firestore

    init(db: Firestore = .app) {
        self.db = db
    }

    func currentQuest(for group: Group, at date: Date) async -> CameraQuest? {
        if let groupId = group.id,
           let quests = try? await groupQuests(groupId: groupId),
           let quest = Quest.current(in: quests, at: date) {
            return CameraQuest(quest: quest)
        }
        return BuiltInQuests.quest(for: group, at: date)
    }

    /// groups/{groupId}/quests. Documents that don't match `Quest` are skipped.
    func groupQuests(groupId: String) async throws -> [Quest] {
        let snapshot = try await db.collection("groups").document(groupId)
            .collection("quests")
            .getDocuments()

        return snapshot.documents.compactMap { document in
            guard var quest = try? document.data(as: Quest.self) else { return nil }
            quest.id = document.documentID
            return quest
        }
    }
}
