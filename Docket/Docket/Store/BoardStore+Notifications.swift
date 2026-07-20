import CloudKit
import Foundation

extension BoardStore {
    /// Handles a silent CloudKit database notification. A push is only a hint
    /// that something changed, so each matching board is fetched and compared
    /// with its persisted item IDs. Only newly-created records belonging to a
    /// different profile become visible notifications.
    func handleRemoteDatabaseChange(scope: CKDatabase.Scope) async -> Bool {
        let matchingSpaces = spaces.filter { candidate in
            switch scope {
            case .private: candidate.isOwned
            case .shared: !candidate.isOwned
            default: false
            }
        }
        guard !matchingSpaces.isEmpty else { return false }

        var receivedData = false
        for candidate in matchingSpaces {
            do {
                let candidateService = makeService(candidate)
                let loaded = try await candidateService.loadEverything()
                let previousIDs = rememberedItemIDs(in: candidate)
                let previousVersions = rememberedItemVersions(in: candidate)
                remember(items: loaded.items, in: candidate)
                // A database push means the server observed a change. Even an
                // edit can leave the set of IDs untouched while still giving
                // us fresh data to publish.
                receivedData = true

                if let previousIDs {
                    let newItems = loaded.items.filter {
                        !previousIDs.contains($0.id.recordName)
                    }
                    let myProfileIDs: Set<CKRecord.ID>
                    if let userRecordName = try? await candidateService.accountUserRecordID().recordName {
                        myProfileIDs = Set(
                            profilesForCurrentAccount(
                                in: loaded.profiles,
                                space: candidate,
                                userRecordName: userRecordName
                            ).map(\.id)
                        )
                    } else if let rememberedID = defaults.string(
                        forKey: profileKey(for: candidate)
                    ) {
                        myProfileIDs = Set(
                            loaded.profiles
                                .filter { $0.id.recordName == rememberedID }
                                .map(\.id)
                        )
                    } else {
                        myProfileIDs = []
                    }
                    let additionsByOthers = newItems.filter {
                        !myProfileIDs.contains($0.addedBy.recordID)
                    }
                    let editedItems: [any SharedListItem]
                    if let previousVersions {
                        editedItems = loaded.items.filter { item in
                            guard previousIDs.contains(item.id.recordName),
                                  let previousVersion = previousVersions[item.id.recordName]
                            else { return false }
                            return previousVersion != itemVersion(item)
                        }
                    } else {
                        editedItems = []
                    }
                    if !additionsByOthers.isEmpty || !editedItems.isEmpty {
                        try? await notificationService.post(
                            notice(
                                additions: additionsByOthers,
                                edits: editedItems,
                                profiles: loaded.profiles,
                                in: candidate
                            )
                        )
                    }
                }

                if candidate == space {
                    publishRemoteLoad(loaded)
                    await repairCurrentProfileIdentityIfNeeded()
                }
            } catch {
                // A push-triggered fetch failing is invisible work the user
                // never asked for; don't surface a banner over valid data.
                // The data on screen simply stays as it was.
                continue
            }
        }
        return receivedData
    }

    private func publishRemoteLoad(
        _ loaded: (items: [any SharedListItem], profiles: [UserProfile])
    ) {
        // Supersede any in-flight refresh: it started before this push-driven
        // fetch, so letting it publish would overwrite newer data with older.
        refreshGeneration += 1
        items = loaded.items.sorted { $0.dateAdded > $1.dateAdded }
        profiles = loaded.profiles
        reconcileCurrentProfile()
        errorMessage = nil
        loadState = .loaded
    }

