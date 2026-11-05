//
//  EditGroupView.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/5/26.
//

import SwiftUI

struct EditGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditGroupViewModel
    
    init(group: Group) {
        _viewModel = State(initialValue: EditGroupViewModel(group: group))
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack{
            GroupFormView(
                name: $viewModel.name,
                description: $viewModel.description,
                revealAt: $viewModel.revealAt
            )
            .navigationTitle("Edit Group")
            .toolbar{
                Button("Cancel") {
                    dismiss()
                }
                .disabled(viewModel.isSaving)
                
                Button("Save") {
                    Task {
                        await viewModel.saveChanges()
                    }
                }
                .disabled(viewModel.isSaving || !viewModel.isValid)
            }
            
        }
    }
}
