# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A native iOS app (SwiftUI + SwiftData) for Pack 134's hike club — single-user, runs only on the owner's iPhone, no backend or network calls, all data persisted locally on-device. It tracks hike attendance, per-scout mileage, badge awards, and inventory (badges + hiking sticks) across the lifecycle of a hike event. Full product spec, including the badge catalog and award rules: `requirements.md`.

## Development Workflow

- Use git worktrees to isolate feature branches before starting implementation (see the `using-git-worktrees` skill).
- Plan first: scope and design non-trivial changes in plan mode (Opus) before writing code; switch to Sonnet once the plan is approved for actual implementation.
- Non-UI code (`Models.swift` logic, `Awards.swift`, `Seed.swift` parsing) must maintain ≥90% test coverage. View files are exempt.
- Architectural changes (schema changes in `Models.swift`, state-machine changes, new derived-data patterns) must be reflected back into this file.

## Commands

Run from `Pack134HikeClub/` (where `Pack134HikeClub.xcodeproj` lives). Scheme is `Pack134HikeClub`.

```bash
# Build
xcodebuild -scheme Pack134HikeClub -destination 'platform=iOS Simulator,name=iPhone 17' build

# Run all tests
xcodebuild test -scheme Pack134HikeClub -destination 'platform=iOS Simulator,name=iPhone 17'

# Run a single test
xcodebuild test -scheme Pack134HikeClub -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:Pack134HikeClubTests/AwardsTests/mileageBadgesAtTwentyFiveMiles
```

Or open `Pack134HikeClub.xcodeproj` in Xcode and use Cmd+U / the diamond next to a test. There is no lint/format tooling configured yet.

## Architecture

- No MVVM layer — Views hold `@Query`/`@Environment(\.modelContext)` directly and mutate `@Model` objects in place (SwiftData autosaves). The one exception is `Awards.swift`, a `Scout` extension that computes derived data (`earnedBadges`, `cumulativeMileage`) instead of a stored view model.
- `Models.swift` is the single schema source of truth: `Scout`, `Hike`, `Attendance`, `InventoryItem`, `StickAssignment`, plus four enums that cross-reference each other — `HikeQuality`, `ScoutQuality`, `BadgeType`, `InventoryKind`. Each badge/quality is wired through computed properties (`badgeType`, `hikeQuality`, `inventoryKind`); adding a new badge means touching all four enums and keeping their mappings in sync.
- Hike lifecycle is a 4-state machine (`HikeStatus`: `planned` → `inProgress` → `recap` → `complete`, with `complete` reopenable back to `recap`). `HikeDetailView` gates field editability (`isEditable`, `showAttendance`, `showDetails`) purely off `hike.status` — follow this status-driven visibility pattern when adding fields.
- Badges are derived, not stored: `Scout.earnedBadges(completedHikes:)` recomputes from scratch (seeded badges + mileage thresholds + hike qualities + scout qualities) on every call — O(hikes×scouts), intentionally uncached for pack-sized data (see `ponytail:` comment in `Awards.swift`). `Scout.givenBadges` is the only persisted badge state (badges physically handed out); giving/un-giving a badge in `ScoutDetailView` manually decrements/increments the matching `InventoryItem.count` — there is no automatic sync between `earnedBadges` and inventory.
- Roster seeding (`Seed.swift`) parses a bundled `Roster.csv` (`name,startingMileage,semicolon-separated BadgeType raw values`) on first launch only, guarded by an empty-table check; `InventoryItem` rows are seeded to zero for every `InventoryKind` case at the same time.

## Testing

Uses **Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest. All changes must include unit tests, we are targeting 90%+ coverage for non-UI code. All unit tests must enforce complete isolation.