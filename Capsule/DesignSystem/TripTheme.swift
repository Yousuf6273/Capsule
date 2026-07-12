import SwiftUI

/// Two colors extracted from a vault's cover photo. Drives every trip-specific
/// gradient, accent, and button — the app shell keeps the default theme.
struct TripTheme: Equatable, Hashable, Codable {
    var primaryHex: String   // --t1
    var secondaryHex: String // --t2
    var isFallback: Bool = false

    var primary: Color { Color(hex: primaryHex) }
    var secondary: Color { Color(hex: secondaryHex) }

    static let `default` = TripTheme(primaryHex: "6B46E0", secondaryHex: "D9B26A", isFallback: true)

    /// Fallback pairs from the mockup's palette pool.
    static let fallbackPool: [TripTheme] = [
        TripTheme(primaryHex: "6B46E0", secondaryHex: "D9B26A", isFallback: true), // purple / gold
        TripTheme(primaryHex: "6B46E0", secondaryHex: "FF6F5E", isFallback: true), // purple / coral
        TripTheme(primaryHex: "D9B26A", secondaryHex: "201E25", isFallback: true), // gold / charcoal
        TripTheme(primaryHex: "2FA97A", secondaryHex: "6B46E0", isFallback: true), // emerald / purple
        TripTheme(primaryHex: "FF6F5E", secondaryHex: "F8F6F2", isFallback: true), // coral / white
    ]

    // ── Derived styles (mirrors the mockup's CSS recipes) ────────

    /// The `.btn-primary` gradient: linear 100deg t1 → t2.
    var primaryButtonGradient: LinearGradient {
        LinearGradient(colors: [primary, secondary],
                       startPoint: .leading, endPoint: .trailing)
    }

    /// The FAB gradient: 135deg t1 → t2.
    var fabGradient: LinearGradient {
        LinearGradient(colors: [primary, secondary],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// The rich full-screen mesh from `.phone` / `.recap-wrap`:
    /// deep saturated t1 falling into a t1/coral blend, never washed out with white.
    var meshColors: [Color] {
        [
            primary.mixed(with: .black, selfAmount: 0.92),
            primary,
            primary.mixed(with: .poolCoral, selfAmount: 0.55),
            Color.poolCoral.mixed(with: secondary, selfAmount: 0.88),
        ]
    }

    var meshGradient: LinearGradient {
        LinearGradient(colors: meshColors, startPoint: .top, endPoint: .bottom)
    }

    /// Light-bloom radial for the unlock sequence (`.door-light`).
    var doorLight: RadialGradient {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: primary.opacity(0.92), location: 0),
                .init(color: secondary.opacity(0.34), location: 0.4),
                .init(color: .clear, location: 0.7),
            ]),
            center: .center, startRadius: 0, endRadius: 420)
    }
}

// ── Environment plumbing ─────────────────────────────────────────

private struct TripThemeKey: EnvironmentKey {
    static let defaultValue: TripTheme = .default
}

extension EnvironmentValues {
    var tripTheme: TripTheme {
        get { self[TripThemeKey.self] }
        set { self[TripThemeKey.self] = newValue }
    }
}

extension View {
    func tripTheme(_ theme: TripTheme) -> some View {
        environment(\.tripTheme, theme)
    }
}

/// Full-bleed themed background with the two radial glows from the mockup body css.
struct ThemedMeshBackground: View {
    @Environment(\.tripTheme) private var theme

    var body: some View {
        ZStack {
            theme.meshGradient
            RadialGradient(colors: [theme.primary.opacity(0.55), .clear],
                           center: .init(x: 0.2, y: 0.0), startRadius: 0, endRadius: 380)
            RadialGradient(colors: [theme.secondary.opacity(0.35), .clear],
                           center: .init(x: 0.88, y: 0.18), startRadius: 0, endRadius: 340)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.2), value: theme)
    }
}
