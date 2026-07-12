import SwiftUI

extension Color {
    init(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    // ── Fixed tokens (the app shell never re-themes) ─────────────
    static let capsuleCharcoal = Color(hex: "18161C")
    static let capsuleCharcoal2 = Color(hex: "201E25")
    static let capsuleCharcoal3 = Color(hex: "151318")
    static let capsuleCream = Color(hex: "F8F6F2")
    static let capsuleDim = Color(hex: "F8F6F2").opacity(0.62)
    static let capsuleDim2 = Color(hex: "F8F6F2").opacity(0.40)
    static let capsuleGlass = Color.white.opacity(0.18)
    static let capsuleGlassBorder = Color.white.opacity(0.32)

    // ── Palette pool (theme-extraction fallback) ─────────────────
    static let poolPurple = Color(hex: "6B46E0")
    static let poolGold = Color(hex: "D9B26A")
    static let poolCoral = Color(hex: "FF6F5E")
    static let poolEmerald = Color(hex: "2FA97A")
}

extension Color {
    /// Approximation of CSS `color-mix(in srgb, self pct%, other)`.
    func mixed(with other: Color, selfAmount: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(selfAmount)
        return Color(.sRGB,
                     red: Double(r1 * t + r2 * (1 - t)),
                     green: Double(g1 * t + g2 * (1 - t)),
                     blue: Double(b1 * t + b2 * (1 - t)),
                     opacity: Double(a1 * t + a2 * (1 - t)))
    }
}
