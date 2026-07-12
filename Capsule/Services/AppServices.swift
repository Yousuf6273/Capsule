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
}

// ── App-wide observable state ────────────────────────────────────

@Observable
final class AppModel {
    var profile: UserProfile?
    var vaults: [Vault] = []
    var isRestoringSession = true

    let auth: AuthServicing
    let vaultService: VaultServicing

    init(auth: AuthServicing = MockAuthService(),
         vaultService: VaultServicing = MockVaultService()) {
        self.auth = auth
        self.vaultService = vaultService
    }

    var isSignedIn: Bool { profile != nil }

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

    var readyToRelive: [Vault] {
        vaults.filter { $0.state == .unlocked }
    }

    @MainActor
    func restore() async {
        profile = await auth.restoreSession()
        if let profile {
            vaults = (try? await vaultService.loadVaults(for: profile.id)) ?? []
        }
        isRestoringSession = false
    }

    @MainActor
    func signIn(displayName: String) async throws {
        let p = try await auth.signIn(displayName: displayName)
        profile = p
        vaults = (try? await vaultService.loadVaults(for: p.id)) ?? []
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
