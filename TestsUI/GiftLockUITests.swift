import XCTest

final class GiftLockUITests: XCTestCase {
    @MainActor
    private func openTransfer(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["beginTransfer"].waitForExistence(timeout: 10))
        app.buttons["beginTransfer"].tap()
        XCTAssertTrue(app.buttons["confirmRecipient"].waitForExistence(timeout: 3))
        app.buttons["confirmRecipient"].tap()
        XCTAssertTrue(app.buttons["authorizeAction"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testCancelLeavesGiftUntouched() throws {
        let app = XCUIApplication(); app.launch()
        openTransfer(app)
        XCTAssertTrue(app.staticTexts["This is a gift transfer, not a sale."].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["beginTransfer"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Rose Gold"].exists)
    }

    @MainActor
    func testWrongPasswordThenAuthorizedDemoTransfer() throws {
        let app = XCUIApplication(); app.launch()
        openTransfer(app)
        app.buttons["authorizeAction"].tap()
        let password = app.secureTextFields["giftPassword"]
        XCTAssertTrue(password.waitForExistence(timeout: 3))
        password.tap(); password.typeText("wrong")
        app.buttons["authorizeAction"].tap()
        XCTAssertTrue(app.staticTexts["Incorrect password. Your gift has not moved."].waitForExistence(timeout: 3))
        password.tap(); password.typeText("gift-demo-2026")
        app.buttons["authorizeAction"].tap()
        XCTAssertTrue(app.staticTexts["Transfer authorized"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Completed in the offline demo only.\nYour real bracelet is unchanged."].exists)
        app.buttons["doneAction"].tap()
        XCTAssertTrue(app.buttons["beginTransfer"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testDisablingLockRequiresAuthorizationAndCanBeCancelled() throws {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["giftMenu"].waitForExistence(timeout: 10))
        app.buttons["giftMenu"].tap()
        app.buttons["giftLockSettings"].tap()
        app.buttons["toggleGiftLock"].tap()
        XCTAssertTrue(app.staticTexts["Turn off Gift Lock?"].waitForExistence(timeout: 4))
        app.buttons["authorizeAction"].tap()
        XCTAssertTrue(app.secureTextFields["giftPassword"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["authorizeAction"].isEnabled)
        app.buttons["Cancel"].tap()
        app.buttons["giftMenu"].tap()
        XCTAssertTrue(app.buttons["giftLockSettings"].label.contains("On"))
    }
}
