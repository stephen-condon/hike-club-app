//
//  SeedTests.swift
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
        configurations: config
    )
}

// MARK: - Seed.parseRoster

struct ParseRosterTests {

    @Test func headerRowIsSkipped() {
        let csv = "name,mileage,badges\nAlice,10.0,"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.count == 1)
        #expect(scouts[0].name == "Alice")
    }

    @Test func blankLinesAreSkipped() {
        let csv = "name,mileage,badges\nAlice,5.0,\n\n   \nBob,3.0,"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.count == 2)
        #expect(scouts[0].name == "Alice")
        #expect(scouts[1].name == "Bob")
    }

    @Test func nameOnlyRowHasZeroMileageAndNoBadges() {
        let csv = "name,mileage,badges\nCharlie"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.count == 1)
        #expect(scouts[0].name == "Charlie")
        #expect(scouts[0].startingMileage == 0.0)
        #expect(scouts[0].seededEarnedBadges.isEmpty)
    }

    @Test func nameAndMileageParsedCorrectly() {
        let csv = "name,mileage,badges\nDana,42.5"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.count == 1)
        #expect(scouts[0].startingMileage == 42.5)
    }

    @Test func semicolonSeparatedBadgesParsed() {
        let csv = "name,mileage,badges\nEve,10.0,mile10;polarBear"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.count == 1)
        #expect(scouts[0].seededEarnedBadges.contains(.mile10))
        #expect(scouts[0].seededEarnedBadges.contains(.polarBear))
    }

    @Test func unknownBadgeRawValueDropped() {
        let csv = "name,mileage,badges\nFrank,0.0,unknownBadge;mile10"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.count == 1)
        #expect(scouts[0].seededEarnedBadges.count == 1)
        #expect(scouts[0].seededEarnedBadges.contains(.mile10))
        #expect(!scouts[0].seededEarnedBadges.contains(where: { $0.rawValue == "unknownBadge" }))
    }

    @Test func nonNumericMileageBecomesZero() {
        let csv = "name,mileage,badges\nGrace,notanumber,"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.count == 1)
        #expect(scouts[0].startingMileage == 0.0)
    }

    @Test func emptyContentsAfterHeaderProducesNoScouts() {
        let csv = "name,mileage,badges\n"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.isEmpty)
    }

    @Test func multipleScoutsParsedInOrder() {
        let csv = "name,mileage,badges\nAlice,10.0,\nBob,20.0,mile20\nCarol,0.0,"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.count == 3)
        #expect(scouts[0].name == "Alice")
        #expect(scouts[1].name == "Bob")
        #expect(scouts[1].seededEarnedBadges.contains(.mile20))
        #expect(scouts[2].name == "Carol")
    }

    @Test func isActiveDefaultsTrueForParsedScouts() {
        let csv = "name,mileage,badges\nHank,0.0,"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.count == 1)
        #expect(scouts[0].isActive == true)
    }

    @Test func hasStickColumnOneCreatesAssignment() {
        let csv = "name,mileage,badges,hasStick\nIvy,0.0,,1"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.count == 1)
        #expect(scouts[0].stickAssignment != nil)
    }

    @Test func hasStickColumnBlankNoAssignment() {
        let csv = "name,mileage,badges,hasStick\nJack,0.0,,"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.count == 1)
        #expect(scouts[0].stickAssignment == nil)
    }

    @Test func hasStickColumnMissingNoAssignment() {
        let csv = "name,mileage,badges\nKate,0.0,"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.count == 1)
        #expect(scouts[0].stickAssignment == nil)
    }

    @Test func hasStickNonOneValueNoAssignment() {
        let csv = "name,mileage,badges,hasStick\nLeo,0.0,,0\nMia,0.0,,true\nNed,0.0,,yes"
        let scouts = Seed.parseRoster(csv)
        #expect(scouts.count == 3)
        #expect(scouts.allSatisfy { $0.stickAssignment == nil })
    }
}

// MARK: - Seed.seedIfNeeded

@MainActor
struct SeedIfNeededTests {

    @Test func seedInventoryCreatesOneItemPerKind() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        Seed.seedIfNeeded(context: ctx)

        let items = try ctx.fetch(FetchDescriptor<InventoryItem>())
        #expect(items.count == InventoryKind.allCases.count)

        for kind in InventoryKind.allCases {
            #expect(items.filter { $0.kind == kind }.count == 1,
                    "Expected exactly one item for kind \(kind)")
        }
    }

    @Test func seedIfNeededInventoryIdempotent() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        Seed.seedIfNeeded(context: ctx)
        Seed.seedIfNeeded(context: ctx)

        let items = try ctx.fetch(FetchDescriptor<InventoryItem>())
        #expect(items.count == InventoryKind.allCases.count,
                "seedIfNeeded should not duplicate inventory on second call")
    }

    @Test func seedIfNeededSkipsInventoryWhenAlreadyPresent() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        // Pre-populate inventory
        let preItem = InventoryItem(kind: .hikingStick, count: 99, minReserve: 0)
        ctx.insert(preItem)

        Seed.seedIfNeeded(context: ctx)

        let items = try ctx.fetch(FetchDescriptor<InventoryItem>())
        // Only the 1 pre-populated item; seedInventory skipped
        #expect(items.count == 1)
        #expect(items[0].count == 99)
    }
}
