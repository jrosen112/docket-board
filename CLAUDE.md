# Docket

A shared iOS app for two people to collaboratively track places and experiences they want to do together: bars, restaurants, happy hours, landmarks, movies, hikes/walks, and general activities. Replaces a shared Apple Notes note with something structured and visual.

**Phase 1 goal**: build this for personal use between two people (me and my girlfriend). No custom auth, no backend server. CloudKit handles sharing. Distribution via TestFlight (paid Apple Developer account in hand).

## Tech Stack
- SwiftUI
- Raw CloudKit (`CKContainer`, `CKRecordZone`, `CKShare`) — **not** Core Data+CloudKit, **not** SwiftData. No `NSPersistentCloudKitContainer`.
- CoreLocation / MapKit for location-based categories
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

Category types: `Restaurant`, `Bar`, `HappyHour`, `Landmark`, `Movie`, `Hike`, `Activity` — each conforms to `SharedListItem` plus its own category-specific fields (e.g. `Hike` has `distanceMiles`/`elevationGainFt`/`difficulty`; `Movie` has `runtime`/`streamingService`/`releaseYear`). Keep field naming consistent across types (e.g. always `location`, never mix `Location`/`location`) since CloudKit schema is case-sensitive and will silently create duplicate fields on a typo.

## Design Direction — "The Board"
Pinned corkboard aesthetic, not a plain list. Reference: two-column masonry grid, variable card height by content (photo-bearing categories like Hike/Landmark/Restaurant/Activity get taller cards; text-only categories like HappyHour/Movie stay short), color-coded accent per category, slight per-card rotation for a tactile feel.

Palette: ink-navy background (`#14181F`), warm cream cards (`#EFE6D3`), brass/gold primary accent (`#D9A441`). Serif display type (Georgia) for titles.

Current interaction details:

- The board uses a compact pinned filter bar. Its full surface opens a
  multi-select sheet; `CLEAR` is the only excluded tap target.
- Filter state is set-based: empty means all, selections are ORed within
  categories/statuses, and the two dimensions are ANDed together.
- Long-press shows a rich quick look; its Edit action routes into the same
  typed detail editor used everywhere else.
- Save operations show progress and successful additions produce a transient
  board notice.
- Stable card IDs drive animated filter, add, delete, refresh, and masonry
  position changes.

## Implementation Status

Built: CloudKit zones/sharing, multi-board switching, typed Restaurant/Bar/Movie
records, masonry board, multi-select filtering, typed add/detail editing,
conflict handling, silent push reconciliation, local notifications, and current
board interaction polish. See `IMPLEMENTATION.md` for authoritative details.

Next: MapKit search/map support, Happy Hour/Landmark/Hike/Activity record types,
photos, profile images, board management, and production/TestFlight work.

## Explicitly Out of Scope for Phase 1
- Custom auth beyond Apple ID + CloudKit sharing
- Backend server
- App Store submission

## Working Agreement
- **Do not run the app on simulators or devices.** Build and run tests (`xcodebuild build`, `xcodebuild test`, `swift build`, etc.) are fine, but launching/running the app itself is reserved for me to do manually in Xcode. If something needs to be visually verified or tested against live CloudKit sync, tell me what to check rather than launching it.
