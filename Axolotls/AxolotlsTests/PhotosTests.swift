//
//  PhotosTests.swift
//  AxolotlsTests
//
//  Part C (Photos) unit tests. No network: Firebase and the camera are
//  replaced by fakes, so these run on the Simulator with ⌘U.
//

import Foundation
import Testing
import UIKit
@testable import Axolotls

// MARK: - Fixtures

private let start = Date(timeIntervalSince1970: 1_800_000_000)
private let hour: TimeInterval = 60 * 60

private func makeGroup(id: String? = "g_axolotls",
                       name: String = "The Axolotls",
                       mode: String = "party",
                       createdAt: Date = start,
                       revealAt: Date = start.addingTimeInterval(16 * hour)) -> Group {
    Group(id: id, name: name, description: "The best group of people ever.",
          mode: mode, createdAt: createdAt, revealAt: revealAt, joinCode: "123456")
}

/// A solid-color image of the given pixel size, as PNG data.
private func makeImageData(width: Int, height: Int) -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
        UIColor.systemTeal.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
    return image.pngData()!
}

/// (seconds left, text shown on the camera)
private let timeLeftCases: [(TimeInterval, String)] = [
    (2 * hour, "2 hr left"),
    (hour + 20 * 60, "1 hr 20 min left"),
    (12 * 60 + 30, "12 min left"),
    (30, "Less than a minute left"),
    (-60, "Less than a minute left"),
]

/// (group mode, which built-in list it should use)
private let modeCases: [(String, String)] = [
    ("party", "party"),
    ("Travel", "vacation"),
    ("vacation", "vacation"),
    ("", "general"),
]

private func isJPEG(_ data: Data) -> Bool {
    data.starts(with: [0xFF, 0xD8, 0xFF])
}

private struct FakeError: LocalizedError {
    var errorDescription: String? { "The network is down." }
}

@MainActor
private final class FakeCapturer: PhotoCapturing {
    var result: Result<Data, Error>
    private(set) var flashRequests: [Bool] = []

    init(result: Result<Data, Error>) { self.result = result }

    func capturePhoto(flash: Bool) async throws -> Data {
        flashRequests.append(flash)
        return try result.get()
    }
}

@MainActor
private final class FakeUploader: PhotoUploading {
    struct Call {
        let jpeg: Data
        let groupId: String
        let photographerId: String
        let quest: CameraQuest?
        let capturedAt: Date
    }

    var error: Error?
    private(set) var calls: [Call] = []

    func uploadPhoto(jpeg: Data, groupId: String, photographerId: String,
                     quest: CameraQuest?, capturedAt: Date) async throws -> GroupPhoto {
        calls.append(Call(jpeg: jpeg, groupId: groupId, photographerId: photographerId,
                          quest: quest, capturedAt: capturedAt))
        if let error { throw error }
        let photoId = "p_\(calls.count)"
        return GroupPhoto(id: photoId, photoAsset: GroupPhoto.storagePath(groupId: groupId, photoId: photoId),
                          groupId: groupId, photographerId: photographerId, capturedAt: capturedAt,
                          questId: quest?.id, questPrompt: quest?.prompt)
    }
}

@MainActor
private final class FakeQuests: QuestProviding {
    var quest: CameraQuest?
    init(_ quest: CameraQuest?) { self.quest = quest }
    func currentQuest(for group: Group, at date: Date) async -> CameraQuest? { quest }
}

// MARK: - GroupPhoto

@MainActor
@Suite("GroupPhoto record")
struct GroupPhotoTests {
    @Test func storagePathMatchesTheSprint3Layout() {
        #expect(GroupPhoto.storagePath(groupId: "g_axolotls", photoId: "p_001") == "groups/g_axolotls/photos/p_001.jpg")
    }

    @Test func encodesSnakeCaseFieldsAndLeavesOutTheID() throws {
        let photo = GroupPhoto(id: "p_001", photoAsset: "groups/g/photos/p_001.jpg", groupId: "g",
                               photographerId: "u_michael", capturedAt: start,
                               questId: "q_03", questPrompt: "Take a photo of a statue")
        let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(photo)) as? [String: Any])

        #expect(Set(json.keys) == ["photo_asset", "group_id", "photographer_id",
                                   "captured_at", "quest_id", "quest_prompt"])
        #expect(json["photographer_id"] as? String == "u_michael")
    }

    @Test func photoWithoutAQuestHasNoQuestFields() throws {
        let photo = GroupPhoto(photoAsset: "a.jpg", groupId: "g", photographerId: "u", capturedAt: start)
        let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(photo)) as? [String: Any])

        #expect(!json.keys.contains("quest_id"))
        #expect(!json.keys.contains("quest_prompt"))
    }

    @Test func decodesWhatItEncodes() throws {
        let photo = GroupPhoto(photoAsset: "a.jpg", groupId: "g", photographerId: "u", capturedAt: start,
                               questId: "builtin-party-0", questPrompt: "Capture the dance floor")
        let decoded = try JSONDecoder().decode(GroupPhoto.self, from: JSONEncoder().encode(photo))
        #expect(decoded == photo)
    }
}

