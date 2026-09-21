# App Shell — EARS Specs

## Store

- [x] **SHELL-001**: The system shall declare a SwiftData schema containing Scout, Hike, Attendance, InventoryItem, StickAssignment, Ceremony, and CeremonyAward.
- [x] **SHELL-002**: The system shall persist all application data on-device.

## Launch Sequence

- [x] **SHELL-003**: When the app launches, the system shall run first-launch seeding before computing the sticks-to-buy count used for ceremony reminders.
- [x] **SHELL-004**: When the app launches, the system shall request notification authorization and then reschedule ceremony reminders.
- [x] **SHELL-005**: When the app launches, the system shall compute the sticks-to-buy count from the active scouts, all hikes, and inventory then in the store.

## Navigation

- [x] **SHELL-006**: The system shall present five tabs: Hikes, Scouts, Inventory, Ceremonies, and Settings.
- [x] **SHELL-007**: The system shall open the Hikes tab on every launch.
- [x] **SHELL-008**: When the app launches, the system shall show a branded splash overlay and dismiss it with a fade after 1.5 seconds.
