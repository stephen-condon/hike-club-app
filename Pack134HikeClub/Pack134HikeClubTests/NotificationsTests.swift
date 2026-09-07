//
//  NotificationsTests.swift
//  Pack134HikeClubTests
//

import Testing
import Foundation
@testable import Pack134HikeClub

struct CeremonyRemindersTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000) // fixed "now"

    private func ceremony(weeksFromNow weeks: Int, isComplete: Bool = false) -> Ceremony {
        let date = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: now)!
        return Ceremony(title: "Award Ceremony", date: date, isComplete: isComplete)
    }

    @Test func eightWeeksOutProducesBothReminders() {
        let reminders = CeremonyReminders.upcoming(for: [ceremony(weeksFromNow: 8)], sticksToBuy: 0, now: now)
        #expect(reminders.count == 2)
        #expect(reminders.contains { $0.title == "Order badges" })
        #expect(reminders.contains { $0.title == "Buy hiking sticks" })
    }

    @Test func threeWeeksOutDropsBadgeReminder() {
        // 5-week badge reminder would be in the past; only the 2-week stick reminder survives.
        let reminders = CeremonyReminders.upcoming(for: [ceremony(weeksFromNow: 3)], sticksToBuy: 0, now: now)
        #expect(reminders.count == 1)
        #expect(reminders.first?.title == "Buy hiking sticks")
    }

    @Test func withinTwoWeeksProducesNothing() {
        let reminders = CeremonyReminders.upcoming(for: [ceremony(weeksFromNow: 1)], sticksToBuy: 0, now: now)
        #expect(reminders.isEmpty)
    }

    @Test func completeCeremonyProducesNothing() {
        let reminders = CeremonyReminders.upcoming(
            for: [ceremony(weeksFromNow: 8, isComplete: true)], sticksToBuy: 0, now: now)
        #expect(reminders.isEmpty)
    }

    @Test func fireDatesLandFiveAndTwoWeeksBeforeAtNineAM() {
        let cer = ceremony(weeksFromNow: 8)
        let reminders = CeremonyReminders.upcoming(for: [cer], sticksToBuy: 0, now: now)
        let cal = Calendar.current

        let badge = reminders.first { $0.title == "Order badges" }!
        let stick = reminders.first { $0.title == "Buy hiking sticks" }!

        let badgeDay = cal.date(byAdding: .weekOfYear, value: -5, to: cer.date)!
        let stickDay = cal.date(byAdding: .weekOfYear, value: -2, to: cer.date)!
        #expect(cal.isDate(badge.fireDate, inSameDayAs: badgeDay))
        #expect(cal.isDate(stick.fireDate, inSameDayAs: stickDay))
        #expect(cal.component(.hour, from: badge.fireDate) == 9)
        #expect(cal.component(.hour, from: stick.fireDate) == 9)
    }

    private func stickBody(sticksToBuy: Int) -> String {
        CeremonyReminders.upcoming(for: [ceremony(weeksFromNow: 8)], sticksToBuy: sticksToBuy, now: now)
            .first { $0.title == "Buy hiking sticks" }!.body
    }

    @Test func stickBodyCarriesBuyCount() {
        #expect(stickBody(sticksToBuy: 4).contains("Buy 4 hiking sticks."))
    }

    @Test func stickBodyIsSingularForOne() {
        #expect(stickBody(sticksToBuy: 1).contains("Buy 1 hiking stick."))
    }

    @Test func stickBodySaysStockedWhenNothingToBuy() {
        #expect(stickBody(sticksToBuy: 0).contains("You have enough hiking sticks on hand."))
    }
}
