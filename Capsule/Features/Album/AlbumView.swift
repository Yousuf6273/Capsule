import SwiftUI

/// The permanent album: 2-column grid grouped by trip day, kept forever.
struct AlbumView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tripTheme) private var theme
    let vault: Vault

    @State private var selected: Memory?
    @State private var showWrapped = false
    @State private var showQuiz = false

    private var memories: [Memory] { model.memoryStore.memories(for: vault.id) }

    private var stats: RecapStats {
        RecapStats.compute(vault: vault, memories: memories,
                           currentUserId: model.profile?.id ?? "")
    }

    private var byDay: [(day: Int, items: [Memory])] {
        let all = memories
        let grouped = Dictionary(grouping: all) { model.memoryStore.dayIndex(of: $0, in: all) }
        return grouped.sorted { $0.key < $1.key }.map { (day: $0.key, items: $0.value) }
    }

    var body: some View {
        ZStack {
            Color.capsuleCharcoal.ignoresSafeArea()
            ThemedMeshBackground().opacity(0.25)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(vault.subtitle ?? vault.displayName)
                        .font(CapsuleFont.display(26, .bold))
                        .foregroundStyle(Color.capsuleCream)
                        .padding(.top, 8)
                    Text("✨ Ready to relive · opened \(vault.unlockedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                        .font(CapsuleFont.body(12.5, .medium))
                        .foregroundStyle(Color.capsuleDim)
                        .padding(.top, 5)

                    ForEach(byDay, id: \.day) { group in
                        Text("DAY \(group.day)")
                            .monoLabel(size: 10, color: theme.secondary, tracking: 1.5)
                            .padding(.top, 22)
                            .padding(.bottom, 10)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                            GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(group.items) { memory in
                                albumCell(memory)
                                    .onTapGesture { selected = memory }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 60)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                GlassIconButton(systemName: "gamecontroller.fill") { showQuiz = true }
                GlassIconButton(systemName: "sparkles") { showWrapped = true }
            }
        }
        .sheet(item: $selected) { memory in
            MemoryDetailView(vault: vault, memory: memory)
                .tripTheme(vault.theme)
        }
        .fullScreenCover(isPresented: $showWrapped) {
            RecapWrappedView(vault: vault, stats: stats) { showWrapped = false }
                .tripTheme(vault.theme)
        }
        .fullScreenCover(isPresented: $showQuiz) {
            QuizView(vault: vault, memories: memories, stats: stats) { showQuiz = false }
                .tripTheme(vault.theme)
        }
    }

    private func albumCell(_ memory: Memory) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image = model.memoryStore.image(for: memory) {
                Color.clear
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .overlay(Image(uiImage: image).resizable().scaledToFill())
                    .clipped()
            }
            LinearGradient(colors: [.clear, Color(hex: "05070C").opacity(0.85)],
                           startPoint: .center, endPoint: .bottom)
            Text(contributorName(memory).uppercased())
                .font(CapsuleFont.mono(9.5, .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.capsuleCream)
                .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.capsuleGlassBorder, lineWidth: 1.5))
    }

    private func contributorName(_ memory: Memory) -> String {
        if memory.uploaderId == model.profile?.id || memory.uploaderId == "CURRENT_USER" { return "You" }
        return vault.members.first { $0.id == memory.uploaderId }?.displayName
            ?? memory.uploaderId.replacingOccurrences(of: "friend-", with: "").capitalized
    }
}

/// Full-screen single memory with caption + metadata.
struct MemoryDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tripTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let vault: Vault
    let memory: Memory

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "05070C").ignoresSafeArea()
            if let image = model.memoryStore.image(for: memory) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(memory.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .monoLabel(size: 10, color: theme.secondary, tracking: 1)
                if let caption = memory.caption {
                    Text("\u{201C}\(caption)\u{201D}")
                        .font(CapsuleFont.display(15, .semibold))
                        .foregroundStyle(Color.capsuleCream)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(.ultraThinMaterial)
        }
        .overlay(alignment: .topTrailing) {
            GlassIconButton(systemName: "xmark") { dismiss() }
                .padding(16)
        }
    }
}
