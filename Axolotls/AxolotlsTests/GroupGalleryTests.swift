//
//  GroupGalleryTests.swift
//  AxolotlsTests
//
//  Created by Lily Beerhalter on 11/8/26.
//

import Foundation
import Testing
import UIKit
@testable import Axolotls

private let revealAt = Date(timeIntervalSince1970: 1_800_000_000)

private func makeGroup() -> Group {
    Group(id: "g_test", name: "Test", description: "", mode: "party",
          createdAt: revealAt.addingTimeInterval(-3600), revealAt: revealAt, joinCode: "123456")
}

private func makePhoto(id: String) -> GroupPhoto {
    GroupPhoto(id: id, photoAsset: "groups/g_test/photos/\(id).jpg", groupId: "g_test",
               photographerId: "u_test", capturedAt: revealAt)
}

private func makeImageData(width: Int, height: Int) -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        .image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        .pngData()!
}

private struct LoadFailure: Error {}

private struct FakePhotoReader: GroupPhotoReading {
    var photos: [GroupPhoto] = []
    var imageData: Data?
    var failsLoadingPhotos = false

    func photos(inGroup groupId: String) async throws -> [GroupPhoto] {
        if failsLoadingPhotos { throw LoadFailure() }
        return photos
    }

    func imageData(for photo: GroupPhoto, maxSize: Int64) async throws -> Data {
        guard let imageData else { throw LoadFailure() }
        return imageData
    }
}

@MainActor
struct GroupGalleryTests {
    private func makeViewModel(reader: FakePhotoReader = FakePhotoReader(),
                               at date: Date) -> GroupGalleryViewModel {
        GroupGalleryViewModel(group: makeGroup(), photoService: reader, now: { date })
    }

    @Test func isLockedBeforeRevealTime() {
        #expect(!makeViewModel(at: revealAt.addingTimeInterval(-1)).isRevealed)
    }

    @Test func isRevealedAtRevealTime() {
        #expect(makeViewModel(at: revealAt).isRevealed)
    }

    @Test func unlocksWhenRevealTimeArrives() async {
        var current = revealAt.addingTimeInterval(-0.05)
        let viewModel = GroupGalleryViewModel(group: makeGroup(), photoService: FakePhotoReader(),
                                              now: {
            defer { current = revealAt }
            return current
        })
        await viewModel.waitForReveal()
        #expect(viewModel.isRevealed)
    }

    @Test func loadsPhotos() async {
        let viewModel = makeViewModel(reader: FakePhotoReader(photos: [makePhoto(id: "p1"), makePhoto(id: "p2")]),
                                      at: revealAt)
        await viewModel.load()
        #expect(viewModel.photos.map(\.id) == ["p1", "p2"])
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test func reportsLoadFailure() async {
        let viewModel = makeViewModel(reader: FakePhotoReader(failsLoadingPhotos: true), at: revealAt)
        await viewModel.load()
        #expect(viewModel.photos.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func thumbnailIsSmallerThanLargePhoto() async throws {
        let photo = makePhoto(id: "p1")
        let viewModel = makeViewModel(reader: FakePhotoReader(imageData: makeImageData(width: 2000, height: 1000)),
                                      at: revealAt)
        await viewModel.loadThumbnail(for: photo)
        let thumbnail = try #require(viewModel.thumbnails["p1"])
        let shortSidePixels = min(thumbnail.size.width, thumbnail.size.height) * thumbnail.scale
        #expect(shortSidePixels < 1000)
    }

    @Test func recordsFailedThumbnail() async {
        let viewModel = makeViewModel(reader: FakePhotoReader(), at: revealAt)
        await viewModel.loadThumbnail(for: makePhoto(id: "p1"))
        #expect(viewModel.thumbnails["p1"] == nil)
        #expect(viewModel.failedThumbnailIds.contains("p1"))
    }

    @Test func cancelledLoadDoesNotReplacePhotos() async {
        let viewModel = makeViewModel(reader: FakePhotoReader(photos: [makePhoto(id: "stale")]), at: revealAt)
        let load = Task { await viewModel.load() }
        load.cancel()
        await load.value
        #expect(viewModel.photos.isEmpty)
    }

    // MARK: Game photos

    @Test func gameRecordsFailedPhoto() async {
        let viewModel = GuessGameViewModel(groupId: "g_test", photoService: FakePhotoReader())
        await viewModel.loadImage(for: makePhoto(id: "p1"))
        #expect(viewModel.images["p1"] == nil)
        #expect(viewModel.failedImageIds.contains("p1"))
    }

    @Test func gameLoadsPhoto() async {
        let reader = FakePhotoReader(imageData: makeImageData(width: 10, height: 10))
        let viewModel = GuessGameViewModel(groupId: "g_test", photoService: reader)
        await viewModel.loadImage(for: makePhoto(id: "p1"))
        #expect(viewModel.images["p1"] != nil)
        #expect(viewModel.failedImageIds.isEmpty)
    }
}
