import CloudKit
import Foundation

extension BoardStore {
    /// Reclaims this iCloud user's profiles and board memberships on a new
    /// device. Profile ownership comes from CloudKit's creator metadata; no
    /// names are guessed and no duplicate profile records are created.
    func restoreFromICloud() async -> ICloudRestoreResult {
        errorMessage = nil
        isLoading = true

        do {
            try await requireNetwork()
            let userRecordName = (try await service.accountUserRecordID()).recordName
            let discovered = try await service.discoverSpaces()
            let candidates = discovered.map { discoveredSpace in
                spaces.first(where: { $0.id == discoveredSpace.id }) ?? discoveredSpace
            }

            var restored: [(
                space: Space,
                service: any SpaceDataService,
                items: [any SharedListItem],
                profiles: [UserProfile],
                profile: UserProfile
            )] = []
            var firstLoadError: Error?

            for candidate in candidates {
                let candidateService = makeService(candidate)
                do {
                    let loaded = try await candidateService.loadEverything()
                    guard let profile = loaded.profiles.first(where: {
                        Self.profileBelongsToCurrentAccount(
                            $0,
                            in: candidate,
                            userRecordName: userRecordName
                        )
                    }) else { continue }
                    restored.append((
                        candidate,
                        candidateService,
                        loaded.items,
                        loaded.profiles,
                        profile
                    ))
                } catch {
                    if firstLoadError == nil { firstLoadError = error }
                }
            }

            guard !restored.isEmpty else {
                isLoading = false
                if let firstLoadError {
                    needsMembershipRecovery = true
                    let message = Self.message(for: firstLoadError)
                    errorMessage = message
                    return .failed(message: message)
                }
                needsMembershipRecovery = false
                return .notFound
            }

            let selected = restored.first(where: { $0.space.id == space.id }) ?? restored[0]
            // Discovery succeeded for every candidate even if loading one of
            // those zones failed transiently. Keep all discovered memberships
            // so one flaky board never disappears from the local switcher.
            SpaceStore.replace(with: candidates, selected: selected.space, in: defaults)
            for board in restored {
                defaults.set(
                    board.profile.id.recordName,
                    forKey: profileKey(for: board.space)
                )
                remember(items: board.items, in: board.space)
            }

            refreshGeneration += 1
            space = selected.space
            spaces = SpaceStore.loadAll(from: defaults)
            service = selected.service
            items = selected.items.sorted { $0.dateAdded > $1.dateAdded }
            profiles = selected.profiles
            currentProfile = selected.profile
            rememberProfileTemplate(selected.profile)
            activeShare = nil
            activeShareSpace = nil
            errorMessage = nil
            isLoading = false
            loadState = .loaded
            needsMembershipRecovery = firstLoadError != nil
            return .restored(boardCount: restored.count)
        } catch {
            needsMembershipRecovery = true
            let message = Self.message(for: error)
            errorMessage = message
            isLoading = false
            return .failed(message: message)
        }
    }

    /// CloudKit aliases the owner of a private database to
    /// `CKCurrentUserDefaultName` in record system metadata. Shared databases
    /// do not get that fallback because their default owner is another person.
    static func profileBelongsToCurrentAccount(
        _ profile: UserProfile,
        in space: Space,
        userRecordName: String
    ) -> Bool {
        guard let creator = profile.creatorUserRecordName else { return false }
        if creator == userRecordName { return true }
        return space.isOwned && creator == CKCurrentUserDefaultName
    }

