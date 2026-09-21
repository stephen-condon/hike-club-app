# Award Derivation — EARS Specs

## Derivation Model

- [x] **AWARD-DERV-001**: The system shall derive a scout's earned badges on every read rather than storing them.
- [x] **AWARD-DERV-002**: The system shall recompute a scout's derived awards from scratch on each request, holding no cache.
- [x] **AWARD-DERV-003**: The system shall count a hike toward a scout's derived mileage and badges only when that hike is complete and that scout attended it.
- [x] **AWARD-DERV-004**: The system shall exclude complete hikes a scout did not attend from that scout's derived mileage and badges.
- [x] **AWARD-DERV-005**: The system shall derive awards for archived scouts on the same terms as for active scouts.

## Mileage

- [x] **AWARD-DERV-006**: The system shall compute a scout's cumulative mileage as that scout's starting mileage plus the mileage of every complete hike that scout attended.
- [x] **AWARD-DERV-007**: The system shall define mileage badges at ten-mile intervals from 10 through 100 miles.
- [x] **AWARD-DERV-008**: The system shall award a mileage badge to a scout when that scout's cumulative mileage is at or above that badge's threshold.
- [x] **AWARD-DERV-009**: The system shall report no mileage threshold for badges that are not mileage badges.

## Badge Rules

- [x] **AWARD-DERV-010**: The system shall include every badge in a scout's seeded earned badges in that scout's derived earned badges.
- [x] **AWARD-DERV-011**: The system shall award the 10-Mile Massacre badge to a scout when any complete hike that scout attended was at least 10 miles, deriving it from hike mileage rather than from a hike quality flag.
- [x] **AWARD-DERV-012**: The system shall award the badge mapped to each hike quality flagged on any complete hike a scout attended.
- [x] **AWARD-DERV-013**: The system shall award the Pack Mule badge to a scout when the backpack scout quality was recorded on that scout's attendance for any complete hike.
- [x] **AWARD-DERV-014**: The system shall award each badge to a scout at most once, however many hikes qualify for it.

## Badge Catalog

- [x] **AWARD-DERV-015**: The system shall map each hike quality to exactly one badge: litter cleanup to Litter Bug, cold to Polar Bear, hot to Scorpion, snow to Mammoth, elevation to Matterhorn, rain or mud to Hippopotamus, parade to Patriot, unimproved to Tricky Fox, night to Raven, and river to River Runner.
- [x] **AWARD-DERV-016**: The system shall report no hike quality for badges that are not derived from a hike quality.
- [x] **AWARD-DERV-017**: The system shall use the raw value "river" for the River Runner badge, matching the corresponding inventory kind's raw value.
- [x] **AWARD-DERV-018**: The system shall provide a non-empty display name for every badge.

## Pending Awards

- [x] **AWARD-DERV-019**: The system shall compute a scout's pending badges as that scout's derived earned badges minus the badges already given to that scout.
- [x] **AWARD-DERV-020**: The system shall treat a scout's stick as pending when that scout's stick is marked earned and that scout has no stick assignment.
- [x] **AWARD-DERV-021**: The system shall treat a scout as having pending awards when that scout has at least one pending badge or a pending stick.
