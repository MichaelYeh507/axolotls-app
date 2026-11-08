//
//  GuessPhotoTakesView.swift
//  Axolotls
//
//  Created by Lily Beerhalter on 11/6/26.
//

import SwiftUI

struct GuessPhotoTakersView: View {
    let group: Group

    var body: some View {
        ZStack {
            LinearGradient(colors: [PhotosTheme.mediumPurple, PhotosTheme.darkPurple],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Guess the Photo Takers")
                    .font(.title.bold())
                Text("The game for \(group.name) is coming soon.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(.white)
            .padding()
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
