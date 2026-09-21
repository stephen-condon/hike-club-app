# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A native iOS app (SwiftUI + SwiftData) for Pack 134's hike club — single-user, runs only on the owner's iPhone, all data persisted locally on-device. It tracks hike attendance, per-scout mileage, badge awards, and inventory (badges + hiking sticks) across the lifecycle of a hike event. The **one** network call is the optional, read-only Hike Club API trail-info fetch (see Architecture); everything else is offline and on-device. Full product spec, including the badge catalog and award rules: `requirements.md`.

## Development Workflow

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

Or open `Pack134HikeClub.xcodeproj` in Xcode and use Cmd+U / the diamond next to a test. SwiftLint is configured (`Pack134HikeClub/.swiftlint.yml`) and CI runs `swiftlint lint --strict` as a gate before tests; run it locally with `swiftlint lint --strict` from `Pack134HikeClub/`.

Commits on `main` drive `semantic-release` (`.releaserc.json`, `.github/workflows/release.yml`) — use conventional commit prefixes (`feat:`, `fix:`, `chore:`, etc.) so versioning and release notes stay accurate.

## Architecture

- No MVVM layer — Views hold `@Query`/`@Environment(\.modelContext)` directly and mutate `@Model` objects in place (SwiftData autosaves). The one exception is `Awards.swift`, a `Scout` extension that computes derived data (`earnedBadges`, `cumulativeMileage`) instead of a stored view model.
- `Models.swift` is the single schema source of truth: `Scout`, `Hike`, `Attendance`, `InventoryItem`, `StickAssignment`, `Ceremony`, `CeremonyAward`, plus four enums that cross-reference each other — `HikeQuality`, `ScoutQuality`, `BadgeType`, `InventoryKind`. Each badge/quality is wired through computed properties (`badgeType`, `hikeQuality`, `inventoryKind`); adding a new badge means touching all four enums and keeping their mappings in sync.
- Hike lifecycle is a 4-state machine (`HikeStatus`: `planned` → `inProgress` → `recap` → `complete`, with `complete` reopenable back to `recap`). `HikeDetailView` gates field editability (`isEditable`, `showAttendance`, `showDetails`) purely off `hike.status` — follow this status-driven visibility pattern when adding fields.
- `Hike.mileage` (per-hike distance) and `Hike.elevationGain` (feet, optional) can be imported from HealthKit via the "Import from Health" button in `HikeDetailView` (gated by `isEditable`). `HealthImport.swift` reads the owner's own `.hiking` `HKWorkout`s recorded on the hike's date — on-device only, so the "no network" property holds; per-scout `cumulativeMileage` stays derived from the shared `hike.mileage`. Distance is rounded to the nearest half mile (`milesRoundedToHalf`); the HealthKit store calls are device-only (Simulator has no workout data), while the pure conversion helpers are unit-tested. Requires the HealthKit entitlement + `NSHealthShareUsageDescription` (added via Xcode's Signing & Capabilities). Imported elevation drives the **Matterhorn** badge: on import, `apply(_:)` sets/clears the `.elevation` hike quality from `Hike.earnsMatterhorn(elevationFeet:)` (≥100 ft), and the `.elevation` quality toggle in `HikeDetailView` goes read-only once elevation is imported (`elevationGain != nil` is the "imported" signal). Non-imported hikes keep manual `.elevation` flagging. `qualitiesRaw` stays the single source of truth, so `earnedBadges` is unchanged.
- Badges are derived, not stored: `Scout.earnedBadges(completedHikes:)` recomputes from scratch (seeded badges + mileage thresholds + hike qualities + scout qualities) on every call — O(hikes×scouts), intentionally uncached for pack-sized data (see `ponytail:` comment in `Awards.swift`). `Scout.givenBadges` is the only persisted badge state (badges physically handed out); giving/un-giving a badge in `ScoutDetailView` manually decrements/increments the matching `InventoryItem.count` — there is no automatic sync between `earnedBadges` and inventory.
- Roster seeding (`Seed.swift`) parses a bundled `Roster.csv` with columns `name,startingMileage,earnedBadges (`;`-separated `BadgeType` raw values),stick` on first launch only, guarded by an empty-table check; `InventoryItem` rows are seeded to zero for every `InventoryKind` case at the same time. Parsed `earnedBadges` seed `Scout.seededEarnedBadges` (earned) while `givenBadges` starts **empty** — seeded awards are earned-but-not-yet-handed-out. The `stick` column is `has` (earned & awarded → creates `StickAssignment`), `earned` (earned only → sets `stickEarned`), or blank (neither).
- Stick state has two levels mirroring badges: `Scout.stickEarned` (ceremony decision, persisted) vs `Scout.stickAssignment != nil` (physically awarded, decrements hiking-stick inventory). `assignStick` sets both; `returnStick` clears only the assignment, leaving `stickEarned` true (scout drops back to earned-but-not-awarded, not un-earned).
- The Ceremonies tab (`CeremoniesView.swift`, `CeremonyDetailView.swift`, logic in `Ceremonies.swift`) is the primary path for handing out earned badges/sticks in bulk. `Ceremony` stores only `title`/`date`/`isComplete` — the set of scouts with pending awards is **live-derived** every time a scheduled ceremony is viewed (`Scout.pendingBadges(completedHikes:)` = `earnedBadges − givenBadges`; `Scout.hasPendingStick` = `stickEarned && stickAssignment == nil`), never snapshotted at scheduling time. All pending scouts are auto-included; completion is **per-scout all-or-nothing** — you toggle scouts off if they didn't show up, and `completeCeremony(...)` only awards the scouts passed to it, so toggled-off scouts stay pending and simply reappear in the next ceremony. Awarding reuses `ScoutActions.swift` (`giveBadge`/`assignStick`) via `Scout.awardAllPending(...)`, so inventory stays consistent — no separate award path. `ceremonyInventoryNeeds`/`ceremonyShortfalls` flag a kind for restocking when `onHand − need < minReserve` (below-need-plus-reserve, not just below-need). On completion, exactly what was handed to each scout is snapshotted into a `CeremonyAward` (badges + stick given) attached to the `Ceremony` — this is the only persisted historical record of ceremony contents; `earnedBadges`/`givenBadges` don't track *which* ceremony gave what.
- Planned (incomplete) ceremonies schedule two local reminders (`Notifications.swift`, `UserNotifications`): 5 weeks out to order badges, 2 weeks out to buy hiking sticks, at 9 AM local. `CeremonyReminders.upcoming(for:sticksToBuy:now:)` is the pure, unit-tested builder (future-only, skips complete ceremonies); the stick reminder body carries the live `stickBuyCount(scouts:hikes:inventory:)` (`Ceremonies.swift`, = the `Buy N` shown in `CeremonyDetailView`, or "enough on hand" text at 0) — pack-wide, not per-ceremony, so both call sites fetch scouts/hikes/inventory to compute it. `reschedule(_:sticksToBuy:)` nuke-and-repaves all pending requests and is called at app launch (`Pack134HikeClubApp`) and on `CeremoniesView.onAppear` (covers create/edit/delete/complete on tab return). Local notifications need no entitlement or Info.plist key.
- **Hike Club API integration** (`HikeAPI.swift`, `HikeID.swift`, `Keychain.swift`, `SettingsView.swift`) — the app's *only* network call, and the sole exception to "no network". Uses **API v2** — every request sends `x-api-version: 2` (absent would be v1). A `Hike` stores `apiHikeID` as its only API link; it is **not typed by hand** — it's derived as `"yyyy-MM-dd-<slug>"` (`HikeID.make(date:slug:)`) from the hike's date + a **location picker** on `HikeDetailView` (planned-only), where the slug is the location's `short_name`. Changing the date while planned re-syncs the id's prefix (`.onChange(of: hike.date)`); an existing/typed id back-derives its selected slug via `HikeID.slug(from:)` (strips the `yyyy-MM-dd-` prefix), so no migration was needed. `HikeAPI.fetch(id:)` does a read-only `GET /hike/{id}` and returns `HikeResponse` (v2 weather: `startTempF`/`endTempF`, `precipitation` with `probabilityPct`/`expected`/`startsAt`/`endsAt`, `heatIndexF`/`windChillF`, alerts). `TrailInfoView` renders it with a conditions-matched SF Symbol (`weatherSymbol(for:)`, keyword heuristic). The fetched hike data is **ephemeral view `@State`, never persisted**. The location picker is fed by `GET /hike-locations` (`[{short_name, full_name}]`) cached in `UserDefaults` (`HikeAPI.cachedLocations()`); `refreshLocationsIfStale()` re-fetches when older than 7 days (`locationsAreStale(fetchedAt:now:)`) **but keeps stale data on any fetch failure / offline** — the cache is only cleared by the **Settings → Trail Locations → "Clear cached locations"** button (`clearLocationsCache()`). Config: base URL in `UserDefaults` (`@AppStorage`), API key in the **Keychain** (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, never in git/binary), both entered in the **Settings** tab. Security invariants to preserve: base URL is `https`-only (rejected otherwise in `SettingsView`, so the key can't leak to an http/wrong host); `apiHikeID` is validated + `URL.appending(path:)`-encoded (no path escaping); remote strings render as `Text(variable)` and response URLs are `https`-gated before `AsyncImage`/`Link` (no markdown/deep-link injection); no ATS exception. Like `HealthImport`, the pure helpers (`HikeResponse.decode`, `HikeLocation.decode`, `HikeID`, `weatherSymbol`, `locationsAreStale`) are unit-tested (`HikeAPITests`) while the `URLSession`/Keychain/UserDefaults calls are device-only and untested. New `.swift` files auto-join the target via the project's file-system-synchronized groups — no `project.pbxproj` edit needed.

