//
//  Friend.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/7/26.
//

import Foundation
import Observation
import FirebaseFirestore

struct Friend: Codable, Identifiable {
    
    // MARK: Fields
    @DocumentID var id: String? // Firebase ID
    var userId1: String
    var userId2: String
    
    // MARK: Codable
    enum CodingKeys: String, CodingKey {
        case id
        case userId1 = "user_id1"
        case userId2 = "user_id2"
    }
}
