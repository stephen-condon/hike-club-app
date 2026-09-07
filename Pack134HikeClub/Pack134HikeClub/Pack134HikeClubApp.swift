//
//  Pack134HikeClubApp.swift
//  Pack134HikeClub
//
//  Created by Stephen Condon on 6/29/26.
//

import SwiftUI
import SwiftData

@main
struct Pack134HikeClubApp: App {
    let container: ModelContainer = {
        let schema = Schema([
            Scout.self,
            Hike.self,
            Attendance.self,
            InventoryItem.self,
            StickAssignment.self,
            Ceremony.self,
            CeremonyAward.self
        ])
        return try! ModelContainer(for: schema)
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .onAppear {
                    Seed.seedIfNeeded(context: container.mainContext)
                    Task {
                        await CeremonyReminders.requestAuthorization()
                        let context = container.mainContext
                        let ceremonies = (try? context.fetch(FetchDescriptor<Ceremony>())) ?? []
                        let scouts = (try? context.fetch(
                            FetchDescriptor<Scout>(predicate: #Predicate { $0.isActive }))) ?? []
                        let hikes = (try? context.fetch(FetchDescriptor<Hike>())) ?? []
                        let inventory = (try? context.fetch(FetchDescriptor<InventoryItem>())) ?? []
                        CeremonyReminders.reschedule(
                            ceremonies,
                            sticksToBuy: stickBuyCount(scouts: scouts, hikes: hikes, inventory: inventory))
                    }
                }
        }
    }
}
