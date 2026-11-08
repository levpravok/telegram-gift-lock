import XCTest

final class GiftLockUITests: XCTestCase {
    @MainActor
    func testCancelLeavesCollectionUntouched() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["reviewOffer"].waitForExistence(timeout: 8))
        app.buttons["reviewOffer"].tap()
        XCTAssertTrue(app.staticTexts["Accept Offer"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["reviewOffer"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testWrongPasswordThenAuthorizedSale() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["reviewOffer"].waitForExistence(timeout: 8))
        app.buttons["reviewOffer"].tap()
        XCTAssertTrue(app.buttons["authorizeAction"].waitForExistence(timeout: 3))
        app.buttons["authorizeAction"].tap()
        let password = app.secureTextFields["giftPassword"]
        XCTAssertTrue(password.waitForExistence(timeout: 3))
        password.tap(); password.typeText("wrong")
        app.buttons["authorizeAction"].tap()
        XCTAssertTrue(app.staticTexts["Incorrect password. Your gift has not moved."].waitForExistence(timeout: 3))
        password.tap(); password.typeText("gift-demo-2026")
        app.buttons["authorizeAction"].tap()
        XCTAssertTrue(app.staticTexts["Offer accepted"].waitForExistence(timeout: 3))
        app.buttons["doneAction"].tap()
        XCTAssertTrue(app.staticTexts["Offer accepted"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["reviewOffer"].exists)
        app.buttons["openCollection"].tap()
        XCTAssertTrue(app.staticTexts["2 gifts · sample account"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testDisablingLockRequiresAuthorizationAndCanBeCancelled() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["giftLockSettings"].waitForExistence(timeout: 8))
        app.buttons["giftLockSettings"].tap()
        app.buttons["toggleGiftLock"].tap()
        XCTAssertTrue(app.staticTexts["Turn off Gift Lock?"].waitForExistence(timeout: 3))
        app.buttons["authorizeAction"].tap()
        XCTAssertTrue(app.secureTextFields["giftPassword"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["authorizeAction"].isEnabled)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["giftLockSettings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["giftLockSettings"].label.contains("Gift Lock is on"))
    }
}
