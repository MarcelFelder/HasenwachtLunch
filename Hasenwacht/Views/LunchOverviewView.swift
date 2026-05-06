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
    @State private var weekOffset = 0

    private var weekDays: [DayViewModel] {
        viewModel.days(forWeekOffset: weekOffset)
    }

    private var upcomingSignups: Int {
        weekDays.filter { $0.currentUserAttending && !$0.isPast && $0.lunchDay.hasLunch }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGray6).ignoresSafeArea()

                if viewModel.isLoading && viewModel.days.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                dayListSection
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LUNCH")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.orange)
                        .tracking(2.5)
                    Text("Anmeldung")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.primary)
                }
                Spacer()
                signupCountPill
            }

            weekSwitcher
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(Color.white)
    }

    private var signupCountPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.lunchEmerald)
                .frame(width: 6, height: 6)
            Text("\(upcomingSignups) dabei")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.lunchEmeraldDark)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.lunchEmeraldDark.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.lunchEmeraldDark.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var weekSwitcher: some View {
        HStack(spacing: 4) {
            Button {
                if weekOffset > 0 { weekOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(weekOffset == 0 ? Color(UIColor.tertiaryLabel) : Color.primary)
                    .frame(width: 36, height: 36)
                    .background(weekOffset == 0 ? Color.clear : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: weekOffset > 0 ? Color.black.opacity(0.08) : Color.clear,
                            radius: 2, y: 1)
            }
            .disabled(weekOffset == 0)

            Spacer()

            VStack(spacing: 2) {
                Text(weekLabel)
                    .font(.system(size: 14, weight: .bold))
                Text(weekDateRange)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
            }

            Spacer()

            Button {
                if weekOffset < 2 { weekOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(weekOffset < 2 ? Color.primary : Color(UIColor.tertiaryLabel))
                    .frame(width: 36, height: 36)
                    .background(weekOffset < 2 ? Color.white : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: weekOffset < 2 ? Color.black.opacity(0.08) : Color.clear,
                            radius: 2, y: 1)
            }
            .disabled(weekOffset >= 2)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Tagesliste

    private var dayListSection: some View {
        VStack(spacing: 8) {
            ForEach(weekDays) { day in
                DayCard(day: day) {
                    guard !day.isPast, day.lunchDay.hasLunch else { return }
                    Task { await viewModel.toggleAttendance(for: day.date) }
                }
            }

            Text("Anmeldung bis 9:00 Uhr am gleichen Tag möglich")
                .font(.system(size: 11))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
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
        switch weekOffset {
        case 0: return "Diese Woche"
        case 1: return "Nächste Woche"
        default: return "In \(weekOffset) Wochen"
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
    let onToggle: () -> Void

    var body: some View {
        Group {
            if day.isToday {
                TodayCard(day: day, onToggle: onToggle)
            } else if day.isPast {
                PastCard(day: day)
            } else {
                UpcomingCard(day: day, onToggle: onToggle)
            }
        }
    }
}

// MARK: - Heute (Hero)

private struct TodayCard: View {
    let day: DayViewModel
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .blur(radius: 24)
                    .offset(x: 20, y: -20)

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

                    ActionPill(isSignedUp: day.currentUserAttending, variant: .dark)
                }
                .padding(16)
            }
            .background(
                LinearGradient(
                    colors: [Color(white: 0.11), Color(white: 0.19)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.20), radius: 12, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(day.lunchDay.isLocked)
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
                Text(day.currentUserAttending ? "✓ Du warst dabei" : "Nicht teilgenommen")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(UIColor.quaternaryLabel))
            }

            Spacer()

            Text("Vorbei")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(UIColor.tertiaryLabel))
                .tracking(0.5)
        }
        .padding(16)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .opacity(0.6)
    }
}

// MARK: - Kommende Tage

private struct UpcomingCard: View {
    let day: DayViewModel
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                DateBlock(day: day, variant: .light)

                VStack(alignment: .leading, spacing: 4) {
                    Text(day.date.weekdayNameLong)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.primary)
                    HStack(spacing: 6) {
                        AvatarStack(users: Array(day.attendees.prefix(3)), variant: .light)
                        Text("\(day.attendingCount) angemeldet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                    }
                }

                Spacer(minLength: 0)

                ActionPill(isSignedUp: day.currentUserAttending, variant: .light)
            }
            .padding(16)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        day.currentUserAttending
                            ? Color.lunchEmerald.opacity(0.35)
                            : Color(UIColor.separator),
                        lineWidth: day.currentUserAttending ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(day.lunchDay.isLocked)
    }
}

// MARK: - Unterkomponenten

private enum CardVariant { case dark, light, past }

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
        case .dark:  return Color.white.opacity(0.1)
        case .light: return Color(UIColor.systemGray6)
        case .past:  return Color(UIColor.systemGray5)
        }
    }

    private var labelColor: Color {
        switch variant {
        case .dark:  return Color.white.opacity(0.55)
        case .light: return Color(UIColor.secondaryLabel)
        case .past:  return Color(UIColor.tertiaryLabel)
        }
    }

    private var numberColor: Color {
        switch variant {
        case .dark:  return Color.white
        case .light: return Color.primary
        case .past:  return Color(UIColor.tertiaryLabel)
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
        variant == .dark ? Color(white: 0.14) : Color.white
    }

    var body: some View {
        HStack(spacing: -6) {
            ForEach(users) { user in
                Circle()
                    .fill(user.avatarColor)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(borderColor, lineWidth: 2))
            }
        }
    }
}

private struct ActionPill: View {
    let isSignedUp: Bool
    let variant: CardVariant

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isSignedUp ? "checkmark" : "plus")
                .font(.system(size: 12, weight: .bold))
            Text(isSignedUp ? "Dabei" : "Anmelden")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(pillForeground)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(pillBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            Group {
                if variant == .light && !isSignedUp {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(UIColor.separator), lineWidth: 1)
                }
            }
        )
    }

    private var pillForeground: Color {
        switch (variant, isSignedUp) {
        case (.dark, true):  return Color(white: 0.1)
        case (.dark, false): return Color(white: 0.1)
        case (.light, true): return Color.white
        default:             return Color(UIColor.secondaryLabel)
        }
    }

    private var pillBackground: Color {
        switch (variant, isSignedUp) {
        case (.dark, true):  return Color.lunchEmeraldLight   // emerald-400-ish
        case (.dark, false): return Color.white
        case (.light, true): return Color.lunchEmerald        // emerald-500
        default:             return Color(UIColor.systemGray6)
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
    static let lunchEmerald     = Color(red: 0.13, green: 0.70, blue: 0.44)
    static let lunchEmeraldDark = Color(red: 0.09, green: 0.55, blue: 0.34)
    static let lunchEmeraldLight = Color(red: 0.38, green: 0.88, blue: 0.58)
}
