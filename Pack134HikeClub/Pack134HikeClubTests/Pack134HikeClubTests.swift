//
//  Pack134HikeClubTests.swift
//  Pack134HikeClubTests
//

import Testing
@testable import Pack134HikeClub

// MARK: - Helpers

/// Wires up an Attendance between a scout and hike, appending to both sides.
@discardableResult
private func attend(_ scout: Scout, _ hike: Hike, qualities: [ScoutQuality] = []) -> Attendance {
    let att = Attendance(hike: hike, scout: scout, scoutQualitiesRaw: qualities)
    scout.attendances.append(att)
    hike.attendances.append(att)
    return att
}

// MARK: - Awards Tests

struct AwardsTests {

    // 1. 25 miles of completed hikes → mile10 and mile20 earned, mile30 NOT earned
    @Test func mileageBadgesAtTwentyFiveMiles() {
        let scout = Scout(name: "Alice", startingMileage: 0)
        let hike1 = Hike(title: "Hike A", status: .complete, mileage: 15)
        let hike2 = Hike(title: "Hike B", status: .complete, mileage: 10)
        attend(scout, hike1)
        attend(scout, hike2)

        let completedHikes = [hike1, hike2]
        let badges = scout.earnedBadges(completedHikes: completedHikes)

        #expect(badges.contains(.mile10))
        #expect(badges.contains(.mile20))
        #expect(!badges.contains(.mile30))
    }

    // 2. Attending 2 cold hikes → polarBear earned exactly once (set semantics)
    @Test func polarBearEarnedOnceFromTwoColdHikes() {
        let scout = Scout(name: "Bob")
        let hike1 = Hike(title: "Cold Hike 1", status: .complete, mileage: 2, qualitiesRaw: [.cold])
        let hike2 = Hike(title: "Cold Hike 2", status: .complete, mileage: 2, qualitiesRaw: [.cold])
        attend(scout, hike1)
        attend(scout, hike2)

        let badges = scout.earnedBadges(completedHikes: [hike1, hike2])

        #expect(badges.contains(.polarBear))
        // Set<BadgeType> can only contain one .polarBear — filter to confirm count
        #expect(badges.filter { $0 == .polarBear }.count == 1)
    }

    // 3. Scout wears a backpack → packMule earned
    @Test func packMuleEarnedWithBackpack() {
        let scout = Scout(name: "Carol")
        let hike = Hike(title: "Pack Hike", status: .complete, mileage: 3)
        attend(scout, hike, qualities: [.backpack])

        let badges = scout.earnedBadges(completedHikes: [hike])

        #expect(badges.contains(.packMule))
    }

    // 4. Hike mileage exactly 10.0 → tenMileMassacre earned
    @Test func tenMileMassacreEarnedAtExactlyTenMiles() {
        let scout = Scout(name: "Dan")
        let hike = Hike(title: "10-Miler", status: .complete, mileage: 10.0)
        attend(scout, hike)

        let badges = scout.earnedBadges(completedHikes: [hike])

        #expect(badges.contains(.tenMileMassacre))
    }

    // 5. Hike mileage 9.9 → tenMileMassacre NOT earned
    @Test func tenMileMassacreNotEarnedBelowTenMiles() {
        let scout = Scout(name: "Eve")
        let hike = Hike(title: "9.9-Miler", status: .complete, mileage: 9.9)
        attend(scout, hike)

        let badges = scout.earnedBadges(completedHikes: [hike])

        #expect(!badges.contains(.tenMileMassacre))
    }

    // 6. Archived (isActive: false) scout — Awards derivation still works correctly
    @Test func archivedScoutStillDerivesAwards() {
        let scout = Scout(name: "Frank", isActive: false)
        let hike = Hike(title: "Old Hike", status: .complete, mileage: 12, qualitiesRaw: [.cold])
        attend(scout, hike)

        let badges = scout.earnedBadges(completedHikes: [hike])

        #expect(badges.contains(.mile10))
        #expect(badges.contains(.tenMileMassacre))
        #expect(badges.contains(.polarBear))
    }

    // 7. Seeded badges included even when no hike qualifies
    @Test func seededBadgesAlwaysIncluded() {
        let scout = Scout(name: "Grace", seededEarnedBadges: [.polarBear, .mile10])
        // No hikes at all
        let badges = scout.earnedBadges(completedHikes: [])

        #expect(badges.contains(.polarBear))
        #expect(badges.contains(.mile10))
    }

    // Bonus: Hike not attended by scout should not contribute mileage
    @Test func nonAttendedHikeDoesNotCountTowardMileage() {
        let scout = Scout(name: "Hank", startingMileage: 5)
        let hikeAttended = Hike(title: "Attended", status: .complete, mileage: 8)
        let hikeNotAttended = Hike(title: "Not Attended", status: .complete, mileage: 100)
        attend(scout, hikeAttended)
        // hikeNotAttended is not attended by this scout

        let mileage = scout.cumulativeMileage(completedHikes: [hikeAttended, hikeNotAttended])

        #expect(mileage == 13.0)  // 5 + 8, not 5 + 8 + 100
    }

