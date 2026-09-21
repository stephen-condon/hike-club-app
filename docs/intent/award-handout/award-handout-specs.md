# Award Handout — EARS Specs

## Given Badges

- [x] **AWARD-HAND-001**: The system shall persist, per scout, the set of badges physically given to that scout.
- [x] **AWARD-HAND-002**: When the owner gives a scout a badge that scout has not been given, the system shall record that badge as given and decrement the count of the matching inventory kind.
- [x] **AWARD-HAND-003**: If the owner gives a scout a badge that scout has already been given, then the system shall record no duplicate and move no inventory.
- [x] **AWARD-HAND-004**: When giving a badge would take the matching inventory count below zero, the system shall set that count to zero and still record the badge as given.
- [x] **AWARD-HAND-005**: If no inventory row exists for a given badge's kind, then the system shall still record that badge as given.
- [x] **AWARD-HAND-006**: When the owner un-gives a badge that a scout was given, the system shall remove one occurrence of that badge from the scout's given badges and increment the count of the matching inventory kind.
- [x] **AWARD-HAND-007**: If the owner un-gives a badge that a scout was not given, then the system shall change nothing and move no inventory.

## Hiking Sticks

- [x] **AWARD-HAND-008**: The system shall record a scout's stick state at two levels: earned, meaning the decision was made, and assigned, meaning the stick was physically handed over.
- [x] **AWARD-HAND-009**: When the owner awards a scout a hiking stick, the system shall create a stick assignment for that scout, mark that scout's stick earned, and decrement the hiking-stick inventory count, taking that count no lower than zero.
- [x] **AWARD-HAND-010**: When the owner records a scout's hiking stick as returned, the system shall delete that scout's stick assignment and increment the hiking-stick inventory count.
- [x] **AWARD-HAND-011**: When a scout's hiking stick is returned, the system shall leave that scout's stick marked earned.

## Bulk Awarding

- [x] **AWARD-HAND-012**: When awarding all of a scout's pending items, the system shall give every pending badge and, where that scout's stick is pending, assign the stick, using the same give and assign operations as single awards.
- [x] **AWARD-HAND-013**: When awarding all of a scout's pending items, the system shall report exactly which badges were given and whether a stick was given.
- [x] **AWARD-HAND-014**: If awarding all pending items is repeated for a scout with nothing pending, then the system shall give nothing further and move no inventory.

## Independence from Derivation

- [x] **AWARD-HAND-015**: The system shall not automatically give a scout a badge when that scout earns it.
- [x] **AWARD-HAND-016**: The system shall not reserve or adjust inventory when a scout earns a badge, only when one is given.

## Scout Detail Presentation

- [x] **AWARD-HAND-017**: The scout detail view shall list every badge in the catalog, offering a give control for badges that are earned but not given and an un-give control for badges that are given.
- [x] **AWARD-HAND-018**: The scout detail view shall display badges that are neither earned nor given as inactive, with no give control.
- [x] **AWARD-HAND-019**: While a scout has no stick assignment, the scout detail view shall state whether that scout's stick is earned-but-not-awarded or not earned, and shall offer to award a stick.
- [x] **AWARD-HAND-020**: While a scout has a stick assignment, the scout detail view shall show the date it was assigned and shall offer to record the stick as returned.
