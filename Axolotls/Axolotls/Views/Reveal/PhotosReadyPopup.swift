//
//  PhotosReadyPopup.swift
//  Axolotls
//
//  Created by Lily Beerhalter on 11/6/26.
//

import SwiftUI

struct PhotosReadyPopup: View {
    let group: Group
    let onGuess: () -> Void
    let onRevealAlbum: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(PhotosTheme.coral)

                VStack(spacing: 6) {
                    Text("Your photos are ready!")
                        .font(.title.bold())
                    Text(group.name)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    Button(action: onGuess) {
                        Text("Guess the Photo Takers")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PhotosTheme.coral)
                    .foregroundStyle(.black)

                    Button(action: onRevealAlbum) {
                        Text("Reveal the Album")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
            }
            .foregroundStyle(.white)
            .padding(28)
            .background(
                LinearGradient(colors: [PhotosTheme.mediumPurple, PhotosTheme.darkPurple],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 28)
            )
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .accessibilityAddTraits(.isModal)
    }
}
