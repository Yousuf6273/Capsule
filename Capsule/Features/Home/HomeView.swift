import SwiftUI

/// "Your Vaults" — hero vault + horizontally scrolling sections.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    var onCreate: () -> Void
    var onJoin: () -> Void = {}

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning ☀️"
        case 12..<18: return "Good afternoon 🌤"
        default: return "Good evening 🌅"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(greeting)
                        .font(CapsuleFont.mono(12, .semibold))
                        .foregroundStyle(Color.capsuleDim)
                        .padding(.top, 8)

                    Text("Your Vaults")
                        .font(CapsuleFont.display(38, .extraBold))
                        .foregroundStyle(Color.capsuleCream)
                        .padding(.top, 2)

                    if let hero = model.heroVault {
                        NavigationLink(value: hero) {
                            HeroVaultCard(vault: hero)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 18)
                    }

                    if !model.fillingUp.isEmpty {
                        sectionHeader("Filling up", count: model.fillingUp.count)
                        vaultRow(model.fillingUp, locked: true)
                    }

                    if !model.readyToRelive.isEmpty {
                        sectionHeader("✨ Ready to relive", count: model.readyToRelive.count)
                        vaultRow(model.readyToRelive, locked: false)
                    }

                    if model.vaults.isEmpty {
                        emptyState
                    }

                    Button(action: onJoin) {
                        Text("Have an invite code? Join a capsule →")
                            .monoLabel(size: 10.5, color: .capsuleDim, tracking: 0.8)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 130)
            }

            // FAB
            Button(action: onCreate) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .frame(width: 58, height: 58)
                    .background(TripTheme.default.fabGradient, in: Circle())
                    .shadow(color: Color.poolPurple.opacity(0.58), radius: 15, y: 7)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 92)
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(CapsuleFont.display(15, .bold))
                .foregroundStyle(Color.capsuleCream)
            Spacer()
            Text("\(count)")
                .font(CapsuleFont.mono(11, .medium))
                .foregroundStyle(Color.capsuleDim2)
        }
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private func vaultRow(_ vaults: [Vault], locked: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(vaults) { vault in
                    NavigationLink(value: vault) {
                        MiniVaultCard(vault: vault, locked: locked)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.horizontal, -18)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🔒")
                .font(.system(size: 40))
            Text("No vaults yet")
                .font(CapsuleFont.display(16, .bold))
                .foregroundStyle(Color.capsuleCream)
            Text("Start a capsule for your next trip and invite the squad.")
                .font(CapsuleFont.body(13, .medium))
                .foregroundStyle(Color.capsuleDim)
                .multilineTextAlignment(.center)
            Button("Start a capsule", action: onCreate)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard()
        .padding(.top, 32)
    }
}

// ── Cover art: local photo, else themed gradient placeholder ─────

struct CoverArt: View {
    let vault: Vault
    var dimmed: Bool = false

    var body: some View {
        GeometryReader { geo in
            if let image = LocalStore.image(named: vault.coverImageFileName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .brightness(dimmed ? -0.25 : 0)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            vault.theme.primary.mixed(with: .black, selfAmount: dimmed ? 0.5 : 0.75),
                            vault.theme.primary.mixed(with: vault.theme.secondary, selfAmount: 0.45)
                                .mixed(with: .black, selfAmount: dimmed ? 0.55 : 0.85),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(vault.emojiFlag ?? "🏝")
                        .font(.system(size: min(geo.size.width, geo.size.height) * 0.32))
                        .opacity(0.45)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}
