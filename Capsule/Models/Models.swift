import Foundation

// ── Vault ────────────────────────────────────────────────────────

enum VaultState: String, Codable {
    case collecting   // members can add memories
    case sealed       // adding closed, waiting on the unlock condition
    case unlocked     // reveal available, then permanent album
}

enum UnlockCondition: Codable, Equatable, Hashable {
    case date(Date)
    case everyoneReady
}

struct Vault: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String                 // "Kefalonia"
    var emojiFlag: String?           // "🇬🇷"
    var subtitle: String?            // "Kefalonia, July"
    var coverImageFileName: String?  // local file in app container (server path later)
    var state: VaultState
    var unlockCondition: UnlockCondition
    var theme: TripTheme
    var members: [Member]
    var memoryCount: Int
    var createdAt: Date
    var unlockedAt: Date?
    var inviteCode: String           // e.g. "8QK2VN"
    var hasCompletedReveal: Bool = false

    var displayName: String {
        if let emojiFlag { return "\(emojiFlag) \(name)" }
        return name
    }

    var unlockDate: Date? {
        if case .date(let d) = unlockCondition { return d }
        return nil
    }

    var readyCount: Int { members.filter(\.isReady).count }

    var inviteURL: URL { URL(string: "https://capsule.app/j/\(inviteCode)")! }
}

// ── People ───────────────────────────────────────────────────────

struct Member: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var displayName: String
    var avatarColorIndex: Int
    var isReady: Bool = false
    var isCurrentUser: Bool = false

    var initial: String { String(displayName.prefix(1)).uppercased() }
}

struct UserProfile: Codable, Equatable {
    let id: String
    var displayName: String
    var avatarColorIndex: Int
}

// ── Memories ─────────────────────────────────────────────────────

enum MediaType: String, Codable {
    case photo, video
}

struct Memory: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var vaultId: String
    var uploaderId: String
    var mediaType: MediaType
    var lockedThumbFileName: String? // blurred derivative, viewable while sealed
    var mediaFileName: String?       // original — server refuses this until unlock
    var capturedAt: Date
    var uploadedAt: Date
    var caption: String?
    var byteSize: Int64
}