// MARK: - Quests

@MainActor
@Suite("Quests")
struct QuestTests {
    private func quest(_ id: String, order: Int, from: TimeInterval, to: TimeInterval) -> Quest {
        Quest(id: id, prompt: "Prompt \(id)", checkable: false, order: order,
              startsAt: start.addingTimeInterval(from), endsAt: start.addingTimeInterval(to), source: .bank)
    }

    @Test func currentPicksTheActiveQuestWithTheLowestOrder() {
        let quests = [quest("late", order: 2, from: 0, to: 2 * hour),
                      quest("early", order: 1, from: 0, to: hour),
                      quest("future", order: 0, from: 3 * hour, to: 4 * hour)]
        #expect(Quest.current(in: quests, at: start.addingTimeInterval(30 * 60))?.id == "early")
        #expect(Quest.current(in: quests, at: start.addingTimeInterval(90 * 60))?.id == "late")
    }

    @Test func noQuestBeforeStartOrAtTheDeadline() {
        let quests = [quest("q", order: 0, from: hour, to: 2 * hour)]
        #expect(Quest.current(in: quests, at: start) == nil)
        #expect(Quest.current(in: quests, at: start.addingTimeInterval(2 * hour)) == nil)   // ends_at is exclusive
    }

    @Test func cameraQuestFromAGroupQuest() {
        let cameraQuest = CameraQuest(quest: quest("q_03", order: 3, from: 0, to: hour))
        #expect(cameraQuest.id == "q_03")
        #expect(cameraQuest.prompt == "Prompt q_03")
        #expect(cameraQuest.source == .group)

        var unsaved = quest("x", order: 5, from: 0, to: hour)
        unsaved.id = nil
        #expect(CameraQuest(quest: unsaved).id == "quest-5")
    }

    @Test(arguments: timeLeftCases)
    func timeLeftText(secondsLeft: TimeInterval, expected: String) {
        let cameraQuest = CameraQuest(id: "q", prompt: "p", endsAt: start.addingTimeInterval(secondsLeft), source: .builtIn)
        #expect(cameraQuest.timeLeftText(from: start) == expected)
    }
}

// MARK: - Built-in prompts

@MainActor
@Suite("Built-in prompts")
struct BuiltInQuestTests {
    @Test func stableHashIsFNV1a() {
        // Published FNV-1a 64-bit test vectors.
        #expect(BuiltInQuests.stableHash("") == 0xcbf29ce484222325)
        #expect(BuiltInQuests.stableHash("a") == 0xaf63dc4c8601ec8c)
    }

    @Test func samePromptForTheWholeWindowThenTheNextOne() throws {
        let group = makeGroup()
        let first = try #require(BuiltInQuests.quest(for: group, at: start.addingTimeInterval(10 * 60)))
        let later = try #require(BuiltInQuests.quest(for: group, at: start.addingTimeInterval(BuiltInQuests.window - 1)))
        let next = try #require(BuiltInQuests.quest(for: group, at: start.addingTimeInterval(BuiltInQuests.window)))

        #expect(first == later)
        #expect(first.endsAt == start.addingTimeInterval(BuiltInQuests.window))
        #expect(next.prompt != first.prompt)
        #expect(first.source == .builtIn)
    }

    @Test func goesThroughEveryPromptBeforeRepeating() {
        let group = makeGroup(revealAt: start.addingTimeInterval(100 * hour))
        let count = BuiltInQuests.party.count
        let prompts = (0..<count).compactMap { window in
            BuiltInQuests.quest(for: group, at: start.addingTimeInterval(Double(window) * BuiltInQuests.window))?.prompt
        }
        #expect(Set(prompts).count == count)
    }

    @Test(arguments: modeCases)
    func promptMatchesTheGroupMode(mode: String, expectedList: String) throws {
        let list = switch expectedList {
        case "party": BuiltInQuests.party
        case "vacation": BuiltInQuests.vacation
        default: BuiltInQuests.general
        }
        let quest = try #require(BuiltInQuests.quest(for: makeGroup(mode: mode), at: start))
        #expect(list.contains(quest.prompt))
        #expect(quest.id.hasPrefix("builtin-\(expectedList)-"))
    }

    @Test func noPromptOnceTheEventHasEnded() {
        let group = makeGroup(revealAt: start.addingTimeInterval(3 * hour))
        #expect(BuiltInQuests.quest(for: group, at: start.addingTimeInterval(3 * hour)) == nil)
    }

