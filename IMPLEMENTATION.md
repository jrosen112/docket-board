# Docket — Implementation

_Current as of 2026-07-13._

This document describes the app as it exists now. [CLAUDE.md](CLAUDE.md)
contains the original product brief and working agreement; where its old
phase-oriented notes disagree with this file, this file is authoritative for
the current implementation.

## Current product

Docket is a SwiftUI iOS 26 app for shared boards of places and experiences.
It uses raw CloudKit—no custom account system, backend server, Core Data, or
SwiftData.

The current app supports:

- Creating multiple named boards, each backed by its own CloudKit record zone.
- Inviting people to an owned board with Apple's native CloudKit sharing UI.
- Joining, switching between, and leaving shared boards.
- Owner-only membership management; participants collaborate on board content.
- Restaurant, Bar, and Movie items with category-specific fields.
- Add, inline detail editing, deletion, conflict detection, and attribution.
- Category/status filtering over a two-column masonry board.
- Silent CloudKit change notifications and local notifications for items added
  by another participant.
- Pull-to-refresh feedback showing the number of newly added items.
- Offline detection, bounded CloudKit reads, and short user-facing errors.

## CloudKit and board architecture

### Container and databases

The app uses container `iCloud.jaredrosen.docket`. The identifier belongs to
the app; it does not mean data is routed through one person's iCloud account.
Each iCloud user has their own private database.

An owned board's custom zone lives in its creator's private database. Once the
zone is shared, invited participants access that same zone through their shared
database.

### Spaces and persistence

`CloudKit/Space.swift` models one board membership:

- `zoneID`: the board's unique custom record zone.
- `access`: `.owned` or `.joined`.
- `title`: the local board-switcher title.

`Space.newOwned(title:)` generates a distinct zone for every new board.
`SpaceStore` persists the full board catalog and selected board, deduplicates
memberships by stable space ID, and migrates the original single-space keys.

Local state that belongs to one board is keyed by `Space.id`, including the
current profile record and remembered item IDs. Switching boards never destroys
another board's local identity.

### Sharing and roles

Each zone has at most one zone-wide `CKShare`. `CloudKitService.loadShare()`
loads the existing share or creates it for an unshared owned board.

`UICloudSharingController` supplies the membership UI:

- Owners can invite/remove people, change sharing settings, or stop sharing.
- Participants can inspect the people list or leave the share.

Shares are private and read/write. CloudKit exposes read-only and read/write
participant permissions, but no secure add-only role. Membership management is
owner-only; read/write participants can add, edit, and delete board content.

Share acceptance is handled by `AppDelegate`, which runs
`CKAcceptSharesOperation` and routes the accepted zone into `BoardStore`.
`CKSharingSupported` is declared in the real `Docket/Info.plist`; using an
`INFOPLIST_KEY_` build setting for this key does not survive into the bundle.

## Data and sync architecture

### Models

`Models/SharedListItem.swift` defines the common board surface. Restaurant,
Bar, and Movie are separate CloudKit record types with their own fields rather
than variants of one generic record.

Every item stores `addedBy` as a `CKRecord.Reference` to a `UserProfile` in the
same shared zone. Profiles are first-class records and the current device's
profile identity is remembered per board.

Decoded models archive CloudKit system fields. Edits rebuild records from that
archive so change tags survive round-trips and concurrent writes produce a real
`serverRecordChanged` conflict instead of silently overwriting newer data.

`Support/ItemDraft.swift` is the shared, tested conversion path for both new
items and inline edits.

### Service layer

`SpaceDataService` is the test seam for board-scoped data access.
`CloudKitService` is an actor bound to one `Space` and selects the private or
shared database from that space's access mode.

Reads use `CKFetchRecordZoneChangesOperation`, avoiding query-index setup and
capturing record-level and zone-level failures. Fetches have request/resource
timeouts so a lost connection cannot leave refresh UI running indefinitely.

`RecordDecoder` owns record dispatch and partitions fetched records into items
and profiles. `CloudKitFetchAccumulator` safely collects operation callbacks
that may arrive on different queues.

### BoardStore

`BoardStore` is `@MainActor`, `@Observable`, and dependency-injected. It owns:

- The selected space and complete space catalog.
- Loaded items, profiles, and the current per-space profile.
- Loading, switching, sharing, error, and refresh-result state.
- Profile creation and item save/delete workflows.
- Board creation and atomic board switching.
- Remote change reconciliation and notification decisions.

Refresh generations prevent older requests from publishing into a newly
selected board. Board switches keep the board screen mounted while loading; a
failed switch restores the complete previous board state and selected-space
persistence.

### Notifications

`CloudKitBoardNotificationService` installs silent database subscriptions for
the private and shared databases. A push is treated as a change hint, not as
the data itself: `BoardStore` reloads matching spaces and compares persisted
record IDs.

Only newly discovered items added by a different local profile produce a local
notification. Tapping that notification routes the app to the relevant board.

### Connectivity and errors

`SystemNetworkAvailability` wraps `NWPathMonitor`. User actions preflight known
offline state before beginning CloudKit work. If the monitor has not published
its first path yet, the app allows CloudKit to try rather than falsely blocking
an online launch.

