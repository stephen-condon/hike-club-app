//
//  Models.swift
//  Pack134HikeClub
//

import Foundation
import SwiftData

// MARK: - Enums

enum HikeStatus: String, Codable, CaseIterable {
    case planned, inProgress, recap, complete
}

enum HikeQuality: String, Codable, CaseIterable {
    // Manual toggles only — these map 1:1 to quality badges
    case litterCleanup   // Litter Bug badge
    case cold            // Polar Bear: <40°F
    case hot             // Scorpion: >79°F
    case snow            // Mammoth: snow on ground/falling
    case elevation       // Matterhorn: >100ft elevation change
    case rainMud         // Hippopotamus: rain or muddy trail
    case parade          // Patriot: parade in uniform
    case unimproved      // Tricky Fox: dirt/grass trail
    case night           // Raven: dusk/night hike
    case river           // River Runner: near water (pond/lake/river)
    // NOTE: 10-Mile Massacre is NOT here — it's derived from hike.mileage >= 10

    var badgeType: BadgeType {
        switch self {
        case .litterCleanup: return .litterBug
        case .cold:          return .polarBear
        case .hot:           return .scorpion
        case .snow:          return .mammoth
        case .elevation:     return .matterhorn
        case .rainMud:       return .hippopotamus
        case .parade:        return .patriot
        case .unimproved:    return .trickyFox
        case .night:         return .raven
        case .river:         return .riverRunner
        }
    }
}

enum ScoutQuality: String, Codable, CaseIterable {
    case backpack  // Pack Mule badge
}

enum BadgeType: String, Codable, CaseIterable {
    // Mileage badges
    case mile10, mile20, mile30, mile40, mile50
    case mile60, mile70, mile80, mile90, mile100
    // Quality badges (from HikeQuality)
    case litterBug, polarBear, scorpion, mammoth, matterhorn
    case tenMileMassacre, hippopotamus, patriot, trickyFox, raven
    case riverRunner = "river"
    // Scout quality badge
    case packMule

    var displayName: String {
        switch self {
        case .mile10:          return "10 Mile"
        case .mile20:          return "20 Mile"
        case .mile30:          return "30 Mile"
        case .mile40:          return "40 Mile"
        case .mile50:          return "50 Mile"
        case .mile60:          return "60 Mile"
        case .mile70:          return "70 Mile"
        case .mile80:          return "80 Mile"
        case .mile90:          return "90 Mile"
        case .mile100:         return "100 Mile"
        case .litterBug:       return "Litter Bug"
        case .polarBear:       return "Polar Bear"
        case .scorpion:        return "Scorpion"
        case .mammoth:         return "Mammoth"
        case .matterhorn:      return "Matterhorn"
        case .tenMileMassacre: return "10-Mile Massacre"
        case .hippopotamus:    return "Hippopotamus"
        case .patriot:         return "Patriot"
        case .trickyFox:       return "Tricky Fox"
        case .raven:           return "Raven"
        case .riverRunner:     return "River Runner"
        case .packMule:        return "Pack Mule"
        }
    }

    var mileageThreshold: Double? {
        switch self {
        case .mile10:  return 10.0
        case .mile20:  return 20.0
        case .mile30:  return 30.0
        case .mile40:  return 40.0
        case .mile50:  return 50.0
        case .mile60:  return 60.0
        case .mile70:  return 70.0
        case .mile80:  return 80.0
        case .mile90:  return 90.0
        case .mile100: return 100.0
        default:       return nil
        }
    }

    var hikeQuality: HikeQuality? {
        switch self {
        case .litterBug:    return .litterCleanup
        case .polarBear:    return .cold
        case .scorpion:     return .hot
        case .mammoth:      return .snow
        case .matterhorn:   return .elevation
        case .hippopotamus: return .rainMud
        case .patriot:      return .parade
        case .trickyFox:    return .unimproved
        case .raven:        return .night
        case .riverRunner:  return .river
        default:            return nil
        }
    }

    var inventoryKind: InventoryKind {
        // rawValues are aligned 1:1 by construction (including riverRunner == "river" on both enums)
        InventoryKind(rawValue: rawValue)!
    }
}

enum InventoryKind: String, Codable, CaseIterable {
    // One case per BadgeType, plus hikingStick
    case mile10, mile20, mile30, mile40, mile50
    case mile60, mile70, mile80, mile90, mile100
    case litterBug, polarBear, scorpion, mammoth, matterhorn
    case tenMileMassacre, hippopotamus, patriot, trickyFox, raven
    case riverRunner = "river"
    case packMule
    case hikingStick
}

extension InventoryKind {
    var displayName: String {
        self == .hikingStick ? "Hiking Stick" : (BadgeType(rawValue: rawValue)?.displayName ?? rawValue)
    }
}

