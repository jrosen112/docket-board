import PhotosUI
import SwiftUI
import UIKit

/// Shared image renderer for item photos. The board supplies a fixed frame and
/// `.fill`; detail screens use `.fit` so the full image remains available.
struct ItemPhotoImage: View {
    let data: Data
    let contentMode: ContentMode

    var body: some View {
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        }
    }
}

/// Renders the portion of a photo selected for the board card.
struct BoardCroppedPhoto: View {
    let data: Data
    let position: BoardPhotoPosition

    var body: some View {
        GeometryReader { geometry in
            if let image = UIImage(data: data) {
                let layout = BoardPhotoLayout(
                    imageSize: image.size,
                    containerSize: geometry.size
                )

                Image(uiImage: image)
                    .resizable()
                    .frame(width: layout.imageSize.width, height: layout.imageSize.height)
                    .position(
                        x: layout.imageSize.width / 2
                            - CGFloat(position.x) * layout.horizontalOverflow,
                        y: layout.imageSize.height / 2
                            - CGFloat(position.y) * layout.verticalOverflow
                    )
            }
        }
        .clipped()
    }
}

/// Keeps the background and rounded corners attached to the fitted image,
/// rather than to the larger detail-page container around it.
struct RoundedItemPhoto: View {
    let data: Data
    let maximumHeight: CGFloat

    var body: some View {
        ItemPhotoImage(data: data, contentMode: .fit)
            .frame(maxHeight: maximumHeight)
            .background(
                DocketTheme.ink.opacity(0.08),
                in: RoundedRectangle(
                    cornerRadius: DocketDetailTheme.Photo.cornerRadius,
                    style: .continuous
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DocketDetailTheme.Photo.cornerRadius,
                    style: .continuous
                )
            )
    }
}

/// Read-only detail presentation that mirrors the saved board crop without
/// growing taller than the rest of the hero content.
struct CroppedDetailPhoto: View {
    let data: Data
    let position: BoardPhotoPosition
    let aspectRatio: CGFloat

    var body: some View {
        FittedPhotoLayout(
            aspectRatio: aspectRatio,
            maximumHeight: DocketDetailTheme.Photo.detailMaximumHeight
        ) {
            BoardCroppedPhoto(data: data, position: position)
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: DocketDetailTheme.Photo.cornerRadius,
                style: .continuous
            )
        )
        .frame(maxWidth: .infinity)
    }
}

/// Photo picker used by both the add flow and the typed detail editors.
struct ItemPhotoEditor: View {
    @Binding var photoData: Data?
    @Binding var showsPhotoOnBoard: Bool
    @Binding var showsMapOnBoard: Bool
    @Binding var boardPhotoPosition: BoardPhotoPosition

    let accent: Color
    let boardCropAspectRatio: CGFloat

    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isCroppingForBoard = false

