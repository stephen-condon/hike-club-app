# Hikes — EARS Specs

## Lifecycle

- [x] **HIKE-001**: The system shall create every new hike in the planned state.
- [x] **HIKE-002**: While a hike is planned, the system shall offer exactly one transition, to in-progress.
- [x] **HIKE-003**: While a hike is in progress, the system shall offer exactly one transition, to recap.
- [x] **HIKE-004**: While a hike is in recap, the system shall offer exactly one transition, to complete.
- [x] **HIKE-005**: While a hike is complete, the system shall offer exactly one transition, back to recap.
- [x] **HIKE-006**: While a hike is planned, the system shall allow the owner to edit that hike's title, date, end time, and location.
- [x] **HIKE-039**: The system shall compute a hike's effective end time as its explicit end time if one is set, otherwise as two hours after its date.
- [x] **HIKE-007**: While a hike is in progress or in recap, the system shall allow the owner to edit that hike's title, attendance, mileage, notes, and hike qualities.
- [x] **HIKE-008**: While a hike is in progress or in recap, the system shall display that hike's date and location as read-only.
- [x] **HIKE-009**: While a hike is planned, the system shall hide that hike's attendance and hike-detail sections.
- [x] **HIKE-010**: While a hike is complete, the system shall display every field of that hike as read-only and indicate that it is locked.
- [x] **HIKE-011**: While a hike is complete, the system shall display that hike's attendance as a read-only list sorted by scout name, marking each attendee who carried a backpack.

## Hike List and Records

- [x] **HIKE-012**: The Hikes list shall show non-complete hikes soonest-first and complete hikes most-recent-first, in separate sections.
- [x] **HIKE-013**: While the new-hike title field is empty or contains only whitespace, the system shall disable saving that hike.
- [x] **HIKE-014**: The system shall allow deleting only complete hikes, and only after a confirmation stating that attendees' mileage and badges will be recalculated.
- [x] **HIKE-015**: When a hike is deleted, the system shall cascade-delete that hike's attendance records.
- [x] **HIKE-016**: The system shall store one mileage value per hike, shared by every attendee of that hike.
- [x] **HIKE-017**: The system shall treat a hike's recorded qualities and an attendance's scout qualities as sets, ignoring duplicate entries.

## Attendance

- [x] **HIKE-018**: When the owner marks a scout as attending a hike, the system shall create an attendance record linking that scout to that hike.
- [x] **HIKE-019**: When the owner marks an attending scout as no longer attending a hike, the system shall delete that attendance record together with the scout qualities recorded on it.
- [x] **HIKE-020**: While a scout is attending a hike, the system shall allow the owner to toggle that scout's backpack quality for that hike.
- [x] **HIKE-021**: While a scout is not attending a hike, the system shall disable that scout's backpack control for that hike.

## Mileage Entry

- [x] **HIKE-022**: While a hike's mileage field is editable and its text is empty, the system shall set that hike's mileage to zero.
- [x] **HIKE-023**: If a hike's mileage field holds text that is not a valid number, then the system shall keep that hike's last valid mileage.

## Health Import

- [x] **HIKE-024**: Where HealthKit is available and a hike is in progress or in recap, the system shall offer to import that hike's distance and elevation from Health.
- [x] **HIKE-025**: When importing from Health, the system shall request read-only authorization for workouts and shall request no permission to write.
- [x] **HIKE-026**: When importing from Health for a hike, the system shall consider only hiking workouts that started on the same calendar day as that hike, ordered newest first.
- [x] **HIKE-027**: If no hiking workout exists for a hike's date, then the system shall tell the owner none was found and change nothing about that hike.
- [x] **HIKE-028**: When exactly one hiking workout exists for a hike's date, the system shall apply that workout without prompting.
- [x] **HIKE-029**: When more than one hiking workout exists for a hike's date, the system shall prompt the owner to choose one, showing each workout's start time and distance.
- [x] **HIKE-030**: When applying an imported workout to a hike, the system shall set that hike's mileage to the workout's distance in miles, rounded to the nearest half mile.
- [x] **HIKE-031**: When applying an imported workout that carries elevation-ascended metadata, the system shall set that hike's elevation gain to that value in whole feet.
- [x] **HIKE-032**: If an imported workout carries no elevation-ascended metadata, then the system shall leave that hike's elevation gain unset.
- [x] **HIKE-033**: When applying an imported workout to a hike, the system shall set that hike's elevation quality if the imported elevation gain is at least 100 feet, and clear that quality otherwise.
- [x] **HIKE-034**: While a hike has an imported elevation gain, the system shall display that hike's elevation quality as read-only.
- [x] **HIKE-035**: While a hike has no imported elevation gain and that hike is editable, the system shall allow the owner to flag its elevation quality by hand.
- [x] **HIKE-036**: While a hike is not planned and has an elevation gain, the system shall display that elevation gain in whole feet.
- [x] **HIKE-037**: If Health data cannot be read, then the system shall tell the owner and change nothing about the hike.
- [x] **HIKE-038**: The system shall perform every Health import on-device, issuing no network request.
