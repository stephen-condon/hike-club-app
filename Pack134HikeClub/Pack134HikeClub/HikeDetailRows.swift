//
//  HikeDetailRows.swift
//  Pack134HikeClub
//
//  Row views used by HikeDetailView's Attendance and Qualities sections.
//  Split out of HikeDetailView.swift to keep it under the file-length lint limit.
//

import SwiftUI
import SwiftData

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
