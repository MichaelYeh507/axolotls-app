//
//  CameraSession.swift
//  Axolotls
//
//  Part C (Photos). The live camera, built on AVFoundation. All work on the
//  capture session happens on its own serial queue (Apple's rule: starting a
//  session blocks, so never on the main thread). The class is `nonisolated`
//  to opt out of the app's default MainActor isolation for that reason.
//
//  The Simulator has no camera: `isCameraAvailable` is false there and the
//  Camera screen offers the photo library instead.
//

import AVFoundation

/// Thrown from the session queue, so it opts out of MainActor isolation too.
nonisolated enum CameraError: LocalizedError {
    case noCamera
    case cannotUseCamera
    case notRunning
    case noImageData

    var errorDescription: String? {
        switch self {
        case .noCamera:         return "This device doesn't have a camera."
        case .cannotUseCamera:  return "The camera couldn't be started."
        case .notRunning:       return "The camera isn't running yet."
        case .noImageData:      return "The camera didn't return a photo."
        }
    }
}

/// Takes a photo and returns its file data (HEIC or JPEG). Tests swap in a fake.
protocol PhotoCapturing: AnyObject {
    func capturePhoto(flash: Bool) async throws -> Data
}

nonisolated final class CameraSession: NSObject, PhotoCapturing, @unchecked Sendable {
    /// Hand this to `CameraPreview`. Only touched on `queue` after setup.
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "axolotls.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var input: AVCaptureDeviceInput?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var inFlight: [Int64: PhotoCaptureProcessor] = [:]

    // MARK: Availability and permission

    static var isCameraAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    /// Asks the first time (shows NSCameraUsageDescription); afterwards returns the saved answer.
    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:       return true
        case .notDetermined:    return await AVCaptureDevice.requestAccess(for: .video)
        default:                return false        // denied or restricted
        }
    }

    // MARK: Running

    /// Sets up the camera on `position` (first call, or when flipping) and starts it.
    func start(position: AVCaptureDevice.Position) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.configure(position: position)
                    if !self.session.isRunning { self.session.startRunning() }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    /// The camera in use, for the preview's rotation handling. Call after `start`.
    var activeDevice: AVCaptureDevice? {
        queue.sync { input?.device }
    }

    // MARK: Capture

    func capturePhoto(flash: Bool) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            queue.async {
                guard self.session.isRunning else {
                    continuation.resume(throwing: CameraError.notRunning)
                    return
                }

                // Keep the photo level with the horizon however the phone is held.
                if let connection = self.photoOutput.connection(with: .video),
                   let angle = self.rotationCoordinator?.videoRotationAngleForHorizonLevelCapture,
                   connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }

                let settings = AVCapturePhotoSettings()
                let flashMode: AVCaptureDevice.FlashMode = flash ? .on : .off
                if self.photoOutput.supportedFlashModes.contains(flashMode) {
                    settings.flashMode = flashMode
                }

                let id = settings.uniqueID
                let processor = PhotoCaptureProcessor { result in
                    self.queue.async { self.inFlight[id] = nil }
                    continuation.resume(with: result)
                }
                self.inFlight[id] = processor           // AVFoundation holds the delegate weakly
                self.photoOutput.capturePhoto(with: settings, delegate: processor)
            }
        }
    }

    // MARK: Setup (on `queue`)

    private func configure(position: AVCaptureDevice.Position) throws {
        if let input, input.device.position == position { return }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
                ?? AVCaptureDevice.default(for: .video) else {
            throw CameraError.noCamera
        }
        let newInput = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }

        if let input { session.removeInput(input) }
        guard session.canAddInput(newInput) else {
            if let input { session.addInput(input) }        // put the old camera back
            throw CameraError.cannotUseCamera
        }
        session.addInput(newInput)
        input = newInput

        if !session.outputs.contains(photoOutput) {
            guard session.canAddOutput(photoOutput) else { throw CameraError.cannotUseCamera }
            session.addOutput(photoOutput)
        }

        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
    }
}

/// Receives one photo from AVFoundation and reports it exactly once.
nonisolated final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (Result<Data, Error>) -> Void
    private var photoData: Data?
    private var finished = false

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            finish(.failure(error))
            return
        }
        photoData = photo.fileDataRepresentation()
    }

    /// Always called last, whether or not the capture worked.
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        if let error {
            finish(.failure(error))
        } else if let photoData {
            finish(.success(photoData))
        } else {
            finish(.failure(CameraError.noImageData))
        }
    }

    private func finish(_ result: Result<Data, Error>) {
        guard !finished else { return }
        finished = true
        completion(result)
    }
}
