# Ceremonies — EARS Specs

## Ceremony Record

- [x] **CEREM-001**: The system shall store a ceremony as a title, a date, a completion flag, and the awards handed out at it.
- [x] **CEREM-002**: The Ceremonies list shall show incomplete ceremonies soonest-first and complete ceremonies most-recent-first, in separate sections.
- [x] **CEREM-003**: The system shall allow the owner to delete an incomplete ceremony from the Ceremonies list.
- [x] **CEREM-004**: While the new-ceremony title field is empty or contains only whitespace, the system shall disable saving that ceremony.
- [x] **CEREM-005**: While a ceremony is not complete, the system shall allow the owner to edit that ceremony's title and date.

## Pending Scouts

- [x] **CEREM-006**: The system shall derive a ceremony's pending scouts each time that ceremony is viewed, rather than recording them when the ceremony is scheduled.
- [x] **CEREM-007**: While a ceremony is not complete, the system shall list every active scout who has at least one pending badge or a pending stick, naming what each is owed.
- [x] **CEREM-008**: While a ceremony is not complete, the system shall include every pending scout by default and allow the owner to exclude individual scouts from it.
- [x] **CEREM-009**: While a ceremony is not complete and no active scout has a pending award, the system shall say that no scouts have pending awards.

## Inventory Readiness

- [x] **CEREM-010**: The system shall compute a ceremony's inventory needs as one item per pending badge plus one hiking stick per scout with a pending stick, counted across the scouts that ceremony lists.
- [x] **CEREM-011**: The system shall flag an inventory kind as short for a ceremony when handing out that ceremony's needed quantity would leave the on-hand count below that kind's minimum reserve.
- [x] **CEREM-012**: When an inventory kind is short for a ceremony, the system shall show the quantity to buy as the need plus the minimum reserve, less the on-hand count.
- [x] **CEREM-013**: The system shall flag an inventory kind as short for a ceremony when its on-hand count is below its minimum reserve even where that ceremony needs none of that kind.
- [x] **CEREM-014**: If no inventory row exists for a kind a ceremony needs, then the system shall omit that kind from that ceremony's shortfall list.

## Completion

- [x] **CEREM-015**: When the owner completes a ceremony, the system shall award every pending badge and pending stick to each scout included in that ceremony, using the same give and assign operations as single awards.
- [x] **CEREM-016**: When the owner completes a ceremony, the system shall record one award snapshot per included scout who received at least one item, naming the badges given and whether a stick was given.
- [x] **CEREM-017**: When the owner completes a ceremony, the system shall leave excluded scouts' pending awards untouched, so those scouts appear at the next ceremony.
- [x] **CEREM-018**: When the owner completes a ceremony, the system shall mark that ceremony complete even where no scout received anything.
- [x] **CEREM-019**: While a ceremony is complete, the system shall display that ceremony's title, date, and awards given, all read-only.
- [x] **CEREM-020**: While a ceremony is complete and recorded no awards, the system shall say that no awards were given.
- [x] **CEREM-021**: While a ceremony is complete, the system shall list its award snapshots sorted by scout name.

## Reminders

- [x] **CEREM-022**: For each incomplete ceremony, the system shall schedule a local reminder to order badges five weeks before that ceremony's date at 9 AM local time.
- [x] **CEREM-023**: For each incomplete ceremony, the system shall schedule a local reminder to buy hiking sticks two weeks before that ceremony's date at 9 AM local time.
- [x] **CEREM-024**: The system shall schedule a ceremony reminder only where that reminder's fire time is in the future.
- [x] **CEREM-025**: The system shall schedule no reminders for a complete ceremony.
- [x] **CEREM-026**: The system shall include in each hiking-stick reminder the pack-wide count of sticks to buy, pluralized for counts other than one.
- [x] **CEREM-027**: Where the pack-wide sticks-to-buy count is zero, the system shall state in the hiking-stick reminder that enough sticks are on hand.
- [x] **CEREM-028**: The system shall compute the sticks-to-buy count as the hiking-stick shortfall across all active scouts, pack-wide rather than per ceremony.
- [x] **CEREM-029**: The system shall include each ceremony's title and date in the body of that ceremony's reminders.
- [x] **CEREM-030**: When rescheduling ceremony reminders, the system shall cancel all pending notification requests and then add the current set.
- [x] **CEREM-031**: The system shall reschedule ceremony reminders when the app launches and when the Ceremonies tab appears.
- [x] **CEREM-032**: The system shall request notification authorization for alerts and sound.
