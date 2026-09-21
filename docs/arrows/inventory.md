# Arrow: inventory

Physical stock of badges and hiking sticks, and the low-stock signal.

## Status

**MAPPED** — last audited 2026-09-20 (git SHA `d0f0493`). Reverse-engineered from code; LLD and EARS are skeletons awaiting flesh-out.

## References

### HLD
- docs/high-level-design.md (§ Inventory)

### LLD
- docs/intent/inventory/inventory-design.md

### EARS
- docs/intent/inventory/inventory-specs.md *(not yet drafted)*

### Tests
- Pack134HikeClub/Pack134HikeClubTests/ModelsTests.swift:172-195
- Pack134HikeClub/Pack134HikeClubTests/ViewTests.swift:144-172,217-259
- Pack134HikeClub/Pack134HikeClubTests/SeedTests.swift:181-224

### Code
- Pack134HikeClub/Pack134HikeClub/Models.swift:125-140,244-257 (InventoryKind, InventoryItem)
- Pack134HikeClub/Pack134HikeClub/InventoryView.swift
- Pack134HikeClub/Pack134HikeClub/Seed.swift:81-86

## Architecture

**Purpose:** Track how many of each badge and how many hiking sticks are actually in the box, and flag when it is time to order more.

**Key Components:**
1. `InventoryKind` — one case per `BadgeType` plus `hikingStick`, raw-value-aligned 1:1 with `BadgeType` by construction
2. `InventoryItem` @Model — count, minReserve, and the derived `isLow`
3. `InventoryView` — manual increment/decrement with a zero floor, per-kind min-reserve editing
4. Inventory seeding — one row per kind at 0/0 on first launch

## Spec Coverage

*(specs not yet drafted — regenerate this table after `inventory-specs.md` lands)*

## Key Findings

1. **The 1:1 raw-value invariant is force-unwrapped** — `Models.swift:121` does `InventoryKind(rawValue: rawValue)!`, which would crash if a `BadgeType` case ever lacked an `InventoryKind` twin. The invariant *is* asserted across all cases by `ModelsTests.swift:87`, so the unwrap is guarded by test rather than by type.
2. **Two different notions of "low"** — `InventoryItem.isLow` is `count < minReserve` (`Models.swift:250`), while ceremony shortfall is `count - need < minReserve` (`Ceremonies.swift:77`). The same kind can read fine in Inventory and red in a ceremony.
3. **`minReserve` defaults to 0** — `Seed.swift:83` — so `isLow` can never fire until the owner sets a reserve by hand. A freshly seeded app shows no warnings at zero stock.
4. **Counts move by hand and by handout** — `InventoryView.swift:76,89` for manual edits, `ScoutActions` for award-driven decrements. No audit trail distinguishes them.
5. **Decrement floors at 0 in the UI too** — `InventoryView.swift:76` guards `count > 0`, matching `ScoutActions`.

## Work Required

### Should Fix
1. Reconcile the two low-stock definitions, or name why they differ (finding 2).

### Nice to Have
2. Seed a non-zero default `minReserve`, or prompt for one, so the low-stock signal is live from first launch (finding 3).
