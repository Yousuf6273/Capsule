import SwiftUI

/// Routes a vault to the right experience for its state and injects the
/// trip's theme into the environment — everything below re-themes per trip.
struct VaultRouter: View {
    @Environment(AppModel.self) private var model
    let vaultId: String

    private var vault: Vault? {
        model.vaults.first { $0.id == vaultId }
    }

    var body: some View {
        Group {
            if let vault {
                switch vault.state {
                case .collecting:
                    CollectingView(vault: vault)
                case .sealed:
                    WaitingView(vault: vault)
                case .unlocked:
                    OpenedVaultView(vault: vault)
                }
            } else {
                Text("This vault no longer exists.")
                    .font(CapsuleFont.body(14, .medium))
                    .foregroundStyle(Color.capsuleDim)
            }
        }
        .tripTheme(vault?.theme ?? .default)
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

/// Placeholder for unlocked vaults until the reveal sequence (milestone 5–6)
/// and permanent album (milestone 9) land.
struct OpenedVaultView: View {
    @Environment(\.tripTheme) private var theme
    let vault: Vault

    var body: some View {
        ZStack {
            ThemedMeshBackground()
            VStack(spacing: 12) {
                Text("✨")
                    .font(.system(size: 44))
                Text(vault.displayName)
                    .font(CapsuleFont.display(26, .extraBold))
                    .foregroundStyle(Color.capsuleCream)
                Text("\(vault.memoryCount) memories · opened \(vault.unlockedAt?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                    .monoLabel(size: 10, color: .capsuleCream.opacity(0.8), tracking: 0.8)
                Text("The unlock sequence, reveal slideshow and wrapped recap arrive in milestones 5–8.")
                    .font(CapsuleFont.body(12.5, .medium))
                    .foregroundStyle(Color.capsuleCream.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 6)
            }
        }
    }
}
