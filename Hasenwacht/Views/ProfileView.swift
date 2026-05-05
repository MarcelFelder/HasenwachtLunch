//
//  ProfileView.swift
//  Hasenwacht
//
//  Profil-Screen: eigene Daten, Notification-Toggle, Logout.
//

import SwiftUI

struct ProfileView: View {
    @State private var firstName: String = "Max"
    @State private var lastName: String = "Hasenwacht"
    @State private var notificationsEnabled: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                // Avatar-Bereich oben
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Text(initials)
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 100, height: 100)
                                .background(Color(hex: "#D9C9A8"))
                                .clipShape(Circle())

                            Button("Foto ändern") {
                                // Später: Foto-Picker
                            }
                            .font(.subheadline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // Name-Felder
                Section("Name") {
                    TextField("Vorname", text: $firstName)
                    TextField("Nachname", text: $lastName)
                }

                // Einstellungen
                Section("Benachrichtigungen") {
                    Toggle("Reminder am Vorabend", isOn: $notificationsEnabled)
                }

                // Logout
                Section {
                    Button(role: .destructive) {
                        // Später: echte Logout-Logik
                    } label: {
                        HStack {
                            Spacer()
                            Text("Abmelden")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profil")
        }
    }

    private var initials: String {
        let first = firstName.first.map { String($0) } ?? ""
        let last = lastName.first.map { String($0) } ?? ""
        return first + last
    }
}

#Preview {
    ProfileView()
}
