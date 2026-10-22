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
    @ObservedObject private var childrenViewModel = ChildrenViewModel.shared

    private var day: DayViewModel? {
        viewModel.day(for: date)
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
                        cancelCard(day: day)
                        cookingCard
                        attendeesCard(day: day)
                        childrenCard(day: day)
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
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(date.formattedLong())
                        .font(DS.Typography.small)
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
                        ? [DS.Colors.success.opacity(0.85), DS.Colors.successDark]
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
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))

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
                    DSLockedChip(
                        icon: isAttending ? "checkmark" : "xmark",
                        text: isAttending ? "Dabei" : "Abgemeldet"
                    )
                } else if isAttending {
                    Button {
                        Task { await viewModel.toggleAttendance(for: day.date) }
                    } label: {
                        DSPillLabel(icon: "xmark", text: "Abmelden")
                    }
                    .buttonStyle(.glass)
                    .tint(DS.Colors.textSecondary)
                } else {
                    Button {
                        Task { await viewModel.toggleAttendance(for: day.date) }
                    } label: {
                        DSPillLabel(icon: "checkmark", text: "Anmelden")
                    }
                    .buttonStyle(.glassProminent)
                    .tint(DS.Colors.success)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DS.Colors.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .dsShadow(DS.Shadow.card)
    }

    // MARK: - Tag-Streichung Card

    private func cancelCard(day: DayViewModel) -> some View {
        let userId = currentUserService.currentUser?.id ?? ""
        let userIsAttending = day.attendees.contains { $0.id == userId }
        let isCancelledByMe = day.cancelledBy == userId

        return Group {
            if day.isCancelled {
                // Tag ist gestrichen — Info-Card mit "Wieder aktivieren" (nur für den der gestrichen hat)
                cancelledStateCard(day: day, canUncancel: isCancelledByMe)
            } else if userIsAttending && !day.isPast && !day.lunchDay.isLocked {
                // Tag normal — Option zum Streichen (nur für angemeldete User)
                cancelActionCard(day: day)
            }
        }
    }

    /// Zeigt "Tag ist gestrichen" mit optionalem Reaktivieren-Button.
    private func cancelledStateCard(day: DayViewModel, canUncancel: Bool) -> some View {
        let cancellerName = day.allUsers.first { $0.id == day.cancelledBy }?.firstName ?? "Jemand"

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.danger)
                Text("Tag gestrichen")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                Spacer()
                Text("ABGESAGT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DS.Colors.danger)
                    .tracking(0.8)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(DS.Colors.dangerSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(DS.Colors.background)
            .overlay(Divider().background(DS.Colors.border), alignment: .bottom)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kein Mittagessen heute")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(canUncancel
                         ? "Du hast diesen Tag gestrichen"
                         : "Gestrichen von \(cancellerName)")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()
                if canUncancel {
                    Button {
                        Task { await viewModel.uncancelLunch(date: day.date) }
                    } label: {
                        DSPillLabel(icon: "arrow.uturn.backward", text: "Aktivieren")
                    }
                    .buttonStyle(.glass)
                    .tint(DS.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(DS.Colors.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(DS.Colors.danger.opacity(0.3), lineWidth: 1)
        )
        .background(DS.Colors.dangerSurface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .dsShadow(DS.Shadow.subtle)
    }

    /// "Tag streichen" Aktions-Karte — nur für angemeldete User sichtbar.
    @State private var showCancelConfirmation = false

    private func cancelActionCard(day: DayViewModel) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                Text("Tag streichen")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(DS.Colors.background)
            .overlay(Divider().background(DS.Colors.border), alignment: .bottom)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heute findet kein Lunch statt?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("Streiche den Tag — alle anderen sehen die Absage")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()
                Button {
                    showCancelConfirmation = true
                } label: {
                    DSPillLabel(icon: "xmark", text: "Streichen")
                }
                .buttonStyle(.glass)
                .tint(DS.Colors.danger)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(DS.Colors.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl).stroke(DS.Colors.border, lineWidth: 1))
        .dsShadow(DS.Shadow.subtle)
        .confirmationDialog(
            "Tag wirklich streichen?",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Ja, streichen", role: .destructive) {
                Task { await viewModel.cancelLunch(date: day.date) }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle anderen User sehen die Absage. Du kannst sie jederzeit wieder aufheben.")
        }
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
                        .font(DS.Typography.micro)
                        .foregroundStyle(DS.Colors.success)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(DS.Colors.successSurface)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
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
                            DSPillLabel(icon: "xmark", text: "Deaktivieren")
                        }
                        .buttonStyle(.glass)
                        .tint(DS.Colors.danger)
                    }
                } else {
                    // Aktivieren
                    Button {
                        Task { await viewModel.activateLunchForHoliday(date: day.date) }
                    } label: {
                        DSPillLabel(icon: "fork.knife", text: "Aktivieren")
                    }
                    .buttonStyle(.glass)
                    .tint(DS.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(DS.Colors.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(day.lunchDay.forceLunch
                        ? DS.Colors.success.opacity(0.3)
                        : DS.Colors.warning.opacity(0.3), lineWidth: 1)
        )
        .background(day.lunchDay.forceLunch ? DS.Colors.successSurface : DS.Colors.warningSurface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .dsShadow(DS.Shadow.subtle)
    }

    // MARK: - Cooking Card

    private var cookingCard: some View {
        let slot = cookingViewModel.slot(for: date)
        let cook = slot.flatMap { s in
            viewModel.day(for: date)?.allUsers.first { $0.id == s.userId }
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
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(slot != nil ? Color.cookingPurple.opacity(0.25) : DS.Colors.border, lineWidth: 1)
        )
        .dsShadow(DS.Shadow.subtle)
    }

    // MARK: - Children Card (eigene Kinder für diesen Tag steuern)

    private func childrenCard(day: DayViewModel) -> some View {
        let userId = currentUserService.currentUser?.id ?? ""
        let myChildren = childrenViewModel.children(forUserId: userId)
        let attendingIds = Set(day.attendees.compactMap { $0.id })

        return Group {
            if !myChildren.isEmpty && !day.isPast {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Circle().fill(DS.Colors.primary).frame(width: 6, height: 6)
                        Text("Meine Kinder")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.Colors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(DS.Colors.background)
                    .overlay(Divider().background(DS.Colors.border), alignment: .bottom)

                    ForEach(Array(myChildren.enumerated()), id: \.element.id) { index, child in
                        childToggleRow(
                            child: child,
                            day: day,
                            currentUserId: userId,
                            attendingIds: attendingIds
                        )
                        if index < myChildren.count - 1 {
                            Divider().padding(.leading, 16).background(DS.Colors.border)
                        }
                    }
                }
                .background(DS.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl).stroke(DS.Colors.border, lineWidth: 1))
                .dsShadow(DS.Shadow.subtle)
            }
        }
    }

    /// Eine Toggle-Zeile pro Kind. Logik:
    ///  - Wenn primary parent dabei → automatisch dabei (für secondary parent nicht änderbar)
    ///  - Wenn primary parent nicht da → kann secondary parent das Kind übernehmen
    ///  - Wenn aktueller User = primary → kann selbst toggeln (abmelden für heute)
    private func childToggleRow(child: Child,
                                day: DayViewModel,
                                currentUserId: String,
                                attendingIds: Set<String>) -> some View {

        let isPrimary = child.primaryParentId == currentUserId
        let primaryAttending = attendingIds.contains(child.primaryParentId)
        let currentTaker = childrenViewModel.takingParent(
            for: child, on: day.date, attendingUserIds: attendingIds
        )
        let primaryParentUser = day.allUsers.first { $0.id == child.primaryParentId }

        return HStack(spacing: 12) {
            // Avatar/Initial
            ZStack {
                Circle().fill(DS.Colors.primarySurface).frame(width: 32, height: 32)
                Text(String(child.name.prefix(1)).uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.Colors.primaryDark)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(child.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.Colors.textPrimary)

                if let taker = currentTaker {
                    if taker == currentUserId {
                        Text(isPrimary ? "Standard: kommt mit dir" : "Du übernimmst")
                            .font(DS.Typography.micro)
                            .foregroundStyle(DS.Colors.success)
                    } else {
                        let takerUser = day.allUsers.first { $0.id == taker }
                        Text("Kommt mit \(takerUser?.firstName ?? "?")")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                } else {
                    Text(primaryAttending
                         ? "—"
                         : "\(primaryParentUser?.firstName ?? "Hauptbetreuer") nicht dabei")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
            }

            Spacer()

            childToggleButton(
                child: child,
                day: day,
                isPrimary: isPrimary,
                primaryAttending: primaryAttending,
                currentTaker: currentTaker,
                currentUserId: currentUserId
            )
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(DS.Colors.background)
    }

    @ViewBuilder
    private func childToggleButton(child: Child,
                                   day: DayViewModel,
                                   isPrimary: Bool,
                                   primaryAttending: Bool,
                                   currentTaker: String?,
                                   currentUserId: String) -> some View {
        let isDabei = currentTaker != nil
        let iCanToggle: Bool = {
            // Primary kann immer toggeln
            if isPrimary { return true }
            // Secondary nur wenn primary nicht da
            if !primaryAttending { return true }
            // Wenn primary dabei ist und secondary das Kind übernommen hat → kann zurückgeben
            if currentTaker == currentUserId { return true }
            return false
        }()

        let toggle = {
            Task {
                guard let childId = child.id else { return }
                if isDabei {
                    // Aktuell dabei → abmelden
                    await childrenViewModel.setOverride(
                        childId: childId, date: day.date, takingParentId: nil
                    )
                } else {
                    // Aktuell nicht dabei → ich übernehme
                    await childrenViewModel.setOverride(
                        childId: childId, date: day.date, takingParentId: currentUserId
                    )
                }
            }
        }

        Group {
            if isDabei {
                Button { _ = toggle() } label: {
                    DSPillLabel(icon: "checkmark", text: "Dabei", height: 32)
                }
                .buttonStyle(.glassProminent)
            } else {
                Button { _ = toggle() } label: {
                    DSPillLabel(icon: "plus", text: "Mitnehmen", height: 32)
                }
                .buttonStyle(.glass)
            }
        }
        .tint(DS.Colors.primary)
        .disabled(!iCanToggle)
        .opacity(iCanToggle ? 1.0 : 0.5)
    }

    // MARK: - Dabei Section (immer sichtbar)

    private func attendeesCard(day: DayViewModel) -> some View {
        let attendingIds = Set(day.attendees.compactMap { $0.id })

        return VStack(alignment: .leading, spacing: 0) {
            DSSectionHeader(title: "Dabei", count: day.attendees.count, dotColor: DS.Colors.success)

            if day.attendees.isEmpty {
                emptyRow(text: "Niemand angemeldet")
            } else {
                ForEach(Array(day.attendees.enumerated()), id: \.element.id) { index, user in
                    let kids = childrenViewModel.childrenTakenBy(
                        userId: user.id ?? "",
                        on: day.date,
                        attendingUserIds: attendingIds
                    )
                    DetailUserRow(user: user, dimmed: false, childrenTaken: kids)
                    if index < day.attendees.count - 1 {
                        Divider().padding(.leading, 64).background(DS.Colors.border)
                    }
                }
            }
        }
        .background(DS.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl).stroke(DS.Colors.border, lineWidth: 1))
        .dsShadow(DS.Shadow.subtle)
    }

    // MARK: - Abgemeldet Section (immer sichtbar)

    private func absenteesCard(day: DayViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DSSectionHeader(title: "Abgemeldet", count: day.absentees.count, dotColor: DS.Colors.textTertiary)

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
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl).stroke(DS.Colors.border, lineWidth: 1))
        .dsShadow(DS.Shadow.subtle)
    }

    // MARK: - Helpers

    private func emptyRow(text: String) -> some View {
        Text(text)
            .font(DS.Typography.body)
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
    var childrenTaken: [Child] = []

    @State private var showChildrenPopover = false

    var body: some View {
        HStack(spacing: 12) {
            UserAvatarView(user: user, size: 36)
                .opacity(dimmed ? 0.4 : 1.0)

            Text(user.fullName)
                .font(.system(size: 15))
                .foregroundStyle(dimmed ? DS.Colors.textTertiary : DS.Colors.textPrimary)

            // Kinder-Badge "+N"
            if !childrenTaken.isEmpty {
                Button {
                    showChildrenPopover = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "figure.child")
                            .font(.system(size: 10, weight: .bold))
                        Text("+\(childrenTaken.count)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(DS.Colors.primaryDark)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(DS.Colors.primarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .popover(isPresented: $showChildrenPopover) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Kinder dabei")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .tracking(0.5)
                        ForEach(childrenTaken) { child in
                            HStack(spacing: 6) {
                                Image(systemName: "figure.child")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DS.Colors.primary)
                                Text(child.name)
                                    .font(.system(size: 14))
                                    .foregroundStyle(DS.Colors.textPrimary)
                            }
                        }
                    }
                    .padding(14)
                    .presentationCompactAdaptation(.popover)
                }
            }

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
                    .foregroundStyle(DS.Colors.success)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
