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

    private var isPast: Bool {
        guard let day else { return false }
        return day.isPast || (day.isToday && {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
            return cal.component(.hour, from: Date()) >= 13
        }())
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            DS.Colors.surface.ignoresSafeArea()

            if let day {
                ScrollView {
                    VStack(spacing: 12) {
                        heroCard(day: day)

                        if day.isHoliday && !day.lunchDay.forceLunch {
                            holidayCard(day: day)
                        } else {
                            attendeesSection(day: day)
                            if !day.absentees.isEmpty {
                                absenteesSection(day: day)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DS.Colors.surface, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(date.weekdayNameLong)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(date.formattedLong())
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Hero Card (Status + Toggle)

    private func heroCard(day: DayViewModel) -> some View {
        let isLocked = day.lunchDay.isLocked || isPast
        let isAttending = day.currentUserAttending

        return HStack(spacing: 12) {
            // Datums-Block links — gleich wie in OverviewView
            VStack(spacing: 1) {
                Text(date.weekdayName.replacingOccurrences(of: ".", with: ""))
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(isPast ? DS.Colors.textTertiary : (isAttending ? Color.lunchEmeraldDark : DS.Colors.textSecondary))
                Text(String(Calendar.current.component(.day, from: date)))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isPast ? DS.Colors.textTertiary : DS.Colors.textPrimary)
            }
            .frame(width: 52, height: 52)
            .background(isPast ? DS.Colors.surfaceAlt : (isAttending ? Color.lunchEmerald.opacity(0.08) : DS.Colors.surface))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Status-Text
            VStack(alignment: .leading, spacing: 3) {
                Text(isAttending ? "Du bist dabei" : "Du bist abgemeldet")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isPast ? DS.Colors.textSecondary : DS.Colors.textPrimary)
                    .strikethrough(!isAttending && !isPast, color: DS.Colors.textTertiary)

                if let message = day.phaseMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(DS.Colors.textTertiary)
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                } else if isPast {
                    Text(isAttending ? "Teilgenommen" : "Nicht teilgenommen")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                } else {
                    Text("\(day.attendingCount) von \(day.totalCount) angemeldet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }

            Spacer(minLength: 0)

            // Toggle-Pill
            if isLocked {
                // Greyed-out Status
                HStack(spacing: 4) {
                    Image(systemName: isAttending ? "checkmark" : "xmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text(isAttending ? "Dabei" : "Abgemeldet")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(DS.Colors.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(DS.Colors.border, lineWidth: 1)
                )
            } else {
                Button {
                    Task { await viewModel.toggleAttendance(for: day.date) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isAttending ? "xmark" : "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text(isAttending ? "Abmelden" : "Anmelden")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(isAttending ? DS.Colors.textSecondary : Color.white)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(isAttending ? DS.Colors.surface : Color.lunchEmerald)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isAttending ? DS.Colors.border : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(16)
        .background(DS.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isAttending && !isPast
                        ? Color.lunchEmerald.opacity(0.35)
                        : DS.Colors.border,
                    lineWidth: isAttending && !isPast ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }

    // MARK: - Feiertags-Hinweis

    private func holidayCard(day: DayViewModel) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 16))
                    .foregroundStyle(DS.Colors.warning)
                Text(day.holidayName ?? "Feiertag")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
            }

            Text("An diesem Tag findet kein Mittagessen statt.")
                .font(.system(size: 13))
                .foregroundStyle(DS.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await viewModel.activateLunchForHoliday(date: day.date) }
            } label: {
                Text("Mittagessen trotzdem aktivieren")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(DS.Colors.primarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(DS.Colors.primaryLight, lineWidth: 1)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(16)
        .background(DS.Colors.warningSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(DS.Colors.warning.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Teilnehmerlisten

    private func attendeesSection(day: DayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Dabei")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .tracking(0.3)
                Spacer()
                Text("\(day.attendees.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .background(DS.Colors.border)

            if day.attendees.isEmpty {
                Text("Niemand angemeldet.")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(16)
            } else {
                ForEach(Array(day.attendees.enumerated()), id: \.element.id) { index, user in
                    DetailUserRow(user: user, dimmed: false)
                    if index < day.attendees.count - 1 {
                        Divider()
                            .background(DS.Colors.border)
                            .padding(.leading, 64)
                    }
                }
            }
        }
        .background(DS.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    private func absenteesSection(day: DayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Abgemeldet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .tracking(0.3)
                Spacer()
                Text("\(day.absentees.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .background(DS.Colors.border)

            ForEach(Array(day.absentees.enumerated()), id: \.element.id) { index, user in
                DetailUserRow(user: user, dimmed: true)
                if index < day.absentees.count - 1 {
                    Divider()
                        .background(DS.Colors.border)
                        .padding(.leading, 64)
                }
            }
        }
        .background(DS.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }
}

// MARK: - User-Zeile

private struct DetailUserRow: View {
    let user: User
    let dimmed: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Avatar-Kreis
            ZStack {
                Circle()
                    .fill(dimmed ? DS.Colors.surfaceAlt : user.avatarColor)
                Text(user.initials)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(dimmed ? DS.Colors.textTertiary : .white)
            }
            .frame(width: 36, height: 36)

            Text(user.fullName)
                .font(.system(size: 15))
                .foregroundStyle(dimmed ? DS.Colors.textTertiary : DS.Colors.textPrimary)
                .strikethrough(dimmed, color: DS.Colors.textTertiary)

            Spacer()

            if dimmed {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Farb-Konstanten

private extension Color {
    static let lunchEmerald     = Color(red: 0.13, green: 0.70, blue: 0.44)
    static let lunchEmeraldDark = Color(red: 0.09, green: 0.55, blue: 0.34)
}
