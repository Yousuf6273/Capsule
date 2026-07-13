import SwiftUI

// ── Trip Replay: the cinematic unlock ceremony ───────────────────
// unseal → intro → numbers → journey → finale → gallery.
// One coordinator owns the phase machine so the whole sequence is a
// single interruptible flow (backgrounding resumes at the current phase).

enum ReplayPhase: Int, Comparable {
    case unseal, intro, numbers, journey, finale

    static func < (lhs: ReplayPhase, rhs: ReplayPhase) -> Bool { lhs.rawValue < rhs.rawValue }
}

@MainActor
@Observable
final class TripReplayCoordinator {
    var phase: ReplayPhase = .unseal
    let vault: Vault
    let memories: [Memory]
    let stats: RecapStats
    let slides: [StatSlide]        // 5-8 dynamically chosen for THIS trip
    let journey: [ReplayItem]      // chapter cards interleaved with highlights

    init(vault: Vault, memories: [Memory], currentUserId: String) {
        self.vault = vault
        self.memories = memories
        let stats = RecapStats.compute(vault: vault, memories: memories, currentUserId: currentUserId)
        self.stats = stats
        self.slides = StatSelector.select(vault: vault, stats: stats)
        self.journey = JourneyBuilder.build(vault: vault, memories: memories)
    }

    func advance() {
        guard let next = ReplayPhase(rawValue: phase.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.7)) { phase = next }
    }
}

struct RevealFlowView: View {
    @Environment(AppModel.self) private var model
    @State private var coordinator: TripReplayCoordinator?
    let vault: Vault

