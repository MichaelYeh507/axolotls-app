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
              endPoint: .bottomLeading
            ).ignoresSafeArea()

            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text(group.name)
                        .font(.largeTitle).bold()
                    Text(group.description)
                        .multilineTextAlignment(.leading)

                    VStack {
                        Button("Invite People") {
                            invitePopup.toggle()
                        }.sheet(isPresented: $invitePopup) {
                            GroupInviteModalView(group: group, members: viewModel.members)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle)
                        .controlSize(.large)
                        .foregroundStyle(.black)
                        .tint(coral)
                    }
                    .frame(maxWidth: .infinity)

                    Text("Members")
                        .font(.title).bold()
                    SwiftUI.Group {
                        if viewModel.isLoading {
                            ProgressView("Loading members...")
                        } else if viewModel.errorMessage != nil {
                            Text("Unable to load members")
                        } else if viewModel.members.isEmpty {
                            Text("Members added to the group will appear here.")
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(viewModel.members) { member in
                                        Text(member.username)
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(.white.opacity(0.9))
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .frame(height: 50)
                        }
                    }

                    Text("Photos")
                        .font(.title).bold()
                    Text("[photos here in V2]")
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
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
