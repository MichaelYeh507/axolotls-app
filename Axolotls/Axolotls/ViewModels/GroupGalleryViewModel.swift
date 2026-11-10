//
//  GroupGalleryViewModel.swift
//  Axolotls
//
//  Created by Lily Beerhalter on 11/8/26.
//

import Foundation
import Observation
import UIKit


protocol GroupPhotoReading {
    func photos(inGroup groupId: String) async throws -> [GroupPhoto]
    func imageData(for photo: GroupPhoto, maxSize: Int64) async throws -> Data
}

extension FirebasePhotoService: GroupPhotoReading {}

@MainActor
@Observable
final class GroupGalleryViewModel {
    private(set) var photos: [GroupPhoto] = []
    private(set) var thumbnails: [String: UIImage] = [:]    // photo id -> small image for the grid
    private(set) var failedThumbnailIds: Set<String> = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var isRevealed: Bool

    private let groupId: String
    private let revealAt: Date
    private let photoService: GroupPhotoReading
    private let now: () -> Date

    private static let maxImageBytes: Int64 = 10 * 1024 * 1024
    private static let thumbnailShortSide: CGFloat = 400

    init(group: Group, photoService: GroupPhotoReading? = nil, now: @escaping () -> Date = Date.init) {
        self.groupId = group.id ?? ""
        self.revealAt = group.revealAt
        self.photoService = photoService ?? FirebasePhotoService()
        self.now = now
        self.isRevealed = now() >= group.revealAt
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let loadedPhotos = try await photoService.photos(inGroup: groupId)
            guard !Task.isCancelled else { return } // a newer load replaced this one
            photos = loadedPhotos
        } catch is CancellationError {
            return // the view went away or a newer load replaced this one
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    //sleeps until the reveal time so the gallery unblurs while it's on screen.
    func waitForReveal() async {
        while !isRevealed {
            let wait = revealAt.timeIntervalSince(now())
            do {
                try await Task.sleep(for: .seconds(max(wait, 0) + 0.1))
            } catch {
                return // view went away
            }
            isRevealed = now() >= revealAt
        }
    }

    //loads the small grid image for a photo
    func loadThumbnail(for photo: GroupPhoto) async {
        guard let id = photo.id, thumbnails[id] == nil else { return }
        guard let image = await downloadImage(for: photo),
              let thumbnail = await Self.thumbnail(of: image) else {
            failedThumbnailIds.insert(id)
            return
        }
        failedThumbnailIds.remove(id)
        thumbnails[id] = thumbnail
    }

    //gets the fullsize image shown when a photo is tapped
    func fullImage(for photo: GroupPhoto) async -> UIImage? {
        await downloadImage(for: photo)
    }

    private func downloadImage(for photo: GroupPhoto) async -> UIImage? {
        guard let data = try? await photoService.imageData(for: photo, maxSize: Self.maxImageBytes) else {
            return nil
        }
        return UIImage(data: data)
    }

    //keeps the grid light
    private static func thumbnail(of image: UIImage) async -> UIImage? {
        let shortSide = min(image.size.width, image.size.height)
        guard shortSide > thumbnailShortSide else { return image }
        let scale = thumbnailShortSide / shortSide
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return await image.byPreparingThumbnail(ofSize: size)
    }
}