    var body: some View {
        ZStack {
            Color.capsuleCharcoal3.ignoresSafeArea()

            if let coordinator {
                switch coordinator.phase {
                case .unseal:
                    UnsealView(vault: vault) { coordinator.advance() }
                case .intro:
                    IntroCardView(vault: vault, stats: coordinator.stats) { coordinator.advance() }
                case .numbers:
                    NumbersView(slides: coordinator.slides) { coordinator.advance() }
                case .journey:
                    JourneyView(vault: vault, items: coordinator.journey) { coordinator.advance() }
                case .finale:
                    FinaleView {
                        model.markRevealCompleted(vaultId: vault.id)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .onAppear {
            if coordinator == nil {
                coordinator = TripReplayCoordinator(
                    vault: vault,
                    memories: model.memoryStore.memories(for: vault.id),
                    currentUserId: model.profile?.id ?? "")
            }
        }
    }
}

// ── Journey timeline ─────────────────────────────────────────────

enum ReplayItem: Identifiable {
    case chapter(title: String, subtitle: String)
    case photo(Memory)

    var id: String {
        switch self {
        case .chapter(let title, let subtitle): return "ch-\(title)-\(subtitle)"
        case .photo(let memory): return memory.id
        }
    }
}

enum JourneyBuilder {
    /// Chronological chapters (Arrival → Day N → Goodbye) with up to 3
    /// highlight photos each — captioned shots win, and a Sunset chapter
    /// appears when an evening cluster exists.
    static func build(vault: Vault, memories: [Memory]) -> [ReplayItem] {
        let sorted = memories.sorted { $0.capturedAt < $1.capturedAt }
        guard !sorted.isEmpty else { return [] }

        let cal = Calendar.current
        let grouped = Dictionary(grouping: sorted) { cal.startOfDay(for: $0.capturedAt) }
        let days = grouped.keys.sorted()
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEEE, MMM d"

        var items: [ReplayItem] = []
        for (index, day) in days.enumerated() {
            let photos = grouped[day] ?? []
            let title: String
            switch index {
            case 0: title = "Arrival"
            case days.count - 1 where days.count > 1: title = "The Last Day"
            default: title = "Day \(numberWord(index + 1))"
            }
            items.append(.chapter(title: title, subtitle: dayFmt.string(from: day)))
            items.append(contentsOf: highlights(from: photos, limit: 3).map { .photo($0) })

            // Sunset interlude when an evening cluster exists on this day.
            let evening = photos.filter { (18...20).contains(cal.component(.hour, from: $0.capturedAt)) }
            if evening.count >= 2, index != days.count - 1 {
                items.append(.chapter(title: "Sunset", subtitle: "golden hour, \(dayFmt.string(from: day))"))
                items.append(.photo(evening[evening.count / 2]))
            }
        }

        if let last = sorted.last, days.count > 1 {
            items.append(.chapter(title: "Goodbye", subtitle: "until next time"))
            items.append(.photo(last))
        }
        return items
    }

    /// Spread picks across the day, preferring captioned photos.
    private static func highlights(from photos: [Memory], limit: Int) -> [Memory] {
        guard photos.count > limit else { return photos }
        let captioned = photos.filter { $0.caption != nil }
        var picks: [Memory] = []
        picks.append(photos.first!)
        if let mid = captioned.first(where: { $0.id != photos.first!.id }) ?? photos.dropFirst(photos.count / 2).first {
            picks.append(mid)
        }
        if let last = photos.last, !picks.contains(last) { picks.append(last) }
        return Array(picks.prefix(limit))
    }

    private static func numberWord(_ n: Int) -> String {
        let words = ["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]
        return n <= words.count ? words[n - 1] : "\(n)"
    }
}

// ── Dynamic stat selection ───────────────────────────────────────

struct StatSlide: Identifiable {
    let id = UUID()
    let emoji: String
    let eyebrow: String
    let value: String        // the oversized line
    let countTo: Int?        // when set, the value animates 0 → countTo
    let caption: String
    let score: Double        // interestingness — top slides win
}

enum StatSelector {
    /// Computes every candidate stat, scores how interesting it is for THIS
    /// trip, and returns the top 5-8 so the replay stays tight (30-60s).
    static func select(vault: Vault, stats: RecapStats) -> [StatSlide] {
        var mandatory: [StatSlide] = [
            StatSlide(emoji: "🔒", eyebrow: "While no one was looking",
                      value: "\(stats.totalMemories)", countTo: stats.totalMemories,
                      caption: "memories were sealed away", score: 10),
            StatSlide(emoji: "🗓", eyebrow: "The trip",
                      value: "\(stats.dayCount) days", countTo: nil,
                      caption: "\(stats.dateRange.capitalized) · \(stats.friendCount) friends", score: 9),
        ]
        if let top = stats.topContributor {
            mandatory.append(
                StatSlide(emoji: "📸", eyebrow: "Couldn't put the phone down",
                          value: top.name, countTo: nil,
                          caption: "added the most — \(top.count) memories", score: 8))
        }

        var candidates: [StatSlide] = []

        if stats.videoCount > 0 {
            candidates.append(StatSlide(
                emoji: "🎬", eyebrow: "Lights, camera",
                value: "\(stats.videoCount)", countTo: stats.videoCount,
                caption: stats.videoCount == 1 ? "video captured" : "videos captured",
                score: 3 + min(3, Double(stats.videoCount) / 5)))
        }
        candidates.append(StatSlide(
            emoji: "💾", eyebrow: "The damage",
            value: stats.gbLabel, countTo: nil,
            caption: "of pure, uncompressed chaos",
            score: stats.totalBytes > 1_073_741_824 ? 6 : 3))
        candidates.append(StatSlide(
            emoji: "🎉", eyebrow: "The big one",
            value: stats.busiestDayLabel, countTo: nil,
            caption: "\(stats.busiestDayCount) memories in a single day",
            score: 4 + min(3, Double(stats.busiestDayCount) / 10)))
        if stats.sunsetCount >= 2 {
            candidates.append(StatSlide(
                emoji: "🌇", eyebrow: "Golden hour devotees",
                value: "\(stats.sunsetCount)", countTo: stats.sunsetCount,
                caption: "sunset photos. Worth it every time.",
                score: 4 + min(4, Double(stats.sunsetCount) / 3)))
        }
        if let owl = stats.nightOwl {
            candidates.append(StatSlide(
                emoji: "🦉", eyebrow: "Night owl award",
                value: owl.name, countTo: nil,
                caption: "still capturing memories at \(owl.time)",
                score: owl.isAfterMidnight ? 7 : 4))
        }
        if let bird = stats.earlyBird {
            candidates.append(StatSlide(
                emoji: "🌅", eyebrow: "Early bird award",
                value: bird.name, countTo: nil,
                caption: "up and shooting at \(bird.time)",
                score: bird.isBeforeSeven ? 7 : 3.5))
        }
        if stats.longestStreak >= 2 {
            candidates.append(StatSlide(
                emoji: "🔥", eyebrow: "No days off",
                value: "\(stats.longestStreak) days", countTo: nil,
                caption: "longest streak of daily memories",
                score: 3 + Double(stats.longestStreak) / 2))
        }
        if let hour = stats.commonHourLabel {
            candidates.append(StatSlide(
                emoji: "⏰", eyebrow: "Peak memory hour",
                value: hour, countTo: nil,
                caption: "when this group does its best work",
                score: 4))
        }
        if stats.hiddenGemCount > 0 {
            candidates.append(StatSlide(
                emoji: "💎", eyebrow: "Hidden gems",
                value: "\(stats.hiddenGemCount)", countTo: stats.hiddenGemCount,
                caption: "photos nobody remembered taking",
                score: 5 + min(2, Double(stats.hiddenGemCount))))
        }

        let picked = candidates.sorted { $0.score > $1.score }
            .prefix(max(2, 8 - mandatory.count))
        return mandatory + Array(picked)
    }
}

// ── Recap stats (shared by replay, quiz and wrapped screen) ──────

struct RecapStats {
    let totalMemories: Int
    let photoCount: Int
    let videoCount: Int
    let totalBytes: Int64
    let dayCount: Int
    let dateRange: String
    let friendCount: Int
    let leaderboard: [(name: String, count: Int)]   // sorted desc
    let busiestDayLabel: String
    let busiestDayCount: Int
    let earliestUploadLabel: String
    let latestUploadLabel: String
    let sealedDays: Int
    let sunsetCount: Int
    let nightOwl: (name: String, time: String, isAfterMidnight: Bool)?
    let earlyBird: (name: String, time: String, isBeforeSeven: Bool)?
    let longestStreak: Int
    let commonHourLabel: String?
    let hiddenGemCount: Int

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

        let cal = Calendar.current
        var perMember: [String: Int] = [:]
        var perDay: [Date: Int] = [:]
        var perHour: [Int: Int] = [:]
        for m in memories {
            perMember[name(for: m.uploaderId), default: 0] += 1
            perDay[cal.startOfDay(for: m.capturedAt), default: 0] += 1
            perHour[cal.component(.hour, from: m.capturedAt), default: 0] += 1
        }

        let leaderboard = perMember.sorted { $0.value > $1.value }.map { (name: $0.key, count: $0.value) }
        let busiest = perDay.max { $0.value < $1.value }

        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        let dates = memories.map(\.capturedAt)
        let range: String
        if let first = dates.min(), let last = dates.max() {
            range = "\(fmt.string(from: first)) – \(fmt.string(from: last))".uppercased()
        } else { range = "" }

        let timeFmt = DateFormatter(); timeFmt.dateFormat = "h:mma"
        func clockMinutes(_ d: Date) -> Int {
            let c = cal.dateComponents([.hour, .minute], from: d)
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
        let earliestByClock = memories.min { clockMinutes($0.capturedAt) < clockMinutes($1.capturedAt) }
        let latestByClock = memories.max { clockMinutes($0.capturedAt) < clockMinutes($1.capturedAt) }

        let dayFmt = DateFormatter(); dayFmt.dateFormat = "EEEE"
        let sealedDays = max(1, cal.dateComponents([.day], from: vault.createdAt,
                                                   to: vault.unlockedAt ?? .now).day ?? 1)

        // Longest run of consecutive days with at least one memory.
        var longestStreak = 0
        var streak = 0
        var cursor: Date? = nil
        for day in perDay.keys.sorted() {
            if let prev = cursor, cal.dateComponents([.day], from: prev, to: day).day == 1 {
                streak += 1
            } else {
                streak = 1
            }
            longestStreak = max(longestStreak, streak)
            cursor = day
        }

        let hourFmt = DateFormatter(); hourFmt.dateFormat = "ha"
        let commonHour = perHour.max { $0.value < $1.value }
        let commonHourLabel: String? = commonHour.flatMap { hour, count in
            guard count >= 3 else { return nil }
            let date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
            return hourFmt.string(from: date).lowercased()
        }

        let nightOwl: (String, String, Bool)? = latestByClock.map {
            let hour = cal.component(.hour, from: $0.capturedAt)
            return (name(for: $0.uploaderId),
                    timeFmt.string(from: $0.capturedAt).lowercased(),
                    hour >= 0 && hour < 4)
        }
        let earlyBird: (String, String, Bool)? = earliestByClock.map {
            let hour = cal.component(.hour, from: $0.capturedAt)
            return (name(for: $0.uploaderId),
                    timeFmt.string(from: $0.capturedAt).lowercased(),
                    hour < 7)
        }

        return RecapStats(
            totalMemories: memories.count,
            photoCount: memories.filter { $0.mediaType == .photo }.count,
            videoCount: memories.filter { $0.mediaType == .video }.count,
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
            sealedDays: sealedDays,
            sunsetCount: memories.filter { (18...20).contains(cal.component(.hour, from: $0.capturedAt)) }.count,
            nightOwl: nightOwl,
            earlyBird: earlyBird,
            longestStreak: longestStreak,
            commonHourLabel: commonHourLabel,
            hiddenGemCount: memories.filter { $0.uploadedAt.timeIntervalSince($0.capturedAt) > 6 * 3600 }.count)
    }
}
