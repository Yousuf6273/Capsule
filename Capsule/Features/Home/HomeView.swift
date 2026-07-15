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
                    Text(greeting.uppercased())
                        .monoLabel(size: 10.5, color: Color(hex: "F4D796").opacity(0.85), tracking: 2.2)
                        .padding(.top, 14)
                        .floatIn(delay: 0)

                    Text("Your Vaults")
                        .font(CapsuleFont.display(38, .extraBold))
                        .foregroundStyle(Color.capsuleCream)
                        .padding(.top, 6)
                        .floatIn(delay: 0.06)

                    if let hero = model.heroVault {
                        NavigationLink(value: hero) {
                            HeroVaultCard(vault: hero)
                        }
                        .buttonStyle(PressableCardStyle())
                        .accessibilityIdentifier("heroCard")
                        .padding(.top, 20)
                        .floatIn(delay: 0.14)
                    }

                    if !model.fillingUp.isEmpty {
                        sectionHeader("Still filling up", count: model.fillingUp.count)
                            .floatIn(delay: 0.24)
                        vaultRow(model.fillingUp, status: .collecting)
                            .floatIn(delay: 0.3)
                    }

                    if !model.alsoSealed.isEmpty {
                        sectionHeader("🔒 Sealed, waiting", count: model.alsoSealed.count)
                            .floatIn(delay: 0.28)
                        vaultRow(model.alsoSealed, status: .sealed)
                            .floatIn(delay: 0.32)
                    }

                    if !model.readyToRelive.isEmpty {
                        sectionHeader("✨ Ready to relive", count: model.readyToRelive.count)
                            .floatIn(delay: 0.34)
                        vaultRow(model.readyToRelive, status: .unlocked)
                            .floatIn(delay: 0.4)
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

            // FAB — champagne, like the unseal button
            Button(action: onCreate) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(hex: "17141C"))
                    .frame(width: 58, height: 58)
                    .background(
                        LinearGradient(colors: [Color(hex: "F4D796"), Color(hex: "D9B26A")],
                                       startPoint: .top, endPoint: .bottom),
                        in: Circle())
                    .shadow(color: Color(hex: "D9B26A").opacity(0.45), radius: 18, y: 8)
            }
            .buttonStyle(PressableCardStyle())
            .padding(.trailing, 20)
            .padding(.bottom, 96)
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

    private func vaultRow(_ vaults: [Vault], status: MiniVaultCard.Status) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(vaults) { vault in
                    NavigationLink(value: vault) {
                        MiniVaultCard(vault: vault, status: status)
                    }
                    .buttonStyle(PressableCardStyle())
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
