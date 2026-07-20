# Docket — Implementation

_Current as of 2026-07-20._

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
- MapKit place search and structured addresses for Restaurants and Bars.
- Optional pinned map snapshots on place cards, alongside the existing photo
  and paper-only card treatments.
- TMDB movie lookup that fills titles, release years, runtimes, and posters.
- Add, inline detail editing, detail-toolbar and long-press deletion with a
  standard destructive confirmation alert, conflict detection, and
  attribution.
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

On a fresh device, the welcome screen can rebuild that local catalog from
CloudKit. `CloudKitService.discoverSpaces()` enumerates Docket zones in both the
private and shared databases. `BoardStore.restoreFromICloud()` admits only zones
containing a `UserProfile` whose CloudKit `creatorUserRecordID` matches the
currently signed-in account, then restores each per-board profile pointer
without creating duplicate records. Owned private-database profiles also match
CloudKit's `CKCurrentUserDefaultName` owner alias; joined boards intentionally
require the explicit account record ID so the zone owner's profile cannot be
mistaken for the current participant.

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

Share acceptance uses a custom `UIWindowSceneDelegate`, configured by
`AppDelegate`, because scene-based SwiftUI apps receive CloudKit invitation
metadata at the scene rather than the legacy application callback. The scene
delegate handles both an already-running scene and cold-launch metadata from
`UIScene.ConnectionOptions`. `CloudKitShareAcceptanceRouter` runs
`CKAcceptSharesOperation` and buffers its result until `BoardStore` installs a
handler, preventing a cold-launch invitation from being dropped. Once CloudKit
accepts the membership, Docket presents a board invitation sheet with the board
title and owner's display name when available. Join Board provisions the
current user's existing profile in that board and switches to it; Not Now keeps
the accepted board in the switcher without changing the current selection. The
first shared-zone load retries briefly because CloudKit can finish acceptance
before the shared zone is fully visible.
`CKSharingSupported` is declared in the real `Docket/Info.plist`; using an
`INFOPLIST_KEY_` build setting for this key does not survive into the bundle.

## Data and sync architecture

### Models

`Models/SharedListItem.swift` defines the common board surface. Restaurant,
Bar, and Movie are separate CloudKit record types with their own fields rather
than variants of one generic record.

Every item stores `addedBy` as a `CKRecord.Reference` to a `UserProfile` in the
same shared zone. Profiles are first-class records and the current device's
profile identity is remembered per board. A decoded profile also retains its
CloudKit creator identity so the same iCloud user can reclaim it on another
device without adding an app-specific account field.

Decoded models archive CloudKit system fields. Edits rebuild records from that
archive so change tags survive round-trips and concurrent writes produce a real
`serverRecordChanged` conflict instead of silently overwriting newer data.

`Support/ItemDraft.swift` is the shared, tested conversion path for both new
items and inline edits.

Restaurants and Bars store an optional `ItemLocation` rather than freeform
location text. A location retains the MapKit place name and identifier,
formatted address variants, city/region metadata, and a CloudKit-native
coordinate. The add and edit flows resolve place-name or address searches with
`MKLocalSearch`. No device-location permission is needed because Docket does
not request the user's current position.

Place cards can show a generated `MKMapSnapshotter` image centered on the saved
coordinate with a visible pin. Snapshots are cached in memory and are not
uploaded to CloudKit. Photo, map, and paper-only are mutually exclusive board
card treatments; selecting one never deletes an uploaded photo or location.
Place detail screens also show an interactive pinned map between the hero and
particulars, with pan/zoom gestures, a saved-place recenter control, and an
Apple Maps handoff. Detail addresses include city, state/region, and postal
code, omitting the country only for US locations.

Movie records can also retain a TMDB movie ID. While adding or editing a movie,
the user can search TMDB, select a result, and fill its title, release year,
runtime, and poster. Poster bytes are prepared through the existing photo path
and saved as the movie's CloudKit asset, so collaborators do not need to call
TMDB to see the chosen art. Existing manually entered movie fields remain fully
editable, and older movie records safely decode without a TMDB ID.

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

`BoardStore` is a dependency-injected, `@MainActor`, `@Observable` façade. Its
core file owns observable state plus lifecycle and refresh orchestration; its
domain behavior is split across focused files under `Docket/Store`:

- `BoardStore+Profiles` handles iCloud identity recovery, profile creation,
  profile stats, and cross-board name changes.
