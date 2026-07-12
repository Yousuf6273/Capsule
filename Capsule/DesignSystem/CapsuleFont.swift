import SwiftUI

/// The three-font system from the mockup:
/// Unbounded → display/headlines, Inter → body/UI, JetBrains Mono → labels/countdowns.
enum CapsuleFont {

    enum DisplayWeight: String {
        case regular = "Unbounded-Regular"
        case semibold = "Unbounded-SemiBold"
        case bold = "Unbounded-Bold"
        case extraBold = "Unbounded-ExtraBold"
        case black = "Unbounded-Black"
    }

    enum BodyWeight: String {
        case regular = "Inter-Regular"
        case medium = "Inter-Medium"
        case semibold = "Inter-SemiBold"
        case bold = "Inter-Bold"
        case extraBold = "Inter-ExtraBold"
    }

    enum MonoWeight: String {
        case medium = "JetBrainsMono-Medium"
        case semibold = "JetBrainsMono-SemiBold"
        case bold = "JetBrainsMono-Bold"
    }

    static func display(_ size: CGFloat, _ weight: DisplayWeight = .bold) -> Font {
        .custom(weight.rawValue, size: size)
    }

    static func body(_ size: CGFloat, _ weight: BodyWeight = .regular) -> Font {
        .custom(weight.rawValue, size: size)
    }

    static func mono(_ size: CGFloat, _ weight: MonoWeight = .semibold) -> Font {
        .custom(weight.rawValue, size: size)
    }
}

/// Uppercase, letter-spaced mono label — the `.field-label` / eyebrow style.
struct MonoLabelStyle: ViewModifier {
    var size: CGFloat = 10
    var color: Color = .capsuleCream
    var tracking: CGFloat = 1.4

    func body(content: Content) -> some View {
        content
            .font(CapsuleFont.mono(size, .semibold))
            .textCase(.uppercase)
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

extension View {
    func monoLabel(size: CGFloat = 10, color: Color = .capsuleCream, tracking: CGFloat = 1.4) -> some View {
        modifier(MonoLabelStyle(size: size, color: color, tracking: tracking))
    }
}
