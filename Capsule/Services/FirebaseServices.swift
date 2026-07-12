// ── Milestone 3: live backend implementations ────────────────────
// Compiled only once the Firebase iOS SDK is added via SPM
// (FirebaseAuth, FirebaseFirestore, FirebaseStorage, FirebaseFunctions,
// FirebaseMessaging) and GoogleService-Info.plist is dropped into Resources.
// Until then this file is inert and the mock stack runs.
//
// Server-side enforcement lives in firebase/firestore.rules,
// firebase/storage.rules and firebase/functions — clients here NEVER decide
// unlock state; they just read what the rules let them read.

#if canImport(FirebaseFirestore)

import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import Foundation
import UIKit

enum FirebaseBootstrap {
    static func configureIfNeeded() {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
    }
}

final class FirebaseAuthService: AuthServicing {
    func restoreSession() async -> UserProfile? {
        FirebaseBootstrap.configureIfNeeded()
        guard let user = Auth.auth().currentUser else { return nil }
        let doc = try? await Firestore.firestore().document("users/\(user.uid)").getDocument()
        let name = doc?.data()?["displayName"] as? String ?? user.displayName ?? "You"
        let colorIndex = doc?.data()?["avatarColorIndex"] as? Int ?? 0
        return UserProfile(id: user.uid, displayName: name, avatarColorIndex: colorIndex)
    }

    /// Anonymous auth to start; Sign in with Apple can be linked on top later
    /// without losing the uid (Auth.link(with:)).
    func signIn(displayName: String) async throws -> UserProfile {
        FirebaseBootstrap.configureIfNeeded()
        let result = try await Auth.auth().signInAnonymously()
        let profile = UserProfile(id: result.user.uid, displayName: displayName, avatarColorIndex: 0)
        try await Firestore.firestore().document("users/\(profile.id)").setData([
            "displayName": displayName,
            "avatarColorIndex": 0,
            "createdAt": FieldValue.serverTimestamp(),
        ], merge: true)
        return profile
    }

    func signOut() async {
        try? Auth.auth().signOut()
    }
}

final class FirebaseVaultService: VaultServicing {
    private var db: Firestore { Firestore.firestore() }

    func loadVaults(for userId: String) async throws -> [Vault] {
        let snapshot = try await db.collection("vaults")
            .whereField("memberIds", arrayContains: userId)
            .getDocuments()
        return snapshot.documents.compactMap { Self.vault(from: $0, currentUserId: userId) }
    }

    func createVault(name: String, unlockCondition: UnlockCondition,
                     coverImageFileName: String?, theme: TripTheme,
                     creator: UserProfile) async throws -> Vault {
        let ref = db.collection("vaults").document()
        let code = MockVaultService.generateInviteCode()

        var data: [String: Any] = [
            "name": name,
            "state": "collecting",
            "memberIds": [creator.id],
            "memberNames": [creator.id: creator.displayName],
            "readyMemberIds": [],
            "memoryCount": 0,
            "themePrimary": theme.primaryHex,
            "themeSecondary": theme.secondaryHex,
            "inviteCode": code,
            "createdAt": FieldValue.serverTimestamp(),
        ]
        switch unlockCondition {
        case .date(let d):
            data["unlockCondition"] = "date"
            data["unlockAt"] = Timestamp(date: d)
        case .everyoneReady:
            data["unlockCondition"] = "everyoneReady"
        }
        try await ref.setData(data)
        // Invite-code mapping is function/admin territory in production; writing
        // it here requires relaxing rules or (better) a `createVault` callable.
        try await Functions.functions().httpsCallable("registerInviteCode")
            .call(["vaultId": ref.documentID, "code": code])

        if let coverImageFileName,
           let image = LocalStore.image(named: coverImageFileName),
           let jpeg = image.jpegData(compressionQuality: 0.85) {
            _ = try await Storage.storage().reference(withPath: "vaults/\(ref.documentID)/cover.jpg")
                .putDataAsync(jpeg)
        }

        return Vault(
            id: ref.documentID, name: name, emojiFlag: nil, subtitle: nil,
            coverImageFileName: coverImageFileName, state: .collecting,
            unlockCondition: unlockCondition, theme: theme,
            members: [Member(id: creator.id, displayName: creator.displayName,
                             avatarColorIndex: 0, isCurrentUser: true)],
            memoryCount: 0, createdAt: .now, unlockedAt: nil, inviteCode: code)
    }

