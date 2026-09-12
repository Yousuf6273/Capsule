# Presenting Capsule in university applications

*For Mechanical / Aerospace Engineering programmes in Germany and the Netherlands.*

Capsule is a software project, and you are applying to build aircraft and machines. The honest way to use it is **not** "I made an app, therefore engineering" — it is evidence of *how you work*: you saw a real problem, wrote requirements, designed a system, built it, tested it rigorously, found your own mistakes and fixed the model, and documented it. That is the engineering method, and admissions readers and interviewers at TU Delft, TU/e, TUM, RWTH, KIT or Stuttgart recognise it regardless of domain.

> **Where it actually helps.** Bachelor admission at German universities (TUM, RWTH, KIT, Stuttgart) is mostly formal: Abitur/qualification, sometimes an aptitude procedure (TUM's *Eignungsfeststellungsverfahren*, which can include a motivation letter and interview). Dutch programmes with *numerus fixus* selection (TU Delft Aerospace, TU/e Mechanical) use motivation letters, assignments or tests. So the project matters most in **motivation letters, selection assignments and interviews** — not as a substitute for grades. Check each programme's current procedure; they change.

---

## 1. The one-paragraph version (motivation letter)

Use, adapt, shorten. Keep the claims exactly as true as they are.

**English**

> Alongside school I designed and built *Capsule*, a native iOS app that turns a habit my friends already have — a "do not open" group chat for trip videos — into a real product. I wrote the requirements, designed a state machine for the vault's lifecycle, implemented the app in Swift with a custom design system and a five-stage animated "reveal" sequence, and wrote a twelve-scenario automated test suite that drives the real application end to end. The most instructive moment was a countdown that silently never fired: I traced it to the difference between edge-triggered and level-triggered detection in the UI framework, fixed the model rather than the symptom, and added a regression test. The project is on GitHub with a full engineering report. It taught me that the interesting part of engineering is rarely the first version — it is the disciplined loop of specifying, building, measuring and correcting, which is exactly what draws me to [aerospace / mechanical] engineering.

**Deutsch** (für TUM / RWTH / KIT / Stuttgart, falls ein Motivationsschreiben verlangt wird)

> Neben der Schule habe ich *Capsule* entworfen und entwickelt, eine native iOS-App, die eine Gewohnheit meines Freundeskreises — einen „nicht öffnen“-Gruppenchat für Reisevideos — in ein echtes Produkt übersetzt. Ich habe die Anforderungen formuliert, einen Zustandsautomaten für den Lebenszyklus des „Tresors“ entworfen, die App in Swift mit eigenem Designsystem und einer fünfstufigen animierten Enthüllungssequenz umgesetzt und eine automatisierte End-to-End-Testsuite mit zwölf Szenarien geschrieben. Am lehrreichsten war ein Countdown, der stillschweigend nie auslöste: Ich habe die Ursache auf den Unterschied zwischen flanken- und pegelgesteuerter Erkennung im UI-Framework zurückgeführt, das Modell statt des Symptoms korrigiert und einen Regressionstest ergänzt. Das Projekt liegt mit vollständigem technischen Bericht auf GitHub. Es hat mir gezeigt, dass der spannende Teil des Ingenieurwesens selten die erste Version ist, sondern der disziplinierte Kreislauf aus Spezifizieren, Bauen, Messen und Korrigieren — genau das zieht mich zum [Luft- und Raumfahrt- / Maschinenbau-]Studium.

## 2. What the repository lets a reader verify

Point them at specific things; vague "I built an app" is weaker than "see §7.1 of the report".

- **Requirements → design → verification** are written down: `docs/PROJECT_REPORT.md` §2, §3, §5.
- **A state machine** designed from the domain (§3.2) and the story of getting it wrong first (§7.2).
- **Time-critical behaviour** with three redundant mechanisms and an edge-vs-level bug (§3.4, §7.1) — the closest thing here to control-systems thinking.
- **An algorithm with a scoring model** (stat selection, §3.5) and a signal-processing step (k-means colour clustering, §3.6).
- **Verification you can run:** `xcodebuild test` — 12 scenarios, listed in §5 with what each proves.
- **Honest limitations** (§6). Readers trust a project more when its author states what is *not* done.

## 3. Framing for engineering (without overreaching)

Do **not** claim the app is mechanical or aerospace work. Do draw the parallels in how you *worked*:

| In Capsule | The engineering habit it shows |
|---|---|
| Requirements list with functional / non-functional split | Specification before build |
| Vault lifecycle state machine; router as a pure function of state | Modelling a system's states and transitions explicitly |
| Countdown with edge/level detection bug, redundancy (§3.4) | Timing, triggers, fail-safes — control-adjacent thinking |
| Server-side lock as the *only* trust boundary | Identifying where a guarantee must live, not where it's convenient |
| Automated end-to-end tests with deterministic setup | Verification and repeatability over "it worked when I tried it" |
| Field testing on a real phone → model correction (§7.2) | Iterating on evidence, changing the design not the patch |
| Report + README + setup guide | Documentation as part of the deliverable |

A good interview line: *"The app isn't the point — the point is that I now know what it feels like to own a system end to end, be wrong about its model, and fix it with a test to prove it."*

## 4. CV / résumé bullets

- **Capsule — iOS app (Swift/SwiftUI), solo, 2026.** Designed and built a time-locked shared memory vault with a server-enforced access model, offline upload queue, video pipeline and a five-stage animated reveal; 4.3k LOC, 12-scenario automated UI test suite, full engineering report. github.com/Yousuf6273/Capsule
- Shorter: **Capsule (iOS, Swift)** — locked trip-memory vault with cinematic reveal; state-machine design, automated E2E tests, documented engineering process.

## 5. Interview talking points (60–90 s each)

1. **The problem and why it's real** — the "do not open" group chat exists; the tools don't enforce the promise or celebrate the opening.
2. **The lock** — why hiding on the client is not security; how rules + a single privileged writer make it true; what a modified client can and cannot do.
3. **The bug you're proudest of** — §7.1. Explain edge- vs level-triggered plainly; say how you found it (a tester's screenshot at 00:00:00), fixed it, and proved it.
4. **The design mistake** — §7.2. Show you can say "my model was wrong" without flinching, and what the correct model is.
5. **What you'd do next and why** — live two-device test first (it's the one requirement not yet exercised), then field-test on a real trip.

