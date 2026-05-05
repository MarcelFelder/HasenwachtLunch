//
//  LunchDetailView.swift
//  Hasenwacht
//
//  Detail-Ansicht eines Tages mit Teilnehmerliste.
//  Reaktiv: Daten kommen direkt aus dem LunchDaysViewModel.
//

import SwiftUI

struct LunchDetailView: View {

    // MARK: - Input

    let date: Date

    // MARK: - ViewModel

    @ObservedObject private var viewModel = LunchDaysViewModel.shared

    // MARK: - Computed

    private var day: DayViewModel? {
        viewModel.days.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            if let day {
                VStack(spacing: 24) {
                    statusCard(day: day)

                    if day.isHoliday && !day.lunchDay.forceLunch {
                        holidayCard(day: day)
                    } else {
                        attendeesSection(day: day)
                        absenteesSection(day: day)
                    }
                }
                .padding()
            } else {
                ProgressView()
                    .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text(date.weekdayName())
                        .font(.headline)
                    Text(date.formattedLong())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Status-Karte

    private func statusCard(day: DayViewModel) -> some View {
        VStack(spacing: 16) {
            Text(day.currentUserAttending ? "Du bist dabei" : "Du bist nicht dabei")
                .font(.title2)
                .fontWeight(.semibold)

            Button {
                Task { await viewModel.toggleAttendance(for: day.date) }
            } label: {
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

    private func holidayCard(day: DayViewModel) -> some View {
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
                // Logik kommt mit Phase 4
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            .disabled(true)
            .opacity(0.5)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Teilnehmerlisten

    private func attendeesSection(day: DayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dabei")
                    .font(.headline)
                Spacer()
                Text("\(day.attendees.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if day.attendees.isEmpty {
                Text("Niemand dabei.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(day.attendees) { user in
                    UserRowView(user: user)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func absenteesSection(day: DayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nicht dabei")
                    .font(.headline)
                Spacer()
                Text("\(day.absentees.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if day.absentees.isEmpty {
                Text("Alle dabei.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(day.absentees) { user in
                    UserRowView(user: user)
                        .opacity(0.6)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
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
