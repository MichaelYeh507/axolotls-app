//
//  JoinGroupView.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/7/26.
//

import SwiftUI

struct JoinGroupView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = JoinGroupViewModel()
    
    @State private var joinCode = ""
    
    var isCodeComplete: Bool {
        joinCode.count == 6
    }
    
    var body: some View {
        let coral = Color(red: 0.9921, green: 0.5882, blue: 0.5098)
        
        Text("Join Group").font(.largeTitle)
        Form {
            Section("Enter the 6-digit code to join a group") {
                JoinCodeFormView(joinCode: $joinCode)
            }
        }
        
        Button("Join Group") {
            Task {
                if await viewModel.joinGroup(joinCode: joinCode, userId: session.userID) { dismiss() }
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isCodeComplete)
        .foregroundStyle(.black)
        .tint(coral)
    }
}
