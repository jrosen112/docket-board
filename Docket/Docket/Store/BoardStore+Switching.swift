import CloudKit
import Foundation

extension BoardStore {
    /// Adds an accepted board to the catalog, selects it, and reloads. Existing
    /// memberships and their per-board profiles remain available to switch
    /// back to at any time.
    func switchTo(space newSpace: Space) async {
        SpaceStore.save(newSpace, in: defaults)
        spaces = SpaceStore.loadAll(from: defaults)
        let selectedSpace = spaces.first(where: { $0.id == newSpace.id }) ?? newSpace
        let profileTemplate = currentProfile.map {
            ProfileNameTemplate(firstName: $0.firstName, lastName: $0.lastName)
        } ?? rememberedProfileTemplate()
        if isSwitchingBoard, selectedSpace == space { return }
        guard selectedSpace != space else {
            space = selectedSpace
            isSwitchingBoard = true
            if loadState == .loaded {
                do {
                    try await provisionProfileIfNeeded(
                        in: selectedSpace,
                        using: profileTemplate
                    )
                    guard space == selectedSpace else { return }
                } catch {
                    let message = Self.message(for: error)
                    errorMessage = message
                    loadState = .failed(message: message)
                }
                isSwitchingBoard = false
                return
            }
            let result = await performRefresh()
            guard space == selectedSpace else { return }
            if case .loaded = result {
                do {
                    try await provisionProfileIfNeeded(
                        in: selectedSpace,
                        using: profileTemplate
                    )
                    guard space == selectedSpace else { return }
                    loadState = .loaded
                } catch {
                    let message = Self.message(for: error)
                    errorMessage = message
                    loadState = .failed(message: message)
                }
            }
            isSwitchingBoard = false
            return
        }

        let previousSpace = space
        let previousService = service
        let previousItems = items
        let previousProfiles = profiles
        let previousProfile = currentProfile
        let previousShare = activeShare
        let previousShareSpace = activeShareSpace
        let previousLoadState = loadState

        // Invalidate any in-flight read before changing services.
        refreshGeneration += 1
        isSwitchingBoard = true
        space = selectedSpace
        service = makeService(selectedSpace)
        items = []
        profiles = []
        currentProfile = nil
        activeShare = nil
        activeShareSpace = nil

        let result = await performRefresh()
        // A newer switch owns the presentation state if the selected space
        // changed while this CloudKit request was suspended.
        guard space == selectedSpace else { return }

        switch result {
        case .loaded:
            do {
                try await provisionProfileIfNeeded(
                    in: selectedSpace,
                    using: profileTemplate
                )
                guard space == selectedSpace else { return }
                loadState = .loaded
                isSwitchingBoard = false
            } catch {
                guard space == selectedSpace else { return }
                errorMessage = Self.message(for: error)
                space = previousSpace
                service = previousService
                items = previousItems
                profiles = previousProfiles
                currentProfile = previousProfile
                activeShare = previousShare
                activeShareSpace = previousShareSpace
                loadState = previousLoadState
                isSwitchingBoard = false
                SpaceStore.save(previousSpace, in: defaults)
                spaces = SpaceStore.loadAll(from: defaults)
            }
        case .failed:
            // A failed switch must not strand the app with the new service and
            // the old board's profile. Restore the fully-consistent board that
            // was visible before the request; the failed board stays cataloged
            // so the user can retry it later.
            space = previousSpace
            service = previousService
            items = previousItems
            profiles = previousProfiles
            currentProfile = previousProfile
            activeShare = previousShare
            activeShareSpace = previousShareSpace
            loadState = previousLoadState
            isSwitchingBoard = false
            SpaceStore.save(previousSpace, in: defaults)
            spaces = SpaceStore.loadAll(from: defaults)
        case .superseded:
            break
        }
    }

    /// Profiles are records inside each board's zone. When an existing Docket
    /// user joins a new board, copy their name into that zone silently instead
    /// of treating the absent per-board record as a signed-out session.
    private func provisionProfileIfNeeded(
        in targetSpace: Space,
        using template: ProfileNameTemplate?
    ) async throws {
        guard currentProfile == nil else { return }
        let targetService = service
        let userRecordName = try await targetService.accountUserRecordID().recordName
        guard space == targetSpace else { return }

        if let existing = profileForCurrentAccount(
            in: profiles,
            space: targetSpace,
            userRecordName: userRecordName
        ) {
            defaults.set(existing.id.recordName, forKey: profileKey(for: targetSpace))
            currentProfile = existing
            rememberProfileTemplate(existing)
            return
        }

        guard let template else { return }
        let profile = UserProfile(
            id: targetService.newRecordID(),
            firstName: template.firstName,
            lastName: template.lastName
        )
        let savedRecord = try await targetService.save(profile.toRecord())
        guard space == targetSpace else { return }
        var savedProfile = UserProfile(record: savedRecord) ?? profile
        savedProfile.creatorUserRecordName = userRecordName
        defaults.set(savedProfile.id.recordName, forKey: profileKey(for: targetSpace))
        profiles.append(savedProfile)
        currentProfile = savedProfile
        rememberProfileTemplate(savedProfile)
    }

