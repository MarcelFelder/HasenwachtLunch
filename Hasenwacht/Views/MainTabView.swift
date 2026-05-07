//
//  MainTabView.swift
//  Hasenwacht
//
//  Tabs: Mittagessen, Kochen (nur wenn canCook), Abwesenheiten, Profil.
//

import SwiftUI

struct MainTabView: View {

    @Environment(CurrentUserService.self) private var currentUserService

    private var canCook: Bool { currentUserService.currentUser?.canCook ?? false }

    var body: some View {
        TabView {
            LunchOverviewView()
                .tabItem {
                    Label("Mittagessen", systemImage: "fork.knife")
                }

            if canCook {
                CookingView()
                    .tabItem {
                        Label("Kochen", systemImage: "frying.pan")
                    }
                    .badge("β")
            }

            AbsenceView()
                .tabItem {
                    Label("Abwesenheiten", systemImage: "calendar.badge.minus")
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
