//
//  GroupPhoto.swift
//  Axolotls
//
//  Part C (Photos). Mirrors groups/{groupId}/photos/{photoId} from the Sprint 3
//  data design (same snake_case field names), so Part D can read photos for the
//  reveal and the guessing game.
//

import Foundation

/// One photo taken on the Camera screen. The image itself lives in Cloud Storage
/// at `photoAsset`; this record is what the album and the game read.
///
/// `id` is the Firestore document ID. It isn't stored as a field, so it's left out
/// of CodingKeys: set it yourself after decoding (`photo.id = snapshot.documentID`).
struct GroupPhoto: Codable, Identifiable, Hashable {
    var id: String? = nil
    var photoAsset: String          // photo_asset      Storage path "groups/{groupId}/photos/{photoId}.jpg"
    var groupId: String             // group_id
    var photographerId: String      // photographer_id  hidden in the album until the game is played
    var capturedAt: Date            // captured_at
    var questId: String? = nil      // quest_id         nil = taken without a quest
    var questPrompt: String? = nil  // quest_prompt     copied from the quest for display

    enum CodingKeys: String, CodingKey {
        case photoAsset = "photo_asset"
        case groupId = "group_id"
        case photographerId = "photographer_id"
        case capturedAt = "captured_at"
        case questId = "quest_id"
        case questPrompt = "quest_prompt"
    }

    /// Where the JPEG for a photo is stored in Cloud Storage.
    static func storagePath(groupId: String, photoId: String) -> String {
        "groups/\(groupId)/photos/\(photoId).jpg"
    }
}
