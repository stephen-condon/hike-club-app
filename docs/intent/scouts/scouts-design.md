---
parent: high-level-design
prefix: SCOUT
---

# Scouts

## Context and Design Philosophy

The roster is the app's root datum: every mileage total, every badge, and every ceremony line item is derived from a `Scout` and the hikes that scout attended. It is also the one piece of data that predates the app — the pack already tracks its scouts in a spreadsheet, and scouts already have mileage and badges from before any of this existed. So the roster is designed around import rather than entry: the bundled CSV is the authority on first launch, and the in-app "add scout" path is the exception, not the rule.

That import is a trust boundary. The CSV is a hand-edited export from a spreadsheet maintained by someone else, and the app has exactly one chance to read it correctly — there is no second import. A row the parser misreads does not fail loudly on its own; it produces a scout with zero mileage and no badges who looks exactly like a new scout. So the parser validates rather than coerces, and every row it refuses is reported to the coordinator instead of being dropped.

Scouts leave the pack, but their history stays meaningful — a completed hike's attendance list should not develop holes when a scout ages out. The roster therefore archives rather than deletes, and archiving is reversible and visible.

## The Scout Record

`Scout` (`Models.swift:144-178`) holds:

- `name` — display identity, editable after creation; no separate id beyond SwiftData's `persistentModelID`
- `startingMileage` — miles walked before the app existed, added to every derived total
- `isActive` — roster visibility; archived scouts remain fully intact
- `dateAdded` — set at construction, not currently surfaced in any view
- `seededEarnedBadges` — badges earned before the app; folded into derivation, never re-awarded
- `givenBadges`, `stickEarned` — physical-handout state owned by [[award-handout]]
- `attendances` (cascade), `stickAssignment` (nullify) — relationships

A scout's name is editable from their detail page, trimmed of surrounding whitespace and newlines, and rejected when empty. A misspelling in the CSV, or a scout who starts going by a different name, is corrected in place — creating a replacement scout would orphan their attendance history.

**Current-state divergence:** no rename path exists. `ScoutDetailView.swift:36` renders the name as static text, and the only `TextField` in the segment is in `NewScoutSheet`.

### Removal

There is no delete path for a scout, by design. Archiving is the supported removal: it takes the scout out of attendance and ceremony lists while leaving completed hikes' history intact.

The cascade and nullify rules declared on `Scout`'s relationships (`Models.swift:156-157`) therefore describe how the model *would* behave under a delete, not an operation the app can reach.

## Roster Import

`Seed.seedIfNeeded` runs on every launch and seeds the roster only when a successful fetch returns an empty scout table. A fetch that throws is not treated as an empty table — it aborts seeding and is reported, because re-seeding on top of an existing roster produces a duplicate of every scout, and there is no delete path to clean that up.

Scouts are inserted and then committed in a single save that covers the roster only. A launch interrupted before that save leaves nothing persisted, so the next launch re-seeds from scratch rather than resuming into a half-written roster. Inventory seeding commits separately: a roster and a zero-count inventory are independent, and a failure in one should not cost the other.

`Roster.csv` is bundled and gitignored — real scout names are PII and stay out of version control.

### Column mapping

The header row is read, not discarded. Columns are located by name, so inserting or reordering columns in the source spreadsheet does not silently shift the data:

| Column | Required | Meaning |
|--------|----------|---------|
| `name` | yes | Display identity |
| `startingMileage` | no | Miles before the app; absent means zero |
| `earnedBadges` | no | `;`-separated `BadgeType` raw values |
| `stick` | no | `has`, `earned`, or blank |

If the `name` column is absent from the header, the import fails as a whole and is reported. A file with no header row fails this way rather than silently consuming its first scout as a header.

### Row validation

Every column is trimmed of surrounding whitespace before it is interpreted, so a spreadsheet that pretty-prints as `Ivy, 7.5, mile10` reads identically to one that does not. Trimming precedes every emptiness check: a whitespace-only `startingMileage` is empty and imports as zero, not an invalid number.

A row is refused, and reported, when:

- its `name` is empty after trimming
- its `startingMileage` is present but is not a finite number, or is negative

A row is accepted with a reported warning when its `earnedBadges` column holds a token that is not a recognized `BadgeType` raw value; the token is dropped and the rest of the row imports. A badge that fails to parse costs the scout one badge at the next ceremony, which is recoverable by hand — refusing the whole row would cost them their mileage too.

`stick` is matched case-insensitively: `has` marks the stick earned and creates a stick assignment, `earned` marks it earned only, and blank or any other value means neither. An unrecognized stick token is reported rather than silently treated as blank.

