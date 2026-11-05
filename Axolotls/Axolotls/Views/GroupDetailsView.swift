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
        Text(group.name).font(Font.largeTitle)
        Text(group.description)
        
        TabView {
            EditGroupView(group: group)
            .tabItem {
                Image(systemName: "pencil")
                Text("Edit Group")
            }
        }
    }
}
