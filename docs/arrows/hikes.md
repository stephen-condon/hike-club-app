# Arrow: hikes

The hike event lifecycle — scheduling, running, recording attendance and conditions, and locking results in.

## Status

**MAPPED** — last audited 2026-09-20 (git SHA `d0f0493`). Reverse-engineered from code; LLD and EARS are skeletons awaiting flesh-out.

## References

### HLD
- docs/high-level-design.md (§ Hike lifecycle)

### LLD
- docs/intent/hikes/hikes-design.md

### EARS
- docs/intent/hikes/hikes-specs.md *(not yet drafted)*

### Tests
- Pack134HikeClub/Pack134HikeClubTests/ModelsTests.swift:99-170
- Pack134HikeClub/Pack134HikeClubTests/HealthImportTests.swift
- Pack134HikeClub/Pack134HikeClubTests/ViewTests.swift:22-123,194-214,262-282
- Pack134HikeClub/Pack134HikeClubTests/Pack134HikeClubTests.swift:205-249

### Code
- Pack134HikeClub/Pack134HikeClub/Models.swift:11-13,180-242 (HikeStatus, Hike, Attendance)
- Pack134HikeClub/Pack134HikeClub/HikesView.swift
- Pack134HikeClub/Pack134HikeClub/HikeDetailView.swift:23-33,56-215,235-294,297-389
- Pack134HikeClub/Pack134HikeClub/HealthImport.swift

## Architecture

**Purpose:** Model one hike as a four-state event, and capture everything about it that awards are later derived from — who came, how far, and under what conditions.

**Key Components:**
1. `HikeStatus` state machine — `planned → inProgress → recap → complete`, with `complete` reopenable to `recap`
2. `Hike` @Model — title, date, mileage, optional elevationGain, `qualitiesRaw` as the sole conditions source of truth
3. `Attendance` @Model — the hike↔scout join, carrying per-scout qualities (currently backpack only)
4. `HikeDetailView` status gating — `isEditable` / `showAttendance` / `showDetails` derive all field visibility from status
5. `HealthImport` — read-only same-day HealthKit hiking-workout lookup, on-device only

## Spec Coverage

*(specs not yet drafted — regenerate this table after `hikes-specs.md` lands)*

## Key Findings

1. **Transitions are button-shaped, not guarded** — `HikeDetailView.swift:273-294` offers exactly one forward transition per state, so the machine is enforced by which button renders rather than by a validated transition function. Nothing rejects an out-of-band status write.
2. **Visibility is purely status-derived** — `HikeDetailView.swift:23-33`. This is the codebase's stated pattern for adding new fields.
3. **Partial mileage input keeps the last valid value** — `HikeDetailView.swift:158-165`. Typing `"3."` leaves mileage at its prior number rather than zeroing it; empty string does zero it.
4. **Health import is same-day only** — `HealthImport.swift:55-64` uses `startOfDay`+1day with `.strictStartDate`. A `ponytail:` comment names the midnight-spanning ceiling.
5. **Import both sets and clears the `.elevation` quality** — `HikeDetailView.swift:258-261` removes it, then re-adds only if `earnsMatterhorn`. `elevationGain != nil` is the sole "was imported" signal and locks the manual toggle (`:206`).
6. **Deleting a completed hike silently rewrites history** — `HikesView.swift:71-78` cascades attendance deletion (`Models.swift:193`), which lowers attendees' cumulative mileage and can un-earn badges. The alert warns; nothing reconciles already-given badges.
7. **Toggling attendance off discards the backpack flag** — `HikeDetailView.swift:339-341` deletes the `Attendance` row. Re-adding the scout starts with empty qualities, with no warning.

## Work Required

### Should Fix
1. Attendance toggle-off discards a recorded scout quality without confirmation (finding 7).
2. No defined behavior when hike deletion or reopening shrinks a scout's earned set below what was already given (finding 6) — cascades into `award-derivation` and `award-handout`.

### Nice to Have
3. Validated transition function instead of render-gated transitions (finding 1).
