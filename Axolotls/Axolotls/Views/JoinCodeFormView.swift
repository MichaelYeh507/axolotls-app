//
//  SegmentedJoinCodeView.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/7/26.
//

import SwiftUI

struct JoinCodeFormView: View {
    @Binding var joinCode: String
    @FocusState private var isFocused: Bool
    
    private let codeLength = 6
    
    var body: some View {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Excluded easily confused characters like O, 0, I, 1
        
        ZStack {
            TextField("", text: $joinCode)
            .focused($isFocused)
            .accentColor(.clear)
            .foregroundColor(.clear)
            .onChange(of: joinCode) { _, newValue in
                let filtered = newValue
                        .uppercased()
                        .filter { letters.contains($0) }
                if filtered.count > codeLength {
                    joinCode = String(filtered.prefix(codeLength))
                } else if filtered != newValue {
                    joinCode = filtered
                }
            }
            
            SegmentedJoinCodeView(joinCode: joinCode)
        }.onTapGesture { isFocused = true }
    }
}
