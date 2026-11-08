# Validation record

Verified on **9 November 2026**, using Xcode 26.4.1, Swift 6.3.1 and an iPhone 17 Pro simulator running iOS 26.4.1. The project targets iOS 17 and later; older supported OS versions were not separately tested.

## Build

The native iOS app compiled successfully for the iOS Simulator, with the pinned official Lottie 4.6.1 renderer and without a signing team. It was installed and run in the simulator. The package contains source and project files, not a signed App Store or device installation package.

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

## iPhone interface tests: 3 scenarios verified

XCTest UI automation verified the transfer and password scenarios, then the revised switch interaction passed its targeted rerun after its tap target was corrected:

- Cancelling the transfer review returns to the unchanged reference gift panel.
- An incorrect password shows an error; the correct sample password authorizes only the local demo transfer. The success message explicitly says the real bracelet is unchanged.
- Disabling Gift Lock opens the password step; its submit button is disabled when empty; cancellation leaves the setting on.

## Recording and visual verification

The revised submitted video records the compiled native app’s guided sequence in the dark gift panel matched to the supplied Nail Bracelet #4465 screenshot, with a phone frame and gradient presentation. The sequence uses the same service methods as the interactive controls. The opening was decoded frame by frame to verify off → visible tap → on, with the startup flash trimmed. It starts with the Gift Lock switch off, shows a tap and the authenticated demo policy changing to on, then demonstrates the real public bracelet animation, local sample recipient selection, zero-proceeds transfer review, wrong-password error, authorized demo transfer, Gift Lock setting, sample offer review and cancellation. It is an automated walkthrough of running code, not a hand-animated mockup.

The gift panel, transfer review, authorization error and lock-setting screens are visually checked in simulator screenshots and the exported video. The final delivery MP4 was decoded and verified: **22.85 seconds (about 23 seconds), 1080 × 1080, approximately 30 fps, H.264, approximately 5.7 MB**, within the supplied 30-second limit. Its phone frame is presentation only; the feature behavior is recorded from the compiled app. Frames sampled from the final export are checked for the wrong-password error, authorized demo transfer, offer review and the matching gift panel. No production Telegram login, password or gift transaction was used.

## Limits

These results establish behavior of the standalone prototype only. They do not validate a production Telegram client/server integration, real SRP authentication, backend durability, recovery, paid transfers, TON, marketplace listings, device compromise resistance, accessibility conformance or every screen size/theme. The security authority in this package is an in-memory test double. See `INTEGRATION.md` for work required before release.
