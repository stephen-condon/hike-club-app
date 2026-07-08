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
                        let ceremonies = (try? container.mainContext.fetch(FetchDescriptor<Ceremony>())) ?? []
                        CeremonyReminders.reschedule(ceremonies)
                    }
                }
        }
    }
}
