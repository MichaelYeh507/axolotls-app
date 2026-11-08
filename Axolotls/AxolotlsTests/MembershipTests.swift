//
//  MembershipTests.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/8/26.
//

import Foundation
import Testing
@testable import Axolotls

@MainActor
struct MembershipTests {
    @Test func membershipStoresOptionalFields() {
        let joinedAt = Date(timeIntervalSince1970: 3_000)

        let membership = Membership(
            userId: "user-1",
            groupId: "group-1",
            role: "member",
            membershipStatus: "pending",
            joinedAt: joinedAt
        )

        #expect(membership.userId == "user-1")
        #expect(membership.groupId == "group-1")
        #expect(membership.role == "member")
        #expect(membership.membershipStatus == "pending")
        #expect(membership.joinedAt == joinedAt)
    }

    @Test func membershipAllowsMissingOptionalFields() {
        let membership = Membership(
            userId: "user-1",
            groupId: "group-1",
            role: nil,
            membershipStatus: nil,
            joinedAt: nil
        )

        #expect(membership.role == nil)
        #expect(membership.membershipStatus == nil)
        #expect(membership.joinedAt == nil)
    }
    
    @Test func joinGroupRequiresSignedInUser() async {
        let viewModel = JoinGroupViewModel()

        let didJoin = await viewModel.joinGroup(joinCode: "ABC234", userId: nil)

        #expect(didJoin == false)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.errorMessage == "You must be signed in to join a group.")
    }
    
    @Test func inviteFriendsRequiresGroup() async {
        let viewModel = GroupInviteModalViewModel()

        let didInvite = await viewModel.inviteFriends(groupId: nil)

        #expect(didInvite == false)
        #expect(viewModel.isSaving == false)
        #expect(viewModel.inviteErrorMessage == "You must select a group to view it's details")
    }
}
