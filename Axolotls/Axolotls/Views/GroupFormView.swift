//
//  GroupFormView.swift
//  Axolotls
//
//  Created by Stephanie Reed on 11/5/26.
//
import SwiftUI

struct GroupFormView: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var revealAt: Date
    
    var body: some View {
        Form {
            Section("Group Name") {
                TextField("Name", text: $name)
            }
            
            Section("Description") {
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            Section("Details") {
                DatePicker(
                    "When will this event end?",
                    selection: $revealAt,
                    displayedComponents: [.date, .hourAndMinute])
                Text("[Image/Icon selection here]")
            }
        }
    }
}