    var body: some View {
        VStack(spacing: DocketDetailTheme.Photo.controlSpacing) {
            if let photoData {
                photoPreview(photoData)
                controls
            } else {
                addPhotoButton
            }

            if isLoading {
                ProgressView("Preparing photo…")
                    .font(DocketDetailTheme.Photo.supportingFont)
                    .tint(accent)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(DocketDetailTheme.Photo.supportingFont)
                    .foregroundStyle(DocketDetailTheme.Edit.errorColor)
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            guard let newValue else { return }
            Task { await load(newValue) }
        }
        .sheet(isPresented: $isCroppingForBoard) {
            if let photoData {
                BoardPhotoCropEditor(
                    data: photoData,
                    position: $boardPhotoPosition,
                    aspectRatio: boardCropAspectRatio,
                    accent: accent
                )
            }
        }
    }

    private func photoPreview(_ data: Data) -> some View {
        RoundedItemPhoto(
            data: data,
            maximumHeight: DocketDetailTheme.Photo.editorMaximumHeight
        )
            .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        HStack(spacing: DocketDetailTheme.Photo.controlSpacing) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                preferredItemEncoding: .automatic
            ) {
                Label("Change", systemImage: "photo.badge.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DocketPhotoButtonStyle(tint: accent))

            Button {
                isCroppingForBoard = true
            } label: {
                Label("Board crop", systemImage: "crop")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DocketPhotoButtonStyle(tint: accent))

            Button(role: .destructive) {
                withAnimation(DocketDetailTheme.Edit.modeAnimation) {
                    photoData = nil
                    showsPhotoOnBoard = false
                    boardPhotoPosition = .center
                    errorMessage = nil
                }
            } label: {
                Image(systemName: "trash")
                    .frame(
                        width: DocketDetailTheme.Photo.removeButtonSize,
                        height: DocketDetailTheme.Photo.removeButtonSize
                    )
            }
            .buttonStyle(DocketPhotoButtonStyle(tint: DocketDetailTheme.Edit.errorColor))
            .accessibilityLabel("Remove photo")
        }
        .font(DocketDetailTheme.Photo.buttonFont)
    }

    private var addPhotoButton: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            preferredItemEncoding: .automatic
        ) {
            VStack(spacing: DocketDetailTheme.Photo.emptySpacing) {
                Image(systemName: "photo.badge.plus")
                    .font(DocketDetailTheme.Photo.emptySymbolFont)
                    .foregroundStyle(accent)
                    .brightness(0.18)

                Text("Tap to add photo")
                    .font(DocketDetailTheme.Photo.emptyTitleFont)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: DocketDetailTheme.Photo.emptyHeight)
            .background(DocketTheme.inkLight.opacity(0.96))
            .overlay {
                RoundedRectangle(
                    cornerRadius: DocketDetailTheme.Photo.cornerRadius,
                    style: .continuous
                )
                .stroke(
                    accent.opacity(0.9),
                    style: StrokeStyle(
                        lineWidth: DocketDetailTheme.Photo.borderWidth,
                        dash: DocketDetailTheme.Photo.borderDash
                    )
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func load(_ item: PhotosPickerItem) async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            selectedItem = nil
        }

        do {
            guard let sourceData = try await item.loadTransferable(type: Data.self),
                let preparedData = ItemPhotoProcessor.preparedData(from: sourceData)
            else {
                errorMessage = "That photo couldn't be read. Please choose another one."
                return
            }

            let isFirstPhoto = photoData == nil
            withAnimation(DocketDetailTheme.Edit.modeAnimation) {
                photoData = preparedData
                boardPhotoPosition = .center
                if isFirstPhoto {
                    showsPhotoOnBoard = true
                    showsMapOnBoard = false
                }
            }
        } catch {
            errorMessage = "That photo couldn't be loaded. Please try again."
        }
    }
}

/// Recipe-specific gallery editor. The first image is the board-card cover;
/// the remaining images are available in the detail carousel.
struct RecipePhotoCarouselEditor: View {
    @Binding var photoData: Data?
    @Binding var additionalPhotoData: [Data]
    @Binding var showsPhotoOnBoard: Bool
    @Binding var showsMapOnBoard: Bool
    @Binding var boardPhotoPosition: BoardPhotoPosition

    let accent: Color
    let boardCropAspectRatio: CGFloat

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isCroppingForBoard = false

    private var photos: [Data] {
        ([photoData].compactMap(\.self) + additionalPhotoData)
            .prefix(Recipe.maximumPhotoCount)
            .map { $0 }
    }

    private var remainingCapacity: Int {
        max(0, Recipe.maximumPhotoCount - photos.count)
    }

