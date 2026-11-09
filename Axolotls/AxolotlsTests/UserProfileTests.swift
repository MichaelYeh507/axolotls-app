import XCTest
import FirebaseFirestore
@testable import Axolotls

/// Checks the Firestore field names match the Sprint 3 data design (snake_case).
final class UserProfileTests: XCTestCase {
    func testNotificationPreferencesUseSnakeCaseKeys() throws {
        let data = try Firestore.Encoder().encode(NotificationPreferences.default)
        XCTAssertEqual(Set(data.keys), [
            "group_invite_notifications_enabled",
            "photos_available_notifications_enabled",
            "quest_notifications_enabled"
        ])
        XCTAssertEqual(data["quest_notifications_enabled"] as? Bool, true)
    }

    func testNotificationPreferencesRoundTrip() throws {
        let prefs = NotificationPreferences(groupInviteNotificationsEnabled: false,
                                            photosAvailableNotificationsEnabled: true,
                                            questNotificationsEnabled: false)
        let json = try JSONEncoder().encode(prefs)
        XCTAssertEqual(try JSONDecoder().decode(NotificationPreferences.self, from: json), prefs)
    }

    func testDefaultPreferencesAreAllOn() {
        let p = NotificationPreferences.default
        XCTAssertTrue(p.groupInviteNotificationsEnabled)
        XCTAssertTrue(p.photosAvailableNotificationsEnabled)
        XCTAssertTrue(p.questNotificationsEnabled)
    }

    func testUserProfileEncodesExpectedFields() throws {
        let data = try Firestore.Encoder().encode(UserProfile.testFixture())
        XCTAssertEqual(data["username"] as? String, "anabella")
        XCTAssertEqual(data["display_name"] as? String, "Anabella")
        XCTAssertTrue(data["created_at"] is Timestamp)
        XCTAssertNotNil(data["notification_preferences"] as? [String: Any])
        XCTAssertNil(data["id"], "the document ID must not be stored as a field")
        XCTAssertNil(data["displayName"], "camelCase keys must not leak into Firestore")
    }

    func testUsernameClaimEncodesUserId() throws {
        let data = try Firestore.Encoder().encode(UsernameClaim(userId: "u1"))
        XCTAssertEqual(data["user_id"] as? String, "u1")
    }
}

private extension UserProfile {
    static func testFixture() -> UserProfile {
        UserProfile(id: "u1", username: "anabella", displayName: "Anabella",
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                    notificationPreferences: .default)
    }
}