## Testing

Uses **Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest. All changes must include unit tests, we are targeting 90%+ coverage for non-UI code. All unit tests must enforce complete isolation.

## LID
- Mode: Full
- Version: 1.3.0

## Linked-Intent Development (MANDATORY)

**Consult the `linked-intent-dev` skill for ALL code changes.** All changes flow through the arrow of intent in one direction:

```
HLD → LLDs → EARS → Tests → Code
```

- **New features and refactors**: full six-phase workflow (HLD check → LLD check/draft → EARS → intent-narrowing edge audit → tests-first → code).
- **Bug fixes**: walk the arrow like any other change — find where behavior diverged from intent and cascade from there. No short-circuit.
- **If unsure**: use the full workflow.

Stop after each phase for user review. **Docs carry current intent, written to be read cold** — write each doc as if authored fresh today, from current intent alone: no narration of how it changed, no meaning that needs the conversation that produced it, no rebuttals to questions only a past discussion raised. Rationale, considered alternatives, and constraints a fresh author would independently write stay; record rejected alternatives and why in the LLD's Decisions & Alternatives table, not as asides in body prose.

**Memory vs. intent.** Before saving durable project knowledge to agent or tool memory, test whether it is project *intent* — would a fresh agent, in any tool, next session, need it to build this system correctly? If yes, record it in the arrow (HLD / LLD / EARS / decision doc), which travels and cascades — not in private, per-tool memory, where intent escapes the arrow. Knowledge about the user or how they like to work stays in memory.

