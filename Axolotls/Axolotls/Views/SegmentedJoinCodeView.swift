//
//  Untitled.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/7/26.
//

import SwiftUI

struct SegmentedJoinCodeView: View {
    var joinCode: String
    @FocusState private var isFocused: Bool
    
    private let codeLength = 6
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<codeLength, id: \.self) { index in
                let digit = getDigit(at: index)
                
                Text(digit)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .frame(width: 45, height: 55)
                    .background(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused && index == joinCode.count ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                    .cornerRadius(8)
            }
        }
    }
    
    private func getDigit(at index: Int) -> String {
        guard index < joinCode.count else { return "" }
        let stringIndex = joinCode.index(joinCode.startIndex, offsetBy: index)
        return String(joinCode[stringIndex])
    }
}
