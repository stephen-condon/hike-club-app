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
        default:            return nil
        }
    }

    var inventoryKind: InventoryKind {
        switch self {
        case .mile10:          return .mile10
        case .mile20:          return .mile20
        case .mile30:          return .mile30
        case .mile40:          return .mile40
        case .mile50:          return .mile50
        case .mile60:          return .mile60
        case .mile70:          return .mile70
        case .mile80:          return .mile80
        case .mile90:          return .mile90
        case .mile100:         return .mile100
        case .litterBug:       return .litterBug
        case .polarBear:       return .polarBear
        case .scorpion:        return .scorpion
        case .mammoth:         return .mammoth
        case .matterhorn:      return .matterhorn
        case .tenMileMassacre: return .tenMileMassacre
        case .hippopotamus:    return .hippopotamus
        case .patriot:         return .patriot
        case .trickyFox:       return .trickyFox
        case .raven:           return .raven
        case .packMule:        return .packMule
        }
    }
}

enum InventoryKind: String, Codable, CaseIterable {
    // One case per BadgeType, plus hikingStick
    case mile10, mile20, mile30, mile40, mile50
    case mile60, mile70, mile80, mile90, mile100
    case litterBug, polarBear, scorpion, mammoth, matterhorn
    case tenMileMassacre, hippopotamus, patriot, trickyFox, raven
    case packMule
    case hikingStick
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
    @Relationship(deleteRule: .cascade) var attendances: [Attendance]
    @Relationship(deleteRule: .nullify) var stickAssignment: StickAssignment?

    init(
        name: String,
        startingMileage: Double = 0,
        isActive: Bool = true,
        dateAdded: Date = .now,
        seededEarnedBadges: [BadgeType] = [],
        givenBadges: [BadgeType] = []
    ) {
        self.name = name
        self.startingMileage = startingMileage
        self.isActive = isActive
        self.dateAdded = dateAdded
        self.seededEarnedBadges = seededEarnedBadges
        self.givenBadges = givenBadges
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
    // Store as array for SwiftData compatibility (treat as set in logic)
    var qualitiesRaw: [HikeQuality]
    var notes: String
    @Relationship(deleteRule: .cascade) var attendances: [Attendance]

    var qualities: Set<HikeQuality> { Set(qualitiesRaw) }

    init(
        title: String,
        date: Date = .now,
        status: HikeStatus = .planned,
        mileage: Double = 0,
        qualitiesRaw: [HikeQuality] = [],
        notes: String = ""
    ) {
        self.title = title
        self.date = date
        self.status = status
        self.mileage = mileage
        self.qualitiesRaw = qualitiesRaw
        self.notes = notes
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
