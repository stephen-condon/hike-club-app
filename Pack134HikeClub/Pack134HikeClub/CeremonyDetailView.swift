//
//  CeremonyDetailView.swift
//  Pack134HikeClub
//

import SwiftUI
import SwiftData

// MARK: - CeremonyDetailView

struct CeremonyDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var ceremony: Ceremony
    @Query(filter: #Predicate<Scout> { $0.isActive }, sort: \Scout.name) var scouts: [Scout]
    @Query var allHikes: [Hike]
    @Query var inventoryItems: [InventoryItem]

    @State private var excludedScoutIDs: Set<PersistentIdentifier> = []

    var pendingScouts: [Scout] {
        scouts.filter { $0.hasPendingAwards(completedHikes: $0.completedHikes(from: allHikes)) }
    }

    var needs: [InventoryKind: Int] {
        ceremonyInventoryNeeds(scouts: pendingScouts, hikes: allHikes)
    }

    var shortfalls: [CeremonyShortfall] {
        ceremonyShortfalls(needs: needs, inventory: inventoryItems)
    }

    func isIncluded(_ scout: Scout) -> Bool {
        !excludedScoutIDs.contains(scout.persistentModelID)
    }

    func toggleIncluded(_ scout: Scout) {
        if excludedScoutIDs.contains(scout.persistentModelID) {
            excludedScoutIDs.remove(scout.persistentModelID)
        } else {
            excludedScoutIDs.insert(scout.persistentModelID)
        }
    }

    var body: some View {
        Form {
            Section {
                if ceremony.isComplete {
                    LabeledContent("Title", value: ceremony.title)
                    LabeledContent("Date", value: ceremony.date.formatted(date: .abbreviated, time: .omitted))
                } else {
                    TextField("Title", text: $ceremony.title)
                    DatePicker("Date", selection: $ceremony.date, displayedComponents: .date)
                }
            }

            if ceremony.isComplete {
                Section("Awards Given") {
                    let sortedAwards = ceremony.awards.sorted { ($0.scout?.name ?? "") < ($1.scout?.name ?? "") }
                    if sortedAwards.isEmpty {
                        Text("No awards given")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedAwards) { award in
                            CeremonyAwardRow(award: award)
                        }
                    }
                }
            } else {
                Section("Inventory Readiness") {
                    if needs.isEmpty {
                        Text("No pending awards")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(needs.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { kind in
                            InventoryNeedRow(
                                kind: kind,
                                need: needs[kind] ?? 0,
                                onHand: inventoryItems.first(where: { $0.kind == kind })?.count ?? 0,
                                shortfall: shortfalls.first { $0.kind == kind }
                            )
                        }
                    }
                }

                Section("Scouts") {
                    if pendingScouts.isEmpty {
                        Text("No scouts with pending awards")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pendingScouts) { scout in
                            PendingScoutRow(
                                scout: scout,
                                completedHikes: scout.completedHikes(from: allHikes),
                                isIncluded: isIncluded(scout),
                                onToggle: { toggleIncluded(scout) }
                            )
                        }
                    }
                }

                Section {
                    Button("Complete Ceremony") {
                        completeCeremony(
                            ceremony,
                            scouts: pendingScouts.filter(isIncluded),
                            hikes: allHikes,
                            context: context,
                            inventory: inventoryItems
                        )
                    }
                }
            }
        }
        .navigationTitle(ceremony.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - InventoryNeedRow

struct InventoryNeedRow: View {
    let kind: InventoryKind
    let need: Int
    let onHand: Int
    let shortfall: CeremonyShortfall?

    var displayName: String {
        kind == .hikingStick ? "Hiking Stick" : (BadgeType(rawValue: kind.rawValue)?.displayName ?? kind.rawValue)
    }

    var body: some View {
        HStack {
            Text(displayName)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Need \(need) · Have \(onHand)")
                    .font(.subheadline)
                    .foregroundStyle(shortfall != nil ? .red : .primary)
                if let shortfall {
                    Label("Buy \(shortfall.buy)", systemImage: "cart.badge.plus")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - PendingScoutRow

struct PendingScoutRow: View {
    let scout: Scout
    let completedHikes: [Hike]
    let isIncluded: Bool
    let onToggle: () -> Void

    var pendingItems: [String] {
        let badgeNames = scout.pendingBadges(completedHikes: completedHikes).map(\.displayName).sorted()
        return badgeNames + (scout.hasPendingStick ? ["Hiking Stick"] : [])
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(scout.name)
                    .font(.headline)
                Text(pendingItems.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isIncluded }, set: { _ in onToggle() }))
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - CeremonyAwardRow

struct CeremonyAwardRow: View {
    let award: CeremonyAward

    var awardedItems: [String] {
        let badgeNames = award.badges.map(\.displayName).sorted()
        return badgeNames + (award.stickGiven ? ["Hiking Stick"] : [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(award.scout?.name ?? "Unknown Scout")
                .font(.headline)
            Text(awardedItems.isEmpty ? "—" : awardedItems.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
