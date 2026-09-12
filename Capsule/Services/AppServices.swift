import Foundation
import SwiftUI

// ── Service protocols ────────────────────────────────────────────
// The app talks only to these; `Mock*` implementations back the UI now,
// Firebase implementations slot in behind the same interfaces (milestone 3).

protocol AuthServicing {
    func restoreSession() async -> UserProfile?
    func signIn(displayName: String) async throws -> UserProfile
    func signOut() async
}

protocol VaultServicing {
    func loadVaults(for userId: String) async throws -> [Vault]
    func createVault(name: String, unlockCondition: UnlockCondition,
                     coverImageFileName: String?, theme: TripTheme,
                     creator: UserProfile) async throws -> Vault
    func joinVault(inviteCode: String, user: UserProfile) async throws -> Vault
    func markReady(vaultId: String, userId: String) async throws -> Vault
    func update(vault: Vault) async throws
}

// ── App-wide observable state ────────────────────────────────────

@Observable
final class AppModel {
    var profile: UserProfile?
    var vaults: [Vault] = []
    var isRestoringSession = true

    let auth: AuthServicing
    let vaultService: VaultServicing
    let memoryStore: MemoryStore
    let uploadQueue: UploadQueue
    /// True when the Firebase backend is live (see BackendFactory).
    let isLiveBackend: Bool

    private var vaultObservation: Task<Void, Never>?
    private var syncedVaultIds: Set<String> = []

    @MainActor
    init(auth: AuthServicing? = nil, vaultService: VaultServicing? = nil) {
        let backend = BackendFactory.make()
        self.auth = auth ?? backend.auth
        self.vaultService = vaultService ?? backend.vaults
        self.isLiveBackend = auth == nil && vaultService == nil && backend.isLive
        let store = MemoryStore()
        self.memoryStore = store
        self.uploadQueue = UploadQueue(transport: backend.uploadTransport)
        uploadQueue.memoryStore = store
        uploadQueue.onUploaded = { [weak self] memory in
            guard let self, let idx = vaults.firstIndex(where: { $0.id == memory.vaultId }) else { return }
            vaults[idx].memoryCount += 1
            Task { try? await self.vaultService.update(vault: self.vaults[idx]) }
        }
    }

    var isSignedIn: Bool { profile != nil }

    // ── Live backend hooks (no-ops on the mock stack) ────────────

    /// Subscribes to realtime vault changes so every member's phone stays in
    /// step — including the server flipping a vault to unlocked.
    @MainActor
    private func startObservingVaults(userId: String) {
        guard let observer = vaultService as? VaultObserving else { return }
        vaultObservation?.cancel()
        vaultObservation = Task { [weak self] in
            for await remote in observer.observeVaults(for: userId) {
                guard let self, !Task.isCancelled else { return }
                // Keep local-only flags (reveal completed) across refreshes.
                let local = Dictionary(uniqueKeysWithValues: vaults.map { ($0.id, $0) })
                vaults = remote.map { v in
                    var merged = v
                    if let l = local[v.id] { merged.hasCompletedReveal = merged.hasCompletedReveal || l.hasCompletedReveal }
                    return merged
                }
                for vault in vaults where vault.state == .unlocked {
                    syncMemoriesIfNeeded(vaultId: vault.id)
                }
            }
        }
    }

    /// Pulls an unlocked vault's sealed media to this device, once.
    @MainActor
    func syncMemoriesIfNeeded(vaultId: String) {
        guard let syncer = vaultService as? MemorySyncing,
              !syncedVaultIds.contains(vaultId) else { return }
        syncedVaultIds.insert(vaultId)
        Task {
            if let remote = try? await syncer.syncMemories(vaultId: vaultId) {
                memoryStore.mergeRemote(remote)
            } else {
                syncedVaultIds.remove(vaultId) // retry next time
            }
        }
    }

    @MainActor
    private func registerPushIfAvailable(userId: String) {
        #if canImport(FirebaseMessaging)
        guard isLiveBackend else { return }
        Task { await FirebasePush.shared.registerForPush(userId: userId) }
        #endif
    }

    /// Featured vault for the hero card: the sealed vault unlocking soonest,
    /// else the most recently active one.
    var heroVault: Vault? {
        let sealed = vaults
            .filter { $0.state == .sealed }
            .sorted { ($0.unlockDate ?? .distantFuture) < ($1.unlockDate ?? .distantFuture) }
        return sealed.first ?? vaults.first
    }

    var fillingUp: [Vault] {
        vaults.filter { $0.state == .collecting && $0.id != heroVault?.id }
    }

