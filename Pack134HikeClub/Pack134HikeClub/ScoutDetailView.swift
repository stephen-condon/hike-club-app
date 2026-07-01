//
//  ScoutDetailView.swift
//  Pack134HikeClub
//

import SwiftUI
import SwiftData

struct ScoutDetailView: View {
    @Bindable var scout: Scout
    @Query var allHikes: [Hike]
    @Query var inventoryItems: [InventoryItem]
    @Environment(\.modelContext) private var context

    var completedHikes: [Hike] {
        scout.completedHikes(from: allHikes)
    }

    func inventoryItem(for badge: BadgeType) -> InventoryItem? {
        inventoryItems.first(where: { $0.kind == badge.inventoryKind })
    }

    var hikingStickItem: InventoryItem? {
        inventoryItems.first(where: { $0.kind == .hikingStick })
    }

    var sortedCompletedHikes: [Hike] {
        completedHikes.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            // MARK: Header Section
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(scout.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(String(format: "%.1f mi", scout.cumulativeMileage(completedHikes: completedHikes)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                Toggle(scout.isActive ? "Active" : "Archived", isOn: $scout.isActive)
            }

            // MARK: Badges Section
            Section("Badges") {
                let earned = scout.earnedBadges(completedHikes: completedHikes)
                ForEach(BadgeType.allCases, id: \.self) { badge in
                    let isEarned = earned.contains(badge)
                    let isGiven = scout.givenBadges.contains(badge)

                    if isGiven || isEarned {
                        BadgeRow(
                            badge: badge,
                            isGiven: isGiven,
                            onGive: { giveBadge(badge) },
                            onUngive: { ungiveBadge(badge) }
                        )
                    } else {
                        Text(badge.displayName)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // MARK: Hiking Stick Section
            Section("Hiking Stick") {
                if let assignment = scout.stickAssignment {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Assigned")
                            .fontWeight(.medium)
                        Text("Since \(assignment.dateAssigned.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        returnStick(assignment: assignment)
                    } label: {
                        Text("Return Stick")
                    }
                } else {
                    Text("Not assigned")
                        .foregroundStyle(.secondary)
                    Button {
                        assignStick()
                    } label: {
                        Text("Assign Stick")
                    }
                }
            }

            // MARK: Hike History Section
            Section("Completed Hikes") {
                if sortedCompletedHikes.isEmpty {
                    Text("No completed hikes yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedCompletedHikes) { hike in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hike.title)
                                .font(.headline)
                            HStack(spacing: 8) {
                                Text(hike.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.1f mi", hike.mileage))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(scout.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Badge Actions

    private func giveBadge(_ badge: BadgeType) {
        scout.giveBadge(badge, inventory: inventoryItems)
    }

    private func ungiveBadge(_ badge: BadgeType) {
        scout.ungiveBadge(badge, inventory: inventoryItems)
    }

    // MARK: - Stick Actions

    private func assignStick() {
        scout.assignStick(context: context, inventory: inventoryItems)
    }

    private func returnStick(assignment: StickAssignment) {
        scout.returnStick(assignment, context: context, inventory: inventoryItems)
    }
}

// MARK: - BadgeRow

private struct BadgeRow: View {
    let badge: BadgeType
    let isGiven: Bool
    let onGive: () -> Void
    let onUngive: () -> Void

    var body: some View {
        HStack {
            Text(badge.displayName)
            Spacer()
            if isGiven {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Un-give", action: onUngive)
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .tint(.orange)
            } else {
                Button("Give", action: onGive)
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
            }
        }
    }
}