    @Test func lastPromptEndsWithTheEvent() throws {
        let group = makeGroup(revealAt: start.addingTimeInterval(3 * hour))
        let quest = try #require(BuiltInQuests.quest(for: group, at: start.addingTimeInterval(2.5 * hour)))
        #expect(quest.endsAt == group.revealAt)
    }

    @Test func clockBehindTheGroupUsesTheFirstPrompt() {
        let group = makeGroup()
        #expect(BuiltInQuests.quest(for: group, at: start.addingTimeInterval(-60)) == BuiltInQuests.quest(for: group, at: start))
    }
}

// MARK: - Where a Home photo goes

@MainActor
@Suite("Capture destination")
struct CaptureDestinationTests {
    private let now = start.addingTimeInterval(hour)

    @Test func noGroups() {
        guard case .noGroups = CaptureDestination.resolve(from: [], at: now) else {
            Issue.record("Expected .noGroups")
            return
        }
    }

    @Test func endedGroupsDontCount() {
        let ended = makeGroup(id: "old", revealAt: now.addingTimeInterval(-60))
        guard case .noGroups = CaptureDestination.resolve(from: [ended], at: now) else {
            Issue.record("Expected .noGroups")
            return
        }
    }

    @Test func oneActiveGroupOpensTheCameraDirectly() {
        let groups = [makeGroup(id: "old", revealAt: now.addingTimeInterval(-60)),
                      makeGroup(id: "tonight", revealAt: now.addingTimeInterval(5 * hour))]
        guard case .single(let group) = CaptureDestination.resolve(from: groups, at: now) else {
            Issue.record("Expected .single")
            return
        }
        #expect(group.id == "tonight")
    }

    @Test func severalActiveGroupsAskSoonestRevealFirst() {
        let groups = [makeGroup(id: "trip", revealAt: now.addingTimeInterval(72 * hour)),
                      makeGroup(id: "tonight", revealAt: now.addingTimeInterval(5 * hour)),
                      makeGroup(id: "old", revealAt: now.addingTimeInterval(-60))]
        guard case .choose(let choices) = CaptureDestination.resolve(from: groups, at: now) else {
            Issue.record("Expected .choose")
            return
        }
        #expect(choices.map(\.id) == ["tonight", "trip"])
    }
}

// MARK: - Image processing

@MainActor
@Suite("Photo processing")
struct PhotoProcessingTests {
    @Test(arguments: [
        (CGSize(width: 4000, height: 3000), CGSize(width: 2048, height: 1536)),
        (CGSize(width: 3024, height: 4032), CGSize(width: 1536, height: 2048)),
        (CGSize(width: 1000, height: 800), CGSize(width: 1000, height: 800)),
        (CGSize(width: 2048, height: 2048), CGSize(width: 2048, height: 2048)),
    ])
    func scaledSize(input: CGSize, expected: CGSize) {
        #expect(PhotoProcessing.scaledSize(for: input, maxDimension: 2048) == expected)
    }

    @Test func largePhotoBecomesASmallerJPEG() throws {
        let png = makeImageData(width: 3000, height: 4000)
        let jpeg = try #require(PhotoProcessing.uploadJPEG(from: png))
        let image = try #require(UIImage(data: jpeg))

        #expect(isJPEG(jpeg))
        #expect(image.size == CGSize(width: 1536, height: 2048))
    }

    @Test func sidewaysPhotoComesOutUpright() throws {
        // A 400×300 sensor image tagged "rotate right" displays as 300×400.
        let landscape = try #require(UIImage(data: makeImageData(width: 400, height: 300))?.cgImage)
        let rotated = UIImage(cgImage: landscape, scale: 1, orientation: .right)

        let jpeg = try #require(PhotoProcessing.uploadJPEG(from: rotated))
        let image = try #require(UIImage(data: jpeg))
        #expect(image.size == CGSize(width: 300, height: 400))
        #expect(image.imageOrientation == .up)
    }

    @Test func notAnImage() {
        #expect(PhotoProcessing.uploadJPEG(from: Data("hello".utf8)) == nil)
    }
}

// MARK: - Camera screen

@MainActor
@Suite("Camera view model")
struct CameraViewModelTests {
    private let now = start.addingTimeInterval(hour)
    private let statue = CameraQuest(id: "q_03", prompt: "Take a photo of a statue",
                                     endsAt: start.addingTimeInterval(2 * hour), source: .group)

