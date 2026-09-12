# Capsule — Engineering Project Report

*Yousuf Ahmed · solo project · iOS / SwiftUI · July 2026*

This report documents the design, implementation and verification of Capsule, a native iOS application, in the structure of an engineering project write-up: problem, requirements, design, implementation, verification, evaluation, and lessons learned. It is written to be read by someone who has not seen the code.

---

## 1. Problem statement

Friend groups on trips already perform a ritual: they create a group chat named "do not open", upload their photos and videos into it for the duration of the trip, and open it together at the end. The tools they use were not built for this. Nothing enforces "do not open" — anyone can scroll up. Nothing makes the opening an *event* — it is a scrollable list. And the content lives in a chat that is deleted or buried within weeks.

**Goal:** build a product that makes the "do not open" promise technically true, turns the opening into a shared cinematic moment, and keeps the memories permanently.

## 2. Requirements

Derived from the problem and refined through three rounds of use-testing on a real device.

**Functional**
- R1 Create a vault with a name, cover photo, members and an *unlock condition* (a date-time, or "when every member marks ready").
- R2 Members add photos and **primarily videos** throughout the trip. After upload nobody — including the uploader — can view the content.
- R3 The vault unlocks automatically at the unlock moment, whether or not the app is open, and every member sees the same state.
- R4 The reveal is a produced, timed sequence (target 30–60 s of "intro" before the first photo), not a gallery.
- R5 After the reveal the content is permanently browsable and the reveal is replayable.
- R6 Uploads must tolerate bad connectivity (trips) — queue locally, sync later, never fail silently.

**Non-functional**
- N1 The lock must be enforced server-side; client-side hiding is not acceptable.
- N2 Navigation must never dead-end: every screen has a way back, and "back" returns to Home rather than an intermediate step.
- N3 Each trip develops its own visual identity from its cover photo; the app shell stays consistent.
- N4 The app must be verifiable by automated end-to-end tests, not only by hand.

## 3. System design

### 3.1 Architecture

The app is a single SwiftUI target organised as `App → Features → Services → Models`, with a design-system layer shared by all features. State lives in one `@Observable` `AppModel` (vaults, profile) plus two disk-backed stores (`MemoryStore` for memory records, `UploadQueue` for pending uploads).

All I/O goes through three protocols — `AuthServicing`, `VaultServicing`, `UploadTransporting` — with two implementations each: a **local mock stack** (UserDefaults + app container; single device) and a **Firebase stack** (Auth, Firestore, Storage, Functions, Messaging). `BackendFactory` selects at launch based on whether the Firebase SDK and configuration are present. Optional capabilities (`VaultObserving` for realtime listeners, `MemorySyncing` for post-unlock download, `PushRegistering`) are discovered by protocol conformance so the mock stack does not need to fake them.

### 3.2 The vault lifecycle (state machine)

```
collecting ──(date reached | everyone ready)──▶ unlocked ──(ceremony finished)──▶ unlocked+revealed
     └──(legacy/manual)──▶ sealed ──(date reached)──▶ unlocked
```

`VaultRouter` is a pure function of `(state, hasCompletedReveal)` → screen. Because the router re-evaluates whenever the model changes, an unlock never needs a navigation push: the countdown screen is *replaced* by the ceremony in place, and finishing the ceremony replaces it with the album. This also gives N2 for free — the navigation stack is always exactly one level deep.

An earlier iteration required a manual "Done" step to move `collecting → sealed`. Field testing showed this was a design error (§7.2): a user tapped "Done" before adding anything and was locked out of an empty vault. The final design keeps the vault open for adding until the unlock moment itself; `sealed` remains only for legacy/sample data.

### 3.3 The trust boundary

The mock stack cannot enforce anything (one device). In the live stack the enforcement is entirely in Firebase Security Rules, which are evaluated server-side:

