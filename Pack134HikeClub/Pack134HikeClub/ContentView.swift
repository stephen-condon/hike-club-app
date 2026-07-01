//
//  ContentView.swift
//  Pack134HikeClub
//
//  Created by Stephen Condon on 6/29/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HikesView()
                .tabItem { Label("Hikes", systemImage: "figure.hiking") }
            ScoutsView()
                .tabItem { Label("Scouts", systemImage: "person.3") }
            InventoryView()
                .tabItem { Label("Inventory", systemImage: "shippingbox") }
        }
    }
}
