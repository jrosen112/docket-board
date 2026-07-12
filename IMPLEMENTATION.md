# Docket — Implementation Progress

Living status doc so any session can pick up where the last left off. See
[CLAUDE.md](CLAUDE.md) for the product spec and hard constraints.

_Last updated: 2026-07-12_

## Guiding principle
Build the **data/CloudKit engine correctly first**; the SwiftUI UI is a thin,
swappable layer on top. Don't bake presentation decisions into the data layer.

## Kickoff decisions (2026-07-12)
- **Identity:** first-class, extensible `UserProfile` record (firstName,
  lastName, profile picture later; room for interests/favorites). Every item's
  `addedBy` is a `CKRecord.Reference` to a profile. Profiles live in the shared
  zone so both participants see each other's.
- **Category scope:** start with a **subset — Restaurant, Bar, Movie** — to
  prove the protocol + board + form pattern (2 location-based + 1 text-only).
  HappyHour / Landmark / Hike / Activity come after.
- **Location:** plain text field for now; MKLocalSearch autocomplete +
  coordinates later.
- **Board card sizing / photos / "show detail on board" toggle:** future work,
  layered on once the data model is solid.
- **Project facts:** iOS 26.4 deployment target, bundle `jared.rosen.Docket`,
  CloudKit container `iCloud.jaredrosen.docket`, Xcode file-system-synchronized
  groups (drop `.swift` files in the folder → auto-added to target, no pbxproj
  editing).

## Build order (from CLAUDE.md) & status
1. **CloudKit container/zone/share setup** — ✅ owner zone + share send + invitee acceptance (owner/participant scopes)
2. **CKRecord conversion per category** — ✅ done (models + round-trip tests)
3. **Masonry board view w/ filtering** — 🟡 plain list board wired; masonry + filters pending
4. **Add/edit form** — ✅ done (`ItemFormView`: add + tap-to-edit)
5. **Category detail views** — 🔲 not started
6. **Map view for location categories** — 🔲 not started
7. **Push sync + photo attachments + polish** — 🔲 not started

## Done so far
- **Model layer** (`Docket/Docket/Models/`) — `SharedListItem` protocol +
  `ItemStatus`/`ItemCategory` enums + shared encode/decode helpers; `UserProfile`;
  `Restaurant`/`Bar`/`Movie` with round-trip CKRecord conversion. All marked
  `nonisolated` so the background service actor can build them (project uses
  Xcode 26 default-MainActor isolation). Every decoded model carries a
  `systemFields: Data?` archive (`CKRecord+SystemFields.swift`) so edits keep
  the server change tag — saving a from-scratch CKRecord over an existing one
  fails with `serverRecordChanged`, and the change tag also gives real
  conflict detection between the two participants.
- **CloudKit schema constants** (`CloudKit/CloudKitSchema.swift`) — namespaced
  `Schema.RecordType` / `Schema.Field` / `Schema.zoneName` to dodge both the
  case-sensitivity duplicate-field trap and CloudKit's own `CKRecord.RecordType`
  / `CKRecord.FieldKey` names.
- **Space model** (`CloudKit/Space.swift`) — a board = `Space(zoneID, access)`
  where access is `.owned` (private DB) or `.joined` (shared DB). This is the
  multi-board foundation: girlfriend board / brother board / a friend's board
  you joined are all just distinct Spaces; Phase 1 persists one current Space
  (`SpaceStore`), multi-board later = a list + selection. Per-space local state
  is keyed by `Space.id`.
- **SpaceDataService protocol** (`CloudKit/SpaceDataService.swift`) — the seam
  between BoardStore and CloudKit; tests substitute `MockSpaceService`.
- **RecordDecoder** (`CloudKit/RecordDecoder.swift`) — record→model dispatch +
  item/profile partition, extracted from the service and unit-tested.
- **CloudKitService** (`CloudKit/CloudKitService.swift`) — `actor` implementing
  `SpaceDataService` for one Space. `ensureZone`, `save`, `delete`,
  `loadEverything` (via `CKFetchRecordZoneChangesOperation` — no schema indexes
  needed), `createZoneShare`. Share creation returns the EXISTING zone-wide
  share when one exists (CloudKit allows exactly one per zone; re-creating
  throws a server error).
