//
//  CameraPreview.swift
//  Axolotls
//
//  Part C (Photos). Shows the live camera feed (AVCaptureVideoPreviewLayer)
//  in SwiftUI and keeps it level when the phone rotates.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// The active camera; the preview re-levels itself when this changes (flip).
    let device: AVCaptureDevice?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if let device { view.track(device) }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // layerClass guarantees the type.
            layer as! AVCaptureVideoPreviewLayer
        }

        private var coordinator: AVCaptureDevice.RotationCoordinator?
        private var observation: NSKeyValueObservation?

        func track(_ device: AVCaptureDevice) {
            guard coordinator?.device != device else { return }
            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
            self.coordinator = coordinator
            apply(coordinator.videoRotationAngleForHorizonLevelPreview)

            // KVO may report on any thread; the layer is only touched on main.
            observation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] coordinator, _ in
                let angle = coordinator.videoRotationAngleForHorizonLevelPreview
                DispatchQueue.main.async { self?.apply(angle) }
            }
        }

        private func apply(_ angle: CGFloat) {
            guard let connection = previewLayer.connection,
                  connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }
    }
}
