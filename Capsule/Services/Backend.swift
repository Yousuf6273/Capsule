import Foundation
import UIKit

// ── Backend selection ────────────────────────────────────────────
// The app is written against protocols. This file decides which
// implementation is live:
//   • Firebase SDK present AND GoogleService-Info.plist bundled → live backend
//     (real accounts, realtime multi-user sync, server-enforced unlock, push)
//   • otherwise → the local mock stack (single device, sample data)
// Nothing else in the app knows or cares which one it got.

/// Optional capability: services that can stream live vault changes
/// (Firestore snapshot listeners). The mock stack doesn't need it.
protocol VaultObserving {
    func observeVaults(for userId: String) -> AsyncStream<[Vault]>
}

/// Optional capability: pull an unlocked vault's memories down to the
/// device so the ceremony and album work off local files.
protocol MemorySyncing {
    func syncMemories(vaultId: String) async throws -> [Memory]
}

/// Optional capability: register this device for push notifications and
/// associate its token with the signed-in user.
protocol PushRegistering {
    func registerForPush(userId: String) async
}

struct BackendServices {
    let auth: AuthServicing
    let vaults: VaultServicing
    let uploadTransport: UploadTransporting
    let isLive: Bool
}

enum BackendFactory {
    /// True when a Firebase config is bundled — the signal that the user
    /// has completed docs/BACKEND_SETUP.md.
    static var hasFirebaseConfig: Bool {
        Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
    }

    static func make() -> BackendServices {
        #if canImport(FirebaseFirestore)
        if hasFirebaseConfig {
            FirebaseBootstrap.configureIfNeeded()
            return BackendServices(auth: FirebaseAuthService(),
                                   vaults: FirebaseVaultService(),
                                   uploadTransport: FirebaseUploadTransport(),
                                   isLive: true)
        }
        #endif
        return BackendServices(auth: MockAuthService(),
                               vaults: MockVaultService(),
                               uploadTransport: MockUploadTransport(),
                               isLive: false)
    }
}

// ── App delegate (APNs plumbing) ─────────────────────────────────
// SwiftUI apps still need a UIApplicationDelegate to receive the APNs
// device token. With Firebase present it forwards to FCM; without it this
// is inert.

final class CapsuleAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        FirebasePush.shared.didReceiveAPNsToken(deviceToken)
        #endif
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Non-fatal: the app is fully usable without push.
    }
}
