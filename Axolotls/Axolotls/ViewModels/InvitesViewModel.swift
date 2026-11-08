//
//  InvitesViewModel.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/7/26.
//

import FirebaseFirestore

final class InvitesViewModel {
    var isSaving = false
    var errorMessage: String?
    
    func acceptInvite(userId: String?, groupId: String?) async -> Bool {
        guard let userId else {
            isSaving = false
            errorMessage = "You must be signed in to accept an invite"
            return false
        }
        guard let groupId else {
            isSaving = false
            errorMessage = "You must select a group to accept it's invite"
            return false
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            let membershipSnapshot = try await Firestore.app
                .collection("membership")
                .whereField("user_id", isEqualTo: userId)
                .whereField("group_id", isEqualTo: groupId)
                .getDocuments()
            
            if membershipSnapshot.documents.count == 0 {
                isSaving = false
                errorMessage = "No invite for this group was found"
                return false
            }
            
            let membershipDocument = membershipSnapshot.documents[0]
            try await membershipDocument.reference.updateData([
                "membership_status": "active",
                "joined_at": Date()
            ])
            
            isSaving = false
            return true
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func declineInvite(userId: String?, groupId: String?) async -> Bool {
        guard let userId else {
            isSaving = false
            errorMessage = "You must be signed in to decline an invite"
            return false
        }
        guard let groupId else {
            isSaving = false
            errorMessage = "You must select a group to decline it's invite"
            return false
        }
        
        isSaving = true
        errorMessage = nil
        
        do {
            let membershipSnapshot = try await Firestore.app
                .collection("membership")
                .whereField("user_id", isEqualTo: userId)
                .whereField("group_id", isEqualTo: groupId)
                .getDocuments()
            
            if membershipSnapshot.documents.count == 0 {
                isSaving = false
                errorMessage = "No invite for this group was found"
                return false
            }
            
            let membershipDocument = membershipSnapshot.documents[0]
            try await membershipDocument.reference.delete()
            
            isSaving = false
            return true
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
            return false
        }
    }
}
