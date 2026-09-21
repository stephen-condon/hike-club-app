# Arrow: ceremonies

The bulk handout event — who gets what, whether stock covers it, and the reminders to prepare.

## Status

**MAPPED** — last audited 2026-09-20 (git SHA `d0f0493`). Reverse-engineered from code; LLD and EARS are skeletons awaiting flesh-out.

## References

### HLD
- docs/high-level-design.md (§ Ceremonies)

### LLD
- docs/intent/ceremonies/ceremonies-design.md

### EARS
- docs/intent/ceremonies/ceremonies-specs.md *(not yet drafted)*

### Tests
- Pack134HikeClub/Pack134HikeClubTests/CeremoniesTests.swift:182-364
- Pack134HikeClub/Pack134HikeClubTests/NotificationsTests.swift

### Code
- Pack134HikeClub/Pack134HikeClub/Models.swift:270-298 (Ceremony, CeremonyAward)
- Pack134HikeClub/Pack134HikeClub/Ceremonies.swift:52-116
- Pack134HikeClub/Pack134HikeClub/CeremoniesView.swift
- Pack134HikeClub/Pack134HikeClub/CeremonyDetailView.swift
- Pack134HikeClub/Pack134HikeClub/Notifications.swift

## Architecture

**Purpose:** Turn a pile of pending awards into one evening's handout — show what to buy beforehand, hand everything out at once, and keep a record of what each scout actually received.

**Key Components:**
1. `Ceremony` @Model — title, date, isComplete, and the awards snapshot; the pending roster is never stored on it
2. `ceremonyInventoryNeeds` / `ceremonyShortfalls` / `stickBuyCount` — the pre-ceremony shopping math
3. `completeCeremony` — awards each included scout via `awardAllPending`, snapshots a `CeremonyAward` per scout, marks complete
4. `CeremonyReminders` — local notifications 5 weeks out (badges) and 2 weeks out (sticks), nuke-and-repaved on launch and tab appear

## Spec Coverage

*(specs not yet drafted — regenerate this table after `ceremonies-specs.md` lands)*

## Key Findings

1. **Pending scouts are live-derived, never snapshotted at scheduling time** — `CeremonyDetailView.swift:20-22` recomputes on every render, so a ceremony scheduled today reflects awards earned tomorrow.
2. **Completion is per-scout all-or-nothing** — `Ceremonies.swift:105-113`. Toggled-off scouts are simply not passed in, stay pending, and reappear at the next ceremony.
3. **Exclusions live in view `@State`** — `CeremonyDetailView.swift:18`. Navigating away and back resets every scout to included, with no warning.
4. **Shortfall is below-need-plus-reserve, not below-need** — `Ceremonies.swift:77`. A kind is flagged when handing out would eat into the reserve, which is a stricter test than `InventoryItem.isLow`.
5. **`CeremonyAward` is the only historical record of ceremony contents** — `Models.swift:286-298`. Neither `earnedBadges` nor `givenBadges` records which ceremony gave what.
6. **Rescheduling nukes all pending notification requests** — `Notifications.swift:70`, justified by a `ponytail:` comment because the app schedules nothing else. Identifiers are only batch-unique (`:82`).
7. **`stickBuyCount` is pack-wide, not per-ceremony** — `Notifications.swift:24-25` documents that the same count goes into every stick reminder in a batch.
8. **Reschedule fires only at launch and on Ceremonies-tab appear** — `CeremoniesView.swift:68-74`; a `ponytail:` comment names per-mutation calls as the upgrade path if cross-tab accuracy is ever needed.
9. **Completion is one-way** — there is no inverse of `completeCeremony`, and `CeremonyDetailView.swift:47` locks the form once complete. A mis-clicked completion cannot be undone in-app, unlike a hike, which can be reopened.
10. **Deleting a scout leaves orphan award rows** — `CeremonyAward.scout` is nullify-on-delete (`Models.swift:289`), rendered as "Unknown Scout" (`CeremonyDetailView.swift:189`).

## Work Required

### Should Fix
1. Per-scout exclusions are lost on navigation (finding 3) — the one piece of ceremony-night state that is neither derived nor persisted.
2. No way to reopen a ceremony completed by mistake (finding 9); note the asymmetry with the reopenable hike lifecycle.

### Nice to Have
3. Record which ceremony gave a badge, so a scout's history is walkable from either end (finding 5).
