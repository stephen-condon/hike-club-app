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

    var pendingScouts: [Scout] {
        scouts.filter { $0.hasPendingAwards(completedHikes: $0.completedHikes(from: allHikes)) }
    }

    func hasEarnedStick(_ scout: Scout) -> Bool {
        scout.hasEarnedStick(completedHikes: scout.completedHikes(from: allHikes))
    }

    // @spec CEREM-034
    func isIncluded(_ scout: Scout) -> Bool {
        hasEarnedStick(scout) && ceremony.isIncluded(scout)
    }

    var needs: [InventoryKind: Int] {
        ceremonyInventoryNeeds(scouts: pendingScouts, hikes: allHikes)
    }

    var shortfalls: [CeremonyShortfall] {
        ceremonyShortfalls(needs: needs, inventory: inventoryItems)
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
                    let kinds = Set(needs.keys).union(shortfalls.map(\.kind))
                        .sorted { $0.rawValue < $1.rawValue }
                    if kinds.isEmpty {
                        Text("No pending awards")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(kinds, id: \.self) { kind in
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
                                canInclude: hasEarnedStick(scout),
                                onToggle: { ceremony.toggleExcluded(scout) }
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

    var body: some View {
        HStack {
            Text(kind.displayName)
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
    let canInclude: Bool
    let onToggle: () -> Void

    var pendingItems: [String] {
        scout.pendingBadges(completedHikes: completedHikes).map(\.displayName).sorted()
    }

    var showsStick: Bool {
        scout.hasPendingStick(completedHikes: completedHikes)
    }

    // @spec CEREM-036
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(scout.name)
                        .font(.headline)
                    if showsStick { HikingStickIcon() }
                }
                if !pendingItems.isEmpty {
                    Text(pendingItems.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isIncluded }, set: { _ in onToggle() }))
                .labelsHidden()
                .disabled(!canInclude)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - CeremonyAwardRow

struct CeremonyAwardRow: View {
    let award: CeremonyAward

    var awardedItems: [String] {
        award.badges.map(\.displayName).sorted()
    }

    // @spec CEREM-036
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(award.scout?.name ?? "Unknown Scout")
                    .font(.headline)
                if award.stickGiven { HikingStickIcon() }
            }
            if !awardedItems.isEmpty {
                Text(awardedItems.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - HikingStickIcon

/// The stick is the milestone award, so it gets an icon beside the name rather than a list entry.
struct HikingStickIcon: View {
    var body: some View {
        Image(systemName: "figure.hiking")
            .foregroundStyle(.brown)
            .accessibilityLabel("Hiking Stick")
    }
}
