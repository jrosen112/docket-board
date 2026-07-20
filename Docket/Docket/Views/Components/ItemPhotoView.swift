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

/// Photo picker used by both the add flow and the typed detail editors.
struct ItemPhotoEditor: View {
    @Binding var photoData: Data?
    @Binding var showsPhotoOnBoard: Bool
    @Binding var showsMapOnBoard: Bool

    let accent: Color

    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var errorMessage: String?

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
    }

    private func photoPreview(_ data: Data) -> some View {
        ItemPhotoImage(data: data, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: DocketDetailTheme.Photo.editorMaximumHeight)
            .background(DocketTheme.ink.opacity(0.08))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DocketDetailTheme.Photo.cornerRadius,
                    style: .continuous
                )
            )
    }

    private var controls: some View {
        HStack(spacing: DocketDetailTheme.Photo.controlSpacing) {
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                preferredItemEncoding: .automatic
            ) {
                Label("Change photo", systemImage: "photo.badge.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DocketPhotoButtonStyle(tint: accent))

            Button(role: .destructive) {
                withAnimation(DocketDetailTheme.Edit.modeAnimation) {
                    photoData = nil
                    showsPhotoOnBoard = false
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
