//
//  LunchOverviewView.swift
//  Hasenwacht
//
//  Lunch-Übersicht: Wochennavigation, Hero-Card für heute,
//  gedimmte Vergangenheit, Anmelde-Pills für kommende Tage.
//

import SwiftUI

// MARK: - Hauptscreen

struct LunchOverviewView: View {

    @Environment(CurrentUserService.self) private var currentUserService
    @StateObject private var viewModel = LunchDaysViewModel.shared
    @State private var weekOffset: Int = {
        let current = LunchDaysViewModel.currentWeekOffset()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let weekday = cal.component(.weekday, from: Date()) // 1=So, 7=Sa
        let isWeekend = weekday == 1 || weekday == 7
        return isWeekend ? current + 1 : current
    }()

    private var weekDays: [DayViewModel] {
        viewModel.days(forWeekOffset: weekOffset)
    }

    private var minWeekOffset: Int { 0 }
    private var maxWeekOffset: Int { LunchDaysViewModel.currentWeekOffset() + 5 }

    /// True wenn heute nach 14:00 Uhr und die aktuelle Woche angezeigt wird —
    /// dann ist Morgen bereits gesperrt und der Banner wird eingeblendet.
    private var showCutoffBanner: Bool {
        guard weekOffset == LunchDaysViewModel.currentWeekOffset() else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)
        let isWeekday = weekday >= 2 && weekday <= 5
        return isWeekday && hour >= LunchDay.cutoffHour
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.surface.ignoresSafeArea()

                if viewModel.isLoading && viewModel.days.isEmpty {
                    VStack(spacing: 0) {
                        headerSection
                        SkeletonOverviewList()
                    }
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else {
                    mainContent
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Layout

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerSection
            ScrollView {
                dayListSection
            }
            .background(DS.Colors.surface)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LUNCH")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.Colors.primary)
                        .tracking(2.5)
                    Text("Anmeldung")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                Spacer()
                // Badge entfernt — unnötige Information
            }

            weekSwitcher
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(DS.Colors.surface)
    }

