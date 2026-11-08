//
//  InvitesView.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/7/26.
//

import SwiftUI

struct InvitesView: View {
    var pendingGroups: [Group]
    var refreshPending: () async -> Void
    
    @EnvironmentObject private var session: AppSession
    @State private var viewModel = InvitesViewModel()
    
    var body: some View {
        SwiftUI.Group {
            if !pendingGroups.isEmpty {
                List(pendingGroups) { group in
                    HStack {
                        Text("You were invited to join \(group.name)")
                        Button {
                            Task {
                                let accepted = await viewModel.acceptInvite(
                                    userId: session.userID,
                                    groupId: group.id
                                )
                                if accepted {
                                    await refreshPending()
                                }
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                        }
                        .accessibilityLabel("Accept invite")
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .tint(.green)
                        
                        Button {
                            Task {
                                let accepted = await viewModel.declineInvite(
                                    userId: session.userID,
                                    groupId: group.id
                                )
                                if accepted {
                                    await refreshPending()
                                }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.subheadline.weight(.semibold))
                        }
                        .accessibilityLabel("Decline invite")
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .tint(.red)
                    }
                    .padding(.vertical, 2)
                    .listRowInsets(
                        EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 8)
                    )
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(height: 100)
    }
}
