//
//  LunchDetailView.swift
//  Hasenwacht
//
//  Detail-Ansicht eines Tages mit Teilnehmerliste.
//

import SwiftUI

struct LunchDetailView: View {
    @Binding var day: DayViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statusCard

                if day.isHoliday && !day.lunchDay.forceLunch {
                    holidayCard
                } else {
                    attendeesSection
                    absenteesSection
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text(day.date.weekdayName())
                        .font(.headline)
                    Text(day.date.formattedLong())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Status-Karte

    private var statusCard: some View {
        VStack(spacing: 16) {
            Text(day.currentUserAttending ? "Du bist dabei" : "Du bist nicht dabei")
                .font(.title2)
                .fontWeight(.semibold)

            Button(action: toggleAttendance) {
                HStack {
                    Image(systemName: day.currentUserAttending
                          ? "xmark.circle.fill"
                          : "checkmark.circle.fill")
                    Text(day.currentUserAttending ? "Austragen" : "Eintragen")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.white)
                .background(day.currentUserAttending ? .red : .green)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(day.isHoliday && !day.lunchDay.forceLunch)
            .opacity((day.isHoliday && !day.lunchDay.forceLunch) ? 0.5 : 1.0)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Feiertags-Hinweis

    private var holidayCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(day.holidayName ?? "Feiertag")
                .font(.headline)
            Text("An diesem Tag findet kein Mittagessen statt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Mittagessen trotzdem aktivieren") {
                // Logik kommt mit dem Service-Layer
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Teilnehmerlisten

    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dabei")
                    .font(.headline)
                Spacer()
                Text("\(day.attendees.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(day.attendees) { user in
                UserRowView(user: user)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var absenteesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nicht dabei")
                    .font(.headline)
                Spacer()
                Text("\(day.absentees.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(day.absentees) { user in
                UserRowView(user: user)
                    .opacity(0.6)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Toggle-Logik

    private func toggleAttendance() {
        let userId = MockData.currentUser.id ?? ""
        let current = MockData.currentUser
        if day.currentUserAttending {
            day.attendees.removeAll { $0.id == userId }
            day.absentees.append(current)
        } else {
            day.absentees.removeAll { $0.id == userId }
            day.attendees.append(current)
        }
    }
}

// MARK: - User-Zeile

struct UserRowView: View {
    let user: User

    var body: some View {
        HStack(spacing: 12) {
            Text(user.initials)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(user.avatarColor)
                .clipShape(Circle())

            Text(user.fullName)
                .font(.body)

            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        LunchDetailView(day: .constant(MockData.mockDays()[0]))
    }
}