    var body: some View {
        VStack(spacing: DocketDetailTheme.Photo.controlSpacing) {
            if photos.isEmpty {
                addPhotosButton(label: "Tap to add photos", isEmptyState: true)
            } else {
                TabView {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, data in
                        RoundedItemPhoto(
                            data: data,
                            maximumHeight: DocketDetailTheme.Photo.editorMaximumHeight
                        )
                            .overlay(alignment: .topTrailing) {
                                Button(role: .destructive) {
                                    removePhoto(at: index)
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 34, height: 34)
                                        .background(.black.opacity(0.62), in: Circle())
                                }
                                .padding(10)
                                .accessibilityLabel("Remove photo \(index + 1)")
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
                .frame(height: DocketDetailTheme.Photo.editorMaximumHeight)

                HStack(spacing: DocketDetailTheme.Photo.controlSpacing) {
                    if remainingCapacity > 0 {
                        addPhotosButton(label: "Add photos", isEmptyState: false)
                    }

                    Button {
                        isCroppingForBoard = true
                    } label: {
                        Label("Board crop", systemImage: "crop")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DocketPhotoButtonStyle(tint: accent))

                    Text("\(photos.count) of \(Recipe.maximumPhotoCount)")
                        .font(DocketDetailTheme.Photo.supportingFont)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            if isLoading {
                ProgressView("Preparing photos…")
                    .font(DocketDetailTheme.Photo.supportingFont)
                    .tint(accent)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(DocketDetailTheme.Photo.supportingFont)
                    .foregroundStyle(DocketDetailTheme.Edit.errorColor)
            }
        }
        .onChange(of: selectedItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
        .sheet(isPresented: $isCroppingForBoard) {
            if let photoData {
                BoardPhotoCropEditor(
                    data: photoData,
                    position: $boardPhotoPosition,
                    aspectRatio: boardCropAspectRatio,
                    accent: accent
                )
            }
        }
    }

    private func addPhotosButton(label: String, isEmptyState: Bool) -> some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: max(1, remainingCapacity),
            matching: .images,
            preferredItemEncoding: .automatic
        ) {
            if isEmptyState {
                VStack(spacing: DocketDetailTheme.Photo.emptySpacing) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(DocketDetailTheme.Photo.emptySymbolFont)
                        .foregroundStyle(accent)
                        .brightness(0.18)
                    Text(label)
                        .font(DocketDetailTheme.Photo.emptyTitleFont)
                        .foregroundStyle(.white)
                    Text("Choose up to \(Recipe.maximumPhotoCount)")
                        .font(DocketDetailTheme.Photo.supportingFont)
                        .foregroundStyle(.white.opacity(0.68))
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: DocketDetailTheme.Photo.emptyHeight)
                .background(DocketTheme.inkLight.opacity(0.96))
                .overlay {
                    RoundedRectangle(
                        cornerRadius: DocketDetailTheme.Photo.cornerRadius,
                        style: .continuous
                    )
                    .stroke(
                        accent.opacity(0.9),
                        style: StrokeStyle(
                            lineWidth: DocketDetailTheme.Photo.borderWidth,
                            dash: DocketDetailTheme.Photo.borderDash
                        )
                    )
                }
                .contentShape(Rectangle())
            } else {
                Label(label, systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
                    .font(DocketDetailTheme.Photo.buttonFont)
                    .foregroundStyle(accent)
                    .padding(.horizontal, DocketDetailTheme.Photo.buttonHorizontalPadding)
                    .frame(height: DocketDetailTheme.Photo.buttonHeight)
                    .background(accent.opacity(0.1))
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: DocketDetailTheme.Photo.buttonCornerRadius,
                            style: .continuous
                        )
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func removePhoto(at index: Int) {
        var updated = photos
        guard updated.indices.contains(index) else { return }
        updated.remove(at: index)
        withAnimation(DocketDetailTheme.Edit.modeAnimation) {
            photoData = updated.first
            additionalPhotoData = Array(updated.dropFirst())
            if index == 0 { boardPhotoPosition = .center }
            if updated.isEmpty { showsPhotoOnBoard = false }
        }
    }

    @MainActor
    private func load(_ items: [PhotosPickerItem]) async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            selectedItems = []
        }

        var updated = photos
        do {
            for item in items.prefix(remainingCapacity) {
                guard let sourceData = try await item.loadTransferable(type: Data.self),
                    let preparedData = ItemPhotoProcessor.preparedData(from: sourceData)
                else { continue }
                updated.append(preparedData)
            }
        } catch {
            errorMessage = "One of those photos couldn't be loaded. Please try again."
        }

        guard updated.count > photos.count else {
            if errorMessage == nil {
                errorMessage = "Those photos couldn't be read. Please choose different ones."
            }
            return
        }

        let wasEmpty = photos.isEmpty
        withAnimation(DocketDetailTheme.Edit.modeAnimation) {
            photoData = updated.first
            additionalPhotoData = Array(updated.dropFirst())
            if wasEmpty {
                boardPhotoPosition = .center
                showsPhotoOnBoard = true
                showsMapOnBoard = false
            }
        }
    }
}

struct RecipePhotoCarousel: View {
    let photos: [Data]
    let coverPosition: BoardPhotoPosition

    var body: some View {
        FittedPhotoLayout(
            aspectRatio: 4.0 / 3.0,
            maximumHeight: DocketDetailTheme.Photo.detailMaximumHeight
        ) {
            TabView {
                ForEach(Array(photos.enumerated()), id: \.offset) { index, data in
                    BoardCroppedPhoto(
                        data: data,
                        position: index == 0 ? coverPosition : .center
                    )
                    .accessibilityLabel("Recipe photo \(index + 1) of \(photos.count)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: DocketDetailTheme.Photo.cornerRadius,
                style: .continuous
            )
        )
        .frame(maxWidth: .infinity)
    }
}

private struct FittedPhotoLayout: Layout {
    let aspectRatio: CGFloat
    let maximumHeight: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty, aspectRatio > 0 else { return .zero }

        let availableHeight = min(proposal.height ?? maximumHeight, maximumHeight)
        let availableWidth = proposal.width ?? availableHeight * aspectRatio
        let width = min(availableWidth, availableHeight * aspectRatio)
        return CGSize(width: width, height: width / aspectRatio)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else { return }
        subview.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )
    }
}

private struct BoardPhotoCropEditor: View {
    @Environment(\.dismiss) private var dismiss

    let data: Data
    @Binding var position: BoardPhotoPosition
    let aspectRatio: CGFloat
    let accent: Color

    @State private var workingPosition: BoardPhotoPosition
    @State private var dragStart: BoardPhotoPosition?

    init(
        data: Data,
        position: Binding<BoardPhotoPosition>,
        aspectRatio: CGFloat,
        accent: Color
    ) {
        self.data = data
        self._position = position
        self.aspectRatio = aspectRatio
        self.accent = accent
        self._workingPosition = State(initialValue: position.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Drag the photo to frame its board card.")
                    .font(DocketDetailTheme.Photo.supportingFont)
                    .foregroundStyle(.secondary)

                cropCanvas
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .frame(maxHeight: 340)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)

                Button("Reset to center") {
                    withAnimation(.snappy) {
                        workingPosition = .center
                    }
                }
                .font(DocketDetailTheme.Photo.buttonFont)
                .foregroundStyle(accent)

                Spacer(minLength: 0)
            }
            .padding()
            .background(DocketTheme.cream)
            .navigationTitle("Board crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        position = workingPosition
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var cropCanvas: some View {
        GeometryReader { geometry in
            BoardCroppedPhoto(data: data, position: workingPosition)
                .overlay {
                    cropGuides
                }
                .contentShape(Rectangle())
                .gesture(cropGesture(in: geometry.size))
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: DocketDetailTheme.Photo.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: DocketDetailTheme.Photo.cornerRadius,
                style: .continuous
            )
            .stroke(accent, lineWidth: 2)
        }
        .accessibilityLabel("Board photo crop")
        .accessibilityHint("Drag the photo to choose which part appears on the board")
    }

    private var cropGuides: some View {
        ZStack {
            HStack(spacing: 0) {
                Spacer()
                Rectangle().frame(width: 0.5)
                Spacer()
                Rectangle().frame(width: 0.5)
                Spacer()
            }
            VStack(spacing: 0) {
                Spacer()
                Rectangle().frame(height: 0.5)
                Spacer()
                Rectangle().frame(height: 0.5)
                Spacer()
            }
        }
        .foregroundStyle(.white.opacity(0.58))
        .allowsHitTesting(false)
    }

    private func cropGesture(in containerSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard let image = UIImage(data: data) else { return }
                let layout = BoardPhotoLayout(
                    imageSize: image.size,
                    containerSize: containerSize
                )
                let start = dragStart ?? workingPosition
                if dragStart == nil { dragStart = start }

                let x = layout.horizontalOverflow > 0
                    ? start.x - Double(value.translation.width / layout.horizontalOverflow)
                    : 0.5
                let y = layout.verticalOverflow > 0
                    ? start.y - Double(value.translation.height / layout.verticalOverflow)
                    : 0.5
                workingPosition = BoardPhotoPosition(x: x, y: y)
            }
            .onEnded { _ in
                dragStart = nil
            }
    }
}

private struct BoardPhotoLayout {
    let imageSize: CGSize
    let horizontalOverflow: CGFloat
    let verticalOverflow: CGFloat

