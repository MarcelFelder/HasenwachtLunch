//
//  AttendanceWidget.swift
//  HasenwachtWidget
//

import WidgetKit
import SwiftUI

struct AttendanceWidget: Widget {
    let kind: String = AppGroupConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AttendanceTimelineProvider()) { entry in
            AttendanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Mittagessen")
        .description("Zeigt deinen An-/Abmeldestatus fürs nächste Mittagessen und erlaubt Umschalten per Tap.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
