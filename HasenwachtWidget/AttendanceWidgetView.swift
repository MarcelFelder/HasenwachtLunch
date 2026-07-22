//
//  AttendanceWidgetView.swift
//  HasenwachtWidget
//

import SwiftUI
import WidgetKit

struct AttendanceWidgetView: View {
    let entry: AttendanceEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch entry.state {
            case .loggedOut:
                loggedOutView
            case .error(let message):
                errorView(message)
            case .attendance(let state):
                attendanceView(state)
            }
        }
        .containerBackground(WidgetDS.Colors.background, for: .widget)
    }

    // MARK: - Nicht eingeloggt / Fehler

    private var loggedOutView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 22))
                .foregroundStyle(WidgetDS.Colors.textTertiary)
            Text("Nicht angemeldet")
                .font(WidgetDS.Typography.subheading)
                .foregroundStyle(WidgetDS.Colors.textPrimary)
            Text("In der App anmelden")
                .font(WidgetDS.Typography.caption)
                .foregroundStyle(WidgetDS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .widgetURL(URL(string: "hasenwacht://open"))
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 20))
                .foregroundStyle(WidgetDS.Colors.textTertiary)
            Text(message)
                .font(WidgetDS.Typography.caption)
                .foregroundStyle(WidgetDS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }

    // MARK: - Anwesenheits-Status

    private func attendanceView(_ state: AttendanceDisplayState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(state)
            Spacer(minLength: 4)
            statusBadge(state)

            if family == .systemMedium {
                Spacer(minLength: 4)
                actionRow(state)
            } else if state.phase == .bookable {
                Spacer(minLength: 4)
                toggleButton(state)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(_ state: AttendanceDisplayState) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(state.date, format: .dateTime.weekday(.wide))
                .font(WidgetDS.Typography.subheading)
                .foregroundStyle(WidgetDS.Colors.textPrimary)
            HStack(spacing: 4) {
                Text(state.date, format: .dateTime.day().month(.abbreviated))
                    .font(WidgetDS.Typography.caption)
                    .foregroundStyle(WidgetDS.Colors.textSecondary)
                if let holidayName = state.holidayName {
                    Text("· \(holidayName)")
                        .font(WidgetDS.Typography.caption)
                        .foregroundStyle(WidgetDS.Colors.warning)
                }
                if state.isCancelled {
                    Text("· Gestrichen")
                        .font(WidgetDS.Typography.caption)
                        .foregroundStyle(WidgetDS.Colors.danger)
                }
                if state.isStale {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 10))
                        .foregroundStyle(WidgetDS.Colors.textTertiary)
                }
            }
        }
    }

    private func statusBadge(_ state: AttendanceDisplayState) -> some View {
        HStack(spacing: 6) {
            Image(systemName: state.isAttending ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(state.isAttending ? WidgetDS.Colors.success : WidgetDS.Colors.danger)
            Text(state.isAttending ? "Du bist dabei" : "Du bist abgemeldet")
                .font(WidgetDS.Typography.body)
                .foregroundStyle(WidgetDS.Colors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(state.isAttending ? WidgetDS.Colors.successSurface : WidgetDS.Colors.dangerSurface)
        .clipShape(RoundedRectangle(cornerRadius: WidgetDS.Radius.md))
    }

    private func actionRow(_ state: AttendanceDisplayState) -> some View {
        Group {
            if state.phase == .bookable {
                toggleButton(state)
            } else {
                Text(LunchPhaseCalculator.message(for: state.phase) ?? "")
                    .font(WidgetDS.Typography.caption)
                    .foregroundStyle(WidgetDS.Colors.textTertiary)
            }
        }
    }

    private func toggleButton(_ state: AttendanceDisplayState) -> some View {
        Button(intent: ToggleAttendanceIntent(date: state.date, currentlyAttending: state.isAttending)) {
            HStack(spacing: 5) {
                Image(systemName: state.isAttending ? "xmark" : "checkmark")
                    .font(.system(size: 11, weight: .bold))
                Text(state.isAttending ? "Abmelden" : "Anmelden")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(state.isAttending ? WidgetDS.Colors.textSecondary : .white)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(state.isAttending ? WidgetDS.Colors.surfaceAlt : WidgetDS.Colors.success)
            .clipShape(RoundedRectangle(cornerRadius: WidgetDS.Radius.pill))
        }
        .buttonStyle(.plain)
    }
}
