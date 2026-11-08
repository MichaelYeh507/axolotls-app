//
//  JoinGroupViewModel.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/7/26.
//

import FirebaseFirestore

@MainActor
final class JoinGroupViewModel {
    var isSaving = false
    var errorMessage: String?
    
    func joinGroup(joinCode: String?, userId: String?) async -> Bool {
        guard let userId else {
            errorMessage = "You must be signed in to join a group."
            return false
        }
        guard let joinCode else {
            errorMessage = "Enter the 6-digit code to join a group."
            return false
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            let groupSnapshot = try await Firestore.app
                .collection("groups")
                .whereField("join_code", isEqualTo: joinCode)
                .getDocuments()
            
            if groupSnapshot.documents.count == 0 {
                isSaving = false
                errorMessage = "No group with this code was found."
                return false
            }
            
            let groupReference = groupSnapshot.documents[0]
            
            let membershipSnapshot = try await Firestore.app
                .collection("membership")
                .whereField("user_id", isEqualTo: userId)
                .whereField("group_id", isEqualTo: groupReference.documentID)
                .getDocuments()
            
            if membershipSnapshot.documents.count != 0 {
                isSaving = false
                errorMessage = "Already in this group"
                return false
            }
            
            let membership = Membership(
                userId: userId,
                groupId: groupReference.documentID,
                role: "member",
                membershipStatus: "active",
                joinedAt: Date()
            )
            
            try Firestore.app
                .collection("membership")
                .addDocument(from: membership)
                
            isSaving = false
            return true
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
            return false
        }
    }
}
