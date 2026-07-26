import Foundation
import SwiftUI
import UIKit

/// One photo in the full-screen viewer.
///
/// `data` is the copy stored on the item — always present, renders instantly,
/// and works offline. `highResolutionURL` is an optional sharper source for the
/// same image (a movie's TMDB poster, whose stored copy is downsized for the
/// board). The viewer fades it in when it loads and falls back to `data` in
/// every failure case.
struct BoardPhoto {
    let data: Data
    let highResolutionURL: URL?

    init(data: Data, highResolutionURL: URL? = nil) {
        self.data = data
        self.highResolutionURL = highResolutionURL
    }
}

/// Full-screen, swipeable photo presentation for a board item. Recipes supply
/// all of their photos; other item types supply their single shared photo.
struct BoardPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let photos: [BoardPhoto]

    @State private var selectedIndex = 0
    @State private var isCurrentPhotoZoomed = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                    ZoomablePhotoPage(
                        photo: photo,
                        isSelected: selectedIndex == index,
                        onZoomStateChanged: { isZoomed in
                            guard selectedIndex == index else { return }
                            isCurrentPhotoZoomed = isZoomed
                        }
                    )
                    .tag(index)
                    .accessibilityLabel(photoAccessibilityLabel(for: index))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .scrollDisabled(isCurrentPhotoZoomed)
            .ignoresSafeArea()

            viewerControls
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onChange(of: selectedIndex) { _, _ in
            isCurrentPhotoZoomed = false
        }
    }

    private var viewerControls: some View {
        VStack {
            HStack(spacing: DocketTheme.PhotoViewer.controlSpacing) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(
                            width: DocketTheme.PhotoViewer.closeButtonSize,
                            height: DocketTheme.PhotoViewer.closeButtonSize
                        )
                        .background(.black.opacity(0.64), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
                }
                .accessibilityLabel("Close photo viewer")
            }
            .padding(.horizontal, DocketTheme.PhotoViewer.horizontalPadding)
            .padding(.top, DocketTheme.PhotoViewer.topPadding)

            Spacer()

            if photos.count > 1 {
                HStack(spacing: DocketTheme.PhotoViewer.pageIndicatorSpacing) {
                    ForEach(photos.indices, id: \.self) { index in
                        Capsule()
                            .fill(
                                index == selectedIndex
                                    ? DocketTheme.brass : Color.white.opacity(0.42)
                            )
                            .frame(
                                width: index == selectedIndex
                                    ? DocketTheme.PhotoViewer.selectedPageIndicatorWidth
                                    : DocketTheme.PhotoViewer.pageIndicatorSize,
                                height: DocketTheme.PhotoViewer.pageIndicatorSize
                            )
                    }
                }
                .padding(DocketTheme.PhotoViewer.pageIndicatorPadding)
                .background(.black.opacity(0.56), in: Capsule())
                .padding(.bottom, DocketTheme.PhotoViewer.bottomPadding)
                .animation(
                    DocketTheme.PhotoViewer.pageIndicatorAnimation,
                    value: selectedIndex
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Photo \(selectedIndex + 1) of \(photos.count)")
            }
        }
    }

    private func photoAccessibilityLabel(for index: Int) -> String {
        photos.count == 1
            ? "\(title) photo"
            : "\(title), photo \(index + 1) of \(photos.count)"
    }
}

private struct ZoomablePhotoPage: View {
    let photo: BoardPhoto
    let isSelected: Bool
    let onZoomStateChanged: (Bool) -> Void

    @State private var scale: CGFloat = 1
    @State private var settledScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero
    @State private var highResolutionImage: UIImage?

    var body: some View {
        GeometryReader { geometry in
            photoLayers
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(scale)
                .offset(offset)
                .contentShape(Rectangle())
                .gesture(magnifyGesture(in: geometry.size))
                .simultaneousGesture(
                    dragGesture(in: geometry.size),
                    including: scale > DocketTheme.PhotoViewer.zoomedThreshold
                        ? .gesture : .none
                )
                .onTapGesture(count: 2) {
                    toggleDoubleTapZoom(in: geometry.size)
                }
        }
        .task(id: isSelected) {
            await loadHighResolutionImage()
        }
        .onChange(of: isSelected) { _, selected in
            guard !selected else { return }
            resetZoom()
            // A decoded full-resolution poster costs tens of megabytes. Only the
            // page on screen keeps one.
            highResolutionImage = nil
        }
    }

