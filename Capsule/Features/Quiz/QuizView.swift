import SwiftUI

/// Group guessing game — designed for phones-out-in-the-same-room energy:
/// large touch targets, fast rounds, celebratory reveals, shareable results.
struct QuizView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tripTheme) private var theme
    let vault: Vault
    let memories: [Memory]
    let stats: RecapStats
    var onFinished: () -> Void

    @State private var engine: QuizEngine?
    @State private var showIntro = true

    var body: some View {
        ZStack {
            Color.capsuleCharcoal3.ignoresSafeArea()
            ThemedMeshBackground().opacity(0.5)

            if showIntro {
                intro
            } else if let engine {
                if engine.isFinished {
                    QuizResultsView(engine: engine, onDone: onFinished)
                } else {
                    QuizRoundView(engine: engine)
                }
            }
        }
        .onAppear {
            if engine == nil {
                engine = QuizEngine(vault: vault, memories: memories, stats: stats,
                                    currentUserId: model.profile?.id ?? "")
            }
        }
    }

    private var intro: some View {
        VStack(spacing: 16) {
            Text("🎮").font(.system(size: 52))
            Text("Before the deep dive…")
                .monoLabel(size: 11, color: theme.secondary, tracking: 2)
            Text("How well do you\nknow this trip?")
                .font(CapsuleFont.display(28, .extraBold))
                .foregroundStyle(Color.capsuleCream)
                .multilineTextAlignment(.center)
            Text("5 quick rounds · fastest guess wins bonus points")
                .font(CapsuleFont.body(13, .semibold))
                .foregroundStyle(Color.capsuleDim)

            Button("Let's play") {
                withAnimation(.spring(duration: 0.5)) { showIntro = false }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 60)
            .padding(.top, 14)

            Button("Maybe later") { onFinished() }
                .font(CapsuleFont.body(12.5, .semibold))
                .foregroundStyle(Color.capsuleDim)
                .padding(.top, 2)
        }
    }
}

// ── One round ────────────────────────────────────────────────────

struct QuizRoundView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tripTheme) private var theme
    @Bindable var engine: QuizEngine
    @State private var celebrate = false

    private var round: QuizRound { engine.currentRound }
    private var revealing: Bool { engine.roundState == .revealing }

    var body: some View {
        VStack(spacing: 0) {
            // Round header
            HStack {
                Text("ROUND \(engine.roundIndex + 1)/\(engine.rounds.count)")
                    .monoLabel(size: 10, color: theme.secondary, tracking: 1.5)
                Spacer()
                Text("SCORE \(engine.myScore)")
                    .font(CapsuleFont.mono(11, .bold))
                    .foregroundStyle(Color(hex: "F4D796"))
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)

            // Photo (for photo rounds)
            if case .guessWhoTook(let memory) = round.kind {
                roundPhoto(memory)
            } else if case .whichDay(let memory) = round.kind {
                roundPhoto(memory)
            } else {
                Spacer().frame(height: 40)
            }

            Text(round.prompt)
                .font(CapsuleFont.display(19, .bold))
                .foregroundStyle(Color.capsuleCream)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.top, 18)

            // Options — big targets, 2-col grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                ForEach(round.options) { option in
                    optionButton(option)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            Spacer()

            if revealing {
                Button(engine.roundIndex + 1 >= engine.rounds.count ? "See the scores" : "Next round") {
                    engine.advance()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 22)
                .padding(.bottom, 26)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.success, trigger: celebrate)
        .onChange(of: engine.roundState) { _, state in
            if state == .revealing,
               let mine = engine.myGuessOptionId,
               mine == round.correctOptionId {
                celebrate.toggle()
            }
        }
    }

    private func roundPhoto(_ memory: Memory) -> some View {
        Group {
            if let image = model.memoryStore.image(for: memory) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 260)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                    .padding(.horizontal, 22)
                    .padding(.top, 16)
            }
        }
    }

    @ViewBuilder
    private func optionButton(_ option: QuizOption) -> some View {
        let isMine = engine.myGuessOptionId == option.id
        let isCorrect = revealing && round.correctOptionId == option.id
        let isWrongPick = revealing && isMine && !isCorrect
        let guesserCount = revealing ? engine.guesses.values.filter { $0.optionId == option.id }.count : 0

        Button {
            engine.submitGuess(optionId: option.id)
        } label: {
            HStack(spacing: 8) {
                if let initial = option.avatarInitial {
                    InitialAvatar(initial: initial, size: 26, colorIndex: option.avatarColorIndex)
                }
                Text(option.label)
                    .font(CapsuleFont.body(13.5, .bold))
                    .foregroundStyle(Color.capsuleCream)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.poolEmerald)
                } else if isWrongPick {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.poolCoral)
                }
                if guesserCount > 0 {
                    Text("\(guesserCount)")
                        .font(CapsuleFont.mono(11, .bold))
                        .foregroundStyle(Color.capsuleDim)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 15)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isCorrect ? Color.poolEmerald.opacity(0.22)
                          : isMine ? theme.primary.opacity(0.3)
                          : Color.white.opacity(0.08))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isCorrect ? Color.poolEmerald
                                  : isMine ? theme.secondary
                                  : Color.capsuleGlassBorder,
                                  lineWidth: isCorrect || isMine ? 2 : 1.5))
            .scaleEffect(isCorrect && revealing ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quizOption")
        .disabled(engine.myGuessOptionId != nil)
        .animation(.spring(duration: 0.4), value: revealing)
    }
}

// ── Results ──────────────────────────────────────────────────────

struct QuizResultsView: View {
    @Environment(\.tripTheme) private var theme
    let engine: QuizEngine
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("🏆").font(.system(size: 46)).padding(.top, 40)
            Text("Quiz complete")
                .monoLabel(size: 11, color: theme.secondary, tracking: 2)
                .padding(.top, 8)
            Text("How you stacked up")
                .font(CapsuleFont.display(22, .extraBold))
                .foregroundStyle(Color.capsuleCream)
                .padding(.top, 6)

            // Screenshot-friendly scoreboard card
            VStack(spacing: 0) {
                ForEach(Array(engine.sortedScores.enumerated()), id: \.element.member.id) { rank, entry in
                    HStack(spacing: 12) {
                        Text(rank == 0 ? "👑" : "\(rank + 1)")
                            .font(CapsuleFont.display(14, .bold))
                            .foregroundStyle(rank == 0 ? Color.poolGold : Color.capsuleDim)
                            .frame(width: 26)
                        InitialAvatar(initial: entry.member.initial, size: 30,
                                      colorIndex: engine.vault.members.firstIndex(of: entry.member) ?? 0)
                        Text(entry.member.isCurrentUser ? "You" : entry.member.displayName)
                            .font(CapsuleFont.body(14, .bold))
                            .foregroundStyle(Color.capsuleCream)
                        Spacer()
                        Text("\(entry.score)")
                            .font(CapsuleFont.mono(15, .bold))
                            .foregroundStyle(rank == 0 ? Color.poolGold : Color.capsuleCream)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    if rank < engine.sortedScores.count - 1 {
                        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                            .padding(.leading, 56)
                    }
                }
            }
            .glassCard()
            .padding(.horizontal, 22)
            .padding(.top, 22)

            Spacer()

            Button("Back to the album") { onDone() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 22)
                .padding(.bottom, 26)
        }
    }
}