    /// Fakes are built in the body, not as default arguments: default arguments
    /// run outside the main actor, and the fakes are main-actor types.
    private func makeViewModel(group: Group = makeGroup(),
                               uploader: FakeUploader? = nil,
                               quests: FakeQuests? = nil,
                               capturer: FakeCapturer? = nil,
                               hasCamera: Bool = true) -> CameraViewModel {
        let fixedNow = now
        let viewModel = CameraViewModel(group: group, photographerId: "u_michael",
                                        uploader: uploader ?? FakeUploader(),
                                        quests: quests ?? FakeQuests(nil),
                                        now: { fixedNow })
        if hasCamera {
            viewModel.capturer = capturer ?? FakeCapturer(result: .success(makeImageData(width: 400, height: 300)))
        }
        return viewModel
    }

    @Test func loadsThePromptForTheGroup() async {
        let viewModel = makeViewModel(quests: FakeQuests(statue))
        await viewModel.loadQuest()
        #expect(viewModel.quest == statue)
    }

    @Test func captureGoesToReviewAndPassesTheFlashSetting() async {
        let capturer = FakeCapturer(result: .success(makeImageData(width: 400, height: 300)))
        let viewModel = makeViewModel(capturer: capturer)
        viewModel.flashEnabled = true

        await viewModel.capture()

        #expect(viewModel.phase == .review)
        #expect(viewModel.reviewImage != nil)
        #expect(capturer.flashRequests == [true])
    }

    @Test func failedCaptureShowsAnErrorAndStaysReady() async {
        let viewModel = makeViewModel(capturer: FakeCapturer(result: .failure(FakeError())))
        await viewModel.capture()

        #expect(viewModel.phase == .ready)
        #expect(viewModel.errorMessage?.contains("The network is down.") == true)
    }

    @Test func cannotCaptureWithoutACamera() async {
        let viewModel = makeViewModel(hasCamera: false)
        #expect(!viewModel.canCapture)
        await viewModel.capture()
        #expect(viewModel.phase == .ready)
    }

    @Test func cannotCaptureAfterTheEventEnds() async {
        let capturer = FakeCapturer(result: .success(makeImageData(width: 10, height: 10)))
        let viewModel = makeViewModel(group: makeGroup(revealAt: now), capturer: capturer)

        #expect(viewModel.isEventOver)
        #expect(!viewModel.canCapture)
        await viewModel.capture()
        #expect(capturer.flashRequests.isEmpty)
    }

    @Test func retakeThrowsAwayThePhoto() async {
        let viewModel = makeViewModel()
        await viewModel.capture()
        viewModel.retake()

        #expect(viewModel.phase == .ready)
        #expect(viewModel.reviewImage == nil)
    }

    @Test func sendSavesThePhotoForThisGroupAndPhotographer() async throws {
        let uploader = FakeUploader()
        let viewModel = makeViewModel(uploader: uploader, quests: FakeQuests(statue))
        await viewModel.loadQuest()
        await viewModel.capture()
        await viewModel.send()

        let call = try #require(uploader.calls.first)
        #expect(uploader.calls.count == 1)
        #expect(call.groupId == "g_axolotls")
        #expect(call.photographerId == "u_michael")
        #expect(call.quest == statue)
        #expect(call.capturedAt == now)
        #expect(isJPEG(call.jpeg))

        #expect(viewModel.phase == .sent)
        #expect(viewModel.sentCount == 1)
        #expect(viewModel.reviewImage == nil)
    }

    @Test func failedSendKeepsThePhotoSoItCanBeRetried() async {
        let uploader = FakeUploader()
        uploader.error = FakeError()
        let viewModel = makeViewModel(uploader: uploader)
        await viewModel.capture()

        await viewModel.send()
        #expect(viewModel.phase == .review)
        #expect(viewModel.reviewImage != nil)
        #expect(viewModel.errorMessage?.contains("The network is down.") == true)

        uploader.error = nil
        await viewModel.send()
        #expect(viewModel.phase == .sent)
        #expect(uploader.calls.count == 2)
    }

    @Test func groupWithoutAnIDIsNotUploaded() async {
        let uploader = FakeUploader()
        let viewModel = makeViewModel(group: makeGroup(id: nil), uploader: uploader)
        await viewModel.capture()
        await viewModel.send()

        #expect(uploader.calls.isEmpty)
        #expect(viewModel.phase == .review)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func libraryPhotoThatIsNotAnImageIsRejected() {
        let viewModel = makeViewModel()
        viewModel.accept(Data("not an image".utf8))

        #expect(viewModel.phase == .ready)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func takeAnotherReturnsToTheCameraWithTheLatestPrompt() async {
        let quests = FakeQuests(statue)
        let viewModel = makeViewModel(quests: quests)
        await viewModel.loadQuest()
        await viewModel.capture()
        await viewModel.send()

        let next = CameraQuest(id: "builtin-party-1", prompt: "Capture the dance floor",
                               endsAt: start.addingTimeInterval(4 * hour), source: .builtIn)
        quests.quest = next
        await viewModel.takeAnother()

        #expect(viewModel.phase == .ready)
        #expect(viewModel.quest == next)
    }
}
