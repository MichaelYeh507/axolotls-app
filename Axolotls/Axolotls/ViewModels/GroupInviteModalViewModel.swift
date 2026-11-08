//
//  GroupInviteModalView.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/7/26.
//

import Observation
import FirebaseFirestore

@MainActor
@Observable
final class GroupInviteModalViewModel {
    var friends: [(UserProfile, Bool)] = []
    
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var inviteErrorMessage: String?
    
    func loadFriends(curUserId: String?, members: [UserProfile]) async {
        guard let curUserId else {
            friends = []
            isLoading = false
            errorMessage = "You must be signed in to view friends"
            return
        }
        
        let memberIds = members.map { $0.id }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let friendsSnapshot = try await Firestore.app
                .collection("friends")
                .whereFilter(Filter.orFilter([
                    Filter.whereField("user_id1", isEqualTo: curUserId),
                    Filter.whereField("user_id2", isEqualTo: curUserId)
                ]))
                .getDocuments()
            
            let friendsData = try friendsSnapshot.documents.map {
                try $0.data(as: Friend.self)
            }
            
            let friendUserIds = Array(Set(friendsData
                .filter { (!memberIds.contains($0.userId1)) && (!memberIds.contains($0.userId2))}
                .map{
                    if $0.userId1 == curUserId {
                        $0.userId2
                    } else {
                        $0.userId1
                    }
                }))
            
            friends = try await friendUserIds.asyncMap { userId in
                let snapshot = try await Firestore.app
                    .collection("users")
                    .document(userId)
                    .getDocument()

                guard snapshot.exists else {
                    throw GroupInviteModalViewModelError.missingUser(userId)
                }

                return (try snapshot.data(as: UserProfile.self), false)
            }
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            return
        }
    }
    
    func inviteFriends(groupId: String?) async -> Bool {
        guard let groupId else {
            isLoading = false
            inviteErrorMessage = "You must select a group to view it's details"
            return false
        }
        
        isSaving = true
        inviteErrorMessage = nil
        
        let selectedFriends = friends.filter{ $0.1 }.map{ $0.0 }
        
        do {
            for friend in selectedFriends {
                guard let friendId = friend.id else {
                    isLoading = false
                    inviteErrorMessage = "You must select a friend to invite them"
                    return false
                }
                
                let membership = Membership(
                    userId: friendId,
                    groupId: groupId,
                    role: "member",
                    membershipStatus: "pending",
                    joinedAt: nil,
                )
                
                try Firestore.app
                    .collection("membership")
                    .addDocument(from: membership)
                
                isSaving = false
            }
            return true
        } catch {
            isSaving = false
            inviteErrorMessage = error.localizedDescription
            return false
        }
    }
    
    private enum GroupInviteModalViewModelError: LocalizedError {
        case missingUser(String)
    
        var errorDescription: String? {
            switch self {
            case .missingUser(let userId):
                return "The user \(userId) could not be found."
            }
        }
    }
}
