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
        let darkPurple = Color(red: 0.2196, green: 0.1568, blue: 0.3058)
        let mediumPurple = Color(red: 0.4117, green: 0.2941, blue: 0.5764)
        let coral = Color(red: 0.9921, green: 0.5882, blue: 0.5098)
        
        ZStack {
            LinearGradient(
              gradient: Gradient(colors: [darkPurple, mediumPurple]),
              startPoint: .trailing,
              endPoint: .bottomLeading
            ).ignoresSafeArea()

            VStack {
                Text("Join Group").font(.largeTitle).bold()
                Form {
                    Section("Enter the 6-digit code to join a group") {
                        JoinCodeFormView(joinCode: $joinCode)
                    }
                }
                .frame(height: 150)
                .scrollContentBackground(.hidden)
                
                Button("Join Group") {
                    Task {
                        if await viewModel.joinGroup(joinCode: joinCode, userId: session.userID) { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle)
                .controlSize(.large)
                .disabled(!isCodeComplete)
                .foregroundStyle(.black)
                .tint(coral)
            }
            .foregroundStyle(.white)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .center
            )
        }
    }
}
