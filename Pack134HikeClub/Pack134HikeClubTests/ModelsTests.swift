//
//  ModelsTests.swift
//  Pack134HikeClubTests
//

import Testing
@testable import Pack134HikeClub

// MARK: - HikeQuality.badgeType

struct HikeQualityTests {

    @Test func allCasesBadgeTypeMappings() {
        #expect(HikeQuality.litterCleanup.badgeType == .litterBug)
        #expect(HikeQuality.cold.badgeType == .polarBear)
        #expect(HikeQuality.hot.badgeType == .scorpion)
        #expect(HikeQuality.snow.badgeType == .mammoth)
        #expect(HikeQuality.elevation.badgeType == .matterhorn)
        #expect(HikeQuality.rainMud.badgeType == .hippopotamus)
        #expect(HikeQuality.parade.badgeType == .patriot)
        #expect(HikeQuality.unimproved.badgeType == .trickyFox)
        #expect(HikeQuality.night.badgeType == .raven)
        #expect(HikeQuality.river.badgeType == .riverRunner)
    }
}

// MARK: - BadgeType

struct BadgeTypeTests {

    @Test func displayNameAllNonEmpty() {
        for badge in BadgeType.allCases {
            #expect(!badge.displayName.isEmpty, "displayName empty for \(badge)")
        }
    }

    @Test func displayNameSpotChecks() {
        #expect(BadgeType.mile10.displayName == "10 Mile")
        #expect(BadgeType.mile100.displayName == "100 Mile")
        #expect(BadgeType.tenMileMassacre.displayName == "10-Mile Massacre")
        #expect(BadgeType.packMule.displayName == "Pack Mule")
        #expect(BadgeType.raven.displayName == "Raven")
        #expect(BadgeType.polarBear.displayName == "Polar Bear")
    }

    @Test func mileageThresholdMileageBadges() {
        #expect(BadgeType.mile10.mileageThreshold == 10.0)
        #expect(BadgeType.mile20.mileageThreshold == 20.0)
        #expect(BadgeType.mile30.mileageThreshold == 30.0)
        #expect(BadgeType.mile40.mileageThreshold == 40.0)
        #expect(BadgeType.mile50.mileageThreshold == 50.0)
        #expect(BadgeType.mile60.mileageThreshold == 60.0)
        #expect(BadgeType.mile70.mileageThreshold == 70.0)
        #expect(BadgeType.mile80.mileageThreshold == 80.0)
        #expect(BadgeType.mile90.mileageThreshold == 90.0)
        #expect(BadgeType.mile100.mileageThreshold == 100.0)
    }

    @Test func mileageThresholdNilForNonMileageBadges() {
        #expect(BadgeType.litterBug.mileageThreshold == nil)
        #expect(BadgeType.tenMileMassacre.mileageThreshold == nil)
        #expect(BadgeType.packMule.mileageThreshold == nil)
        #expect(BadgeType.raven.mileageThreshold == nil)
    }

    @Test func hikeQualityMappings() {
        #expect(BadgeType.litterBug.hikeQuality == .litterCleanup)
        #expect(BadgeType.polarBear.hikeQuality == .cold)
        #expect(BadgeType.scorpion.hikeQuality == .hot)
        #expect(BadgeType.mammoth.hikeQuality == .snow)
        #expect(BadgeType.matterhorn.hikeQuality == .elevation)
        #expect(BadgeType.hippopotamus.hikeQuality == .rainMud)
        #expect(BadgeType.patriot.hikeQuality == .parade)
        #expect(BadgeType.trickyFox.hikeQuality == .unimproved)
        #expect(BadgeType.raven.hikeQuality == .night)
        #expect(BadgeType.riverRunner.hikeQuality == .river)
    }

    @Test func hikeQualityNilForNonQualityBadges() {
        #expect(BadgeType.mile10.hikeQuality == nil)
        #expect(BadgeType.mile100.hikeQuality == nil)
        #expect(BadgeType.tenMileMassacre.hikeQuality == nil)
        #expect(BadgeType.packMule.hikeQuality == nil)
    }

    @Test func inventoryKindRawValueRoundTrip() {
        for badge in BadgeType.allCases {
            let kind = badge.inventoryKind
            #expect(kind.rawValue == badge.rawValue,
                    "rawValue mismatch: badge=\(badge.rawValue) kind=\(kind.rawValue)")
            #expect(InventoryKind(rawValue: kind.rawValue) != nil)
        }
    }
}

// MARK: - Hike model

struct HikeModelTests {

    @Test func qualitiesSetDedupsDuplicates() {
        let hike = Hike(title: "Test", qualitiesRaw: [.cold, .cold, .hot])
        #expect(hike.qualities.count == 2)
        #expect(hike.qualities.contains(.cold))
        #expect(hike.qualities.contains(.hot))
    }

    @Test func qualitiesEmptyWhenNoRawQualities() {
        let hike = Hike(title: "Test", qualitiesRaw: [])
        #expect(hike.qualities.isEmpty)
    }
}

// MARK: - Attendance model

struct AttendanceModelTests {

    @Test func scoutQualitiesSetDedupsDuplicates() {
        let scout = Scout(name: "Test")
        let hike = Hike(title: "Test")
        let att = Attendance(hike: hike, scout: scout, scoutQualitiesRaw: [.backpack, .backpack])
        #expect(att.scoutQualities.count == 1)
        #expect(att.scoutQualities.contains(.backpack))
    }

    @Test func scoutQualitiesEmptyByDefault() {
        let scout = Scout(name: "Test")
        let hike = Hike(title: "Test")
        let att = Attendance(hike: hike, scout: scout)
        #expect(att.scoutQualities.isEmpty)
    }
}

// MARK: - InventoryItem model

struct InventoryItemTests {

    @Test func isLowTrueWhenBelowMinReserve() {
        let item = InventoryItem(kind: .mile10, count: 2, minReserve: 5)
        #expect(item.isLow == true)
    }

    @Test func isLowFalseWhenEqualToMinReserve() {
        let item = InventoryItem(kind: .mile10, count: 5, minReserve: 5)
        #expect(item.isLow == false) // count < minReserve is false when equal
    }

    @Test func isLowFalseWhenAboveMinReserve() {
        let item = InventoryItem(kind: .mile10, count: 10, minReserve: 5)
        #expect(item.isLow == false)
    }

    @Test func isLowFalseWhenMinReserveIsZero() {
        let item = InventoryItem(kind: .mile10, count: 0, minReserve: 0)
        #expect(item.isLow == false) // 0 < 0 is false
    }
}

// MARK: - Scout init defaults

struct ScoutInitTests {

    @Test func defaultsAreCorrect() {
        let scout = Scout(name: "Test Scout")
        #expect(scout.name == "Test Scout")
        #expect(scout.startingMileage == 0.0)
        #expect(scout.isActive == true)
        #expect(scout.seededEarnedBadges.isEmpty)
        #expect(scout.givenBadges.isEmpty)
        #expect(scout.attendances.isEmpty)
        #expect(scout.stickAssignment == nil)
    }

    @Test func customInitValuesAreStored() {
        let scout = Scout(
            name: "Alice",
            startingMileage: 42.5,
            isActive: false,
            seededEarnedBadges: [.mile10, .polarBear],
            givenBadges: [.raven]
        )
        #expect(scout.name == "Alice")
        #expect(scout.startingMileage == 42.5)
        #expect(scout.isActive == false)
        #expect(scout.seededEarnedBadges == [.mile10, .polarBear])
        #expect(scout.givenBadges == [.raven])
    }
}
