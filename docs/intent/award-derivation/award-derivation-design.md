---
parent: high-level-design
prefix: AWARD-DERV
---

# Award Derivation

## Context and Design Philosophy

A scout's badges are a *question*, not a record. "What has Alex earned?" is answered by looking at the hikes Alex attended and applying the pack's rules — every time it is asked, from scratch. Nothing about earned status is stored, so nothing about it can go stale, drift, or need migrating when a rule changes or a hike is corrected.

This is the app's central bet. It costs O(hikes × scouts) on every render and buys the guarantee that the answer is always consistent with the data. `Awards.swift:9` records the bet as a sized decision — pack-scale data makes the cost invisible, and caching is the named upgrade if it ever isn't.

The badge catalog is the other half of the segment: the enum web that says what is earnable at all, and how a condition observed on the trail becomes a badge on a shirt.

## The Badge Catalog

Four enums cross-reference each other, three of them owned here:

- `HikeQuality` — conditions manually flagged (or imported) on a hike; each maps 1:1 to a badge via `badgeType`
- `ScoutQuality` — per-attendance qualities; currently `.backpack` alone, mapping to Pack Mule
- `BadgeType` — the full catalog, with `displayName`, `mileageThreshold`, and the reverse `hikeQuality` mapping
- `InventoryKind` — owned by [[inventory]], but raw-value-aligned 1:1 with `BadgeType` by construction

Adding a badge means touching all four and keeping the mappings in sync. `BadgeType.riverRunner` carries the raw value `"river"` (`Models.swift:56`) — a historical name that must be preserved on both sides of the `BadgeType`↔`InventoryKind` alignment.

`tenMileMassacre` is deliberately absent from `HikeQuality` (`Models.swift:27`): it is derived from `hike.mileage >= 10`, not flagged by hand.

## Derivation

`Scout.earnedBadges(completedHikes:)` (`Awards.swift:32-68`) unions five sources:

1. **Seeded** — `seededEarnedBadges` from the CSV, always included
2. **Mileage** — every `BadgeType` whose `mileageThreshold` is at or below cumulative mileage
3. **10-Mile Massacre** — any attended completed hike of 10+ miles
4. **Hike qualities** — every `HikeQuality` on any attended completed hike, mapped through `badgeType`
5. **Pack Mule** — `.backpack` recorded on any attended completed hike's attendance

`Scout.cumulativeMileage(completedHikes:)` is `startingMileage` plus the sum of attended completed hikes' `mileage`.

### What counts

A hike contributes only when it is **both** `complete` and attended by the scout (`Awards.swift:14-17`). In-progress and recap hikes contribute nothing — mileage does not accrue until the hike is locked in.

**Current-state divergence:** the file uses two identity idioms — `persistentModelID` in `completedHikes` (`:16`) and `ObjectIdentifier` in `attendedHikes` (`:21-22`). Both work against the callers in use; no comment explains why they differ.

## Pending Awards

`Scout.pendingBadges(completedHikes:)` is `earnedBadges` minus `givenBadges` — the set difference between what the rules say and what was physically handed over. `hasPendingStick` is the same shape for the stick: `stickEarned && stickAssignment == nil`.

These are the inputs every ceremony view reads. They are derived on the same terms as everything else here: computed on read, never stored, never snapshotted.

## Decisions & Alternatives

| Decision | Chosen | Alternatives Considered | Rationale |
|----------|--------|------------------------|-----------|
| Badge storage | Derived on every read | Persisted with recompute-on-change; cached with invalidation | Correcting a hike immediately corrects every downstream total, with no sync step that can fail |
| Cost | Accept O(hikes × scouts) | Memoize; cache per scout | Pack-scale data; `ponytail:` at `Awards.swift:9` names caching as the upgrade if measured slow |
| Badge catalog | Four hand-synced enums | One enum with associated data; a data-driven table | `[inferred]` — the mappings are exhaustive `switch`es, so the compiler catches a missing case |
| 10-Mile Massacre | Derived from mileage | A `HikeQuality` toggle | It is a measurement, not an observation; `Models.swift:27` records this explicitly |
| `riverRunner` raw value | `"river"` | Rename to `"riverRunner"` | Load-bearing for the `InventoryKind` alignment; renaming would need a store migration |
| Hike eligibility | `complete` **and** attended | Any status; attended only | Mileage should not accrue from a hike still being edited |
| Seeded badges | Unioned in, never re-derived | Converted to synthetic hikes | Pre-app history has no hikes to attach to |
| Pending as a set difference | `earned − given` | A persisted pending queue | A queue would need reconciling; the difference cannot drift |

## Open Questions & Future Decisions

### Deferred
1. **The earned set can shrink.** Deleting or reopening a hike lowers mileage and drops qualities, so `earnedBadges` can contract while `givenBadges` does not. Nothing detects the resulting given-but-no-longer-earned state, and `ScoutDetailView.swift:55` renders such a badge indistinguishably from a legitimately earned one. The substance of this decision sits here; [[award-handout]] and [[hikes]] carry the obligation.
2. **Two identity idioms in one file.** Reconcile, or record why they differ.
3. **Mileage thresholds stop at 100.** `BadgeType` has `mile10` through `mile100`. What happens past 100 miles is unspecified.
4. **Qualities are all-or-nothing per hike.** A scout who joined a hike late still earns every quality flagged on it. Whether per-attendance quality overrides are ever wanted is undecided.
5. **No badge is ever revoked by derivation alone** — but see (1); the current behavior is silent contraction, not revocation.

## References

- `Pack134HikeClub/Pack134HikeClub/Models.swift:15-123`, `Awards.swift`, `Ceremonies.swift:11-25`
- Arrow doc: `docs/arrows/award-derivation.md`
- Related: [[award-handout]], [[inventory]], [[hikes]], [[ceremonies]]
