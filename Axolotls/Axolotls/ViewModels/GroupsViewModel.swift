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
    
    func loadGroups(for userID: String?) async {
        guard let userID else {
            groups = []
            isLoading = false
            errorMessage = nil
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let decoder = Firestore.Decoder()
            let userReference = Firestore.app
                .collection("users")
                .document(userID)

            let membershipSnapshot = try await Firestore.app
                .collectionGroup("members")
                .whereField("user_id", isEqualTo: userReference)
                .getDocuments()
            
            let memberships = try membershipSnapshot.documents.map {
                try decoder.decode(Membership.self, from: $0.data())
            }
            let activeGroupIds = Array(Set(memberships
                .filter { $0.membershipStatus == "active" }
                .map(\.groupId)))
            
            groups = try await activeGroupIds.asyncMap { groupId in
                let snapshot = try await Firestore.app
                    .collection("groups")
                    .document(groupId)
                    .getDocument()
                
                guard let data = snapshot.data() else {
                    throw GroupsViewModelError.missingGroup(groupId)
                }
                
                return try decoder.decode(Group.self, from: data)
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
            case .missingGroup(let groupID):
                return "The group \(groupID) could not be found."
            }
        }
    }
}

private extension Array {
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