    private func notice(
        additions: [any SharedListItem],
        edits: [any SharedListItem],
        profiles: [UserProfile],
        in space: Space
    ) -> BoardChangeNotice {
        let title: String
        let body: String
        let destinationItem: (any SharedListItem)?

        if additions.count == 1, edits.isEmpty, let item = additions.first {
            let author = profiles.first {
                $0.id.recordName == item.addedBy.recordID.recordName
            }?.displayName
            title = "New on \(space.title)"
            if let author, !author.isEmpty {
                body = "\(author) pinned “\(item.title)” · \(item.category.label)"
            } else {
                body = "Someone pinned “\(item.title)” · \(item.category.label)"
            }
            destinationItem = item
        } else if edits.count == 1, additions.isEmpty, let item = edits.first {
            title = "Updated on \(space.title)"
            body = "“\(item.title)” has new details."
            destinationItem = item
        } else if edits.isEmpty {
            title = "\(additions.count) new pins on \(space.title)"
            body = "Fresh ideas are waiting on your board."
            destinationItem = nil
        } else if additions.isEmpty {
            title = "\(edits.count) updates on \(space.title)"
            body = "Recent pins changed. Tap to catch up."
            destinationItem = nil
        } else {
            title = "New activity on \(space.title)"
            let additionText = additions.count == 1
                ? "1 new pin"
                : "\(additions.count) new pins"
            let editText = edits.count == 1
                ? "1 update"
                : "\(edits.count) updates"
            body = "\(additionText) and \(editText)."
            destinationItem = nil
        }
        return BoardChangeNotice(
            boardID: space.id,
            itemRecordName: destinationItem?.id.recordName,
            title: title,
            body: body
        )
    }

    private func rememberedItemIDs(in space: Space) -> Set<String>? {
        let key = rememberedItemsKey(for: space)
        guard defaults.object(forKey: key) != nil else { return nil }
        return Set(defaults.stringArray(forKey: key) ?? [])
    }

    func remember(items: [any SharedListItem], in space: Space) {
        remember(itemIDs: Set(items.map { $0.id.recordName }), in: space)
        defaults.set(
            Dictionary(uniqueKeysWithValues: items.map {
                ($0.id.recordName, itemVersion($0))
            }),
            forKey: rememberedItemVersionsKey(for: space)
        )
    }

    private func remember(itemIDs: Set<String>, in space: Space) {
        defaults.set(itemIDs.sorted(), forKey: rememberedItemsKey(for: space))
    }

    func rememberedItemsKey(for space: Space) -> String {
        "docket.knownItemRecordNames.\(space.id)"
    }

    private func rememberedItemVersions(in space: Space) -> [String: String]? {
        defaults.dictionary(forKey: rememberedItemVersionsKey(for: space)) as? [String: String]
    }

    func rememberedItemVersionsKey(for space: Space) -> String {
        "docket.knownItemVersions.\(space.id)"
    }

    /// CloudKit change tags are the authoritative remote version. Unit-test
    /// records and never-fetched local models do not have one, so a stable
    /// content fingerprint keeps the same behavior testable and deterministic.
    private func itemVersion(_ item: any SharedListItem) -> String {
        if let changeTag = item.toRecord().recordChangeTag {
            return "cloud:\(changeTag)"
        }

        var fields = [
            item.category.rawValue,
            item.title,
            item.notes ?? "",
            item.status.rawValue,
            item.showsPhotoOnBoard ? "1" : "0",
            item.addedBy.recordID.recordName,
            String(item.dateAdded.timeIntervalSinceReferenceDate)
        ]
        switch item {
        case let restaurant as Restaurant:
            fields += [
                locationFingerprint(restaurant.location),
                restaurant.showsMapOnBoard ? "1" : "0",
                restaurant.cuisine ?? "",
                restaurant.priceRange?.rawValue ?? ""
            ]
        case let bar as Bar:
            fields += [
                locationFingerprint(bar.location),
                bar.showsMapOnBoard ? "1" : "0",
                bar.barType?.rawValue ?? ""
            ]
        case let movie as Movie:
            fields += [
                movie.runtimeMinutes.map(String.init) ?? "",
                movie.streamingService ?? "",
                movie.releaseYear.map(String.init) ?? "",
                movie.tmdbID.map(String.init) ?? ""
            ]
        default:
            break
        }

        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in fields.joined(separator: "\u{1F}").utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        for byte in item.photoData ?? Data() {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    private func locationFingerprint(_ location: ItemLocation?) -> String {
        guard let location else { return "" }
        return [
            location.name,
            location.fullAddress,
            location.shortAddress ?? "",
            location.city ?? "",
            location.cityWithContext ?? "",
            location.country ?? "",
            location.countryCode ?? "",
            String(location.latitude),
            String(location.longitude),
            location.mapItemIdentifier ?? "",
        ].joined(separator: "\u{1E}")
    }
}
