//
//  Awards.swift
//  Pack134HikeClub
//

import Foundation
import SwiftData

// ponytail: O(hikes×scouts) recomputed on view render — fine for pack-sized data; cache if slow

extension Scout {

    /// Filters `allHikes` to only those that are complete AND attended by this scout.
    func completedHikes(from allHikes: [Hike]) -> [Hike] {
        allHikes.filter { $0.status == .complete &&
            $0.attendances.contains { $0.scout?.persistentModelID == persistentModelID } }
    }

    /// Filters `completedHikes` to those this scout actually attended.
    private func attendedHikes(from completedHikes: [Hike]) -> [Hike] {
        let attendedHikeIds = Set(attendances.compactMap { $0.hike }.map { ObjectIdentifier($0) })
        return completedHikes.filter { attendedHikeIds.contains(ObjectIdentifier($0)) }
    }

    /// Total mileage: startingMileage + sum of mileage for completed hikes this scout attended.
    func cumulativeMileage(completedHikes: [Hike]) -> Double {
        let attended = attendedHikes(from: completedHikes)
        return startingMileage + attended.reduce(0) { $0 + $1.mileage }
    }

    /// Full set of earned badges derived from seeded badges, mileage, hike qualities, and scout qualities.
    func earnedBadges(completedHikes: [Hike]) -> Set<BadgeType> {
        let attended = attendedHikes(from: completedHikes)
        var badges = Set(seededEarnedBadges)

        // Mileage badges
        let mileage = cumulativeMileage(completedHikes: completedHikes)
        for badge in BadgeType.allCases {
            if let threshold = badge.mileageThreshold, threshold <= mileage {
                badges.insert(badge)
            }
        }

        // 10-Mile Massacre: any attended completed hike >= 10 miles
        if attended.contains(where: { $0.mileage >= 10.0 }) {
            badges.insert(.tenMileMassacre)
        }

        // Quality badges: each HikeQuality present on any attended completed hike
        for hike in attended {
            for quality in hike.qualitiesRaw {
                badges.insert(quality.badgeType)
            }
        }

        // Pack Mule: scout wore a backpack on any attended completed hike
        let attendedIds = Set(attended.map { ObjectIdentifier($0) })
        let hasBackpack = attendances.contains { attendance in
            guard let hikeRef = attendance.hike else { return false }
            return attendedIds.contains(ObjectIdentifier(hikeRef))
                && attendance.scoutQualitiesRaw.contains(.backpack)
        }
        if hasBackpack {
            badges.insert(.packMule)
        }

        return badges
    }
}
