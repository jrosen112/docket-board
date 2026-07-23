import SwiftUI
import UIKit

struct SharedRecipePayload {
    let url: URL
    let suggestedTitle: String?
    let caption: String?
}

private enum ShareRecipeField: Hashable {
    case title
}

struct ShareRootView: View {
    let payload: SharedRecipePayload?
    let boards: [ShareBoard]
    let onCancel: () -> Void
    let onComplete: () -> Void

    @State private var title: String
    @State private var ingredients = ""
    @State private var instructions = ""
    @State private var photoData: Data?
    @State private var selectedBoardID: String?
    @State private var isAnalyzing: Bool
    @State private var hasAttemptedAnalysis = false
    @State private var showsAnalysisFailure = false
    @State private var analysisFailureMessage = ""
    @State private var isSaving = false
    @State private var didSave = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: ShareRecipeField?

    init(
        payload: SharedRecipePayload?,
        boards: [ShareBoard],
        onCancel: @escaping () -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.payload = payload
        self.boards = boards
        self.onCancel = onCancel
        self.onComplete = onComplete
        _title = State(initialValue: payload?.suggestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        _selectedBoardID = State(initialValue: boards.first?.id)
        _isAnalyzing = State(initialValue: payload != nil)
        _photoData = State(initialValue: nil)
    }

    private var selectedBoard: ShareBoard? {
        boards.first { $0.id == selectedBoardID }
    }

    private var canSave: Bool {
        payload != nil && selectedBoard != nil && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isAnalyzing
    }

    var body: some View {
        ZStack {
            SharePalette.navy.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                ScrollView {
                    paperCard
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            if isAnalyzing {
                analysisOverlay
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .interactiveDismissDisabled(isSaving || isAnalyzing)
        .task { await analyzeCaptionIfNeeded() }
        .background {
            Color.clear
                .alert("Couldn't create recipe", isPresented: $showsAnalysisFailure) {
                    Button("Edit manually") {
                        if title.isEmpty {
                            focusedField = .title
                        }
                    }
                } message: {
                    Text(analysisFailureMessage)
                }
                .tint(.blue)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onCancel) {
                Text("Cancel")
                    .frame(minWidth: 68, minHeight: 48)
                    .background(
                        Capsule(style: .continuous)
                            .fill(SharePalette.cream.opacity(0.12))
                    )
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(SharePalette.cream.opacity(0.9))
            .contentShape(Capsule())
            .buttonStyle(.plain)
            .accessibilityHint("Closes the share sheet without saving")
            .disabled(isSaving || isAnalyzing)

            Spacer(minLength: 4)

            Label("SHARE TO DOCKET", systemImage: "pin.fill")
                .font(.system(size: 15, weight: .black))
                .tracking(1.05)
                .foregroundStyle(SharePalette.brass)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 4)

            Button(action: save) {
                Text("Save")
                    .frame(minWidth: 68, minHeight: 48)
                    .background(
                        Capsule(style: .continuous)
                            .fill(canSave ? SharePalette.brass : SharePalette.cream.opacity(0.09))
                    )
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(canSave ? SharePalette.navy : SharePalette.cream.opacity(0.32))
            .contentShape(Capsule())
            .buttonStyle(.plain)
            .accessibilityHint("Adds this recipe to the selected board")
            .disabled(!canSave || isSaving)
        }
        .frame(minHeight: 52)
    }

    private var titleEditor: some View {
        ZStack(alignment: .topLeading) {
            if title.isEmpty {
                Text("What should we call it?")
                    .font(.custom("Georgia", size: 20))
                    .foregroundStyle(SharePalette.ink.opacity(0.38))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $title)
                .font(.custom("Georgia-Bold", size: 22))
                .foregroundStyle(SharePalette.ink)
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .title)
                .frame(minHeight: 76, maxHeight: 108)
                .padding(.horizontal, 1)
                .accessibilityLabel("Recipe title")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.white.opacity(0.32))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    focusedField == .title ? SharePalette.sage : SharePalette.ink.opacity(0.16),
                    lineWidth: focusedField == .title ? 2 : 1
                )
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = .title }
    }

    private var paperCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            if didSave {
                savedContent
            } else if let payload {
                form(for: payload)
            } else {
                unavailableContent
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(SharePalette.cream)
                .shadow(color: .black.opacity(0.3), radius: 9, y: 5)
        )
        .overlay(alignment: .top) {
            Circle()
                .fill(SharePalette.brass)
                .frame(width: 14, height: 14)
                .offset(y: -6)
        }
    }