    func joinVault(inviteCode: String, user: UserProfile) async throws -> Vault {
        let result = try await Functions.functions().httpsCallable("joinByInviteCode")
            .call(["code": inviteCode])
        guard let dict = result.data as? [String: Any],
              let vaultId = dict["vaultId"] as? String else {
            throw CapsuleError.inviteCodeNotFound
        }
        let doc = try await db.document("vaults/\(vaultId)").getDocument()
        guard let vault = Self.vault(from: doc, currentUserId: user.id) else {
            throw CapsuleError.vaultNotFound
        }
        return vault
    }

    func markReady(vaultId: String, userId: String) async throws -> Vault {
        _ = try await Functions.functions().httpsCallable("markReady")
            .call(["vaultId": vaultId])
        let doc = try await db.document("vaults/\(vaultId)").getDocument()
        guard let vault = Self.vault(from: doc, currentUserId: userId) else {
            throw CapsuleError.vaultNotFound
        }
        return vault
    }

    func update(vault: Vault) async throws {
        // Rules restrict which fields members may touch; state changes are
        // silently ignored server-side (function-only).
        try await db.document("vaults/\(vault.id)").updateData([
            "name": vault.name,
            "hasCompletedReveal": vault.hasCompletedReveal,
        ])
    }

    // ── Mapping ──────────────────────────────────────────────────

    private static func vault(from doc: DocumentSnapshot, currentUserId: String) -> Vault? {
        guard let data = doc.data(),
              let name = data["name"] as? String,
              let stateRaw = data["state"] as? String,
              let state = VaultState(rawValue: stateRaw),
              let memberIds = data["memberIds"] as? [String] else { return nil }

        let memberNames = data["memberNames"] as? [String: String] ?? [:]
        let readyIds = Set(data["readyMemberIds"] as? [String] ?? [])
        let members = memberIds.enumerated().map { i, uid in
            Member(id: uid,
                   displayName: memberNames[uid] ?? "Friend",
                   avatarColorIndex: i,
                   isReady: readyIds.contains(uid),
                   isCurrentUser: uid == currentUserId)
        }

        let condition: UnlockCondition
        if data["unlockCondition"] as? String == "everyoneReady" {
            condition = .everyoneReady
        } else if let ts = data["unlockAt"] as? Timestamp {
            condition = .date(ts.dateValue())
        } else {
            condition = .everyoneReady
        }

        return Vault(
            id: doc.documentID,
            name: name,
            emojiFlag: data["emojiFlag"] as? String,
            subtitle: data["subtitle"] as? String,
            coverImageFileName: nil, // covers stream from Storage in the live stack
            state: state,
            unlockCondition: condition,
            theme: TripTheme(primaryHex: data["themePrimary"] as? String ?? "6B46E0",
                             secondaryHex: data["themeSecondary"] as? String ?? "D9B26A"),
            members: members,
            memoryCount: data["memoryCount"] as? Int ?? 0,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? .now,
            unlockedAt: (data["unlockedAt"] as? Timestamp)?.dateValue(),
            inviteCode: data["inviteCode"] as? String ?? "",
            hasCompletedReveal: data["hasCompletedReveal"] as? Bool ?? false)
    }
}

/// Storage-backed upload transport for the offline queue.
struct FirebaseUploadTransport: UploadTransporting {
    func upload(_ item: PendingUpload, uploaderId: String) async throws -> Memory {
        let storage = Storage.storage()
        let db = Firestore.firestore()

        let originalURL = LocalStore.url(for: item.originalFileName)
        let thumbURL = LocalStore.url(for: item.lockedThumbFileName)

        // 1. Locked thumb first (member-visible), then the sealed original.
        _ = try await storage.reference(withPath: "vaults/\(item.vaultId)/lockedThumbs/\(item.id)")
            .putFileAsync(from: thumbURL)
        _ = try await storage.reference(withPath: "vaults/\(item.vaultId)/media/\(item.id)")
            .putFileAsync(from: originalURL)

        // 2. Metadata doc — rules make this unreadable until unlock.
        try await db.document("vaults/\(item.vaultId)/memories/\(item.id)").setData([
            "uploaderId": uploaderId,
            "mediaType": item.mediaType.rawValue,
            "capturedAt": Timestamp(date: item.capturedAt),
            "uploadedAt": FieldValue.serverTimestamp(),
            "byteSize": item.byteSize,
        ])
        try await db.document("vaults/\(item.vaultId)/lockedThumbs/\(item.id)").setData([
            "uploaderId": uploaderId,
            "createdAt": FieldValue.serverTimestamp(),
        ])

        return Memory(
            id: item.id, vaultId: item.vaultId, uploaderId: uploaderId,
            mediaType: item.mediaType,
            lockedThumbFileName: item.lockedThumbFileName,
            mediaFileName: item.originalFileName,
            capturedAt: item.capturedAt, uploadedAt: .now,
            caption: nil, byteSize: item.byteSize)
    }
}

#endif
