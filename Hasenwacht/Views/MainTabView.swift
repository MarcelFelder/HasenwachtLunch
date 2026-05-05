//
//  MainTabView.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//
//  Hauptcontainer für die Tab-basierte Navigation nach erfolgreichem Login.
//  Enthält die zwei Hauptbereiche der App: Mittagessen und Profil.
//

import SwiftUI

struct MainTabView: View {

    var body: some View {
        TabView {
            LunchOverviewView()
                .tabItem {
                    Label("Mittagessen", systemImage: "fork.knife")
                }

            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle")
                }
        }
    }
}

#Preview {
    MainTabView()
}
