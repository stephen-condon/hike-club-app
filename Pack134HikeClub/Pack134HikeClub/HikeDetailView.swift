//
//  HikeDetailView.swift
//  Pack134HikeClub
//

import SwiftUI
import SwiftData

// MARK: - HikeDetailView

struct HikeDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var hike: Hike
    @Query(filter: #Predicate<Scout> { $0.isActive }, sort: \Scout.name) var scouts: [Scout]

    @State private var mileageText: String = ""

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
                    } else {
                        LabeledContent("Mileage", value: String(format: "%.1f mi", hike.mileage))
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
                        QualityRow(hike: hike, quality: quality, isEditable: isEditable)
                    }
                }
            }
        }
        .navigationTitle(hike.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            mileageText = hike.mileage == 0 ? "" : String(hike.mileage)
        }
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
