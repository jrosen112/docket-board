//
//  BoardView.swift
//  Docket
//
//  The board screen. Pure composition: background + filter bar + masonry of
//  cards + toolbar + sheets. All visuals live in components/DocketTheme; the
//  only state here is screen-local (sheet flags, filter selection).
//

import CloudKit
import SwiftUI

struct BoardView: View {
    @Environment(BoardStore.self) private var store
    @Environment(\.dismissSearch) private var dismissSearch
    @Namespace private var toolbarTransitionNamespace
    @Namespace private var boardTransitionNamespace

    @State private var addTarget: AddTarget?
    @State private var showingSettings = false
    @State private var showingBoardManager = false
    @State private var detailTarget: DetailTarget?
    @State private var filter = BoardFilter()
    @State private var searchQuery = ""
    @State private var scrollNoteProgress: CGFloat = 0
    @State private var boardNotice: BoardNotice?
    @State private var pendingSave: PendingBoardSave?
    @State private var pendingTransfer: PendingBoardTransfer?
    @State private var deleteCandidate: BoardDeleteCandidate?
    @State private var moveCandidate: BoardMoveCandidate?
    @State private var physicalDeleteCandidates: [CKRecord.ID: BoardDeleteCandidate] = [:]
    @State private var locallyRemovedItemIDs: Set<CKRecord.ID> = []
    @State private var physicalInsertionItemID: CKRecord.ID?
    @State private var physicalInsertionTrigger: UUID?
    @State private var photoViewerTarget: BoardPhotoViewerTarget?
    @State private var diceRoll: DiceRoll?
    @State private var lastRandomItemID: CKRecord.ID?
    @State private var longPressTarget: CKRecord.ID?
    @State private var pressedItemID: CKRecord.ID?

    private var filteredItems: [any SharedListItem] {
        filter.apply(to: store.items).filter {
            !locallyRemovedItemIDs.contains($0.id)
                && itemMatchesBoardSearch($0, query: searchQuery)
        }
    }

