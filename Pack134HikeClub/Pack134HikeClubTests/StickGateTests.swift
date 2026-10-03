//
//  StickGateTests.swift
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

// MARK: - Hiking stick gate

@MainActor
struct StickGateTests {

    // @spec AWARD-DERV-022
    @Test func stickEarnedAtTenMiles() {
        #expect(!Scout(name: "Ann", startingMileage: 9.9).hasEarnedStick(completedHikes: []))
        #expect(Scout(name: "Ben", startingMileage: 10).hasEarnedStick(completedHikes: []))
        #expect(Scout(name: "Cal", stickEarned: true).hasEarnedStick(completedHikes: []))
    }

    // @spec AWARD-DERV-020
    @Test func stickPendingAtTenMilesWithoutAssignment() {
        #expect(Scout(name: "Ben", startingMileage: 10).hasPendingStick(completedHikes: []))
    }

    // @spec CEREM-010
    @Test func needsSkipScoutsWithoutStick() {
        let gated = Scout(name: "Ann", startingMileage: 5, seededEarnedBadges: [.polarBear])
        let ready = Scout(name: "Ben", startingMileage: 10)
        let needs = ceremonyInventoryNeeds(scouts: [gated, ready], hikes: [])
        #expect(needs[.polarBear] == nil)
        #expect(needs[.hikingStick] == 1)
        #expect(needs[.mile10] == 1)
    }

    // @spec CEREM-035
    @Test func completionSkipsScoutsWithoutStick() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let ceremony = Ceremony(title: "Fall Ceremony")
        let gated = Scout(name: "Ann", startingMileage: 5, seededEarnedBadges: [.polarBear])
        ctx.insert(ceremony)
        ctx.insert(gated)

        completeCeremony(ceremony, scouts: [gated], hikes: [], context: ctx, inventory: [])

        #expect(gated.givenBadges.isEmpty)
        #expect(gated.pendingBadges(completedHikes: []).contains(.polarBear))
        #expect(ceremony.awards.isEmpty)
    }

    // @spec CEREM-015, CEREM-035
    @Test func stickCeremonyGivesStickAndEverythingElse() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let ceremony = Ceremony(title: "Fall Ceremony")
        let scout = Scout(name: "Ben", startingMileage: 10, seededEarnedBadges: [.polarBear])
        let stick = InventoryItem(kind: .hikingStick, count: 2, minReserve: 0)
        ctx.insert(ceremony)
        ctx.insert(scout)
        ctx.insert(stick)

        completeCeremony(ceremony, scouts: [scout], hikes: [], context: ctx, inventory: [stick])

        #expect(scout.stickAssignment != nil)
        #expect(Set(scout.givenBadges) == [.polarBear, .mile10])
        #expect(ceremony.awards.first?.stickGiven == true)
        #expect(stick.count == 1)
    }
}
