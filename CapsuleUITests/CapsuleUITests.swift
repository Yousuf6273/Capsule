import XCTest

/// End-to-end pressure tests for every user flow. Each test launches with
/// `--uitest-reset` so state is deterministic (fresh sample vaults, no profile).
final class CapsuleUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()
    }

    // ── Helpers ──────────────────────────────────────────────────

    /// Sign in from the fresh entrance screen and land on Home.
    func signIn() {
        let field = app.textFields["nameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "name field should appear")
        field.tap()
        field.typeText("Tester")
        app.buttons["Begin"].tap()
        XCTAssertTrue(app.staticTexts["Your Vaults"].waitForExistence(timeout: 10),
                      "should land on Home after sign-in")
    }

    func assertOnHome(_ message: String) {
        XCTAssertTrue(app.staticTexts["Your Vaults"].waitForExistence(timeout: 8), message)
    }

    /// Runs the ceremony up to the point the skip control is available, then skips.
    func skipCeremonyToAlbum() {
        let unseal = app.buttons["unsealButton"]
        XCTAssertTrue(unseal.waitForExistence(timeout: 8), "unseal screen should appear")
        let skip = app.buttons["skipReveal"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10), "skip control should appear after a beat")
        skip.tap()
        XCTAssertTrue(app.buttons["openQuiz"].waitForExistence(timeout: 8),
                      "album (with quiz toolbar button) should appear after skipping")
    }

    // ── Tests ────────────────────────────────────────────────────

    /// Auth → Home, and both sheets (create, join) open and close cleanly.
    func testAuthHomeAndSheets() {
        signIn()

        // Create sheet opens and closes
        app.buttons["tabNew"].tap()
        XCTAssertTrue(app.staticTexts["Start a capsule 🌴"].waitForExistence(timeout: 6))
        app.buttons["xmark"].firstMatch.tap()
        assertOnHome("closing create sheet should return to Home")

        // Join sheet opens and closes
        let joinLink = app.buttons["Have an invite code? Join a capsule →"]
        if joinLink.waitForExistence(timeout: 4) {
            joinLink.tap()
            XCTAssertTrue(app.staticTexts["Join a capsule"].waitForExistence(timeout: 6))
            app.buttons["xmark"].firstMatch.tap()
            assertOnHome("closing join sheet should return to Home")
        }
    }

    /// Collecting screen: opens from Home, "Done for now" returns straight Home.
    func testCollectingDoneReturnsHome() {
        signIn()
        app.staticTexts["Tokyo"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Done for now"].waitForExistence(timeout: 8),
                      "collecting screen should show Done for now")
        app.buttons["Done for now"].tap()
        assertOnHome("Done for now must land on Home, not an intermediate step")

        // Regression: "Done for now" must actually seal the vault (move it
        // out of collecting), not just dismiss the screen — otherwise it sits
        // in limbo forever with no countdown and no way to ever unlock.
        let tokyoRow = app.staticTexts["Tokyo"].firstMatch
        XCTAssertTrue(tokyoRow.waitForExistence(timeout: 6))
        tokyoRow.tap()
        XCTAssertFalse(app.buttons["Done for now"].waitForExistence(timeout: 3),
                       "Tokyo should now be sealed (waiting screen), not still collecting")
    }

    /// Sealed vault: hero → waiting screen with countdown → back goes Home.
    func testWaitingScreenAndBack() {
        signIn()
        // Kefalonia is the sealed hero card
        let hero = app.buttons["heroCard"]
        XCTAssertTrue(hero.waitForExistence(timeout: 8), "hero card should exist")
        hero.tap()
        XCTAssertTrue(app.staticTexts["KEFALONIA OPENS IN"].waitForExistence(timeout: 8)
                      || app.buttons["simulateUnlock"].waitForExistence(timeout: 4),
                      "waiting screen should appear for the sealed vault")
        app.navigationBars.buttons.firstMatch.tap() // system back
        assertOnHome("back from waiting must land on Home")
    }

    /// The full unlock path: simulate unlock → ceremony phases → skip → album → back → Home.
    func testUnlockCeremonySkipAndAlbum() {
        signIn()
        let hero = app.buttons["heroCard"]
        XCTAssertTrue(hero.waitForExistence(timeout: 8), "hero card should exist")
        hero.tap()
        let simulate = app.buttons["simulateUnlock"]
        XCTAssertTrue(simulate.waitForExistence(timeout: 8))
        simulate.tap()

        skipCeremonyToAlbum()

        // Album cells exist; open + close a memory detail
        let cell = app.buttons.matching(identifier: "albumCell").firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 8), "album should show memory cells")
        cell.tap()
        let close = app.buttons["closeDetail"]
        XCTAssertTrue(close.waitForExistence(timeout: 6), "memory detail should open")
        close.tap()
        XCTAssertTrue(app.buttons["openQuiz"].waitForExistence(timeout: 6),
                      "closing detail should return to the album")

        app.navigationBars.buttons.firstMatch.tap()
        assertOnHome("back from album must land on Home")
    }

    /// Ceremony runs on its own: unseal → intro → numbers appear without taps.
    func testCeremonyPhasesAdvance() {
        signIn()
        let hero = app.buttons["heroCard"]
        XCTAssertTrue(hero.waitForExistence(timeout: 8), "hero card should exist")
        hero.tap()
        app.buttons["simulateUnlock"].tap()

        let unseal = app.buttons["unsealButton"]
        XCTAssertTrue(unseal.waitForExistence(timeout: 8))
        unseal.tap()

        // Intro card appears with the vault name and swipe cue
        XCTAssertTrue(app.staticTexts["SWIPE TO BEGIN"].waitForExistence(timeout: 8),
                      "intro card should follow the unseal animation")
        app.swipeUp()

        // Numbers phase: memory-count slide arrives
        XCTAssertTrue(app.staticTexts["memories were sealed away"].waitForExistence(timeout: 8),
                      "first stat slide should appear after intro")
    }

    /// Solo quiz: answering reveals immediately (no waiting-for-the-room state).
    func testSoloQuizFromAlbum() {
        signIn()
        let hero = app.buttons["heroCard"]
        XCTAssertTrue(hero.waitForExistence(timeout: 8), "hero card should exist")
        hero.tap()
        app.buttons["simulateUnlock"].tap()
        skipCeremonyToAlbum()

        app.buttons["openQuiz"].tap()
        let play = app.buttons["Let's play"]
        XCTAssertTrue(play.waitForExistence(timeout: 8), "quiz intro should appear")
        play.tap()

        // Play all rounds: tap the first option; reveal must be IMMEDIATE.
        for round in 0..<6 {
            let next = app.buttons["Next round"]
            let scores = app.buttons["See the scores"]
            let option = app.buttons.matching(identifier: "quizOption").firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 8), "round \(round): options should exist")
            option.tap()

            // SOLO requirement: advance button appears right away after answering
            let advanced = next.waitForExistence(timeout: 3) || scores.waitForExistence(timeout: 2)
            XCTAssertTrue(advanced, "round \(round): reveal must be immediate after answering (solo mode)")
            if scores.exists {
                scores.tap()
                break
            }
            next.tap()
        }

        // Results screen, then back to the album
        let done = app.buttons["Back to the album"]
        XCTAssertTrue(done.waitForExistence(timeout: 8), "results screen should appear")
        done.tap()
        XCTAssertTrue(app.buttons["openQuiz"].waitForExistence(timeout: 6),
                      "quiz must return to the album")
    }

    /// Wrapped stats cover opens from the album and returns.
    func testWrappedCoverFromAlbum() {
        signIn()
        let hero = app.buttons["heroCard"]
        XCTAssertTrue(hero.waitForExistence(timeout: 8), "hero card should exist")
        hero.tap()
        app.buttons["simulateUnlock"].tap()
        skipCeremonyToAlbum()

        app.buttons["openWrapped"].tap()
        XCTAssertTrue(app.staticTexts["memories, together"].waitForExistence(timeout: 8),
                      "wrapped screen should appear")
        app.buttons["Back to the album"].tap()
        XCTAssertTrue(app.buttons["openQuiz"].waitForExistence(timeout: 6),
                      "wrapped must return to the album")
    }

    /// Wrapped tab lists opened vaults; row opens the vault; back goes Home.
    func testWrappedTabNavigation() {
        signIn()
        app.buttons["tabWrapped"].tap()
        XCTAssertTrue(app.staticTexts["Wrapped"].waitForExistence(timeout: 6))

        // Heilbronn is unlocked in sample data
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Heilbronn'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 6), "Heilbronn row should exist")
        row.tap()

        // Heilbronn ships already revealed → straight to the album
        XCTAssertTrue(app.buttons["openQuiz"].waitForExistence(timeout: 8),
                      "revealed vault should open its album directly")
        app.navigationBars.buttons.firstMatch.tap()
        // Back lands on the shell (wrapped tab still selected)
        XCTAssertTrue(app.staticTexts["Wrapped"].waitForExistence(timeout: 8)
                      || app.staticTexts["Your Vaults"].waitForExistence(timeout: 4),
                      "back from album must land on the shell")
    }

    /// When the countdown reaches zero on its own — no button tap — the vault
    /// must auto-unlock into the ceremony. Regression test for the bug where
    /// nothing happened once the timer hit 00:00:00.
    func testCountdownReachingZeroAutoUnlocks() {
        // Relaunch with a near-future unlock so the real clock does the work.
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launchEnvironment = ["CAPSULE_TEST_UNLOCK_SECONDS": "12"]
        app.launch()

        signIn()
        let hero = app.buttons["heroCard"]
        XCTAssertTrue(hero.waitForExistence(timeout: 8), "hero card should exist")
        hero.tap()

        // Waiting screen should appear with a near-zero countdown — and NO tap
        // on simulateUnlock. Just wait for the clock. (It may have already
        // flipped by the time we check, which is fine — that's the point.)
        _ = app.buttons["simulateUnlock"].waitForExistence(timeout: 3)

        // The countdown must, on its own, flip the vault to unlocked and
        // land on the unseal screen — this is the whole point of the test.
        let unseal = app.buttons["unsealButton"]
        XCTAssertTrue(unseal.waitForExistence(timeout: 20),
                      "vault must auto-unlock into the ceremony when the countdown reaches zero, without any button tap")
    }
}
