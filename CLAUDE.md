# Docket

A shared iOS app for two people to collaboratively track places and experiences they want to do together: bars, restaurants, happy hours, landmarks, movies, hikes/walks, and general activities. Replaces a shared Apple Notes note with something structured and visual.

**Phase 1 goal**: build this for personal use between two people (me and my girlfriend). No custom auth, no backend server. CloudKit handles sharing. Distribution via TestFlight (paid Apple Developer account in hand).

## Tech Stack
- SwiftUI
- Raw CloudKit (`CKContainer`, `CKRecordZone`, `CKShare`) — **not** Core Data+CloudKit, **not** SwiftData. No `NSPersistentCloudKitContainer`.
- CoreLocation / MapKit for location-based categories
- Apple Foundation Models for on-device, guided recipe extraction
- A Share extension plus bounded public-page/oEmbed metadata requests for
  Instagram, TikTok, and web recipe intake
- iOS only

## Sharing Model
- One shared `CKRecordZone` per "space"/board (e.g. me + girlfriend). Multi-board is **built**: users can create additional named boards (each its own private zone), switch between them, and hold per-board profiles. See IMPLEMENTATION.md for the current state.
- Zone owner creates the `CKShare`, sends invite link via native share sheet, other person accepts. Data lives in the owner's private database; both read/write into the shared zone.
- Full read/write for both participants — no read-only permission tiers needed in Phase 1.

## Data Model
No generic "Item" record type. Each category is its own `CKRecord` type, unified by a shared protocol for list/grid rendering, so each category can carry its own fields and eventually its own detail view without a schema migration.

```swift
protocol SharedListItem {
    var id: CKRecord.ID { get }
    var title: String { get set }
    var notes: String? { get set }
    var status: ItemStatus { get set }
    var addedBy: CKRecord.Reference { get }
    var dateAdded: Date { get }
    var category: ItemCategory { get }
}

enum ItemStatus: String, CaseIterable {
    case wantToGo, planned, completed
}
```

Current category types are `Restaurant`, `Bar`, `Recipe`, and `Movie`. Planned
typed categories include `HappyHour`, `Landmark`, `Hike`, and `Activity`.
Each conforms to `SharedListItem` plus its own category-specific fields (e.g.
`Hike` can have `distanceMiles`/`elevationGainFt`/`difficulty`; `Movie` has
`runtime`/`streamingService`/`releaseYear`). Keep field naming consistent across
types (e.g. always `location`, never mix `Location`/`location`) since CloudKit
schema is case-sensitive and will silently create duplicate fields on a typo.
The project does not currently require backward-compatible migrations for
unreleased model/schema changes.

## Design Direction — "The Board"
Pinned corkboard aesthetic, not a plain list. Reference: two-column masonry grid, variable card height by content (photo-bearing categories like Hike/Landmark/Restaurant/Activity get taller cards; text-only categories like HappyHour/Movie stay short), color-coded accent per category, slight per-card rotation for a tactile feel.

Palette: ink-navy background (`#14181F`), warm cream cards (`#EFE6D3`), brass/gold primary accent (`#D9A441`). Serif display type (Georgia) for titles.

Board-card information hierarchy is title-first. Category metadata uses compact
icon-led utility cues, not a joined subtitle; author names and planning/history
dates remain off the already-dense card surface.

Current interaction details:

- The board uses a compact pinned filter bar. Its full surface opens a
  multi-select sheet; `CLEAR` is the only excluded tap target.
- Filter state is set-based: empty means all, selections are ORed within
  categories/statuses, and the two dimensions are ANDed together.
- Long-press shows a rich quick look; its Edit action routes into the same
  typed detail editor used everywhere else.
- Double-tap opens an iMessage-style reaction picker. Each participant can
  leave one reaction per item; holding the top-right reaction badge shows who
  added each tapback.
- Save operations show progress and successful additions produce a transient
  board notice.
- The top-bar dice runs an animated, haptic Pick for us roll over the current
  visible pins and opens the winning detail view.
- The Share to Docket extension turns supported public Instagram, TikTok, and
  web links into editable Recipes. It captures shared text when available,
  otherwise reads bounded public metadata, then uses Apple's on-device
  Foundation Model to generate the title, ingredients, and ordered steps.
- TikTok uses its official public oEmbed response first. Generic links use
  Open Graph, Twitter, standard description, and JSON-LD metadata fallbacks.
  A clean structured-data thumbnail is preferred, prepared locally, previewed
  as a removable cover, and stored in the existing Recipe photo field.
- Missing/private metadata, an unavailable Apple Intelligence model, or an
  unusable caption produces a short alert and leaves the manual recipe editor
  available. The extension never needs to download or transcribe the video.
- Stable card IDs drive animated filter, add, delete, refresh, and masonry
  position changes.
- Long-press Delete requires a native destructive alert and confirms successful
  removal with a transient `Deleted <title>` board notice.

## Implementation Status

Built: CloudKit zones/sharing, multi-board switching, typed Restaurant/Bar/Recipe/Movie
records, masonry board, multi-select filtering, typed add/detail editing,
structured MapKit locations and maps, photo/map card treatments, item and board
deletion, board management, conflict handling, silent push reconciliation,
local notifications, caption-to-Recipe sharing with generated cover photos and
board selection, shared planned dates and completion history, Pick for us dice,
per-person item reactions, and current board interaction polish. The
asset catalog also contains the production app icon. See `IMPLEMENTATION.md`
for authoritative details.

Next: Happy Hour/Landmark/Hike/Activity record types, profile images,
board renaming, additional real-device CloudKit testing, and
production/TestFlight work. Continue testing social recipe extraction across
public/private posts, short links, supported languages, and Apple Intelligence
availability states.

## Local Commands

The root `Justfile` is the canonical command interface. Install `just` with
`brew install just`, then run `just` to list all recipes. Common commands are
`just build`, `just test`, `just test-one <Class[/method]>`, `just format`,
`just format-check`, and `just verify`. Simulator and DerivedData defaults can
be overridden with `DOCKET_SIMULATOR`, `DOCKET_SIMULATOR_OS`, and
`DOCKET_DERIVED_DATA`.

## Explicitly Out of Scope for Phase 1
- Custom auth beyond Apple ID + CloudKit sharing
- Backend server
- Server-side AI inference, third-party video downloading, and Reel/TikTok
  audio transcription
- App Store submission

## Working Agreement
- **Do not run the app on simulators or devices.** Build and run tests
  (`xcodebuild build`, `xcodebuild test`, `swift build`, etc.) are fine, but
  launching/running the app itself is reserved for me to do manually in Xcode.
  If something needs to be visually verified or tested against live CloudKit
  sync, tell me what to check rather than launching it.
- Foundation Model inference cannot be validated in Simulator. Verify social
  recipe extraction, Apple Intelligence availability states, and real
  Instagram/TikTok metadata on an eligible physical device.