    /// Sealed vaults waiting on their countdown that aren't the featured hero —
    /// without this row they'd vanish from Home entirely once sealed.
    var alsoSealed: [Vault] {
        vaults.filter { $0.state == .sealed && $0.id != heroVault?.id }
    }

    var readyToRelive: [Vault] {
        vaults.filter { $0.state == .unlocked }
    }

    @MainActor
    func restore() async {
        profile = await auth.restoreSession()
        if let profile {
            uploadQueue.uploaderId = profile.id
            vaults = (try? await vaultService.loadVaults(for: profile.id)) ?? []
            unlockExpiredVaults()
            startObservingVaults(userId: profile.id)
            registerPushIfAvailable(userId: profile.id)
        }
        isRestoringSession = false
    }

    @MainActor
    func signIn(displayName: String) async throws {
        let p = try await auth.signIn(displayName: displayName)
        profile = p
        uploadQueue.uploaderId = p.id
        vaults = (try? await vaultService.loadVaults(for: p.id)) ?? []
        startObservingVaults(userId: p.id)
        registerPushIfAvailable(userId: p.id)
    }

    /// The mock stand-in for the server's scheduled unlock: any vault whose
    /// unlock date has passed flips to unlocked — including ones still in
    /// `.collecting`, since adding stays open right up to the unlock moment.
    /// Runs at launch and whenever the app returns to the foreground, so an
    /// expired vault is never stuck waiting for a screen visit.
    @MainActor
    func unlockExpiredVaults() {
        for idx in vaults.indices {
            guard vaults[idx].state != .unlocked,
                  case .date(let unlockDate) = vaults[idx].unlockCondition,
                  unlockDate <= .now else { continue }
            vaults[idx].state = .unlocked
            vaults[idx].unlockedAt = unlockDate
            let vault = vaults[idx]
            Task { try? await vaultService.update(vault: vault) }
        }
    }

    /// Moves a vault from `.collecting` to `.sealed` — the moment the group
    /// stops adding and the countdown (or "everyone ready") takes over.
    @MainActor
    func sealVault(vaultId: String) {
        guard let idx = vaults.firstIndex(where: { $0.id == vaultId }),
              vaults[idx].state == .collecting else { return }
        vaults[idx].state = .sealed
        let vault = vaults[idx]
        Task { try? await vaultService.update(vault: vault) }
    }

    // In production only the Cloud Function flips state — this local path
    // backs the mock stack and the demo "simulate unlock" button.
    @MainActor
    func unlockLocally(vaultId: String) {
        guard let idx = vaults.firstIndex(where: { $0.id == vaultId }) else { return }
        vaults[idx].state = .unlocked
        vaults[idx].unlockedAt = .now
        let vault = vaults[idx]
        Task { try? await vaultService.update(vault: vault) }
    }

    @MainActor
    func markRevealCompleted(vaultId: String) {
        guard let idx = vaults.firstIndex(where: { $0.id == vaultId }) else { return }
        vaults[idx].hasCompletedReveal = true
        let vault = vaults[idx]
        Task { try? await vaultService.update(vault: vault) }
    }

    @MainActor
    func createVault(name: String, unlockCondition: UnlockCondition,
                     coverImageFileName: String?, theme: TripTheme) async throws -> Vault {
        guard let profile else { throw CapsuleError.notSignedIn }
        let vault = try await vaultService.createVault(
            name: name, unlockCondition: unlockCondition,
            coverImageFileName: coverImageFileName, theme: theme, creator: profile)
        vaults.insert(vault, at: 0)
        return vault
    }

    @MainActor
    func joinVault(inviteCode: String) async throws -> Vault {
        guard let profile else { throw CapsuleError.notSignedIn }
        let vault = try await vaultService.joinVault(inviteCode: inviteCode, user: profile)
        if !vaults.contains(where: { $0.id == vault.id }) {
            vaults.insert(vault, at: 0)
        }
        return vault
    }
}

enum CapsuleError: LocalizedError {
    case notSignedIn
    case inviteCodeNotFound
    case vaultNotFound

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "You need to sign in first."
        case .inviteCodeNotFound: return "That invite code doesn't match any vault."
        case .vaultNotFound: return "This vault no longer exists."
        }
    }
}

// ── Local file storage for covers & media ────────────────────────

enum LocalStore {
    static var mediaDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(for fileName: String) -> URL {
        mediaDirectory.appendingPathComponent(fileName)
    }

    @discardableResult
    static func save(data: Data, fileName: String) throws -> URL {
        let url = url(for: fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func image(named fileName: String?) -> UIImage? {
        guard let fileName else { return nil }
        return UIImage(contentsOfFile: url(for: fileName).path)
    }
}
