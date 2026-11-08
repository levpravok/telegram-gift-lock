import XCTest
@testable import GiftLockCore

final class ControlledClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1_800_000_000)
    func now() -> Date { lock.lock(); defer { lock.unlock() }; return date }
    func advance(_ seconds: TimeInterval) { lock.lock(); date.addTimeInterval(seconds); lock.unlock() }
}

final class GiftLockCoreTests: XCTestCase {
    let session = DemoGiftService.phoneSession
    let password = DemoGiftService.samplePassword
    let transfer = GiftIntent.transfer(giftID: "crystal-381", recipientID: DemoGiftService.recipient.id)

    func expect(_ expected: GiftLockError, _ operation: () async throws -> Void,
                file: StaticString = #filePath, line: UInt = #line) async {
        do { try await operation(); XCTFail("Expected \(expected)", file: file, line: line) }
        catch { XCTAssertEqual(error as? GiftLockError, expected, file: file, line: line) }
    }

    func testReviewDoesNotMoveGiftOrChangeBalance() async throws {
        let server = DemoGiftService()
        _ = try await server.review(.acceptOffer(offerID: "sample-offer-1"), session: session)
        let state = await server.snapshot()
        XCTAssertEqual(state.gifts.count, 3); XCTAssertEqual(state.stars, 1200)
    }
    func testWrongPasswordAndEmptyPasswordDoNotMoveGift() async throws {
        let server = DemoGiftService()
        let quote = try await server.review(transfer, session: session)
        for wrong in ["", "wrong"] {
            await expect(.wrongPassword) { _ = try await server.commit(quote.id, password: wrong, session: self.session) }
        }
        let state = await server.snapshot()
        XCTAssertEqual(state.gifts.count, 3); XCTAssertTrue(state.receipts.isEmpty)
    }
    func testAuthorizedSaleMovesGiftAndCreditsOnlyNetAmount() async throws {
        let server = DemoGiftService()
        let quote = try await server.review(.acceptOffer(offerID: "sample-offer-1"), session: session)
        XCTAssertEqual(quote.grossStars, 4800); XCTAssertEqual(quote.feeStars, 480); XCTAssertEqual(quote.netStars, 4320)
        _ = try await server.commit(quote.id, password: password, session: session)
        let state = await server.snapshot()
        XCTAssertFalse(state.gifts.contains { $0.id == "moon-1042" })
        XCTAssertEqual(state.stars, 5520); XCTAssertEqual(state.receipts.count, 1); XCTAssertTrue(state.locked)
    }
    func testTransferDoesNotCreditStars() async throws {
        let server = DemoGiftService()
        let quote = try await server.review(transfer, session: session)
        XCTAssertEqual(quote.netStars, 0)
        _ = try await server.commit(quote.id, password: password, session: session)
        let state = await server.snapshot()
        XCTAssertEqual(state.gifts.count, 2); XCTAssertEqual(state.stars, 1200)
    }
    func testCancelInvalidatesChallengeWithoutMutation() async throws {
        let server = DemoGiftService()
        let quote = try await server.review(transfer, session: session)
        await server.cancel(quote.id, session: session)
        await expect(.expiredReview) { _ = try await server.commit(quote.id, password: self.password, session: self.session) }
        let state = await server.snapshot(); XCTAssertEqual(state.gifts.count, 3)
    }
    func testConsumedChallengeCannotBeReplayed() async throws {
        let server = DemoGiftService()
        let quote = try await server.review(transfer, session: session)
        _ = try await server.commit(quote.id, password: password, session: session)
        await expect(.expiredReview) { _ = try await server.commit(quote.id, password: self.password, session: self.session) }
        let state = await server.snapshot(); XCTAssertEqual(state.receipts.count, 1)
    }
    func testReviewExpiresAtSixtySeconds() async throws {
        let clock = ControlledClock()
        let server = DemoGiftService(clock: { clock.now() })
        let quote = try await server.review(transfer, session: session)
        clock.advance(60)
        await expect(.expiredReview) { _ = try await server.commit(quote.id, password: self.password, session: self.session) }
        let state = await server.snapshot(); XCTAssertEqual(state.gifts.count, 3)
    }
    func testChallengeCannotBeUsedFromAnotherLoggedInSession() async throws {
        let server = DemoGiftService()
        let quote = try await server.review(transfer, session: session)
        await expect(.invalidSession) { _ = try await server.commit(quote.id, password: self.password, session: "demo-other-session") }
        // A hostile session cannot cancel a review on the owner's phone either.
        await server.cancel(quote.id, session: "demo-other-session")
        _ = try await server.commit(quote.id, password: password, session: session)
    }
    func testUnknownSessionCannotOpenReview() async throws {
        let server = DemoGiftService()
        await expect(.invalidSession) { _ = try await server.review(self.transfer, session: "unknown") }
    }
    func testAnyMutationInvalidatesOtherPendingChallenges() async throws {
        let server = DemoGiftService()
        let first = try await server.review(transfer, session: session)
        let second = try await server.review(.acceptOffer(offerID: "sample-offer-1"), session: session)
        _ = try await server.commit(first.id, password: password, session: session)
        await expect(.expiredReview) { _ = try await server.commit(second.id, password: self.password, session: self.session) }
    }
    func testLockCannotBeDisabledWithoutPassword() async throws {
        let server = DemoGiftService()
        let quote = try await server.review(.setLock(enabled: false), session: session)
        XCTAssertTrue(quote.requiresPassword)
        await expect(.wrongPassword) { _ = try await server.commit(quote.id, password: "", session: self.session) }
        let state = await server.snapshot(); XCTAssertTrue(state.locked)
    }
    func testDisabledLockStillReviewsTransferAndEnablingNeedsPassword() async throws {
        let server = DemoGiftService()
        let off = try await server.review(.setLock(enabled: false), session: session)
        _ = try await server.commit(off.id, password: password, session: session)
        let quote = try await server.review(transfer, session: session)
        XCTAssertFalse(quote.requiresPassword)
        _ = try await server.commit(quote.id, password: "", session: session)
        let on = try await server.review(.setLock(enabled: true), session: session)
        XCTAssertTrue(on.requiresPassword)
        _ = try await server.commit(on.id, password: password, session: session)
        let state = await server.snapshot(); XCTAssertTrue(state.locked)
    }
    func testFiveFailuresBlockCorrectPasswordTemporarilyAcrossSessions() async throws {
        let clock = ControlledClock()
        let server = DemoGiftService(clock: { clock.now() })
        let quote = try await server.review(transfer, session: session)
        for _ in 0..<4 {
            await expect(.wrongPassword) { _ = try await server.commit(quote.id, password: "bad", session: self.session) }
        }
        await expect(.rateLimited(seconds: 30)) { _ = try await server.commit(quote.id, password: "bad", session: self.session) }
        let other = try await server.review(transfer, session: "demo-other-session")
        await expect(.rateLimited(seconds: 30)) { _ = try await server.commit(other.id, password: self.password, session: "demo-other-session") }
        clock.advance(30)
        _ = try await server.commit(quote.id, password: password, session: session)
    }
    func testInvalidRecipientAndNonexistentGiftAreRejected() async throws {
        let server = DemoGiftService()
        await expect(.invalidRecipient) { _ = try await server.review(.transfer(giftID: "crystal-381", recipientID: "tampered-peer"), session: self.session) }
        await expect(.noLongerOwned) { _ = try await server.review(.transfer(giftID: "not-owned", recipientID: DemoGiftService.recipient.id), session: self.session) }
    }
    func testUnknownExpiredAndAlreadyAcceptedOffersCannotBeAccepted() async throws {
        let clock = ControlledClock()
        let server = DemoGiftService(clock: { clock.now() })
        await expect(.offerUnavailable) { _ = try await server.review(.acceptOffer(offerID: "forged-offer"), session: self.session) }
        clock.advance(3600)
        await expect(.offerUnavailable) { _ = try await server.review(.acceptOffer(offerID: "sample-offer-1"), session: self.session) }
        let fresh = DemoGiftService()
        let quote = try await fresh.review(.acceptOffer(offerID: "sample-offer-1"), session: session)
        _ = try await fresh.commit(quote.id, password: password, session: session)
        await expect(.offerUnavailable) { _ = try await fresh.review(.acceptOffer(offerID: "sample-offer-1"), session: self.session) }
    }
    func testUnownedGiftCannotBeTransferredTwice() async throws {
        let server = DemoGiftService()
        let quote = try await server.review(transfer, session: session)
        _ = try await server.commit(quote.id, password: password, session: session)
        await expect(.noLongerOwned) { _ = try await server.review(self.transfer, session: self.session) }
    }
}
