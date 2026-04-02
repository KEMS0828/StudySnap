import SwiftUI

struct SubjectColorStore {
    private static let storageKey = "subjectColors"

    static let availableColors: [(name: String, color: Color, hex: String)] = [
        ("レッド", Color(.systemRed), "red"),
        ("オレンジ", .orange, "orange"),
        ("イエロー", Color(red: 0.95, green: 0.8, blue: 0.0), "yellow"),
        ("グリーン", Color(red: 0.2, green: 0.78, blue: 0.35), "green"),
        ("ティール", Color(red: 0.0, green: 0.65, blue: 0.65), "teal"),
        ("ブルー", Color(red: 0.0, green: 0.48, blue: 1.0), "blue"),
        ("ネイビー", Color(red: 0.2, green: 0.25, blue: 0.6), "navy"),
        ("パープル", Color(red: 0.6, green: 0.3, blue: 0.85), "purple"),
        ("マゼンタ", Color(red: 0.85, green: 0.2, blue: 0.55), "magenta"),
        ("ピンク", Color(red: 1.0, green: 0.45, blue: 0.6), "pink"),
        ("ブラウン", Color(red: 0.55, green: 0.35, blue: 0.17), "brown"),
        ("グレー", Color(red: 0.5, green: 0.5, blue: 0.55), "gray"),
    ]

    static func save(subject: String, colorHex: String) {
        var dict = loadAll()
        dict[subject] = colorHex
        UserDefaults.standard.set(dict, forKey: storageKey)
    }

    static func remove(subject: String) {
        var dict = loadAll()
        dict.removeValue(forKey: subject)
        UserDefaults.standard.set(dict, forKey: storageKey)
    }

    static func colorHex(for subject: String) -> String? {
        loadAll()[subject]
    }

    static func color(for subject: String) -> Color? {
        guard let hex = colorHex(for: subject) else { return nil }
        return availableColors.first { $0.hex == hex }?.color
    }

    static func loadAll() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }
}
