//
//  HealthImport.swift
//  Pack134HikeClub
//
//  Read-only import of recorded hike distance + elevation from HealthKit.
//  On-device only — no network, consistent with the app's offline design.
//

import Foundation
import HealthKit

// MARK: - Pure conversions (unit-tested, no HealthKit dependency)

/// Meters → miles, rounded to the nearest half mile.
func milesRoundedToHalf(meters: Double) -> Double {
    let miles = meters / 1609.344
    return (miles * 2).rounded() / 2
}

/// Meters → whole feet.
func feet(fromMeters meters: Double) -> Double {
    (meters * 3.28084).rounded()
}

// MARK: - Imported values

struct WorkoutImport {
    let mileage: Double         // miles, rounded to nearest half
    let elevationGain: Double?  // feet, nil when the workout has no elevation metadata

    init(workout: HKWorkout) {
        let meters = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        self.mileage = milesRoundedToHalf(meters: meters)

        if let ascended = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
            self.elevationGain = feet(fromMeters: ascended.doubleValue(for: .meter()))
        } else {
            self.elevationGain = nil
        }
    }
}

// MARK: - HealthKit store wrapper (device-only, not unit-tested)

enum HealthImport {
    static let store = HKHealthStore()
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Read-only authorization for workouts (elevation rides along in workout metadata).
    static func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType()])
    }

    // ponytail: same-day filter; widen to a ±1 day window if hikes ever span midnight.
    /// Hiking workouts recorded on the same calendar day as `date`, newest first.
    static func hikingWorkouts(on date: Date, calendar: Calendar = .current) async throws -> [HKWorkout] {
        guard isAvailable else { return [] }
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForWorkouts(with: .hiking),
            HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: .strictStartDate)
        ])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try await descriptor.result(for: store)
    }
}
