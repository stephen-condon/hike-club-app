//
//  ActionsTests.swift
//  Pack134HikeClubTests
//

import Testing
import SwiftData
@testable import Pack134HikeClub

// MARK: - Helpers

private func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Scout.self, Hike.self, Attendance.self,
            InventoryItem.self, StickAssignment.self,
            Ceremony.self, CeremonyAward.self,
        configurations: config
    )
}

// MARK: - Badge Actions

@MainActor
struct BadgeActionsTests {

    @Test func giveBadgeAppendsToGivenBadges() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Alice")
        let item = InventoryItem(kind: .polarBear, count: 5, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.giveBadge(.polarBear, inventory: [item])

        #expect(scout.givenBadges.contains(.polarBear))
    }

    @Test func giveBadgeDecrementsInventory() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Alice")
        let item = InventoryItem(kind: .polarBear, count: 5, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.giveBadge(.polarBear, inventory: [item])

        #expect(item.count == 4)
    }

    @Test func giveBadgeFloorsInventoryAtZero() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Bob")
        let item = InventoryItem(kind: .polarBear, count: 0, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.giveBadge(.polarBear, inventory: [item])

        #expect(item.count == 0)
        #expect(scout.givenBadges.contains(.polarBear))
    }

    @Test func giveBadgeNoInventoryItemLeavesCountUnchanged() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Carol")
        ctx.insert(scout)

        scout.giveBadge(.polarBear, inventory: [])  // empty inventory

        #expect(scout.givenBadges.contains(.polarBear))
    }

    @Test func ungiveBadgeRemovesFromGivenBadges() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Dan", givenBadges: [.polarBear])
        let item = InventoryItem(kind: .polarBear, count: 2, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.ungiveBadge(.polarBear, inventory: [item])

        #expect(!scout.givenBadges.contains(.polarBear))
    }

    @Test func ungiveBadgeIncrementsInventory() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Eve", givenBadges: [.polarBear])
        let item = InventoryItem(kind: .polarBear, count: 2, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.ungiveBadge(.polarBear, inventory: [item])

        #expect(item.count == 3)
    }

    @Test func ungiveBadgeBadgeAbsentLeavesInventoryUnchanged() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Frank")  // no givenBadges
        let item = InventoryItem(kind: .polarBear, count: 2, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.ungiveBadge(.polarBear, inventory: [item])

        #expect(scout.givenBadges.isEmpty)
        #expect(item.count == 2)
    }

    @Test func giveBadgeTwiceIsIdempotent() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Gus")
        let item = InventoryItem(kind: .polarBear, count: 5, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.giveBadge(.polarBear, inventory: [item])
        scout.giveBadge(.polarBear, inventory: [item])

        #expect(scout.givenBadges.filter { $0 == .polarBear }.count == 1)
        #expect(item.count == 4)
    }

    @Test func giveThenUngiveBadgeRestoresInventory() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Grace")
        let item = InventoryItem(kind: .mammoth, count: 5, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.giveBadge(.mammoth, inventory: [item])
        #expect(item.count == 4)

        scout.ungiveBadge(.mammoth, inventory: [item])
        #expect(item.count == 5)
        #expect(!scout.givenBadges.contains(.mammoth))
    }
}

// MARK: - Stick Actions

@MainActor
struct StickActionsTests {

    @Test func assignStickCreatesAssignmentRelationship() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Hank")
        let item = InventoryItem(kind: .hikingStick, count: 3, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.assignStick(context: ctx, inventory: [item])

        #expect(scout.stickAssignment != nil)
    }

    @Test func assignStickDecrementsInventory() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Iris")
        let item = InventoryItem(kind: .hikingStick, count: 3, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.assignStick(context: ctx, inventory: [item])

        #expect(item.count == 2)
    }

    @Test func assignStickFloorsInventoryAtZero() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Jack")
        let item = InventoryItem(kind: .hikingStick, count: 0, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.assignStick(context: ctx, inventory: [item])

        #expect(item.count == 0)
        #expect(scout.stickAssignment != nil)
    }

    @Test func returnStickClearsRelationship() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Kate")
        let item = InventoryItem(kind: .hikingStick, count: 2, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.assignStick(context: ctx, inventory: [item])

        guard let assignment = scout.stickAssignment else {
            Issue.record("No assignment after assignStick")
            return
        }

        scout.returnStick(assignment, context: ctx, inventory: [item])

        #expect(scout.stickAssignment == nil)
    }

    @Test func returnStickIncrementsInventory() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Leo")
        let item = InventoryItem(kind: .hikingStick, count: 2, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.assignStick(context: ctx, inventory: [item])
        // count is 1 after assign

        guard let assignment = scout.stickAssignment else {
            Issue.record("No assignment after assignStick")
            return
        }

        scout.returnStick(assignment, context: ctx, inventory: [item])

        #expect(item.count == 2) // back to original
    }

    @Test func assignThenReturnStickRestoresInventory() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Mia")
        let item = InventoryItem(kind: .hikingStick, count: 5, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.assignStick(context: ctx, inventory: [item])
        #expect(item.count == 4)
        #expect(scout.stickAssignment != nil)

        guard let assignment = scout.stickAssignment else {
            Issue.record("No assignment after assignStick")
            return
        }

        scout.returnStick(assignment, context: ctx, inventory: [item])
        #expect(item.count == 5)
        #expect(scout.stickAssignment == nil)
    }
}
