# Scouts — EARS Specs

## The Scout Record

- [x] **SCOUT-001**: The system shall store for each scout a name, a pre-app starting mileage, an active flag, and a date added.
- [x] **SCOUT-002**: The system shall include a scout's starting mileage in every derived cumulative mileage total for that scout.
- [x] **SCOUT-003**: The scout model shall declare that deleting a scout cascade-deletes that scout's attendance records.
- [x] **SCOUT-004**: The scout model shall declare that deleting a scout nulls that scout's references from stick assignments and ceremony award records rather than deleting those records.
- [x] **SCOUT-026**: The system shall provide no operation for deleting a scout; archiving is the supported way to remove a scout from the roster.
- [ ] **SCOUT-043**: The scout detail view shall allow the owner to edit that scout's name.
- [ ] **SCOUT-044**: When the owner edits a scout's name, the system shall trim surrounding whitespace and newlines from it and shall reject a name that is empty after trimming.

## Roster Import — Seeding

- [x] **SCOUT-005**: When a fetch of the scout table at app launch succeeds and returns no scouts, the system shall seed the roster from the bundled Roster.csv.
- [x] **SCOUT-006**: While the scout table is non-empty at app launch, the system shall make no change to the roster.
- [ ] **SCOUT-027**: If fetching the scout table at app launch fails, then the system shall not seed the roster and shall record a roster import problem.
- [ ] **SCOUT-035**: When seeding the roster from Roster.csv, the system shall insert every accepted scout and then commit them all in a single save that covers the roster only, separate from inventory seeding.
- [ ] **SCOUT-036**: If Roster.csv is missing from the app bundle or cannot be read as UTF-8, then the system shall import no scouts and shall record a roster import problem.

## Roster Import — Header and Columns

- [x] **SCOUT-007**: When parsing Roster.csv, the system shall treat the first line as the header row and ignore blank lines.
- [ ] **SCOUT-028**: When parsing Roster.csv, the system shall locate the name, startingMileage, earnedBadges, and stick columns by their header names rather than by their position.
- [ ] **SCOUT-029**: If the Roster.csv header row has no name column, then the system shall import no scouts and shall record a roster import problem.
- [ ] **SCOUT-030**: When the Roster.csv header row omits an optional column (startingMileage, earnedBadges, or stick), the system shall treat that column as empty for every row.
- [ ] **SCOUT-031**: When parsing a Roster.csv row, the system shall trim surrounding whitespace from every column before interpreting it.

## Roster Import — Row Validation

- [ ] **SCOUT-034**: If a Roster.csv row's name column is empty after trimming, then the system shall refuse that row and record a roster import problem identifying it.
- [x] **SCOUT-009**: If a Roster.csv row's startingMileage column is absent, empty, or whitespace-only, then the system shall set that scout's starting mileage to zero.
- [ ] **SCOUT-032**: If a Roster.csv row's startingMileage column is present but is not a finite, non-negative number, then the system shall refuse that row and record a roster import problem identifying it.
- [ ] **SCOUT-010**: When parsing a Roster.csv row's earnedBadges column, the system shall split it on semicolons, trim each token, and record each recognized badge raw value as a seeded earned badge for that scout.
- [ ] **SCOUT-011**: If a Roster.csv row's earnedBadges column contains a token that is not a recognized badge raw value, then the system shall discard that token, record a roster import problem naming it, and continue importing the row.
- [x] **SCOUT-012**: When seeding a scout from Roster.csv, the system shall leave that scout's given badges empty, so seeded awards are earned but not yet handed out.
- [x] **SCOUT-013**: When a Roster.csv row's stick column is "has" in any letter case, the system shall mark that scout's stick earned and create a stick assignment for them.
- [x] **SCOUT-014**: When a Roster.csv row's stick column is "earned" in any letter case, the system shall mark that scout's stick earned without creating a stick assignment.
- [x] **SCOUT-015**: If a Roster.csv row's stick column is blank or absent, then the system shall mark that scout as neither having earned nor been awarded a stick.
- [ ] **SCOUT-033**: If a Roster.csv row's stick column holds a value other than "has", "earned", or blank, then the system shall mark that scout as neither having earned nor been awarded a stick and shall record a roster import problem naming the value.
- [x] **SCOUT-016**: When seeding a scout from Roster.csv, the system shall mark that scout active.
- [x] **SCOUT-017**: The system shall create scouts from Roster.csv in the order their rows appear.

## Roster Import — Diagnostics

- [ ] **SCOUT-037**: While roster import problems are recorded, the Scouts tab shall display them.
- [ ] **SCOUT-038**: When the owner dismisses the displayed roster import problems, the system shall clear them.
- [ ] **SCOUT-046**: The system shall retain recorded roster import problems across app launches until the owner dismisses them.

## Roster Display

- [x] **SCOUT-018**: The Scouts list shall show active scouts sorted by name, each with their cumulative mileage.
- [ ] **SCOUT-042**: The Scouts list shall show each archived scout's cumulative mileage.
- [x] **SCOUT-019**: While at least one archived scout exists, the Scouts list shall offer a control to show or hide an archived-scouts section.
- [x] **SCOUT-020**: The system shall persist the archived-scouts visibility preference across app launches.
- [x] **SCOUT-021**: The system shall derive mileage and badges for archived scouts on the same terms as for active scouts.
- [x] **SCOUT-022**: Where a scout is archived, the system shall exclude that scout from hike attendance lists and from ceremony pending-award lists.

## Archiving

- [x] **SCOUT-025**: The scout detail view shall allow the owner to move a scout between active and archived.
- [ ] **SCOUT-039**: When the owner archives an active scout, the system shall ask for confirmation before archiving that scout.
- [x] **SCOUT-040**: When the owner un-archives a scout, the system shall do so without asking for confirmation.
- [ ] **SCOUT-041**: When a scout is archived, the system shall turn on the persisted archived-scouts visibility preference.

## Manual Entry

- [x] **SCOUT-023**: When the owner adds a scout through the Scouts tab, the system shall create an active scout with zero starting mileage, no seeded badges, and no stick.
- [ ] **SCOUT-024**: While the new-scout name field is empty or contains only whitespace and newlines, the system shall disable saving that scout.
- [ ] **SCOUT-045**: When the owner saves a new scout, the system shall store that scout's name trimmed of surrounding whitespace and newlines.