Seeded scouts are created active, in source-file order, with `givenBadges` empty — seeded awards are earned but not yet handed out, so they surface at the next ceremony.

### Import diagnostics

Parsing produces a list of human-readable problems alongside the scouts. Those problems, plus any whole-import failure, are persisted in `UserDefaults` and shown in the Scouts tab until the coordinator dismisses them — across relaunches, since seeding happens on a first launch during which the coordinator may never open the Scouts tab. Because the Scouts tab observes that stored value, it picks up problems whenever seeding finishes, regardless of whether the tab rendered first.

This is what makes the import a trust boundary rather than a coercion: a roster that imported with three refused rows says so, instead of presenting a short roster that looks correct.

**Current-state divergence:** none of this section's validation, header mapping, diagnostics, or atomic save exists yet. `Seed.swift` currently discards the header by position (`:31`), maps columns by index (`:36-49`), trims only the line and the stick column (`:32,48`), coerces any unparseable mileage to zero (`:38`), accepts an empty name (`:37`), treats a thrown fetch as an empty table (`:11-12`), returns silently when the file is missing or not UTF-8 (`:72-73`), and never saves explicitly (`:71-78`).

## Active and Archived

`ScoutsView` partitions on `isActive`. Active scouts are listed with their cumulative mileage; archived scouts appear in a secondary section behind a toolbar toggle whose visibility is itself persisted.

Archived scouts show their cumulative mileage too. Deciding what to order for a final ceremony means checking whether a scout who aged out finished a mileage badge, and that should not require opening each scout in turn.

Archiving asks for confirmation; un-archiving does not. Archiving is the one action in this segment that makes a scout disappear from the roster view and from every attendance and ceremony list, and the coordinator's most likely reading of an accidental tap is that the app lost a child. After a scout is archived, the persisted show-archived preference is turned on, so the scout is visibly somewhere rather than apparently gone. The toolbar toggle turns it back off.

Archived scouts still derive awards — `Pack134HikeClubTests.swift:97` pins this — so archiving is a roster-visibility concern and nothing more. Other segments query only active scouts (`HikeDetailView.swift:15`, `CeremonyDetailView.swift:14`, `Pack134HikeClubApp.swift:36-37`), so an archived scout is invisible to attendance and ceremonies while remaining fully derivable on their own detail page.

**Current-state divergence:** archived rows render as bare text with no mileage (`ScoutsView.swift:36`), and the archive toggle is a bare binding with no confirmation and no auto-reveal (`ScoutDetailView.swift:45`).

## Manual Entry

`NewScoutSheet` creates an active scout with zero starting mileage, no seeded badges, and no stick. Names are trimmed of whitespace *and newlines* before the empty check, so a pasted value that renders blank cannot be saved.

**Current-state divergence:** both the validation and the trim use `.whitespaces`, which excludes newlines (`ScoutsView.swift:100,123`), so a name consisting of a newline passes the check.

## Decisions & Alternatives