// MARK: - @Model Classes

@Model
class Scout {
    var name: String
    var startingMileage: Double
    var isActive: Bool
    var dateAdded: Date
    // Already-earned badges seeded from before the app (exclude from re-awarding logic)
    var seededEarnedBadges: [BadgeType]
    // Physically handed out (inventory-decrementing); append to award, remove to un-give
    var givenBadges: [BadgeType]
    // Stick earned (ceremony decision) but not necessarily awarded; stickAssignment != nil means awarded
    var stickEarned: Bool = false
    @Relationship(deleteRule: .cascade) var attendances: [Attendance]
    @Relationship(deleteRule: .nullify) var stickAssignment: StickAssignment?

    init(
        name: String,
        startingMileage: Double = 0,
        isActive: Bool = true,
        dateAdded: Date = .now,
        seededEarnedBadges: [BadgeType] = [],
        givenBadges: [BadgeType] = [],
        stickEarned: Bool = false
    ) {
        self.name = name
        self.startingMileage = startingMileage
        self.isActive = isActive
        self.dateAdded = dateAdded
        self.seededEarnedBadges = seededEarnedBadges
        self.givenBadges = givenBadges
        self.stickEarned = stickEarned
        self.attendances = []
        self.stickAssignment = nil
    }
}

@Model
class Hike {
    var title: String
    var date: Date
    var status: HikeStatus
    var mileage: Double
    // Feet, nil until imported from a HealthKit hiking workout
    var elevationGain: Double?
    // Store as array for SwiftData compatibility (treat as set in logic)
    var qualitiesRaw: [HikeQuality]
    var notes: String
    // Matching hike id in the Hike Club API; nil = not linked. Drives the Trail Info fetch.
    var apiHikeID: String?
    @Relationship(deleteRule: .cascade) var attendances: [Attendance]

    var qualities: Set<HikeQuality> { Set(qualitiesRaw) }

    // Matterhorn is earned for hikes with at least this much elevation gain.
    static let matterhornElevationFeet = 100.0

    /// True when imported elevation clears the Matterhorn threshold. nil elevation (not imported) → false.
    static func earnsMatterhorn(elevationFeet: Double?) -> Bool {
        guard let feet = elevationFeet else { return false }
        return feet >= matterhornElevationFeet
    }

    init(
        title: String,
        date: Date = .now,
        status: HikeStatus = .planned,
        mileage: Double = 0,
        elevationGain: Double? = nil,
        qualitiesRaw: [HikeQuality] = [],
        notes: String = "",
        apiHikeID: String? = nil
    ) {
        self.title = title
        self.date = date
        self.status = status
        self.mileage = mileage
        self.elevationGain = elevationGain
        self.qualitiesRaw = qualitiesRaw
        self.notes = notes
        self.apiHikeID = apiHikeID
        self.attendances = []
    }
}

@Model
class Attendance {
    var hike: Hike?
    var scout: Scout?
    // Store as array for SwiftData compatibility
    var scoutQualitiesRaw: [ScoutQuality]

    var scoutQualities: Set<ScoutQuality> { Set(scoutQualitiesRaw) }

    init(hike: Hike, scout: Scout, scoutQualitiesRaw: [ScoutQuality] = []) {
        self.hike = hike
        self.scout = scout
        self.scoutQualitiesRaw = scoutQualitiesRaw
    }
}

@Model
class InventoryItem {
    var kind: InventoryKind
    var count: Int
    var minReserve: Int

    var isLow: Bool { count < minReserve }

    init(kind: InventoryKind, count: Int = 0, minReserve: Int = 0) {
        self.kind = kind
        self.count = count
        self.minReserve = minReserve
    }
}

@Model
class StickAssignment {
    var scout: Scout?
    var dateAssigned: Date

    init(scout: Scout, dateAssigned: Date = .now) {
        self.scout = scout
        self.dateAssigned = dateAssigned
    }
}

@Model
class Ceremony {
    var title: String
    var date: Date
    var isComplete: Bool
    // Historical snapshot of what was actually handed out here, populated on completion.
    @Relationship(deleteRule: .cascade) var awards: [CeremonyAward]

    init(title: String, date: Date = .now, isComplete: Bool = false) {
        self.title = title
        self.date = date
        self.isComplete = isComplete
        self.awards = []
    }
}

@Model
class CeremonyAward {
    var ceremony: Ceremony?
    @Relationship(deleteRule: .nullify) var scout: Scout?
    var badges: [BadgeType]
    var stickGiven: Bool

    init(scout: Scout, badges: [BadgeType] = [], stickGiven: Bool = false) {
        self.scout = scout
        self.badges = badges
        self.stickGiven = stickGiven
    }
}
