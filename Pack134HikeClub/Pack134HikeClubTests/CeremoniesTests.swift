//
//  CeremoniesTests.swift
//  Pack134HikeClubTests
//

import Testing
import Foundation
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

@discardableResult
private func attend(_ scout: Scout, _ hike: Hike, qualities: [ScoutQuality] = []) -> Attendance {
    let att = Attendance(hike: hike, scout: scout, scoutQualitiesRaw: qualities)
    scout.attendances.append(att)
    hike.attendances.append(att)
    return att
}

// MARK: - Scout pending derivation

@MainActor
struct PendingAwardsTests {

    @Test func pendingBadgesIncludesEarnedNotGiven() {
        let scout = Scout(name: "Alice", startingMileage: 10)
        #expect(scout.pendingBadges(completedHikes: []).contains(.mile10))
    }

    @Test func pendingBadgesExcludesAlreadyGiven() {
        let scout = Scout(name: "Bob", startingMileage: 10, givenBadges: [.mile10])
        #expect(!scout.pendingBadges(completedHikes: []).contains(.mile10))
    }

    @Test func pendingBadgesIncludesSeededNotGiven() {
        let scout = Scout(name: "Carol", seededEarnedBadges: [.polarBear])
        #expect(scout.pendingBadges(completedHikes: []).contains(.polarBear))
    }

    @Test func hasPendingStickTrueWhenEarnedNotAssigned() {
        let scout = Scout(name: "Dan", stickEarned: true)
        #expect(scout.hasPendingStick)
    }

    @Test func hasPendingStickFalseWhenNotEarned() {
        let scout = Scout(name: "Eve")
        #expect(!scout.hasPendingStick)
    }

    @Test func hasPendingStickFalseWhenAlreadyAssigned() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let scout = Scout(name: "Frank")
        let item = InventoryItem(kind: .hikingStick, count: 3, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.assignStick(context: ctx, inventory: [item])

        #expect(!scout.hasPendingStick)
    }

    @Test func hasPendingAwardsFalseWhenNothingPending() {
        let scout = Scout(name: "Grace")
        #expect(!scout.hasPendingAwards(completedHikes: []))
    }

    @Test func hasPendingAwardsTrueWithPendingBadgeOnly() {
        let scout = Scout(name: "Hank", seededEarnedBadges: [.polarBear])
        #expect(scout.hasPendingAwards(completedHikes: []))
    }

    @Test func hasPendingAwardsTrueWithPendingStickOnly() {
        let scout = Scout(name: "Iris", stickEarned: true)
        #expect(scout.hasPendingAwards(completedHikes: []))
    }
}

// MARK: - awardAllPending

@MainActor
struct AwardAllPendingTests {

    @Test func givesAllPendingBadgesAndDecrementsInventory() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Jack", seededEarnedBadges: [.polarBear, .mile10])
        let polarBearItem = InventoryItem(kind: .polarBear, count: 5, minReserve: 0)
        let mile10Item = InventoryItem(kind: .mile10, count: 5, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(polarBearItem)
        ctx.insert(mile10Item)

        scout.awardAllPending(completedHikes: [], context: ctx, inventory: [polarBearItem, mile10Item])

        #expect(scout.givenBadges.contains(.polarBear))
        #expect(scout.givenBadges.contains(.mile10))
        #expect(polarBearItem.count == 4)
        #expect(mile10Item.count == 4)
    }

    @Test func assignsStickWhenPending() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Kate", stickEarned: true)
        let stickItem = InventoryItem(kind: .hikingStick, count: 3, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(stickItem)

        scout.awardAllPending(completedHikes: [], context: ctx, inventory: [stickItem])

        #expect(scout.stickAssignment != nil)
        #expect(stickItem.count == 2)
    }

    @Test func doesNotAssignStickWhenNotPending() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Leo")  // stick not earned
        let stickItem = InventoryItem(kind: .hikingStick, count: 3, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(stickItem)

        scout.awardAllPending(completedHikes: [], context: ctx, inventory: [stickItem])

        #expect(scout.stickAssignment == nil)
        #expect(stickItem.count == 3)
    }

    @Test func returnsExactBadgesAndStickGiven() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Mia", seededEarnedBadges: [.polarBear], stickEarned: true)
        let polarBearItem = InventoryItem(kind: .polarBear, count: 1, minReserve: 0)
        let stickItem = InventoryItem(kind: .hikingStick, count: 1, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(polarBearItem)
        ctx.insert(stickItem)

        let result = scout.awardAllPending(completedHikes: [], context: ctx, inventory: [polarBearItem, stickItem])

        #expect(result.badges == [.polarBear])
        #expect(result.stickGiven == true)
    }

    @Test func secondCallGivesNothingNew() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let scout = Scout(name: "Nina", seededEarnedBadges: [.polarBear])
        let item = InventoryItem(kind: .polarBear, count: 5, minReserve: 0)
        ctx.insert(scout)
        ctx.insert(item)

        scout.awardAllPending(completedHikes: [], context: ctx, inventory: [item])
        let secondResult = scout.awardAllPending(completedHikes: [], context: ctx, inventory: [item])

        #expect(secondResult.badges.isEmpty)
        #expect(scout.givenBadges.filter { $0 == .polarBear }.count == 1)
        #expect(item.count == 4)
    }
}

// MARK: - ceremonyInventoryNeeds

@MainActor
struct CeremonyInventoryNeedsTests {

