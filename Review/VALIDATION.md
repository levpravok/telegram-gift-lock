# Validation record

Verified on **8 November 2026**, using Xcode 26.4.1, Swift 6.3.1 and an iPhone 17 Pro simulator running iOS 26.4.1. The project targets iOS 17 and later; older supported OS versions were not separately tested.

## Build

The native iOS app compiled successfully for the iOS Simulator, without third-party dependencies or a signing team. It was installed and run in the simulator. The package contains source and project files, not a signed App Store or device installation package.

## Policy tests: 16 passed, zero failures

1. Reviewing an action does not move gifts or change the balance.
2. Empty and incorrect passwords do not move gifts.
3. An authorized sale removes the gift and credits only the sample net proceeds.
4. A free gift transfer does not credit sale proceeds.
5. Cancellation invalidates the review without mutation.
6. A consumed review cannot be replayed.
7. Reviews expire at 60 seconds.
8. A review cannot be committed or cancelled by another fictional session.
9. An unknown session cannot open a review.
10. A mutation invalidates other pending reviews.
11. Turning the lock off requires the password.
12. An unlocked transfer retains review; re-enabling the lock still requires authorization.
13. Five failures temporarily block password attempts across fictional sessions.
14. Invalid recipients and gifts not owned are rejected.
15. Unknown, expired and previously accepted offers are rejected.
16. An already-transferred gift cannot be transferred again.

## iPhone interface tests: 3 passed, zero failures

XCTest UI automation tapped the app's real controls and verified:

- Cancelling the sale review preserves the offer and allows it to be reviewed again.
- An incorrect password shows an error; the correct sample password completes the sale and leaves two gifts.
- Disabling Gift Lock opens the password step; its submit button is disabled when empty; cancellation leaves the setting on.

## Recording and visual verification

The revised submitted video records the compiled native app’s guided sequence in its Telegram-style chat interface, with a phone frame and gradient presentation matching the supplied references. The sequence uses the same service methods as the interactive controls. It demonstrates the chat offer, Gift Lock setting, sale review, wrong-password attempt, successful sale, collection, zero-proceeds transfer review, password requirement and cancellation. It is an automated walkthrough of running code, not a hand-animated mockup.

The chat, sale review, authorization error and lock-setting screens were visually inspected in simulator screenshots. The final delivery MP4 was decoded and verified: **28.00 seconds, 1080 × 1080, 30 fps, H.264, approximately 6.8 MB**, within the supplied 30-second limit. Its phone frame is presentation only; the feature behavior is recorded from the compiled app. Frames sampled from the exported file show the wrong-password error, successful sale and transfer review. No production Telegram login, password or gift transaction was used.

## Limits

These results establish behavior of the standalone prototype only. They do not validate a production Telegram client/server integration, real SRP authentication, backend durability, recovery, paid transfers, TON, marketplace listings, device compromise resistance, accessibility conformance or every screen size/theme. The security authority in this package is an in-memory test double. See `INTEGRATION.md` for work required before release.
