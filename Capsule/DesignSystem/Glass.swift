import SwiftUI

// ── Glassmorphic building blocks (`.glass-card`, `.btn-glass`, `.icon-btn`) ──

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(Color.capsuleGlass, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.capsuleGlassBorder, lineWidth: 1.5)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 22) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

/// `.btn-primary` — themed gradient CTA.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.tripTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CapsuleFont.body(14, .bold))
            .foregroundStyle(Color.capsuleCream)
            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(theme.primaryButtonGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: theme.primary.opacity(0.55), radius: 14, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// `.btn-glass` — frosted secondary CTA.
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CapsuleFont.body(14, .bold))
            .foregroundStyle(Color.capsuleCream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassCard(cornerRadius: 18)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// `.icon-btn` — 36pt circular frosted icon button.
struct GlassIconButton: View {
    let systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.capsuleCream)
                .frame(width: 36, height: 36)
                .background(Color(hex: "0A0F1C").opacity(0.55), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.capsuleGlassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Gradient initial avatar (`.member-avatar` / `.avatar-dot`).
struct InitialAvatar: View {
    let initial: String
    var size: CGFloat = 32
    var gradient: LinearGradient

    init(initial: String, size: CGFloat = 32, colorIndex: Int = 0) {
        self.initial = initial
        self.size = size
        let pairs: [(Color, Color)] = [
            (.poolPurple, .poolGold),
            (.poolGold, .poolCoral),
            (.capsuleCream, .poolPurple),
            (.poolEmerald, .poolPurple),
            (.poolCoral, .poolGold),
            (.poolPurple, .poolEmerald),
        ]
        let pair = pairs[abs(colorIndex) % pairs.count]
        self.gradient = LinearGradient(colors: [pair.0, pair.1],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        Text(initial)
            .font(CapsuleFont.body(size * 0.4, .extraBold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            .frame(width: size, height: size)
            .background(gradient, in: Circle())
    }
}
