//
//  GroupGalleryView.swift
//  Axolotls
//
//  Created by Lily Beerhalter on 11/8/26.
//

import SwiftUI

struct GroupGalleryView: View {
    var refreshID: Int

    @State private var viewModel: GroupGalleryViewModel
    @State private var selectedPhoto: GroupPhoto?
    private let revealAt: Date

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    init(group: Group, refreshID: Int = 0) {
        self.refreshID = refreshID
        self.revealAt = group.revealAt
        _viewModel = State(initialValue: GroupGalleryViewModel(group: group))
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: refreshID) {
                await viewModel.load()
            }
            .task {
                await viewModel.waitForReveal()
            }
            .fullScreenCover(item: $selectedPhoto) { photo in
                GroupPhotoViewer(photo: photo, viewModel: viewModel)
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.photos.isEmpty {
            ProgressView("Loading photos...")
                .frame(maxWidth: .infinity)
        } else if viewModel.errorMessage != nil && viewModel.photos.isEmpty {
            Text("Unable to load photos")
        } else if viewModel.photos.isEmpty {
            Text(viewModel.isRevealed ? "No photos were taken in this group." : "Photos taken in this group will appear here.")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if !viewModel.isRevealed {
                    Label("Unlocks \(revealAt.formatted(date: .abbreviated, time: .shortened))",
                          systemImage: "lock.fill")
                        .font(.subheadline)
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(viewModel.photos) { photo in
                            cell(for: photo)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(for photo: GroupPhoto) -> some View {
        if viewModel.isRevealed {
            Button {
                selectedPhoto = photo
            } label: {
                thumbnail(for: photo)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View photo")
        } else {
            thumbnail(for: photo)
                .accessibilityLabel("Hidden photo")
        }
    }

    private func thumbnail(for photo: GroupPhoto) -> some View {
        Color.white.opacity(0.15)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let id = photo.id, let image = viewModel.thumbnails[id] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: viewModel.isRevealed ? 0 : 24, opaque: true)
                } else if let id = photo.id, viewModel.failedThumbnailIds.contains(id) {
                    Image(systemName: "photo")
                } else {
                    ProgressView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .task(id: photo.id) {
                await viewModel.loadThumbnail(for: photo)
            }
    }
}

//full screen view of one photo, opened by tapping it in the gallery
private struct GroupPhotoViewer: View {
    let photo: GroupPhoto
    let viewModel: GroupGalleryViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var fullImage: UIImage?
    @State private var didFinishLoading = false

    private var displayedImage: UIImage? {
        fullImage ?? photo.id.flatMap { viewModel.thumbnails[$0] }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = displayedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if didFinishLoading {
                Text("Unable to load this photo")
                    .foregroundStyle(.white)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.black, .white)
                    .padding()
            }
            .accessibilityLabel("Close")
        }
        .task {
            fullImage = await viewModel.fullImage(for: photo)
            didFinishLoading = true
        }
    }
}
