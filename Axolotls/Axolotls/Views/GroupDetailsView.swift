//
//  GroupView.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/5/26.
//

import SwiftUI

struct GroupDetailsView: View {
    var group: Group
    
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var invitePopup = false
    @State private var viewModel = GroupDetailsViewModel()
    @State private var showConfirmation = false
    
    var body: some View {
        let darkPurple = Color(red: 0.2196, green: 0.1568, blue: 0.3058)
        let mediumPurple = Color(red: 0.4117, green: 0.2941, blue: 0.5764)
        let coral = Color(red: 0.9921, green: 0.5882, blue: 0.5098)
        
        ZStack {
            LinearGradient(
              gradient: Gradient(colors: [darkPurple, mediumPurple]),
              startPoint: .trailing,
              endPoint: .bottomLeading)

            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text(group.name)
                        .font(.largeTitle)
                    Text(group.description)
                        .multilineTextAlignment(.leading)

                    Button("Invite People") {
                        invitePopup.toggle()
                    }.sheet(isPresented: $invitePopup) {
                        GroupInviteModalView(group: group, members: viewModel.members)
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.black)
                    .tint(coral)

                    Text("Members")
                        .font(.largeTitle)
                    SwiftUI.Group {
                        if viewModel.isLoading {
                            ProgressView("Loading members...")
                        } else if let errorMessage = viewModel.errorMessage {
                            ContentUnavailableView(
                                "Unable to Load Members",
                                systemImage: "exclamationmark.triangle",
                                description: Text(errorMessage)
                            )
                        } else if viewModel.members.isEmpty {
                            ContentUnavailableView(
                                "No Other Members Yet",
                                systemImage: "person.3",
                                description: Text("Members added to the group will appear here.")
                            )
                        } else {
                            List(viewModel.members) { member in
                                Text(member.username).foregroundStyle(.black)
                            }
                        }
                    }

                    Text("Photos")
                        .font(.largeTitle)
                    Text("[photos here]")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        NavigationLink("Edit Group") {
                            EditGroupView(group: group)
                        }
                        Button("Invite People") {
                            invitePopup.toggle()
                        }.sheet(isPresented: $invitePopup) {
                            GroupInviteModalView(group: group, members: viewModel.members)
                        }
                        Button("Leave Group", role: .destructive) {
                            showConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .foregroundStyle(.black)
                    .confirmationDialog(
                        "Permanently leave the group?",
                        isPresented: $showConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Leave Group", role: .destructive) {
                            Task {
                                if await viewModel.leaveGroup(
                                    groupId: group.id,
                                    userId: session.userID
                                ) {
                                    dismiss()
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("You cannot undo this action.")
                    }
                }
            }
            .foregroundStyle(.white)
            .task(id: session.userID) {
                await viewModel.loadMembers(groupId: group.id, curUserId: session.userID)
            }
        }
    }
}