    /// Aggregates only items whose `addedBy` reference points at this user's
    /// profile on that board. No records are mutated while calculating stats.
    func loadProfileStats() async -> ProfileStatsLoadResult {
        do {
            try await requireNetwork()
            let userRecordName = (try await service.accountUserRecordID()).recordName
            var loadedBoardCount = 0
            var itemCount = 0
            var wantToGoCount = 0
            var plannedCount = 0
            var completedCount = 0
            var categoryCounts: [ItemCategory: Int] = [:]
            var boardStats: [BoardProfileStats] = []

            for candidate in spaces {
                do {
                    let loaded = try await makeService(candidate).loadEverything()
                    guard let profile = profileForCurrentAccount(
                        in: loaded.profiles,
                        space: candidate,
                        userRecordName: userRecordName
                    ) else { continue }

                    loadedBoardCount += 1
                    let authoredItems = loaded.items.filter {
                        $0.addedBy.recordID == profile.id
                    }
                    itemCount += authoredItems.count
                    for item in authoredItems {
                        switch item.status {
                        case .wantToGo: wantToGoCount += 1
                        case .planned: plannedCount += 1
                        case .completed: completedCount += 1
                        }
                        categoryCounts[item.category, default: 0] += 1
                    }
                    boardStats.append(
                        BoardProfileStats(
                            id: candidate.id,
                            title: candidate.title,
                            itemCount: authoredItems.count
                        )
                    )
                } catch {
                    // Keep useful partial stats when one board is temporarily
                    // unavailable. The page calls this out explicitly.
                }
            }

            let favoriteCategory = ItemCategory.supported.max { lhs, rhs in
                let lhsCount = categoryCounts[lhs, default: 0]
                let rhsCount = categoryCounts[rhs, default: 0]
                if lhsCount == rhsCount {
                    return ItemCategory.supported.firstIndex(of: lhs)!
                        > ItemCategory.supported.firstIndex(of: rhs)!
                }
                return lhsCount < rhsCount
            }.flatMap { categoryCounts[$0, default: 0] > 0 ? $0 : nil }

            return .loaded(
                ProfileStats(
                    boardCount: spaces.count,
                    loadedBoardCount: loadedBoardCount,
                    itemCount: itemCount,
                    wantToGoCount: wantToGoCount,
                    plannedCount: plannedCount,
                    completedCount: completedCount,
                    favoriteCategory: favoriteCategory,
                    boards: boardStats.sorted {
                        if $0.itemCount == $1.itemCount { return $0.title < $1.title }
                        return $0.itemCount > $1.itemCount
                    }
                )
            )
        } catch {
            return .failed(message: Self.message(for: error))
        }
    }

    /// Updates the profile record in every known board. Item records are left
    /// untouched: their `addedBy` references continue pointing at the same
    /// profile IDs and resolve to the new display name automatically.
    func updateCurrentUserName(
        firstName: String,
        lastName: String
    ) async -> ProfileNameUpdateResult {
        let cleanedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedFirstName.isEmpty else {
            return .failed(message: "Enter a first name.")
        }

        do {
            try await requireNetwork()
            let userRecordName = (try await service.accountUserRecordID()).recordName
            var updatedBoardCount = 0
            var failedBoardTitles: [String] = []

            for candidate in spaces {
                let candidateService = makeService(candidate)
                do {
                    let loaded = try await candidateService.loadEverything()
                    guard var profile = profileForCurrentAccount(
                        in: loaded.profiles,
                        space: candidate,
                        userRecordName: userRecordName
                    ) else {
                        failedBoardTitles.append(candidate.title)
                        continue
                    }

                    profile.firstName = cleanedFirstName
                    profile.lastName = cleanedLastName
                    let savedRecord = try await candidateService.save(profile.toRecord())
                    let savedProfile = UserProfile(record: savedRecord) ?? profile
                    defaults.set(
                        savedProfile.id.recordName,
                        forKey: profileKey(for: candidate)
                    )
                    updatedBoardCount += 1

                    if candidate == space {
                        if let index = profiles.firstIndex(where: { $0.id == savedProfile.id }) {
                            profiles[index] = savedProfile
                        }
                        currentProfile = savedProfile
                        rememberProfileTemplate(savedProfile)
                    }
                } catch {
                    failedBoardTitles.append(candidate.title)
                }
            }

            if failedBoardTitles.isEmpty {
                return .updated(boardCount: updatedBoardCount)
            }
            if updatedBoardCount > 0 {
                return .partiallyUpdated(
                    updatedBoardCount: updatedBoardCount,
                    failedBoardTitles: failedBoardTitles
                )
            }
            return .failed(message: "Your name couldn’t be updated. Please try again.")
        } catch {
            return .failed(message: Self.message(for: error))
        }
    }

    func profileForCurrentAccount(
        in candidates: [UserProfile],
        space: Space,
        userRecordName: String
    ) -> UserProfile? {
        if let rememberedID = defaults.string(forKey: profileKey(for: space)),
           let remembered = candidates.first(where: { $0.id.recordName == rememberedID }) {
            return remembered
        }
        return candidates.first {
            Self.profileBelongsToCurrentAccount(
                $0,
                in: space,
                userRecordName: userRecordName
            )
        }
    }

    @discardableResult
    func createProfile(firstName: String, lastName: String) async -> Bool {
        errorMessage = nil
        let requestedSpace = space
        let requestedService = service
        let profile = UserProfile(
            id: requestedService.newRecordID(),
            firstName: firstName,
            lastName: lastName
        )
        do {
            try await requireNetwork()
            let savedRecord = try await requestedService.save(profile.toRecord())
            let savedProfile = UserProfile(record: savedRecord) ?? profile
            guard space == requestedSpace else { return true }
            defaults.set(profile.id.recordName, forKey: profileKey)
            currentProfile = savedProfile
            rememberProfileTemplate(savedProfile)
            if let index = profiles.firstIndex(where: { $0.id == savedProfile.id }) {
                profiles[index] = savedProfile
            } else {
                profiles.append(savedProfile)
            }
            _ = await refresh()
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }
}
