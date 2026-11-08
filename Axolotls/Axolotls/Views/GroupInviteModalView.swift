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
        let darkPurple = Color(red: 0.2196, green: 0.1568, blue: 0.3058)
        let mediumPurple = Color(red: 0.4117, green: 0.2941, blue: 0.5764)
        let coral = Color(red: 0.9921, green: 0.5882, blue: 0.5098)
        
        ZStack {
            LinearGradient(
              gradient: Gradient(colors: [darkPurple, mediumPurple]),
              startPoint: .trailing,
              endPoint: .bottomLeading
            ).ignoresSafeArea()
            
            VStack {
                Text("Invite Friends").font(.largeTitle).bold()
                VStack {
                    HStack {
                        Text("Group invite code").bold()
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding()
                    SegmentedJoinCodeView(joinCode: group.joinCode)
                    Button("Copy") {
                        UIPasteboard.general.string = group.joinCode
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle)
                    .foregroundStyle(.black)
                    .tint(coral)
                
                    HStack {
                        Text("Invite from friends list").bold()
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding()
                    SwiftUI.Group {
                        if viewModel.isLoading {
                            ProgressView("Loading friends...")
                        } else if viewModel.errorMessage != nil {
                            Text("Unable to load friends.")
                        } else if viewModel.friends.isEmpty {
                            Text("Your friends will appear here.")
                        } else {
                            List(viewModel.friends.indices, id: \.self) { index in
                                HStack {
                                    Text(viewModel.friends[index].0.username)
                                    .foregroundStyle(.black)
                                    Spacer()
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
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle)
                        .controlSize(.large)
                        .foregroundStyle(.black)
                        .tint(coral)
                        
                        Button("Send") {
                            Task {
                                if await viewModel.inviteFriends(groupId: group.id) { dismiss() }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle)
                        .controlSize(.large)
                        .foregroundStyle(.black)
                        .tint(coral)
                    }
                }
            }
            .task(id: session.userID) {
                await viewModel.loadFriends(curUserId: session.userID, members: members)
            }
            .foregroundStyle(.white)
            .frame(alignment: .leading)
            .padding()
        }
    }
}
