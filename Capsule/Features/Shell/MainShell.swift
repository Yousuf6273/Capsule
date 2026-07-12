import SwiftUI

enum ShellTab: Hashable {
    case vaults, wrapped
}

/// App chrome: fixed default theme, custom glass bottom bar (`.bottomnav`).
/// Trip-specific screens are pushed on top and re-theme themselves.
struct MainShell: View {
    @Environment(AppModel.self) private var model
    @State private var tab: ShellTab = .vaults
    @State private var path = NavigationPath()
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var pendingInviteCode = ""

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                ThemedMeshBackground()

                Group {
                    switch tab {
                    case .vaults:
                        HomeView(onCreate: { showCreate = true },
                                 onJoin: { showJoin = true })
                    case .wrapped:
                        WrappedListView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
            }
            .navigationDestination(for: Vault.self) { vault in
                VaultRouter(vaultId: vault.id)
            }
            .sheet(isPresented: $showCreate) {
                CreateVaultView { newVault in
                    showCreate = false
                    path.append(newVault)
                }
            }
            .sheet(isPresented: $showJoin) {
                JoinVaultView(prefilledCode: pendingInviteCode) { vault in
                    showJoin = false
                    pendingInviteCode = ""
                    path.append(vault)
                }
            }
        }
        .tint(.capsuleCream)
        // Handles capsule.app/j/CODE universal links and capsule://j/CODE.
        .onOpenURL { url in
            let parts = url.pathComponents.filter { $0 != "/" }
            if let idx = parts.firstIndex(of: "j"), parts.indices.contains(idx + 1) {
                pendingInviteCode = parts[idx + 1].uppercased()
                showJoin = true
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            navItem(icon: "shippingbox.fill", label: "Vaults", active: tab == .vaults) { tab = .vaults }
            Spacer()
            navItem(icon: "plus", label: "New", active: false) { showCreate = true }
            Spacer()
            navItem(icon: "sparkles.rectangle.stack.fill", label: "Wrapped", active: tab == .wrapped) { tab = .wrapped }
        }
        .padding(.horizontal, 48)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(alignment: .top) {
            Rectangle().fill(Color.capsuleGlassBorder).frame(height: 1)
        }
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.14))
    }

    private func navItem(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold))
                Text(label).monoLabel(size: 9, color: active ? .poolGold : .capsuleDim, tracking: 0.8)
            }
            .foregroundStyle(active ? Color.poolGold : Color.capsuleDim)
        }
        .buttonStyle(.plain)
    }
}

/// "Wrapped" tab: opened vaults you can relive any time.
struct WrappedListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Wrapped")
                    .font(CapsuleFont.display(38, .extraBold))
                    .foregroundStyle(Color.capsuleCream)
                    .padding(.top, 8)

                if model.readyToRelive.isEmpty {
                    Text("Opened capsules will live here forever.")
                        .font(CapsuleFont.body(13, .medium))
                        .foregroundStyle(Color.capsuleDim)
                        .padding(.top, 8)
                } else {
                    ForEach(model.readyToRelive) { vault in
                        NavigationLink(value: vault) {
                            HStack(spacing: 12) {
                                CoverArt(vault: vault)
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(vault.displayName)
                                        .font(CapsuleFont.display(15, .bold))
                                        .foregroundStyle(Color.capsuleCream)
                                    Text("\(vault.memoryCount) memories")
                                        .monoLabel(size: 9, color: .poolEmerald, tracking: 0.6)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.capsuleDim2)
                            }
                            .padding(14)
                            .glassCard(cornerRadius: 20)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 110)
        }
    }
}
