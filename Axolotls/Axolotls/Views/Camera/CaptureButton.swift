//
//  CaptureButton.swift
//  Axolotls
//
//  Part C (Photos). The round shutter button from the Figma Home and Camera
//  screens: white center, dark gap, coral ring.
//

import SwiftUI

struct CaptureButton: View {
    var size: CGFloat = 76
    var isBusy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(PhotosTheme.darkPurple)
                Circle()
                    .strokeBorder(PhotosTheme.coral, lineWidth: size * 0.05)
                Circle()
                    .fill(.white)
                    .padding(size * 0.11)
                if isBusy {
                    ProgressView()
                        .tint(PhotosTheme.darkPurple)
                }
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }
}

#Preview {
    VStack(spacing: 24) {
        CaptureButton {}
        CaptureButton(size: 88, isBusy: true) {}
    }
    .padding()
    .background(PhotosTheme.mediumPurple)
}
