//
//  ChildrenProfileSection.swift
//  Hasenwacht
//
//  Sektion im Profil-Tab zum Verwalten eigener Kinder.
//  Wird in ProfileView eingebunden.
//

import SwiftUI

// MARK: - Children Profile Section

struct ChildrenProfileSection: View {

    @ObservedObject var viewModel: ChildrenViewModel
    let currentUserId: String
    let allUsers: [User]

    @State private var editingChild: Child? = nil
    @State private var showAddSheet = false
    @State private var deleteCandidate: Child? = nil

    private var myChildren: [Child] {
        viewModel.children(forUserId: currentUserId)
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "figure.2.and.child.holdinghands")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                Text("Kinder")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Hinzufügen")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(DS.Colors.primary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(DS.Colors.primarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(DS.Colors.background)
            .overlay(Divider().background(DS.Colors.border), alignment: .bottom)

            if myChildren.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text("Du kannst Kinder erfassen die mitessen.")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(DS.Colors.background)
            } else {
                ForEach(Array(myChildren.enumerated()), id: \.element.id) { index, child in
                    childRow(child)
                    if index < myChildren.count - 1 {
                        Divider().background(DS.Colors.border).padding(.leading, 16)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
        .sheet(isPresented: $showAddSheet) {
            ChildEditSheet(
                child: nil,
                currentUserId: currentUserId,
                allUsers: allUsers
            )
        }
        .sheet(item: $editingChild) { child in
            ChildEditSheet(
                child: child,
                currentUserId: currentUserId,
                allUsers: allUsers
            )
        }
        .confirmationDialog(
            "Kind löschen?",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                if let child = deleteCandidate, let id = child.id {
                    Task { try? await ChildService.shared.deleteChild(id: id) }
                }
                deleteCandidate = nil
            }
            Button("Abbrechen", role: .cancel) { deleteCandidate = nil }
        } message: {
            Text("\(deleteCandidate?.name ?? "Das Kind") und alle Anmeldungen werden entfernt.")
        }
    }

    private func childRow(_ child: Child) -> some View {
        let isPrimary = child.primaryParentId == currentUserId
        let otherParentNames = child.allParentIds
            .filter { $0 != currentUserId }
            .compactMap { id in allUsers.first { $0.id == id }?.firstName }

        return Button {
            editingChild = child
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(DS.Colors.primarySurface)
                        .frame(width: 36, height: 36)
                    Text(String(child.name.prefix(1)).uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.Colors.primaryDark)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(child.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)

                    HStack(spacing: 4) {
                        if isPrimary {
                            Text("Hauptbetreuer:in")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Colors.primary)
                        } else {
                            Text("Ergänzend")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                        if !otherParentNames.isEmpty {
                            Text("• mit \(otherParentNames.joined(separator: ", "))")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Colors.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                if isPrimary {
                    Button {
                        deleteCandidate = child
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Colors.textTertiary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(DS.Colors.background)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Child Edit Sheet

struct ChildEditSheet: View {

    let child: Child?
    let currentUserId: String
    let allUsers: [User]

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var primaryParentId: String = ""
    @State private var secondaryParentIds: Set<String> = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isEditing: Bool { child != nil }
    private var isPrimaryParent: Bool {
        guard let child else { return true }
        return child.primaryParentId == currentUserId
    }

    private var availableParents: [User] {
        allUsers.filter { $0.id != currentUserId && $0.id != nil }
            .sorted { $0.firstName < $1.firstName }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.surface.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 12) {
                        // Name
                        VStack(spacing: 0) {
                            sectionHeader(icon: "person.fill", title: "Name")
                            HStack {
                                TextField("z.B. Lia", text: $name)
                                    .font(.system(size: 15))
                                    .foregroundStyle(DS.Colors.textPrimary)
                                    .tint(DS.Colors.primary)
                                    .autocorrectionDisabled()
                                    .disabled(!isPrimaryParent)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(DS.Colors.background)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))

                        // Hauptbetreuer Info
                        VStack(spacing: 0) {
                            sectionHeader(icon: "star.fill", title: "Hauptbetreuer:in")
                            HStack {
                                let primary = allUsers.first { $0.id == primaryParentId }
                                Text(primary?.fullName ?? "Du")
                                    .font(.system(size: 15))
                                    .foregroundStyle(DS.Colors.textPrimary)
                                Spacer()
                                Text("nimmt das Kind standardmässig mit")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(DS.Colors.background)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))

                        // Weitere Eltern
                        if isPrimaryParent {
                            VStack(spacing: 0) {
                                sectionHeader(icon: "person.2.fill", title: "Weitere Eltern")
                                if availableParents.isEmpty {
                                    HStack {
                                        Text("Keine weiteren User in der WG")
                                            .font(.system(size: 12))
                                            .foregroundStyle(DS.Colors.textTertiary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                    .background(DS.Colors.background)
                                } else {
                                    ForEach(Array(availableParents.enumerated()), id: \.element.id) { index, user in
                                        parentToggleRow(user: user)
                                        if index < availableParents.count - 1 {
                                            Divider().background(DS.Colors.border).padding(.leading, 16)
                                        }
                                    }
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 10))
                                        .foregroundStyle(DS.Colors.textTertiary)
                                    Text("Sie können das Kind an einzelnen Tagen übernehmen wenn du nicht da bist.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(DS.Colors.textTertiary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(DS.Colors.surfaceAlt)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(DS.Colors.danger)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 40)
                }
            }
            .navigationTitle(isEditing ? "Kind bearbeiten" : "Kind hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.Colors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(DS.Colors.primary)
                        } else {
                            Text("Sichern")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(canSave ? DS.Colors.primary : DS.Colors.textTertiary)
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { prefill() }
        }
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.Colors.primary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.Colors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(DS.Colors.background)
        .overlay(Divider().background(DS.Colors.border), alignment: .bottom)
    }

    private func parentToggleRow(user: User) -> some View {
        let userId = user.id ?? ""
        let isSelected = secondaryParentIds.contains(userId)

        return Button {
            if isSelected { secondaryParentIds.remove(userId) }
            else          { secondaryParentIds.insert(userId) }
        } label: {
            HStack(spacing: 12) {
                UserAvatarView(user: user, size: 32)
                Text(user.fullName)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? DS.Colors.primary : DS.Colors.textTertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(DS.Colors.background)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Logik

    private func prefill() {
        if let child {
            name = child.name
            primaryParentId = child.primaryParentId
            secondaryParentIds = Set(child.secondaryParentIds)
        } else {
            primaryParentId = currentUserId
        }
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Name darf nicht leer sein."
            return
        }
        isSaving = true; errorMessage = nil; defer { isSaving = false }

        do {
            if var existing = child {
                if isPrimaryParent {
                    existing.name = trimmedName
                    existing.secondaryParentIds = Array(secondaryParentIds)
                }
                try await ChildService.shared.updateChild(existing)
            } else {
                let newChild = Child(
                    name: trimmedName,
                    primaryParentId: currentUserId,
                    secondaryParentIds: Array(secondaryParentIds)
                )
                _ = try await ChildService.shared.addChild(newChild)
            }
            dismiss()
        } catch {
            errorMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