- `BoardStore+Items` handles item identity, saving, deletion, attribution, and
  debug-only sample data.
- `BoardStore+Management` handles sharing, board summaries, creation,
  deletion, and leaving shared boards.
- `BoardStore+Switching` handles atomic board changes, accepted invitations,
  profile provisioning, and notification deep links.
- `BoardStore+Notifications` handles remote-change reconciliation, local
  fingerprints, notification copy, and destination metadata.
- `BoardStoreTypes` contains the store's value types and operation results.

Together, the façade and its focused domains own:

- The selected space and complete space catalog.
- Loaded items, profiles, and the current per-space profile.
- Loading, switching, sharing, error, and refresh-result state.
- Profile creation, cross-board profile updates/stats, and item save/delete
  workflows.
- Board creation and atomic board switching.
- Remote change reconciliation and notification decisions.

Profile name edits save the matching `UserProfile` in every known board. Item
records are deliberately not rewritten: their existing `addedBy` references
continue to resolve through the same profile record IDs, so the new display
name propagates to every attributed item and arrives on other devices through
the existing silent database-change reconciliation. Partial multi-board saves
retain successful updates and identify the boards that should be retried.

Profile stats are calculated on demand across the local board catalog. Counts
include only items whose `addedBy` reference matches the current user's profile
for that board, and expose total pins, status counts, favorite category, and a
per-board contribution breakdown. An unavailable board produces partial stats
rather than discarding the boards that loaded successfully.

Refresh generations prevent older requests from publishing into a newly
selected board. Board switches keep the board screen mounted while loading; a
failed switch restores the complete previous board state and selected-space
persistence.

### Notifications

`CloudKitBoardNotificationService` installs silent database subscriptions for
the private and shared databases. A push is treated as a change hint, not as
the data itself: `BoardStore` reloads matching spaces and compares persisted
record IDs.

Per-board item fingerprints distinguish additions from edits. Single-item
notifications use contextual copy (board, author/category for new pins, and
the updated title for edits) and carry both the board and record identity.
Tapping one survives cold launch, switches to the relevant board, refreshes it,
and opens the exact item. Batched activity routes to the board rather than
guessing which item the user intended to inspect.

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
- Tapping the board title opens `BoardManagerView`, a full board-management
  sheet with current/ownership state, pin counts, participant profile names,
  switching, creation, native CloudKit People controls, and owner-only board
  deletion. Deleting an owned board removes its complete CloudKit zone only
  after a valid fallback board is selected; joined boards leave through
  CloudKit's participant UI and then prune the local membership.
- The bottom Settings control
  opens app preferences, including a persisted Darker Theme toggle. This is a
  Docket-specific palette that darkens board cards, quick looks, detail cards,
  and editing surfaces without changing the system light/dark appearance.
- Settings includes TMDB's required logo, link, and API attribution notice.
- `BoardFilterHeader` is a stable one-line pinned surface. Its main area opens
  the editor, reads “No Filters” when inactive or “Filters (N)” when active,
  and keeps a separate brass `CLEAR` action on the trailing edge.
- `BoardFilterSheet` is the scalable multi-select editor. Category tiles use
  an adaptive grid, status choices are independent, Cancel discards, and both
  the explicit apply action and interactive sheet dismissal commit changes.
- `BoardSwitcher` is the compact title-bar entry point into board management.
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
- Restaurant and Bar location rows open a MapKit-backed search sheet. Choosing
  the first location defaults a card without a photo to the map treatment; the
  On the Board selector can switch between map, photo, and no image. Saved
  fields prefer the compact street address because the title already identifies
  the venue.
- `ItemDetailView` resolves a record ID against live store data so edits update
  the visible detail without replacing the navigation destination. Context-menu
  Edit navigates here with edit mode already active; the legacy form sheet has
  been removed. Its bottom toolbar includes a trash action outside edit mode;
  deletion requires a standard system alert, dismisses the detail after the
  shared record is removed, and keeps the screen open with user-facing feedback
  if CloudKit fails.
- Saves replace the Save label with progress, dismiss keyboard focus, prevent
  interactive dismissal while in flight, and retain inline failure feedback.
- Stable item IDs plus asymmetric transitions animate filtered/deleted cards
  out, visible/new cards in, and remaining cards into new masonry positions.
  A newly created card is revealed after its add sheet finishes dismissing.
  Successful long-press deletion shows a transient `Deleted <title>` board
  notice only after CloudKit confirms removal.
