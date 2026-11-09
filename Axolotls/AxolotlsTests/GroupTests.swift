//
//  GroupTests.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/8/26.
//

import Foundation
import Testing
@testable import Axolotls

@MainActor
struct GroupTests {

    @Test func groupStoresItsFields() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let revealAt = Date(timeIntervalSince1970: 2_000)

        let group = Group(
            id: "group-1",
            name: "Axolotls",
            description: "A test group",
            mode: "party",
            createdAt: createdAt,
            revealAt: revealAt,
            joinCode: "ABC234"
        )

        #expect(group.id == "group-1")
        #expect(group.name == "Axolotls")
        #expect(group.description == "A test group")
        #expect(group.mode == "party")
        #expect(group.createdAt == createdAt)
        #expect(group.revealAt == revealAt)
        #expect(group.joinCode == "ABC234")
    }

    @Test func newGroupValidationRequiresNonWhitespaceName() {
        let viewModel = NewGroupViewModel()

        #expect(viewModel.isValid == false)

        viewModel.name = "   "
        #expect(viewModel.isValid == false)

        viewModel.name = "  Axolotls  "
        #expect(viewModel.isValid)
    }

    @Test func editGroupValidationRequiresNonWhitespaceName() {
        let viewModel = EditGroupViewModel(group: makeGroup())

        viewModel.name = "   "
        #expect(viewModel.isValid == false)

        viewModel.name = "  Updated group  "
        #expect(viewModel.isValid)
    }

    @Test func generatedJoinCodeUsesRequestedLengthAndAllowedCharacters() {
        let viewModel = NewGroupViewModel()
        let allowedCharacters = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

        let code = viewModel.generateJoinCode(length: 32)

        #expect(code.count == 32)
        #expect(code.allSatisfy { allowedCharacters.contains($0) })
    }

    @Test func loadGroupsWithoutUserClearsState() async {
        let viewModel = GroupsViewModel()
        viewModel.groups = [makeGroup()]
        viewModel.isLoading = true
        viewModel.errorMessage = "previous error"

        await viewModel.loadGroups(for: nil)

        #expect(viewModel.groups.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func loadMembersRequiresSignedInUser() async {
        let viewModel = GroupDetailsViewModel()

        await viewModel.loadMembers(groupId: "group-1", curUserId: nil)

        #expect(viewModel.members.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == "You must be signed in to view group details")
    }

    @Test func asyncMapPreservesOrder() async throws {
        let values = try await [1, 2, 3].asyncMap { value in
            value * 2
        }

        #expect(values == [2, 4, 6])
    }

    private func makeGroup() -> Group {
        Group(
            id: "group-1",
            name: "Axolotls",
            description: "A test group",
            mode: "party",
            createdAt: Date(timeIntervalSince1970: 1_000),
            revealAt: Date(timeIntervalSince1970: 2_000),
            joinCode: "ABC234"
        )
    }

}
