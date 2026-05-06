//
//  User+AvatarColor.swift
//  Hasenwacht
//
//  Erzeugt eine deterministische Avatar-Farbe pro User aus der ID.
//  Gleiche ID = gleiche Farbe, ohne dass die Farbe gespeichert werden muss.
//
 
import SwiftUI
 
extension User {
    /// Stabile Farbe aus der User-ID (Hash-basiert).
    var avatarColor: Color {
        let palette: [Color] = [
            Color(red: 0.72, green: 0.35, blue: 0.24),  // Terrakotta
            Color(red: 0.24, green: 0.35, blue: 0.29),  // Tannengrün
            Color(red: 0.48, green: 0.24, blue: 0.32),  // Bordeaux
            Color(red: 0.17, green: 0.24, blue: 0.36),  // Marineblau
            Color(red: 0.66, green: 0.72, blue: 0.60),  // Salbei
            Color(red: 0.85, green: 0.79, blue: 0.66)   // Sand
        ]
        let userId = id ?? "default"
        let hash = abs(userId.hashValue)
        return palette[hash % palette.count]
    }
}
 


