    /// Queues a confirmation sheet after CloudKit accepts an invitation. On a
    /// cold launch, presentation waits until the user's existing identity has
    /// had a chance to load so the invite never looks like a sign-in failure.
    func openAcceptedShare(
        _ acceptedSpace: Space,
        inviterName: String? = nil
    ) async {
        let invitation = BoardInvitation(
            space: acceptedSpace,
            inviterName: inviterName?.trimmingCharacters(in: .whitespacesAndNewlines).orNil
        )
        pendingAcceptedInvitation = invitation
        shareAcceptanceErrorMessage = nil
        guard didBootstrap else { return }
        presentPendingBoardInvitationIfNeeded()
    }

    /// Keeps the already-accepted CloudKit membership available without
    /// changing the board currently on screen.
    func dismissBoardInvitation() {
        guard !isJoiningBoardInvitation else { return }
        boardInvitation = nil
        pendingAcceptedInvitation = nil
    }

    /// Opens the accepted board and silently provisions this person's profile
    /// inside its shared zone. CloudKit can take a few moments to expose a
    /// freshly accepted zone, so retry briefly before surfacing an error.
    func joinPendingBoardInvitation() async {
        guard
            let invitation = boardInvitation ?? pendingAcceptedInvitation,
            !isJoiningBoardInvitation
        else { return }

        isJoiningBoardInvitation = true
        shareAcceptanceErrorMessage = nil
        defer { isJoiningBoardInvitation = false }

        let acceptedSpace = invitation.space
        await switchTo(space: acceptedSpace)
        if finishBoardInvitationIfLoaded(acceptedSpace) { return }

        for delay in [
            Duration.milliseconds(500),
            .seconds(1.5),
            .seconds(3),
            .seconds(6)
        ] {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            await switchTo(space: acceptedSpace)
            if finishBoardInvitationIfLoaded(acceptedSpace) { return }
        }

        shareAcceptanceErrorMessage =
            "The invitation was accepted, but iCloud is still preparing the board. Tap Join Board to try again in a moment."
    }

    func presentPendingBoardInvitationIfNeeded() {
        guard didBootstrap, let invitation = pendingAcceptedInvitation else { return }

        // CKAcceptSharesOperation has already granted membership. Catalog it
        // now while preserving the currently selected board, which gives Not
        // Now useful semantics instead of losing the accepted invitation.
        SpaceStore.replace(
            with: spaces + [invitation.space],
            selected: space,
            in: defaults
        )
        spaces = SpaceStore.loadAll(from: defaults)
        boardInvitation = invitation
    }

    private func finishBoardInvitationIfLoaded(_ acceptedSpace: Space) -> Bool {
        guard space == acceptedSpace, loadState == .loaded, !isSwitchingBoard else {
            return false
        }
        boardInvitation = nil
        pendingAcceptedInvitation = nil
        return true
    }

    /// Selects the destination board and asks BoardView to push the referenced
    /// item. The request is retained across cold launch until bootstrap has
    /// restored the board catalog and profile identity.
    func openDeepLink(_ link: BoardDeepLink) async {
        pendingDeepLink = link
        await openPendingDeepLinkIfNeeded()
    }

    func consumeItemNavigationRequest(_ requestID: UUID) {
        guard itemNavigationRequest?.id == requestID else { return }
        itemNavigationRequest = nil
    }

    func openPendingDeepLinkIfNeeded() async {
        guard didBootstrap, let link = pendingDeepLink else { return }
        guard let destination = spaces.first(where: { $0.id == link.spaceID }) else {
            pendingDeepLink = nil
            errorMessage = "That board is no longer available in this iCloud account."
            return
        }

        if destination != space {
            await switchTo(space: destination)
        } else {
            _ = await refresh()
        }
        guard space == destination, loadState == .loaded, !isSwitchingBoard else {
            return
        }

        pendingDeepLink = nil
        guard let recordName = link.itemRecordName else { return }
        guard let item = items.first(where: { $0.id.recordName == recordName }) else {
            errorMessage = "That pin is no longer available on \(destination.title)."
            return
        }
        itemNavigationRequest = BoardItemNavigationRequest(recordID: item.id)
    }
}