`UserFacingError` is the only CloudKit/network error-to-copy translator. Raw
CloudKit descriptions are never intentionally shown in the board UI. It maps
offline, iCloud availability, authentication, quota, permission, and missing
board errors to concise messages.

## UI architecture

Screens compose small components; CloudKit and conversion logic stay out of
views.

- `ContentView` handles initial loading, retry, profile setup, and entry into
  the persistent board screen.
- `BoardView` composes the board background, pinned filters, masonry cards,
  native navigation/toolbars, sheets, navigation, and transient overlays.
- `BoardSwitcher` selects any owned or joined board and starts board creation.
- `CreateBoardView` creates a named board using the same visual language as the
  detail editors.
- `BoardSkeletonView` replaces only the card area during board switches. The
  navigation bar, filters, background, and bottom toolbar remain mounted.
- `BoardRefreshPill` reports “No new items,” “1 item added,” or a plural count,
  auto-dismisses, and tracks a downward swipe for early dismissal.
- `DetailViews/` contains the typed Restaurant, Bar, and Movie detail screens,
  the new-item screen, and their shared inline-editing components.
- `ItemDetailView` resolves a record ID against live store data so edits update
  the visible detail without replacing the navigation destination.
- The bottom toolbars use native iOS glass styling and matched transitions.

All reusable visual constants belong under `Views/Theme/`:

- `DocketTheme.swift`: board palette, cards, filters, skeletons, refresh pill,
  switcher, creation flow, and other board tokens.
- `DocketDetailTheme.swift`: detail and inline-edit presentation.
- `DocketControlStyles.swift`: shared control/button styles.

## Reliability behavior

- Initial CloudKit failure cannot masquerade as first-time onboarding.
- Saving a new profile persists its local identity only after CloudKit succeeds.
- Failed item saves keep editing UI open.
- Concurrent edits show a specific reload-and-retry message.
- Pull-to-refresh returns an exact new-record count only after a successful read.
- Airplane-mode refresh ends promptly with a short offline message.
- Airplane-mode board switching restores the previous board.
- CloudKit fetches are bounded if connectivity disappears after preflight.
- Unsupported or unexpected CloudKit errors fall back to generic user copy,
  never a raw `CKError` dump.

## Debug support

`Support/SampleData.swift` and the debug toolbar menu can seed a varied board
covering every currently supported category and status. Sample records use a
`sample-` record-name prefix, and deletion targets only that prefix. Debug
seeding is compiled out of release/TestFlight builds.

## Tests and verification

The signed iPhone 17 Pro simulator suite currently has **67 passing tests**:

- `BoardStoreTests`: 30
- `ModelConversionTests`: 8
- `DocketThemeTests`: 7
- `BoardFilterTests`: 5
- `SpaceTests`: 4
- `ItemDraftTests`: 3
- `RecordDecoderTests`: 3
- `UserFacingErrorTests`: 3
- `CloudKitFetchAccumulatorTests`: 2
- `SampleDataTests`: 2

Coverage includes model/system-field round-trips, conflict behavior, profile
identity, multi-board persistence and switching, board-creation rollback,
remote-add notification decisions, offline refresh/switch handling, error-copy
sanitization, filters, skeleton timing, refresh counts, and sample-data safety.

Build and test commands are allowed, but automated sessions should not launch
the app. Live CloudKit sharing and notification behavior require Jared's manual
testing on signed-in devices, ideally with two iCloud accounts.

Important manual checks:

1. Create two owned boards and switch repeatedly; board chrome should remain
   fixed while skeleton cards crossfade into content.
2. Invite a second iCloud account. Confirm both devices can add/edit content,
   only the owner manages membership, and the participant can leave.
3. Add an item on device B. Confirm device A receives a notification and that
   tapping it selects the correct board.
4. Pull to refresh and verify the new-item pill count, auto-dismissal, and
   swipe-down dismissal.
5. Enable airplane mode. Refresh should finish promptly, board switching should
   return to the previous board, and no technical CloudKit text should appear.

## Remaining work

- Implement MapKit search/autocomplete, coordinates, and a map view for
  location-based categories.
- Add HappyHour, Landmark, Hike, and Activity models/forms/detail views.
- Add item photos and profile-picture `CKAsset` support.
- Add first-class board rename/delete management and reconcile local catalogs
  after a participant leaves or an owner stops sharing.
- Continue real-device testing for CloudKit sharing, push delivery, revoked
  access, notification permissions, and poor-network edge cases.
- Prepare production CloudKit schema/deployment and TestFlight release work
  when the feature set is ready.

## Decisions to preserve

- Keep raw CloudKit; do not introduce a second auth system or backend casually.
- Keep one custom zone per board and one zone-wide share per zone.
- Keep category records typed rather than collapsing them into a generic item.
- Keep CloudKit system fields on decoded models for safe edits.
- Keep data services injectable and store behavior testable without iCloud.
- Keep presentation constants in `Views/Theme/` and screen views compositional.
- Preserve unrelated workspace changes and do not add tool/author attribution.
