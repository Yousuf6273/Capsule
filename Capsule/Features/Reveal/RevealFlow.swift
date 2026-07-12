import SwiftUI

// ── The unlock ceremony: doors → teaser → slideshow → quiz → wrapped ──
// One coordinator owns the phase machine so the whole sequence is a single
// interruptible flow (backgrounding resumes at the current phase).

enum RevealPhase: Int, Comparable {
    case doors, teaser, slideshow, quiz, wrapped

    static func < (lhs: RevealPhase, rhs: RevealPhase) -> Bool { lhs.rawValue < rhs.rawValue }
}

@MainActor
@Observable
final class RevealFlowCoordinator {
    var phase: RevealPhase = .doors
    let vault: Vault
    let memories: [Memory]
    let stats: RecapStats

    init(vault: Vault, memories: [Memory], currentUserId: String) {
        self.vault = vault
        self.memories = memories
        self.stats = RecapStats.compute(vault: vault, memories: memories, currentUserId: currentUserId)
    }

    func advance() {
        guard let next = RevealPhase(rawValue: phase.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.6)) { phase = next }
    }
}

struct RevealFlowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tripTheme) private var theme
    @State private var coordinator: RevealFlowCoordinator?
    let vault: Vault

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let coordinator {
                switch coordinator.phase {
                case .doors:
                    UnlockDoorsView(vault: vault, stats: coordinator.stats) {
                        coordinator.advance()
                    }
                case .teaser:
                    RecapTeaserView(stats: coordinator.stats) {
                        coordinator.advance()
                    }
                case .slideshow:
                    RevealSlideshowView(vault: vault, memories: coordinator.memories) {
                        coordinator.advance()
                    }
                case .quiz:
                    QuizView(vault: vault, memories: coordinator.memories, stats: coordinator.stats) {
                        coordinator.advance()
                    }
                case .wrapped:
                    RecapWrappedView(vault: vault, stats: coordinator.stats) {
                        model.markRevealCompleted(vaultId: vault.id)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .onAppear {
            if coordinator == nil {
                coordinator = RevealFlowCoordinator(
                    vault: vault,
                    memories: model.memoryStore.memories(for: vault.id),
                    currentUserId: model.profile?.id ?? "")
            }
        }
    }
}

// ── Recap stats: computed client-side from unlocked memories ─────
// (In the live stack the Cloud Function precomputes these at unlock;
// the shapes match so the source can swap.)

struct RecapStats {
    let totalMemories: Int
    let totalBytes: Int64
    let dayCount: Int
    let dateRange: String
    let friendCount: Int
    let leaderboard: [(name: String, count: Int)]   // sorted desc
    let busiestDayLabel: String
    let busiestDayCount: Int
    let earliestUploadLabel: String   // "Rhys, 4:52am"
    let latestUploadLabel: String
    let sealedDays: Int

    var topContributor: (name: String, count: Int)? { leaderboard.first }

    var gbLabel: String {
        let gb = Double(totalBytes) / 1_073_741_824
        return gb >= 1 ? String(format: "%.0fGB", gb) : String(format: "%.0fMB", Double(totalBytes) / 1_048_576)
    }

    static func compute(vault: Vault, memories: [Memory], currentUserId: String) -> RecapStats {
        func name(for uploaderId: String) -> String {
            if uploaderId == currentUserId || uploaderId == "CURRENT_USER" { return "You" }
            return vault.members.first { $0.id == uploaderId }?.displayName
                ?? uploaderId.replacingOccurrences(of: "friend-", with: "").capitalized
        }

        var perMember: [String: Int] = [:]
        var perDay: [Date: Int] = [:]
        let cal = Calendar.current
        for m in memories {
            perMember[name(for: m.uploaderId), default: 0] += 1
            perDay[cal.startOfDay(for: m.capturedAt), default: 0] += 1
        }

        let leaderboard = perMember.sorted { $0.value > $1.value }.map { (name: $0.key, count: $0.value) }
        let busiest = perDay.max { $0.value < $1.value }

        let dates = memories.map(\.capturedAt)
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let range: String
        if let first = dates.min(), let last = dates.max() {
            range = "\(fmt.string(from: first)) – \(fmt.string(from: last))".uppercased()
        } else {
            range = ""
        }

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mma"
        let earliestByClock = memories.min {
            let a = cal.dateComponents([.hour, .minute], from: $0.capturedAt)
            let b = cal.dateComponents([.hour, .minute], from: $1.capturedAt)
            return (a.hour! * 60 + a.minute!) < (b.hour! * 60 + b.minute!)
        }
        let latestByClock = memories.max {
            let a = cal.dateComponents([.hour, .minute], from: $0.capturedAt)
            let b = cal.dateComponents([.hour, .minute], from: $1.capturedAt)
            return (a.hour! * 60 + a.minute!) < (b.hour! * 60 + b.minute!)
        }

        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEEE"

        let sealedDays = max(1, cal.dateComponents([.day], from: vault.createdAt,
                                                   to: vault.unlockedAt ?? .now).day ?? 1)

        return RecapStats(
            totalMemories: memories.count,
            totalBytes: memories.reduce(0) { $0 + $1.byteSize },
            dayCount: perDay.count,
            dateRange: range,
            friendCount: vault.members.count,
            leaderboard: leaderboard,
            busiestDayLabel: busiest.map { dayFmt.string(from: $0.key) } ?? "—",
            busiestDayCount: busiest?.value ?? 0,
            earliestUploadLabel: earliestByClock.map {
                "\(name(for: $0.uploaderId)), \(timeFmt.string(from: $0.capturedAt).lowercased())"
            } ?? "—",
            latestUploadLabel: latestByClock.map {
                "\(name(for: $0.uploaderId)), \(timeFmt.string(from: $0.capturedAt).lowercased())"
            } ?? "—",
            sealedDays: sealedDays)
    }
}
