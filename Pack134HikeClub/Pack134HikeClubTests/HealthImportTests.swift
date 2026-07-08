//
//  HealthImportTests.swift
//  Pack134HikeClubTests
//

import Testing
@testable import Pack134HikeClub

// MARK: - milesRoundedToHalf

struct MilesRoundedToHalfTests {

    @Test func exactMileRoundsToWhole() {
        #expect(milesRoundedToHalf(meters: 3218.688) == 2.0) // 2.0 mi
    }

    @Test func exactHalfStays() {
        #expect(milesRoundedToHalf(meters: 4023.36) == 2.5) // 2.5 mi
    }

    @Test func roundsUpToHalf() {
        #expect(milesRoundedToHalf(meters: 3862) == 2.5) // ~2.4 mi
    }

    @Test func roundsDownToHalf() {
        #expect(milesRoundedToHalf(meters: 2735) == 1.5) // ~1.7 mi
    }

    @Test func zero() {
        #expect(milesRoundedToHalf(meters: 0) == 0)
    }
}

// MARK: - feet(fromMeters:)

struct FeetFromMetersTests {

    @Test func hundredMeters() {
        #expect(feet(fromMeters: 100) == 328)
    }

    @Test func zero() {
        #expect(feet(fromMeters: 0) == 0)
    }
}

// MARK: - Hike.earnsMatterhorn

struct EarnsMatterhornTests {

    @Test func notImportedDoesNotEarn() {
        #expect(Hike.earnsMatterhorn(elevationFeet: nil) == false)
    }

    @Test func belowThresholdDoesNotEarn() {
        #expect(Hike.earnsMatterhorn(elevationFeet: 99) == false)
    }

    @Test func atThresholdEarns() {
        #expect(Hike.earnsMatterhorn(elevationFeet: 100) == true)
    }

    @Test func aboveThresholdEarns() {
        #expect(Hike.earnsMatterhorn(elevationFeet: 250) == true)
    }
}
