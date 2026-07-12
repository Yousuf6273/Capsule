import SwiftUI

/// Pre-reveal recap teaser — 5 fast, auto-advancing full-screen stat cards
/// (Spotify-Wrapped pacing: ~2.2s each, crossfade+slide, tap to skip ahead,
/// swipe/tap-left to go back). Plays after the doors, before any photos.
struct RecapTeaserView: View {
    @Environment(\.tripTheme) private var theme
    let stats: RecapStats
    var onFinished: () -> Void

    @State private var index = 0
    @State private var cardVisible = false
    @State private var timerTask: Task<Void, Never>?

    private struct TeaserCard: Identifiable {
        let id = UUID()
        let eyebrow: String
        let big: String
        let sub: String
        let emoji: String
    }

    private var cards: [TeaserCard] {
        var c: [TeaserCard] = [
            .init(eyebrow: "While you weren't looking",
                  big: "\(stats.totalMemories)",
                  sub: "memories were sealed in this vault", emoji: "🔒"),
            .init(eyebrow: "The trip",
                  big: "\(stats.dayCount) days",
                  sub: stats.dateRange.capitalized, emoji: "🗓"),
        ]
        if let top = stats.topContributor {
            c.append(.init(eyebrow: "Someone couldn't stop",
                           big: top.name,
                           sub: "added the most — \(top.count) drops", emoji: "📸"))
        }
        c.append(.init(eyebrow: "The big day",
                       big: stats.busiestDayLabel,
                       sub: "\(stats.busiestDayCount) memories in one day", emoji: "🎉"))
        c.append(.init(eyebrow: "Up before the sun",
                       big: stats.earliestUploadLabel,
                       sub: "the trip's earliest capture", emoji: "🌅"))
        return c
    }

    var body: some View {
        let cards = self.cards
        ZStack {
            ThemedMeshBackground()

            // Story-style progress bars
            VStack {
                HStack(spacing: 5) {
                    ForEach(0..<cards.count, id: \.self) { i in
                        Capsule()
                            .fill(Color.white.opacity(i <= index ? 0.95 : 0.25))
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                Spacer()
            }

            // Current card
            if index < cards.count {
                let card = cards[index]
                VStack(spacing: 14) {
                    Text(card.emoji)
                        .font(.system(size: 52))
                    Text(card.eyebrow)
                        .monoLabel(size: 11, color: .white.opacity(0.75), tracking: 2)
                    Text(card.big)
                        .font(CapsuleFont.display(card.big.count > 8 ? 34 : 64, .black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.22), radius: 13, y: 4)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 24)
                    Text(card.sub)
                        .font(CapsuleFont.body(15, .bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .id(card.id)
                .opacity(cardVisible ? 1 : 0)
                .offset(y: cardVisible ? 0 : 26)
                .scaleEffect(cardVisible ? 1 : 0.96)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            // Instagram-story semantics: left fifth = back, rest = forward.
            if location.x < UIScreen.main.bounds.width * 0.2 {
                step(-1)
            } else {
                step(1)
            }
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

    private func showCard() {
        timerTask?.cancel()
        cardVisible = false
        withAnimation(.spring(duration: 0.55)) { cardVisible = true }
        timerTask = Task {
            try? await Task.sleep(for: .milliseconds(2200))
            guard !Task.isCancelled else { return }
            step(1)
        }
    }

    private func step(_ delta: Int) {
        timerTask?.cancel()
        let next = index + delta
        if next >= cards.count {
            onFinished()
        } else if next >= 0 {
            withAnimation(.easeIn(duration: 0.18)) { cardVisible = false }
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                index = next
                showCard()
            }
        }
    }
}
