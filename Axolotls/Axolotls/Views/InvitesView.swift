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
        let coral = Color(red: 0.9921, green: 0.5882, blue: 0.5098)
        
        SwiftUI.Group {
            if !pendingGroups.isEmpty {
                List(pendingGroups) { group in
                    HStack {
                        Text("You were invited to join \(group.name)")
                        Button("Accept") {
                            Task {
                                let accepted = await viewModel.acceptInvite(
                                    userId: session.userID,
                                    groupId: group.id
                                )
                                if accepted {
                                    await refreshPending()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(.black)
                        .tint(coral)
                    }
                }
            }
        }
    }
}
