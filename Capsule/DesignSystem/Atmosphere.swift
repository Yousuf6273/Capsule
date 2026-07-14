import SwiftUI

// ── The app-wide atmosphere: deep charcoal, warm glows, drifting dust ──
// The shell never shouts; it frames. Trip screens layer their own theme
// glow on top of the same charcoal base.

/// The base canvas for every non-replay screen: deep charcoal with a rich
/// purple breath at the top, champagne gold warmth low, a whisper of coral.
struct ShellBackground: View {
    @Environment(\.tripTheme) private var theme
    var showDust: Bool = true

    var body: some View {
        ZStack {
            Color(hex: "121016").ignoresSafeArea()

            RadialGradient(colors: [Color.poolPurple.opacity(0.32), .clear],
                           center: .init(x: 0.2, y: -0.05), startRadius: 0, endRadius: 500)
            RadialGradient(colors: [Color(hex: "D9B26A").opacity(0.13), .clear],
                           center: .init(x: 0.9, y: 0.95), startRadius: 0, endRadius: 500)
            RadialGradient(colors: [Color.poolCoral.opacity(0.10), .clear],
                           center: .init(x: 0.05, y: 0.85), startRadius: 0, endRadius: 400)

            if showDust {
                GoldenDust(count: 22, baseOpacity: 0.35)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

/// Slow-drifting golden dust. Density and brightness tune per context —
/// barely-there ambience in the shell, a burst during the unseal.
struct GoldenDust: View {
    var active: Bool = false
    var tint: Color = Color(hex: "F4D796")
    var count: Int = 38
    var baseOpacity: Double = 1

    private struct Particle {
        let x: Double, size: Double, speed: Double, phase: Double, alpha: Double
    }

    private var particles: [Particle] {
        var rng = SeededRandom(seed: "golden-dust-\(count)")
        return (0..<count).map { _ in
            Particle(x: rng.next(), size: 1.5 + rng.next() * 3,
                     speed: 0.35 + rng.next() * 0.8,
                     phase: rng.next(), alpha: 0.25 + rng.next() * 0.5)
        }
    }

    var body: some View {
        let particles = self.particles
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            Canvas { canvas, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let boost: Double = active ? 5 : 1
                for p in particles {
                    let progress = ((t * p.speed * boost / 14) + p.phase).truncatingRemainder(dividingBy: 1)
                    let y = size.height * (1.05 - progress * 1.1)
                    let wobble = sin(t * 0.8 + p.phase * 6.28) * 14
                    let rect = CGRect(x: p.x * size.width + wobble, y: y,
                                      width: p.size, height: p.size)
                    canvas.fill(Ellipse().path(in: rect),
                                with: .color(tint.opacity(p.alpha * baseOpacity * (active ? 1 : 0.55))))
                }
            }
        }
    }
}

// ── Motion vocabulary ────────────────────────────────────────────

/// Cards float gently into place, staggered by `delay`.
struct FloatIn: ViewModifier {
    var delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 26)
            .scaleEffect(shown ? 1 : 0.985)
            .onAppear {
                withAnimation(.spring(duration: 0.85, bounce: 0.22).delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    func floatIn(delay: Double = 0) -> some View {
        modifier(FloatIn(delay: delay))
    }
}

/// Soft spring press response for any tappable card.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? 0.04 : 0)
            .animation(.spring(duration: 0.35, bounce: 0.4), value: configuration.isPressed)
    }
}

/// The champagne CTA from the unseal moment — the app's signature button.
struct GoldButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CapsuleFont.body(15, .bold))
            .foregroundStyle(Color(hex: "17141C"))
            .padding(.horizontal, 24)
            .padding(.vertical, 17)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [Color(hex: "F4D796"), Color(hex: "D9B26A")],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: Color(hex: "D9B26A").opacity(0.4), radius: 20, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.35), value: configuration.isPressed)
    }
}
