//
//  CameraViewModel.swift
//  Axolotls
//
//  Part C (Photos). The Camera screen's state:
//    ready → capturing → review → sending → sent → (take another) → ready
//  Retake goes from review back to ready. A failed send stays on review with
//  an error, so the photo isn't lost and Send can be tapped again.
//

import Foundation
import Observation
import UIKit

@Observable
final class CameraViewModel {
    enum Phase: Equatable {
        case ready          // live preview, capture button enabled
        case capturing      // waiting for the camera
        case review         // photo taken: Retake or Send
        case sending        // uploading
        case sent           // saved; hidden until the reveal
    }

    let group: Group
    let photographerId: String

    /// Set by the view once the camera is running. Nil on the Simulator.
    var capturer: (any PhotoCapturing)?

    private(set) var phase: Phase = .ready
    private(set) var quest: CameraQuest?
    private(set) var reviewImage: UIImage?
    private(set) var sentCount = 0
    var errorMessage: String?
    var flashEnabled = false

    private var pendingJPEG: Data?
    private let uploader: any PhotoUploading
    private let quests: any QuestProviding
    private let now: () -> Date

    init(group: Group,
         photographerId: String,
         uploader: any PhotoUploading,
         quests: any QuestProviding,
         now: @escaping () -> Date = { Date() }) {
        self.group = group
        self.photographerId = photographerId
        self.uploader = uploader
        self.quests = quests
        self.now = now
    }

    /// Photos can only be added until the event ends (that's when they're revealed).
    var isEventOver: Bool { now() >= group.revealAt }

    var canCapture: Bool { phase == .ready && capturer != nil && !isEventOver }

    // MARK: Quest

    func loadQuest() async {
        quest = await quests.currentQuest(for: group, at: now())
    }

    // MARK: Taking a photo

    func capture() async {
        guard phase == .ready, !isEventOver, let capturer else { return }
        errorMessage = nil
        phase = .capturing
        do {
            let data = try await capturer.capturePhoto(flash: flashEnabled)
            accept(data)
        } catch {
            phase = .ready
            errorMessage = "Couldn't take the photo. \(error.localizedDescription)"
        }
    }

    /// A photo from the camera or the photo library, ready for review.
    func accept(_ imageData: Data) {
        guard let jpeg = PhotoProcessing.uploadJPEG(from: imageData),
              let image = UIImage(data: jpeg) else {
            phase = .ready
            errorMessage = "That photo couldn't be read."
            return
        }
        pendingJPEG = jpeg
        reviewImage = image
        errorMessage = nil
        phase = .review
    }

    func retake() {
        pendingJPEG = nil
        reviewImage = nil
        errorMessage = nil
        phase = .ready
    }

    // MARK: Sending

    func send() async {
        guard phase == .review, let jpeg = pendingJPEG else { return }
        guard let groupId = group.id else {
            errorMessage = "This group is missing its ID, so the photo can't be saved."
            return
        }
        guard !isEventOver else {
            errorMessage = "This event has ended, so new photos can't be added."
            return
        }

        phase = .sending
        errorMessage = nil
        do {
            _ = try await uploader.uploadPhoto(jpeg: jpeg, groupId: groupId, photographerId: photographerId,
                                               quest: quest, capturedAt: now())
            pendingJPEG = nil
            reviewImage = nil
            sentCount += 1
            phase = .sent
        } catch {
            phase = .review
            errorMessage = "Couldn't send the photo. \(error.localizedDescription)"
        }
    }

    /// From the "sent" screen back to the camera. The prompt may have changed.
    func takeAnother() async {
        retake()
        await loadQuest()
    }
}
