//
//  NewGroupView.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/5/26.
//
import SwiftUI

struct NewGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = NewGroupViewModel()
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack {
            GroupFormView(
                name: $viewModel.name,
                description: $viewModel.description,
                revealAt: $viewModel.revealAt
            )
            .navigationTitle("New Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            if await viewModel.createGroup() { dismiss() }
                        }
                    }
                    .bold()
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
        }
    }
}
