//
//  NewGroupView.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/5/26.
//
import SwiftUI

struct NewGroupView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = NewGroupViewModel()
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            GroupFormView(
                name: $viewModel.name,
                description: $viewModel.description,
                mode: $viewModel.mode,
                revealAt: $viewModel.revealAt
            )
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Create") {
                        Task {
                            if await viewModel.createGroup(for: session.userID) { dismiss() }
                        }
                    }
                    .bold()
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
        }
    }
}
