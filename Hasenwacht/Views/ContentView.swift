//
//  ContentView.swift
//  Hasenwacht
//
//  Hauptcontainer mit TabView.
//  Auf iOS 26+ kommt der Liquid-Glass-Look der Tab-Bar automatisch.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // Tab 1: Mittagessen
            LunchOverviewView()
                .tabItem {
                    Label("Mittagessen", systemImage: "fork.knife")
                }

            // Tab 2: Profil
            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle")
                }
        }
    }
}

#Preview {
    ContentView()
}
