//
//  Membership.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/5/26.
//

import Foundation
import FirebaseFirestore

struct Membership: Codable {
    
    var userId: String
    var groupId: String
    var role: String?
    var membershipStatus: String?
    var joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case groupId = "group_id"
        case role
        case membershipStatus = "membership_status"
        case joinedAt = "joined_at"
    }
}
