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
                ShellBackground()

                Group {
                    switch tab {
                    case .vaults:
                        HomeView(onCreate: { showCreate = true },
                                 onJoin: { showJoin = true })
                    case .wrapped:
                        WrappedListView { vault in
                            path.append(vault)
                        }
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

    /// Floating glass pill — quiet, jewel-like, never a toolbar.
    private var bottomBar: some View {
        HStack(spacing: 38) {
            navItem(icon: "shippingbox.fill", label: "Vaults", active: tab == .vaults) { tab = .vaults }
                .accessibilityIdentifier("tabVaults")
            navItem(icon: "plus", label: "New", active: false) { showCreate = true }
                .accessibilityIdentifier("tabNew")
            navItem(icon: "sparkles", label: "Wrapped", active: tab == .wrapped) { tab = .wrapped }
                .accessibilityIdentifier("tabWrapped")
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Color(hex: "17141C").opacity(0.5), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        .padding(.bottom, 12)
    }

    private func navItem(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                Text(label).monoLabel(size: 8.5, color: active ? Color(hex: "F4D796") : .capsuleDim2, tracking: 1)
            }
            .foregroundStyle(active ? Color(hex: "F4D796") : Color.capsuleDim)
        }
        .buttonStyle(.plain)
    }
}

/// "Wrapped" tab: opened vaults you can relive any time.
struct WrappedListView: View {
    @Environment(AppModel.self) private var model
    var onOpen: (Vault) -> Void = { _ in }

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
                        Button { onOpen(vault) } label: {
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
