import SwiftUI

/// Full "Trip wrapped" deep-dive — vivid themed mesh, big number, crown rows,
/// stat tiles, and a shareable summary card rendered via ImageRenderer.
struct RecapWrappedView: View {
    @Environment(\.tripTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let vault: Vault
    let stats: RecapStats
    var onDone: () -> Void

    @State private var shareCard: UIImage?
    @State private var appeared = false

    var body: some View {
        ZStack {
            ThemedMeshBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    Text("Trip wrapped")
                        .monoLabel(size: 11, color: .black.opacity(0.72), tracking: 1.6)
                        .padding(.top, 24)
                    Text(vault.displayName)
                        .font(CapsuleFont.display(36, .black))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
                        .padding(.top, 10)
                    Text("\(stats.dateRange) · \(stats.friendCount) FRIENDS")
                        .font(CapsuleFont.mono(11.5, .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 4)

                    // Big stat
                    Text("\(stats.totalMemories)")
                        .font(CapsuleFont.display(88, .black))
                        .foregroundStyle(Color(hex: "FFF6C9"))
                        .shadow(color: .black.opacity(0.22), radius: 13, y: 4)
                        .padding(.top, 22)
                        .scaleEffect(appeared ? 1 : 0.8, anchor: .leading)
                        .opacity(appeared ? 1 : 0)
                    Text("memories, together")
                        .font(CapsuleFont.body(14.5, .bold))
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // Crown rows
                    if let top = stats.topContributor {
                        crownRow("📸", text: "Most memories added: ", bold: "\(top.name) — \(top.count) drops")
                    }
                    crownRow("🌅", text: "Earliest wake-up: ", bold: stats.earliestUploadLabel)
                    crownRow("🌙", text: "Latest one still up: ", bold: stats.latestUploadLabel)

                    // Tile grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                              spacing: 10) {
                        statTile(stats.gbLabel, "of pure chaos")
                        statTile("\(stats.dayCount)", "days of memories")
                        statTile(stats.busiestDayLabel, "busiest day — \(stats.busiestDayCount) drops")
                        statTile("\(stats.sealedDays)", "days sealed")
                    }
                    .padding(.top, 8)

                    // Leaderboard
                    if stats.leaderboard.count > 1 {
                        leaderboard.padding(.top, 12)
                    }

                    // Actions
                    VStack(spacing: 10) {
                        if let shareCard {
                            ShareLink(
                                item: Image(uiImage: shareCard),
                                preview: SharePreview("\(vault.name) — wrapped", image: Image(uiImage: shareCard))
                            ) {
                                Text("Share the wrapped card")
                                    .font(CapsuleFont.body(14, .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color(hex: "17141C"),
                                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                        }
                        Button("Back to the album") { onDone() }
                            .buttonStyle(GlassButtonStyle())
                    }
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 22)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.3).delay(0.15)) { appeared = true }
            renderShareCard()
        }
    }

    private func crownRow(_ emoji: String, text: String, bold: String) -> some View {
        HStack(spacing: 10) {
            Text(emoji).font(.system(size: 20))
            (Text(text).foregroundStyle(.white)
             + Text(bold).foregroundStyle(Color(hex: "FFF6C9")))
                .font(CapsuleFont.body(12.5, .bold))
                .lineSpacing(3)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .glassCard(cornerRadius: 16)
        .padding(.bottom, 10)
    }

    private func statTile(_ num: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(num)
                .font(CapsuleFont.display(22, .extraBold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(CapsuleFont.body(10.5, .bold))
                .foregroundStyle(.white.opacity(0.82))
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The leaderboard")
                .monoLabel(size: 10, color: .white.opacity(0.8), tracking: 1.4)
            VStack(spacing: 6) {
                ForEach(Array(stats.leaderboard.prefix(5).enumerated()), id: \.offset) { i, entry in
                    HStack(spacing: 10) {
                        Text(i == 0 ? "👑" : "\(i + 1)")
                            .font(CapsuleFont.display(12, .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 22)
                        Text(entry.name)
                            .font(CapsuleFont.body(13, .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        GeometryReader { geo in
                            Capsule()
                                .fill(Color(hex: "FFF6C9").opacity(i == 0 ? 0.95 : 0.45))
                                .frame(width: geo.size.width
                                       * (Double(entry.count) / Double(stats.leaderboard.first?.count ?? 1)),
                                       height: 6)
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(width: 90, height: 14)
                        Text("\(entry.count)")
                            .font(CapsuleFont.mono(12, .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, alignment: .trailing)
                    }
                }
            }
            .padding(14)
            .glassCard(cornerRadius: 18)
        }
    }

    // ── Shareable card (1080×1350, IG-portrait) ──────────────────

    private func renderShareCard() {
        let renderer = ImageRenderer(content: ShareCardView(vault: vault, stats: stats, theme: theme))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 360, height: 450)
        shareCard = renderer.uiImage
    }
}

/// The exported wrapped card — self-contained (no Environment) for ImageRenderer.
struct ShareCardView: View {
    let vault: Vault
    let stats: RecapStats
    let theme: TripTheme

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.meshColors, startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                Text("TRIP WRAPPED")
                    .font(CapsuleFont.mono(10, .bold))
                    .tracking(2)
                    .foregroundStyle(.black.opacity(0.7))
                Text(vault.displayName)
                    .font(CapsuleFont.display(30, .black))
                    .foregroundStyle(.white)
                    .padding(.top, 8)
                Text(stats.dateRange)
                    .font(CapsuleFont.mono(10.5, .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 3)

                Spacer()

                Text("\(stats.totalMemories)")
                    .font(CapsuleFont.display(84, .black))
                    .foregroundStyle(Color(hex: "FFF6C9"))
                Text("memories, together")
                    .font(CapsuleFont.body(14, .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 4)

                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let top = stats.topContributor {
                            Text("👑 \(top.name) · \(top.count) drops")
                                .font(CapsuleFont.body(11.5, .bold))
                                .foregroundStyle(.white)
                        }
                        Text("\(stats.friendCount) friends · \(stats.gbLabel) · \(stats.dayCount) days")
                            .font(CapsuleFont.body(10.5, .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer()
                    Text("🔒 capsule")
                        .font(CapsuleFont.mono(10, .bold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(26)
        }
        .frame(width: 360, height: 450)
    }
}
