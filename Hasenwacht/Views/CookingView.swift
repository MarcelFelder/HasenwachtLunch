//
//  CookingView.swift
//  Hasenwacht
//
//  Kochplanung-Tab (Beta).
//

import SwiftUI

struct CookingView: View {

    @Environment(CurrentUserService.self) private var currentUserService
    @StateObject private var viewModel = CookingViewModel.shared
    @StateObject private var lunchViewModel = LunchDaysViewModel.shared

    @State private var weekOffset = 0
    @State private var menuEditDate: Date? = nil

    private var weekDays: [Date] { LunchDaysViewModel.weekDates(offset: weekOffset) }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                        betaBanner
                        dayListSection
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if let userId = currentUserService.currentUser?.id {
                    viewModel.start(userId: userId)
                }
            }
            .sheet(item: $menuEditDate) { date in
                MenuEditSheet(date: date, viewModel: viewModel)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KOCHEN")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DS.Colors.primary)
                        .tracking(2.5)
                    Text("Kochplan")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(DS.Colors.textPrimary)
                }
                Spacer()
                Text("β Beta")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.cookingPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cookingPurple.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cookingPurple.opacity(0.3), lineWidth: 1))
            }
            weekSwitcher
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background(DS.Colors.surface)
    }

    private var betaBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "flask.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.cookingPurple)
            Text("Dieses Feature ist in der Entwicklung. Feedback willkommen!")
                .font(.system(size: 12))
                .foregroundStyle(DS.Colors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.cookingPurple.opacity(0.06))
        .overlay(Rectangle().frame(height: 1)
            .foregroundStyle(Color.cookingPurple.opacity(0.12)), alignment: .bottom)
    }

    private var weekSwitcher: some View {
        HStack(spacing: 4) {
            Button { if weekOffset > 0 { weekOffset -= 1 } } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(weekOffset == 0 ? DS.Colors.textTertiary : DS.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(weekOffset == 0 ? Color.clear : DS.Colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(weekOffset == 0)

            Spacer()
            VStack(spacing: 2) {
                Text(weekLabel).font(.system(size: 15, weight: .bold)).foregroundStyle(DS.Colors.textPrimary)
                Text(weekDateRange).font(.system(size: 12, weight: .medium)).foregroundStyle(DS.Colors.textSecondary)
            }
            Spacer()

            Button { if weekOffset < 2 { weekOffset += 1 } } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(weekOffset < 2 ? DS.Colors.textSecondary : DS.Colors.textTertiary)
                    .frame(width: 44, height: 44)
                    .background(weekOffset < 2 ? DS.Colors.background : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(weekOffset >= 2)
        }
        .padding(.horizontal, 6).padding(.vertical, 6)
        .background(DS.Colors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var dayListSection: some View {
        VStack(spacing: 8) {
            ForEach(weekDays, id: \.self) { date in
                let slot = viewModel.slot(for: date)
                let cook = lunchViewModel.days
                    .first { Calendar.current.isDate($0.date, inSameDayAs: date) }?
                    .allUsers.first { $0.id == slot?.userId }

                CookingDayCard(
                    date: date,
                    slot: slot,
                    cook: cook,
                    isCurrentUserCooking: viewModel.isCurrentUserCooking(on: date),
                    onClaim:    { Task { await viewModel.claimSlot(for: date) } },
                    onRelease:  { Task { await viewModel.releaseSlot(for: date) } },
                    onEditMenu: { menuEditDate = date }
                )
            }

            Text("Nur du kannst deine eigenen Kocheinträge bearbeiten.")
                .font(.system(size: 11))
                .foregroundStyle(DS.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8).padding(.horizontal, 16)
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 40)
    }

    private var weekLabel: String {
        switch weekOffset {
        case 0: return "Diese Woche"
        case 1: return "Nächste Woche"
        default: return "In \(weekOffset) Wochen"
        }
    }

    private var weekDateRange: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let cal = Calendar.current
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_CH")
        df.dateFormat = "MMMM"
        return "\(cal.component(.day, from: first)). – \(cal.component(.day, from: last)). \(df.string(from: last))"
    }
}

// MARK: - Day Card

private struct CookingDayCard: View {
    let date: Date
    let slot: CookingSlot?
    let cook: User?
    let isCurrentUserCooking: Bool
    let onClaim: () -> Void
    let onRelease: () -> Void
    let onEditMenu: () -> Void

    private var isPast: Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        return cal.startOfDay(for: date) < cal.startOfDay(for: Date())
    }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Datum
                VStack(spacing: 1) {
                    Text(date.weekdayName.replacingOccurrences(of: ".", with: ""))
                        .font(.system(size: 9, weight: .bold)).tracking(0.5)
                        .foregroundStyle(isPast ? DS.Colors.textTertiary :
                                         isCurrentUserCooking ? Color.cookingPurple : DS.Colors.textSecondary)
                    Text(String(Calendar.current.component(.day, from: date)))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(isPast ? DS.Colors.textTertiary : DS.Colors.textPrimary)
                }
                .frame(width: 52, height: 52)
                .background(isPast ? DS.Colors.surfaceAlt :
                             isCurrentUserCooking ? Color.cookingPurple.opacity(0.10) : DS.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(date.weekdayNameLong)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isPast ? DS.Colors.textTertiary : DS.Colors.textPrimary)
                        if isToday {
                            Text("Heute")
                                .font(.system(size: 9, weight: .bold)).foregroundStyle(.white).tracking(0.8)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Color.orange).clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    if let slot {
                        HStack(spacing: 6) {
                            if let cook { UserAvatarView(user: cook, size: 16) }
                            Text(isCurrentUserCooking ? "Du kochst 👨‍🍳" : "\(cook?.firstName ?? "Jemand") kocht")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isCurrentUserCooking ? Color.cookingPurple : DS.Colors.textSecondary)
                        }
                        if let title = slot.menuTitle, !title.isEmpty {
                            Text("🍽 \(title)")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    } else {
                        Text(isPast ? "Niemand hat gekocht" : "Noch kein Koch")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }

                Spacer(minLength: 0)

                if isPast {
                    Text("VORBEI")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.Colors.textTertiary).tracking(0.5)
                } else {
                    actionButton
                }
            }
            .padding(16)

            // Menü-Zeile wenn aktueller User kocht
            if isCurrentUserCooking && !isPast {
                Divider().background(DS.Colors.border)
                Button(action: onEditMenu) {
                    HStack(spacing: 8) {
                        Image(systemName: slot?.hasMenu == true ? "pencil" : "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.cookingPurple)
                        Text(slot?.hasMenu == true ? "Menü bearbeiten" : "Menü bekannt geben")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.cookingPurple)
                        Spacer()
                        if slot?.hasMenu == true {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.cookingPurple.opacity(0.5))
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Color.cookingPurple.opacity(0.04))
                }
            }
        }
        .background(DS.Colors.background)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isCurrentUserCooking ? Color.cookingPurple.opacity(0.4) : DS.Colors.border,
                        lineWidth: isCurrentUserCooking ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(isPast ? 0 : 0.04), radius: 4, y: 2)
        .opacity(isPast ? 0.6 : 1.0)
    }

    @ViewBuilder
    private var actionButton: some View {
        if isCurrentUserCooking {
            Button(action: onRelease) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                    Text("Austragen").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.horizontal, 12).frame(height: 36)
                .background(DS.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(DS.Colors.border, lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())
        } else if slot == nil {
            Button(action: onClaim) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill").font(.system(size: 11, weight: .bold))
                    Text("Ich koche").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).frame(height: 36)
                .background(Color.cookingPurple)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
}

