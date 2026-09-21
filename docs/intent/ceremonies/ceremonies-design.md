---
parent: high-level-design
prefix: CEREM
---

# Ceremonies

## Context and Design Philosophy

Badges accumulate quietly for weeks and then get handed out in one evening in front of the pack. This segment is built around that evening: what to buy before it, who to call up during it, and what to remember about it afterward.

The central decision is that a ceremony holds no list. It stores a title, a date, and whether it happened — the set of scouts with something coming is derived fresh every time the ceremony is opened. A ceremony scheduled in October and held in November automatically includes the badges earned in between, and nothing has to be re-synced when a hike is corrected.

The second decision is that ceremony night is about attendance, not editing. Everyone with something pending is included by default; the owner's only job is to switch off the scouts who didn't show. Those scouts stay pending and turn up at the next ceremony on their own.

## Live Derivation

`CeremonyDetailView.pendingScouts` (`:20-22`) filters active scouts on `hasPendingAwards`, which comes from [[award-derivation]]. Nothing is snapshotted at scheduling time.

`ceremonyInventoryNeeds(scouts:hikes:)` counts, per `InventoryKind`, one item for every pending badge and one hiking stick per scout with a pending stick.

`ceremonyShortfalls(needs:inventory:)` flags a kind when `count - need < minReserve` — below need *plus* reserve, a stricter test than `InventoryItem.isLow` (see [[inventory]]). Each shortfall carries `buy = need + minReserve - count`.

`stickBuyCount(scouts:hikes:inventory:)` pulls the hiking-stick `buy` out of that list, or 0. It is pack-wide rather than per-ceremony, which matters for reminders.

## Completion

`completeCeremony` (`Ceremonies.swift:97-116`):

1. For each scout passed in, call `awardAllPending` — which gives every pending badge and assigns a pending stick through [[award-handout]], moving inventory
2. Snapshot a `CeremonyAward` per scout who actually received something, attached to the ceremony
3. Mark the ceremony complete

Scouts not passed in are untouched. The view supplies `pendingScouts.filter(isIncluded)` (`CeremonyDetailView.swift:107`), so toggling a scout off means they simply never enter the function. Completion is per-scout all-or-nothing: there is no partial award within a scout.

`CeremonyAward` (`Models.swift:286-298`) is the only persisted record of what a ceremony contained. `givenBadges` knows a badge was handed over; only the award row knows which evening it happened on.

**Current-state divergence:** the exclusion set is view `@State` (`CeremonyDetailView.swift:18`). Navigating away and back resets every scout to included.

**Current-state divergence:** completion is one-way. There is no inverse of `completeCeremony`, and the form locks at `:47` — unlike a hike, which reopens.

## Reminders

`CeremonyReminders` (`Notifications.swift`) schedules two local notifications per planned ceremony: order badges 5 weeks out, buy hiking sticks 2 weeks out, both at 9 AM local. Only future fire dates for incomplete ceremonies produce reminders.

The stick reminder body carries the live `stickBuyCount`, or "You have enough hiking sticks on hand." at zero.

`reschedule` cancels all pending requests and re-adds the current set (`:68-85`) — safe because the app schedules nothing else, as a `ponytail:` comment records. Identifiers are only batch-unique (`ceremony-0`, `ceremony-1`, …), which is sufficient under nuke-and-repave.

It runs at app launch ([[app-shell]]) and on `CeremoniesView.onAppear`, which together cover create, edit, delete, and complete whenever the owner returns to the tab. A `ponytail:` comment at `CeremoniesView.swift:68` names per-mutation scheduling as the upgrade if cross-tab immediacy is ever needed.

`upcoming(for:sticksToBuy:now:)` is pure and unit-tested; the `UNUserNotificationCenter` calls are not.

## Decisions & Alternatives

| Decision | Chosen | Alternatives Considered | Rationale |
|----------|--------|------------------------|-----------|
| Ceremony contents | Live-derived every view | Snapshot at scheduling; editable list | A ceremony scheduled weeks ahead should include what is earned by the time it happens |
| Scout inclusion | All pending, toggle off | Opt-in; per-badge selection | The realistic failure is a scout not showing up, not a scout getting the wrong badge |
| Award granularity | Per-scout all-or-nothing | Per-badge within a scout | A scout who is present receives everything they are owed |
| Excluded scouts | Stay pending, reappear later | Mark deferred; carry to a named next ceremony | Falls out of live derivation with no extra state |
| Exclusion storage | View `@State` | Persisted on the ceremony | `[inferred]` — ephemeral by implementation, not by recorded choice |
| Awarding path | Reuses `ScoutActions` | A ceremony-specific award routine | Inventory correctness cannot depend on which path was taken |
| Historical record | `CeremonyAward` snapshot | Derive from `givenBadges`; nothing | `givenBadges` has no dates, so history is underivable |
| Shortfall test | Below need **plus** reserve | Below need | Handing out should not silently eat the reserve |
| `stickBuyCount` scope | Pack-wide | Per-ceremony | Pending awards are derived across the whole roster; documented at `Notifications.swift:24-25` |
| Reminder lead times | 5 weeks badges, 2 weeks sticks | Configurable; one reminder | Matches badge order turnaround and local stick availability |
| Rescheduling | Nuke and repave | Diff and patch | Only the app's own notifications exist; `ponytail:` at `Notifications.swift:67` |
| Reschedule triggers | Launch + tab appear | After every mutation | `ponytail:` at `CeremoniesView.swift:68` names the upgrade |
| Completion | One-way | Reopenable like a hike | `[inferred]` — no inverse exists; whether that is deliberate is unrecorded |

## Open Questions & Future Decisions

### Deferred
1. **Exclusions are lost on navigation.** The one piece of ceremony-night state that is neither derived nor persisted. If the owner toggles off four absent scouts and taps into a scout's detail page, all four return.
2. **No way to reopen a completed ceremony.** A mis-tapped "Complete Ceremony" hands out everything pending with no undo, and the asymmetry with the reopenable hike lifecycle is unexplained. The HLD tenet *every mistake is reversible* leans toward making completion reopenable; what reopening should do to the awards already handed out and the inventory already decremented is the open part.
3. **Which ceremony gave which badge is only walkable one way.** From a ceremony you can see its awards; from a scout you cannot see which ceremony gave a badge.
4. **Orphan award rows.** `CeremonyAward.scout` is nullify-on-delete (`Models.swift:289`), so deleting a scout leaves "Unknown Scout" rows in past ceremonies (`CeremonyDetailView.swift:189`).
5. **Reminders carry a pack-wide stick count into a per-ceremony message.** With two planned ceremonies, both stick reminders quote the same number.
6. **No reminder for a ceremony scheduled inside the lead window.** A ceremony three weeks out gets the stick reminder but never the badge reminder, silently.

## References

- `Pack134HikeClub/Pack134HikeClub/Ceremonies.swift:52-116`, `Models.swift:270-298`, `CeremoniesView.swift`, `CeremonyDetailView.swift`, `Notifications.swift`
- Arrow doc: `docs/arrows/ceremonies.md`
- Related: [[award-derivation]], [[award-handout]], [[inventory]], [[app-shell]]
