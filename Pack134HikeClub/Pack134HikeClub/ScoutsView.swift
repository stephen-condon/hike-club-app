//
//  ScoutsView.swift
//  Pack134HikeClub
//

import SwiftUI
import SwiftData

// MARK: - ScoutsView

struct ScoutsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Scout> { $0.isActive }, sort: \Scout.name) var scouts: [Scout]
    @Query(filter: #Predicate<Scout> { !$0.isActive }, sort: \Scout.name) var archivedScouts: [Scout]
    @Query var allHikes: [Hike]
    @State private var showingNewScout = false

    func completedHikes(for scout: Scout) -> [Hike] {
        scout.completedHikes(from: allHikes)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(scouts) { scout in
                    NavigationLink(destination: ScoutDetailView(scout: scout)) {
                        ScoutRow(scout: scout, completedHikes: completedHikes(for: scout))
                    }
                }

                if !archivedScouts.isEmpty {
                    Section("Archived") {
                        ForEach(archivedScouts) { scout in
                            NavigationLink(destination: ScoutDetailView(scout: scout)) {
                                Text(scout.name)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewScout = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewScout) {
                NewScoutSheet()
            }
        }
    }
}

// MARK: - ScoutRow

struct ScoutRow: View {
    let scout: Scout
    let completedHikes: [Hike]

    var mileage: Double {
        scout.cumulativeMileage(completedHikes: completedHikes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scout.name)
                .font(.headline)
            Text(String(format: "%.1f mi", mileage))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - NewScoutSheet

struct NewScoutSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""

    static func isSaveDisabled(name: String) -> Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isSaveDisabled: Bool {
        Self.isSaveDisabled(name: name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }
            }
            .navigationTitle("New Scout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let scout = Scout(
                            name: name.trimmingCharacters(in: .whitespaces),
                            startingMileage: 0
                        )
                        context.insert(scout)
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }
}