- **Sharing acceptance** — `Info.plist` (partial, merged) sets
  `CKSharingSupported=<true/>`; `AppDelegate` receives
  `userDidAcceptCloudKitShareWith`, runs `CKAcceptSharesOperation`, and posts a
  notification; `DocketApp` routes it to `BoardStore.switchToParticipant`, which
  persists the participant scope and reloads. Share button hidden for participants.
- **BoardStore** (`BoardStore.swift`) — `@MainActor @Observable`; holds items /
  profiles / currentProfile; bootstrap, refresh, createProfile, add, delete,
  prepareShare, `switchTo(space:)`. Service factory + UserDefaults are injected
  (real-CloudKit defaults) so all store behavior is unit-tested. "Who am I" is
  stored per-space (`docket.currentProfileRecordName.<space.id>`), with a
  one-time migration from the old global key; joining another board never wipes
  the owned board's identity.
- **UI** (`Views/`, plain styling on purpose) — `ContentView` gate
  (loading → profile setup → board), `ProfileSetupView`, `BoardView` (list +
  add/share toolbar + pull-to-refresh + swipe-delete + tap-to-edit),
  `ItemFormView` (add: category picker → category fields; edit: pre-filled,
  category fixed, preserves record identity), `CloudSharingSheet`
  (UICloudSharingController bridge).
- **Tests** — 27 offline tests, all passing: `ModelConversionTests` (8, incl.
  system-fields/edit round-trips), `RecordDecoderTests` (3), `SpaceTests` (3),
  `BoardStoreTests` (12, via `MockSpaceService` — loading, sorting, error
  surfacing, profile identity + legacy-key migration, add/edit/delete, space
  switching). Full app builds clean for the iOS 26 simulator with no warnings.

## Next up
- [ ] Masonry/corkboard styling + category color accents + status/category filters.
- [ ] Then step 5+ (detail views, map, push sync, photos).

Notes for later:
- `INFOPLIST_KEY_CKSharingSupported=YES` build setting is **silently dropped**
  (Xcode only honors `INFOPLIST_KEY_` for known keys) — that's why there's a real
  `Docket/Info.plist`. Verified in the generated bundle plist.
- Participant onboarding: accepting a share switches the current Space to the
  joined board and the invitee onboards fresh there. Any profile on their own
  owned board is preserved (per-space keys) for when multi-board switching
  arrives.
- Multi-board later: persist a `[Space]` list + current selection in
  `SpaceStore`, add a board switcher UI. Engine already takes a `Space` per
  service instance, so no data-layer rework is expected.

## Verification notes
- **Do not run the app** (CLAUDE.md working agreement) — build + tests only; Jared
  runs it in Xcode.
- Model conversion is covered by offline unit tests (no iCloud account needed).
- **Manual smoke test (owner, solo) — run in Xcode on a device/sim signed into
  iCloud:**
  1. Launch → profile setup appears → enter a name → Get started.
  2. Board shows empty state → tap **+** → add a Restaurant/Bar/Movie → it
     appears in the list, attributed to your name.
  3. Force-quit and relaunch → profile is remembered, item still there (proves
     the CloudKit round-trip, not just local state).
  4. Swipe-delete an item → it's gone after a refresh.
  5. Tap an item → edit form pre-filled (no category picker) → change the title
     and status → Save → row updates; force-quit + relaunch → edit persisted.
     This exercises the change-tag path (real CloudKit rejects tag-less
     updates, which the mock can't simulate — worth checking on-device).
  - If any CloudKit call errors, the message surfaces on-screen (profile screen)
    or is stored in `store.errorMessage`. Tell me the exact text.
- **Sharing smoke test (needs two iCloud accounts + two real devices — CloudKit
  sharing does not work in the simulator):**
  1. On device A (owner), add a couple items, then tap the **+person** button →
     native share sheet appears → send the invite (Messages to yourself/other
     account is fine).
  2. On device B (second iCloud account), tap the invite link → app launches →
     it should switch to participant mode and show device A's items.
  3. On device B, add an item; on device A pull-to-refresh → it appears (and
     vice-versa). This is the core "sync works between two accounts" check.
  4. Confirm device B has **no** +person share button (participants can't invite).
  - Known limitation: the app currently only refreshes on launch / pull-to-refresh
    (no live push yet — that's step 7), so use pull-to-refresh to see the other
    person's changes.
