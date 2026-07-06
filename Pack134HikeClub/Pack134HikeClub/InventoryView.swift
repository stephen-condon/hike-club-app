//
//  InventoryView.swift
//  Pack134HikeClub
//

import SwiftUI
import SwiftData

// MARK: - InventoryView Helpers

/// Returns badge items (non-hikingStick) ordered by InventoryKind declaration order.
func orderedBadgeItems(from items: [InventoryItem]) -> [InventoryItem] {
    let kinds = InventoryKind.allCases.filter { $0 != .hikingStick }
    return kinds.compactMap { kind in items.first { $0.kind == kind } }
}

/// Returns only hikingStick items from the given inventory.
func equipmentItems(from items: [InventoryItem]) -> [InventoryItem] {
    items.filter { $0.kind == .hikingStick }
}

// MARK: - InventoryView

struct InventoryView: View {
    @Query var items: [InventoryItem]
    @State private var editingItem: InventoryItem?

    /// Badge items ordered by InventoryKind declaration order (mileage → quality → packMule)
    var badgeItems: [InventoryItem] {
        orderedBadgeItems(from: items)
    }

    var equipmentItems: [InventoryItem] {
        Pack134HikeClub.equipmentItems(from: items)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Badges") {
                    ForEach(badgeItems) { item in
                        InventoryRow(item: item) {
                            editingItem = item
                        }
                    }
                }
                Section("Equipment") {
                    ForEach(equipmentItems) { item in
                        InventoryRow(item: item) {
                            editingItem = item
                        }
                    }
                }
            }
            .navigationTitle("Inventory")
            .sheet(item: $editingItem) { item in
                MinReserveSheet(item: item)
            }
        }
    }
}

// MARK: - InventoryRow

struct InventoryRow: View {
    @Bindable var item: InventoryItem
    let onEditMinReserve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(item.kind.displayName)
                    .font(.headline)
                Spacer()
                Button {
                    if item.count > 0 { item.count -= 1 }
                } label: {
                    Image(systemName: "minus.circle")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)

                Text("\(item.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(item.isLow ? .red : .primary)
                    .frame(minWidth: 32, alignment: .center)

                Button {
                    item.count += 1
                } label: {
                    Image(systemName: "plus.circle")
                        .imageScale(.large)
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 6) {
                Text("Min: \(item.minReserve)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    onEditMinReserve()
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)

                if item.isLow {
                    Spacer()
                    Label("Low stock", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - MinReserveSheet

struct MinReserveSheet: View {
    @Bindable var item: InventoryItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Min Reserve: \(item.minReserve)", value: $item.minReserve, in: 0...999)
                } header: {
                    Text(item.kind.displayName)
                } footer: {
                    Text("A warning appears when inventory falls below this number.")
                }
            }
            .navigationTitle("Min Reserve")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: InventoryItem.self, configurations: config)
    let ctx = container.mainContext
    for kind in InventoryKind.allCases {
        let item = InventoryItem(kind: kind, count: Int.random(in: 0...10), minReserve: 3)
        ctx.insert(item)
    }
    return InventoryView()
        .modelContainer(container)
}
