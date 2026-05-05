//
//  LunchOverviewView.swift
//  Hasenwacht
//
//  Hauptscreen: Liste der nächsten 7 Werktage mit Status pro Tag.
//

import SwiftUI

struct LunchOverviewView: View {
    @State private var days: [DayViewModel] = MockData.mockDays()

    var body: some View {
        NavigationStack {
            List {
                ForEach($days) { $day in
                    NavigationLink(value: day) {
                        DayRowView(day: day) {
                            toggleAttendance(for: $day)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Mittagessen")
            .navigationDestination(for: DayViewModel.self) { day in
                if let index = days.firstIndex(where: { $0.id == day.id }) {
                    LunchDetailView(day: $days[index])
                }
            }
        }
    }

    /// Toggle-Logik für Mock-Daten.
    /// Später ersetzt durch echten Service-Aufruf.
    private func toggleAttendance(for day: Binding<DayViewModel>) {
        let userId = MockData.currentUser.id ?? ""
        let current = MockData.currentUser
        if day.wrappedValue.currentUserAttending {
            day.wrappedValue.attendees.removeAll { $0.id == userId }
            day.wrappedValue.absentees.append(current)
        } else {
            day.wrappedValue.absentees.removeAll { $0.id == userId }
            day.wrappedValue.attendees.append(current)
        }
    }
}

// MARK: - Einzelne Zeile in der Tagesliste

struct DayRowView: View {
    let day: DayViewModel
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.date.weekdayName())
                    .font(.headline)
                    .foregroundStyle(day.isHoliday ? .secondary : .primary)
                Text(day.date.formattedShort())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
            Text("\(day.attendingCount) von \(day.totalCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
