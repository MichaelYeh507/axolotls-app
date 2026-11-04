import Foundation
import FirebaseFirestore

// Mirrors users/{userId} in the Sprint 3 Firestore design.
// Firestore fields are snake_case; Swift properties are camelCase via CodingKeys.
// NOTE: Person D owns the shared models. If D's versions land first, delete these and use theirs.

struct NotificationPreferences: Codable, Equatable, Sendable {
    var groupInviteNotificationsEnabled: Bool
    var photosAvailableNotificationsEnabled: Bool
    var questNotificationsEnabled: Bool

    static let `default` = NotificationPreferences(
        groupInviteNotificationsEnabled: true,
        photosAvailableNotificationsEnabled: true,
        questNotificationsEnabled: true
    )

    enum CodingKeys: String, CodingKey {
        case groupInviteNotificationsEnabled = "group_invite_notifications_enabled"
        case photosAvailableNotificationsEnabled = "photos_available_notifications_enabled"
        case questNotificationsEnabled = "quest_notifications_enabled"
    }
}

struct UserProfile: Codable, Identifiable, Equatable, Sendable {
    @DocumentID var id: String?          // Firebase Auth uid
    var username: String                 // lowercase, unique (see UsernameClaim)
    var displayName: String
    var createdAt: Date                  // created_at (Firestore Timestamp)
    var notificationPreferences: NotificationPreferences

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case createdAt = "created_at"
        case notificationPreferences = "notification_preferences"
    }
}

// Mirrors usernames/{username}. Existence of this doc = username is taken.
struct UsernameClaim: Codable, Sendable {
    var userId: String

    enum CodingKeys: String, CodingKey { case userId = "user_id" }
}
