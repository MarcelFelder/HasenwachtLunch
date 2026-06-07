//
//  LunchDetailView.swift
//  Hasenwacht
//
//  Detail-Ansicht eines Tages mit Teilnehmerliste.
//  Reaktiv: Daten kommen direkt aus dem LunchDaysViewModel.
//

import SwiftUI

struct LunchDetailView: View {

    let date: Date

    @Environment(CurrentUserService.self) private var currentUserService
    @ObservedObject private var viewModel = LunchDaysViewModel.shared
    @ObservedObject private var teamAbsenceViewModel = TeamAbsenceViewModel.shared
    @ObservedObject private var cookingViewModel = CookingViewModel.shared

    private var day: DayViewModel? {
        viewModel.days.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private var isPast: Bool {
        guard let day else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        return day.isPast || (day.isToday && cal.component(.hour, from: Date()) >= 13)
    }

    var body: some View {
        ZStack {
            DS.Colors.surface.ignoresSafeArea()

            if let day {
                ScrollView {
                    VStack(spacing: 12) {
                        statusHero(day: day)
                        if day.isHoliday {
                            holidayBanner(day: day)
                        }
                        cookingCard
                        attendeesCard(day: day)
                        absenteesCard(day: day)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        SkeletonDetailHero()
                        SkeletonUserList(title: "Dabei", count: 3)
                        SkeletonUserList(title: "Abgemeldet", count: 2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
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
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Status Hero

    private func statusHero(day: DayViewModel) -> some View {
        let isAttending = day.currentUserAttending
        let isLocked = day.lunchDay.isLocked || isPast

        return VStack(spacing: 0) {
            // Illustration-Banner
            ZStack {
                // Hintergrund-Gradient
                LinearGradient(
                    colors: isAttending
                        ? [Color.lunchEmerald.opacity(0.85), Color.lunchEmeraldDark]
                        : [Color(white: 0.22), Color(white: 0.30)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Dekorative Kreise
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 140, height: 140)
                    .offset(x: 80, y: -30)
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 90, height: 90)
                    .offset(x: -70, y: 40)

                HStack(spacing: 16) {
                    // SF Symbol als Illustration
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: isAttending ? "fork.knife" : "fork.knife.circle")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(Color.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isAttending ? "Du bist dabei" : "Du bist abgemeldet")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.white)
                        Text(isAttending
                             ? "\(day.attendingCount) von \(day.totalCount) essen mit"
                             : "\(day.attendingCount) von \(day.totalCount) angemeldet")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.75))
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .frame(height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Toggle-Zeile direkt darunter, innerhalb derselben Karte
            HStack {
                if let message = day.phaseMessage {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Colors.textTertiary)
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                } else if isPast {
                    Text(isAttending ? "✓ Teilgenommen" : "Nicht teilgenommen")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                } else {
                    Text("Tippe um deinen Status zu ändern")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Spacer()

                if isLocked {
                    HStack(spacing: 4) {
                        Image(systemName: isAttending ? "checkmark" : "xmark")
                            .font(.system(size: 11, weight: .semibold))
                        Text(isAttending ? "Dabei" : "Abgemeldet")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(DS.Colors.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(DS.Colors.border, lineWidth: 1))
                } else {
                    Button {
                        Task { await viewModel.toggleAttendance(for: day.date) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isAttending ? "xmark" : "checkmark")
                                .font(.system(size: 11, weight: .bold))
                            Text(isAttending ? "Abmelden" : "Anmelden")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(isAttending ? DS.Colors.textSecondary : .white)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(isAttending ? DS.Colors.surface : Color.lunchEmerald)
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17)
                                .stroke(isAttending ? DS.Colors.border : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DS.Colors.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }

    // MARK: - Feiertags-Banner

    private func holidayBanner(day: DayViewModel) -> some View {
        let isActivator = day.lunchDay.activatedBy == viewModel.days.first?.currentUserId
            || day.lunchDay.activatedBy == currentUserService.currentUser?.id

        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.warning)
                Text(day.holidayName ?? "Feiertag")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                Spacer()
                if day.lunchDay.forceLunch {
                    Text("Aktiviert")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.lunchEmerald)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(DS.Colors.successSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(DS.Colors.background)
            .overlay(Divider().background(DS.Colors.border), alignment: .bottom)

            // Info + Aktions-Button
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.lunchDay.forceLunch
                         ? "Mittagessen findet statt"
                         : "Kein Mittagessen geplant")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(day.lunchDay.forceLunch
                         ? (isActivator ? "Tippe um es wieder zu deaktivieren" : "Wurde manuell aktiviert")
                         : "Tippe um es trotzdem zu aktivieren")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()

                if day.lunchDay.forceLunch {
                    // Deaktivieren — nur für den der aktiviert hat
                    if isActivator {
                        Button {
                            Task { await viewModel.deactivateLunchForHoliday(date: day.date) }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Deaktivieren")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(DS.Colors.danger)
                            .padding(.horizontal, 12).frame(height: 34)
                            .background(DS.Colors.dangerSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 17))
                            .overlay(
                                RoundedRectangle(cornerRadius: 17)
                                    .stroke(DS.Colors.danger.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                } else {
                    // Aktivieren
                    Button {
                        Task { await viewModel.activateLunchForHoliday(date: day.date) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 11, weight: .bold))
                            Text("Aktivieren")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(DS.Colors.textSecondary)
                        .padding(.horizontal, 12).frame(height: 34)
                        .background(DS.Colors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17)
                                .stroke(DS.Colors.border, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(DS.Colors.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(day.lunchDay.forceLunch
                        ? Color.lunchEmerald.opacity(0.3)
                        : DS.Colors.warning.opacity(0.3), lineWidth: 1)
        )
        .background(day.lunchDay.forceLunch ? DS.Colors.successSurface : DS.Colors.warningSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Cooking Card

    private var cookingCard: some View {
        let slot = cookingViewModel.slot(for: date)
        let cook = slot.flatMap { s in
            viewModel.days.first { Calendar.current.isDate($0.date, inSameDayAs: date) }?
                .allUsers.first { $0.id == s.userId }
        }

        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.cookingPurple)
                Text("Wer kocht")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                Spacer()
                Text("β")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.cookingPurple.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DS.Colors.background)
            .overlay(Divider().background(DS.Colors.border), alignment: .bottom)

            // Inhalt
            HStack(spacing: 12) {
                if let cook {
                    UserAvatarView(user: cook, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cook.fullName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DS.Colors.textPrimary)
                        if let slot, slot.hasMenu {
                            Text(slot.displayMenuTitle)
                                .font(.system(size: 12))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .lineLimit(2)
                        } else {
                            Text("Noch kein Menu hinterlegt")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .frame(width: 36, height: 36)
                    Text("Noch niemand eingetragen")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(DS.Colors.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(slot != nil ? Color.cookingPurple.opacity(0.25) : DS.Colors.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Dabei Section (immer sichtbar)

    private func attendeesCard(day: DayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "Dabei", count: day.attendees.count, color: Color.lunchEmerald)

            if day.attendees.isEmpty {
                emptyRow(text: "Niemand angemeldet")
            } else {
                ForEach(Array(day.attendees.enumerated()), id: \.element.id) { index, user in
                    DetailUserRow(user: user, dimmed: false)
                    if index < day.attendees.count - 1 {
                        Divider().padding(.leading, 64).background(DS.Colors.border)
                    }
                }
            }
        }
        .background(DS.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Abgemeldet Section (immer sichtbar)

    private func absenteesCard(day: DayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "Abgemeldet", count: day.absentees.count, color: DS.Colors.textTertiary)

            if day.absentees.isEmpty {
                emptyRow(text: "Alle dabei")
            } else {
                ForEach(Array(day.absentees.enumerated()), id: \.element.id) { index, user in
                    let reason = teamAbsenceViewModel.teamAbsences
                        .first { $0.user.id == user.id }?
                        .absenceReason(on: date)
                    DetailUserRow(user: user, dimmed: true, absenceReason: reason)
                    if index < day.absentees.count - 1 {
                        Divider().padding(.leading, 64).background(DS.Colors.border)
                    }
                }
            }
        }
        .background(DS.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, count: Int, color: Color) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.textSecondary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DS.Colors.textTertiary)
                .frame(minWidth: 20)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(DS.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(Divider().background(DS.Colors.border), alignment: .bottom)
    }

    private func emptyRow(text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(DS.Colors.textTertiary)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
    }
}

// MARK: - User Row

private struct DetailUserRow: View {
    let user: User
    let dimmed: Bool
    var absenceReason: AbsenceReason? = nil

    var body: some View {
        HStack(spacing: 12) {
            UserAvatarView(user: user, size: 36)
                .opacity(dimmed ? 0.4 : 1.0)

            Text(user.fullName)
                .font(.system(size: 15))
                .foregroundStyle(dimmed ? DS.Colors.textTertiary : DS.Colors.textPrimary)

            Spacer()

            // Abwesenheits-Badge
            if let reason = absenceReason {
                HStack(spacing: 4) {
                    Image(systemName: reason.isVacation ? "airplane" : "repeat")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(reason.isVacation ? DS.Colors.primaryDark : Color.absenceBlue)
                    Text(reason.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(reason.isVacation ? DS.Colors.primaryDark : Color.absenceBlue)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(reason.isVacation ? DS.Colors.primarySurface : Color.absenceBlue.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if dimmed {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lunchEmerald)
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
