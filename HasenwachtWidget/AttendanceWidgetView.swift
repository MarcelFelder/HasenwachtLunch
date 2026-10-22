//
//  AttendanceWidgetView.swift
//  HasenwachtWidget
//
//  Visuelles Konzept: jede Kachel ist eine vollflächige, zustandsbasierte
//  Gradient-Karte (grün = dabei, korall = abgemeldet) mit einem grossen
//  "Glas"-Icon als Blickfang. Bei .locked/.lunchOver wird dieselbe Farbe
//  über einen dunklen Scrim abgedunkelt statt die Farbsemantik zu wechseln —
//  so bleibt "grün = angemeldet" immer gültig, auch wenn nicht mehr
//  editierbar. Beim Small-Widget ist die GANZE Kachel der Toggle-Button.
//

import SwiftUI
import WidgetKit
import AppIntents

struct AttendanceWidgetView: View {
    let entry: AttendanceEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryRectangular {
            accessoryContent
                .containerBackground(for: .widget) { Color.clear }
        } else {
            cardContent
                .containerBackground(for: .widget) { background }
        }
    }

    // MARK: - Hintergrund

    private var background: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Color.black.opacity(scrimOpacity)
            // dezenter Glanz-Schimmer für den "Liquid Glass"-Touch
            LinearGradient(
                colors: [.white.opacity(0.14), .clear, .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var gradientColors: [Color] {
        switch entry.state {
        case .loggedOut, .error:
            return WidgetDS.Gradients.neutral
        case .attendance(let state):
            return state.isAttending ? WidgetDS.Gradients.attending : WidgetDS.Gradients.notAttending
        case .week:
            return WidgetDS.Gradients.week
        }
    }

    private var scrimOpacity: Double {
        switch entry.state {
        case .loggedOut, .error:
            return 0.1
        case .attendance(let state):
            switch state.phase {
            case .bookable:  return 0
            case .locked:    return 0.35
            case .lunchOver: return 0.55
            }
        case .week:
            return 0.05
        }
    }

    // MARK: - Karten-Inhalt (systemSmall / systemLarge)

    @ViewBuilder
    private var cardContent: some View {
        switch entry.state {
        case .loggedOut:
            loggedOutCard
        case .error(let message):
            errorCard(message)
        case .attendance(let state):
            smallCard(state)
        case .week(let states):
            weekCard(states)
        }
    }

    private var loggedOutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassIcon(systemName: "person.fill.questionmark", diameter: 42)
            Spacer(minLength: 4)
            Text("Nicht angemeldet")
                .font(WidgetDS.Typography.subheading)
            Text("Zum Anmelden tippen")
                .font(WidgetDS.Typography.caption)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "hasenwacht://open"))
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassIcon(systemName: "wifi.slash", diameter: 42)
            Spacer(minLength: 4)
            Text(message)
                .font(WidgetDS.Typography.subheading)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(URL(string: "hasenwacht://open"))
    }

    // MARK: - systemSmall: die ganze Kachel ist der Toggle

    @ViewBuilder
    private func smallCard(_ state: AttendanceDisplayState) -> some View {
        let visual = visual(for: state)
        let tile = VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Explizit "HEUTE"/"MORGEN" statt nur des Wochentags — sonst ist beim
                // Blick aufs Widget nicht klar, für welchen Tag man sich gerade an-
                // oder abmeldet (besonders relevant nach dem 14-Uhr-Cutoff, wenn der
                // angezeigte Tag "lautlos" von heute auf morgen springt).
                Text(relativeDayLabel(for: state.date))
                    .font(WidgetDS.Typography.caption2)
                    .tracking(1.2)
                Spacer()
                if state.isStale {
                    GlassPill(systemImage: "wifi.slash", text: nil)
                }
            }

            Spacer(minLength: 2)

            HStack {
                Spacer()
                GlassIcon(systemName: visual.mainIcon, diameter: 48, badge: visual.phaseBadge)
                Spacer()
            }

            Spacer(minLength: 2)

            Text(visual.title)
                .font(WidgetDS.Typography.subheading)
            Text(state.date, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                .font(WidgetDS.Typography.caption)
                .opacity(0.85)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let badge = contextBadge(state) {
                badge
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        if state.phase == .bookable {
            Button(intent: ToggleAttendanceIntent(date: state.date, currentlyAttending: state.isAttending)) {
                tile
            }
            .buttonStyle(.plain)
        } else {
            tile.widgetURL(URL(string: "hasenwacht://open"))
        }
    }

    // MARK: - systemLarge: ganze Woche (Mo–Fr) mit Toggle pro Tag

    private func weekCard(_ states: [AttendanceDisplayState]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(weekLabel(for: states))
                .font(WidgetDS.Typography.caption2)
                .tracking(1.4)
                .opacity(0.85)

            VStack(spacing: 6) {
                ForEach(states, id: \.date) { state in
                    weekRow(state)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func weekRow(_ state: AttendanceDisplayState) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(state.date, format: .dateTime.weekday(.abbreviated))
                    .font(WidgetDS.Typography.caption)
                    .opacity(0.75)
                Text(state.date, format: .dateTime.day())
                    .font(WidgetDS.Typography.body)
            }
            .frame(width: 32, alignment: .leading)

            weekRowStatus(state)
                .font(WidgetDS.Typography.caption)
                .lineLimit(1)
                .opacity(0.95)

            Spacer(minLength: 4)

            weekRowTrailing(state)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: WidgetDS.Radius.md))
    }

    private func weekRowStatus(_ state: AttendanceDisplayState) -> Text {
        if state.isCancelled {
            return Text("Gestrichen")
        } else if let holidayName = state.holidayName {
            return Text(holidayName)
        } else {
            return Text(state.isAttending ? "Dabei" : "Abgemeldet")
        }
    }

    @ViewBuilder
    private func weekRowTrailing(_ state: AttendanceDisplayState) -> some View {
        if state.isCancelled || state.holidayName != nil {
            Image(systemName: state.isCancelled ? "calendar.badge.minus" : "calendar.badge.exclamationmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        } else if state.phase == .bookable {
            Button(intent: ToggleAttendanceIntent(date: state.date, currentlyAttending: state.isAttending)) {
                Image(systemName: state.isAttending ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: state.isAttending ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    /// "DIESE WOCHE" / "NÄCHSTE WOCHE" — Vergleich der ISO-Kalenderwoche des ersten
    /// angezeigten Tages mit der aktuellen Woche (statt eines gespeicherten Flags,
    /// da sich das aus den Entry-Daten selbst ergibt).
    private func weekLabel(for states: [AttendanceDisplayState]) -> String {
        guard let first = states.first else { return "WOCHE" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let weeksApart = calendar.dateComponents([.weekOfYear], from: Date(), to: first.date).weekOfYear ?? 0
        return weeksApart >= 1 ? "NÄCHSTE WOCHE" : "DIESE WOCHE"
    }

    /// "HEUTE" / "MORGEN" für den Tagestitel im kleinen Widget, sonst der Wochentag.
    private func relativeDayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "HEUTE" }
        if calendar.isDateInTomorrow(date) { return "MORGEN" }
        return date.formatted(.dateTime.weekday(.wide)).uppercased()
    }

    // MARK: - Feiertag / Gestrichen-Badge (für Small)

    private func contextBadge(_ state: AttendanceDisplayState) -> GlassPill? {
        if state.isCancelled {
            return GlassPill(systemImage: "calendar.badge.minus", text: "Gestrichen")
        }
        if let holidayName = state.holidayName {
            return GlassPill(systemImage: "calendar.badge.exclamationmark", text: holidayName)
        }
        return nil
    }

    // MARK: - Abgeleiteter visueller Zustand

    private struct VisualState {
        let mainIcon: String
        let phaseBadge: String?
        let title: String
        let phaseNote: String?
    }

    private func visual(for state: AttendanceDisplayState) -> VisualState {
        let badge: String?
        switch state.phase {
        case .bookable:  badge = nil
        case .locked:    badge = "lock.fill"
        case .lunchOver: badge = "clock.fill"
        }
        return VisualState(
            mainIcon: state.isAttending ? "checkmark" : "xmark",
            phaseBadge: badge,
            title: state.isAttending ? "Dabei" : "Abgemeldet",
            phaseNote: LunchPhaseCalculator.message(for: state.phase)
        )
    }

    // MARK: - Lock-Screen-Widget (accessoryRectangular)

    @ViewBuilder
    private var accessoryContent: some View {
        switch entry.state {
        case .loggedOut:
            Label("Anmelden", systemImage: "person.crop.circle.badge.exclamationmark")
                .widgetURL(URL(string: "hasenwacht://open"))
        case .error:
            Label("Offline", systemImage: "wifi.slash")
        case .attendance(let state):
            let icon = state.isAttending ? "checkmark.circle.fill" : "xmark.circle.fill"
            let label = "\(state.date.formatted(.dateTime.weekday(.abbreviated))): \(state.isAttending ? "Dabei" : "Abgemeldet")"
            if state.phase == .bookable {
                Button(intent: ToggleAttendanceIntent(date: state.date, currentlyAttending: state.isAttending)) {
                    Label(label, systemImage: icon)
                }
                .buttonStyle(.plain)
            } else {
                Label(label, systemImage: icon)
            }
        case .week:
            // Wird für .accessoryRectangular nie geliefert (der Provider gibt
            // .week nur bei .systemLarge zurück) — nur für Exhaustiveness nötig.
            Label("Mittagessen", systemImage: "fork.knife")
        }
    }
}
