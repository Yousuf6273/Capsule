import SwiftUI

// ── Milestone 7: guessing game — a 60-90s group activity ────────
// Round types: predict-the-leaderboard (before any answers), guess-who-took,
// which-day. Friends' guesses arrive through a transport so the mock
// (simulated friends with humanlike delays) swaps for Firestore listeners.

enum QuizRoundKind {
    case predictTopContributor
    case guessWhoTook(Memory)
    case whichDay(Memory)
}

struct QuizOption: Identifiable, Equatable {
    let id: String
    let label: String
    let avatarInitial: String?
    let avatarColorIndex: Int
}

struct QuizRound: Identifiable {
    let id = UUID().uuidString
    let kind: QuizRoundKind
    let prompt: String
    let options: [QuizOption]
    let correctOptionId: String?   // nil for predictions (resolved at the end)
}

struct QuizGuess: Equatable {
    let memberId: String
    let optionId: String
    let elapsed: Double
}

protocol QuizTransporting {
    /// Streams friends' guesses for one round.
    func friendGuesses(round: QuizRound, friends: [Member]) -> AsyncStream<QuizGuess>
}

/// Simulated friends: everyone answers within ~1-4s, mostly correctly-ish.
struct MockQuizTransport: QuizTransporting {
    func friendGuesses(round: QuizRound, friends: [Member]) -> AsyncStream<QuizGuess> {
        AsyncStream { continuation in
            let task = Task {
                var rng = SeededRandom(seed: round.id)
                for friend in friends {
                    let delay = 0.9 + rng.next() * 3.0
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { break }
                    // 55% chance of the right answer when one exists.
                    let optionId: String
                    if let correct = round.correctOptionId, rng.next() < 0.55 {
                        optionId = correct
                    } else {
                        optionId = round.options[Int(rng.next() * Double(round.options.count - 1) + 0.5)].id
                    }
                    continuation.yield(QuizGuess(memberId: friend.id, optionId: optionId, elapsed: delay))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

@MainActor
@Observable
final class QuizEngine {
    enum RoundState { case answering, revealing }

    let vault: Vault
    let rounds: [QuizRound]
    let currentUserId: String

    var roundIndex = 0
    var roundState: RoundState = .answering
    var guesses: [String: QuizGuess] = [:]      // memberId → guess (current round)
    var scores: [String: Int] = [:]             // memberId → points
    var myGuessOptionId: String?
    var isFinished = false

    private let transport: QuizTransporting
    private var streamTask: Task<Void, Never>?
    private var roundStart = Date.now

    var currentRound: QuizRound { rounds[roundIndex] }
    var friends: [Member] { vault.members.filter { !$0.isCurrentUser } }

    init(vault: Vault, memories: [Memory], stats: RecapStats, currentUserId: String,
         transport: QuizTransporting = MockQuizTransport()) {
        self.vault = vault
        self.currentUserId = currentUserId
        self.transport = transport
        self.rounds = Self.buildRounds(vault: vault, memories: memories,
                                       stats: stats, currentUserId: currentUserId)
        for member in vault.members { scores[member.id] = 0 }
        startRound()
    }

    func submitGuess(optionId: String) {
        guard roundState == .answering, myGuessOptionId == nil else { return }
        myGuessOptionId = optionId
        let elapsed = Date.now.timeIntervalSince(roundStart)
        guesses[currentUserId] = QuizGuess(memberId: currentUserId, optionId: optionId, elapsed: elapsed)
        maybeReveal()
    }

    func advance() {
        guard roundState == .revealing else { return }
        if roundIndex + 1 >= rounds.count {
            isFinished = true
        } else {
            roundIndex += 1
            startRound()
        }
    }

    var sortedScores: [(member: Member, score: Int)] {
        vault.members
            .map { ($0, scores[$0.id] ?? 0) }
            .sorted { $0.1 > $1.1 }
    }

    // ── Internals ────────────────────────────────────────────────

    private func startRound() {
        roundState = .answering
        guesses = [:]
        myGuessOptionId = nil
        roundStart = .now
        streamTask?.cancel()
        let round = currentRound
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await guess in transport.friendGuesses(round: round, friends: friends) {
                guard !Task.isCancelled, self.currentRound.id == round.id else { break }
                self.guesses[guess.memberId] = guess
                self.maybeReveal()
            }
            // Everyone answered (or stream ended) — reveal even if user is slow? No:
            // wait for the user; friends finishing just updates the "N in" count.
        }
    }

    /// Reveal once every member (including you) has guessed.
    private func maybeReveal() {
        guard roundState == .answering,
              guesses.count >= vault.members.count else { return }
        withAnimation(.spring(duration: 0.5)) { roundState = .revealing }
        scoreRound()
    }

    private func scoreRound() {
        guard let correct = currentRound.correctOptionId else { return }
        for (memberId, guess) in guesses where guess.optionId == correct {
            // 100 for correct + up to 50 speed bonus.
            scores[memberId, default: 0] += 100 + max(0, 50 - Int(guess.elapsed * 10))
        }
    }

    // ── Round construction ───────────────────────────────────────

    private static func buildRounds(vault: Vault, memories: [Memory],
                                    stats: RecapStats, currentUserId: String) -> [QuizRound] {
        var rounds: [QuizRound] = []
        var rng = SeededRandom(seed: vault.id + "quiz")

        let memberOptions = vault.members.enumerated().map { i, m in
            QuizOption(id: m.id, label: m.isCurrentUser ? "You" : m.displayName,
                       avatarInitial: m.initial, avatarColorIndex: i)
        }

        // 1. Prediction: who added the most? (resolved against the leaderboard)
        let topName = stats.topContributor?.name
        let topId = vault.members.first {
            ($0.isCurrentUser && topName == "You") || $0.displayName == topName
        }?.id
        rounds.append(QuizRound(
            kind: .predictTopContributor,
            prompt: "Before you see anything — who do you think added the most memories?",
            options: memberOptions,
            correctOptionId: topId))

        // 2-4. Guess who took this (pick photos from distinct uploaders).
        let candidates = memories.filter { $0.uploaderId != "unknown" }.shuffled(using: &rng)
        var usedUploaders = Set<String>()
        for memory in candidates {
            guard rounds.count < 4 else { break }
            let normalizedUploader = memory.uploaderId == "CURRENT_USER" ? currentUserId : memory.uploaderId
            guard vault.members.contains(where: { $0.id == normalizedUploader }),
                  !usedUploaders.contains(normalizedUploader) else { continue }
            usedUploaders.insert(normalizedUploader)
            rounds.append(QuizRound(
                kind: .guessWhoTook(memory),
                prompt: "Who took this?",
                options: memberOptions,
                correctOptionId: normalizedUploader))
        }

        // 5. Which day was this taken?
        if let memory = candidates.last, stats.dayCount > 1 {
            let cal = Calendar.current
            let start = memories.map(\.capturedAt).min() ?? memory.capturedAt
            let correctDay = (cal.dateComponents([.day], from: cal.startOfDay(for: start),
                                                 to: cal.startOfDay(for: memory.capturedAt)).day ?? 0) + 1
            let dayOptions = (1...max(2, stats.dayCount)).prefix(4).map {
                QuizOption(id: "day-\($0)", label: "Day \($0)", avatarInitial: nil, avatarColorIndex: 0)
            }
            rounds.append(QuizRound(
                kind: .whichDay(memory),
                prompt: "Which day was this?",
                options: Array(dayOptions),
                correctOptionId: "day-\(correctDay)"))
        }

        return rounds
    }
}

private extension Array {
    func shuffled(using rng: inout SeededRandom) -> [Element] {
        var copy = self
        for i in stride(from: copy.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() * Double(i + 1)) % (i + 1)
            copy.swapAt(i, j)
        }
        return copy
    }
}
