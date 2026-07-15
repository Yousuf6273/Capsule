import SwiftUI

/// The "it's time" moment — a warm burst of light and particles that fires
/// once, the instant a countdown reaches zero. Distinct from `GoldenDust`
/// (ambient) and the unseal screen's own bloom (deliberate, tap-triggered):
/// this one is involuntary, celebratory, and over in about a second.
struct FireworksBurst: View {
    var onFinished: () -> Void = {}

    @State private var flash = false
    @State private var particlesVisible = false

    private let palette: [Color] = [
        Color(hex: "F4D796"), Color(hex: "D9B26A"),
        Color.poolCoral, Color.poolPurple, Color.capsuleCream,
    ]

    var body: some View {
        ZStack {
            // Bright flash from the center
            RadialGradient(
                colors: [Color(hex: "F4D796").opacity(flash ? 0.9 : 0), .clear],
                center: .center, startRadius: 0, endRadius: flash ? 480 : 40)
            .animation(.easeOut(duration: 0.5), value: flash)

            BurstParticles(active: particlesVisible, palette: palette)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .heavy), trigger: flash)
        .onAppear {
            flash = true
            withAnimation(.easeOut(duration: 0.1)) { particlesVisible = true }
            Task {
                try? await Task.sleep(for: .milliseconds(1100))
                onFinished()
            }
        }
    }
}

/// Radiating burst of colored particles with gravity and fade-out.
private struct BurstParticles: View {
    let active: Bool
    let palette: [Color]

    private struct Spark {
        let angle: Double, speed: Double, size: Double, colorIndex: Int, delay: Double
    }

    private let sparks: [Spark] = {
        var rng = SeededRandom(seed: "fireworks-burst")
        return (0..<46).map { i in
            Spark(angle: rng.next() * 2 * .pi,
                  speed: 220 + rng.next() * 340,
                  size: 3 + rng.next() * 5,
                  colorIndex: i % 5,
                  delay: rng.next() * 0.08)
        }
    }()

    @State private var startDate = Date.now

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { context in
            Canvas { canvas, size in
                guard active else { return }
                let elapsed = max(0, context.date.timeIntervalSince(startDate))
                let center = CGPoint(x: size.width / 2, y: size.height * 0.42)

                for spark in sparks {
                    let local = max(0, elapsed - spark.delay)
                    guard local < 1.0 else { continue }
                    let dx = cos(spark.angle) * spark.speed * local
                    let dy = sin(spark.angle) * spark.speed * local + 260 * local * local // gravity
                    let alpha = max(0, 1 - local * 1.15)
                    let rect = CGRect(x: center.x + dx - spark.size / 2,
                                      y: center.y + dy - spark.size / 2,
                                      width: spark.size, height: spark.size)
                    canvas.fill(Ellipse().path(in: rect),
                                with: .color(palette[spark.colorIndex].opacity(alpha)))
                }
            }
        }
    }
}