    @Test func countsAcrossMultipleScouts() {
        let scoutA = Scout(name: "Oscar", seededEarnedBadges: [.mile10])
        let scoutB = Scout(name: "Pat", seededEarnedBadges: [.mile10])
        let scoutC = Scout(name: "Quinn", seededEarnedBadges: [.polarBear])

        let needs = ceremonyInventoryNeeds(scouts: [scoutA, scoutB, scoutC], hikes: [])

        #expect(needs[.mile10] == 2)
        #expect(needs[.polarBear] == 1)
    }

    @Test func includesHikingStickPerPendingScout() {
        let scoutA = Scout(name: "Rose", stickEarned: true)
        let scoutB = Scout(name: "Sam", stickEarned: true)

        let needs = ceremonyInventoryNeeds(scouts: [scoutA, scoutB], hikes: [])

        #expect(needs[.hikingStick] == 2)
    }

    @Test func excludesScoutsWithNothingPending() {
        let scout = Scout(name: "Tina")  // nothing pending
        let needs = ceremonyInventoryNeeds(scouts: [scout], hikes: [])
        #expect(needs.isEmpty)
    }
}

// MARK: - ceremonyShortfalls

struct CeremonyShortfallsTests {

    @Test func flagsWhenOnHandBelowNeed() {
        let item = InventoryItem(kind: .mile10, count: 1, minReserve: 0)
        let shortfalls = ceremonyShortfalls(needs: [.mile10: 3], inventory: [item])

        #expect(shortfalls.count == 1)
        #expect(shortfalls[0].kind == .mile10)
        #expect(shortfalls[0].buy == 2)
    }

    @Test func flagsWhenHandingOutWouldDropBelowMinReserve() {
        let item = InventoryItem(kind: .mile10, count: 5, minReserve: 3)
        // Need 3, on hand 5: 5 - 3 = 2, which is below minReserve of 3 -> flagged
        let shortfalls = ceremonyShortfalls(needs: [.mile10: 3], inventory: [item])

        #expect(shortfalls.count == 1)
        #expect(shortfalls[0].buy == 1) // 3 + 3 - 5
    }

    @Test func doesNotFlagWhenComfortablyAboveReserve() {
        let item = InventoryItem(kind: .mile10, count: 10, minReserve: 2)
        // 10 - 3 = 7, well above minReserve of 2
        let shortfalls = ceremonyShortfalls(needs: [.mile10: 3], inventory: [item])

        #expect(shortfalls.isEmpty)
    }

    @Test func missingInventoryItemIsSkipped() {
        let shortfalls = ceremonyShortfalls(needs: [.mile10: 3], inventory: [])
        #expect(shortfalls.isEmpty)
    }
}

// MARK: - completeCeremony

@MainActor
struct CompleteCeremonyTests {

    @Test func awardsIncludedScoutsAndSnapshotsCeremonyAward() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let ceremony = Ceremony(title: "Fall Ceremony", date: .now)
        let scout = Scout(name: "Uma", seededEarnedBadges: [.polarBear])
        let item = InventoryItem(kind: .polarBear, count: 5, minReserve: 0)
        ctx.insert(ceremony)
        ctx.insert(scout)
        ctx.insert(item)

        completeCeremony(ceremony, scouts: [scout], hikes: [], context: ctx, inventory: [item])

        #expect(scout.givenBadges.contains(.polarBear))
        #expect(ceremony.isComplete)
        #expect(ceremony.awards.count == 1)
        #expect(ceremony.awards[0].scout?.persistentModelID == scout.persistentModelID)
        #expect(ceremony.awards[0].badges == [.polarBear])
    }

    @Test func excludedScoutStaysPendingAndUngrouped() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let ceremony = Ceremony(title: "Fall Ceremony", date: .now)
        let included = Scout(name: "Victor", seededEarnedBadges: [.mile10])
        let excluded = Scout(name: "Wendy", seededEarnedBadges: [.mile20])
        let item10 = InventoryItem(kind: .mile10, count: 5, minReserve: 0)
        let item20 = InventoryItem(kind: .mile20, count: 5, minReserve: 0)
        ctx.insert(ceremony)
        ctx.insert(included)
        ctx.insert(excluded)
        ctx.insert(item10)
        ctx.insert(item20)

        // Only `included` is passed — mirrors the toggle-off flow.
        completeCeremony(ceremony, scouts: [included], hikes: [], context: ctx, inventory: [item10, item20])

        #expect(included.givenBadges.contains(.mile10))
        #expect(!excluded.givenBadges.contains(.mile20))
        #expect(excluded.pendingBadges(completedHikes: []).contains(.mile20))
        #expect(ceremony.awards.count == 1)
    }

    @Test func scoutWithNoActualPendingAwardsGetsNoSnapshot() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let ceremony = Ceremony(title: "Fall Ceremony", date: .now)
        let scout = Scout(name: "Xena")  // nothing pending
        ctx.insert(ceremony)
        ctx.insert(scout)

        completeCeremony(ceremony, scouts: [scout], hikes: [], context: ctx, inventory: [])

        #expect(ceremony.isComplete)
        #expect(ceremony.awards.isEmpty)
    }

    @Test func marksCeremonyCompleteEvenWithNoScouts() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let ceremony = Ceremony(title: "Fall Ceremony", date: .now)
        ctx.insert(ceremony)

        completeCeremony(ceremony, scouts: [], hikes: [], context: ctx, inventory: [])

        #expect(ceremony.isComplete)
        #expect(ceremony.awards.isEmpty)
    }
}