### Navigation

| What you need | Where to look |
|---|---|
| High-level design | `docs/high-level-design.md` |
| Design tree (sub-HLDs, LLDs, their specs) | `docs/intent/` — one folder per node |
| EARS specs | beside each design doc as `{node}-specs.md` in the node's folder under `docs/intent/` |
| Decision docs | `docs/decisions/` (project-level) and `docs/intent/<segment>/decisions/` |
| Arrow of intent overlay | `docs/arrows/index.yaml` and per-segment docs in `docs/arrows/` |

### Terminology

- **HLD**: High-Level Design — single project-level doc at `docs/high-level-design.md`.
- **LLD**: Low-Level Design — detailed component design doc in `docs/intent/`. The design layer is a recursive tree: the root is the HLD, leaf LLDs own EARS, and a component deep enough to outgrow one doc becomes a sub-HLD (HLD-shaped, owns no EARS) with children beneath it. "HLD" and "LLD" are roles by position; depth-2 (one HLD over flat leaf LLDs) is the default.
- **EARS**: Easy Approach to Requirements Syntax — structured one-line requirements beside each design doc as `{node}-specs.md` in the node's folder under `docs/intent/`. IDs are path-concatenated — the root-to-leaf path of the owning segment plus a number — so a prefix grep gathers a subtree. Markers: `[x]` implemented, `[ ]` active gap, `[D]` deferred.
- **Arrow**: the unidirectional chain from vision to code (HLD → LLDs → EARS → Tests → Code). Strictly a DAG of intent.
- **Arrow segment**: the territory owned by one leaf LLD — the LLD itself plus the specs, tests, and code that cite its EARS IDs. The boundary is the leaf prefix. Within-segment cascade is free; across-segment cascade pauses.
- **Cascade**: propagating a change downstream through the arrow so adjacent levels stay coherent.

### Code annotations

Annotate code and tests with `@spec` comments citing EARS IDs:

```
// @spec AUTH-UI-001, AUTH-UI-002
```

Place the annotation at the *entry point of the behavior's implementation graph* — the topmost function or module owning the specified behavior, not every helper. When a behavior spans multiple subsystems (UI + API + database, for example), annotate at the entry point in each subsystem. Tests follow the same rule: annotate the test that directly exercises the spec, not every inner assertion.