    private var availableCuisines: [String] {
        CuisineCatalog.normalized(
            store.items.flatMap(itemCuisines) + Array(filter.cuisines)
        )
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var otherBoards: [Space] {
        store.spaces.filter { $0 != store.space }
    }

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filteredItemIDs: [CKRecord.ID] {
        filteredItems.map(\.id)
    }

    private var deleteAlertTitle: String {
        guard let deleteCandidate else { return "Delete Item?" }
        return "Delete “" + deleteCandidate.title + "”?"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(DocketTheme.boardBackground)
                    .ignoresSafeArea()
                BoardScrollNote(
                    progress: store.isSwitchingBoard ? 0 : scrollNoteProgress,
                    createdCount: store.currentUserItemCount,
                    totalCount: store.items.count
                )
                boardContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DocketTheme.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                topToolbarItems
                BoardBottomToolbar(
                    isAddEnabled: !store.isSwitchingBoard,
                    transitionNamespace: toolbarTransitionNamespace,
                    onSettings: { showingSettings = true },
                    onAdd: beginAdding(category:)
                )
            }
            .searchable(
                text: $searchQuery,
                placement: .toolbar,
                prompt: "Search board"
            )
            .onSubmit(of: .search) {
                guard !isSearching else { return }
                dismissSearch()
            }
            .overlay(alignment: .bottom) { boardOverlay }
            .overlay { diceRollOverlay }
            .sheet(item: $addTarget) { target in
                NewItemView(
                    itemID: target.id,
                    dateAdded: target.dateAdded,
                    initialCategory: target.category,
                    onSave: { beginSave($0, kind: .pinning) }
                )
                .navigationTransition(
                    .zoom(
                        sourceID: BoardToolbarTransitionID.add,
                        in: toolbarTransitionNamespace
                    )
                )
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .navigationTransition(
                        .zoom(
                            sourceID: BoardToolbarTransitionID.settings,
                            in: toolbarTransitionNamespace
                        )
                    )
            }
            .sheet(isPresented: $showingBoardManager) {
                BoardManagerView()
            }
            .fullScreenCover(item: $photoViewerTarget) { target in
                BoardPhotoViewer(title: target.title, photos: target.photos)
            }
            .navigationDestination(item: $detailTarget) { target in
                ItemDetailView(
                    itemID: target.id,
                    onSave: { beginSave($0, kind: .editing) },
                    onDelete: presentDeletedNotice(title:),
                    startsEditing: target.startsEditing
                )
                .navigationTransition(
                    .zoom(sourceID: target.id, in: boardTransitionNamespace)
                )
            }
            .background {
                deleteAlertPresenter
            }
            .background {
                moveAlertPresenter
            }
            .task(id: store.itemNavigationRequest?.id) {
                guard let request = store.itemNavigationRequest else { return }
                detailTarget = DetailTarget(id: request.recordID)
                store.consumeItemNavigationRequest(request.id)
            }
        }
        .overlayPreferenceValue(BoardCardAnchorPreferenceKey.self) { anchors in
            GeometryReader { geometry in
                longPressOverlay(anchors: anchors, geometry: geometry)
            }
            .ignoresSafeArea()
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: longPressTarget) { _, target in
            target != nil
        }
    }

    private var deleteAlertPresenter: some View {
        Color.clear
            .alert(
                deleteAlertTitle,
                isPresented: Binding(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                presenting: deleteCandidate
            ) { candidate in
                Button("Delete", role: .destructive) {
                    deleteCandidate = nil
                    performDelete(candidate)
                }
                Button("Cancel", role: .cancel) {
                    deleteCandidate = nil
                }
            } message: { _ in
                Text("This removes the item from the shared board for everyone. This can't be undone.")
            }
            .tint(DocketTheme.alertActionTint)
    }

    private var moveAlertPresenter: some View {
        let title =
            moveCandidate.map {
                "Move “\($0.item.title)” to “\($0.destination.title)”?"
            } ?? "Move Item?"

        return Color.clear
            .alert(
                title,
                isPresented: Binding(
                    get: { moveCandidate != nil },
                    set: { if !$0 { moveCandidate = nil } }
                ),
                presenting: moveCandidate
            ) { candidate in
                Button("Move", role: .destructive) {
                    moveCandidate = nil
                    beginTransfer(candidate.item, to: candidate.destination, kind: .move)
                }
                Button("Cancel", role: .cancel) {
                    moveCandidate = nil
                }
            } message: { candidate in
                Text(
                    "The item will be copied to \(candidate.destination.title), then removed from \(store.space.title) for everyone."
                )
            }
            .tint(DocketTheme.alertActionTint)
    }

    // MARK: - Pieces

    private var boardContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    boardItems
                        .padding(.top, 10)
                        .padding(.bottom, 32)
                } header: {
                    BoardFilterHeader(
                        filter: $filter,
                        categories: ItemCategory.supported,
                        cuisines: availableCuisines
                    )
                }
            }
            .padding(.horizontal, 16)
        }
        .docketPullToRefresh(isEnabled: !store.isSwitchingBoard) {
            await refreshBoard()
        }
        .onScrollGeometryChange(
            for: CGFloat.self,
            of: { geometry in
                let offset = geometry.contentOffset.y + geometry.contentInsets.top
                return DocketTheme.BoardScrollNote.progress(for: offset)
            },
            action: { _, progress in
                scrollNoteProgress = progress
            }
        )
    }

    private var boardItems: some View {
        ZStack(alignment: .top) {
            if store.isSwitchingBoard {
                BoardSkeletonView()
                    .transition(.opacity)
            } else {
                loadedBoardItems
                    .transition(.opacity)
            }
        }
        .animation(
            .easeInOut(duration: DocketTheme.BoardSkeleton.contentTransitionDuration),
            value: store.isSwitchingBoard
        )
    }

    @ViewBuilder
    private var loadedBoardItems: some View {
        if filteredItems.isEmpty {
            EmptyBoardView(
                isFiltered: (filter.isActive || isSearching) && !store.items.isEmpty,
                isSearching: isSearching && !store.items.isEmpty
            )
        } else {
            MasonryLayout(
                columns: 2,
                spacing: 14,
                contentOverflow: DocketTheme.BoardCard.transitionCaptureInset
            ) {
                ForEach(filteredItems, id: \.id) { item in
                    card(for: item)
                }
            }
            .animation(DocketTheme.BoardItems.changeAnimation, value: filteredItemIDs)
            // Breathing room so pins/tilts don't clip at the edges.
            .padding(.top, 6)
        }
    }

    private func card(for item: any SharedListItem) -> some View {
        let captureInset = DocketTheme.BoardCard.transitionCaptureInset
        let isPhysicallyInserting = physicalInsertionItemID == item.id
        let photos = photoViewerPhotos(for: item)

        return PhysicalCardInsertionView(
            isStaged: isPhysicallyInserting,
            animationTrigger: isPhysicallyInserting ? physicalInsertionTrigger : nil,
            direction: physicalInsertionDirection(for: item.id),
            onAnimationCompleted: {
                finishPhysicalInsertionAnimation(for: item.id)
            }
        ) {
            PhysicalCardRemovalView(
                isRemoving: physicalDeleteCandidates[item.id] != nil,
                direction: physicalDeleteDirection(for: item.id),
                showsPin: !isPhysicallyInserting,
                onAnimationCompleted: {
                    finishPhysicalDeleteAnimation(for: item.id)
                }
            ) {
                BoardCard(
                    item: item,
                    reactionGroups: store.reactionGroups(for: item),
                    showsPin: false
                )
                .anchorPreference(
                    key: BoardCardAnchorPreferenceKey.self,
                    value: .bounds
                ) { [item.id: $0] }
            }
        }
        // Capture visual overflow from the pin, shadow, and card rotation.
        // MasonryLayout accounts for this inset without moving the paper.
        .padding(captureInset)
        .contentShape(.interaction, Rectangle().inset(by: captureInset))
        .matchedTransitionSource(id: item.id, in: boardTransitionNamespace)
        .pinchToOpenPhotos(
            isEnabled: !photos.isEmpty
                && !isPhysicallyInserting
                && physicalDeleteCandidates[item.id] == nil,
            onOpen: {
                photoViewerTarget = BoardPhotoViewerTarget(
                    id: item.id,
                    title: item.title,
                    photos: photos
                )
            }
        )
        // `.onLongPressGesture` rather than a composed gesture: it is the one
        // form that leaves the enclosing scroll view alone. A `.gesture`, an
        // exclusive pair, and a `.simultaneousGesture` all put a long-press
        // recognizer in front of the scroll pan, and the board stops scrolling.
        //
        // Order matters as much as form. Attached after the tap it never fires
        // at all, because the tap is then the inner gesture and claims the
        // sequence — which is what kept this surface shut. Inner here, tap
        // outer, and the tap declines when a hold already opened the surface.
        .onLongPressGesture(
            minimumDuration: DocketTheme.BoardLongPress.holdDuration,
            perform: {
                longPressTarget = item.id
            },
            onPressingChanged: { isPressing in
                withAnimation(DocketTheme.BoardLongPress.pressAnimation) {
                    pressedItemID = isPressing ? item.id : nil
                }
            }
        )
        // Single tap is unconditional so opening an item is instant. Pairing it
        // with a double tap meant every open had to wait out the system
        // multi-tap window first, just to prove no second tap was coming.
        .onTapGesture {
            guard longPressTarget == nil else { return }
            detailTarget = DetailTarget(id: item.id)
        }
        .scaleEffect(
            pressedItemID == item.id
                ? DocketTheme.BoardLongPress.pressedCardScale
                : 1
        )
        .zIndex(
            physicalDeleteCandidates[item.id] == nil && !isPhysicallyInserting
                ? 0 : 10
        )
        .transition(
            isPhysicallyInserting
                ? .identity
                : .asymmetric(
                    insertion: .scale(scale: DocketTheme.BoardItems.insertionScale)
                        .combined(with: .opacity),
                    removal: .scale(scale: DocketTheme.BoardItems.removalScale)
                        .combined(with: .opacity)
                )
        )
    }

    @ViewBuilder
    private func longPressOverlay(
        anchors: [CKRecord.ID: Anchor<CGRect>],
        geometry: GeometryProxy
    ) -> some View {
        if let itemID = longPressTarget,
            let item = store.items.first(where: { $0.id == itemID })
        {
            BoardLongPressOverlay(
                item: item,
                addedBy: store.displayName(for: item),
                attributions: store.reactionAttributions(for: item),
                currentReaction: store.currentReaction(for: item),
                sourceFrame: anchors[itemID].map { geometry[$0] },
                containerSize: geometry.size,
                safeAreaInsets: geometry.safeAreaInsets,
                actions: longPressActions(for: item),
                onSelectReaction: { kind in
                    dismissLongPress()
                    Task { await store.setReaction(kind, for: item) }
                },
                onDismiss: dismissLongPress
            )
            .transition(.opacity.animation(DocketTheme.BoardLongPress.dismissalAnimation))
        }
    }

    private func dismissLongPress() {
        withAnimation(DocketTheme.BoardLongPress.dismissalAnimation) {
            longPressTarget = nil
        }
    }

    /// The menu half of the long-press surface. Board transfers are submenus
    /// because they need a destination; everything else acts immediately, and
    /// the two that can't be undone still route through their own alert.
    private func longPressActions(
        for item: any SharedListItem
    ) -> [BoardLongPressAction] {
        var actions: [BoardLongPressAction] = [
            BoardLongPressAction(
                id: "edit",
                title: "Edit",
                symbol: "pencil",
                handler: {
                    dismissLongPress()
                    detailTarget = DetailTarget(id: item.id, startsEditing: true)
                }
            )
        ]

        if !otherBoards.isEmpty {
            actions.append(
                BoardLongPressAction(
                    id: "duplicate",
                    title: "Duplicate to Board",
                    symbol: "square.on.square",
                    isEnabled: pendingTransfer == nil,
                    children: boardDestinations(for: item, kind: .duplicate)
                )
            )
            actions.append(
                BoardLongPressAction(
                    id: "move",
                    title: "Move to Board",
                    symbol: "arrow.right.square",
                    isEnabled: pendingTransfer == nil,
                    children: boardDestinations(for: item, kind: .move)
                )
            )
        }

        actions.append(
            BoardLongPressAction(
                id: "delete",
                title: "Delete",
                symbol: "trash",
                isDestructive: true,
                handler: {
                    dismissLongPress()
                    deleteCandidate = BoardDeleteCandidate(item: item)
                }
            )
        )
        return actions
    }

    private func boardDestinations(
        for item: any SharedListItem,
        kind: BoardItemTransferKind
    ) -> [BoardLongPressAction] {
        otherBoards.map { destination in
            BoardLongPressAction(
                id: "\(kind)-\(destination.id)",
                title: destination.title,
                symbol: "rectangle.stack.fill",
                isEnabled: pendingTransfer == nil,
                handler: {
                    dismissLongPress()
                    switch kind {
                    case .duplicate:
                        beginTransfer(item, to: destination, kind: .duplicate)
                    case .move:
                        moveCandidate = BoardMoveCandidate(
                            item: item,
                            destination: destination
                        )
                    }
                }
            )
        }
    }

    private func beginAdding(category: ItemCategory) {
        addTarget = AddTarget(
            id: store.newItemID(),
            dateAdded: .now,
            category: category
        )
    }

    private func startDiceRoll() {
        guard diceRoll == nil, !filteredItems.isEmpty else { return }
        let candidates =
            filteredItems.count > 1
            ? filteredItems.filter { $0.id != lastRandomItemID }
            : filteredItems
        guard let item = candidates.randomElement() else { return }

        lastRandomItemID = item.id
        withAnimation(DocketTheme.DiceRoll.presentationAnimation) {
            diceRoll = DiceRoll(
                itemID: item.id,
                title: item.title,
                category: item.category
            )
        }
    }

    private func finishDiceRoll(_ roll: DiceRoll) {
        guard diceRoll?.id == roll.id else { return }
        withAnimation(DocketTheme.DiceRoll.presentationAnimation) {
            diceRoll = nil
        }
        detailTarget = DetailTarget(id: roll.itemID)
    }

    private func performDelete(_ candidate: BoardDeleteCandidate) {
        guard physicalDeleteCandidates[candidate.item.id] == nil else { return }
        physicalDeleteCandidates[candidate.item.id] = candidate
    }

    private func finishPhysicalDeleteAnimation(for itemID: CKRecord.ID) {
        guard let candidate = physicalDeleteCandidates[itemID] else { return }

        withAnimation(DocketTheme.BoardItems.changeAnimation) {
            locallyRemovedItemIDs.insert(itemID)
            physicalDeleteCandidates[itemID] = nil
        }

        Task { @MainActor in
            switch await store.delete(candidate.item) {
            case .deleted:
                locallyRemovedItemIDs.remove(itemID)
                presentDeletedNotice(title: candidate.title)
            case .failed:
                withAnimation(DocketTheme.BoardItems.changeAnimation) {
                    _ = locallyRemovedItemIDs.remove(itemID)
                }
            }
        }
    }

    private func physicalDeleteDirection(for itemID: CKRecord.ID) -> CGFloat {
        DocketTheme.stableHash(for: itemID.recordName + "#delete") % 2 == 0 ? -1 : 1
    }

    private func physicalInsertionDirection(for itemID: CKRecord.ID) -> CGFloat {
        DocketTheme.stableHash(for: itemID.recordName + "#insert") % 2 == 0 ? -1 : 1
    }

    private func photoViewerPhotos(for item: any SharedListItem) -> [BoardPhoto] {
        if let recipe = item as? Recipe {
            return recipe.allPhotoData.map { BoardPhoto(data: $0) }
        }
        guard let photoData = item.photoData else { return [] }
        return [
            BoardPhoto(
                data: photoData,
                highResolutionURL: highResolutionPhotoURL(for: item)
            )
        ]
    }

    /// A sharper source for an item's stored photo, when one is known. Movies
    /// keep a board-sized copy of TMDB artwork, so the viewer can load the
    /// original from TMDB's unauthenticated image CDN.
    private func highResolutionPhotoURL(for item: any SharedListItem) -> URL? {
        guard let movie = item as? Movie else { return nil }
        return TMDBService.fullResolutionPosterURL(path: movie.tmdbPosterPath)
    }

    private func beginTransfer(
        _ item: any SharedListItem,
        to destination: Space,
        kind: BoardItemTransferKind
    ) {
        performTransfer(
            PendingBoardTransfer(
                id: UUID(),
                item: item,
                source: store.space,
                destination: destination,
                destinationRecordID: store.newItemID(in: destination),
                kind: kind,
                stage: .copy
            )
        )
    }

    private func performTransfer(_ transfer: PendingBoardTransfer) {
        pendingTransfer = transfer
        withAnimation(DocketDetailTheme.Edit.modeAnimation) {
            boardNotice = BoardNotice(
                id: transfer.id,
                message: transfer.progressMessage,
                systemImage: transfer.kind.progressSymbol,
                isProgress: true
            )
        }

        Task { @MainActor in
            let minimumDelay = Task {
                try? await Task.sleep(for: DocketTheme.RefreshPill.minimumSaveDuration)
            }
            let result =
                switch transfer.stage {
                case .copy:
                    await store.transfer(
                        transfer.item,
                        to: transfer.destination,
                        kind: transfer.kind,
                        destinationRecordID: transfer.destinationRecordID
                    )
                case .removeSource:
                    await store.finishMove(transfer.item, from: transfer.source)
                }
            await minimumDelay.value

            guard pendingTransfer?.id == transfer.id else { return }
            switch result {
            case .duplicated, .moved:
                pendingTransfer = nil
                withAnimation(DocketDetailTheme.Edit.modeAnimation) {
                    boardNotice = BoardNotice(
                        id: transfer.id,
                        message: transfer.successMessage,
                        systemImage: transfer.kind.successSymbol,
                        dismissalID: UUID()
                    )
                }
            case .copiedButSourceKept:
                let retry = PendingBoardTransfer(
                    id: transfer.id,
                    item: transfer.item,
                    source: transfer.source,
                    destination: transfer.destination,
                    destinationRecordID: transfer.destinationRecordID,
                    kind: .move,
                    stage: .removeSource
                )
                pendingTransfer = retry
                withAnimation(DocketDetailTheme.Edit.modeAnimation) {
                    boardNotice = BoardNotice(
                        id: retry.id,
                        message:
                            "Copied to \(retry.destination.title), but couldn't remove the original — tap to retry",
                        systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90",
                        isRetryable: true
                    )
                }
            case .failed:
                withAnimation(DocketDetailTheme.Edit.modeAnimation) {
                    boardNotice = BoardNotice(
                        id: transfer.id,
                        message: transfer.failureMessage,
                        systemImage: "arrow.clockwise",
                        isRetryable: true
                    )
                }
            }
        }
    }

    private func presentDeletedNotice(title: String) {
        withAnimation(DocketDetailTheme.Edit.modeAnimation) {
            boardNotice = BoardNotice(
                message: "Deleted \(title)",
                systemImage: "trash",
                dismissalID: UUID()
            )
        }
    }

    private func refreshBoard() async {
        guard let summary = await store.refresh() else { return }
        withAnimation(
            .spring(
                response: DocketTheme.RefreshPill.insertionResponse,
                dampingFraction: DocketTheme.RefreshPill.insertionDamping
            )
        ) {
            boardNotice = BoardNotice(
                message: summary.message,
                systemImage: summary.addedItemCount == 0 ? "checkmark" : "plus",
                dismissalID: UUID()
            )
        }
    }

    private func stagePhysicalInsertion(for itemID: CKRecord.ID) {
        physicalInsertionItemID = itemID
        physicalInsertionTrigger = nil
    }

    private func beginPhysicalInsertion(for itemID: CKRecord.ID) {
        guard physicalInsertionItemID == itemID else { return }
        guard filteredItemIDs.contains(itemID) else {
            finishPhysicalInsertionAnimation(for: itemID)
            return
        }
        physicalInsertionTrigger = UUID()
    }

    private func finishPhysicalInsertionAnimation(for itemID: CKRecord.ID) {
        guard physicalInsertionItemID == itemID else { return }
        physicalInsertionItemID = nil
        physicalInsertionTrigger = nil
    }

    private func beginSave(
        _ item: any SharedListItem,
        kind: BoardSaveKind
    ) {
        performSave(
            PendingBoardSave(
                id: UUID(),
                item: item,
                kind: kind,
                requiresRebase: false
            )
        )
    }

    private func retryPendingSave() {
        guard let pendingSave else { return }
        performSave(pendingSave)
    }

    private func retryPendingOperation() {
        if let pendingTransfer {
            performTransfer(pendingTransfer)
        } else {
            retryPendingSave()
        }
    }

    private func performSave(_ initialSave: PendingBoardSave) {
        pendingSave = initialSave
        if initialSave.kind == .pinning {
            stagePhysicalInsertion(for: initialSave.item.id)
        }
        withAnimation(DocketDetailTheme.Edit.modeAnimation) {
            boardNotice = BoardNotice(
                id: initialSave.id,
                message: initialSave.kind.progressMessage,
                systemImage: "arrow.trianglehead.2.clockwise",
                isProgress: true
            )
        }

        Task { @MainActor in
            var save = initialSave

            if save.requiresRebase {
                _ = await store.refresh()
                guard let latest = store.items.first(where: { $0.id == save.item.id }),
                    let rebased = ItemDraft(item: save.item).applying(to: latest)
                else {
                    presentSaveFailure(for: save, requiresRebase: true)
                    return
                }
                save = PendingBoardSave(
                    id: save.id,
                    item: rebased,
                    kind: save.kind,
                    requiresRebase: false
                )
                pendingSave = save
            }

            let minimumDelay = Task {
                try? await Task.sleep(for: DocketTheme.RefreshPill.minimumSaveDuration)
            }
            let result = await store.save(save.item)
            await minimumDelay.value

            guard pendingSave?.id == save.id else {
                if save.kind == .pinning {
                    finishPhysicalInsertionAnimation(for: save.item.id)
                }
                return
            }
            switch result {
            case .saved:
                pendingSave = nil
                withAnimation(DocketDetailTheme.Edit.modeAnimation) {
                    boardNotice = BoardNotice(
                        id: save.id,
                        message: save.kind.successMessage,
                        systemImage: save.kind.successSymbol,
                        dismissalID: UUID()
                    )
                }
                if save.kind == .pinning {
                    beginPhysicalInsertion(for: save.item.id)
                }
            case .conflict:
                presentSaveFailure(for: save, requiresRebase: true)
            case .failed:
                presentSaveFailure(for: save, requiresRebase: false)
            }
        }
    }

    private func presentSaveFailure(
        for save: PendingBoardSave,
        requiresRebase: Bool
    ) {
        if save.kind == .pinning {
            finishPhysicalInsertionAnimation(for: save.item.id)
        }
        pendingSave = PendingBoardSave(
            id: save.id,
            item: save.item,
            kind: save.kind,
            requiresRebase: requiresRebase
        )
        withAnimation(DocketDetailTheme.Edit.modeAnimation) {
            boardNotice = BoardNotice(
                id: save.id,
                message: save.kind.failureMessage,
                systemImage: "arrow.clockwise",
                isRetryable: true
            )
        }
    }

    private func dismissBoardNotice() {
        if boardNotice?.isRetryable == true {
            pendingSave = nil
            pendingTransfer = nil
        }
        withAnimation(
            .easeIn(duration: DocketTheme.RefreshPill.removalDuration)
        ) {
            boardNotice = nil
        }
    }

    @ViewBuilder
    private var boardOverlay: some View {
        VStack(spacing: DocketTheme.RefreshPill.overlaySpacing) {
            if let message = store.errorMessage {
                ErrorBanner(message: message) { store.errorMessage = nil }
            }

            if let notice = boardNotice {
                BoardNoticePill(
                    message: notice.message,
                    systemImage: notice.systemImage,
                    isProgress: notice.isProgress,
                    isRetryable: notice.isRetryable,
                    onRetry: retryPendingOperation,
                    onDismiss: dismissBoardNotice
                )
                .id(notice.id)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: notice.dismissalID) {
                    guard let dismissalID = notice.dismissalID else { return }
                    do {
                        try await Task.sleep(for: DocketTheme.RefreshPill.visibleDuration)
                    } catch {
                        return
                    }
                    guard boardNotice?.dismissalID == dismissalID else { return }
                    dismissBoardNotice()
                }
            }
        }
        .padding(.bottom, DocketTheme.RefreshPill.bottomPadding)
    }

    @ToolbarContentBuilder private var topToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            BoardSwitcher(
                currentSpace: store.space,
                isEnabled: !store.isSwitchingBoard
            ) {
                showingBoardManager = true
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            Button(action: startDiceRoll) {
                Image(systemName: "dice.fill")
                    .foregroundStyle(DocketTheme.brass)
            }
            .disabled(filteredItems.isEmpty || store.isSwitchingBoard || diceRoll != nil)
            .accessibilityLabel("Pick for us")
            .accessibilityHint("Chooses a random item from the visible board")
        }
        #if DEBUG
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await store.seedSampleData() }
                    } label: {
                        Label("Seed sample data", systemImage: "sparkles")
                    }
                    Button(role: .destructive) {
                        Task { await store.deleteSampleData() }
                    } label: {
                        Label("Delete sample data", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(DocketTheme.brass.opacity(0.7))
                }
            }
        #endif
    }

    @ViewBuilder private var diceRollOverlay: some View {
        if let diceRoll {
            DiceRollOverlay(
                winnerTitle: diceRoll.title,
                accent: diceRoll.category.accent,
                onComplete: { finishDiceRoll(diceRoll) }
            )
            .id(diceRoll.id)
            .transition(.scale(scale: 0.86).combined(with: .opacity))
            .zIndex(10)
        }
    }
}

