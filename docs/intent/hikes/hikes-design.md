---
parent: high-level-design
prefix: HIKE
---

# Hikes

## Context and Design Philosophy

A hike is an event with a life: it gets planned, it happens, it gets tidied up afterward, and then it is finished. Everything the award system needs — who came, how far, what the weather did — is captured during that life, and once the hike is `complete` those facts stop moving.

The design puts the whole notion of "what can I edit right now" into one place: hike status. No field carries its own editability rule; every field asks the status. That keeps the four states meaningful and makes adding a field a matter of deciding which states it belongs to rather than inventing new gating.

Recording is deliberately forgiving. Conditions get flagged on the trail where the owner is holding a phone in the cold, and corrected later in recap when memory is fresher and the weather app can be consulted. `complete` is reopenable precisely because clerical errors are expected.

## The Lifecycle

```
planned ──Start Hike──> inProgress ──End Hike──> recap ──Complete──> complete
                                                    ^                   │
                                                    └─────Reopen────────┘
```

| State | Title | Date | Location | Attendance | Details & Qualities |
|-------|-------|------|----------|------------|---------------------|
| `planned` | edit | edit | edit | hidden | hidden |
| `inProgress` | edit | read | read | edit | edit |
| `recap` | edit | read | read | edit | edit |
| `complete` | read | read | read | read | read |

Derived in `HikeDetailView` as `isEditable` (`inProgress` or `recap`), `showAttendance` (same), and `showDetails` (anything but `planned`) — `HikeDetailView.swift:23-33`. Title and date have their own inline status checks rather than a named property.

**Current-state divergence:** transitions are enforced by which button renders (`HikeDetailView.swift:273-294`), not by a validated transition function. `hike.status` is a plain settable property; nothing rejects an out-of-band write.

## The Hike Record

`Hike` (`Models.swift`) holds title, `date`, optional `endTime`, status, `mileage`, optional `elevationGain` (feet), `qualitiesRaw`, `notes`, and `apiHikeID` (owned by `trail-info`).

`date` and `endTime` are the hike's entire date/time record — the API's own record carries none, so this is the only place a hike's date lives (see [[trail-info]] and the workspace's `system-design.md` Seam 1). `date` carries a time as well as a day; `effectiveEndTime` reads `endTime` if the owner set one, else `date` plus two hours (`Hike.defaultDurationSeconds`). Both are editable, as "Starts"/"Ends", only while `planned`, same as the date's existing editability.

`qualitiesRaw` is an array for SwiftData compatibility and treated as a set through the `qualities` computed property. It is the single source of truth for hike conditions — both the manual toggles and the Health import write to it, so `award-derivation` never needs to know where a quality came from.

`mileage` is per-hike and shared: every attendee accrues the same distance. There is no per-scout distance.

## Attendance

`Attendance` (`Models.swift:228-242`) is the hike↔scout join, carrying `scoutQualitiesRaw` — currently just `.backpack`, structured as an enum so more per-scout qualities can be added without a schema change.

Attendance is presence-by-existence: the row exists or it doesn't (`HikeDetailView.swift:331-344`). Toggling a scout on inserts a row; toggling off deletes it.

**Current-state divergence:** toggling off destroys the row and with it the backpack flag (`:339-341`). Re-adding the scout starts clean, with no warning that a recorded quality was discarded.

## Health Import

`HealthImport` (`HealthImport.swift`) reads the owner's own `.hiking` `HKWorkout`s for the hike's calendar day, newest first. On-device only — this is a read from HealthKit, not a network call, so the app's offline property holds.

- Distance converts to miles rounded to the nearest half (`milesRoundedToHalf`), matching how pack mileage is talked about.
- Elevation comes from `HKMetadataKeyElevationAscended` when present, converted to whole feet; absent metadata yields `nil`.
- Zero workouts, one workout, or several are handled distinctly (`HikeDetailView.swift:241-247`) — several prompts a choice by start time and distance.

The store calls are device-only and untested; the pure conversions are unit-tested. This tested/untested split is the same one `trail-info` uses.

### Imported elevation drives Matterhorn

