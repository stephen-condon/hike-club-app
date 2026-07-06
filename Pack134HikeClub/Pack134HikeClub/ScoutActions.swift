//
//  ScoutActions.swift
//  Pack134HikeClub
//

import Foundation
import SwiftData

extension Scout {

    /// Appends `badge` to `givenBadges` and decrements the matching inventory item (floor 0).
    /// Giving an already-given badge is a no-op (no duplicate entry, no double decrement).
    func giveBadge(_ badge: BadgeType, inventory: [InventoryItem]) {
        guard !givenBadges.contains(badge) else { return }
        givenBadges.append(badge)
        if let item = inventory.first(where: { $0.kind == badge.inventoryKind }) {
            item.count = max(0, item.count - 1)
        }
    }

    /// Removes the first occurrence of `badge` from `givenBadges` and increments the inventory item.
    /// If the badge wasn't given, this is a no-op (inventory is untouched).
    func ungiveBadge(_ badge: BadgeType, inventory: [InventoryItem]) {
        guard let idx = givenBadges.firstIndex(of: badge) else { return }
        givenBadges.remove(at: idx)
        if let item = inventory.first(where: { $0.kind == badge.inventoryKind }) {
            item.count += 1
        }
    }

    /// Creates a `StickAssignment`, sets the relationship, and decrements the hiking stick inventory (floor 0).
    func assignStick(context: ModelContext, inventory: [InventoryItem]) {
        let assignment = StickAssignment(scout: self)
        context.insert(assignment)
        stickAssignment = assignment
        stickEarned = true
        if let item = inventory.first(where: { $0.kind == .hikingStick }) {
            item.count = max(0, item.count - 1)
        }
    }

    /// Clears the stick relationship, deletes the assignment, and increments the hiking stick inventory.
    func returnStick(_ assignment: StickAssignment, context: ModelContext, inventory: [InventoryItem]) {
        stickAssignment = nil
        context.delete(assignment)
        if let item = inventory.first(where: { $0.kind == .hikingStick }) {
            item.count += 1
        }
    }
}
