//
//  GroupViewModel.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/5/26.
//

import Foundation
import Observation
import FirebaseFirestore

@Observable
final class EditGroupViewModel {
    
    // MARK: Fields
    let group: Group
    
    var name: String
    var description: String
    var mode: String
    var revealAt: Date
    
    var isSaving = false
    var errorMessage: String?
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    init(group: Group) {
        self.group = group
        self.name = group.name
        self.description = group.description
        self.mode = group.mode
        self.revealAt = group.revealAt
    }
    
    @MainActor
    func saveChanges() async -> Bool {
        guard let groupID = group.id else {
            errorMessage = "Missing group document ID."
            return false
        }
        
        isSaving = true
        errorMessage = nil
        
        let updatedGroup = Group(
            id: groupID,
            name: name.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            mode: mode,
            createdAt: group.createdAt,
            revealAt: revealAt
        )
        
        do {
            try Firestore.firestore()
                .collection("groups")
                .document(groupID)
                .setData(from: updatedGroup, merge: true)
            
            isSaving = false
            return true
        } catch {
            isSaving = false
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
