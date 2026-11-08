//
//  GroupsViewModel.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/5/26.
//
import Observation
import FirebaseFirestore

@MainActor
@Observable
final class GroupsViewModel {
    var groups: [Group] = []
    var isLoading = false
    var errorMessage: String?
    
    func loadGroups(for userId: String?) async {
        guard let userId else {
            groups = []
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

            let activeGroupIds = Array(Set(memberships
                .filter { $0.membershipStatus == "active" }
                .map(\.groupId)))
            
            // Find groups matching these memberships
            groups = try await activeGroupIds.asyncMap { groupId in
                let snapshot = try await Firestore.app
                    .collection("groups")
                    .document(groupId)
                    .getDocument()

                guard snapshot.exists else {
                    throw GroupsViewModelError.missingGroup(groupId)
                }

                return try snapshot.data(as: Group.self)
            }
            isLoading = false
        } catch {
            groups = []
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
    
    private enum GroupsViewModelError: LocalizedError {
        case missingGroup(String)
    
        var errorDescription: String? {
            switch self {
            case .missingGroup(let groupId):
                return "The group \(groupId) could not be found."
            }
        }
    }
    
}

extension Array {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async throws -> [T] {
        var result: [T] = []
        result.reserveCapacity(count)
        
        for element in self {
            result.append(try await transform(element))
        }
        
        return result
    }
}