    init(imageSize: CGSize, containerSize: CGSize) {
        guard imageSize.width > 0, imageSize.height > 0,
            containerSize.width > 0, containerSize.height > 0
        else {
            self.imageSize = containerSize
            self.horizontalOverflow = 0
            self.verticalOverflow = 0
            return
        }

        let scale = max(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let scaledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        self.imageSize = scaledSize
        self.horizontalOverflow = max(0, scaledSize.width - containerSize.width)
        self.verticalOverflow = max(0, scaledSize.height - containerSize.height)
    }
}

private struct DocketPhotoButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .padding(.horizontal, DocketDetailTheme.Photo.buttonHorizontalPadding)
            .frame(height: DocketDetailTheme.Photo.buttonHeight)
            .background(tint.opacity(configuration.isPressed ? 0.2 : 0.1))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DocketDetailTheme.Photo.buttonCornerRadius,
                    style: .continuous
                )
            )
    }
}

enum ItemPhotoProcessor {
    static let maximumDimension: CGFloat = 1_800
    static let compressionQuality: CGFloat = 0.82

    static func preparedData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(1, maximumDimension / longestSide)
        let targetSize = CGSize(
            width: max(1, (image.size.width * scale).rounded()),
            height: max(1, (image.size.height * scale).rounded())
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: compressionQuality)
    }
}
