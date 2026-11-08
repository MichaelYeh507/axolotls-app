//
//  CameraView.swift
//  Axolotls
//
//  Part C (Photos). The Camera screen from the hi-fi Figma: live preview in a
//  rounded card, the group's current prompt at the top, the shutter at the
//  bottom. After a shot: review (Retake / Send), then a "sent" screen.
//
//  Present it full screen for one group:
//      .fullScreenCover(isPresented: $showingCamera) {
//          CameraView(group: group, userID: session.requireUserID)
//      }
//
//  No camera (the Simulator) or camera access denied: the screen offers the
//  photo library instead, so the flow can still be demoed on a laptop.
//

import SwiftUI
import AVFoundation
import PhotosUI

struct CameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var viewModel: CameraViewModel
    @State private var camera: CameraSession?
    @State private var cameraState: CameraState = .starting
    @State private var device: AVCaptureDevice?
    @State private var position: AVCaptureDevice.Position = .back
    @State private var pickerItem: PhotosPickerItem?

    private enum CameraState {
        case starting, running, unavailable, denied
    }

    init(group: Group,
         userID: String,
         uploader: any PhotoUploading = FirebasePhotoService(),
         quests: any QuestProviding = QuestService()) {
        _viewModel = State(initialValue: CameraViewModel(group: group, photographerId: userID,
                                                         uploader: uploader, quests: quests))
    }

    var body: some View {
        ZStack {
            PhotosTheme.cameraBackground
                .ignoresSafeArea()

            switch viewModel.phase {
            case .ready, .capturing:
                captureScreen
            case .review, .sending:
                reviewScreen
            case .sent:
                sentScreen
            }
        }
        .statusBarHidden()
        .task {
            await viewModel.loadQuest()
        }
        .task {
            await startCamera()
        }
        .task(id: viewModel.quest?.endsAt) {
            // When the prompt's time is up, load the next one.
            guard let endsAt = viewModel.quest?.endsAt else { return }
            let wait = endsAt.timeIntervalSinceNow
            if wait > 0 { try? await Task.sleep(for: .seconds(wait + 1)) }
            guard !Task.isCancelled else { return }
            await viewModel.loadQuest()
        }
        .onChange(of: pickerItem) { _, item in
            Task { await loadPickedPhoto(item) }
        }
        .onDisappear {
            camera?.stop()
        }
    }

    // MARK: - Capture

    private var captureScreen: some View {
        card {
            ZStack {
                cameraContent

                VStack(spacing: 0) {
                    header(showsBackButton: true)
                    Spacer(minLength: 0)
                    captureFooter
                }
            }
        }
    }

    @ViewBuilder
    private var cameraContent: some View {
        switch cameraState {
        case .starting:
            ProgressView()
                .tint(.white)
        case .running:
            if let camera {
                CameraPreview(session: camera.session, device: device)
            }
        case .unavailable:
            libraryFallback(icon: "camera.on.rectangle",
                            title: "No camera here",
                            message: "This device can't take photos (the iOS Simulator has no camera). Choose one from your library instead.",
                            showsSettingsButton: false)
        case .denied:
            libraryFallback(icon: "camera.badge.ellipsis",
                            title: "Camera access is off",
                            message: "Turn on camera access in Settings to take photos for \(viewModel.group.name), or choose one from your library.",
                            showsSettingsButton: true)
        }
    }

    private var captureFooter: some View {
        VStack(spacing: 12) {
            if let message = viewModel.errorMessage {
                errorBanner(message)
            }
            if viewModel.isEventOver {
                Text("This event has ended, so photos can't be added anymore.")
                    .font(.footnote.weight(.medium))
                    .multilineTextAlignment(.center)
            }

            if cameraState == .running || cameraState == .starting {
                HStack {
                    if cameraState == .running {
                        iconButton(viewModel.flashEnabled ? "bolt.fill" : "bolt.slash.fill",
                                   label: viewModel.flashEnabled ? "Flash on" : "Flash off") {
                            viewModel.flashEnabled.toggle()
                        }
                    } else {
                        iconPlaceholder
                    }

                    Spacer()

                    CaptureButton(size: 84, isBusy: viewModel.phase == .capturing) {
                        Task { await viewModel.capture() }
                    }
                    .disabled(!viewModel.canCapture)
                    .opacity(viewModel.canCapture || viewModel.phase == .capturing ? 1 : 0.5)
                    .accessibilityLabel("Take photo")

                    Spacer()

                    if cameraState == .running {
                        iconButton("arrow.triangle.2.circlepath.camera", label: "Flip camera") {
                            Task { await flipCamera() }
                        }
                    } else {
                        iconPlaceholder
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.top, 32)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom))
    }

    private func libraryFallback(icon: String, title: String, message: String,
                                 showsSettingsButton: Bool) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44))
            Text(title)
                .font(.title3.bold())
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .opacity(0.85)

            if showsSettingsButton {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose a Photo", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(PhotosTheme.coral)
            .foregroundStyle(.black)
            .disabled(viewModel.isEventOver)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 32)
        .padding(.top, 120)         // clear of the prompt at the top
    }

    // MARK: - Review

    private var reviewScreen: some View {
        card {
            ZStack {
                if let image = viewModel.reviewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                }

                VStack(spacing: 0) {
                    header(showsBackButton: false)
                    Spacer(minLength: 0)
                    reviewFooter
                }
            }
        }
    }

    private var reviewFooter: some View {
        VStack(spacing: 12) {
            if let message = viewModel.errorMessage {
                errorBanner(message)
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.retake()
                } label: {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .controlSize(.large)

                Button {
                    Task { await viewModel.send() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.phase == .sending {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text("Send")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PhotosTheme.coral)
                .foregroundStyle(.black)
                .controlSize(.large)
            }
            .disabled(viewModel.phase == .sending)

            Text("Only \(viewModel.group.name) will see it, after the reveal.")
                .font(.caption)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom))
    }

    // MARK: - Sent

    private var sentScreen: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 52))
                .padding(30)
                .background(.white.opacity(0.15), in: Circle())

            Text("Sent to \(viewModel.group.name)")
                .font(.title2.bold())

            Text("It stays hidden until the reveal on \(viewModel.group.revealAt.formatted(date: .abbreviated, time: .shortened)).")
                .font(.body)
                .opacity(0.9)

            Spacer()

            Button {
                Task { await viewModel.takeAnother() }
            } label: {
                Label("Take Another", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(PhotosTheme.coral)
            .foregroundStyle(.black)
            .controlSize(.large)

            Button("Done") { dismiss() }
                .font(.headline)
                .padding(.bottom, 8)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(24)
    }

    // MARK: - Shared pieces

    /// Back arrow, group name and the current prompt, over a dark fade for legibility.
    private func header(showsBackButton: Bool) -> some View {
        VStack(spacing: 14) {
            HStack {
                if showsBackButton {
                    iconButton("arrow.left", label: "Back") { dismiss() }
                } else {
                    iconPlaceholder
                }
                Spacer()
                Text(viewModel.group.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.35), in: Capsule())
                Spacer()
                iconPlaceholder            // keeps the name centered
            }

            if let quest = viewModel.quest {
                QuestBanner(quest: quest)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom))
    }

    /// The rounded card the Figma camera sits in, inset from the gradient background.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let inside = content()
        return Color.black
            .overlay { inside }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(12)
    }

    private func iconButton(_ systemImage: String, label: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.35), in: Circle())
        }
        .foregroundStyle(.white)
        .accessibilityLabel(label)
    }

    private var iconPlaceholder: some View {
        Color.clear.frame(width: 44, height: 44)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Camera control

    private func startCamera() async {
        guard CameraSession.isCameraAvailable else {
            cameraState = .unavailable
            return
        }
        guard await CameraSession.requestAccess() else {
            cameraState = .denied
            return
        }

        let session = camera ?? CameraSession()
        camera = session
        do {
            try await session.start(position: position)
            device = session.activeDevice
            viewModel.capturer = session
            cameraState = .running
        } catch {
            cameraState = .unavailable
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func flipCamera() async {
        guard let camera else { return }
        let newPosition: AVCaptureDevice.Position = position == .back ? .front : .back
        do {
            try await camera.start(position: newPosition)
            position = newPosition
            device = camera.activeDevice
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        pickerItem = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                viewModel.errorMessage = "That photo couldn't be loaded."
                return
            }
            viewModel.accept(data)
        } catch {
            viewModel.errorMessage = "That photo couldn't be loaded. \(error.localizedDescription)"
        }
    }
}

// MARK: - Quest prompt

/// "Take a photo with the tallest person in the room" + time left, as on the Figma camera.
private struct QuestBanner: View {
    let quest: CameraQuest

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(spacing: 4) {
                Text(quest.prompt)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text(quest.timeLeftText(from: context.date))
                    .font(.caption.weight(.medium))
                    .opacity(0.85)
            }
            .shadow(color: .black.opacity(0.5), radius: 4)
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current quest: \(quest.prompt)")
    }
}