private struct DetailTarget: Identifiable, Hashable {
    let id: CKRecord.ID
    var startsEditing = false
}

/// Where each card sits, so the long-press surface can fly the lifted item in
/// from the board rather than fading it in at the center.
private struct BoardCardAnchorPreferenceKey: PreferenceKey {
    static let defaultValue: [CKRecord.ID: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [CKRecord.ID: Anchor<CGRect>],
        nextValue: () -> [CKRecord.ID: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

private struct BoardPhotoViewerTarget: Identifiable {
    let id: CKRecord.ID
    let title: String
    let photos: [BoardPhoto]
}

private struct DiceRoll: Identifiable {
    let id = UUID()
    let itemID: CKRecord.ID
    let title: String
    let category: ItemCategory
}

private struct AddTarget: Identifiable {
    let id: CKRecord.ID
    let dateAdded: Date
    let category: ItemCategory
}

private struct BoardDeleteCandidate {
    let item: any SharedListItem
    let title: String

    init(item: any SharedListItem) {
        self.item = item
        self.title = item.title
    }
}

private struct BoardMoveCandidate {
    let item: any SharedListItem
    let destination: Space
}

private struct BoardNotice: Identifiable {
    var id = UUID()
    let message: String
    let systemImage: String
    var isProgress = false
    var isRetryable = false
    var dismissalID: UUID?
}

private enum BoardSaveKind: Equatable {
    case pinning
    case editing

    var progressMessage: String {
        switch self {
        case .pinning: "Pinning…"
        case .editing: "Saving…"
        }
    }

    var successMessage: String {
        switch self {
        case .pinning: "Pinned to board"
        case .editing: "Saved"
        }
    }

    var failureMessage: String {
        switch self {
        case .pinning: "Couldn't pin — tap to retry"
        case .editing: "Couldn't save — tap to retry"
        }
    }

    var successSymbol: String {
        switch self {
        case .pinning: "pin.fill"
        case .editing: "checkmark"
        }
    }
}

private struct PendingBoardSave {
    let id: UUID
    let item: any SharedListItem
    let kind: BoardSaveKind
    let requiresRebase: Bool
}

private struct PendingBoardTransfer {
    enum Stage: Equatable {
        case copy
        case removeSource
    }

    let id: UUID
    let item: any SharedListItem
    let source: Space
    let destination: Space
    let destinationRecordID: CKRecord.ID
    let kind: BoardItemTransferKind
    let stage: Stage

    var progressMessage: String {
        if stage == .removeSource { return "Finishing move…" }
        return switch kind {
        case .duplicate: "Duplicating to \(destination.title)…"
        case .move: "Moving to \(destination.title)…"
        }
    }

    var successMessage: String {
        switch kind {
        case .duplicate: "Duplicated to \(destination.title)"
        case .move: "Moved to \(destination.title)"
        }
    }

    var failureMessage: String {
        switch kind {
        case .duplicate: "Couldn't duplicate to \(destination.title) — tap to retry"
        case .move: "Couldn't move to \(destination.title) — tap to retry"
        }
    }
}

extension BoardItemTransferKind {
    fileprivate var progressSymbol: String {
        switch self {
        case .duplicate: "square.on.square"
        case .move: "arrow.right.square"
        }
    }

    fileprivate var successSymbol: String {
        switch self {
        case .duplicate: "square.on.square.fill"
        case .move: "arrow.right.square.fill"
        }
    }
}
