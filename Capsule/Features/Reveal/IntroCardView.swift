import SwiftUI

/// Screen 2 — full-bleed blurred hero with a glass title card:
/// destination, dates, friends, memory count, one emotional line,
/// and a breathing "Swipe to Begin" cue.
struct IntroCardView: View {
    @Environment(\.tripTheme) private var theme
    let vault: Vault
    let stats: RecapStats
    var onBegin: () -> Void

    @State private var appeared = false
    @State private var cueBounce = false

    private var emotionalLine: String {
        let weeks = stats.dayCount >= 6 ? "One week." : "\(stats.dayCount) days."
        return "\(weeks) Hundreds of moments. One unforgettable trip."
    }

    var body: some View {
        ZStack {
            CoverArt(vault: vault)
                .ignoresSafeArea()
                .blur(radius: 42)
                .saturation(1.1)
                .overlay(Color(hex: "0D0B10").opacity(0.45).ignoresSafeArea())

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 0) {
                    Text("THE VAULT IS OPEN")
                        .monoLabel(size: 10.5, color: Color(hex: "F4D796"), tracking: 2.4)

                    Text(vault.name.uppercased())
                        .font(CapsuleFont.display(40, .black))
                        .foregroundStyle(Color.capsuleCream)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .padding(.top, 14)

                    Text(stats.dateRange)
                        .font(CapsuleFont.mono(12, .semibold))
                        .foregroundStyle(Color.capsuleCream.opacity(0.75))
                        .tracking(1.5)
                        .padding(.top, 10)

                    HStack(spacing: 22) {
                        introMetric("\(stats.friendCount)", "friends")
                        introMetric("\(stats.totalMemories)", "memories")
                        introMetric("\(stats.dayCount)", "days")
                    }
                    .padding(.top, 26)

                    Text(emotionalLine)
                        .font(CapsuleFont.body(14.5, .medium))
                        .foregroundStyle(Color.capsuleCream.opacity(0.72))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 26)
                }
                .padding(30)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 32)
                .padding(.horizontal, 22)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 28)

                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 15, weight: .semibold))
                        .offset(y: cueBounce ? -5 : 3)
                    Text("Swipe to Begin")
                        .monoLabel(size: 10, color: .capsuleCream.opacity(0.55), tracking: 1.8)
                }
                .foregroundStyle(Color.capsuleCream.opacity(0.6))
                .padding(.bottom, 46)
                .opacity(appeared ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onBegin() }
        .gesture(
            DragGesture(minimumDistance: 25).onEnded { value in
                if value.translation.height < 0 || value.translation.width < 0 { onBegin() }
            }
        )
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.2).delay(0.2)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                cueBounce = true
            }
        }
    }

    private func introMetric(_ number: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(number)
                .font(CapsuleFont.display(26, .extraBold))
                .foregroundStyle(Color(hex: "F4D796"))
            Text(label)
                .monoLabel(size: 9.5, color: .capsuleCream.opacity(0.6), tracking: 1.2)
        }
    }
}
