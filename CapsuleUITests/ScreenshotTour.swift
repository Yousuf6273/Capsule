import XCTest

/// Walks the app and attaches a screenshot of every key screen. Used to
/// generate the images in docs/screenshots — run explicitly:
///   xcodebuild test ... -only-testing:CapsuleUITests/ScreenshotTour
final class ScreenshotTour: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launchEnvironment = ["CAPSULE_TEST_UNLOCK_SECONDS": "3600"]
        app.launch()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testTour() {
        // 01 Entrance
        XCTAssertTrue(app.textFields["nameField"].waitForExistence(timeout: 10))
        sleep(2) // let the staged entrance settle
        shot("01-entrance")

        app.textFields["nameField"].tap()
        app.textFields["nameField"].typeText("Yousuf")
        app.buttons["Begin"].tap()

        // 02 Home
        XCTAssertTrue(app.staticTexts["Your Vaults"].waitForExistence(timeout: 10))
        sleep(2)
        shot("02-home")

        // 03 Create vault sheet
        app.buttons["tabNew"].tap()
        XCTAssertTrue(app.staticTexts["Start a capsule 🌴"].waitForExistence(timeout: 6))
        sleep(1)
        shot("03-create-vault")
        app.buttons["xmark"].firstMatch.tap()

        // 04 Collecting (Tokyo)
        app.staticTexts["Tokyo"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Done for now"].waitForExistence(timeout: 8))
        sleep(1)
        shot("04-collecting")
        app.buttons["Done for now"].tap()

        // 05 Waiting / countdown (Kefalonia, sealed, 1h out)
        let hero = app.buttons["heroCard"]
        XCTAssertTrue(hero.waitForExistence(timeout: 8))
        hero.tap()
        XCTAssertTrue(app.buttons["simulateUnlock"].waitForExistence(timeout: 8))
        sleep(1)
        shot("05-countdown")

        // 06 Unseal
        app.buttons["simulateUnlock"].tap()
        let unseal = app.buttons["unsealButton"]
        XCTAssertTrue(unseal.waitForExistence(timeout: 8))
        sleep(1)
        shot("06-unseal")

        // 07 Intro card
        unseal.tap()
        XCTAssertTrue(app.staticTexts["SWIPE TO BEGIN"].waitForExistence(timeout: 8))
        sleep(1)
        shot("07-intro-card")

        // 08 Numbers
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["memories were sealed away"].waitForExistence(timeout: 8))
        sleep(1)
        shot("08-numbers")

        // 09 Journey (ride the auto-advance into the first photo slide)
        sleep(9)
        shot("09-journey")

        // Skip to album
        let skip = app.buttons["skipReveal"]
        if skip.waitForExistence(timeout: 5) { skip.tap() }
        XCTAssertTrue(app.buttons["openQuiz"].waitForExistence(timeout: 8))
        sleep(1)
        shot("10-album")

        // 11 Quiz round
        app.buttons["openQuiz"].tap()
        XCTAssertTrue(app.buttons["Let's play"].waitForExistence(timeout: 8))
        shot("11-quiz-intro")
        app.buttons["Let's play"].tap()
        let option = app.buttons.matching(identifier: "quizOption").firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 8))
        sleep(1)
        shot("12-quiz-round")
        option.tap()
        sleep(1)
        shot("13-quiz-reveal")
        app.buttons["Maybe later"].exists ? app.buttons["Maybe later"].tap() : ()
        if app.buttons["Next round"].exists {
            // back out via results path is long; dismiss by finishing rounds quickly
            for _ in 0..<6 {
                if app.buttons["See the scores"].exists { app.buttons["See the scores"].tap(); break }
                if app.buttons["Next round"].exists { app.buttons["Next round"].tap() }
                let o = app.buttons.matching(identifier: "quizOption").firstMatch
                if o.waitForExistence(timeout: 3) { o.tap() }
            }
            if app.buttons["Back to the album"].waitForExistence(timeout: 6) {
                shot("14-quiz-results")
                app.buttons["Back to the album"].tap()
            }
        }

        // 15 Wrapped
        XCTAssertTrue(app.buttons["openWrapped"].waitForExistence(timeout: 8))
        app.buttons["openWrapped"].tap()
        XCTAssertTrue(app.staticTexts["memories, together"].waitForExistence(timeout: 8))
        sleep(1)
        shot("15-wrapped")
        app.buttons["Back to the album"].tap()

        // 16 Memory detail
        let cell = app.buttons.matching(identifier: "albumCell").firstMatch
        if cell.waitForExistence(timeout: 6) {
            cell.tap()
            if app.buttons["closeDetail"].waitForExistence(timeout: 6) {
                sleep(1)
                shot("16-memory-detail")
                app.buttons["closeDetail"].tap()
            }
        }
    }
}
