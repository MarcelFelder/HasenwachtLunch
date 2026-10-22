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
        .description("Zeigt deinen An-/Abmeldestatus fürs Mittagessen (klein: nächster Tag, gross: ganze Woche) und erlaubt Umschalten per Tap.")
        .supportedFamilies([.systemSmall, .systemLarge, .accessoryRectangular])
    }
}