## 6. Things to prepare

- A **60–90 s screen recording** of the ceremony (unseal → intro → numbers → journey). It is the strongest visual asset. Record on the simulator with ⌘R in Xcode, then *File → Record Screen* in Simulator, or use `xcrun simctl io booted recordVideo demo.mp4`.
- Make the repository **public** when you submit (GitHub → Settings → Danger Zone → Change visibility). Applications can't read a private repo.
- Have the **report open** in the interview; know the section numbers.
- If asked about AI assistance: be straightforward — you directed the design, tested on device, found the bugs, and made the product decisions; tooling helped you write and refactor faster. Universities care about judgement and ownership, and the report demonstrates both.

## 7. Programme-specific notes (verify current rules before applying)

- **TU Delft — BSc Aerospace Engineering:** numerus fixus; selection typically includes a motivation/portfolio element and tests. A documented technical project with a report is exactly what the "demonstrate affinity with engineering" criteria look for.
- **TU Eindhoven — BSc Mechanical Engineering:** selection procedure with motivation; Dutch programmes value *self-directed* projects.
- **TUM — Aerospace / Mechanical:** the *Eignungsfeststellungsverfahren* may include a motivation letter and interview stage where extracurricular technical work is explicitly scored.
- **RWTH Aachen, KIT, Uni Stuttgart:** Bachelor admission is largely grade-based; the project helps for scholarships (e.g. Deutschlandstipendium), student-research jobs (*HiWi*) and later Master's applications — keep it maintained.

---
*Everything in this document is meant to be edited into your own voice. Keep the facts; change the words.*
