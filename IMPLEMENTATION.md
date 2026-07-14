# Docket — Implementation

_Current as of 2026-07-14._

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
- Multi-select category/status filtering over a two-column masonry board.
- Rich long-press quick looks with category facts, notes, attribution, and
  direct entry into the current detail editor.
- Visible save progress, reusable success/refresh notices, and animated board
  changes for filtering, additions, deletions, and refreshes.
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

`Support/BoardFilter.swift` stores selected categories and statuses as sets.
An empty set means “all” for that dimension. Selections are ORed within one
dimension and the two dimensions are ANDed together; for example,
`(Restaurant OR Bar) AND (Want to go OR Planned)`.

### Service layer

`SpaceDataService` is the test seam for board-scoped data access.
`CloudKitService` is an actor bound to one `Space` and selects the private or
shared database from that space's access mode.

Reads use `CKFetchRecordZoneChangesOperation`, avoiding query-index setup.
Zone-level failures fail the load; record-level failures are skipped so one
bad record cannot take down the whole board. Fetches have request/resource
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
- The native toolbar search capsule occupies the center of the bottom bar,
  between the Settings and Add controls. It matches across card titles, notes,
  category/status labels, and category-specific card details. Search terms are
  ANDed together and compose with the existing category/status filters.
- Tapping Add keeps the fast Restaurant-first flow. Long-pressing it opens a
  native category menu for starting directly with Restaurant, Bar, or Movie.
- Board sharing lives in the top navigation bar. The bottom Settings control
  opens app preferences, including a persisted Darker Theme toggle. This is a
  Docket-specific palette that darkens board cards, quick looks, detail cards,
  and editing surfaces without changing the system light/dark appearance.
- `BoardFilterHeader` is a stable one-line pinned surface. Its main area opens
  the editor, reads “No Filters” when inactive or “Filters (N)” when active,
  and keeps a separate brass `CLEAR` action on the trailing edge.
- `BoardFilterSheet` is the scalable multi-select editor. Category tiles use
  an adaptive grid, status choices are independent, Cancel discards, and both
  the explicit apply action and interactive sheet dismissal commit changes.
- `BoardSwitcher` selects any owned or joined board and starts board creation.
- `CreateBoardView` creates a named board using the same visual language as the
  detail editors.
- `BoardSkeletonView` replaces only the card area during board switches. The
  navigation bar, filters, background, and bottom toolbar remain mounted.
- `BoardNoticePill` is the reusable transient board notice. It reports refresh
  results and successful additions, auto-dismisses, and tracks a downward swipe
  for early dismissal.
- `BoardItemQuickLookView` supplies a rich context-menu preview. Address-like
  fields receive full-width wrapping; compact facts share aligned columns.
- Board cards preserve their pin/shadow overflow in context-menu and matched
  transition captures without changing masonry spacing.
- `DetailViews/` contains the typed Restaurant, Bar, and Movie detail screens,
  the new-item screen, and their shared inline-editing components.
- `ItemDetailView` resolves a record ID against live store data so edits update
  the visible detail without replacing the navigation destination. Context-menu
  Edit navigates here with edit mode already active; the legacy form sheet has
  been removed.
- Saves replace the Save label with progress, dismiss keyboard focus, prevent
  interactive dismissal while in flight, and retain inline failure feedback.
- Stable item IDs plus asymmetric transitions animate filtered/deleted cards
  out, visible/new cards in, and remaining cards into new masonry positions.
  A newly created card is revealed after its add sheet finishes dismissing.
- Board toolbar actions use their native single-layer glass containers. Add is
  the sole brass-prominent action, while the board switcher remains text-only.
  Bottom toolbar sheets retain matched transitions.

All reusable visual constants belong under `Views/Theme/`:

- `DocketTheme.swift`: board palette, cards, filters, skeletons, refresh pill,
  item motion, switcher, creation flow, and other board tokens.
- `DocketDetailTheme.swift`: detail and inline-edit presentation.
- `DocketControlStyles.swift`: shared control/button styles.

## Reliability behavior

- Initial CloudKit failure cannot masquerade as first-time onboarding.
- Saving a new profile persists its local identity only after CloudKit succeeds.
- Failed item saves keep editing UI open.
- Saving presents immediate progress and prevents dismissal until the operation
  completes; a successful add produces a board notice after sheet dismissal.
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

The repository currently contains **72 unit tests**:

- `BoardStoreTests`: 31
- `ModelConversionTests`: 8
- `DocketThemeTests`: 7
- `BoardFilterTests`: 9
- `SpaceTests`: 4
- `ItemDraftTests`: 3
- `RecordDecoderTests`: 3
- `UserFacingErrorTests`: 3
- `CloudKitFetchAccumulatorTests`: 2
- `SampleDataTests`: 2

Coverage includes model/system-field round-trips, conflict behavior, profile
identity, multi-board persistence and switching, board-creation rollback,
remote-add notification decisions, offline refresh/switch handling, error-copy
sanitization, multi-select OR/AND filter behavior, selection counts and clearing,
skeleton timing, refresh counts, and sample-data safety.

A compile-only generic iOS build succeeded on 2026-07-14. The new filter tests
compile, but a focused XCTest execution could not install on the current Mac
because that device is absent from the iOS provisioning profile. Run the full
suite from the signed simulator configuration before treating all 72 as a new
passing baseline.

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
5. Select multiple categories and statuses. Verify the compact count, CLEAR,
   Cancel, explicit apply, swipe-to-apply, and card reflow animations.
6. Long-press a card. Verify the rich quick look, full address wrapping, and
   that Edit opens the current detail editor rather than a legacy form.
7. Add and delete items. Verify save progress, post-dismiss success feedback,
   and card insertion/removal animation.
8. Enable airplane mode. Refresh should finish promptly, board switching should
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