    private var weekSwitcher: some View {
        HStack(spacing: 4) {
            Button {
                if weekOffset > minWeekOffset { weekOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(weekOffset == minWeekOffset ? DS.Colors.textTertiary : DS.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(weekOffset == minWeekOffset ? Color.clear : DS.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: weekOffset > minWeekOffset ? Color.black.opacity(0.06) : Color.clear,
                            radius: 2, y: 1)
            }
            .disabled(weekOffset == minWeekOffset)

            Spacer()

            VStack(spacing: 2) {
                Text(weekLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(weekDateRange)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            Spacer()

            Button {
                if weekOffset < maxWeekOffset { weekOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(weekOffset < maxWeekOffset ? DS.Colors.textSecondary : DS.Colors.textTertiary)
                    .frame(width: 44, height: 44)
                    .background(weekOffset < maxWeekOffset ? DS.Colors.background : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: weekOffset < maxWeekOffset ? Color.black.opacity(0.06) : Color.clear,
                            radius: 2, y: 1)
            }
            .disabled(weekOffset >= maxWeekOffset)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(DS.Colors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Tagesliste

    private var dayListSection: some View {
        VStack(spacing: 8) {
            ForEach(Array(weekDays.enumerated()), id: \.element.id) { index, day in
                // showCutoffBanner nur beim ersten gesperrten Folgetag
                let isCutoffDay = showCutoffBanner
                    && !day.isToday && !day.isPast && day.lunchDay.isLocked
                    && weekDays.prefix(index).allSatisfy { $0.isToday || $0.isPast || !$0.lunchDay.isLocked }

                NavigationLink(destination: LunchDetailView(date: day.date)) {
                    DayCard(day: day, showCutoffBanner: isCutoffDay) {
                        guard !day.lunchDay.isLocked, day.lunchDay.hasLunch else { return }
                        Task { await viewModel.toggleAttendance(for: day.date) }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            Text("Standardmässig bist du angemeldet. Abmeldung bis 14:00 Uhr am Vortag.")
                .font(.system(size: 11))
                .foregroundStyle(DS.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 16)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 40)
    }

    // MARK: - Helpers

    private var weekLabel: String {
        let current = LunchDaysViewModel.currentWeekOffset()
        let diff = weekOffset - current
        switch diff {
        case 0:  return "Diese Woche"
        case 1:  return "Nächste Woche"
        case 2...: return "In \(diff) Wochen"
        case -1: return "Letzte Woche"
        default: return "Vor \(abs(diff)) Wochen"
        }
    }

    private var weekDateRange: String {
        let dates = LunchDaysViewModel.weekDates(offset: weekOffset)
        guard let first = dates.first, let last = dates.last else { return "" }
        let cal = Calendar.current
        let d1 = cal.component(.day, from: first)
        let d2 = cal.component(.day, from: last)
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_CH")
        df.dateFormat = "MMMM"
        return "\(d1). – \(d2). \(df.string(from: last))"
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

// MARK: - Day Card Dispatcher

private struct DayCard: View {
    let day: DayViewModel
    var showCutoffBanner: Bool = false
    let onToggle: () -> Void

    private var isTodayOver: Bool {
        guard day.isToday else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        return calendar.component(.hour, from: Date()) >= 13
    }

    var body: some View {
        Group {
            if day.hasNoData {
                NoDataCard(day: day)
            } else if day.isPast || isTodayOver {
                PastCard(day: day)
            } else if day.isToday {
                TodayCard(day: day, onToggle: onToggle)
            } else if day.isHoliday && !day.lunchDay.forceLunch {
                HolidayCard(day: day)
            } else {
                UpcomingCard(day: day, showCutoffBanner: showCutoffBanner, onToggle: onToggle)
            }
        }
    }
}

// MARK: - Feiertags-Karte

private struct HolidayCard: View {
    let day: DayViewModel

    var body: some View {
        HStack(spacing: 12) {
            DateBlock(day: day, variant: .past)

            VStack(alignment: .leading, spacing: 4) {
                Text(day.date.weekdayNameLong)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DS.Colors.textSecondary)
                HStack(spacing: 5) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.warning)
                    Text(day.holidayName ?? "Feiertag")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.Colors.warning)
                }
            }

            Spacer(minLength: 0)

            Text("Kein Lunch")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.Colors.textTertiary)
                .tracking(0.3)
        }
        .padding(16)
        .background(DS.Colors.warningSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(DS.Colors.warning.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }
}

// MARK: - Keine Daten (vergangene Wochen ohne Firestore-Einträge)

private struct NoDataCard: View {
    let day: DayViewModel

    var body: some View {
        HStack(spacing: 12) {
            DateBlock(day: day, variant: .past)

            VStack(alignment: .leading, spacing: 2) {
                Text(day.date.weekdayNameLong)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                HStack(spacing: 4) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(UIColor.quaternaryLabel))
                    Text("Keine Daten")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(UIColor.quaternaryLabel))
                }
            }

            Spacer()

            Text("ARCHIV")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
                .tracking(0.5)
        }
        .padding(16)
        .background(DS.Colors.background.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .opacity(0.45)
    }
}

// MARK: - Heute (Hero)

private struct TodayCard: View {
    let day: DayViewModel
    let onToggle: () -> Void

    private var isLocked: Bool { day.lunchDay.isLocked }

    var body: some View {
        HStack(spacing: 12) {
            DateBlock(day: day, variant: .dark)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(day.date.weekdayNameLong)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text("Heute")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white)
                        .tracking(0.8)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                HStack(spacing: 6) {
                    AvatarStack(users: Array(day.attendees.prefix(3)), variant: .dark)
                    Text("\(day.attendingCount) angemeldet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }

            Spacer(minLength: 0)

            if isLocked {
                LockedStatusChip(isAttending: day.currentUserAttending)
            } else {
                Button(action: onToggle) {
                    ActionPill(isSignedUp: day.currentUserAttending, variant: .dark)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: isLocked
                    ? [Color(white: 0.20), Color(white: 0.26)]
                    : [Color(white: 0.11), Color(white: 0.19)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(
            color: isLocked ? Color.black.opacity(0.10) : Color.black.opacity(0.20),
            radius: isLocked ? 6 : 12,
            y: isLocked ? 3 : 4
        )
    }
}

// MARK: - Gesperrter Status-Chip (nicht tappbar, klar deaktiviert)

private struct LockedStatusChip: View {
    let isAttending: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isAttending ? "checkmark" : "xmark")
                .font(.system(size: 11, weight: .semibold))
            Text(isAttending ? "Dabei" : "Abgemeldet")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color.white.opacity(0.35))
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Vergangenheit

private struct PastCard: View {
    let day: DayViewModel

    var body: some View {
        HStack(spacing: 12) {
            DateBlock(day: day, variant: .past)

            VStack(alignment: .leading, spacing: 2) {
                Text(day.date.weekdayNameLong)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))

                HStack(spacing: 4) {
                    Image(systemName: day.currentUserAttending ? "checkmark" : "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(UIColor.quaternaryLabel))
                    Text(day.currentUserAttending ? "Teilgenommen" : "Abgemeldet")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(UIColor.quaternaryLabel))
                }
            }

            Spacer()

            Text("VORBEI")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
                .tracking(0.5)
        }
        .padding(16)
        .background(DS.Colors.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .opacity(0.6)
    }
}

// MARK: - Kommende Tage

private struct UpcomingCard: View {
    let day: DayViewModel
    var showCutoffBanner: Bool = false
    let onToggle: () -> Void

    private var isOptedOut: Bool { !day.currentUserAttending }
    private var isLocked: Bool { day.lunchDay.isLocked }

    var body: some View {
        HStack(spacing: 12) {
            DateBlock(day: day, variant: isOptedOut ? .optOut : .light)

            VStack(alignment: .leading, spacing: 4) {
                Text(day.date.weekdayNameLong)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isOptedOut ? DS.Colors.textTertiary : DS.Colors.textPrimary)

                if showCutoffBanner {
                    // Cutoff-Hinweis direkt als Subzeile in der Karte
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(DS.Colors.warning)
                        Text("Keine Änderungen mehr möglich")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.Colors.warning)
                    }
                } else if isOptedOut {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DS.Colors.textTertiary)
                        Text("Du bist abgemeldet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                } else {
                    HStack(spacing: 6) {
                        AvatarStack(users: Array(day.attendees.prefix(3)), variant: .light)
                        Text("\(day.attendingCount) angemeldet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Button(action: onToggle) {
                ActionPill(isSignedUp: day.currentUserAttending, variant: .light)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isLocked)
            .opacity(isLocked ? 0.4 : 1.0)
        }
        .padding(16)
        .background(showCutoffBanner ? DS.Colors.warningSurface : DS.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    showCutoffBanner
                        ? DS.Colors.warning.opacity(0.3)
                        : (isOptedOut ? DS.Colors.border.opacity(0.6) : Color.lunchEmerald.opacity(0.35)),
                    style: StrokeStyle(
                        lineWidth: isOptedOut && !showCutoffBanner ? 1 : (showCutoffBanner ? 1 : 2),
                        dash: isOptedOut && !showCutoffBanner ? [6, 4] : []
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(isOptedOut || showCutoffBanner ? 0 : 0.04), radius: 4, y: 2)
    }
}

// MARK: - Unterkomponenten

private enum CardVariant { case dark, todayLocked, light, past, optOut }

private struct DateBlock: View {
    let day: DayViewModel
    let variant: CardVariant

    var body: some View {
        VStack(spacing: 1) {
            Text(day.date.weekdayName.replacingOccurrences(of: ".", with: ""))
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(labelColor)
            Text(dayNumber)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(numberColor)
        }
        .frame(width: 52, height: 52)
        .background(blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: variant == .dark ? 1 : 0)
        )
    }

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: day.date))
    }

    private var blockBackground: Color {
        switch variant {
        case .dark:        return Color.white.opacity(0.1)
        case .todayLocked: return DS.Colors.surface
        case .light:       return Color.lunchEmerald.opacity(0.08)
        case .past:        return DS.Colors.surfaceAlt
        case .optOut:      return DS.Colors.surface
        }
    }

    private var labelColor: Color {
        switch variant {
        case .dark:        return Color.white.opacity(0.55)
        case .todayLocked: return DS.Colors.textTertiary
        case .light:       return Color.lunchEmeraldDark
        case .past:        return DS.Colors.textTertiary
        case .optOut:      return DS.Colors.textTertiary
        }
    }

    private var numberColor: Color {
        switch variant {
        case .dark:        return Color.white
        case .todayLocked: return DS.Colors.textSecondary
        case .light:       return DS.Colors.textPrimary
        case .past:        return DS.Colors.textTertiary
        case .optOut:      return DS.Colors.textTertiary
        }
    }

    private var borderColor: Color {
        variant == .dark ? Color.white.opacity(0.12) : Color.clear
    }
}

private struct AvatarStack: View {
    let users: [User]
    let variant: CardVariant

    private var borderColor: Color {
        variant == .dark ? Color(white: 0.14) : DS.Colors.background
    }

    var body: some View {
        HStack(spacing: -6) {
            ForEach(users) { user in
                UserAvatarView(user: user, size: 16, borderColor: borderColor, borderWidth: 1.5)
            }
        }
    }
}

private struct ActionPill: View {
    let isSignedUp: Bool
    let variant: CardVariant

    var body: some View {
        HStack(spacing: 4) {
            if isSignedUp {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                Text("Dabei")
                    .font(.system(size: 12, weight: .semibold))
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("Anmelden")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .foregroundStyle(pillForeground)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(pillBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            Group {
                if !isSignedUp {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(DS.Colors.border, lineWidth: 1)
                }
            }
        )
    }

    private var pillForeground: Color {
        switch (variant, isSignedUp) {
        case (.dark, true):  return Color(white: 0.1)
        case (.dark, false): return DS.Colors.textSecondary
        case (.light, true): return Color.white
        default:             return DS.Colors.textSecondary
        }
    }

    private var pillBackground: Color {
        switch (variant, isSignedUp) {
        case (.dark, true):  return Color.lunchEmeraldLight
        case (.dark, false): return Color.white.opacity(0.15)
        case (.light, true): return Color.lunchEmerald
        default:             return DS.Colors.surface
        }
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
    static let lunchEmerald      = Color(red: 0.13, green: 0.70, blue: 0.44)
    static let lunchEmeraldDark  = Color(red: 0.09, green: 0.55, blue: 0.34)
    static let lunchEmeraldLight = Color(red: 0.38, green: 0.88, blue: 0.58)
}
