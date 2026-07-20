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

    private var decodedImage: UIImage? {
        guard let base64 = user.photoBase64 else { return nil }
        return Self.imageCache.image(for: base64)
    }

    var body: some View {
        ZStack {
            if let uiImage = decodedImage {
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

    /// Dekodiert Base64 → UIImage nur einmal pro Foto und hält das Ergebnis vor.
    /// Ohne Cache würde jeder Re-Render (z.B. durch die häufigen Firestore-
    /// Listener-Updates in LunchDaysViewModel) für jeden sichtbaren Avatar
    /// erneut Base64- und JPEG-Decoding durchführen.
    private static let imageCache = AvatarImageCache()
}

private final class AvatarImageCache {
    private let cache = NSCache<NSString, UIImage>()

    func image(for base64: String) -> UIImage? {
        let key = base64 as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
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
