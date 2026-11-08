//
//  GroupsView.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/5/26.
//

import SwiftUI

struct GroupsView: View {
    @EnvironmentObject private var session: AppSession
    @State private var viewModel = GroupsViewModel()
    @State private var revealViewModel = GroupRevealViewModel()
    @State private var revealRoute: RevealRoute?          // where we navigate to
    @State private var pendingRevealRoute: RevealRoute?   // held until the popup closes
    
    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if viewModel.isLoading {
                    ProgressView("Loading groups...")
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Unable to Load Groups",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.groups.isEmpty {
                    ContentUnavailableView(
                        "No Groups Yet",
                        systemImage: "person.3",
                        description: Text("Groups you join will appear here.")
                    )
                } else {
                    List(viewModel.groups) { group in
                        NavigationLink {
                            GroupDetailsView(group: group)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                    .font(.headline)
                                Text(group.description)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationDestination(item: $revealRoute) { route in
                revealDestination(for: route)
            }
            .onAppear { revealViewModel.check(viewModel.groups) }
        }
        .task(id: session.userID) {
            await viewModel.loadGroups(for: session.userID)
        }
        //reveal
        .task(id: viewModel.groups.map(\.id)) {
            await revealViewModel.watch(viewModel.groups)
        }
        .fullScreenCover(
            item: Binding(get: { revealViewModel.readyGroup }, set: { _ in }),
            onDismiss: {
                revealRoute = pendingRevealRoute
                pendingRevealRoute = nil
            }
        ) { group in
            PhotosReadyPopup(
                group: group,
                onGuess: { pendingRevealRoute = revealViewModel.guessTapped() },
                onRevealAlbum: { pendingRevealRoute = revealViewModel.revealAlbumTapped() }
            )
            .presentationBackground(.clear)
        }
    }

    //reveal
    @ViewBuilder
    private func revealDestination(for route: RevealRoute) -> some View {
        switch route {
        case .guessPhotoTakers(let groupID):
            if let group = viewModel.groups.first(where: { $0.id == groupID }) {
                GuessPhotoTakersView(group: group)
            }
        case .album(let groupID):
            if let group = viewModel.groups.first(where: { $0.id == groupID }) {
                GroupDetailsView(group: group)
            }
        }
    }
}
