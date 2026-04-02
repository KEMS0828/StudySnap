import SwiftUI

extension UIColor {
    func toHex() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        if hex.count == 8 {
            let r = Double((rgbValue >> 24) & 0xFF) / 255.0
            let g = Double((rgbValue >> 16) & 0xFF) / 255.0
            let b = Double((rgbValue >> 8) & 0xFF) / 255.0
            let a = Double(rgbValue & 0xFF) / 255.0
            self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
        } else {
            let r = Double((rgbValue >> 16) & 0xFF) / 255.0
            let g = Double((rgbValue >> 8) & 0xFF) / 255.0
            let b = Double(rgbValue & 0xFF) / 255.0
            self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
        }
    }
}
