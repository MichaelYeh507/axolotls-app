//
//  GroupInviteModalView.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/7/26.
//

import SwiftUI

struct GroupInviteModalView: View {
    var group: Group
    var members: [UserProfile]
    
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = GroupInviteModalViewModel()
    
    var body: some View {
        let coral = Color(red: 0.9921, green: 0.5882, blue: 0.5098)
        
        VStack {
            Text("Invite Friends").font(.largeTitle)
            VStack {
                HStack {
                    Text("Group invite code")
                    Button("Copy") {
                        UIPasteboard.general.string = group.joinCode
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.black)
                    .tint(coral)
                }
                SegmentedJoinCodeView(joinCode: group.joinCode)
            }
            
            VStack {
                Text("Invite from friends list")
                SwiftUI.Group {
                    if viewModel.isLoading {
                        ProgressView("Loading friends...")
                    } else if let errorMessage = viewModel.errorMessage {
                        ContentUnavailableView(
                            "Unable to Load Friends",
                            systemImage: "exclamationmark.triangle",
                            description: Text(errorMessage)
                        )
                    } else if viewModel.friends.isEmpty {
                        ContentUnavailableView(
                            "No Friends Yet",
                            systemImage: "person.3",
                            description: Text("Your friends will appear here.")
                        )
                    } else {
                        List(viewModel.friends.indices, id: \.self) { index in
                            HStack {
                                Text(viewModel.friends[index].0.username)
                                .foregroundStyle(.black)
                                
                                Button {
                                    viewModel.friends[index].1.toggle()
                                } label: {
                                    Image(systemName: viewModel.friends[index].1
                                        ? "checkmark.circle.fill"
                                        : "circle")
                                }
                                .accessibilityLabel(
                                    viewModel.friends[index].1
                                        ? "Remove \(viewModel.friends[index].0.username)"
                                        : "Add \(viewModel.friends[index].0.username)"
                                )
                            }
                        }
                    }
                }
                Button("Send") {
                    Task {
                        if await viewModel.inviteFriends(groupId: group.id) { dismiss() }
                    }
                }
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .task(id: session.userID) {
            await viewModel.loadFriends(curUserId: session.userID, members: members)
        }
        .frame(alignment: .leading)
        .padding()
    }
}