// MARK: - Menu Edit Sheet

struct MenuEditSheet: View {
    let date: Date
    let viewModel: CookingViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.surface.ignoresSafeArea()
                VStack(spacing: 12) {
                    fieldCard(header: ("fork.knife", "Gericht"),
                              field: TextField("z. B. Pasta Carbonara", text: $title))

                    fieldCard(header: ("text.alignleft", "Weitere Infos (optional)"),
                              field: TextField("z. B. vegetarisch, Nüsse enthalten…",
                                              text: $description, axis: .vertical)
                                .lineLimit(3...6))

                    Button {
                        Task {
                            isSaving = true
                            await viewModel.updateMenu(for: date, title: title, description: description)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            Text(isSaving ? "Wird gespeichert…" : "Menü speichern")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(title.isEmpty ? DS.Colors.textTertiary : Color.cookingPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(title.isEmpty || isSaving)
                    .padding(.top, 4)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 16)
            }
            .navigationTitle("Menü — \(date.weekdayNameLong)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.Colors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }.foregroundStyle(DS.Colors.textSecondary)
                }
            }
            .onAppear {
                if let slot = viewModel.slot(for: date) {
                    title = slot.menuTitle ?? ""
                    description = slot.menuDescription ?? ""
                }
            }
        }
    }

    private func fieldCard<F: View>(header: (String, String), field: F) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: header.0).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.cookingPurple)
                Text(header.1).font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.Colors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(DS.Colors.background)
            .overlay(Divider().background(DS.Colors.border), alignment: .bottom)

            field
                .font(.system(size: 15))
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(DS.Colors.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
    }
}

// MARK: - Date: Identifiable für sheet(item:)

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}

// MARK: - Styles & Farben

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension Color {
    static let cookingPurple = Color(red: 0.45, green: 0.30, blue: 0.80)
}
