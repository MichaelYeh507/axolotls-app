//
//  Group.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/5/26.
//

import Foundation
import Observation
import FirebaseFirestore

struct Group: Codable, Identifiable {
    
    // MARK: Fields
    @DocumentID var id: String? // Firebase ID
    var name: String
    var description: String
    var mode: String
    var createdAt: Date
    var revealAt: Date
    var joinCode: String
    
    // MARK: Codable
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case mode
        case createdAt = "created_at"
        case revealAt = "reveal_at"
        case joinCode = "join_code"
    }
}