- `vaults/{id}/memories/*` — `create` allowed for members while `state == collecting`; `read` allowed only when `state == unlocked`.
- Storage `vaults/{id}/media/*` — `read` allowed only when the vault document's `state == unlocked` (cross-service rule).
- `state` and `unlockedAt` are excluded from every client write. The only writer is a Cloud Function: a scheduled job for date unlocks, a callable for "everyone ready" that verifies every member's flag in a transaction.
- Locked thumbnails are generated client-side at upload as 12×12-pixel derivatives (irreversibly information-poor) and stored in a separately-readable path, so the collecting grid can show "your drops" without exposing anything.

Consequence: even a modified client cannot fetch sealed media. The reveal is synchronised because every client holds a Firestore listener on its vaults and the function's single write reaches all of them within listener latency.

### 3.4 Time handling

Unlock is driven by wall-clock time. Three independent mechanisms cover every situation:
1. On the countdown screen a `TimelineView` ticks once per second; when `target <= now` it fires a one-shot `onReached` (with `initial: true`, see §7.1) → fireworks → unlock.
2. The same one-shot exists on the compact chip in the collecting screen and Home hero.
3. `unlockExpiredVaults()` sweeps all vaults at launch and on every foreground transition, for the case where the moment passed while the app was closed.

In the live stack the Cloud Function is authoritative and (1)–(3) act as a latency-free fallback.

### 3.5 The Trip Replay

A coordinator owns a phase machine `unseal → intro → numbers → journey → finale`. Two pieces are algorithmic:

**Dynamic stat selection.** Twelve candidate statistics are computed from the memory set (totals, busiest day, sunset-hour count, earliest/latest capture by clock time, longest daily streak, most common hour, "hidden gems" = uploaded > 6 h after capture, …). Each carries a score derived from its data (e.g. sunset count scores `4 + min(4, n/3)` and is dropped below 2 photos). Three mandatory slides plus the top-scoring candidates give 5–8 slides — enough to feel personal, short enough that people watch rather than skip.

**Journey building.** Memories are grouped by calendar day into chapters (Arrival, Day Two, …, The Last Day, Goodbye). Every video is included (they are the emotional core of the vault); photos are curated to three per day (first, a captioned middle, last). A "Sunset" interlude is inserted when a day has ≥2 captures between 18:00–20:59. Slide durations: chapter 2.4 s, photo 4 s, video = clamp(actual length, 4, 30) s with audio.

### 3.6 Theming

At vault creation the cover photo is downsampled to 64 px and clustered with Core Image's `CIKMeans` (k = 8, 8 passes, perceptual). Clusters are scored for "vibrancy" (saturation-weighted, peaking at mid-lightness) to choose a primary; the secondary maximises hue and brightness contrast against it. The pair is stored on the vault and injected through the SwiftUI environment; a fallback palette pool covers muddy images.

## 4. Implementation notes

- **Language/stack:** Swift 5, SwiftUI with the Observation framework, PhotosUI, AVFoundation/AVKit, Core Image, Canvas + TimelineView for particle systems (golden dust, fireworks), XCTest. Cloud Functions in TypeScript.
- **Size:** 34 Swift source files (~4,300 lines), 2 test files (~400 lines), 3 rule/function files.
- **Video pipeline:** the picker's `UTType` is preserved as the file extension (AVFoundation trusts extensions — an `.mp4` saved as `.mov` fails to decode, a bug found in testing); poster frames via `AVAssetImageGenerator` sampled at 0.4 s to skip black lead-in; `AVAudioSession` set to `.playback` so sound survives the silent switch.
- **Offline queue:** items are persisted as JSON with the staged file names; a `NWPathMonitor` re-triggers draining; failures back off exponentially and never drop items.

## 5. Verification

Manual testing alone proved unreliable — the simulator's synthetic input was flaky and two of the most important bugs (§7) were only visible in specific timing conditions. The project therefore has an **XCUITest suite that drives the real application** with deterministic state (`--uitest-reset` wipes persistence; an environment variable sets the sample vault's unlock time so timing tests run in seconds instead of days).

