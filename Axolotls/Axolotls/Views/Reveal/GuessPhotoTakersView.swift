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

    @EnvironmentObject private var appSession: AppSession
    @State private var viewModel: GuessGameViewModel
    @State private var runID = 0

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
        .task(id: runID) {
            guard let userID = appSession.userID else { return }
            await viewModel.run(userId: userID)
        }
        .task(id: viewModel.gameSession?.startedAt) {
            await viewModel.preloadImages()
        }
        .onDisappear { viewModel.leaveLobby() }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { viewModel.actionError != nil }, set: { if !$0 { viewModel.actionError = nil } })
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.actionError ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.stage {
        case .loading:
            ProgressView("Loading game...")
                .tint(.white)
        case .failed(let message):
            messageView(icon: "exclamationmark.triangle", title: "Couldn't load the game", detail: message)
        case .noPhotos:
            messageView(icon: "photo.on.rectangle", title: "No photos yet",
                        detail: "\(group.name) doesn't have any photos to guess.")
        case .lobby:
            lobbyView
        case .alreadyStarted:
            messageView(icon: "hourglass", title: "Game in progress",
                        detail: "This game started without you. You can join the next one when it's over.")
        case .countdown(let secondsLeft):
            VStack(spacing: 12) {
                Text("Get ready!")
                    .font(.title2.bold())
                Text("\(secondsLeft)")
                    .font(.system(size: 80, weight: .bold))
            }
        case .answering(let index, let secondsLeft):
            roundView(index: index, secondsLeft: secondsLeft)
        case .result(let index):
            roundView(index: index, secondsLeft: nil)
        case .finished:
            leaderboardView
        }
    }

    // MARK: Lobby

    private var lobbyView: some View {
        VStack(spacing: 16) {
            Text("Who's playing?")
                .font(.title.bold())
            Text("Tap Ready to join, or play solo. Players get 15 seconds per photo.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.readyPlayers) { player in
                        HStack {
                            Text(player.name)
                                .font(.headline)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .padding()
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            Text(lobbyStatus)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))

            Button {
                Task { await viewModel.toggleReady() }
            } label: {
                Text(viewModel.isReady ? "Not Ready" : "Ready")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .tint(.white)

            if viewModel.canStart {
                Button {
                    Task { await viewModel.start() }
                } label: {
                    Text(viewModel.readyCount == 1 ? "Play Solo" : "Start Game")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(PhotosTheme.coral)
                .foregroundStyle(.black)
                .disabled(viewModel.isStarting)
            }
        }
    }

    private var lobbyStatus: String {
        if viewModel.readyCount == 0 {
            return "Tap Ready to play. You can play solo or wait for others to join."
        }
        if viewModel.canStart && viewModel.readyCount == 1 {
            return "No one else is ready yet. Play solo now, or wait for others to tap Ready."
        }
        if viewModel.canStart {
            return "Everyone who's ready will play."
        }
        return viewModel.isReady ? "Waiting for the game to start." : "Tap Ready to play in this game."
    }

    // MARK: Round

    @ViewBuilder
    private func roundView(index: Int, secondsLeft: Int?) -> some View {
        if let round = viewModel.round(at: index) {
            VStack(spacing: 16) {
                HStack {
                    Text("Photo \(index + 1) of \(viewModel.roundCount)")
                    Spacer()
                    if let secondsLeft {
                        Label("\(secondsLeft)", systemImage: "timer")
                            .foregroundStyle(secondsLeft <= 5 ? PhotosTheme.coral : .white)
                            .monospacedDigit()
                    }
                    Spacer()
                    Text("Score: \(viewModel.myScore(throughRound: secondsLeft == nil ? index : index - 1))")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.8))

                photoView(round)

                Text(prompt(for: round, index: index, isRevealed: secondsLeft == nil))
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(promptColor(for: round, isRevealed: secondsLeft == nil))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(round.choices) { player in
                        playerButton(player, round: round, isRevealed: secondsLeft == nil)
                    }
                }

                Spacer(minLength: 0)
            }
        } else {
            messageView(icon: "photo", title: "This photo is unavailable",
                        detail: "The next one will appear when the timer ends.")
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

    private func playerButton(_ player: GamePlayer, round: GuessRound, isRevealed: Bool) -> some View {
        Button {
            Task { await viewModel.guess(player) }
        } label: {
            Text(player.name)
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(buttonColor(player, round: round, isRevealed: isRevealed),
                            in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
        // No guessing while the photo loads. A failed photo stays guessable so nobody is locked out.
        .disabled(isRevealed || round.hasGuessed
                  || (viewModel.image(for: round) == nil && !viewModel.imageFailed(for: round)))
    }

    //the right answer only shows when the timer ends, for everyone at once
    private func buttonColor(_ player: GamePlayer, round: GuessRound, isRevealed: Bool) -> Color {
        guard isRevealed else {
            return player.id == round.guessedPlayerId ? .white.opacity(0.4) : .white.opacity(0.15)
        }
        if player.id == round.answerId { return .green.opacity(0.8) }
        if player.id == round.guessedPlayerId { return PhotosTheme.coral.opacity(0.8) }
        return .white.opacity(0.08)
    }

    private func prompt(for round: GuessRound, index: Int, isRevealed: Bool) -> String {
        guard isRevealed else {
            guard round.hasGuessed else { return "Who took this?" }
            let waiting = viewModel.playersStillAnswering(round: index)
            return waiting > 0 ? "Locked in! Waiting for \(waiting) more..." : "Locked in!"
        }
        if round.isCorrect { return "Correct!" }
        let answer = viewModel.name(for: round.answerId)
        return round.hasGuessed ? "Nope! It was \(answer)" : "Time's up! It was \(answer)"
    }

    private func promptColor(for round: GuessRound, isRevealed: Bool) -> Color {
        guard isRevealed else { return .white }
        return round.isCorrect ? .green : PhotosTheme.coral
    }

    // MARK: Leaderboard

    private var leaderboardView: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundStyle(PhotosTheme.coral)

            Text("Leaderboard")
                .font(.title.bold())

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { position, entry in
                        HStack(spacing: 12) {
                            Text("\(position + 1)")
                                .font(.headline)
                                .frame(width: 28)
                            Text(entry.id == viewModel.userId ? "\(entry.name) (You)" : entry.name)
                                .font(.headline)
                                .lineLimit(1)
                            Spacer()
                            Text("\(entry.score) / \(viewModel.roundCount)")
                                .font(.headline)
                                .monospacedDigit()
                        }
                        .padding()
                        .background(.white.opacity(position == 0 ? 0.25 : 0.12),
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            Button {
                runID += 1
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