- Board toolbar actions use their native single-layer glass containers. Add is
  the sole brass-prominent action, while the board switcher remains text-only.
  Bottom toolbar sheets retain matched transitions.
- The checked-in asset catalog includes Docket's full-color 1024×1024 app icon
  as an opaque RGB PNG. Xcode derives the required device sizes from that single
  universal source.

All reusable visual constants belong under `Views/Theme/`:

- `DocketTheme.swift`: board palette, cards, filters, skeletons, refresh pill,
  item motion, switcher, creation flow, and other board tokens.
- `DocketDetailTheme.swift`: detail and inline-edit presentation.
- `DocketControlStyles.swift`: shared control/button styles.

## Reliability behavior

- Initial CloudKit failure cannot masquerade as first-time onboarding.
- iCloud restoration never creates or edits records; a no-match account stays
  in onboarding and can create a genuinely new profile.
- Fresh-device restoration rebuilds owned and joined board memberships and
  persists the matching profile pointer for every recovered board.
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

## TMDB configuration

`Docket/Config/Base.xcconfig` is the checked-in target configuration and
optionally includes `Secrets.xcconfig`. Copy `Secrets.xcconfig.example` to that
ignored filename and set `TMDB_API_KEY` to the v3 API Key from TMDB. The build
expands it into the app's generated Info.plist. The key is intentionally absent
from source control; like any key shipped in a client app, it should not be
treated as a server-side secret.

## Tests and verification

The root `Justfile` is the canonical command interface. Install its runner with
`brew install just`, then use `just` to list recipes. The common workflows are
`just build`, `just test`, `just test-one <Class[/method]>`, `just format`,
`just format-check`, and `just verify`. Tests default to an iPhone 17 Pro on the
latest installed simulator runtime. Override that with `DOCKET_SIMULATOR` and
`DOCKET_SIMULATOR_OS`; `DOCKET_DERIVED_DATA` controls the `/tmp` build location.

The repository currently contains **114 unit tests**:

- `BoardStoreTests`: 59
- `ModelConversionTests`: 11
- `DocketThemeTests`: 7
- `BoardFilterTests`: 11
- `SpaceTests`: 4
- `ItemDraftTests`: 6
- `RecordDecoderTests`: 3
- `UserFacingErrorTests`: 3
- `CloudKitFetchAccumulatorTests`: 2
- `SampleDataTests`: 2
- `TMDBServiceTests`: 3
- `ShareAcceptanceRouterTests`: 3

Coverage includes model/system-field round-trips, conflict behavior, profile
identity, multi-board persistence and switching, board-creation rollback,
remote-add notification decisions, offline refresh/switch handling, error-copy
sanitization, multi-select OR/AND filter behavior, selection counts and clearing,
skeleton timing, refresh counts, and sample-data safety.

The signed simulator build and complete unit-test target pass on the configured
iPhone 17 Pro simulator. The Justfile's focused-test workflow has also been
exercised end to end.

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
   the standard destructive alert from the detail toolbar, and card
   insertion/removal animation.
8. Enable airplane mode. Refresh should finish promptly, board switching should
   return to the previous board, and no technical CloudKit text should appear.

## Remaining work

- Add HappyHour, Recipe, Landmark, Hike, and Activity
  models/forms/detail views.
- Add profile-picture `CKAsset` support.
- Add first-class board renaming and reconcile local catalogs after a
  participant leaves or an owner stops sharing.
- Continue real-device testing for CloudKit sharing, push delivery, revoked
  access, notification permissions, and poor-network edge cases.
- Prepare production CloudKit schema/deployment and TestFlight release work
  when the feature set is ready.

## Decisions to preserve

- Keep raw CloudKit; do not introduce a second auth system or backend casually.
- Keep one custom zone per board and one zone-wide share per zone.
- Keep category records typed rather than collapsing them into a generic item.
- Until a compatibility requirement is introduced, prefer direct schema and
  model changes over migration layers for unreleased data shapes.
- Keep CloudKit system fields on decoded models for safe edits.
- Keep data services injectable and store behavior testable without iCloud.
- Keep presentation constants in `Views/Theme/` and screen views compositional.
- Preserve unrelated workspace changes and do not add tool/author attribution.
