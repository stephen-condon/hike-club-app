//
//  Notifications.swift
//  Pack134HikeClub
//

import Foundation
import UserNotifications

/// A local reminder to fire ahead of a ceremony (order badges / buy sticks).
struct CeremonyReminder: Equatable {
    let title: String
    let body: String
    let fireDate: Date
}

enum CeremonyReminders {

    // Lead times before a ceremony: order badges 5 weeks out, buy hiking sticks 2 weeks out.
    private static let badgeLeadWeeks = 5
    private static let stickLeadWeeks = 2
    private static let fireHour = 9   // 9 AM local on the target day

    /// Reminders for all planned (incomplete) ceremonies whose fire date is still in the future.
    static func upcoming(for ceremonies: [Ceremony], now: Date = .now) -> [CeremonyReminder] {
        let calendar = Calendar.current
        var reminders: [CeremonyReminder] = []

        for ceremony in ceremonies where !ceremony.isComplete {
            let when = ceremony.date.formatted(date: .abbreviated, time: .omitted)

            if let fire = fireDate(weeksBefore: badgeLeadWeeks, ceremony: ceremony, calendar: calendar), fire > now {
                reminders.append(CeremonyReminder(
                    title: "Order badges",
                    body: "\(ceremony.title) is on \(when). Order badges now so they arrive in time.",
                    fireDate: fire))
            }
            if let fire = fireDate(weeksBefore: stickLeadWeeks, ceremony: ceremony, calendar: calendar), fire > now {
                reminders.append(CeremonyReminder(
                    title: "Buy hiking sticks",
                    body: "\(ceremony.title) is on \(when). Pick up hiking sticks for anyone earning one.",
                    fireDate: fire))
            }
        }
        return reminders
    }

    private static func fireDate(weeksBefore weeks: Int, ceremony: Ceremony, calendar: Calendar) -> Date? {
        guard let shifted = calendar.date(byAdding: .weekOfYear, value: -weeks, to: ceremony.date) else { return nil }
        return calendar.date(bySettingHour: fireHour, minute: 0, second: 0, of: shifted)
    }

    // MARK: Scheduling (device side)

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    /// Cancels all pending reminders and re-adds one per upcoming reminder.
    /// ponytail: removeAllPending is fine — this app schedules no other notifications.
    static func reschedule(_ ceremonies: [Ceremony], now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let calendar = Calendar.current
        for (index, reminder) in upcoming(for: ceremonies, now: now).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            // Nuke-and-repave every reschedule, so IDs only need to be unique within this batch.
            let request = UNNotificationRequest(identifier: "ceremony-\(index)", content: content, trigger: trigger)
            center.add(request)
        }
    }
}
