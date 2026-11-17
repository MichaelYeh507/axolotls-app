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
    let onSave: (Group) -> Void

    init(group: Group, onSave: @escaping (Group) -> Void) {
        _viewModel = State(initialValue: EditGroupViewModel(group: group))
        self.onSave = onSave
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        NavigationStack{
            GroupFormView(
                name: $viewModel.name,
                description: $viewModel.description,
                mode: $viewModel.mode,
                revealAt: $viewModel.revealAt
            )
            .navigationTitle("Edit Group")
            .toolbar{
                ToolbarItem(placement: .bottomBar) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Save") {
                        Task {
                            if let updatedGroup = await viewModel.saveChanges() {
                                onSave(updatedGroup)
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving || !viewModel.isValid)
                }
            }
            
        }
    }
}
