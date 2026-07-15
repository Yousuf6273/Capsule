import Foundation

// ── Mock implementations ─────────────────────────────────────────
// Persist to UserDefaults/disk so the app is usable end-to-end before
// the Firebase backend lands. Sample vaults mirror the mockup data.

final class MockAuthService: AuthServicing {
    private let key = "capsule.profile"

    func restoreSession() async -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    func signIn(displayName: String) async throws -> UserProfile {
        let profile = UserProfile(id: UUID().uuidString,
                                  displayName: displayName,
                                  avatarColorIndex: 0)
        UserDefaults.standard.set(try JSONEncoder().encode(profile), forKey: key)
        return profile
    }

    func signOut() async {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

final class MockVaultService: VaultServicing {
    private let key = "capsule.vaults"

    private func persist(_ vaults: [Vault]) {
        if let data = try? JSONEncoder().encode(vaults) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func stored() -> [Vault]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([Vault].self, from: data)
    }

    func loadVaults(for userId: String) async throws -> [Vault] {
        if let stored = stored() { return stored }
        let samples = Self.sampleVaults(currentUserId: userId)
        persist(samples)
        return samples
    }

    func createVault(name: String, unlockCondition: UnlockCondition,
                     coverImageFileName: String?, theme: TripTheme,
                     creator: UserProfile) async throws -> Vault {
        var vaults = stored() ?? []
        let vault = Vault(
            id: UUID().uuidString,
            name: name,
            emojiFlag: nil,
            subtitle: nil,
            coverImageFileName: coverImageFileName,
            state: .collecting,
            unlockCondition: unlockCondition,
            theme: theme,
            members: [Member(id: creator.id, displayName: creator.displayName,
                             avatarColorIndex: creator.avatarColorIndex,
                             isCurrentUser: true)],
            memoryCount: 0,
            createdAt: .now,
            unlockedAt: nil,
            inviteCode: Self.generateInviteCode())
        vaults.insert(vault, at: 0)
        persist(vaults)
        return vault
    }

    func joinVault(inviteCode: String, user: UserProfile) async throws -> Vault {
        var vaults = stored() ?? []
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let idx = vaults.firstIndex(where: { $0.inviteCode == code }) else {
            throw CapsuleError.inviteCodeNotFound
        }
        if !vaults[idx].members.contains(where: { $0.id == user.id }) {
            vaults[idx].members.append(Member(id: user.id, displayName: user.displayName,
                                              avatarColorIndex: vaults[idx].members.count,
                                              isCurrentUser: true))
        }
        persist(vaults)
        return vaults[idx]
    }

    func markReady(vaultId: String, userId: String) async throws -> Vault {
        var vaults = stored() ?? []
        guard let idx = vaults.firstIndex(where: { $0.id == vaultId }) else {
            throw CapsuleError.vaultNotFound
        }
        if let m = vaults[idx].members.firstIndex(where: { $0.id == userId }) {
            vaults[idx].members[m].isReady = true
        }
        // "Everyone ready" unlock is decided server-side in the real backend.
        if case .everyoneReady = vaults[idx].unlockCondition,
           vaults[idx].members.allSatisfy(\.isReady) {
            vaults[idx].state = .unlocked
            vaults[idx].unlockedAt = .now
        }
        persist(vaults)
        return vaults[idx]
    }

    func update(vault: Vault) async throws {
        var vaults = stored() ?? []
        guard let idx = vaults.firstIndex(where: { $0.id == vault.id }) else {
            throw CapsuleError.vaultNotFound
        }
        vaults[idx] = vault
        persist(vaults)
    }

    static func generateInviteCode() -> String {
        let alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789" // no easily-confused chars
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }

    // ── Sample data (mirrors the mockup) ─────────────────────────

    static func sampleVaults(currentUserId: String) -> [Vault] {
        let you = Member(id: currentUserId, displayName: "You", avatarColorIndex: 0,
                         isReady: true, isCurrentUser: true)
        func friends(_ names: [String], readyThrough: Int = .max) -> [Member] {
            names.enumerated().map { i, n in
                Member(id: "friend-\(n.lowercased())", displayName: n,
                       avatarColorIndex: i + 1, isReady: i < readyThrough)
            }
        }

        // Test hook only: lets UI tests verify the countdown-reaches-zero →
        // auto-unlock path without waiting 62 real hours.
        var kefaloniaUnlock = Calendar.current.date(byAdding: .hour, value: 62, to: .now)!
        #if DEBUG
        if let secondsArg = ProcessInfo.processInfo.environment["CAPSULE_TEST_UNLOCK_SECONDS"],
           let seconds = TimeInterval(secondsArg) {
            kefaloniaUnlock = Date.now.addingTimeInterval(seconds)
        }
        #endif

        let kefalonia = Vault(
            id: "sample-kefalonia", name: "Kefalonia", emojiFlag: "🇬🇷",
            subtitle: "Kefalonia, July", coverImageFileName: nil,
            state: .sealed,
            unlockCondition: .date(kefaloniaUnlock),
            theme: TripTheme(primaryHex: "6B46E0", secondaryHex: "D9B26A"),
            members: [you] + friends(["Maya", "Rhys", "Sana", "Leo", "Ivy", "Tom", "Ana"], readyThrough: 6),
            memoryCount: 438, createdAt: .now.addingTimeInterval(-86400 * 11),
            unlockedAt: nil, inviteCode: "8QK2VN")

        let tokyo = Vault(
            id: "sample-tokyo", name: "Tokyo", emojiFlag: "🇯🇵",
            subtitle: "Tokyo, October", coverImageFileName: nil,
            state: .collecting,
            unlockCondition: .everyoneReady,
            theme: TripTheme(primaryHex: "6B46E0", secondaryHex: "FF6F5E"),
            members: [you] + friends(["Maya", "Rhys", "Sana", "Leo"], readyThrough: 2),
            memoryCount: 612, createdAt: .now.addingTimeInterval(-86400 * 5),
            unlockedAt: nil, inviteCode: "TKY0J1")

        let dubai = Vault(
            id: "sample-dubai", name: "Dubai", emojiFlag: "🇦🇪",
            subtitle: "Dubai, December", coverImageFileName: nil,
            state: .collecting,
            unlockCondition: .date(Calendar.current.date(byAdding: .day, value: 21, to: .now)!),
            theme: TripTheme(primaryHex: "D9B26A", secondaryHex: "201E25"),
            members: [you] + friends(["Maya", "Rhys", "Ivy", "Tom"], readyThrough: 1),
            memoryCount: 355, createdAt: .now.addingTimeInterval(-86400 * 2),
            unlockedAt: nil, inviteCode: "DXB44K")

        let heilbronn = Vault(
            id: "sample-heilbronn", name: "Heilbronn", emojiFlag: "🇩🇪",
            subtitle: "Heilbronn weekend", coverImageFileName: nil,
            state: .unlocked,
            unlockCondition: .date(.now.addingTimeInterval(-86400 * 21)),
            theme: TripTheme(primaryHex: "2FA97A", secondaryHex: "6B46E0"),
            members: [you] + friends(["Maya", "Rhys", "Sana"]),
            memoryCount: 28, createdAt: .now.addingTimeInterval(-86400 * 40),
            unlockedAt: .now.addingTimeInterval(-86400 * 21), inviteCode: "HLB7WX",
            hasCompletedReveal: true)

        return [kefalonia, tokyo, dubai, heilbronn]
    }
}
