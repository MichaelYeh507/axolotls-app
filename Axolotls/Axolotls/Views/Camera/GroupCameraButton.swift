//
//  GroupCameraButton.swift
//  Axolotls
//
//  Part C (Photos). "Take a Photo" on a group page: photos taken here always go
//  to this group (Sprint 3 user-testing lesson). Hidden once the event has
//  ended, since that's when photos are revealed.
//
//  Usage (one line in GroupDetailsView):  GroupCameraButton(group: group)
//

import SwiftUI

struct GroupCameraButton: View {
    let group: Group
    var onCameraClosed: () -> Void = {}

    @EnvironmentObject private var session: AppSession
    @State private var showingCamera = false

    var body: some View {
        if group.revealAt > Date() {
            Button {
                showingCamera = true
            } label: {
                Label("Take a Photo", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(PhotosTheme.coral)
            .foregroundStyle(.black)
            .controlSize(.large)
            .disabled(session.userID == nil)
            .fullScreenCover(isPresented: $showingCamera, onDismiss: onCameraClosed) {
                if let userID = session.userID {
                    CameraView(group: group, userID: userID)
                }
            }
        }
    }
}
