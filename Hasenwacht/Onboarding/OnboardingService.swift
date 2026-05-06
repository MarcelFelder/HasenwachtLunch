//
//  OnboardingService.swift
//  Hasenwacht
//
//  Verwaltet, ob das Onboarding-Tutorial bereits gesehen wurde.
//  Persistiert in UserDefaults – gerätegebunden, nicht usergebunden.
//  Damit sieht ein User das Tutorial einmal pro Gerät, auch nach Logout/Login.
//

import Foundation
import Observation

@Observable
final class OnboardingService {

    // MARK: - Singleton

    static let shared = OnboardingService()

    // MARK: - Reaktiver State

    /// True, sobald das Tutorial einmal abgeschlossen wurde.
    /// Wird beim App-Start aus UserDefaults gelesen.
    var hasCompletedOnboarding: Bool

    // MARK: - Private Konstanten

    private let storageKey = "hasCompletedOnboarding"

    // MARK: - Init

    private init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: storageKey)
    }

    // MARK: - Public API

    /// Markiert das Tutorial als abgeschlossen.
    /// Wird automatisch aufgerufen, wenn der User die letzte Karte erreicht.
    func markCompleted() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: storageKey)
    }

    /// Setzt den Onboarding-Status zurück.
    /// Nützlich für Debugging oder einen "Tutorial erneut ansehen"-Button im Profil.
    func reset() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: storageKey)
    }
}