| Decision | Chosen | Alternatives Considered | Rationale |
|----------|--------|------------------------|-----------|
| Roster source | Bundled CSV, imported once | In-app entry only; JSON; a Swift literal | The pack's data already lives in a spreadsheet; CSV is the cheapest bridge and `requirements.md` names it explicitly |
| `Roster.csv` in git | Gitignored | Committed; committed with fake names | Real scout names are PII and must stay out of version control |
| Seed guard | Successful fetch returning empty | Any nil-or-empty fetch; version flag; migration record | A thrown fetch and an empty table are different facts; conflating them re-seeds over a live roster |
| Seed commit | Insert all, then one roster-only save | Save per scout; no explicit save; one save covering roster and inventory | An interrupted launch leaves nothing rather than a half-roster; keeping inventory out of the save means an inventory failure cannot roll back a good roster |
| Column mapping | By header name | By index (previous); positional with a fixed contract | The header is already in the file; reading it costs nothing and removes a whole class of silent misimport |
| Missing `name` column | Fail the whole import, reported | Fall back to index 0; skip silently | A file this wrong is a different file; guessing produces a plausible-looking wrong roster |
| Column trimming | Every column | Line only, plus the stick column (previous) | Inconsistent trimming meant the same spreadsheet imported differently depending on whether it pretty-printed |
| Invalid `startingMileage` | Refuse the row, reported | Coerce to zero (previous); accept NaN and infinity | A silent zero is indistinguishable from a genuinely new scout and propagates into every derived total |
| Unknown badge token | Drop it, report, keep the row | Refuse the row; accept silently (previous) | One missing badge is recoverable at a ceremony; losing the row loses the scout's mileage too |
| Empty `name` in a row | Refuse the row, reported | Accept it (previous) | `NewScoutSheet` already enforces non-empty; the import path should not be the weaker one |
| Import problems | Persisted and shown until dismissed | Logged only; alert at launch; this launch only | A launch-time alert is dismissed before it is read, and first-launch problems are the ones most likely to be missed |
| Name after creation | Editable in place | Immutable (previous); delete and recreate | Recreating orphans the scout's attendance history |
| Rename and ceremony history | Past ceremony records show the current name | Snapshot the name into each ceremony award | Renames are mostly typo corrections, where updating history is wanted; a snapshot would need a schema change in [[ceremonies]] |
| Removing a scout | Archive only; no delete path | Hard delete; soft-delete timestamp | Deleting would cascade attendances and hollow out completed hikes' history |
| Archive confirmation | Confirm on archive, not un-archive | Neither; both | Archiving is the only action here that makes a scout vanish from other tabs |
| Reveal after archiving | Turn on the persisted show-archived preference | Reveal for the session only | One setting to reason about, and the toolbar toggle reverses it |
| Archived row content | Same mileage as active rows | Name only (previous) | Final-ceremony ordering needs mileage for scouts who have aged out |
| Name trimming | Whitespace and newlines | Whitespace only (previous) | A pasted newline renders blank but passed the non-empty check |
| Pre-app badges | Seed as earned, not given | Seed as both earned and given | Seeded awards should surface at the next ceremony as things still to hand out |

## Open Questions & Future Decisions

### Resolved
1. ✅ **Roster import is a validating trust boundary, not a coercing one.** Refused rows and dropped tokens are reported to the coordinator rather than silently producing a plausible-but-wrong roster.
2. ✅ **No delete path for scouts.** Archiving is the supported removal; the relationship delete rules describe model behavior, not a reachable operation.
3. ✅ **Names are editable after creation**, because recreating a scout orphans their history.

### Deferred
1. **Name sort order depends on store collation.** `sort: \Scout.name` defers to SwiftData/SQLite, so a lowercase or accented name can sort away from where a coordinator scanning alphabetically expects it. Whether to impose case-insensitive, locale-aware ordering is undecided.
2. **No re-import path.** Editing `Roster.csv` after a successful first launch has no effect. A mid-season transfer-in with prior mileage still cannot be entered correctly, since `NewScoutSheet` creates scouts at zero. Validating the import does not solve this — it only makes the first import trustworthy.
3. **`dateAdded` is written and never read.** Either it is for a future "joined the pack" display or it is vestigial.
4. **Scout identity is the name string.** Two scouts with the same name are distinguishable only by `persistentModelID`.

### Cascade to [[inventory]]
1. **Inventory seeding conflates a failed fetch with an empty table**, exactly as roster seeding did: `Seed.swift:16-17` uses `try?` with `?? true`, so a thrown inventory fetch re-seeds a zero-count row per kind alongside existing counts. The roster fix (seed only on a successful empty fetch) is the likely shape. Not propagated: `inventory` owns its seeding specs.

### Cascade to [[hikes]]
1. **Archiving a scout strands their attendance on an in-progress or recap hike.** Those hikes list active scouts only (`HikeDetailView.swift:15,113`), so an archived scout already marked present disappears from the list while their attendance still counts at completion, and cannot be un-marked. Completed hikes are unaffected, since they list `hike.attendances` directly (`:121`). Not propagated: attendance display belongs to `hikes`.

### Cascade to [[award-handout]]
1. **Seeded stick assignments carry a fabricated award date.** A scout imported with `stick=has` gets `dateAssigned = .now` (`Seed.swift:61-63`, `Models.swift:264`), so every pre-app stick reads "Since \<first-launch date\>". The substance of the fix sits in `award-handout`, which owns `StickAssignment` — most likely making `dateAssigned` optional, with nil meaning "awarded before the app". This segment's obligation is to pass nil when seeding. Not propagated: it is a schema change in another segment's territory.

## References

- `Pack134HikeClub/Pack134HikeClub/Models.swift:144-178`, `Seed.swift`, `ScoutsView.swift`, `ScoutDetailView.swift:31-46,95-121`
- Arrow doc: `docs/arrows/scouts.md`
- Downstream consumers: [[award-derivation]], [[award-handout]], [[hikes]], [[ceremonies]]
