# Inventory — EARS Specs

## Kinds and Rows

- [x] **INV-001**: The system shall track one inventory row per inventory kind, each holding an on-hand count and a minimum reserve.
- [x] **INV-002**: The system shall define one inventory kind for every badge in the catalog, plus a hiking-stick kind.
- [x] **INV-003**: The system shall keep each inventory kind's raw value identical to its corresponding badge's raw value, including "river" for River Runner.
- [x] **INV-004**: The system shall display each inventory kind using its corresponding badge's display name, and "Hiking Stick" for the hiking-stick kind.

## Seeding

- [x] **INV-005**: While the inventory table is empty at app launch, the system shall create one row per inventory kind with a count of zero and a minimum reserve of zero.
- [x] **INV-006**: While the inventory table is non-empty at app launch, the system shall make no change to inventory.

## Low Stock

- [x] **INV-007**: The system shall report an inventory row as low when its on-hand count is below its minimum reserve.
- [x] **INV-008**: While an inventory row is low, the Inventory view shall display that row's count in red and label it as low stock.
- [x] **INV-009**: The system shall never prevent or block an award because inventory is low or zero.

## Editing

- [x] **INV-010**: When the owner increments an inventory row's count, the system shall increase it by one, with no upper bound.
- [x] **INV-011**: When the owner decrements an inventory row's count while that count is zero, the system shall leave it at zero.
- [x] **INV-012**: The system shall allow the owner to set each inventory row's minimum reserve to any value from 0 through 999.
- [x] **INV-013**: The Inventory view shall list badge kinds in inventory-kind declaration order, in a section separate from hiking sticks.
