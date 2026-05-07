//
//  ProfileView.swift
//  Hasenwacht
//
//  Profil-Screen mit inline Edit Mode.
//  Kein Sheet — alles auf einer Seite, Bearbeitung direkt in der View.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {

    @Environment(CurrentUserService.self) private var currentUserService
    @Environment(NotificationService.self) private var notificationService

    // MARK: - Edit State

    @State private var isEditing = false
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var canCook = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImage: UIImage?
    @State private var isSaving = false
    @State private var saveError: String?

    // MARK: - Other State

    @State private var showLogoutConfirmation = false

    private var user: User? { currentUserService.currentUser }

    private var hasChanges: Bool {
        firstName != (user?.firstName ?? "") ||
        lastName  != (user?.lastName  ?? "") ||
        canCook   != (user?.canCook   ?? false) ||
        pendingImage != nil
    }

    // MARK: - Body

    var body: some View {
        @Bindable var notifications = notificationService

        NavigationStack {
            ZStack {
                DS.Colors.surface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        avatarSection
                        if isEditing { nameEditSection }
                        settingsSection(notifications: $notifications.remindersEnabled,
                                        notificationService: notificationService)
                        if isEditing { saveError.map { errorBanner($0) } }
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
                Button("Abbrechen") {
                    withAnimation { cancelEdit() }
                }
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
            } else {
                Button {
                    withAnimation { startEdit() }
                } label: {
                    Text("Bearbeiten")
                        .font(.system(size: 15))
                        .foregroundStyle(DS.Colors.primary)
                }
            }
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        VStack(spacing: 12) {
            // Avatar — im Edit-Mode tappbar
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let img = pendingImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    } else if let user {
                        UserAvatarView(user: user, size: 96,
                                       borderColor: DS.Colors.border, borderWidth: 1)
                    } else {
                        Circle()
                            .fill(DS.Colors.surfaceAlt)
                            .frame(width: 96, height: 96)
                    }
                }
                .shadow(color: Color.black.opacity(0.10), radius: 8, y: 3)

                if isEditing {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack {
                            Circle()
                                .fill(DS.Colors.primary)
                                .frame(width: 30, height: 30)
                                .shadow(color: DS.Colors.primary.opacity(0.4), radius: 4, y: 2)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.white)
                        }
                    }
                    .offset(x: 4, y: 4)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.top, 16)

            // Name
            VStack(spacing: 3) {
                Text(user?.fullName ?? "Unbekannt")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DS.Colors.textPrimary)

                if isEditing {
                    Text("Tippe unten um Name zu ändern")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .transition(.opacity)
                } else {
                    // Foto-Hint im normalen Modus
                    if let user, user.photoBase64 == nil {
                        Text("Kein Profilfoto gesetzt")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Name Edit Section (nur im Edit Mode)

    private var nameEditSection: some View {
        VStack(spacing: 12) {
            // Name-Felder
            VStack(spacing: 0) {
                sectionHeader(icon: "person.fill", title: "Name", color: DS.Colors.primary)

                HStack(spacing: 12) {
                    Text("Vorname")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(width: 68, alignment: .leading)
                    TextField("Vorname", text: $firstName)
                        .font(.system(size: 15))
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(DS.Colors.background)

                Divider().background(DS.Colors.border).padding(.leading, 16)

                HStack(spacing: 12) {
                    Text("Nachname")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(width: 68, alignment: .leading)
                    TextField("Nachname", text: $lastName)
                        .font(.system(size: 15))
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(DS.Colors.background)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)

            // Kochen-Einstellung
            VStack(spacing: 0) {
                sectionHeader(icon: "frying.pan", title: "Kochplan", color: Color.cookingPurple)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ich koche mit")
                            .font(.system(size: 15))
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text("Aktiviert den Kochen-Tab in der App")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: $canCook).labelsHidden()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(DS.Colors.background)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Settings Section (immer sichtbar)

    private func settingsSection(notifications: Binding<Bool>,
                                 notificationService: NotificationService) -> some View {
        VStack(spacing: 12) {
            // Benachrichtigungen
            VStack(spacing: 0) {
                sectionHeader(icon: "bell.fill", title: "Benachrichtigungen", color: .orange)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reminder am Vorabend")
                            .font(.system(size: 15))
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text("Täglich um 19:00 Uhr (ausser Feiertage)")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: notifications)
                        .labelsHidden()
                        .disabled(notificationService.authorizationStatus != .authorized)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(DS.Colors.background)

                if notificationService.authorizationStatus == .denied {
                    permissionBanner(notificationService: notificationService)
                } else if notificationService.authorizationStatus == .notDetermined {
                    permissionRequest(notificationService: notificationService)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)

            // Account / Logout
            VStack(spacing: 0) {
                sectionHeader(icon: "gearshape.fill", title: "Account", color: DS.Colors.textSecondary)

                Button(role: .destructive) {
                    showLogoutConfirmation = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.Colors.danger)
                        Text("Abmelden")
                            .font(.system(size: 15))
                            .foregroundStyle(DS.Colors.danger)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(DS.Colors.background)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
        }
    }

    // MARK: - Sub-Views

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DS.Colors.background)
        .overlay(Divider().background(DS.Colors.border), alignment: .bottom)
    }

    private func permissionBanner(notificationService: NotificationService) -> some View {
        Divider().background(DS.Colors.border).overlay(
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Colors.warning)
                Text("Benachrichtigungen in iOS-Einstellungen deaktiviert.")
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Colors.textSecondary)
                Spacer()
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Öffnen")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.Colors.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DS.Colors.warningSurface)
        )
    }

    private func permissionRequest(notificationService: NotificationService) -> some View {
        Divider().background(DS.Colors.border).overlay(
            Button {
                Task { await notificationService.requestAuthorization() }
            } label: {
                HStack {
                    Text("Benachrichtigungen aktivieren")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Colors.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(DS.Colors.background)
            }
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(DS.Colors.danger)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(DS.Colors.danger)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Colors.dangerSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Colors.danger.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Edit Mode Logik

    private func startEdit() {
        firstName = user?.firstName ?? ""
        lastName  = user?.lastName  ?? ""
        canCook   = user?.canCook   ?? false
        pendingImage = nil
        saveError = nil
        isEditing = true
    }

    private func cancelEdit() {
        isEditing = false
        pendingImage = nil
        selectedPhoto = nil
        saveError = nil
    }

    private func save() async {
        let first = firstName.trimmingCharacters(in: .whitespaces)
        let last  = lastName.trimmingCharacters(in: .whitespaces)
        guard !first.isEmpty, !last.isEmpty else {
            saveError = "Vor- und Nachname dürfen nicht leer sein."
            return
        }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let base64: String?
        if let img = pendingImage,
           let jpeg = img.jpegData(compressionQuality: 0.70) {
            base64 = jpeg.base64EncodedString()
        } else {
            base64 = nil
        }

        do {
            try await currentUserService.updateProfile(
                firstName: first,
                lastName: last,
                photoBase64: base64,
                canCook: canCook
            )
            withAnimation { isEditing = false }
            pendingImage = nil
            selectedPhoto = nil
        } catch {
            saveError = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
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
        } catch {
            // Fehler hier ignorieren — User wird sowieso ausgeloggt
        }
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
}
