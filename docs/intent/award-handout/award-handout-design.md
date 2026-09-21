---
parent: high-level-design
prefix: AWARD-HAND
---

# Award Handout

## Context and Design Philosophy

[[award-derivation]] answers what a scout has earned. This segment answers a different question: what did we actually put in their hand, and what did that cost the supply box?

Keeping the two apart is deliberate. Earning is a rule; handing over is an event. A scout can earn a badge months before a ceremony, and the pack needs to know both facts at once — which is why `givenBadges` is the only persisted badge state in the app, and why nothing automatically reconciles it against the derived earned set.

Every handout moves inventory, and there is exactly one mechanism for it. The bulk ceremony path calls the same functions as the single-badge button in `ScoutDetailView`, so the supply count cannot diverge based on which door the badge went out of.

## Persisted Handout State

| Field | Meaning |
|-------|---------|
| `Scout.givenBadges` | Badges physically handed over; append to give, remove to un-give |
| `Scout.stickEarned` | The ceremony decision that this scout should get a stick |
| `Scout.stickAssignment` | The physical award; non-nil means the stick is in their hands |

Sticks are two-level on purpose. `stickEarned` records the decision; `stickAssignment` records the object. `returnStick` clears only the assignment (`ScoutActions.swift:43-49`), dropping the scout back to earned-but-not-awarded rather than un-earning them — a returned stick is a stick to re-issue, not a revoked honor.

## The Four Actions

`ScoutActions.swift` holds the whole mechanism:

- **`giveBadge`** — no-ops if already given; otherwise appends and decrements the matching `InventoryItem`, floored at 0
- **`ungiveBadge`** — no-ops if not given; otherwise removes the first occurrence and increments inventory
- **`assignStick`** — inserts a `StickAssignment`, sets both stick fields, decrements hiking-stick inventory, floored at 0
- **`returnStick`** — clears the assignment, deletes it, increments inventory

`Scout.awardAllPending` (`Ceremonies.swift:29-46`) is the bulk wrapper: it reads pending badges and stick from `award-derivation`, calls the same four actions, and returns exactly what it gave so [[ceremonies]] can snapshot it.

### Inventory coupling

Handout is the only thing that moves inventory automatically. There is no reverse sync — earning a badge does not reserve stock, and stock changes do not affect what a scout is shown as having.

**Current-state divergence:** the zero floor makes give and un-give asymmetric. Giving a badge when the count is 0 leaves the count at 0; un-giving it then increments to 1, inventing an item that was never there. `ActionsTests.swift:141` covers the round trip only above the floor; `:55` covers the floor in isolation. The crossing case is untested and its intended behavior unrecorded.

## Decisions & Alternatives

| Decision | Chosen | Alternatives Considered | Rationale |
|----------|--------|------------------------|-----------|
| Handout state | `givenBadges` persisted, earned derived | Both persisted; both derived | Handing over is an event with no rule to derive it from |
| Earned↔given sync | None | Auto-give on earn; warn on divergence | The gap between earning and receiving is real and months long |
| Inventory movement | Inline in the give/assign call | Separate inventory transaction; event log | One code path means one place the count can be wrong |
| Inventory floor | `max(0, count - 1)` | Allow negative; block the give | A badge handed from an uncounted stash should not make the count negative — and must never block an award |
| Floor asymmetry | Un-give always increments | Track whether the give was floored | `[inferred]` — behavior falls out of the floor; no evidence it was chosen |
| Stick levels | `stickEarned` + `stickAssignment` | One boolean; assignment only | Mirrors the badge earned/given split so ceremonies treat both the same |
| `returnStick` | Leaves `stickEarned` true | Clears both | A returned stick is re-issuable, not un-earned |
| Bulk awarding | Reuses the single-award actions | A separate batch path | Guarantees the ceremony and the detail page cannot disagree |
| Un-give | Removes first occurrence | Remove all; forbid duplicates structurally | `givenBadges` is an array; `giveBadge` prevents duplicates, so first-occurrence is sufficient |

## Open Questions & Future Decisions

### Deferred
1. **Inventory asymmetry across the zero floor.** Should un-giving a badge whose give was floored be a no-op? Resolving this turns an `[inferred]` Decisions row into an authored one.
2. **Given but no longer earned.** When a hike is deleted or reopened, a scout can hold a badge the rules no longer justify. Nothing detects it, and `ScoutDetailView.swift:55` renders it as normal. Cascaded from [[award-derivation]].
3. **`assignStick` sets `stickEarned = true` unconditionally** (`ScoutActions.swift:36`), and `ScoutDetailView.swift:87-91` offers the button regardless of whether the scout earned one. Awarding is therefore also a way to *make* a stick earned. Whether that is a convenience or a gap is undecided.
4. **No handout history.** `givenBadges` is a set of badges with no dates. Only [[ceremonies]] records when something was handed over, and only for awards that went through a ceremony.
5. **No confirmation on un-give.** A mis-tap silently increments inventory and removes the badge.

## References

- `Pack134HikeClub/Pack134HikeClub/ScoutActions.swift`, `Models.swift:153,155,259-268`, `Ceremonies.swift:29-46`, `ScoutDetailView.swift:48-93,123-171`
- Arrow doc: `docs/arrows/award-handout.md`
- Related: [[award-derivation]], [[inventory]], [[ceremonies]]
