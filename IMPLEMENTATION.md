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
1. **CloudKit container/zone/share setup** — 🟡 send path done; share *acceptance* pending
2. **CKRecord conversion per category** — ✅ done (models + round-trip tests)
3. **Masonry board view w/ filtering** — 🟡 plain list board wired; masonry + filters pending
4. **Add/edit form** — 🟡 add form done; edit pending
5. **Category detail views** — 🔲 not started
6. **Map view for location categories** — 🔲 not started
7. **Push sync + photo attachments + polish** — 🔲 not started

## Done so far
- **Model layer** (`Docket/Docket/Models/`) — `SharedListItem` protocol +
  `ItemStatus`/`ItemCategory` enums + shared encode/decode helpers; `UserProfile`;
  `Restaurant`/`Bar`/`Movie` with round-trip CKRecord conversion. All marked
  `nonisolated` so the background service actor can build them (project uses
  Xcode 26 default-MainActor isolation).
- **CloudKit schema constants** (`CloudKit/CloudKitSchema.swift`) — namespaced
  `Schema.RecordType` / `Schema.Field` / `Schema.zoneName` to dodge both the
  case-sensitivity duplicate-field trap and CloudKit's own `CKRecord.RecordType`
  / `CKRecord.FieldKey` names.
- **CloudKitService** (`CloudKit/CloudKitService.swift`) — `actor` owning the
  container + `SharedSpace` zone. `ensureZone`, `save`, `delete`,
  `loadEverything` (via `CKFetchRecordZoneChangesOperation` — no schema indexes
  needed), and `createZoneShare`. Currently targets the OWNER's private DB.
- **BoardStore** (`BoardStore.swift`) — `@MainActor @Observable`; holds items /
  profiles / currentProfile; bootstrap, refresh, createProfile, add, delete,
  prepareShare. Remembers "me" via UserDefaults record name.
- **UI** (`Views/`, plain styling on purpose) — `ContentView` gate
  (loading → profile setup → board), `ProfileSetupView`, `BoardView` (list +
  add/share toolbar + pull-to-refresh + swipe-delete), `AddItemView` (category
  picker → category fields), `CloudSharingSheet` (UICloudSharingController bridge).
- **Tests** — `ModelConversionTests` (6, offline, all passing). Full app builds
  clean for the iOS 26 simulator with no warnings.

## Next up
- [ ] **Share acceptance path** (the missing half of build-order step 1):
  - Add `CKSharingSupported = true` — needs a real **Info.plist file** with a
    `<true/>` boolean (the `INFOPLIST_KEY_CKSharingSupported=YES` build setting
    writes a *string*, which CloudKit reads as false — don't use it).
  - Handle the accepted share in the SwiftUI lifecycle (`userDidAcceptCloudKitShareWith`
    via an app-delegate adaptor or scene handling) and point the participant's
    reads/writes at `sharedCloudDatabase` + the owner's zone.
- [ ] Edit-item flow (reuse AddItemView).
- [ ] Masonry/corkboard styling + category color accents + status/category filters.
- [ ] Then step 5+ (detail views, map, push sync, photos).

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
  - If any CloudKit call errors, the message surfaces on-screen (profile screen)
    or is stored in `store.errorMessage`. Tell me the exact text.
- **Sharing** can't be fully tested until the acceptance path above is built, but
  the **+person toolbar button** should already create a zone share and present
  the native share sheet — worth confirming that much presents without crashing.
