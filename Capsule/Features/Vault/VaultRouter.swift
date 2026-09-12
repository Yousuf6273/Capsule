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
                    Group {
                        if vault.hasCompletedReveal {
                            AlbumView(vault: vault)
                        } else {
                            RevealFlowView(vault: vault)
                        }
                    }
                    // Live backend: make sure this vault's media is on-device.
                    .task { model.syncMemoriesIfNeeded(vaultId: vault.id) }
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

