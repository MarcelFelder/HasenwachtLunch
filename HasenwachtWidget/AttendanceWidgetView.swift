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
        }
    }

    // MARK: - Karten-Inhalt (systemSmall / systemMedium)

    @ViewBuilder
    private var cardContent: some View {
        switch entry.state {
        case .loggedOut:
            loggedOutCard
        case .error(let message):
            errorCard(message)
        case .attendance(let state):
            attendanceCard(state)
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

    @ViewBuilder
    private func attendanceCard(_ state: AttendanceDisplayState) -> some View {
        if family == .systemMedium {
            mediumCard(state)
        } else {
            smallCard(state)
        }
    }

    // MARK: - systemSmall: die ganze Kachel ist der Toggle

    @ViewBuilder
    private func smallCard(_ state: AttendanceDisplayState) -> some View {
        let visual = visual(for: state)
        let tile = VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(state.date, format: .dateTime.weekday(.abbreviated))
                    .font(WidgetDS.Typography.title)
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
            Text(state.date, format: .dateTime.day().month(.abbreviated))
                .font(WidgetDS.Typography.caption)
                .opacity(0.85)

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

    // MARK: - systemMedium: Info links, grosser Status + Aktion rechts

    private func mediumCard(_ state: AttendanceDisplayState) -> some View {
        let visual = visual(for: state)

        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(state.date, format: .dateTime.weekday(.wide))
                        .font(WidgetDS.Typography.title)
                    if state.isStale {
                        GlassPill(systemImage: "wifi.slash", text: nil)
                    }
                }
                Text(state.date, format: .dateTime.day().month(.wide))
                    .font(WidgetDS.Typography.caption)
                    .opacity(0.85)

                if let badge = contextBadge(state) {
                    badge.padding(.top, 2)
                }

                Spacer(minLength: 4)

                if let note = visual.phaseNote {
                    Text(note)
                        .font(WidgetDS.Typography.caption)
                        .opacity(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(spacing: 8) {
                GlassIcon(systemName: visual.mainIcon, diameter: 44, badge: visual.phaseBadge)
                Text(visual.title)
                    .font(WidgetDS.Typography.body)

                if state.phase == .bookable {
                    Button(intent: ToggleAttendanceIntent(date: state.date, currentlyAttending: state.isAttending)) {
                        HStack(spacing: 4) {
                            Image(systemName: state.isAttending ? "xmark" : "checkmark")
                                .font(.system(size: 10, weight: .bold))
                            Text(state.isAttending ? "Abmelden" : "Anmelden")
                        }
                        .font(WidgetDS.Typography.caption)
                    }
                    .buttonStyle(.plain)
                    .tint(.white)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.22), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 0.75))
                }
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Feiertag / Gestrichen-Badge (gemeinsam für small & medium)

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
        }
    }
}
