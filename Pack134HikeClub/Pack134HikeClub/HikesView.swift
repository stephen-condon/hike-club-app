//
//  HikesView.swift
//  Pack134HikeClub
//

import SwiftUI
import SwiftData

// MARK: - HikesView

struct HikesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Hike.date) var hikes: [Hike]
    @State private var showingNewHike = false
    @State private var hikeToDelete: Hike?

    // Upcoming/active hikes soonest first; completed hikes most recent first (mirrors CeremoniesView).
    var upcoming: [Hike] {
        hikes.filter { $0.status != .complete }.sorted { $0.date < $1.date }
    }

    var completed: [Hike] {
        hikes.filter { $0.status == .complete }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Upcoming") {
                    if upcoming.isEmpty {
                        Text("No hikes scheduled")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(upcoming) { hike in
                            NavigationLink(destination: HikeDetailView(hike: hike)) {
                                HikeRow(hike: hike)
                            }
                        }
                    }
                }
                if !completed.isEmpty {
                    Section("Completed") {
                        ForEach(completed) { hike in
                            NavigationLink(destination: HikeDetailView(hike: hike)) {
                                HikeRow(hike: hike)
                            }
                        }
                        .onDelete { offsets in
                            hikeToDelete = offsets.first.map { completed[$0] }
                        }
                    }
                }
            }
            .navigationTitle("Hikes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewHike = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewHike) {
                NewHikeSheet()
            }
            .alert("Delete this hike?", isPresented: Binding(
                get: { hikeToDelete != nil },
                set: { if !$0 { hikeToDelete = nil } }
            ), presenting: hikeToDelete) { hike in
                Button("Delete", role: .destructive) {
                    context.delete(hike)
                    hikeToDelete = nil
                }
                Button("Cancel", role: .cancel) { hikeToDelete = nil }
            } message: { hike in
                Text("\"\(hike.title)\" will be removed and its attendees' mileage and badges recalculated.")
            }
        }
    }
}

// MARK: - HikeRow

struct HikeRow: View {
    let hike: Hike

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hike.title)
                .font(.headline)
            HStack(spacing: 8) {
                Text(hike.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                StatusBadge(status: hike.status)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - StatusBadge (shared with HikeDetailView)

struct StatusBadge: View {
    let status: HikeStatus

    var label: String {
        switch status {
        case .planned:    return "Planned"
        case .inProgress: return "In Progress"
        case .recap:      return "Recap"
        case .complete:   return "Complete"
        }
    }

    var color: Color {
        switch status {
        case .planned:    return .gray
        case .inProgress: return .blue
        case .recap:      return .orange
        case .complete:   return .green
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - NewHikeSheet

struct NewHikeSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var date = Date()

    static func isSaveDisabled(title: String) -> Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var isSaveDisabled: Bool {
        Self.isSaveDisabled(title: title)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("New Hike")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Location (and thus apiHikeID) is set later on the hike detail page.
                        let hike = Hike(
                            title: title.trimmingCharacters(in: .whitespaces),
                            date: date,
                            status: .planned,
                            mileage: 0,
                            notes: ""
                        )
                        context.insert(hike)
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }
}