    // Bonus: Quality badge not earned from hike scout did not attend
    @Test func qualityBadgeNotEarnedFromUnattendedHike() {
        let scout = Scout(name: "Iris")
        let hike = Hike(title: "Cold Hike", status: .complete, mileage: 3, qualitiesRaw: [.cold])
        // Scout does NOT attend this hike

        let badges = scout.earnedBadges(completedHikes: [hike])

        #expect(!badges.contains(.polarBear))
    }

    // Bonus: Pack mule not earned without backpack quality
    @Test func packMuleNotEarnedWithoutBackpack() {
        let scout = Scout(name: "Jack")
        let hike = Hike(title: "Normal Hike", status: .complete, mileage: 3)
        attend(scout, hike, qualities: [])  // No backpack

        let badges = scout.earnedBadges(completedHikes: [hike])

        #expect(!badges.contains(.packMule))
    }

    // Elevation badge earned via elevation quality
    @Test func matternhornEarnedFromElevationQuality() {
        let scout = Scout(name: "Kim")
        let hike = Hike(title: "Mountain Trail", status: .complete, mileage: 4, qualitiesRaw: [.elevation])
        attend(scout, hike)

        let badges = scout.earnedBadges(completedHikes: [hike])

        #expect(badges.contains(.matterhorn))
    }

    // Night badge earned via night quality
    @Test func ravenEarnedFromNightQuality() {
        let scout = Scout(name: "Lee")
        let hike = Hike(title: "Night Trek", status: .complete, mileage: 2, qualitiesRaw: [.night])
        attend(scout, hike)

        let badges = scout.earnedBadges(completedHikes: [hike])

        #expect(badges.contains(.raven))
    }

    // Multiple qualities on a single hike all earn their badges
    @Test func multipleQualitiesBadgesAllEarned() {
        let scout = Scout(name: "Max")
        let hike = Hike(title: "Epic Hike", status: .complete, mileage: 5,
                        qualitiesRaw: [.cold, .snow, .night, .elevation])
        attend(scout, hike)

        let badges = scout.earnedBadges(completedHikes: [hike])

        #expect(badges.contains(.polarBear))
        #expect(badges.contains(.mammoth))
        #expect(badges.contains(.raven))
        #expect(badges.contains(.matterhorn))
    }

    // Seeded badges and derived badges form a union
    @Test func seededAndDerivedBadgesUnion() {
        let scout = Scout(name: "Nina", startingMileage: 5, seededEarnedBadges: [.mile10])
        let hike = Hike(title: "Hike", status: .complete, mileage: 20, qualitiesRaw: [.cold])
        attend(scout, hike)

        let badges = scout.earnedBadges(completedHikes: [hike])

        #expect(badges.contains(.mile10))     // seeded
        #expect(badges.contains(.mile20))     // derived from 5 + 20 = 25 miles
        #expect(badges.contains(.polarBear))  // from quality
    }

    // completedHikes(from:) excludes non-complete hikes
    @Test func completedHikesExcludesNonCompleteStatuses() {
        let scout = Scout(name: "Oscar")
        let planned = Hike(title: "Planned", status: .planned, mileage: 5)
        let inProgress = Hike(title: "InProgress", status: .inProgress, mileage: 5)
        let recap = Hike(title: "Recap", status: .recap, mileage: 5)
        let complete = Hike(title: "Complete", status: .complete, mileage: 5)
        attend(scout, planned)
        attend(scout, inProgress)
        attend(scout, recap)
        attend(scout, complete)

        let result = scout.completedHikes(from: [planned, inProgress, recap, complete])

        #expect(result.count == 1)
        #expect(result.first?.title == "Complete")
    }

    // completedHikes(from:) excludes hikes not attended by the scout
    @Test func completedHikesExcludesNonAttendedHikes() {
        let scout = Scout(name: "Pat")
        let attended = Hike(title: "Attended", status: .complete, mileage: 5)
        let notAttended = Hike(title: "Not Attended", status: .complete, mileage: 5)
        attend(scout, attended)
        // scout does NOT attend notAttended

        let result = scout.completedHikes(from: [attended, notAttended])

        #expect(result.count == 1)
        #expect(result.first?.title == "Attended")
    }

    // completedHikes(from:) includes all matching hikes
    @Test func completedHikesIncludesAllAttendedCompleteHikes() {
        let scout = Scout(name: "Quinn")
        let h1 = Hike(title: "H1", status: .complete, mileage: 5)
        let h2 = Hike(title: "H2", status: .complete, mileage: 3)
        let h3 = Hike(title: "H3", status: .inProgress, mileage: 2)
        attend(scout, h1)
        attend(scout, h2)
        attend(scout, h3)

        let result = scout.completedHikes(from: [h1, h2, h3])

        #expect(result.count == 2)
    }
}
