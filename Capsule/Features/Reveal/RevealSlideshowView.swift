import SwiftUI

/// The reveal: photos one at a time, chronological, contributor + caption,
/// darkroom "develop" effect + ken-burns motion, 5s auto-advance with
/// story progress bars. Tap right/left to skip/back.
struct RevealSlideshowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tripTheme) private var theme
    let vault: Vault
    let memories: [Memory]
    var onFinished: () -> Void

    @State private var index = 0
    @State private var developed = false
    @State private var kenBurns = false
    @State private var timerTask: Task<Void, Never>?

    private let slideDuration: Double = 5.0
    /// Cap the live show; the full set lives in the album afterwards.
    private var slides: [Memory] { Array(memories.prefix(30)) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "05070C").ignoresSafeArea()

            if index < slides.count {
                let memory = slides[index]

                // Photo with develop + ken-burns
                if let image = model.memoryStore.image(for: memory) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaleEffect(kenBurns ? 1.0 : 1.07)
                        .saturation(developed ? 1.05 : 0.35)
                        .brightness(developed ? 0 : -0.25)
                        .ignoresSafeArea()
                        .clipped()
                        .id(memory.id)
                        .transition(.opacity)
                }

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.35),
                        .init(color: Color(hex: "05070C").opacity(0.95), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

                // Contributor + caption
                VStack(alignment: .leading, spacing: 7) {
                    Text("\(contributorName(memory)) · Day \(model.memoryStore.dayIndex(of: memory, in: memories))")
                        .monoLabel(size: 10.5, color: theme.secondary, tracking: 1)
                    if let caption = memory.caption {
                        Text("\u{201C}\(caption)\u{201D}")
                            .font(CapsuleFont.display(17, .semibold))
                            .foregroundStyle(Color.capsuleCream)
                            .lineSpacing(4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.bottom, 34)
                .id("meta-\(memory.id)")
                .transition(.opacity)
            }

            // Progress bars
            VStack {
                HStack(spacing: 4) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.2))
                                if i < index {
                                    Capsule().fill(barGradient)
                                } else if i == index {
                                    ProgressBarFill(duration: slideDuration, gradient: barGradient)
                                        .id(index)
                                }
                            }
                        }
                        .frame(height: 3)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            if location.x < UIScreen.main.bounds.width * 0.2 { step(-1) } else { step(1) }
        }
        .animation(.easeInOut(duration: 0.9), value: index)
        .sensoryFeedback(.impact(weight: .light), trigger: index)
        .onAppear { playCurrent() }
        .onDisappear { timerTask?.cancel() }
    }

    private var barGradient: LinearGradient {
        LinearGradient(colors: [theme.primary, theme.secondary],
                       startPoint: .leading, endPoint: .trailing)
    }

    private func contributorName(_ memory: Memory) -> String {
        if memory.uploaderId == model.profile?.id || memory.uploaderId == "CURRENT_USER" { return "You" }
        return vault.members.first { $0.id == memory.uploaderId }?.displayName
            ?? memory.uploaderId.replacingOccurrences(of: "friend-", with: "").capitalized
    }

    private func playCurrent() {
        timerTask?.cancel()
        developed = false
        kenBurns = false
        withAnimation(.easeInOut(duration: 1.3)) { developed = true }
        withAnimation(.easeInOut(duration: slideDuration)) { kenBurns = true }
        timerTask = Task {
            try? await Task.sleep(for: .seconds(slideDuration))
            guard !Task.isCancelled else { return }
            step(1)
        }
    }

    private func step(_ delta: Int) {
        timerTask?.cancel()
        let next = index + delta
        if next >= slides.count {
            try? Task.checkCancellation()
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                onFinished()
            }
        } else if next >= 0 {
            index = next
            playCurrent()
        }
    }
}

/// A capsule that fills over `duration` — the `.reveal-dots .playing` bar.
private struct ProgressBarFill: View {
    let duration: Double
    let gradient: LinearGradient
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(gradient)
                .frame(width: geo.size.width * progress)
        }
        .onAppear {
            progress = 0
            withAnimation(.linear(duration: duration)) { progress = 1 }
        }
    }
}
