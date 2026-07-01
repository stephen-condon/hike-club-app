//
//  ViewTests.swift
//  Pack134HikeClubTests
//

import Testing
import SwiftUI
@testable import Pack134HikeClub

// MARK: - Helpers (mirrors the attend() helper from the main test file)

@discardableResult
private func attend(_ scout: Scout, _ hike: Hike, qualities: [ScoutQuality] = []) -> Attendance {
    let att = Attendance(hike: hike, scout: scout, scoutQualitiesRaw: qualities)
    scout.attendances.append(att)
    hike.attendances.append(att)
    return att
}

// MARK: - StatusBadge

struct StatusBadgeTests {

    @Test func labelMappings() {
        #expect(StatusBadge(status: .planned).label == "Planned")
        #expect(StatusBadge(status: .inProgress).label == "In Progress")
        #expect(StatusBadge(status: .recap).label == "Recap")
        #expect(StatusBadge(status: .complete).label == "Complete")
    }

    @Test func colorMappings() {
        #expect(StatusBadge(status: .planned).color == .gray)
        #expect(StatusBadge(status: .inProgress).color == .blue)
        #expect(StatusBadge(status: .recap).color == .orange)
        #expect(StatusBadge(status: .complete).color == .green)
    }
}

// MARK: - HikeDetailView computed properties

struct HikeDetailViewTests {

    @Test func isEditableFalseWhenPlanned() {
        let view = HikeDetailView(hike: Hike(title: "T", status: .planned))
        #expect(view.isEditable == false)
    }

    @Test func isEditableTrueWhenInProgress() {
        let view = HikeDetailView(hike: Hike(title: "T", status: .inProgress))
        #expect(view.isEditable == true)
    }

    @Test func isEditableTrueWhenRecap() {
        let view = HikeDetailView(hike: Hike(title: "T", status: .recap))
        #expect(view.isEditable == true)
    }

    @Test func isEditableFalseWhenComplete() {
        let view = HikeDetailView(hike: Hike(title: "T", status: .complete))
        #expect(view.isEditable == false)
    }

    @Test func showAttendanceFalseWhenPlanned() {
        let view = HikeDetailView(hike: Hike(title: "T", status: .planned))
        #expect(view.showAttendance == false)
    }

    @Test func showAttendanceTrueWhenInProgress() {
        let view = HikeDetailView(hike: Hike(title: "T", status: .inProgress))
        #expect(view.showAttendance == true)
    }

    @Test func showAttendanceTrueWhenRecap() {
        let view = HikeDetailView(hike: Hike(title: "T", status: .recap))
        #expect(view.showAttendance == true)
    }

    @Test func showAttendanceFalseWhenComplete() {
        let view = HikeDetailView(hike: Hike(title: "T", status: .complete))
        #expect(view.showAttendance == false)
    }

    @Test func showDetailsFalseWhenPlanned() {
        let view = HikeDetailView(hike: Hike(title: "T", status: .planned))
        #expect(view.showDetails == false)
    }

    @Test func showDetailsTrueWhenInProgress() {
        let view = HikeDetailView(hike: Hike(title: "T", status: .inProgress))
        #expect(view.showDetails == true)
    }

    @Test func showDetailsTrueWhenRecap() {
        let view = HikeDetailView(hike: Hike(title: "T", status: .recap))
        #expect(view.showDetails == true)
    }

    @Test func showDetailsTrueWhenComplete() {
        let view = HikeDetailView(hike: Hike(title: "T", status: .complete))
        #expect(view.showDetails == true)
    }
}

// MARK: - NewHikeSheet.isSaveDisabled

struct NewHikeSheetTests {

    @Test func isSaveDisabledEmptyTitle() {
        #expect(NewHikeSheet.isSaveDisabled(title: "") == true)
    }

    @Test func isSaveDisabledWhitespaceTitle() {
        #expect(NewHikeSheet.isSaveDisabled(title: "   ") == true)
        #expect(NewHikeSheet.isSaveDisabled(title: "\t") == true)
    }

    @Test func isSaveDisabledFalseForValidTitle() {
        #expect(NewHikeSheet.isSaveDisabled(title: "Trail Run") == false)
        #expect(NewHikeSheet.isSaveDisabled(title: "  Valid  ") == false) // trimmed non-empty
    }
}

// MARK: - NewScoutSheet.isSaveDisabled

struct NewScoutSheetTests {

    @Test func isSaveDisabledEmptyName() {
        #expect(NewScoutSheet.isSaveDisabled(name: "") == true)
    }

    @Test func isSaveDisabledWhitespaceName() {
        #expect(NewScoutSheet.isSaveDisabled(name: "   ") == true)
        #expect(NewScoutSheet.isSaveDisabled(name: "\t") == true)
    }

    @Test func isSaveDisabledFalseForValidName() {
        #expect(NewScoutSheet.isSaveDisabled(name: "Alice") == false)
        #expect(NewScoutSheet.isSaveDisabled(name: "  Bob  ") == false)
    }
}

// MARK: - InventoryRow.displayName / MinReserveSheet.displayName

struct InventoryDisplayNameTests {

    @Test func hikingStickDisplaysCorrectly() {
        let item = InventoryItem(kind: .hikingStick, count: 0, minReserve: 0)
        let row = InventoryRow(item: item, onEditMinReserve: { })
        #expect(row.displayName == "Hiking Stick")
    }

