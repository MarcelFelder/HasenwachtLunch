//
//  ToggleAttendanceIntent.swift
//  HasenwachtWidget
//
//  Interaktiver App-Intent (iOS 17+): schaltet den Anmeldestatus für den
//  gegebenen Tag um, ohne die App zu öffnen. Ablauf:
//  1. Optimistic Update im geteilten Cache + sofortiger Timeline-Reload.
//  2. Echter Write gegen Firestore (REST, mit frisch getauschtem ID-Token).
//  3. Bei Fehler (z.B. Cutoff inzwischen abgelaufen, kein Netz): Cache
//     zurückrollen und Fehlermeldung fürs nächste Rendering hinterlegen.
//

import AppIntents
import WidgetKit
import Foundation

struct ToggleAttendanceIntent: AppIntent {

    static var title: LocalizedStringResource = "An-/Abmelden"
    static var description = IntentDescription("Meldet dich für das nächste buchbare Mittagessen an oder ab.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Datum")
    var date: Date

    @Parameter(title: "Aktuell angemeldet")
    var currentlyAttending: Bool

    init() {
        self.date = Date()
        self.currentlyAttending = true
    }

    init(date: Date, currentlyAttending: Bool) {
        self.date = date
        self.currentlyAttending = currentlyAttending
    }

    func perform() async throws -> some IntentResult {
        let newValue = !currentlyAttending

        applyOptimisticUpdate(isAttending: newValue, errorMessage: nil)
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)

        do {
            guard LunchPhaseCalculator.phase(for: date, now: Date()) == .bookable else {
                throw ToggleError.cutoffPassed
            }
            guard let userId = SharedKeychain.load()?.userId else {
                throw ToggleError.notSignedIn
            }

            let idToken = try await FirebaseTokenRefresher.validIdToken()
            let dateId = LunchPhaseCalculator.dayDocumentId(for: date)
            try await FirestoreRESTClient.patchDocument(
                path: "attendances/\(userId)_\(dateId)",
                fields: [
                    "userId": userId,
                    "date": date,
                    "isAttending": newValue,
                    "updatedAt": Date()
                ],
                idToken: idToken
            )
        } catch {
            // Fehlschlag: optimistisches Update zurückrollen.
            applyOptimisticUpdate(isAttending: currentlyAttending, errorMessage: Self.message(for: error))
        }

        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
        return .result()
    }

    private func applyOptimisticUpdate(isAttending: Bool, errorMessage: String?) {
        guard var cache = SharedAttendanceCache.load(),
              Calendar.current.isDate(cache.date, inSameDayAs: date)
        else { return }
        cache.isAttending = isAttending
        cache.lastErrorMessage = errorMessage
        cache.save()
    }

    private static func message(for error: Error) -> String {
        if let toggleError = error as? ToggleError {
            switch toggleError {
            case .cutoffPassed: return "Eintragungen bereits geschlossen"
            case .notSignedIn: return "Nicht angemeldet"
            }
        }
        return "Änderung nicht gespeichert"
    }

    enum ToggleError: Error {
        case cutoffPassed
        case notSignedIn
    }
}
