//
//  LunchOverviewView.swift
//  Hasenwacht
//
//  Hauptscreen: Liste der nächsten 7 Werktage mit Status pro Tag.
//  Daten kommen reaktiv aus Firestore via LunchDaysViewModel.
//

import SwiftUI

struct LunchOverviewView: View {

    // MARK: - Environment

    @Environment(CurrentUserService.self) private var currentUserService

    // MARK: - State

    @StateObject private var viewModel = LunchDaysViewModel.shared
    
    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.days.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else {
                    daysList
                }
            }
            .navigationTitle("Mittagessen")
        }
    }

    // MARK: - Days-Liste

    private var daysList: some View {
        List {
            ForEach(viewModel.days) { day in
                NavigationLink(value: day) {
                    DayRowView(day: day) {
                        Task { await viewModel.toggleAttendance(for: day.date) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: DayViewModel.self) { day in
            LunchDetailView(date: day.date)
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
                    .foregroundStyle((day.isHoliday && !day.lunchDay.forceLunch) ? .secondary : .primary)

                HStack(spacing: 6) {
                    Text(day.date.formattedShort())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Feiertags-Badge nur bei aktiviertem Feiertag anzeigen
                    if day.isHoliday && day.lunchDay.forceLunch, let name = day.holidayName {
                        Text(name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                // Inline-Hinweis bei überschrittener Deadline
                if day.lunchDay.isLocked {
                    Text(LunchDay.lockedMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }

            Spacer()

            if day.isHoliday && !day.lunchDay.forceLunch {
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
            .disabled(day.lunchDay.isLocked)
            .opacity(day.lunchDay.isLocked ? 0.4 : 1.0)
        }
    }
}