    @Test func badgeKindUsesDisplayName() {
        let item = InventoryItem(kind: .mile10, count: 0, minReserve: 0)
        let row = InventoryRow(item: item, onEditMinReserve: { })
        #expect(row.displayName == "10 Mile")
    }

    @Test func polarBearDisplayName() {
        let item = InventoryItem(kind: .polarBear, count: 0, minReserve: 0)
        let row = InventoryRow(item: item, onEditMinReserve: { })
        #expect(row.displayName == "Polar Bear")
    }

    @Test func packMuleDisplayName() {
        let item = InventoryItem(kind: .packMule, count: 0, minReserve: 0)
        let row = InventoryRow(item: item, onEditMinReserve: { })
        #expect(row.displayName == "Pack Mule")
    }

    @Test func minReserveSheetHikingStickDisplayName() {
        let item = InventoryItem(kind: .hikingStick, count: 0, minReserve: 0)
        let sheet = MinReserveSheet(item: item)
        #expect(sheet.displayName == "Hiking Stick")
    }

    @Test func minReserveSheetBadgeDisplayName() {
        let item = InventoryItem(kind: .raven, count: 0, minReserve: 0)
        let sheet = MinReserveSheet(item: item)
        #expect(sheet.displayName == "Raven")
    }
}

// MARK: - ScoutRow.mileage

struct ScoutRowTests {

    @Test func mileageReflectsCumulativeMileage() {
        let scout = Scout(name: "Test", startingMileage: 5)
        let hike = Hike(title: "H", status: .complete, mileage: 10)
        attend(scout, hike)

        let row = ScoutRow(scout: scout, completedHikes: [hike])
        #expect(row.mileage == 15.0)
    }

    @Test func mileageWithNoHikesIsStartingMileage() {
        let scout = Scout(name: "Test", startingMileage: 7.5)
        let row = ScoutRow(scout: scout, completedHikes: [])
        #expect(row.mileage == 7.5)
    }
}

// MARK: - QualityRow.isOn

struct QualityRowTests {

    @Test func isOnTrueWhenQualityPresent() {
        let hike = Hike(title: "H", qualitiesRaw: [.cold, .snow])
        let row = QualityRow(hike: hike, quality: .cold, isEditable: false)
        #expect(row.isOn == true)
    }

    @Test func isOnFalseWhenQualityAbsent() {
        let hike = Hike(title: "H", qualitiesRaw: [.cold])
        let row = QualityRow(hike: hike, quality: .hot, isEditable: false)
        #expect(row.isOn == false)
    }

    @Test func isOnFalseWhenNoQualities() {
        let hike = Hike(title: "H", qualitiesRaw: [])
        let row = QualityRow(hike: hike, quality: .night, isEditable: false)
        #expect(row.isOn == false)
    }
}

// MARK: - orderedBadgeItems / equipmentItems free functions

struct InventoryFunctionTests {

    @Test func orderedBadgeItemsExcludesHikingStick() {
        let items = InventoryKind.allCases.map { InventoryItem(kind: $0, count: 0, minReserve: 0) }
        let result = orderedBadgeItems(from: items)
        #expect(!result.contains(where: { $0.kind == .hikingStick }))
    }

    @Test func orderedBadgeItemsMatchesKindDeclarationOrder() {
        let shuffled = InventoryKind.allCases
            .filter { $0 != .hikingStick }
            .map { InventoryItem(kind: $0, count: 0, minReserve: 0) }
            .shuffled()

        let result = orderedBadgeItems(from: shuffled)

        let expectedKinds = InventoryKind.allCases.filter { $0 != .hikingStick }
        #expect(result.map { $0.kind } == expectedKinds)
    }

    @Test func orderedBadgeItemsCountMatchesBadgeKinds() {
        let items = InventoryKind.allCases.map { InventoryItem(kind: $0, count: 0, minReserve: 0) }
        let result = orderedBadgeItems(from: items)
        let expectedCount = InventoryKind.allCases.filter { $0 != .hikingStick }.count
        #expect(result.count == expectedCount)
    }

    @Test func equipmentItemsFunctionReturnsOnlyHikingSticks() {
        let items = InventoryKind.allCases.map { InventoryItem(kind: $0, count: 0, minReserve: 0) }
        let result = equipmentItems(from: items)
        #expect(result.allSatisfy { $0.kind == .hikingStick })
        #expect(result.count == 1)
    }

    @Test func equipmentItemsFunctionEmptyWhenNoHikingStick() {
        let items = InventoryKind.allCases
            .filter { $0 != .hikingStick }
            .map { InventoryItem(kind: $0, count: 0, minReserve: 0) }
        let result = equipmentItems(from: items)
        #expect(result.isEmpty)
    }
}

// MARK: - AttendanceRow.isAttending

struct AttendanceRowTests {

    @Test func isAttendingTrueWhenScoutAttended() {
        let scout = Scout(name: "Test")
        let hike = Hike(title: "H")
        attend(scout, hike)

        let row = AttendanceRow(hike: hike, scout: scout)
        #expect(row.isAttending == true)
    }

    @Test func isAttendingFalseWhenScoutNotAttended() {
        let scout = Scout(name: "Attending")
        let otherScout = Scout(name: "Not Attending")
        let hike = Hike(title: "H")
        attend(scout, hike)

        let row = AttendanceRow(hike: hike, scout: otherScout)
        #expect(row.isAttending == false)
    }
}
