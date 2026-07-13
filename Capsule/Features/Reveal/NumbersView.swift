import SwiftUI

/// Screen 3 — "Trip by the Numbers". One oversized stat per screen,
/// numbers counting up, warm golden gradients on charcoal. The slides
/// were pre-selected for interestingness so this stays 15-25 seconds.
struct NumbersView: View {
    @Environment(\.tripTheme) private var theme
    let slides: [StatSlide]
    var onFinished: () -> Void

    @State private var index = 0
    @State private var cardVisible = false
    @State private var timerTask: Task<Void, Never>?

    private let gold = Color(hex: "F4D796")

    var body: some View {
        ZStack {
            Color(hex: "121016").ignoresSafeArea()

            // Warm ambient glow that drifts per slide
            RadialGradient(colors: [Color(hex: "D9B26A").opacity(0.14),
                                    theme.primary.opacity(0.10), .clear],
                           center: index % 2 == 0 ? .init(x: 0.25, y: 0.2) : .init(x: 0.78, y: 0.75),
                           startRadius: 0, endRadius: 480)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: index)

            // Story progress
            VStack {
                HStack(spacing: 5) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        Capsule()
                            .fill(i <= index ? gold.opacity(0.9) : Color.white.opacity(0.14))
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                Spacer()
            }

            if index < slides.count {
                let slide = slides[index]
                VStack(spacing: 0) {
                    Text(slide.emoji)
                        .font(.system(size: 46))
                        .padding(.bottom, 26)

                    Text(slide.eyebrow.uppercased())
                        .monoLabel(size: 11, color: gold.opacity(0.85), tracking: 2.6)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 18)

                    Group {
                        if let target = slide.countTo {
                            CountUpText(target: target, font: bigFont(for: slide.value))
                        } else {
                            Text(slide.value)
                                .font(bigFont(for: slide.value))
                        }
                    }
                    .foregroundStyle(
                        LinearGradient(colors: [Color.capsuleCream, gold],
                                       startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(hex: "D9B26A").opacity(0.35), radius: 24, y: 6)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
                    .lineLimit(2)
                    .padding(.horizontal, 28)

                    Text(slide.caption)
                        .font(CapsuleFont.body(15.5, .semibold))
                        .foregroundStyle(Color.capsuleCream.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 44)
                        .padding(.top, 22)
                }
                .id(slide.id)
                .opacity(cardVisible ? 1 : 0)
                .offset(y: cardVisible ? 0 : 30)
                .scaleEffect(cardVisible ? 1 : 0.95)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            if location.x < UIScreen.main.bounds.width * 0.22 { step(-1) } else { step(1) }
        }
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                step(value.translation.width > 0 ? -1 : 1)
            }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: index)
        .onAppear { showCard() }
        .onDisappear { timerTask?.cancel() }
    }

    private func bigFont(for value: String) -> Font {
        CapsuleFont.display(value.count > 9 ? 40 : 76, .black)
    }

    private func showCard() {
        timerTask?.cancel()
        cardVisible = false
        withAnimation(.spring(duration: 0.6, bounce: 0.18)) { cardVisible = true }
        timerTask = Task {
            try? await Task.sleep(for: .milliseconds(2800))
            guard !Task.isCancelled else { return }
            step(1)
        }
    }

    private func step(_ delta: Int) {
        timerTask?.cancel()
        let next = index + delta
        if next >= slides.count {
            onFinished()
        } else if next >= 0 {
            withAnimation(.easeIn(duration: 0.16)) { cardVisible = false }
            Task {
                try? await Task.sleep(for: .milliseconds(170))
                index = next
                showCard()
            }
        }
    }
}

/// Eased 0 → target count-up over ~0.9s.
struct CountUpText: View {
    let target: Int
    let font: Font

    @State private var start: Date = .now

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let elapsed = context.date.timeIntervalSince(start)
            let progress = min(1, elapsed / 0.9)
            let eased = 1 - pow(1 - progress, 3)   // ease-out cubic
            Text("\(Int(Double(target) * eased))")
                .font(font)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .onAppear { start = .now }
    }
}
