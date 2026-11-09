//
//  GuessPhotoTakesView.swift
//  Axolotls
//
//  Created by Lily Beerhalter on 11/6/26.
//

import SwiftUI

struct GuessPhotoTakersView: View {
    let group: Group
    let onBackToGroup: () -> Void

    @State private var viewModel: GuessGameViewModel

    init(group: Group, onBackToGroup: @escaping () -> Void) {
        self.group = group
        self.onBackToGroup = onBackToGroup
        _viewModel = State(initialValue: GuessGameViewModel(groupId: group.id ?? ""))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [PhotosTheme.mediumPurple, PhotosTheme.darkPurple],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            content
                .foregroundStyle(.white)
                .padding()
        }
        .navigationTitle("Guess the Photo Takers")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Loading photos...")
                .tint(.white)
        case .failed(let message):
            messageView(icon: "exclamationmark.triangle", title: "Couldn't load the game", detail: message)
        case .noPhotos:
            messageView(icon: "photo.on.rectangle", title: "No photos yet",
                        detail: "\(group.name) doesn't have any photos to guess.")
        case .playing:
            if let round = viewModel.game.current {
                roundView(round)
            }
        case .finished:
            resultsView
        }
    }

    // MARK: Round

    private func roundView(_ round: GuessRound) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Photo \(viewModel.game.roundNumber) of \(viewModel.game.rounds.count)")
                Spacer()
                Text("Score: \(viewModel.game.score)")
            }
            .font(.subheadline.bold())
            .foregroundStyle(.white.opacity(0.8))

            photoView(round)

            Text(round.hasGuessed ? feedback(for: round) : "Who took this?")
                .font(.title3.bold())
                .foregroundStyle(round.hasGuessed ? (round.isCorrect ? .green : PhotosTheme.coral) : .white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(round.choices) { player in
                    playerButton(player, round: round)
                }
            }

            Spacer(minLength: 0)

            if round.hasGuessed {
                Button {
                    viewModel.next()
                } label: {
                    Text(viewModel.game.roundNumber == viewModel.game.rounds.count ? "See Results" : "Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(PhotosTheme.coral)
                .foregroundStyle(.black)
            }
        }
        .task(id: round.id) {
            await viewModel.loadImage(for: round.photo)
            // get the next photo ready while they guess
            let nextIndex = viewModel.game.currentIndex + 1
            if nextIndex < viewModel.game.rounds.count {
                await viewModel.loadImage(for: viewModel.game.rounds[nextIndex].photo)
            }
        }
    }

    private func photoView(_ round: GuessRound) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.white.opacity(0.1))
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .overlay {
                if let image = viewModel.image(for: round) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if viewModel.imageFailed(for: round) {
                    VStack(spacing: 8) {
                        Text("Couldn't load this photo")
                        Button("Try Again") {
                            Task { await viewModel.loadImage(for: round.photo) }
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func playerButton(_ player: GamePlayer, round: GuessRound) -> some View {
        Button {
            viewModel.guess(player)
        } label: {
            Text(player.name)
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(buttonColor(player, round: round), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
        // No guessing while the photo loads. A failed photo stays guessable so the game can't get stuck.
        .disabled(round.hasGuessed || (viewModel.image(for: round) == nil && !viewModel.imageFailed(for: round)))
    }

    //after a guess: the right answer turns green, a wrong pick turns coral
    private func buttonColor(_ player: GamePlayer, round: GuessRound) -> Color {
        guard round.hasGuessed else { return .white.opacity(0.15) }
        if player.id == round.answerId { return .green.opacity(0.8) }
        if player.id == round.guessedPlayerId { return PhotosTheme.coral.opacity(0.8) }
        return .white.opacity(0.08)
    }

    private func feedback(for round: GuessRound) -> String {
        round.isCorrect ? "Correct!" : "Nope! It was \(viewModel.name(for: round.answerId))"
    }

    // MARK: Results

    private var resultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundStyle(PhotosTheme.coral)

            Text("You got \(viewModel.game.score) out of \(viewModel.game.rounds.count)!")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Button {
                viewModel.playAgain()
            } label: {
                Text("Play Again")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(PhotosTheme.coral)
            .foregroundStyle(.black)

            backToGroupButton
        }
    }

    private var backToGroupButton: some View {
        Button("Back to Group", action: onBackToGroup)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.8))
    }

    private func messageView(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(PhotosTheme.coral)
            Text(title)
                .font(.title2.bold())
            Text(detail)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            backToGroupButton
        }
    }
}
