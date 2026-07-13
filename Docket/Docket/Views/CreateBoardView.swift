import SwiftUI

struct CreateBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BoardStore.self) private var store

    @State private var title = ""
    @State private var isCreating = false
    @FocusState private var isTitleFocused: Bool

    private var cleanedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Rectangle()
                    .fill(DocketTheme.boardBackground)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: DocketTheme.CreateBoard.contentSpacing) {
                    Text("What should we call it?")
                        .font(DocketTheme.CreateBoard.headingFont)
                        .foregroundStyle(DocketTheme.CreateBoard.headingColor)

                    Text("Each board is its own private space. You decide who gets invited.")
                        .font(DocketTheme.CreateBoard.supportingFont)
                        .foregroundStyle(DocketTheme.CreateBoard.supportingColor)

                    TextField("Weekend Plans", text: $title)
                        .font(DocketTheme.CreateBoard.inputFont)
                        .foregroundStyle(DocketTheme.CreateBoard.inputColor)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isTitleFocused)
                        .onSubmit(create)
                        .padding(DocketTheme.CreateBoard.inputPadding)
                        .background(
                            DocketTheme.CreateBoard.inputBackground,
                            in: RoundedRectangle(
                                cornerRadius: DocketTheme.CreateBoard.inputCornerRadius,
                                style: .continuous
                            )
                        )

                    if let errorMessage = store.errorMessage {
                        Text(errorMessage)
                            .font(DocketTheme.CreateBoard.errorFont)
                            .foregroundStyle(DocketTheme.CreateBoard.errorColor)
                    }

                    Spacer()
                }
                .padding(.horizontal, DocketTheme.CreateBoard.horizontalPadding)
                .padding(.top, DocketTheme.CreateBoard.topPadding)
            }
            .navigationTitle("New Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DocketTheme.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DocketTheme.CreateBoard.cancelColor)
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button(action: create) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Label("Create", systemImage: "plus")
                        }
                    }
                    .docketPrimaryActionStyle()
                    .disabled(cleanedTitle.isEmpty || isCreating)
                }
            }
            .task {
                try? await Task.sleep(for: DocketTheme.CreateBoard.focusDelay)
                isTitleFocused = true
            }
        }
    }

    private func create() {
        guard !cleanedTitle.isEmpty, !isCreating else { return }
        isCreating = true
        Task {
            if await store.createBoard(title: cleanedTitle) {
                dismiss()
            } else {
                isCreating = false
            }
        }
    }
}
