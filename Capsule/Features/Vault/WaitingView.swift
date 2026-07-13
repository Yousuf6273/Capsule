import SwiftUI

/// Sealed screen: full-bleed destination photo, huge countdown, ready progress.
struct WaitingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tripTheme) private var theme
    let vault: Vault

    @State private var isMarkingReady = false

    private var currentUserReady: Bool {
        vault.members.first(where: \.isCurrentUser)?.isReady ?? false
    }

    var body: some View {
        ZStack {
            CoverArt(vault: vault, dimmed: true)
                .ignoresSafeArea()
                .saturation(0.85)

            LinearGradient(
                stops: [
                    .init(color: Color(hex: "0A0F1C").opacity(0.05), location: 0),
                    .init(color: Color(hex: "0A0F1C").opacity(0.3), location: 0.6),
                    .init(color: Color.capsuleCharcoal2, location: 1),
                ],
                startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.capsuleCream.opacity(0.9))
                    .padding(.bottom, 14)

                Text("\(vault.name) opens in")
                    .monoLabel(size: 11, color: theme.secondary, tracking: 1.8)
                    .padding(.bottom, 10)

                if let unlockDate = vault.unlockDate {
                    HugeCountdown(target: unlockDate)
                } else {
                    Text("when everyone's ready")
                        .font(CapsuleFont.display(24, .extraBold))
                        .foregroundStyle(Color.capsuleCream)
                }

                Text("\(vault.memoryCount) memories from \(vault.members.count) friends are locked inside. Everyone opens it at the exact same second.")
                    .font(CapsuleFont.body(12.5, .medium))
                    .foregroundStyle(Color.capsuleDim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 270)
                    .padding(.top, 20)

                readyProgress
                    .padding(.top, 16)

                Spacer()

                VStack(spacing: 10) {
                    if case .everyoneReady = vault.unlockCondition, !currentUserReady {
                        Button(action: markReady) {
                            if isMarkingReady { ProgressView().tint(.white) }
                            else { Text("I'm ready to open it") }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    #if DEBUG
                    // Demo shortcut while the mock backend runs — in production
                    // only the Cloud Function can flip a vault to unlocked.
                    Button("Skip ahead — simulate unlock ✨") {
                        model.unlockLocally(vaultId: vault.id)
                    }
                    .font(CapsuleFont.body(12.5, .semibold))
                    .foregroundStyle(Color.capsuleDim)
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private var readyProgress: some View {
        HStack(spacing: 6) {
            ForEach(Array(vault.members.enumerated()), id: \.element.id) { _, member in
                Circle()
                    .fill(member.isReady ? theme.secondary : Color.white.opacity(0.25))
                    .frame(width: 7, height: 7)
            }
            Text("\(vault.readyCount) of \(vault.members.count) ready")
                .font(CapsuleFont.mono(12, .semibold))
                .foregroundStyle(theme.secondary)
                .padding(.leading, 8)
        }
    }

    private func markReady() {
        guard let userId = model.profile?.id else { return }
        isMarkingReady = true
        Task {
            defer { isMarkingReady = false }
            if let updated = try? await model.vaultService.markReady(vaultId: vault.id, userId: userId),
               let idx = model.vaults.firstIndex(where: { $0.id == vault.id }) {
                model.vaults[idx] = updated
            }
        }
    }
}

/// `.huge-countdown` — Unbounded 52pt days/hours/mins, ticking live.
struct HugeCountdown: View {
    let target: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let p = CountdownParts(from: context.date, to: target)
            HStack(spacing: 14) {
                block(String(format: "%02d", p.days), "days")
                block(String(format: "%02d", p.hours), "hours")
                block(String(format: "%02d", p.minutes), "mins")
            }
        }
    }

    private func block(_ num: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(num)
                .font(CapsuleFont.display(52, .black))
                .foregroundStyle(Color.capsuleCream)
                .monospacedDigit()
            Text(label)
                .monoLabel(size: 10, color: .capsuleDim, tracking: 1.1)
        }
    }
}
