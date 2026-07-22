//
//  AppGroupConstants.swift
//  Hasenwacht
//
//  Zentrale IDs für den Datenaustausch zwischen App und HasenwachtWidget-Extension.
//

import Foundation

enum AppGroupConstants {

    /// App-Group-Container für nicht-sensitive, geteilte Daten (UserDefaults-Suite).
    /// Muss identisch mit dem "App Groups"-Entitlement in beiden Targets sein.
    static let appGroupId = "group.com.marcelfelder.hasenwacht"

    /// Keychain-Access-Group für sensitive, geteilte Daten (Refresh-/ID-Token).
    /// Team-ID ist fix (Team 3YP97Z495J) — entspricht "$(AppIdentifierPrefix)group.com.marcelfelder.hasenwacht"
    /// im keychain-access-groups-Entitlement (Xcode löst das Prefix beim Signieren auf).
    static let keychainAccessGroup = "3YP97Z495J.group.com.marcelfelder.hasenwacht"

    /// `kind` des WidgetKit-Widgets — muss mit AttendanceWidget.swift übereinstimmen.
    static let widgetKind = "HasenwachtAttendanceWidget"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }
}
