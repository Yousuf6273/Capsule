import AVKit
import SwiftUI

/// Screen 4 — the journey. Chronological replay: cinematic chapter cards
/// (Arrival → Day Two → Sunset → Goodbye) between ken-burns highlight
/// photos with contributor + caption. Tap right/left to move.
struct JourneyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tripTheme) private var theme
    let vault: Vault
    let items: [ReplayItem]
    var onFinished: () -> Void

    @State private var index = 0
    @State private var visible = false
    @State private var developed = false
    @State private var kenBurns = false
    @State private var timerTask: Task<Void, Never>?

    private let gold = Color(hex: "F4D796")

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "0D0B10").ignoresSafeArea()

            if index < items.count {
                switch items[index] {
                case .chapter(let title, let subtitle):
                    chapterCard(title: title, subtitle: subtitle)
                case .photo(let memory):
                    photoSlide(memory)
                }
            }

            // Minimal progress ticks
            VStack {
                HStack(spacing: 3) {
                    ForEach(0..<items.count, id: \.self) { i in
                        Capsule()
                            .fill(i <= index ? gold.opacity(0.8) : Color.white.opacity(0.12))
                            .frame(height: 2.5)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { location in
            if location.x < UIScreen.main.bounds.width * 0.22 { step(-1) } else { step(1) }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: index)
        .onAppear { play() }
        .onDisappear { timerTask?.cancel() }
    }

    // ── Chapter interstitial ─────────────────────────────────────

    private func chapterCard(title: String, subtitle: String) -> some View {
        ZStack {
            RadialGradient(colors: [Color(hex: "D9B26A").opacity(0.16),
                                    theme.primary.opacity(0.08), .clear],
                           center: .center, startRadius: 0, endRadius: 420)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, gold, .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 90, height: 1.5)

                Text(title)
                    .font(CapsuleFont.display(38, .black))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.capsuleCream, gold],
                                       startPoint: .top, endPoint: .bottom))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 30)

                Text(subtitle.uppercased())
                    .monoLabel(size: 10.5, color: .capsuleCream.opacity(0.55), tracking: 2.4)

                Rectangle()
                    .fill(LinearGradient(colors: [.clear, gold, .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 90, height: 1.5)
            }
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.94)
        }
    }

    // ── Photo slide ──────────────────────────────────────────────

    private func photoSlide(_ memory: Memory) -> some View {
        ZStack(alignment: .bottom) {
            if let videoURL = model.memoryStore.videoURL(for: memory) {
                LoopingVideoSlide(url: videoURL)
                    .saturation(developed ? 1.0 : 0.4)
                    .brightness(developed ? 0 : -0.2)
                    .ignoresSafeArea()
            } else if let image = model.memoryStore.image(for: memory) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(kenBurns ? 1.0 : 1.08)
                    .saturation(developed ? 1.05 : 0.4)
                    .brightness(developed ? 0 : -0.2)
                    .ignoresSafeArea()
                    .clipped()
            }

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.4),
                    .init(color: Color(hex: "0D0B10").opacity(0.92), location: 1),
                ],
                startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 7) {
                Text(contributorName(memory).uppercased())
                    .monoLabel(size: 10.5, color: gold, tracking: 1.6)
                if let caption = memory.caption {
                    Text("\u{201C}\(caption)\u{201D}")
                        .font(CapsuleFont.display(17, .semibold))
                        .foregroundStyle(Color.capsuleCream)
                        .lineSpacing(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(visible ? 1 : 0)
        }
    }

    private func contributorName(_ memory: Memory) -> String {
        if memory.uploaderId == model.profile?.id || memory.uploaderId == "CURRENT_USER" { return "You" }
        return vault.members.first { $0.id == memory.uploaderId }?.displayName
            ?? memory.uploaderId.replacingOccurrences(of: "friend-", with: "").capitalized
    }

    // ── Sequencing ───────────────────────────────────────────────

    private var currentDuration: Double {
        switch items[index] {
        case .chapter:
            return 2.4
        case .photo(let memory):
            if memory.mediaType == .video,
               let url = model.memoryStore.videoURL(for: memory) {
                return MediaPoster.slideDuration(of: url) // full video, up to 30s
            }
            return 4.0
        }
    }

    private func play() {
        guard index < items.count else { return }
        timerTask?.cancel()
        visible = false
        developed = false
        kenBurns = false
        withAnimation(.easeOut(duration: 0.7)) { visible = true }
        if case .photo = items[index] {
            withAnimation(.easeInOut(duration: 1.2)) { developed = true }
            withAnimation(.easeInOut(duration: currentDuration)) { kenBurns = true }
        }
        timerTask = Task {
            try? await Task.sleep(for: .seconds(currentDuration))
            guard !Task.isCancelled else { return }
            step(1)
        }
    }

    private func step(_ delta: Int) {
        timerTask?.cancel()
        let next = index + delta
        if next >= items.count {
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                onFinished()
            }
        } else if next >= 0 {
            withAnimation(.easeIn(duration: 0.25)) { visible = false }
            Task {
                try? await Task.sleep(for: .milliseconds(260))
                index = next
                play()
            }
        }
    }
}

/// Full-bleed video for a journey slide, WITH sound — these are the moments
/// everyone sealed away; they play in full (looping only if the slide
/// outlasts a very short clip).
struct LoopingVideoSlide: View {
    let url: URL
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        GeometryReader { geo in
            if let player {
                VideoPlayer(player: player)
                    .disabled(true) // no scrubber during the ceremony
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                Color.black
            }
        }
        .onAppear {
            PlaybackAudio.activate()
            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer(playerItem: item)
            queue.isMuted = false
            looper = AVPlayerLooper(player: queue, templateItem: item)
            queue.play()
            player = queue
        }
        .onDisappear {
            player?.pause()
            looper = nil
            player = nil
        }
    }
}

/// Audio session for memory playback — `.playback` so video sound comes
/// through even when the phone's silent switch is on (the default ambient
/// category silently mutes, which reads as "videos have no audio").
enum PlaybackAudio {
    static func activate() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
