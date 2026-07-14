import SwiftUI

/// Screen 1 — the unseal moment. Dark, quiet, a softly breathing vault ring.
/// "Tap to Unseal" triggers golden light, a particle burst and heavy haptics
/// before flowing into the intro card.
struct UnsealView: View {
    @Environment(\.tripTheme) private var theme
    let vault: Vault
    var onUnsealed: () -> Void

    @State private var isUnsealing = false
    @State private var ringScale: CGFloat = 1
    @State private var lightBloom = false
    @State private var contentFade = false

    private var gold: Color { Color(hex: "F4D796") }
    private var deepGold: Color { Color(hex: "D9B26A") }

    var body: some View {
        ZStack {
            Color(hex: "0D0B10").ignoresSafeArea()

            // Faint themed ambience behind everything
            RadialGradient(colors: [theme.primary.opacity(0.16), .clear],
                           center: .center, startRadius: 0, endRadius: 420)
                .ignoresSafeArea()

            // Golden light flood on unseal
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: gold.opacity(0.95), location: 0),
                    .init(color: deepGold.opacity(0.45), location: 0.35),
                    .init(color: theme.primary.opacity(0.25), location: 0.6),
                    .init(color: .clear, location: 1),
                ]),
                center: .center, startRadius: 0, endRadius: 520)
            .opacity(lightBloom ? 1 : 0)
            .scaleEffect(lightBloom ? 1.3 : 0.6)
            .animation(.easeOut(duration: 1.1), value: lightBloom)
            .ignoresSafeArea()

            GoldenDust(active: isUnsealing, tint: gold)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                VaultRing(unsealing: isUnsealing, gold: deepGold, accent: theme.primary)
                    .frame(width: 190, height: 190)
                    .scaleEffect(ringScale)

                Text("Capsule")
                    .font(CapsuleFont.display(20, .bold))
                    .foregroundStyle(Color.capsuleCream.opacity(0.92))
                    .padding(.top, 44)

                Text("Your trip is ready.")
                    .font(CapsuleFont.body(15, .medium))
                    .foregroundStyle(Color.capsuleCream.opacity(0.6))
                    .padding(.top, 8)

                Spacer()

                Button(action: unseal) {
                    Text("Tap to Unseal")
                        .font(CapsuleFont.body(15, .bold))
                        .foregroundStyle(Color(hex: "17141C"))
                        .padding(.horizontal, 44)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(colors: [gold, deepGold],
                                           startPoint: .top, endPoint: .bottom),
                            in: Capsule())
                        .shadow(color: deepGold.opacity(0.45), radius: 22, y: 8)
                }
                .buttonStyle(.plain)
                .disabled(isUnsealing)
                .accessibilityIdentifier("unsealButton")
                .padding(.bottom, 70)
            }
            .opacity(contentFade ? 0 : 1)
            .animation(.easeIn(duration: 0.5), value: contentFade)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: isUnsealing)
        .sensoryFeedback(.success, trigger: lightBloom)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                ringScale = 1.04
            }
        }
    }

    private func unseal() {
        guard !isUnsealing else { return }
        isUnsealing = true
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            lightBloom = true
            try? await Task.sleep(for: .milliseconds(900))
            contentFade = true
            try? await Task.sleep(for: .milliseconds(500))
            onUnsealed()
        }
    }
}

/// The vault: concentric rings + tick marks; the dial spins free on unseal.
private struct VaultRing: View {
    let unsealing: Bool
    let gold: Color
    let accent: Color

    @State private var dialRotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 1.5)
                .padding(2)
            Circle()
                .stroke(
                    AngularGradient(colors: [gold.opacity(0.65), accent.opacity(0.25), gold.opacity(0.65)],
                                    center: .center),
                    lineWidth: 2.5)
                .padding(16)

            // Dial ticks
            ForEach(0..<24, id: \.self) { i in
                Capsule()
                    .fill(i % 6 == 0 ? gold.opacity(0.85) : Color.white.opacity(0.22))
                    .frame(width: 2, height: i % 6 == 0 ? 14 : 7)
                    .offset(y: -72)
                    .rotationEffect(.degrees(Double(i) * 15))
            }
            .rotationEffect(.degrees(dialRotation))

            Image(systemName: unsealing ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(gold)
                .contentTransition(.symbolEffect(.replace))
                .shadow(color: gold.opacity(0.6), radius: unsealing ? 18 : 6)
        }
        .onChange(of: unsealing) { _, opening in
            guard opening else { return }
            withAnimation(.easeInOut(duration: 1.3)) { dialRotation = 540 }
        }
    }
}

