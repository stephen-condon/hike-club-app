# Arrow: award-handout

What was physically handed to a scout, and the inventory movement that implies.

## Status

**MAPPED** — last audited 2026-09-20 (git SHA `d0f0493`). Reverse-engineered from code; LLD and EARS are skeletons awaiting flesh-out.

## References

### HLD
- docs/high-level-design.md (§ Derived awards)

### LLD
- docs/intent/award-handout/award-handout-design.md

### EARS
- docs/intent/award-handout/award-handout-specs.md *(not yet drafted)*

### Tests
- Pack134HikeClub/Pack134HikeClubTests/ActionsTests.swift
- Pack134HikeClub/Pack134HikeClubTests/CeremoniesTests.swift:93-180

### Code
- Pack134HikeClub/Pack134HikeClub/Models.swift:153,155,259-268 (givenBadges, stickEarned, StickAssignment)
- Pack134HikeClub/Pack134HikeClub/ScoutActions.swift
- Pack134HikeClub/Pack134HikeClub/Ceremonies.swift:29-46
- Pack134HikeClub/Pack134HikeClub/ScoutDetailView.swift:48-93,123-171

## Architecture

**Purpose:** Record the physical act of handing a badge or stick to a scout, and keep the shed's count honest as it happens.

**Key Components:**
1. `Scout.givenBadges` — the only persisted badge state; append to give, remove to un-give
2. `ScoutActions` — `giveBadge` / `ungiveBadge` / `assignStick` / `returnStick`, each adjusting the matching `InventoryItem`
3. Two-level stick state — `stickEarned` (the decision) vs. `stickAssignment != nil` (the physical award)
4. `Scout.awardAllPending` — the bulk path ceremonies reuse, so there is exactly one award mechanism

## Spec Coverage

*(specs not yet drafted — regenerate this table after `award-handout-specs.md` lands)*

## Key Findings

1. **Give is idempotent; un-give is not bounded** — `ScoutActions.swift:13-29`. Giving an already-given badge no-ops, but inventory has a floor (`max(0, …)`) and no ceiling.
2. **The floor breaks give/un-give symmetry** — giving a badge at count 0 leaves count 0, and un-giving it then yields count 1, inventing an item. `ActionsTests.swift:141` covers only the symmetric path (count > 0); `:55` covers the floor in isolation. The round trip across the floor is untested and its intended behavior is unrecorded. `[inferred]`
3. **`returnStick` deliberately leaves `stickEarned` true** — `ScoutActions.swift:43-49`. The scout drops back to earned-but-not-awarded rather than un-earned.
4. **`assignStick` sets `stickEarned = true` unconditionally** — `:36`. `ScoutDetailView.swift:87-91` offers "Award Stick" whether or not the scout earned one, so awarding is also a way to *make* it earned.
5. **No automatic sync between earned and given** — stated intent in CLAUDE.md, implemented as absence. `ScoutDetailView.swift:55` renders a badge row when either flag is set, so given-but-not-earned displays normally.

## Work Required

### Should Fix
1. Inventory asymmetry across the zero floor (finding 2) — decide whether un-give should be a no-op when the give was itself floored.
2. Undefined handling for badges that are given but no longer earned (cascaded from `award-derivation`).
