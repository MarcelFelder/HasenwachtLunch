//
//  LunchOverviewView.swift
//  Hasenwacht
//
//  Hauptscreen: Liste der nächsten 7 Werktage mit Status pro Tag.
//

import SwiftUI

struct LunchOverviewView: View {
    @State private var days: [LunchDay] = MockData.nextWorkdays()

    var body: some View {
        NavigationStack {
            List {
                ForEach($days) { $day in
                    NavigationLink(value: day) {
                        DayRowView(day: day) {
                            // Quick-Toggle direkt aus der Liste heraus
                            day.currentUserAttending.toggle()
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Mittagessen")
            .navigationDestination(for: LunchDay.self) { day in
                if let index = days.firstIndex(where: { $0.id == day.id }) {
                    LunchDetailView(day: $days[index])
                }
            }
        }
    }
}

// MARK: - Einzelne Zeile in der Tagesliste

struct DayRowView: View {
    let day: LunchDay
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Datum-Block links
            VStack(alignment: .leading, spacing: 2) {
                Text(day.date.weekdayName())
                    .font(.headline)
                    .foregroundStyle(day.isHoliday ? .secondary : .primary)
                Text(day.date.formattedShort())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status-Anzeige rechts
            if day.isHoliday {
                holidayBadge
            } else {
                attendanceInfo
            }
        }
        .padding(.vertical, 8)
    }

    private var holidayBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(day.holidayName ?? "Feiertag")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("kein Mittagessen")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var attendanceInfo: some View {
        HStack(spacing: 12) {
            // Anzahl-Anzeige
            Text("\(day.attendingCount) von \(day.totalPeople)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Eigener Status als Toggle-Button
            Button(action: onToggle) {
                Image(systemName: day.currentUserAttending
                      ? "checkmark.circle.fill"
                      : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(day.currentUserAttending ? .green : .red)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    LunchOverviewView()
}
