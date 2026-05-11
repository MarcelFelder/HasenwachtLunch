//
//  OnboardingService.swift
//  Hasenwacht
//

import Foundation
import Observation

@Observable
final class OnboardingService {

    static let shared = OnboardingService()

    var hasCompletedOnboarding: Bool
    var firstAppUseDate: Date
    var showTutorial: Bool = false

    private static let onboardingKey  = "hasCompletedOnboarding"
    private static let firstUseDateKey = "firstAppUseDate"

    private init() {
        // Nur true wenn der Key explizit auf true gesetzt wurde
        // UserDefaults.bool gibt false für nicht-existierende Keys — aber wir prüfen explizit
        if UserDefaults.standard.object(forKey: Self.onboardingKey) != nil {
            self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Self.onboardingKey)
        } else {
            self.hasCompletedOnboarding = false
        }

        if let stored = UserDefaults.standard.object(forKey: Self.firstUseDateKey) as? Date {
            self.firstAppUseDate = stored
        } else {
            let now = Date()
            UserDefaults.standard.set(now, forKey: Self.firstUseDateKey)
            self.firstAppUseDate = now
        }
    }

    func markCompleted() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
    }

    func reset() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: Self.onboardingKey)
    }

    func presentTutorial() {
        showTutorial = true
    }
}
