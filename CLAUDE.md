# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Hasenwacht is a native iOS app (SwiftUI) for organizing a shared lunch
schedule for a small group (e.g. a Kita/daycare lunch table): who's
attending which weekday, who's cooking, recurring absences/vacations, and
per-child pickup overrides. Single Xcode project, single app target
(`Hasenwacht`), no local Swift package or shared module — everything lives
under `Hasenwacht/`.

## Commands

There is no CLI build/test workflow — this is an Xcode-only project with no
Package.swift, no test target, and no lint config (no SwiftLint/SwiftFormat
present).

```bash
open Hasenwacht.xcodeproj   # build/run from Xcode (⌘R), target: Hasenwacht
```

```bash
# Equivalent from the command line if needed (iOS Simulator build):
xcodebuild -project Hasenwacht.xcodeproj -scheme Hasenwacht \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Dependencies are Swift Package Manager, resolved via
`Hasenwacht.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
(Firebase iOS SDK 12.12.1 + transitive Google deps) — no `npm install`-style
step needed; Xcode resolves packages on open/build.

Bundle id `com.marcelfelder.hasenwacht`, min iOS 17.6, Swift 5.

## Architecture

### Backend: Firebase (Firestore + Auth)

No Supabase/custom backend — all persistence is Firestore, configured via
`Hasenwacht/GoogleService-Info.plist`. Auth is **Sign in with Apple only**
(`AuthService.swift`, using `AuthenticationServices` + `FirebaseAuth`); there
is no email/password or magic-link path in this app (unlike the sibling
`tact-app` project).

Firestore collections (inferred from `*Service.swift` files, no schema file
exists):
- `users` — profile, `canCook`, `foodPreferences`, `isApproved`
- `lunchDays` — per-day *override* doc (holiday-override/cancel); see below
- `attendances` — per-user-per-day opt-in/opt-out doc, id via
  `Attendance.documentId(userId:date:)`
- `recurringAbsences` — one doc per user, `absentWeekdays: [Int]` (ISO 1=Mo…5=Fr)
- `children` / `childAttendanceOverrides` — child pickup assignment per day
- `config/inviteCode` — single doc holding the current invite code

**Sparse-write convention**: documents in `lunchDays` and `attendances` only
exist when something deviates from the default (default = "lunch happens",
default = "user is attending"). Absence of a document is a meaningful state,
not missing data — `LunchDayService`/`AttendanceService` methods explicitly
delete docs when a value returns to default rather than writing `false`.
Follow this pattern for new override-style data rather than writing a doc
per day per user unconditionally.

**New-user approval flow**: Apple sign-in creates a Firebase user
immediately, but `User.isApproved` gates access to the app — `RootView` in
`HasenwachtApp.swift` routes to `InviteCodeView` until `InviteService.verify`
+ `approveUser` flips that flag. Keep this check in `RootView`'s routing
chain, not scattered per-screen.

### App structure / routing

`HasenwachtApp.swift` → `RootView` is a single linear state machine, checked
in this order: onboarding completed → initial auth check done → logged in →
profile exists → profile approved (invite code) → `MainTabView`. Each step
has its own `didCheck*` flag to avoid flashing the wrong screen on cold
start — when adding a new gate, follow the same `didCheckX` pattern rather
than inferring "not loaded yet" from nil.

`MainTabView` (5 tabs: Mittagessen, Kochen\* (\*only if `canCook`),
Abwesenheiten, Statistik, Profil) is the real post-login UI.
`Views/ContentView.swift` (2 tabs, no gating) is leftover/unused — it's not
referenced from `RootView` — don't extend it, it's dead code.

### Service + singleton-ViewModel pattern

Every feature follows the same two-layer shape, both as **singletons**
(`static let shared`), not injected dependencies:
- `XService` (`Services/` or feature folder) — thin wrapper around one
  Firestore collection: CRUD + `observeX(...) -> ListenerRegistration`
  snapshot listeners. No business logic.
- `XViewModel` (`@Observable` or `ObservableObject`) — owns the
  `ListenerRegistration`s, combines multiple listeners' raw data into
  view-ready models, exposes `start()`/`stop()` lifecycle methods called
  from `RootView.handleAuthChange` on login/logout.

`LunchDaysViewModel` is the central example: it merges 4 listeners (users,
attendances, lunchDays, recurringAbsences) and only calls `rebuildDays()`
once all of them have fired at least once (`readyListeners` set), to avoid
building views off partially-loaded state. It also runs a 60s `Timer` to
re-derive day phases, since phase transitions (14:00 cutoff, 12:15
lunch-over) are time-based and wouldn't otherwise trigger a SwiftUI
re-render. New time-sensitive derived state should hook into this same timer
rather than adding a second one.

Feature folders (`Absence/`, `Child/`, `Cooking/`, `Stats/`) each bundle
their View + ViewModel (+ Service where needed) together; cross-cutting
services (`AuthService`, `CurrentUserService`, `NotificationService`,
`OnboardingService`, `HolidayService`, `InviteService`, `AttendanceService`,
`LunchDayService`, `UserService`) live flat in `Services/`.

### Day-phase business rule

`LunchDay.phase(for:now:)` in `Models/LunchDay.swift` is the one piece of
real business logic in the app and is depended on by the ViewModel, the
widget (on the unmerged branch, see below), and `NotificationService`:
- `.bookable` until the cutoff (day-before 14:00)
- `.locked` after cutoff until lunch time
- `.lunchOver` same-day after 12:15
All of it is computed in the `Europe/Zurich` time zone explicitly (hardcoded
`TimeZone(identifier: "Europe/Zurich")`), regardless of device locale/time
zone — preserve this when touching date logic, since the Gregorian
`Calendar.current` default would silently use device-local time instead.

### Design system

`DesignSystem/DesignSystem.swift` (`DS.Colors`, `DS.Typography`,
`DS.Spacing`, `DS.Radius`, `DS.Shadow`) is the single source of visual
constants, consumed as `DS.Colors.primary` etc. Colors are defined via a
`Color(lightHex:darkHex:)` initializer (`Models/Color+Hex.swift`) that
adapts automatically to system light/dark mode — there is no manual
dark-mode branching elsewhere, unlike `tact-app` which hardcodes one
dark palette.

### German-language convention

UI strings and inline comments are German throughout (matching the pilot
user base) — match this when adding user-facing text or comments.

### Unmerged widget branch

`origin/claude/hasenwacht-lunch-widget-jyqzzj` (not merged into
`hasenwacht-prod`) adds a full `HasenwachtWidget` WidgetKit extension target:
an interactive home-screen widget that toggles attendance via an
`AppIntent`, talking to Firestore over a hand-rolled REST client
(`FirestoreRESTClient.swift`) with its own token refresh
(`FirebaseTokenRefresher.swift`), sharing auth state with the main app via
an App Group keychain (`Shared/SharedKeychain.swift`,
`Shared/AppGroupConstants.swift`) since widget extensions can't use the
regular Firebase SDK's listener/auth session. It also refactors
`LunchPhaseCalculator`/`HolidayService` out of the main target into a new
`Shared/` folder usable by both targets. Worth reviewing/merging before
starting unrelated work in `LunchDay`/`HolidayService`, since that branch
has already moved those files.
