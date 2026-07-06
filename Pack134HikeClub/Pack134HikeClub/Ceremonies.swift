//
//  Ceremonies.swift
//  Pack134HikeClub
//

import Foundation
import SwiftData

// MARK: - Scout pending awards

extension Scout {

    /// Earned badges not yet physically given out.
    func pendingBadges(completedHikes: [Hike]) -> Set<BadgeType> {
        earnedBadges(completedHikes: completedHikes).subtracting(givenBadges)
    }

    /// Stick decision made (ceremony-earned) but not yet physically awarded.
    var hasPendingStick: Bool {
        stickEarned && stickAssignment == nil
    }

    func hasPendingAwards(completedHikes: [Hike]) -> Bool {
        !pendingBadges(completedHikes: completedHikes).isEmpty || hasPendingStick
    }

    /// Gives every pending badge and, if pending, assigns the stick — reusing ScoutActions
    /// so inventory stays consistent. Returns exactly what was given, for snapshotting a CeremonyAward.
    @discardableResult
    func awardAllPending(
        completedHikes: [Hike],
        context: ModelContext,
        inventory: [InventoryItem]
    ) -> (badges: [BadgeType], stickGiven: Bool) {
        let badges = pendingBadges(completedHikes: completedHikes)
        let stickGiven = hasPendingStick

        for badge in badges {
            giveBadge(badge, inventory: inventory)
        }
        if stickGiven {
            assignStick(context: context, inventory: inventory)
        }

        return (Array(badges), stickGiven)
    }
}

// MARK: - Ceremony inventory prep

/// Per-InventoryKind count of pending items needed to cover every scout in `scouts`.
func ceremonyInventoryNeeds(scouts: [Scout], hikes: [Hike]) -> [InventoryKind: Int] {
    var needs: [InventoryKind: Int] = [:]
    for scout in scouts {
        let completedHikes = scout.completedHikes(from: hikes)
        for badge in scout.pendingBadges(completedHikes: completedHikes) {
            needs[badge.inventoryKind, default: 0] += 1
        }
        if scout.hasPendingStick {
            needs[.hikingStick, default: 0] += 1
        }
    }
    return needs
}

struct CeremonyShortfall: Equatable {
    let kind: InventoryKind
    let need: Int
    let onHand: Int
    let buy: Int
}

/// Flags kinds where handing out `needs` would drop on-hand below that item's minReserve.
func ceremonyShortfalls(needs: [InventoryKind: Int], inventory: [InventoryItem]) -> [CeremonyShortfall] {
    inventory.compactMap { item -> CeremonyShortfall? in
        let need = needs[item.kind] ?? 0
        guard item.count - need < item.minReserve else { return nil }
        return CeremonyShortfall(kind: item.kind, need: need, onHand: item.count,
                                 buy: need + item.minReserve - item.count)
    }
    .sorted { $0.kind.rawValue < $1.kind.rawValue }
}

// MARK: - Ceremony completion

/// Awards every pending item to each scout in `scouts` (reusing ScoutActions), snapshots a
/// CeremonyAward per scout actually awarded, and marks the ceremony complete. Scouts left out
/// of `scouts` (e.g. toggled off because they didn't show up) are untouched and remain pending.
@discardableResult
func completeCeremony(
    _ ceremony: Ceremony,
    scouts: [Scout],
    hikes: [Hike],
    context: ModelContext,
    inventory: [InventoryItem]
) -> [CeremonyAward] {
    var created: [CeremonyAward] = []
    for scout in scouts {
        let completedHikes = scout.completedHikes(from: hikes)
        let result = scout.awardAllPending(completedHikes: completedHikes, context: context, inventory: inventory)
        guard !result.badges.isEmpty || result.stickGiven else { continue }
        let award = CeremonyAward(scout: scout, badges: result.badges, stickGiven: result.stickGiven)
        context.insert(award)
        ceremony.awards.append(award)
        created.append(award)
    }
    ceremony.isComplete = true
    return created
}