    private func form(for payload: SharedRecipePayload) -> some View {
        Group {
            Label("RECIPE", systemImage: "book.pages.fill")
                .font(.caption.weight(.black))
                .tracking(1.2)
                .foregroundStyle(SharePalette.sage)

            if let photoData, let image = UIImage(data: photoData) {
                thumbnailPreview(image)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Title")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SharePalette.ink.opacity(0.58))
                titleEditor
            }

            recipeTextEditor(
                label: "Ingredients",
                placeholder: "One ingredient per line",
                text: $ingredients,
                minHeight: 120
            )

            recipeTextEditor(
                label: "Instructions",
                placeholder: "One step per line",
                text: $instructions,
                minHeight: 150
            )

            VStack(alignment: .leading, spacing: 7) {
                Text("Original link")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SharePalette.ink.opacity(0.58))
                Label(payload.url.host ?? payload.url.absoluteString, systemImage: "link")
                    .font(.footnote)
                    .foregroundStyle(SharePalette.ink.opacity(0.76))
                    .lineLimit(2)
            }

            if boards.isEmpty {
                Text("Open Docket once after updating so your boards are available in the share sheet.")
                    .font(.footnote)
                    .foregroundStyle(SharePalette.ink.opacity(0.65))
            } else {
                Picker("Add to board", selection: $selectedBoardID) {
                    ForEach(boards) { board in
                        Text(board.title).tag(Optional(board.id))
                    }
                }
                .pickerStyle(.menu)
                .tint(SharePalette.ink)
            }

            if isSaving {
                HStack(spacing: 10) {
                    ProgressView().tint(SharePalette.sage)
                    Text("Pinning to \(selectedBoard?.title ?? "board")…")
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(SharePalette.ink.opacity(0.7))
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color(red: 0.64, green: 0.19, blue: 0.16))
            }
        }
    }

    private func thumbnailPreview(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Cover photo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SharePalette.ink.opacity(0.58))

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            photoData = nil
                        }
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.black.opacity(0.62), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .accessibilityLabel("Remove cover photo")
                }
        }
    }

    private func recipeTextEditor(
        label: String,
        placeholder: String,
        text: Binding<String>,
        minHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SharePalette.ink.opacity(0.58))

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(SharePalette.ink.opacity(0.34))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: text)
                    .font(.body)
                    .foregroundStyle(SharePalette.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minHeight)
                    .padding(.horizontal, 1)
                    .accessibilityLabel(label)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.white.opacity(0.32))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(SharePalette.ink.opacity(0.16), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }

    private var analysisOverlay: some View {
        ZStack {
            SharePalette.navy.opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .tint(SharePalette.brass)

                VStack(spacing: 7) {
                    Text("Finding the recipe…")
                        .font(.custom("Georgia-Bold", size: 24))
                        .foregroundStyle(SharePalette.cream)

                    Text("Reading the shared link and organizing its caption")
                        .font(.subheadline)
                        .foregroundStyle(SharePalette.cream.opacity(0.68))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analyzing recipe caption")
    }

    private var savedContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(SharePalette.sage)
            Text("Pinned to \(selectedBoard?.title ?? "Docket")")
                .font(.custom("Georgia-Bold", size: 22))
                .foregroundStyle(SharePalette.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var unavailableContent: some View {
        ContentUnavailableView(
            "No recipe link found",
            systemImage: "link.badge.plus",
            description: Text("Share a web, Instagram, or TikTok link to save it as a Recipe.")
        )
    }

    private func save() {
        guard let payload, let board = selectedBoard, canSave, !isSaving else { return }
        focusedField = nil
        isSaving = true
        errorMessage = nil

        Task { @MainActor in
            do {
                try await ShareRecipeService.save(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    sourceURL: payload.url,
                    ingredients: recipeLines(from: ingredients),
                    instructions: recipeLines(from: instructions),
                    photoData: photoData,
                    to: board
                )
                withAnimation(.spring(response: 0.32, dampingFraction: 0.74)) {
                    didSave = true
                    isSaving = false
                }
                try? await Task.sleep(for: .milliseconds(700))
                onComplete()
            } catch {
                isSaving = false
                errorMessage = ShareRecipeService.message(for: error)
            }
        }
    }

    @MainActor
    private func analyzeCaptionIfNeeded() async {
        guard !hasAttemptedAnalysis, let payload else { return }
        hasAttemptedAnalysis = true

        do {
            let metadata: RecipePageMetadata?
            do {
                metadata = try await RecipePageMetadataLoader.metadata(for: payload.url)
            } catch {
                guard payload.caption != nil else { throw error }
                metadata = nil
            }

            guard let caption = payload.caption ?? metadata?.caption else {
                throw CaptionRecipeAnalysisError.noCaption
            }
            async let preparedPhoto = RecipeThumbnailLoader.preparedData(for: metadata?.imageURL)
            let draft = try await CaptionRecipeAnalyzer.analyze(caption: caption)
            let loadedPhoto = await preparedPhoto
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                title = draft.title
                ingredients = draft.ingredients.joined(separator: "\n")
                instructions = draft.instructions.joined(separator: "\n")
                photoData = loadedPhoto
                isAnalyzing = false
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            isAnalyzing = false
            analysisFailureMessage = analysisFailureCopy(for: error)
            showsAnalysisFailure = true
        }
    }

    private func analysisFailureCopy(for error: Error) -> String {
        if error is RecipePageMetadataError {
            return "Docket couldn't read a recipe caption from this public link. You can add the details manually."
        }
        return switch error as? CaptionRecipeAnalysisError {
        case .modelUnavailable:
            "On-device recipe analysis isn't available right now. You can add the details manually."
        case .noCaption:
            "No recipe caption was included with this share. You can add the details manually."
        case .noRecipe:
            "Docket couldn't find a complete recipe in this caption. You can add the details manually."
        case nil:
            "Docket couldn't analyze this caption. You can add the details manually."
        }
    }

    private func recipeLines(from value: String) -> [String] {
        value.components(separatedBy: .newlines).cleanedRecipeLines
    }
}

private enum SharePalette {
    static let navy = Color(red: 20 / 255, green: 24 / 255, blue: 31 / 255)
    static let ink = Color(red: 20 / 255, green: 24 / 255, blue: 31 / 255)
    static let cream = Color(red: 239 / 255, green: 230 / 255, blue: 211 / 255)
    static let brass = Color(red: 217 / 255, green: 164 / 255, blue: 65 / 255)
    static let sage = Color(red: 145 / 255, green: 175 / 255, blue: 132 / 255)
}
