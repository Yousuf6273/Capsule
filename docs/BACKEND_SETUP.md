# Going live: connecting the Firebase backend

The app runs fully on a **local mock backend** out of the box (single device,
sample data). Every screen, the ceremony, the quiz and the tests work without
any account. This guide switches on the **real backend**: real accounts,
multi-user vaults that sync live between friends' phones, the server-enforced
unlock, and push notifications.

The client code for all of this is already in the repo
(`Capsule/Services/FirebaseServices.swift`, compile-gated behind
`#if canImport(FirebaseFirestore)`) and the server side is in `firebase/`.
Nothing needs to be written — only connected. Budget ~30–45 minutes.

> **Cost:** Firebase's free "Spark" tier covers a friend group comfortably
> (1 GiB storage, 50k reads/day). You will not be billed unless you
> explicitly upgrade to a paid plan. Push notifications to real iPhones
> additionally need an Apple Developer Program membership ($99/yr) for the
> APNs key — everything else works without it.

## 1. Create the Firebase project (5 min)

1. Go to <https://console.firebase.google.com> → **Add project** → name it
   `capsule` (or anything) → Analytics can be off.
2. In the project: **Build → Authentication → Get started → Sign-in method →
   Anonymous → Enable.** (The app starts users anonymously; Sign in with
   Apple can be linked later without losing accounts.)
3. **Build → Firestore Database → Create database** → start in *production
   mode* (the rules below replace the defaults) → pick a region near you
   (`europe-west3` Frankfurt is a good choice for Germany/NL).
4. **Build → Storage → Get started** → production mode → same region.
5. Click the **iOS+** icon on the project overview to register the app:
   bundle ID **`app.capsule.ios`** (must match Xcode). Download
   **`GoogleService-Info.plist`** — you'll need it in step 3.

## 2. Deploy the server side (10 min)

The rules are what make the vault trustworthy: sealed media is unreadable by
anyone — including the uploader — until a Cloud Function flips the vault to
`unlocked`. Clients can never write that field.

```bash
npm install -g firebase-tools
firebase login
cd firebase
firebase use --add            # select the project you just created
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,storage,functions
```

> Cloud Functions need the project on the **Blaze** (pay-as-you-go) plan to
> deploy — but Blaze still has the same free allowance; a friend group stays
> at $0. If you'd rather not add a card yet, skip functions for now: the app
> still syncs vaults and media live; only invite-code join, the scheduled
> date-unlock and push need functions. (Date unlock also runs client-side as
> a fallback, so the ceremony still triggers on time.)

## 3. Connect the iOS app (10 min)

1. In Xcode: **File → Add Package Dependencies…** → paste
   `https://github.com/firebase/firebase-ios-sdk` → Add Package → tick these
   products for the **Capsule** target:
   `FirebaseAuth`, `FirebaseFirestore`, `FirebaseStorage`,
   `FirebaseFunctions`, `FirebaseMessaging`.
2. Drag **`GoogleService-Info.plist`** into `Capsule/Resources/` in Xcode
   (tick *Copy items if needed* and the Capsule target).
3. Build & run. That's it — `BackendFactory` detects the plist and the SDK
   and switches every service over automatically. `AppModel.isLiveBackend`
   is `true`.

Verify: sign in on two devices (or a device + the simulator), create a vault
on one, join with the invite code on the other — it appears on both within a
second, and memories sealed on either phone show up in the other's count.

## 4. Push notifications (optional, 10 min + Apple Developer account)

1. Apple Developer → Certificates, IDs & Profiles → **Keys → +** → enable
   *Apple Push Notifications service (APNs)* → download the `.p8` key.
2. Firebase console → Project settings → **Cloud Messaging → Apple app
   configuration → Upload APNs auth key** (key file, Key ID, Team ID).
3. In Xcode → Capsule target → **Signing & Capabilities → + Capability →
   Push Notifications** (and *Background Modes → Remote notifications* is
   already in Info.plist).

The app asks for permission once after sign-in and stores the token in
`users/{uid}.fcmToken`; the functions notify members on **vault unlocked**,
**friend joined**, and **memory sealed** (throttled to one nudge per 15 min).

## What changes when the live backend is on

| Concern | Mock (default) | Live |
|---|---|---|
| Accounts | local profile | Firebase Anonymous Auth (Apple sign-in linkable) |
| Vaults | UserDefaults | Firestore, realtime listener per member |
| Sealed media | app container | Storage, **read-denied by rules until unlock** |
| Unlock | client timer | scheduled Cloud Function (client timer as fallback) |
| Invite codes | local lookup | `joinByInviteCode` callable (codes not enumerable) |
| Post-unlock | already local | media downloaded once to device (`syncMemories`) |
| Push | — | FCM via APNs |

## Troubleshooting

- **"Missing or insufficient permissions"** on a memory read before unlock is
  *correct* — that's the rules doing their job.
- Media not appearing after unlock → check `syncMemories` errors in the Xcode
  console; usually the Storage rules weren't deployed.
- Invite code "not found" → functions not deployed (see Blaze note above).
