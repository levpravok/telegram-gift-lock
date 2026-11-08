import Foundation

// A deterministic, in-memory authority for an OFFLINE prototype.
// This actor models where Telegram's SERVER must enforce the policy. It is not
// an account-security implementation and must never be shipped as one.
struct Collectible: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let number: String
    let symbol: String
}

struct GiftRecipient: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let username: String
}

enum GiftIntent: Equatable, Sendable {
    case transfer(giftID: String, recipientID: String)
    case acceptOffer(offerID: String)
    case setLock(enabled: Bool)
}

struct GiftReview: Identifiable, Sendable {
    let id: UUID
    let intent: GiftIntent
    let gift: Collectible?
    let recipient: GiftRecipient?
    let grossStars: Int
    let feeStars: Int
    let requiresPassword: Bool
    let expiresAt: Date
    var netStars: Int { grossStars - feeStars }
    var isSale: Bool { if case .acceptOffer = intent { return true }; return false }
    var isPolicy: Bool { if case .setLock = intent { return true }; return false }
}

struct GiftReceipt: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let date: Date
}

struct GiftSnapshot: Sendable {
    let gifts: [Collectible]
    let locked: Bool
    let stars: Int
    let receipts: [GiftReceipt]
}

enum GiftLockError: Error, LocalizedError, Equatable {
    case invalidSession, expiredReview, staleReview, noLongerOwned, offerUnavailable
    case wrongPassword, rateLimited(seconds: Int), invalidRecipient
    var errorDescription: String? {
        switch self {
        case .invalidSession: return "This session cannot authorize this action."
        case .expiredReview: return "This review expired. Close it and review the action again."
        case .staleReview: return "Something changed. Close this sheet and review the latest details."
        case .noLongerOwned: return "This gift is no longer in your collection."
        case .offerUnavailable: return "This offer is no longer available."
        case .wrongPassword: return "Incorrect password. Your gift has not moved."
        case .rateLimited(let seconds): return "Too many attempts. Try again in \(seconds) seconds."
        case .invalidRecipient: return "Choose a valid recipient."
        }
    }
}

protocol GiftLockService: Sendable {
    func snapshot() async -> GiftSnapshot
    func review(_ intent: GiftIntent, session: String) async throws -> GiftReview
    func commit(_ reviewID: UUID, password: String, session: String) async throws -> GiftReceipt
    func cancel(_ reviewID: UUID, session: String) async
}