`apply(_:)` (`HikeDetailView.swift:253-263`) clears `.elevation` from `qualitiesRaw` and re-adds it only if `Hike.earnsMatterhorn(elevationFeet:)` — at least 100 ft. Once `elevationGain != nil`, the manual `.elevation` toggle goes read-only (`:206`). Non-imported hikes keep manual flagging.

`elevationGain != nil` is the sole signal for "this hike was imported," noted as such in a `ponytail:` comment at `:205`.

## Deletion

Only completed hikes can be swipe-deleted (`HikesView.swift:41-51`), behind a confirmation that names the consequence: attendees' mileage and badges are recalculated. The cascade on `Hike.attendances` (`Models.swift:193`) removes the join rows, and because awards are derived, totals simply drop.

**Current-state divergence:** nothing reconciles already-given badges against the smaller earned set that results. Same for a reopen that changes mileage or qualities.

## Decisions & Alternatives

| Decision | Chosen | Alternatives Considered | Rationale |
|----------|--------|------------------------|-----------|
| Lifecycle shape | Four states, `complete` reopenable | Two states (planned/done); no reopen; full audit log | `requirements.md` asks for recap-then-lock with reopening for clerical errors |
| Field editability | Derived from status, centrally | Per-field flags; a lock toggle | One rule to reason about; adding a field means choosing its states |
| Transition enforcement | Which button renders | Validated `transition(to:)`; state-pattern types | `[inferred]` — no guard exists; may be deliberate simplicity or an untaken step |
| Mileage granularity | One value per hike | Per-scout distance | Everyone walks the same trail; per-scout distance has no source |
| Attendance representation | Row exists or not | Boolean on a persistent join row | Fewer rows; deletion is the natural "wasn't there" |
| Conditions storage | `qualitiesRaw` as sole truth | Separate imported vs. manual fields | Keeps `award-derivation` ignorant of provenance |
| Health import scope | Same calendar day | ±1 day window; user-picked window | Marked `ponytail:` at `HealthImport.swift:55` with the widening named |
| Elevation authority | Import wins, locks the toggle | Import suggests, owner confirms | Measured data beats a guess; manual flagging survives for non-imported hikes |
| Partial mileage input | Keep last valid value | Zero it; reject the keystroke | Avoids wiping a number mid-edit (`HikeDetailView.swift:164`) |
| Hike date ownership | `date`/`endTime` are the hike's only date/time record | Keep a date on the Hike Club API record too | The API record carries no date under its current version; duplicating one here would let the two disagree. See [[trail-info]]. |
| Default hike duration | Two hours, when `endTime` is unset | Prompt for an end time before allowing Trail Info; no default, omit the end window | A flat default (`ponytail:` at `Models.swift`) needs no extra owner step before the common case; the owner can still set an explicit end. |
| End-time picker scope | Time only, day inherited from `date` | A full end date+time picker | Matches the deferred midnight-spanning gap below rather than solving it; a full picker is the upgrade path if that gap is ever closed. |

## Open Questions & Future Decisions

### Deferred
1. **Should the state machine be guarded?** Today it is render-gated only. A validated transition function would make the machine enforceable and testable independent of the view.
2. **Losing the backpack flag on attendance toggle-off.** Whether this should warn, preserve the quality, or stay destructive is undecided.
3. **Earned-set shrink after delete or reopen.** A hike deletion can drop a scout below a badge they were already handed. Cascades into [[award-derivation]] and [[award-handout]]; the substance of the decision is arguably theirs, but the trigger lives here.
4. **Midnight-spanning hikes.** A night hike (Raven) that crosses midnight has workouts the same-day filter will miss.
5. **`elevationGain != nil` as the "imported" flag.** It conflates "we imported" with "the workout reported elevation." A workout with no elevation metadata imports successfully but leaves the toggle editable.

## References

- `Pack134HikeClub/Pack134HikeClub/Models.swift:11-13,180-242`, `HikesView.swift`, `HikeDetailView.swift`, `HealthImport.swift`
- Arrow doc: `docs/arrows/hikes.md`
- Related: [[award-derivation]], [[trail-info]], [[scouts]]
