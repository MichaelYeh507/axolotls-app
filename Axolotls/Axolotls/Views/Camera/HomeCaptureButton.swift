//
//  HomeCaptureButton.swift
//  Axolotls
//
//  Part C (Photos). The shutter button at the bottom of Home. It decides where
//  the photo goes (see CaptureDestination):
//    • one active group  → opens the camera for it
//    • several           → asks which group first
//    • none              → explains that you need a group
//  Reuses Part B's GroupsViewModel to load the signed-in user's groups.
//

import SwiftUI

struct HomeCaptureButton: View {
    @EnvironmentObject private var session: AppSession

    @State private var groupsModel = GroupsViewModel()
    @State private var isLoading = false
    @State private var choices: [Group] = []
    @State private var showingPicker = false
    @State private var pickedGroup: Group?          // set by the picker, opened after it closes
    @State private var cameraGroup: Group?          // drives the full-screen camera
    @State private var alertMessage: String?

    var body: some View {
        CaptureButton(size: 76, isBusy: isLoading) {
            Task { await openCamera() }
        }
        .accessibilityLabel("Take a photo")
        .padding(.vertical, 8)
        .sheet(isPresented: $showingPicker, onDismiss: openPickedGroup) {
            GroupPickerView(groups: choices) { group in
                pickedGroup = group
                showingPicker = false
            }
        }
        .fullScreenCover(item: $cameraGroup) { group in
            if let userID = session.userID {
                CameraView(group: group, userID: userID)
            }
        }
        .alert("Can't open the camera",
               isPresented: Binding(get: { alertMessage != nil },
                                    set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func openCamera() async {
        isLoading = true
        await groupsModel.loadGroups(for: session.userID)
        isLoading = false

        if let error = groupsModel.errorMessage {
            alertMessage = "Your groups couldn't be loaded. \(error)"
            return
        }

        switch CaptureDestination.resolve(from: groupsModel.groups, at: Date()) {
        case .noGroups:
            alertMessage = "Create or join a group first. Photos go to a group and stay hidden until its event ends."
        case .single(let group):
            cameraGroup = group
        case .choose(let groups):
            choices = groups
            showingPicker = true
        }
    }

    /// A full-screen cover can't open while the sheet is still closing, so wait for onDismiss.
    private func openPickedGroup() {
        guard let group = pickedGroup else { return }
        pickedGroup = nil
        cameraGroup = group
    }
}