actor DemoGiftService: GiftLockService {
    static let samplePassword = "gift-demo-2026" // Fictional demo credential ONLY.
    static let phoneSession = "demo-phone"
    static let recipient = GiftRecipient(id: "sample-peer-17", name: "Mira", username: "@mira_example")
    static let sampleGifts = [
        Collectible(id: "moon-1042", title: "Moon Lantern", number: "#1042", symbol: "moon.stars.fill"),
        Collectible(id: "crystal-381", title: "Blue Crystal", number: "#0381", symbol: "diamond.fill"),
        Collectible(id: "star-892", title: "Lucky Star", number: "#0892", symbol: "star.fill")
    ]
    private struct Challenge: Sendable {
        let review: GiftReview
        let session: String
        let revision: Int
    }
    private var owned = DemoGiftService.sampleGifts
    private var locked = true
    private var stars = 1200
    private var receipts: [GiftReceipt] = []
    private var challenges: [UUID: Challenge] = [:]
    private var revision = 0
    private var failures = 0
    private var blockedUntil = Date.distantPast
    private var offerAvailable = true
    private let offerExpiresAt: Date
    private let clock: @Sendable () -> Date
    private let sessions: Set<String> = ["demo-phone", "demo-other-session"]

    init(clock: @escaping @Sendable () -> Date = { Date() }) {
        self.clock = clock
        self.offerExpiresAt = clock().addingTimeInterval(3600)
    }

    func snapshot() -> GiftSnapshot {
        GiftSnapshot(gifts: owned, locked: locked, stars: stars, receipts: receipts)
    }

    func review(_ intent: GiftIntent, session: String) throws -> GiftReview {
        guard sessions.contains(session) else { throw GiftLockError.invalidSession }
        let now = clock()
        challenges = challenges.filter { $0.value.review.expiresAt > now }
        var gift: Collectible?
        var peer: GiftRecipient?
        var gross = 0
        var fee = 0
        switch intent {
        case .transfer(let giftID, let peerID):
            guard peerID == Self.recipient.id else { throw GiftLockError.invalidRecipient }
            guard let found = owned.first(where: { $0.id == giftID }) else { throw GiftLockError.noLongerOwned }
            gift = found; peer = Self.recipient
        case .acceptOffer(let offerID):
            guard offerID == "sample-offer-1", offerAvailable, offerExpiresAt > now else { throw GiftLockError.offerUnavailable }
            guard let found = owned.first(where: { $0.id == "moon-1042" }) else { throw GiftLockError.noLongerOwned }
            gift = found; peer = Self.recipient
            gross = 4800; fee = 480 // Illustrative sample quote, NOT Telegram's current fee schedule.
        case .setLock(let enabled):
            guard enabled != locked else { throw GiftLockError.staleReview }
        }
        let review = GiftReview(id: UUID(), intent: intent, gift: gift, recipient: peer,
            grossStars: gross, feeStars: fee, requiresPassword: locked || gift == nil,
            expiresAt: min(now.addingTimeInterval(60), gift == nil || gross == 0 ? Date.distantFuture : offerExpiresAt))
        challenges[review.id] = Challenge(review: review, session: session, revision: revision)
        return review
    }

    // Authorization and mutation happen together, without an await point. Clients
    // submit a challenge ID, never editable price/peer/fee fields at commit time.
    func commit(_ reviewID: UUID, password: String, session: String) throws -> GiftReceipt {
        guard sessions.contains(session) else { throw GiftLockError.invalidSession }
        guard let challenge = challenges[reviewID] else { throw GiftLockError.expiredReview }
        guard challenge.session == session else { throw GiftLockError.invalidSession }
        let now = clock()
        guard challenge.review.expiresAt > now else {
            challenges.removeValue(forKey: reviewID); throw GiftLockError.expiredReview
        }
        guard challenge.revision == revision else {
            challenges.removeValue(forKey: reviewID); throw GiftLockError.staleReview
        }
        let review = challenge.review
        if review.requiresPassword {
            guard now >= blockedUntil else {
                throw GiftLockError.rateLimited(seconds: max(1, Int(ceil(blockedUntil.timeIntervalSince(now)))))
            }
            // Deliberately simple fake verifier. Production MUST use Telegram's
            // existing SRP implementation remotely, never this known credential.
            guard password == Self.samplePassword else {
                failures += 1
                if failures >= 5 {
                    blockedUntil = now.addingTimeInterval(30); failures = 0
                    throw GiftLockError.rateLimited(seconds: 30)
                }
                throw GiftLockError.wrongPassword
            }
            failures = 0
        }
        let title: String
        let detail: String
        switch review.intent {
        case .transfer(let giftID, _):
            guard owned.contains(where: { $0.id == giftID }) else { throw GiftLockError.noLongerOwned }
            owned.removeAll { $0.id == giftID }
            title = "Gift transferred"
            detail = "\(review.gift!.title) \(review.gift!.number) sent to \(Self.recipient.username)."
        case .acceptOffer:
            guard offerAvailable, offerExpiresAt > now else { throw GiftLockError.offerUnavailable }
            guard owned.contains(where: { $0.id == "moon-1042" }) else { throw GiftLockError.noLongerOwned }
            owned.removeAll { $0.id == "moon-1042" }
            offerAvailable = false; stars += review.netStars
            title = "Offer accepted"
            detail = "\(review.netStars.formatted()) Stars added. Moon Lantern #1042 sent to \(Self.recipient.username)."
        case .setLock(let enabled):
            locked = enabled
            title = enabled ? "Gift Lock enabled" : "Gift Lock disabled"
            detail = enabled ? "Fresh authorization is required for every transfer and accepted offer in this demo." : "Transfers and accepted offers still show a review, without a password."
        }
        revision += 1
        challenges.removeAll() // Invalidate every stale pending action.
        let receipt = GiftReceipt(id: UUID(), title: title, detail: detail, date: now)
        receipts.insert(receipt, at: 0)
        return receipt
    }

    func cancel(_ reviewID: UUID, session: String) {
        if challenges[reviewID]?.session == session { challenges.removeValue(forKey: reviewID) }
    }
}
