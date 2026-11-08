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
    
    var body: some View {
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
                .scrollContentBackground(.hidden)
            }
        }
        .task(id: session.userID) {
            await viewModel.loadGroups(for: session.userID)
        }
    }
}
