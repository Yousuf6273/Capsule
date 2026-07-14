# Capsule

Friends seal trip **videos and photos** into a locked vault — the "do not open until the trip ends" group, productised. **Nobody — including the uploader — can view content until the unlock condition is met.** Then everyone experiences the Trip Replay together: unseal → intro card → Trip by the Numbers → the Journey → finale → gallery.

Design language: deep charcoal, rich purple breath, champagne gold, drifting golden dust. Every screen is a chapter, not a dashboard — Spotify Wrapped × Apple Journal × a keepsake.

## Running

1. Install Xcode 16+ (the project uses the synchronized-folder format).
2. `open Capsule.xcodeproj`, select an iOS 17+ simulator, hit Run.
3. The app currently runs against **mock services** (local persistence, sample vaults matching the mockup) so every flow is testable without a backend. Sign in with any name.

Fonts (Unbounded, Inter, JetBrains Mono) are bundled in `Capsule/Resources/Fonts` (SIL OFL).

## Architecture

- `DesignSystem/` — three-font system, fixed shell tokens, **`TripTheme`** (two colors extracted per trip via `CIKMeans`, injected through `@Environment(\.tripTheme)`; all trip screens re-theme, the shell doesn't), glass components.
- `Models/` — `Vault`, `Member`, `Memory`, `UnlockCondition`.
- `Services/` — `AuthServicing` / `VaultServicing` protocols. `Mock*` implementations back the UI now; Firebase implementations slot in behind the same interfaces (milestone 3).
- `Features/` — Auth, Shell (custom glass bottom bar), Home, Create (cover photo → live theme extraction), Join (invite code + `capsule.app/j/CODE` deep link), Vault (Collecting / Waiting / Opened routing).
- `firebase/` — the **server-side lock**: Firestore + Storage rules deny all reads of sealed media (for everyone) until a Cloud Function — the only writer of `vault.state` — flips it to `unlocked`. Functions: scheduled date unlock, everyone-ready unlock, invite-code join, recap-stats computation at unlock, FCM notifications.

### Firebase setup (when ready for milestone 3)

```sh
npm i -g firebase-tools
firebase login && firebase projects:create capsule-app
cd firebase && firebase deploy --only firestore:rules,storage,functions
```

Then add the Firebase iOS SDK via SPM, drop `GoogleService-Info.plist` into `Capsule/Resources`, and implement `FirebaseAuthService` / `FirebaseVaultService`.

## Milestones

1. ✅ Auth, create/join vault, invite flow (mock-backed)
2. ✅ Blind contribution + offline queue (`UploadQueue`: instant local sealing, disk-persisted, NWPathMonitor drain)
3. ✅ Server-enforced unlock — rules/functions written; client `FirebaseServices.swift` compiles automatically once the Firebase SDK is added (`#if canImport`)
4. ✅ Color extraction + dynamic theming (`ThemeExtractor`, `TripTheme`)
5. ✅ Unlock door sequence + pre-reveal recap teaser (mockup timing: text 0.3s → light 1.4s → doors 2.0s)
6. ✅ Reveal slideshow (develop effect, ken-burns, story bars, tap navigation)
7. ✅ Quiz mode (prediction, guess-who-took, which-day; simulated friends via `QuizTransporting` — Firestore listener transport slots in)
8. ✅ Wrapped screen + shareable card (`ImageRenderer` → `ShareLink`)
9. ✅ Permanent day-grouped album + memory detail

### Beyond the original milestones

- **Trip Replay** (replaces doors/teaser/slideshow): `UnsealView` (tap-to-unseal vault dial, golden bloom, dust burst) → `IntroCardView` (blurred hero + glass title card) → `NumbersView` (5-8 dynamically-scored stat slides with eased count-ups) → `JourneyView` (chapter cards + highlights, ken-burns photos, **looping muted video slides**) → `FinaleView` ("Until the next adventure.") → gallery. Quiz + wrapped live in the gallery toolbar. A quiet ✕ appears after 4s to skip the ceremony.
- **Video-first pipeline**: picker accepts videos, `UploadQueue` stages originals with their true container extension and derives locked thumbs from the opening frame (`MediaPoster`), `MemoryStore` serves poster frames + playable URLs, album cells carry a play badge, detail view plays with sound.
- **App-wide atmosphere**: `ShellBackground` (charcoal + purple/gold/coral glows + `GoldenDust`), `FloatIn` staggered entrances, `PressableCardStyle` spring presses, `GoldButtonStyle` champagne CTAs, floating glass nav pill, staged auth entrance.

**Demo path in the simulator:** sign in → tap the Kefalonia hero → "Skip ahead — simulate unlock ✨" (DEBUG-only button) → Tap to Unseal → intro → numbers → journey → finale → gallery.

### Going live (the remaining backend step)

The app runs fully on the mock stack. To go live: create a Firebase project, deploy `firebase/`, add the Firebase iOS SDK via SPM (Auth, Firestore, Storage, Functions, Messaging), drop in `GoogleService-Info.plist`, and swap the `AppModel()` initializer to the Firebase services. Push notifications additionally need an Apple Developer account + APNs key uploaded to FCM.
