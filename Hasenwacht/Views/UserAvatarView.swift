//
//  UserAvatarView.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 07.05.2026.
//
//  Wiederverwendbare Avatar-View.
//  Zeigt Profilfoto wenn vorhanden, sonst Initialen auf Avatar-Farbe.
//

import SwiftUI

struct UserAvatarView: View {

    let user: User
    var size: CGFloat = 36
    var borderColor: Color = .clear
    var borderWidth: CGFloat = 0

    var body: some View {
        ZStack {
            if let base64 = user.photoBase64,
               let imageData = Data(base64Encoded: base64),
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(user.avatarColor)
                Text(user.initials)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().stroke(borderColor, lineWidth: borderWidth)
        )
    }
}

// MARK: - Stack Variante (für Übersicht)

struct UserAvatarStack: View {
    let users: [User]
    var size: CGFloat = 16
    var borderColor: Color = .white
    var max: Int = 3

    var body: some View {
        HStack(spacing: -(size * 0.35)) {
            ForEach(Array(users.prefix(max))) { user in
                UserAvatarView(user: user, size: size, borderColor: borderColor, borderWidth: 1.5)
            }
        }
    }
}