| Test | What it proves |
|---|---|
| `testAuthHomeAndSheets` | entrance → Home; create and join sheets open and close |
| `testCollectingDoneReturnsHome` | "Done" returns Home *and the vault stays open for adding* |
| `testWaitingScreenAndBack` | countdown screen; back lands on Home, not a prior step |
| `testUnlockCeremonySkipAndAlbum` | unlock → ceremony → skip → album → detail → back to Home |
| `testCeremonyPhasesAdvance` | unseal → intro → numbers advance without taps |
| `testCountdownReachingZeroAutoUnlocks` | a 12 s countdown unlocks by itself (R3) |
| `testAlreadyExpiredCountdownUnlocksOnFirstAppearance` | regression for §7.1 |
| `testSoloQuizFromAlbum` | full quiz; reveal is immediate after answering |
| `testWrappedCoverFromAlbum`, `testReplayCeremonyFromAlbum` | covers open and return correctly |
| `testWrappedTabNavigation` | list → vault → back to shell |
| `ScreenshotTour` | walks every screen; generates the README images |

All pass on iPhone 17 Pro / iOS 26.5 (`xcodebuild test`). The suite runs in ~4 minutes and has caught three regressions during development.

## 6. Evaluation against requirements

| Req | Result |
|---|---|
| R1, R2, R4, R5, N3 | Met in full. |
| R6 | Met: queue persists across launches; offline banner; verified by disabling network. |
| R3, N1 | Designed and implemented (rules, functions, listeners, sync). **Not yet exercised live** — deploying requires a Firebase account belonging to the owner; a setup guide is included. On a single device the client-side timer provides R3. |
| N2 | Met; enforced by tests. |
| N4 | Met: 12 end-to-end scenarios. |

**Known limitations.** No live multi-device test has been run yet. Push notifications need an Apple Developer Program key. Memory storage is unbounded on device. Video slides cap at 30 s. The quiz's "friends' answers" are simulated (recorded) until the backend is live.

## 7. Notable bugs and what they taught

### 7.1 The countdown that never fired (SwiftUI `onChange` semantics)
The countdown used `.onChange(of: isPast)` to detect reaching zero. `onChange` fires on a *transition*. If the unlock time had already passed when the screen appeared, `isPast` was `true` on the first frame — there was no `false → true` edge, so nothing fired and the screen sat at `00:00:00` indefinitely. The fix is `onChange(of:initial: true)`, which also evaluates on first appearance. **Lesson:** edge-triggered and level-triggered detection are different things; a system that must act on a *condition* rather than a *change* needs a level check at start-up. A regression test now launches with the time 30 s in the past.

### 7.2 "Done" that sealed the vault (a model error, not a code error)
An intermediate fix made "Done for now" move the vault to `sealed`, because the original mock-up's flow was collecting → "done" → countdown. A tester tapped "Done" with zero memories and could never add any. The real model is that *the unlock moment* closes the vault, not a button. **Lesson:** the state machine must be derived from the domain (a trip), not from the order of screens in a mock-up.

### 7.3 Sealed vaults vanishing from Home
Home had rows for "filling up" and "ready to relive" and a single hero card. A second sealed vault had no row and disappeared. Surfaced by the test suite as soon as sealing became possible mid-session. **Lesson:** enumerate every state × every list; a UI that shows "the most important one" still needs a home for the rest.

### 7.4 File extensions and AVFoundation
An MP4 written to disk as `.mov` decoded as garbage. AVFoundation uses the extension as the container hint. Preserving the picker's UTType fixed both poster extraction and playback.

### 7.5 Testing the untestable
Synthetic mouse input into the iOS Simulator drifted by tens of points depending on window state and became impossible when the Mac's display locked. Switching to XCUITest — input injected inside the simulator — made verification deterministic and unattended. **Lesson:** invest in the test harness early; it paid for itself within a day.

## 8. Future work

1. Deploy the Firebase project and run the first live two-device test (guide: `docs/BACKEND_SETUP.md`).
2. Sign in with Apple linked onto the anonymous account.
3. Real multiplayer quiz over Firestore (the `QuizEngine` already separates recorded from live answers).
4. Media lifecycle: thumbnails in cloud, originals evicted from device after export.
5. TestFlight distribution to a real friend group and a trip-long field test.

---
*Repository: <https://github.com/Yousuf6273/Capsule>. Built with Xcode 26 / iOS 26 SDK, targeting iOS 17+.*
