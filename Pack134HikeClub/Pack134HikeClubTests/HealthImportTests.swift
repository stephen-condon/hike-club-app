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
