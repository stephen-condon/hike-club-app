# Arrow: scouts

The pack roster — who is in the hike club, their pre-app mileage, and their active/archived state.

## Status

**MAPPED** — last audited 2026-09-20 (git SHA `d0f0493`). Reverse-engineered from code; LLD and EARS are skeletons awaiting flesh-out.

## References

### HLD
- docs/high-level-design.md (§ Roster)

### LLD
- docs/intent/scouts/scouts-design.md

### EARS
- docs/intent/scouts/scouts-specs.md (45 specs)

### Tests
- Pack134HikeClub/Pack134HikeClubTests/SeedTests.swift:24-179
- Pack134HikeClub/Pack134HikeClubTests/ModelsTests.swift:197-224
- Pack134HikeClub/Pack134HikeClubTests/ViewTests.swift:125-141,174-192

### Code
- Pack134HikeClub/Pack134HikeClub/Models.swift:144-178 (Scout)
- Pack134HikeClub/Pack134HikeClub/Seed.swift:10-20,28-79
- Pack134HikeClub/Pack134HikeClub/ScoutsView.swift
- Pack134HikeClub/Pack134HikeClub/ScoutDetailView.swift:31-46,95-121

## Architecture

**Purpose:** Hold the roster of cub scouts the whole app derives from, and get it populated from the pack's existing spreadsheet on first launch.

**Key Components:**
1. `Scout` @Model — name, startingMileage, isActive, seededEarnedBadges; owns attendances and an optional stick assignment
2. `Seed.parseRoster` / `seedScouts` — first-launch CSV import from bundled `Roster.csv`
3. `ScoutsView` / `NewScoutSheet` — roster list, archive visibility toggle, manual add
4. `ScoutDetailView` header + completed-hike history — the read-only per-scout view

## Spec Coverage

| Category | Spec IDs | Implemented | Active gap | Deferred |
|----------|----------|-------------|------------|----------|
| Scout record | SCOUT-001–004, 026, 043–044 | 5 | 2 | 0 |
| Seeding | SCOUT-005–006, 027, 035–036 | 2 | 3 | 0 |
| Header and columns | SCOUT-007, 028–031 | 1 | 4 | 0 |
| Row validation | SCOUT-009–017, 032–034 | 8 | 5 | 0 |
| Diagnostics | SCOUT-037–038, 046 | 0 | 3 | 0 |
| Roster display | SCOUT-018–022, 042 | 5 | 1 | 0 |
| Archiving | SCOUT-025, 039–041 | 2 | 2 | 0 |
| Manual entry | SCOUT-023–024, 045 | 1 | 2 | 0 |

**Summary:** 23 of 45 specs implemented; 22 active gaps from the roster-import hardening pass. SCOUT-008 deleted (index-based column mapping, superseded by SCOUT-028). No `@spec` annotations yet in code or tests.

## Key Findings

1. **Naive CSV parse** — `Seed.swift:36` splits on commas with no quoting support. A `ponytail:` comment names the ceiling and the upgrade path.
2. **Unknown badge tokens vanish silently** — `Seed.swift:43` `compactMap` drops unrecognized `BadgeType` raw values with no signal to the owner. Covered by `SeedTests.swift:75` as intended behavior, but the intent behind "silent" is unrecorded. `[inferred]`
3. **Seeding is first-launch only** — `Seed.swift:10-20` guards on an empty table per model. Editing `Roster.csv` after first launch has no effect, and there is no re-import path.
4. **Archive, never delete** — `ScoutsView.swift:13-14` partitions on `isActive`. Archived scouts still derive awards (`Pack134HikeClubTests.swift:97`), so archiving is a display concern, not a data one.
5. **`startingMileage` is write-once at seed** — `NewScoutSheet` hardcodes `0` (`ScoutsView.swift:124`) and no UI edits it afterward. A scout added by hand can never carry pre-app mileage.

## Work Required

### Should Fix
1. No path to re-import or amend the roster after first launch (finding 3) — blocks adding a mid-season scout with prior mileage (finding 5).

### Nice to Have
2. Surface dropped badge tokens during parse rather than discarding them silently (finding 2).
