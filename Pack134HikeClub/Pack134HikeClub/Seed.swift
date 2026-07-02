//
//  Seed.swift
//  Pack134HikeClub
//

import Foundation
import SwiftData

enum Seed {
    static func seedIfNeeded(context: ModelContext) {
        let existingScouts = try? context.fetch(FetchDescriptor<Scout>())
        if existingScouts?.isEmpty ?? true {
            seedScouts(context: context)
        }

        let existingInventory = try? context.fetch(FetchDescriptor<InventoryItem>())
        if existingInventory?.isEmpty ?? true {
            seedInventory(context: context)
        }
    }

    // MARK: - Roster Parsing

    /// Parses CSV roster contents (with header row) into `Scout` objects.
    /// The header row is skipped; blank lines are ignored.
    /// Columns: name, startingMileage (optional), earnedBadges (optional, `;`-separated rawValues, seeded
    /// as earned-but-not-given), stick (optional: `has` = earned & awarded, `earned` = earned only, blank = neither).
    static func parseRoster(_ contents: String) -> [Scout] {
        let lines = contents.components(separatedBy: .newlines)
        var scouts: [Scout] = []
        for line in lines.dropFirst() { // skip header row
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // ponytail: naive CSV split, swap for a real parser only if names ever need quoting
            let columns = trimmed.components(separatedBy: ",")
            let name = columns[0]
            let startingMileage = columns.count > 1 ? Double(columns[1]) ?? 0.0 : 0.0
            let seededEarnedBadges: [BadgeType]
            if columns.count > 2 && !columns[2].isEmpty {
                seededEarnedBadges = columns[2]
                    .components(separatedBy: ";")
                    .compactMap { BadgeType(rawValue: $0) }
            } else {
                seededEarnedBadges = []
            }
            let stickToken = columns.count > 3
                ? columns[3].trimmingCharacters(in: .whitespaces).lowercased()
                : ""
            let stickEarned = stickToken == "has" || stickToken == "earned"

            let scout = Scout(
                name: name,
                startingMileage: startingMileage,
                isActive: true,
                dateAdded: .now,
                seededEarnedBadges: seededEarnedBadges,
                givenBadges: [], // seeded awards are earned, not yet physically handed out
                stickEarned: stickEarned
            )
            if stickToken == "has" {
                scout.stickAssignment = StickAssignment(scout: scout)
            }
            scouts.append(scout)
        }
        return scouts
    }

    // MARK: - Private

    private static func seedScouts(context: ModelContext) {
        guard let url = Bundle.main.url(forResource: "Roster", withExtension: "csv"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return }

        for scout in parseRoster(contents) {
            context.insert(scout)
            if let assignment = scout.stickAssignment { context.insert(assignment) }
        }
    }

    private static func seedInventory(context: ModelContext) {
        for kind in InventoryKind.allCases {
            let item = InventoryItem(kind: kind, count: 0, minReserve: 0)
            context.insert(item)
        }
    }
}
