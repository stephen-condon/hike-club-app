//
//  CeremoniesView.swift
//  Pack134HikeClub
//

import SwiftUI
import SwiftData

// MARK: - CeremoniesView

struct CeremoniesView: View {
    @Environment(\.modelContext) private var context
    @Query var ceremonies: [Ceremony]
    @State private var showingNewCeremony = false

    var upcoming: [Ceremony] {
        ceremonies.filter { !$0.isComplete }.sorted { $0.date < $1.date }
    }

    var past: [Ceremony] {
        ceremonies.filter { $0.isComplete }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Upcoming") {
                    if upcoming.isEmpty {
                        Text("No ceremonies scheduled")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(upcoming) { ceremony in
                            NavigationLink(destination: CeremonyDetailView(ceremony: ceremony)) {
                                CeremonyRow(ceremony: ceremony)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(upcoming[index]) }
                        }
                    }
                }
                if !past.isEmpty {
                    Section("Past") {
                        ForEach(past) { ceremony in
                            NavigationLink(destination: CeremonyDetailView(ceremony: ceremony)) {
                                CeremonyRow(ceremony: ceremony)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ceremonies")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewCeremony = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewCeremony) {
                NewCeremonySheet()
            }
            // ponytail: reschedule on tab appear covers create/edit/delete/complete when the user
            // returns here; add per-mutation calls only if instant cross-tab accuracy is ever needed.
            .onAppear {
                CeremonyReminders.reschedule(ceremonies)
            }
        }
    }
}

// MARK: - CeremonyRow

struct CeremonyRow: View {
    let ceremony: Ceremony

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ceremony.title)
                .font(.headline)
            HStack(spacing: 8) {
                Text(ceremony.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if ceremony.isComplete {
                    Text("Complete")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - NewCeremonySheet

struct NewCeremonySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = "Award Ceremony"
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
            .navigationTitle("New Ceremony")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let ceremony = Ceremony(title: title.trimmingCharacters(in: .whitespaces), date: date)
                        context.insert(ceremony)
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Ceremony.self, CeremonyAward.self, configurations: config)
    return CeremoniesView()
        .modelContainer(container)
}
