//
//  PhotosTheme.swift
//  Axolotls
//
//  Part C (Photos). Colors from the hi-fi Figma (same values as GroupDetailsView).
//  If the team adds a shared theme, swap these for it.
//

import SwiftUI

enum PhotosTheme {
    static let darkPurple = Color(red: 0.2196, green: 0.1568, blue: 0.3058)
    static let mediumPurple = Color(red: 0.4117, green: 0.2941, blue: 0.5764)
    static let coral = Color(red: 0.9921, green: 0.5882, blue: 0.5098)

    /// Coral glow at the top fading into purple, as behind the Figma Camera screen.
    static let cameraBackground = LinearGradient(
        colors: [coral, mediumPurple, darkPurple],
        startPoint: .top,
        endPoint: .bottom
    )
}
