//
//  AbsenceView.swift
//  Hasenwacht
//
//  Abwesenheits-Tab: Wiederkehrende Abwesenheiten & Ferienabwesenheiten.
//

import SwiftUI

struct AbsenceView: View {

    @Environment(CurrentUserService.self) private var currentUserService
    @StateObject private var viewModel = AbsenceViewModel.shared
    @StateObject private var teamViewModel = TeamAbsenceViewModel.shared
    @StateObject private var lunchViewModel = LunchDaysViewModel.shared
    @State private var showAddVacation = false
    @State private var showTeamOverview = false

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        pageHeader
                        recurringCard
                        vacationCard
                        teamOverviewCard
                        infoFooter
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if let userId = currentUserService.currentUser?.id {
                    viewModel.start(userId: userId)
                    let users = lunchViewModel.days.first?.allUsers ?? []
                    teamViewModel.start(users: users)
                }
            }
            .sheet(isPresented: $showAddVacation) {
                AddVacationSheet { start, end, name in
                    Task { await viewModel.addVacation(startDate: start, endDate: end, name: name) }
                }
            }
        }
    }

    // MARK: - Team-Übersicht (expandable)

    private var teamOverviewCard: some View {
        VStack(spacing: 0) {
            // Toggle-Header — immer sichtbar
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showTeamOverview.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.absenceBlue)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Team-Übersicht")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.Colors.textSecondary)
                        Text("Wer ist wann abwesend")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    Spacer()
                    Image(systemName: showTeamOverview ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(DS.Colors.background)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Expandable Inhalt
            if showTeamOverview {
                Divider().background(DS.Colors.border)

                // Wochen-Navigation
                HStack(spacing: 4) {
                    Button { teamViewModel.weekOffset -= 1 } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(DS.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Spacer()
                    VStack(spacing: 1) {
                        Text(teamViewModel.weekLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text(teamViewModel.weekDateRange)
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    Spacer()
                    Button { teamViewModel.weekOffset += 1 } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(DS.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(DS.Colors.background)

                Divider().background(DS.Colors.border)

                // Spalten-Header Mo–Fr
                HStack(spacing: 0) {
                    Spacer().frame(width: 88)
                    ForEach(teamViewModel.currentWeekDates, id: \.self) { date in
                        let isToday = Calendar.current.isDateInToday(date)
                        let cal = Calendar.current
                        VStack(spacing: 1) {
                            Text(date.weekdayName.replacingOccurrences(of: ".", with: ""))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isToday ? DS.Colors.primary : DS.Colors.textTertiary)
                            Text(String(cal.component(.day, from: date)))
                                .font(.system(size: 11, weight: isToday ? .bold : .regular))
                                .foregroundStyle(isToday ? DS.Colors.primary : DS.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Spacer().frame(width: 16)
                }
                .padding(.vertical, 6)
                .background(DS.Colors.background)

                Divider().background(DS.Colors.border)

                // User-Zeilen
                ForEach(teamViewModel.teamAbsences) { info in
                    GanttUserRow(info: info, dates: teamViewModel.currentWeekDates)
                    if info.id != teamViewModel.teamAbsences.last?.id {
                        Divider().background(DS.Colors.border).padding(.leading, 16)
                    }
                }

                Divider().background(DS.Colors.border)

                // Legende
                HStack(spacing: 14) {
                    legendDot(color: DS.Colors.primary, label: "Ferien")
                    legendDot(color: Color.absenceBlue, label: "Wiederkehrend")
                    legendDot(color: DS.Colors.surface, label: "Dabei", bordered: true)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(DS.Colors.background)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    private func legendDot(color: Color, label: String, bordered: Bool = false) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay(bordered ? RoundedRectangle(cornerRadius: 3).stroke(DS.Colors.border, lineWidth: 1) : nil)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DS.Colors.textTertiary)
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PLANUNG")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Colors.primary)
                    .tracking(2.5)
                Text("Abwesenheiten")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Wiederkehrende Abwesenheiten

    private var recurringCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "repeat")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.absenceBlue)
                    Text("Wiederkehrend")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                }
                Text("Dauerhaft abwesend an bestimmten Wochentagen")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.leading, 19)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DS.Colors.background)
            .overlay(Divider().background(DS.Colors.border), alignment: .bottom)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { weekday in
                        WeekdayToggle(
                            label: weekdayShort(weekday),
                            isActive: viewModel.recurring.absentWeekdays.contains(weekday)
                        ) {
                            Task { await viewModel.toggleWeekday(weekday) }
                        }
                    }
                }

                if viewModel.recurring.absentWeekdays.isEmpty {
                    Text("Kein Wochentag ausgewählt — du bist überall dabei.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                } else {
                    let names = viewModel.recurring.absentWeekdays.sorted().map { weekdayFull($0) }.joined(separator: ", ")
                    HStack(spacing: 5) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.absenceBlue.opacity(0.7))
                        Text("Automatisch abgemeldet: \(names)")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(DS.Colors.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Ferienabwesenheiten

    private var vacationCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sun.horizon")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.absenceAmber)
                    Text("Ferien")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()
                Button { showAddVacation = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                        Text("Hinzufügen").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.absenceAmber)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Color.absenceAmber.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.absenceAmber.opacity(0.25), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DS.Colors.background)
            .overlay(Divider().background(DS.Colors.border), alignment: .bottom)

            if viewModel.vacations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "airplane.circle")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color.absenceAmber.opacity(0.4))
                    Text("Keine Ferienabwesenheiten geplant")
                        .font(.system(size: 13))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(DS.Colors.background)
            } else {
                ForEach(Array(viewModel.vacations.enumerated()), id: \.element.id) { index, vacation in
                    VacationRow(vacation: vacation) {
                        Task { await viewModel.deleteVacation(vacation) }
                    }
                    if index < viewModel.vacations.count - 1 {
                        Divider().background(DS.Colors.border).padding(.leading, 16)
                    }
                }
                .background(DS.Colors.background)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Footer

    private var infoFooter: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(DS.Colors.textTertiary)
                .padding(.top, 1)
            Text("Aktive Abwesenheiten melden dich automatisch ab. Du kannst dich für einzelne Tage trotzdem manuell wieder anmelden.")
                .font(.system(size: 11))
                .foregroundStyle(DS.Colors.textTertiary)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Helpers

    private func weekdayShort(_ iso: Int) -> String {
        ["Mo", "Di", "Mi", "Do", "Fr"][iso - 1]
    }
    private func weekdayFull(_ iso: Int) -> String {
        ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag"][iso - 1]
    }
}

// MARK: - Wochentag Toggle

private struct WeekdayToggle: View {
    let label: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? .white : DS.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isActive ? Color.absenceBlue : DS.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.absenceBlue : DS.Colors.border, lineWidth: 1)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Vacation Row

private struct VacationRow: View {
    let vacation: VacationAbsence
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.absenceAmber.opacity(0.10))
                Image(systemName: "airplane")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.absenceAmber)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(vacation.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(vacation.dateRangeLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            Spacer()

            if vacation.covers(date: Date()) {
                Text("Aktiv")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.absenceAmber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.absenceAmber.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Colors.danger.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(DS.Colors.dangerSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DS.Colors.background)
    }
}

// MARK: - Add Vacation Sheet

struct AddVacationSheet: View {
    let onSave: (Date, Date, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date()
    @State private var name = ""

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.surface.ignoresSafeArea()
                VStack(spacing: 12) {
                    // Name Card
                    VStack(spacing: 0) {
                        HStack {
                            Text("Name (optional)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DS.Colors.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(DS.Colors.background)
                        .overlay(Divider().background(DS.Colors.border), alignment: .bottom)

                        TextField("z. B. Sommerferien", text: $name)
                            .font(.system(size: 15))
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(DS.Colors.background)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))

                    // Datum Card
                    VStack(spacing: 0) {
                        HStack {
                            Text("Zeitraum")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DS.Colors.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(DS.Colors.background)
                        .overlay(Divider().background(DS.Colors.border), alignment: .bottom)

                        HStack {
                            Text("Von").font(.system(size: 15)).foregroundStyle(DS.Colors.textPrimary)
                            Spacer()
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                                .onChange(of: startDate) { _, new in
                                    if endDate < new { endDate = new }
                                }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(DS.Colors.background)

                        Divider().background(DS.Colors.border).padding(.leading, 16)

                        HStack {
                            Text("Bis").font(.system(size: 15)).foregroundStyle(DS.Colors.textPrimary)
                            Spacer()
                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(DS.Colors.background)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))

                    Button {
                        onSave(startDate, endDate, name.isEmpty ? nil : name)
                        dismiss()
                    } label: {
                        Text("Speichern")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.absenceAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.top, 4)

                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 16)
            }
            .navigationTitle("Ferien hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.Colors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Gantt User Row

private struct GanttUserRow: View {
    let info: UserAbsenceInfo
    let dates: [Date]

    var body: some View {
        HStack(spacing: 0) {
            // Avatar + Name
            HStack(spacing: 6) {
                UserAvatarView(user: info.user, size: 22)
                Text(info.user.firstName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)
            }
            .frame(width: 80, alignment: .leading)
            .padding(.leading, 16)

            // Tages-Zellen
            HStack(spacing: 3) {
                ForEach(dates, id: \.self) { date in
                    let reason = info.absenceReason(on: date)
                    let isToday = Calendar.current.isDateInToday(date)

                    RoundedRectangle(cornerRadius: 5)
                        .fill(cellColor(for: reason))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .overlay(
                            isToday && reason == nil ?
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(DS.Colors.primary.opacity(0.4), lineWidth: 1.5)
                                : nil
                        )
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 10)
        .background(DS.Colors.background)
    }

    private func cellColor(for reason: AbsenceReason?) -> Color {
        guard let reason else { return DS.Colors.surface }
        switch reason {
        case .vacation:  return DS.Colors.primary.opacity(0.75)
        case .recurring: return Color.absenceBlue.opacity(0.75)
        }
    }
}

// MARK: - Styles & Farben

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}
