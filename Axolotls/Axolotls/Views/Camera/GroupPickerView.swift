//
//  GroupPickerView.swift
//  Axolotls
//
//  Part C (Photos). "Where should this photo go?" Shown by the Home capture
//  button when you're in more than one active group.
//

import SwiftUI

struct GroupPickerView: View {
    let groups: [Group]
    let onPick: (Group) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(groups) { group in
                Button {
                    onPick(group)
                } label: {
                    HStack(spacing: 12) {
                        Text(initials(of: group.name))
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(width: 40, height: 40)
                            .background(PhotosTheme.coral, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Reveals \(group.revealAt.formatted(.relative(presentation: .named)))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "camera.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Send photo to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func initials(of name: String) -> String {
        String(name.first(where: \.isLetter) ?? "•").uppercased()
    }
}
