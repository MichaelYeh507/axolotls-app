//
//  GroupDetailsViewModel.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/7/26.
//

import Observation
import FirebaseFirestore

@MainActor
@Observable
final class GroupDetailsViewModel {
    var members: [UserProfile] = []
    
    var isLoading = false
    var errorMessage: String?
    
    var isSaving = false
    var leaveErrorMessage: String?
    
    func loadMembers(groupId: String?, curUserId: String?) async {
        guard let curUserId else {
            members = []
            isLoading = false
            errorMessage = "You must be signed in to view group details"
            return
        }
        guard let groupId else {
            members = []
            isLoading = false
            errorMessage = "You must select a group to view it's details"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let membershipSnapshot = try await Firestore.app
                .collection("membership")
                .whereField("group_id", isEqualTo: groupId)
                .getDocuments()
            
            let memberships = try membershipSnapshot.documents.map {
                try $0.data(as: Membership.self)
            }

            let activeUserIds = Array(Set(memberships
                .filter { ($0.membershipStatus == "active") && ($0.userId != curUserId)}
                .map(\.userId)))
            
            members = try await activeUserIds.asyncMap { userId in
                let snapshot = try await Firestore.app
                    .collection("users")
                    .document(userId)
                    .getDocument()

                guard snapshot.exists else {
                    throw GroupDetailsViewModelError.missingUser(userId)
                }

                return try snapshot.data(as: UserProfile.self)
            }
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return
        }
    }
    
    func leaveGroup(groupId: String?, userId: String?) async -> Bool {
        guard let userId else {
            isSaving = false
            leaveErrorMessage = "You must be signed in to leave a group"
            return false
        }
        guard let groupId else {
            isSaving = false
            leaveErrorMessage = "You must select a group to leave it"
            return false
        }
        
        isSaving = true
        leaveErrorMessage = nil
        
        do {
            let membershipSnapshot = try await Firestore.app
                .collection("membership")
                .whereField("user_id", isEqualTo: userId)
                .whereField("group_id", isEqualTo: groupId)
                .getDocuments()
            
            if membershipSnapshot.documents.count == 0 {
                isSaving = false
                errorMessage = "The group was not found"
                return false
            }
            
            let membershipDocument = membershipSnapshot.documents[0]
            let curMember = try membershipDocument.data(as: Membership.self)
            
            // Delete this user's membership with the group
            try await membershipDocument.reference.delete()
            print("SUCCESS: deleted the user")
            
            if curMember.role == "owner" {
                print("SUCCESS: Identified the owner")
                // Find other memberships for the group
                let otherMembershipsSnapshot = try await Firestore.app
                    .collection("membership")
                    .whereField("group_id", isEqualTo: groupId)
                    .order(by: "joined_at", descending: false)
                    .getDocuments()
                
                print("SUCCESS: found \(otherMembershipsSnapshot.documents.count) other members")
                
                if otherMembershipsSnapshot.documents.count == 0 {
                    // Remove group if there are no members
                    try await Firestore.app.collection("groups").document(groupId).delete()
                    print("SUCCESS: deleted the group")
                } else {
                    // Replace owner if there are remaining members
                    let oldestMember = otherMembershipsSnapshot.documents[0]
                    
                    try await oldestMember.reference.updateData([
                        "role": "owner",
                    ])
                    print("SUCCESS: made oldest member the owner")
                }
            }
            
            isSaving = false
            return true
        } catch {
            isSaving = false
            leaveErrorMessage = error.localizedDescription
            return false
        }
    }
    
    private enum GroupDetailsViewModelError: LocalizedError {
        case missingUser(String)
    
        var errorDescription: String? {
            switch self {
            case .missingUser(let userId):
                return "The user \(userId) could not be found."
            }
        }
    }
}
