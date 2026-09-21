---
parent: high-level-design
prefix: INV
---

# Inventory

## Context and Design Philosophy

There is a box of badges and a bundle of hiking sticks in someone's garage, and this segment's job is to know what is in it. That is the whole scope: a count per kind, a threshold below which the owner wants warning, and a red number when the two cross.

Inventory never blocks anything. A scout who earned a badge gets the badge whether or not the count says there is one — `requirements.md` is explicit that minimums do not prevent awarding. The count is a shopping aid, not a gate, which is why every decrement floors at zero rather than refusing.

Stock moves two ways: by hand when a box arrives, and automatically when [[award-handout]] gives something away.

## The Kinds

`InventoryKind` (`Models.swift:125-134`) is one case per `BadgeType` plus `hikingStick`. The raw values are aligned 1:1 with `BadgeType` by construction, including `riverRunner = "river"` on both sides.

That alignment is what lets `BadgeType.inventoryKind` be a force-unwrapped `InventoryKind(rawValue: rawValue)!` (`Models.swift:121`). The invariant is not enforced by the type system — it is asserted across every case by `ModelsTests.swift:87`, so the unwrap is guarded by test rather than by compiler. Adding a `BadgeType` without its `InventoryKind` twin compiles and crashes at runtime.

`displayName` reflects the same borrowing: everything but `hikingStick` defers to `BadgeType(rawValue:)?.displayName` (`Models.swift:138`).

## The Item

`InventoryItem` (`Models.swift:244-257`) holds `kind`, `count`, and `minReserve`, with `isLow` as `count < minReserve`.

Seeding creates one row per kind at `count: 0, minReserve: 0` on first launch (`Seed.swift:81-86`), guarded independently of scout seeding so the two can be added in either order.

**Current-state divergence:** because `minReserve` defaults to 0, `isLow` is false at zero stock. A freshly seeded app shows no warnings anywhere until the owner sets reserves by hand.

## Two Notions of Low

The app has two different low-stock tests, and they disagree by design or by accident — it is not recorded which:

| Test | Formula | Where |
|------|---------|-------|
| `isLow` | `count < minReserve` | `Models.swift:250`, drives the red count in `InventoryView` |
| shortfall | `count - need < minReserve` | `Ceremonies.swift:77`, drives "Buy N" in a ceremony |

The ceremony test is strictly stronger: it asks whether handing out the pending awards would eat into the reserve. A kind can therefore read black in the Inventory tab and red in a ceremony on the same day.

## Editing

`InventoryView` lists badges in `InventoryKind` declaration order (mileage → quality → packMule) via `orderedBadgeItems`, and hiking sticks separately via `equipmentItems`. Both are free functions so they can be tested without a view.

Counts move by stepper buttons with a zero floor (`InventoryView.swift:76`), matching `ScoutActions`. `minReserve` is edited in a sheet, capped at 999.

## Decisions & Alternatives

| Decision | Chosen | Alternatives Considered | Rationale |
|----------|--------|------------------------|-----------|
| Scope | Count + reserve per kind | Per-item records; purchase orders; supplier links | `requirements.md` asks for "a basic inventory tracking system" |
| Reserve semantics | Warn only, never block | Block awarding below reserve; require confirmation | A scout who earned a badge must get it regardless of the count |
| Kind alignment | Raw values 1:1 with `BadgeType` | Explicit mapping table; shared enum | Makes `inventoryKind` a one-liner, at the cost of a runtime-only invariant |
| Invariant enforcement | Exhaustive test | Compile-time mapping; non-optional init | `[inferred]` — the test exists and covers every case; whether the force-unwrap was weighed against a total mapping is unrecorded |
| Seed values | 0 count, 0 reserve | Prompt on first launch; non-zero defaults | `[inferred]` — simplest seed; leaves the low-stock signal inert until configured |
| Decrement floor | Floor at 0 | Allow negative to signal debt | A negative count of physical objects has no meaning here |
| Two low-stock tests | Both retained | One shared definition | `[inferred]` — they serve different questions but nothing records the choice |
| Ordering | `InventoryKind` declaration order | Alphabetical; by count | Groups mileage badges together, which is how the box is organized |

## Open Questions & Future Decisions

### Deferred
1. **Reconcile the two low-stock definitions**, or name why the Inventory tab and a ceremony should be allowed to disagree. Cascades into [[ceremonies]].
2. **`minReserve` defaults to 0**, so the feature the owner asked for is off until configured per kind. A non-zero seed or a first-run prompt would make it live.
3. **The 1:1 invariant is runtime-only.** Whether to make it structural (a non-optional mapping, or one enum with a computed split) is undecided.
4. **No audit trail.** A count change looks the same whether it came from a stepper tap or an award. The pack cannot reconstruct why stock moved.
5. **No purchase tracking.** "Buy 6" appears in ceremonies and reminders but nothing records that an order was placed, so the number persists until stock physically arrives and is entered.

## References

- `Pack134HikeClub/Pack134HikeClub/Models.swift:125-140,244-257`, `InventoryView.swift`, `Seed.swift:81-86`
- Arrow doc: `docs/arrows/inventory.md`
- Related: [[award-handout]], [[ceremonies]], [[award-derivation]]
