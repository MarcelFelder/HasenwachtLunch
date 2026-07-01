//
//  ProfileView.swift
//  Hasenwacht
//
//  Profil-Screen mit inline Edit Mode.
//  Reihenfolge: Hero → Account → Einstellungen → Hilfe
//

import SwiftUI
import PhotosUI

struct ProfileView: View {

    @Environment(CurrentUserService.self) private var currentUserService
    @Environment(NotificationService.self) private var notificationService
    @Environment(OnboardingService.self)  private var onboardingService

    @StateObject private var childrenViewModel = ChildrenViewModel.shared
    @StateObject private var lunchViewModel = LunchDaysViewModel.shared

    @State private var isEditing = false
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImage: UIImage?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showLogoutConfirmation = false

    private var user: User? { currentUserService.currentUser }

    private var hasChanges: Bool {
        firstName    != (user?.firstName ?? "") ||
        lastName     != (user?.lastName  ?? "") ||
        pendingImage != nil
    }

    // MARK: - Body

    var body: some View {
        @Bindable var notifications = notificationService

        NavigationStack {
            ZStack {
                DS.Colors.surface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        heroSection
                        if isEditing { nameEditSection }
                        if isEditing { saveError.map { errorBanner($0) } }
                        childrenSection
                        accountCard
                        settingsCard(
                            notifications: $notifications.remindersEnabled,
                            notificationService: notificationService
                        )
                        helpCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                    .animation(.easeInOut(duration: 0.22), value: isEditing)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.Colors.surface, for: .navigationBar)
            .toolbar { toolbarContent }
            .confirmationDialog("Wirklich abmelden?",
                                isPresented: $showLogoutConfirmation,
                                titleVisibility: .visible) {
                Button("Abmelden", role: .destructive) { performLogout() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Du kannst dich später jederzeit wieder anmelden.")
            }
            .onChange(of: selectedPhoto) { _, item in
                Task { await loadPhoto(from: item) }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if isEditing {
                Button("Abbrechen") { withAnimation { cancelEdit() } }
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            if isEditing {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().tint(DS.Colors.primary)
                    } else {
                        Text("Sichern")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(hasChanges ? DS.Colors.primary : DS.Colors.textTertiary)
                    }
                }
                .disabled(!hasChanges || isSaving)
            }
        }
    }

    // MARK: - Children Section

    private var childrenSection: some View {
        Group {
            if let userId = user?.id {
                ChildrenProfileSection(
                    viewModel: childrenViewModel,
                    currentUserId: userId,
                    allUsers: lunchViewModel.days.first?.allUsers ?? []
                )
            }
        }
    }

    // MARK: - Hero Section (gross, farbig, mit viel Luft)

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [DS.Colors.primary, DS.Colors.primaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Dekorative Kreise
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 200, height: 200)
                .offset(x: 200, y: -50)
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 120, height: 120)
                .offset(x: -30, y: 80)
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 70, height: 70)
                .offset(x: 280, y: 60)

            VStack(alignment: .leading, spacing: 0) {
                // Avatar — gross, zentriert-links
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let img = pendingImage {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else if let user {
                            UserAvatarView(user: user, size: 100,
                                           borderColor: Color.white.opacity(0.4),
                                           borderWidth: 3)
                        } else {
                            Circle().fill(Color.white.opacity(0.2))
                                .frame(width: 100, height: 100)
                        }
                    }
                    .shadow(color: Color.black.opacity(0.25), radius: 10, y: 5)

                    if isEditing {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack {
                                Circle().fill(DS.Colors.background).frame(width: 30, height: 30)
                                    .shadow(color: Color.black.opacity(0.15), radius: 3, y: 1)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12)).foregroundStyle(DS.Colors.primary)
                            }
                        }
                        .offset(x: 3, y: 3)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.bottom, 14)

                // Name
                Text(user?.fullName ?? "Unbekannt")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, 6)

                // Edit-Button oder Hint
                if !isEditing {
                    Button { withAnimation { startEdit() } } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .medium))
                            Text("Bearbeiten")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .transition(.opacity)
                } else {
                    Text("Tippe auf den Avatar um Foto zu ändern")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 36)
            .padding(.bottom, 24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: DS.Colors.primary.opacity(0.35), radius: 14, y: 6)
    }

    // MARK: - Name Edit Section

    private var nameEditSection: some View {
        VStack(spacing: 0) {
            sectionHeader(icon: "person.fill", title: "Name", color: DS.Colors.primary)

            HStack(spacing: 12) {
                Text("Vorname")
                    .font(.system(size: 14)).foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: 68, alignment: .leading)
                TextField("Vorname", text: $firstName)
                    .font(.system(size: 15))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .tint(DS.Colors.primary)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(DS.Colors.background)

            Divider().background(DS.Colors.border).padding(.leading, 16)

            HStack(spacing: 12) {
                Text("Nachname")
                    .font(.system(size: 14)).foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: 68, alignment: .leading)
                TextField("Nachname", text: $lastName)
                    .font(.system(size: 15))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .tint(DS.Colors.primary)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(DS.Colors.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Account Card

    private var accountCard: some View {
        VStack(spacing: 0) {
            sectionHeader(icon: "person.crop.circle", title: "Account", color: DS.Colors.textSecondary)

            Button(role: .destructive) {
                showLogoutConfirmation = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14)).foregroundStyle(DS.Colors.danger)
                    Text("Abmelden")
                        .font(.system(size: 15)).foregroundStyle(DS.Colors.danger)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(DS.Colors.background)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Settings Card

    private func settingsCard(notifications: Binding<Bool>,
                              notificationService: NotificationService) -> some View {
        VStack(spacing: 0) {
            sectionHeader(icon: "gearshape.fill", title: "Einstellungen", color: DS.Colors.textSecondary)

            // Benachrichtigungen
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminder am Vorabend")
                        .font(.system(size: 15)).foregroundStyle(DS.Colors.textPrimary)
                    Text("Täglich um 19:00 Uhr (ausser Feiertage)")
                        .font(.system(size: 12)).foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()
                Toggle("", isOn: notifications)
                    .labelsHidden()
                    .disabled(notificationService.authorizationStatus != .authorized)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(DS.Colors.background)

            if notificationService.authorizationStatus == .denied {
                Divider().background(DS.Colors.border)
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 13)).foregroundStyle(DS.Colors.warning)
                    Text("In iOS-Einstellungen deaktiviert.")
                        .font(.system(size: 12)).foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Öffnen").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.Colors.primary)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(DS.Colors.warningSurface)
            } else if notificationService.authorizationStatus == .notDetermined {
                Divider().background(DS.Colors.border)
                Button {
                    Task { await notificationService.requestAuthorization() }
                } label: {
                    HStack {
                        Text("Benachrichtigungen aktivieren")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(DS.Colors.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12)).foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(DS.Colors.background)
                }
            }

            Divider().background(DS.Colors.border)

            // Kochplan Toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kochplan")
                        .font(.system(size: 15)).foregroundStyle(DS.Colors.textPrimary)
                    Text("Aktiviert den Kochen-Tab")
                        .font(.system(size: 12)).foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { user?.canCook ?? false },
                    set: { newValue in Task { await toggleCanCook(newValue) } }
                ))
                .labelsHidden()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(DS.Colors.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Help Card

    private var helpCard: some View {
        VStack(spacing: 0) {
            sectionHeader(icon: "questionmark.circle.fill", title: "Hilfe", color: DS.Colors.textSecondary)

            Button {
                onboardingService.presentTutorial()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 14)).foregroundStyle(DS.Colors.primary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Einführung ansehen")
                            .font(.system(size: 15)).foregroundStyle(DS.Colors.textPrimary)
                        Text("Alle Features auf einen Blick")
                            .font(.system(size: 11)).foregroundStyle(DS.Colors.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12)).foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(DS.Colors.background)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(DS.Colors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(DS.Colors.background)
        .overlay(Divider().background(DS.Colors.border), alignment: .bottom)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(DS.Colors.danger)
            Text(message).font(.system(size: 13)).foregroundStyle(DS.Colors.danger)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.dangerSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Colors.danger.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Logik

    private func startEdit() {
        firstName = user?.firstName ?? ""
        lastName  = user?.lastName  ?? ""
        pendingImage = nil; saveError = nil; isEditing = true
    }

    private func cancelEdit() {
        isEditing = false; pendingImage = nil; selectedPhoto = nil; saveError = nil
    }

    private func save() async {
        let first = firstName.trimmingCharacters(in: .whitespaces)
        let last  = lastName.trimmingCharacters(in: .whitespaces)
        guard !first.isEmpty, !last.isEmpty else {
            saveError = "Vor- und Nachname dürfen nicht leer sein."
            return
        }
        isSaving = true; saveError = nil; defer { isSaving = false }

        let base64: String?
        if let img = pendingImage, let jpeg = img.jpegData(compressionQuality: 0.70) {
            base64 = jpeg.base64EncodedString()
        } else { base64 = nil }

        do {
            try await currentUserService.updateProfile(
                firstName: first, lastName: last,
                photoBase64: base64, canCook: user?.canCook ?? false,
                foodPreferences: user?.foodPreferences ?? FoodPreferences()
            )
            withAnimation { isEditing = false }
            pendingImage = nil; selectedPhoto = nil
        } catch {
            saveError = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func toggleCanCook(_ newValue: Bool) async {
        guard let user else { return }
        try? await currentUserService.updateProfile(
            firstName: user.firstName, lastName: user.lastName,
            photoBase64: nil, canCook: newValue,
            foodPreferences: user.foodPreferences
        )
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        await MainActor.run {
            pendingImage = uiImage.resized(to: CGSize(width: 200, height: 200))
        }
    }

    private func performLogout() {
        do {
            NotificationService.shared.cancelAllReminders()
            try AuthService.shared.signOut()
            CurrentUserService.shared.clear()
        } catch { }
    }
}

// MARK: - UIImage Resize

private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

#Preview {
    ProfileView()
        .environment(CurrentUserService.shared)
        .environment(NotificationService.shared)
        .environment(OnboardingService.shared)
}