    /// The stored photo always renders underneath, so the sharper source fades
    /// in over a complete image instead of replacing a placeholder. Both use the
    /// same aspect ratio and `.fit`, making this a crossfade with no reflow.
    private var photoLayers: some View {
        ZStack {
            ItemPhotoImage(data: photo.data, contentMode: .fit)

            if let highResolutionImage {
                Image(uiImage: highResolutionImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .transition(.opacity)
            }
        }
    }

    private func loadHighResolutionImage() async {
        guard isSelected,
            highResolutionImage == nil,
            let url = photo.highResolutionURL
        else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = DocketTheme.PhotoViewer.highResolutionTimeout
        // Reuse the shared cache so reopening a poster is free, and let Low Data
        // Mode keep the stored photo rather than pulling a multi-megabyte image.
        request.cachePolicy = .returnCacheDataElseLoad
        request.allowsConstrainedNetworkAccess = false

        guard let (data, response) = try? await URLSession.shared.data(for: request),
            let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode),
            let image = UIImage(data: data),
            // Decode off the main thread; decoding a full-resolution poster
            // mid-pinch would hitch the gesture.
            let prepared = await image.byPreparingForDisplay(),
            !Task.isCancelled
        else { return }

        withAnimation(DocketTheme.PhotoViewer.highResolutionFadeAnimation) {
            highResolutionImage = prepared
        }
    }

    private func magnifyGesture(in containerSize: CGSize) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                scale = min(
                    max(
                        settledScale * value.magnification,
                        DocketTheme.PhotoViewer.minimumZoomScale
                    ),
                    DocketTheme.PhotoViewer.maximumZoomScale
                )
                offset = clamped(offset, at: scale, in: containerSize)
                onZoomStateChanged(scale > DocketTheme.PhotoViewer.zoomedThreshold)
            }
            .onEnded { _ in
                if scale <= DocketTheme.PhotoViewer.zoomedThreshold {
                    resetZoom()
                } else {
                    settledScale = scale
                    offset = clamped(offset, at: scale, in: containerSize)
                    settledOffset = offset
                    onZoomStateChanged(true)
                }
            }
    }

    private func dragGesture(in containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard scale > DocketTheme.PhotoViewer.zoomedThreshold else { return }
                offset = clamped(
                    CGSize(
                        width: settledOffset.width + value.translation.width,
                        height: settledOffset.height + value.translation.height
                    ),
                    at: scale,
                    in: containerSize
                )
            }
            .onEnded { _ in
                guard scale > DocketTheme.PhotoViewer.zoomedThreshold else { return }
                offset = clamped(offset, at: scale, in: containerSize)
                settledOffset = offset
            }
    }

    private func toggleDoubleTapZoom(in containerSize: CGSize) {
        if scale > DocketTheme.PhotoViewer.zoomedThreshold {
            resetZoom()
        } else {
            withAnimation(DocketTheme.PhotoViewer.zoomResetAnimation) {
                scale = DocketTheme.PhotoViewer.doubleTapZoomScale
                settledScale = scale
                offset = clamped(offset, at: scale, in: containerSize)
                settledOffset = offset
            }
            onZoomStateChanged(true)
        }
    }

    private func resetZoom() {
        withAnimation(DocketTheme.PhotoViewer.zoomResetAnimation) {
            scale = 1
            settledScale = 1
            offset = .zero
            settledOffset = .zero
        }
        onZoomStateChanged(false)
    }

    private func clamped(
        _ candidate: CGSize,
        at scale: CGFloat,
        in containerSize: CGSize
    ) -> CGSize {
        let horizontalLimit = containerSize.width * (scale - 1) / 2
        let verticalLimit = containerSize.height * (scale - 1) / 2
        return CGSize(
            width: min(max(candidate.width, -horizontalLimit), horizontalLimit),
            height: min(max(candidate.height, -verticalLimit), verticalLimit)
        )
    }
}
