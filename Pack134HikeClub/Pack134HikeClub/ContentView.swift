//
//  ContentView.swift
//  Pack134HikeClub
//
//  Created by Stephen Condon on 6/29/26.
//

import SwiftUI

struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            TabView {
                HikesView()
                    .tabItem { Label("Hikes", systemImage: "figure.hiking") }
                ScoutsView()
                    .tabItem { Label("Scouts", systemImage: "person.3") }
                InventoryView()
                    .tabItem { Label("Inventory", systemImage: "shippingbox") }
            }
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
                    }
            }
        }
    }
}
