//
//  HikeDetailView.swift
//  Pack134HikeClub
//

import SwiftUI
import SwiftData
import HealthKit

// MARK: - HikeDetailView

struct HikeDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var hike: Hike
    @Query(filter: #Predicate<Scout> { $0.isActive }, sort: \Scout.name) var scouts: [Scout]

    @State private var mileageText: String = ""
    @State private var importMessage: String?
    @State private var workoutChoices: [HKWorkout] = []
    @State private var showingChoices = false

    var isEditable: Bool {
        hike.status == .inProgress || hike.status == .recap
    }

    var showAttendance: Bool {
        hike.status == .inProgress || hike.status == .recap
    }

    var showDetails: Bool {
        hike.status != .planned
    }

    var body: some View {
        Form {
            // MARK: Header section
            Section {
                // Title — editable in planned/inProgress/recap
                if hike.status == .complete {
                    LabeledContent("Title", value: hike.title)
                } else {
                    TextField("Title", text: $hike.title)
                }

                // Date — editable only in planned
                if hike.status == .planned {
                    DatePicker("Date", selection: $hike.date, displayedComponents: .date)
                } else {
                    LabeledContent("Date", value: hike.date.formatted(date: .abbreviated, time: .omitted))
                }

                // Status row
                HStack {
                    Text("Status")
                    Spacer()
                    StatusBadge(status: hike.status)
                    if hike.status == .complete {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }

                // Hike API ID — editable while planned, read-only once set otherwise
                if hike.status == .planned {
                    TextField("Hike API ID (optional)", text: Binding(
                        get: { hike.apiHikeID ?? "" },
                        set: { newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                            hike.apiHikeID = trimmed.isEmpty ? nil : trimmed
                        }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                } else if let apiID = hike.apiHikeID {
                    LabeledContent("Hike API ID", value: apiID)
                }
            }

            // MARK: Trail Info — fetched from the API when the hike is linked
            if let apiID = hike.apiHikeID {
                TrailInfoView(apiHikeID: apiID)
            }

            // MARK: State machine transition
            Section {
                stateTransitionButton
            }

            // MARK: Attendance — editable in inProgress and recap
            if showAttendance {
                Section("Attendance") {
                    ForEach(scouts) { scout in
                        AttendanceRow(hike: hike, scout: scout)
                    }
                }
            }

            // MARK: Attendance — read-only in complete
            if hike.status == .complete {
                let attended = hike.attendances
                    .filter { $0.scout != nil }
                    .sorted { ($0.scout?.name ?? "") < ($1.scout?.name ?? "") }

                if !attended.isEmpty {
                    Section("Attendance") {
                        ForEach(attended) { attendance in
                            if let scout = attendance.scout {
                                HStack {
                                    Text(scout.name)
                                    Spacer()
                                    if attendance.scoutQualitiesRaw.contains(.backpack) {
                                        Image(systemName: "backpack.fill")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    }
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }

            // MARK: Hike details — visible in inProgress, recap, complete
            if showDetails {
                Section("Hike Details") {
                    // Mileage
                    if isEditable {
                        HStack {
                            Text("Mileage")
                            Spacer()
                            TextField("0.0", text: $mileageText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .onChange(of: mileageText) { _, newValue in
                                    if newValue.isEmpty {
                                        hike.mileage = 0
                                    } else if let value = Double(newValue) {
                                        hike.mileage = value
                                    }
                                    // Partial/invalid non-empty text: keep the last valid mileage
                                }
                            Text("mi")
                                .foregroundStyle(.secondary)
                        }
                        if HealthImport.isAvailable {
                            Button {
                                Task { await importFromHealth() }
                            } label: {
                                Label("Import from Health", systemImage: "heart.fill")
                            }
                        }
                    } else {
                        LabeledContent("Mileage", value: String(format: "%.1f mi", hike.mileage))
                    }

                    // Elevation gain — read-only, shown once imported
                    if let gain = hike.elevationGain {
                        LabeledContent("Elevation gain",
                                       value: "\(gain.formatted(.number.precision(.fractionLength(0)))) ft")
                    }

                    // Notes
                    if isEditable {
                        TextField("Notes", text: $hike.notes, axis: .vertical)
                            .lineLimit(3...6)
                    } else {
                        if hike.notes.isEmpty {
                            Text("No notes")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            Text(hike.notes)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Quality toggles
                Section("Qualities") {
                    ForEach(HikeQuality.allCases, id: \.self) { quality in
                        // ponytail: elevationGain != nil == "imported"; only source that sets it is Health import
                        let locked = quality == .elevation && hike.elevationGain != nil
                        QualityRow(hike: hike, quality: quality, isEditable: isEditable && !locked)
                    }
                }
            }
        }
        .navigationTitle(hike.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            mileageText = hike.mileage == 0 ? "" : String(hike.mileage)
        }
        .confirmationDialog("Choose workout", isPresented: $showingChoices, titleVisibility: .visible) {
            ForEach(workoutChoices, id: \.uuid) { workout in
                Button(workoutLabel(workout)) { apply(workout) }
            }
        }
        .alert("Import from Health",
               isPresented: Binding(get: { importMessage != nil },
                                    set: { if !$0 { importMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importMessage ?? "")
        }
    }

    // MARK: Health import

    private func importFromHealth() async {
        do {
            try await HealthImport.requestAuthorization()
            let workouts = try await HealthImport.hikingWorkouts(on: hike.date)
            switch workouts.count {
            case 0:  importMessage = "No hiking workout found for this date."
            case 1:  apply(workouts[0])
            default:
                workoutChoices = workouts
                showingChoices = true
            }
        } catch {
            importMessage = "Couldn't read Health data."
        }
    }

    private func apply(_ workout: HKWorkout) {
        let imported = WorkoutImport(workout: workout)
        hike.mileage = imported.mileage
        hike.elevationGain = imported.elevationGain
        // Imported elevation drives Matterhorn: set the quality from the data instead of by hand.
        hike.qualitiesRaw.removeAll { $0 == .elevation }
        if Hike.earnsMatterhorn(elevationFeet: hike.elevationGain) {
            hike.qualitiesRaw.append(.elevation)
        }
        mileageText = imported.mileage == 0 ? "" : String(imported.mileage)
    }

    private func workoutLabel(_ workout: HKWorkout) -> String {
        let time = workout.startDate.formatted(date: .omitted, time: .shortened)
        let miles = milesRoundedToHalf(meters: workout.totalDistance?.doubleValue(for: .meter()) ?? 0)
        return "\(time) — \(String(format: "%.1f", miles)) mi"
    }

    // MARK: State machine button

    @ViewBuilder
    var stateTransitionButton: some View {
        switch hike.status {
        case .planned:
            Button("Start Hike") {
                hike.status = .inProgress
            }
        case .inProgress:
            Button("End Hike") {
                hike.status = .recap
            }
        case .recap:
            Button("Complete") {
                hike.status = .complete
            }
        case .complete:
            Button("Reopen") {
                hike.status = .recap
            }
            .foregroundStyle(.orange)
        }
    }
}

// MARK: - AttendanceRow

struct AttendanceRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var hike: Hike
    let scout: Scout

    var attendance: Attendance? {
        hike.attendances.first(where: { $0.scout?.persistentModelID == scout.persistentModelID })
    }

    var isAttending: Bool { attendance != nil }

    var isCarryingBackpack: Bool {
        attendance?.scoutQualitiesRaw.contains(.backpack) ?? false
    }

    var body: some View {
        HStack {
            Text(scout.name)
            Spacer()
            Button {
                    guard let a = attendance else { return }
                    if isCarryingBackpack {
                        a.scoutQualitiesRaw.removeAll { $0 == .backpack }
                    } else {
                        a.scoutQualitiesRaw.append(.backpack)
                    }
                } label: {
                    Text("🎒")
                        .opacity(isAttending ? (isCarryingBackpack ? 1.0 : 0.25) : 0)
                }
                .buttonStyle(.plain)
                .disabled(!isAttending)
            Toggle("", isOn: Binding(
                get: { isAttending },
                set: { newValue in
                    if newValue {
                        let a = Attendance(hike: hike, scout: scout)
                        context.insert(a)
                        hike.attendances.append(a)
                    } else {
                        if let a = attendance {
                            context.delete(a)
                        }
                    }
                }
            ))
            .labelsHidden()
            .fixedSize()
        }
    }
}

// MARK: - QualityRow

struct QualityRow: View {
    @Bindable var hike: Hike
    let quality: HikeQuality
    let isEditable: Bool

    var isOn: Bool { hike.qualitiesRaw.contains(quality) }

    var body: some View {
        HStack {
            Text(quality.badgeType.displayName)
            Spacer()
            if isEditable {
                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { newValue in
                        if newValue {
                            if !hike.qualitiesRaw.contains(quality) {
                                hike.qualitiesRaw.append(quality)
                            }
                        } else {
                            hike.qualitiesRaw.removeAll { $0 == quality }
                        }
                    }
                ))
                .labelsHidden()
            } else {
                if isOn {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "minus")
                        .foregroundStyle(.quaternary)
                }
            }
        }
    }
}
