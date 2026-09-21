# Arrow: award-derivation

What each scout has *earned* — recomputed from scratch on every read, never stored.

## Status

**MAPPED** — last audited 2026-09-20 (git SHA `d0f0493`). Reverse-engineered from code; LLD and EARS are skeletons awaiting flesh-out.

## References

### HLD
- docs/high-level-design.md (§ Derived awards)

### LLD
- docs/intent/award-derivation/award-derivation-design.md

### EARS
- docs/intent/award-derivation/award-derivation-specs.md *(not yet drafted)*

### Tests
- Pack134HikeClub/Pack134HikeClubTests/Pack134HikeClubTests.swift:22-203
- Pack134HikeClub/Pack134HikeClubTests/ModelsTests.swift:12-97
- Pack134HikeClub/Pack134HikeClubTests/CeremoniesTests.swift:34-90

### Code
- Pack134HikeClub/Pack134HikeClub/Models.swift:15-123 (HikeQuality, ScoutQuality, BadgeType)
- Pack134HikeClub/Pack134HikeClub/Awards.swift
- Pack134HikeClub/Pack134HikeClub/Ceremonies.swift:11-25

## Architecture

**Purpose:** Answer "what has this scout earned?" as a pure function of hikes, attendance, and the badge catalog — so the answer is always current and never needs migrating.

**Key Components:**
1. Badge catalog — `BadgeType`, `HikeQuality`, `ScoutQuality` and the hand-kept mappings between them (`badgeType`, `hikeQuality`, `mileageThreshold`)
2. `Scout.earnedBadges(completedHikes:)` — the derivation: seeded ∪ mileage ∪ 10-mile-massacre ∪ hike qualities ∪ Pack Mule
3. `Scout.cumulativeMileage(completedHikes:)` — startingMileage + attended complete-hike mileage
4. `Scout.pendingBadges` / `hasPendingStick` — earned minus given; the input to every ceremony view

## Spec Coverage

*(specs not yet drafted — regenerate this table after `award-derivation-specs.md` lands)*

## Key Findings

1. **Deliberately uncached, O(hikes×scouts) per render** — `Awards.swift:9` `ponytail:` comment records this as a sized decision for pack-scale data, with caching as the named upgrade path.
2. **Only `complete` + attended hikes count** — `Awards.swift:14-17`. In-progress and recap hikes contribute nothing to mileage or qualities.
3. **`tenMileMassacre` is intentionally absent from `HikeQuality`** — `Models.swift:27` documents it as derived from `hike.mileage >= 10` rather than manually flagged.
4. **Two different identity comparisons in one file** — `persistentModelID` at `Awards.swift:16` vs. `ObjectIdentifier` at `:21-22`. No comment explains the split; both appear to work but the inconsistency is unexplained. `[inferred]`
5. **The earned set can shrink** — deleting or reopening a hike lowers derived mileage and drops qualities, so `earnedBadges` can contract while `givenBadges` (persisted) does not. Nothing detects or reports the resulting given-but-no-longer-earned state.
6. **`BadgeType.riverRunner` has raw value `"river"`** — `Models.swift:56`. A historical name that is load-bearing for the `InventoryKind` 1:1 force-unwrap in `inventory`.

## Work Required

### Should Fix
1. Undefined behavior when the earned set shrinks below what was already given (finding 5) — substance sits here; obligation cascades to `award-handout`.

### Nice to Have
2. Reconcile the two identity-comparison idioms, or record why they differ (finding 4).
