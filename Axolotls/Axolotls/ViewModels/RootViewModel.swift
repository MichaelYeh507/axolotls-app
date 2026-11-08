//
//  RootViewModel.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/7/26.
//
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class RootViewModel {
    var pending: [Group] = []
    var isLoading = false
    var errorMessage: String?
    
    func loadPending(for userId: String?) async {
        guard let userId else {
            pending = []
            isLoading = false
            errorMessage = nil
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Find memberships with this user
            let membershipSnapshot = try await Firestore.app
                .collection("membership")
                .whereField("user_id", isEqualTo: userId)
                .getDocuments()

            let memberships = try membershipSnapshot.documents.map {
                try $0.data(as: Membership.self)
            }

            let pendingGroupIds = Array(Set(memberships
                .filter { $0.membershipStatus == "pending" }
                .map(\.groupId)))
            
            // Find groups matching these memberships
            pending = try await pendingGroupIds.asyncMap { groupId in
                let snapshot = try await Firestore.app
                    .collection("groups")
                    .document(groupId)
                    .getDocument()

                guard snapshot.exists else {
                    throw RootViewModelError.missingGroup(groupId)
                }

                return try snapshot.data(as: Group.self)
            }
            
            isLoading = false
        } catch {
            pending = []
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private enum RootViewModelError: LocalizedError {
        case missingGroup(String)
    
        var errorDescription: String? {
            switch self {
            case .missingGroup(let groupId):
                return "The group \(groupId) could not be found."
            }
        }
    }
}
