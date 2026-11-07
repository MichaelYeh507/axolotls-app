//
//  GroupView.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/5/26.
//

import SwiftUI

struct GroupDetailsView: View {
    var group: Group
    
    var body: some View {
        let darkPurple = Color(red: 0.2196, green: 0.1568, blue: 0.3058)
        let mediumPurple = Color(red: 0.4117, green: 0.2941, blue: 0.5764)
        let coral = Color(red: 0.9921, green: 0.5882, blue: 0.5098)
        
        ZStack {
            LinearGradient(
              gradient: Gradient(colors: [darkPurple, mediumPurple]),
              startPoint: .trailing,
              endPoint: .bottomLeading)

            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text(group.name)
                        .font(.largeTitle)
                    Text(group.description)
                        .multilineTextAlignment(.leading)

                    Button("Invite People") {} // TODO (Part B): Invites
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(.black)
                        .tint(coral)

                    GroupCameraButton(group: group) // Part C: photos taken here go to this group

                    Text("Members")
                        .font(.largeTitle)
                    Text("[member info here]")

                    Text("Photos")
                        .font(.largeTitle)
                    Text("[photos here]")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        EditGroupView(group: group)
                    } label: {
                        Image(systemName: "ellipsis")
                    }.foregroundStyle(.black)
                }
            }
            .foregroundStyle(.white)
        }
    }
}
