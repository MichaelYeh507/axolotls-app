//
//  PhotoService.swift
//  Axolotls
//
//  Part C (Photos). Saves a photo: the JPEG goes to Cloud Storage, then the
//  photo record and the group's photo_count are written together in Firestore.
//
//  Storage:   groups/{groupId}/photos/{photoId}.jpg
//  Firestore: groups/{groupId}/photos/{photoId}   (GroupPhoto)
//             groups/{groupId}.photo_count        (+1)
//
//  Part D: use `photos(inGroup:)` and `imageData(for:)` to read them back.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage

/// What the Camera needs to save a photo. Tests swap in a fake.
protocol PhotoUploading {
    func uploadPhoto(jpeg: Data, groupId: String, photographerId: String,
                     quest: CameraQuest?, capturedAt: Date) async throws -> GroupPhoto
}

final class FirebasePhotoService: PhotoUploading {
    private let db: Firestore
    private let storage: Storage

    init(db: Firestore = .app, storage: Storage = .storage()) {
        self.db = db
        self.storage = storage
    }

    // MARK: Save

    func uploadPhoto(jpeg: Data, groupId: String, photographerId: String,
                     quest: CameraQuest?, capturedAt: Date) async throws -> GroupPhoto {
        let groupRef = db.collection("groups").document(groupId)
        let photoRef = groupRef.collection("photos").document()       // new auto ID, nothing written yet
        let path = GroupPhoto.storagePath(groupId: groupId, photoId: photoRef.documentID)

        // 1. The image.
        let imageRef = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = ["photographer_id": photographerId]
        _ = try await imageRef.putDataAsync(jpeg, metadata: metadata)

        // 2. The record and the count, together.
        var photo = GroupPhoto(photoAsset: path, groupId: groupId, photographerId: photographerId,
                               capturedAt: capturedAt, questId: quest?.id, questPrompt: quest?.prompt)
        do {
            let batch = db.batch()
            try batch.setData(from: photo, forDocument: photoRef)
            batch.updateData(["photo_count": FieldValue.increment(Int64(1))], forDocument: groupRef)
            try await batch.commit()
        } catch {
            try? await imageRef.delete()        // don't leave an image with no record
            throw error
        }

        photo.id = photoRef.documentID
        return photo
    }

    // MARK: Read (for Part D: reveal + game)

    /// Every photo in a group, oldest first.
    func photos(inGroup groupId: String) async throws -> [GroupPhoto] {
        let snapshot = try await db.collection("groups").document(groupId)
            .collection("photos")
            .order(by: "captured_at")
            .getDocuments()

        return try snapshot.documents.map { document in
            var photo = try document.data(as: GroupPhoto.self)
            photo.id = document.documentID
            return photo
        }
    }

    /// The JPEG bytes for a photo (`UIImage(data:)` to show it).
    func imageData(for photo: GroupPhoto, maxSize: Int64 = 10 * 1024 * 1024) async throws -> Data {
        try await storage.reference(withPath: photo.photoAsset).data(maxSize: maxSize)
    }
}
