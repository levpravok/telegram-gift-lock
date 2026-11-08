# Gift Lock — Telegram feature proposal

[Watch the 28-second demo](Media/GiftLock-Demo.mp4) · [Submission text](Review/SUBMISSION-MESSAGE.txt)

![Gift Lock in a Telegram-style chat](Media/preview.png)

A runnable native iPhone prototype, presented in a Telegram-style chat, of an optional password check before transferring a collectible gift or accepting a purchase offer. It extends the idea of existing withdrawal protection to everyday gift actions.

**Status:** working, offline SwiftUI implementation with a testable policy model. This is not a modified Telegram client, a ready-to-merge Telegram patch, or protection for a real account. Telegram must implement and enforce the proposed policy on its servers before it can protect stolen sessions. No real credentials, gifts, payments, or Telegram APIs are used.

## Try it

1. Open `GiftLock.xcodeproj` in Xcode 15 or later (validated with Xcode 26.4.1).
2. Select the **GiftLock** scheme and an iPhone simulator running iOS 17 or later. Press Run. No dependencies or Telegram API keys are needed.
3. Tap **Accept** on the purchase offer, inspect the details, then continue with the password.
4. Enter the fictional password **gift-demo-2026**. A wrong password leaves the gift untouched; the correct one removes it from the collection and credits the sample net proceeds.
5. Tap the paperclip to open **My Gifts**, then select a gift to review a transfer to the fixed sample recipient. Cancel to keep it.
6. Open **Gift Lock is on** to review the setting. Turning it off also requires the sample password. When off, transfers and offers retain their review step.

The avatar menu in the upper right offers **Reset sample data** and **Play 25-second demo**. All state is in memory and resets on app relaunch. The sample account starts with Gift Lock already enabled and an assumed existing 2-Step Verification password. Enrollment and password recovery are outside the prototype.

## What the code actually does

- Implements a Telegram-style chat and offer card, collection, compact review sheets, password, error, success and lock settings in SwiftUI.
- Runs a deterministic in-memory authority that owns the canonical action, gift, recipient, fee and price.
- Checks the demo password on commit, binds a review to a session and one operation, expires it after 60 seconds, rejects replays and invalidates pending reviews after mutations.
- Limits incorrect password attempts across the two fictional sessions: five failures trigger a 30-second pause.
- Clears the password after each attempt and when the app becomes inactive. Cancels the current review when backgrounded.
- Makes the difference between a sale and a gift transfer explicit; transfers display zero proceeds.

The known demo password and local actor are intentional test doubles. They do not provide production authentication or protection against a modified client. The `GiftLockService` protocol is the integration boundary. Production must use remote verification and Telegram's existing SRP implementation, rather than comparing passwords locally.

## Files

| File | Purpose |
| --- | --- |
| `Source/GiftLock/GiftLockApp.swift` | Interactive app, reusable screen flow and guided demo |
| `Source/GiftLock/GiftLockCore.swift` | Service contract, immutable reviews and in-memory reference authority |
| `Tests/GiftLockCoreTests.swift` | Policy tests |
| `TestsUI/GiftLockUITests.swift` | Tests of the actual iPhone interface |
| `Review/ASSESSMENT.md` | Research, realistic verdict and limitations |
| `Review/INTEGRATION.md` | Proposed server contract and integration work |
| `Review/VALIDATION.md` | Observed build, test and video checks |
| `Review/SUBMISSION-MESSAGE.txt` | Message to paste when sending the code and video |
| `Scripts/record-demo.sh` | Repeatable simulator recording instructions |

## Run the tests

Policy tests on macOS:

```sh
swift test
```

UI tests: select the GiftLock scheme in Xcode, choose an iPhone simulator and press **Command-U**. From a terminal:

```sh
xcodebuild -project GiftLock.xcodeproj -scheme GiftLock \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

Choose an available iPhone simulator on your machine if its name differs. Running on a physical iPhone requires selecting your own signing team in Xcode.

## Demo integrity

The video is a screen recording of this compiled iOS app, framed inside a phone on a gradient background to match the supplied presentation references. Its duration is under 30 seconds. The guided sequence calls the same review and commit methods used by the interactive controls, including the wrong-password failure and successful sale. It is scripted execution of running code, not a motion-design video. The recording contains fictional data and illustrative pricing. The 480-Star fee is a sample value, not a claim about Telegram's current fees. A real implementation must show live, authoritative fees and any actual transfer charge.

## Scope and remaining work

Implemented: sample Stars offer acceptance, free gift transfer to one fictional recipient, lock changes and policy error handling. Not implemented: Telegram networking, SRP, durable server storage, real enrollment/recovery, recipient search, TON amounts, paid-transfer invoices, real marketplace listings, exports or gift destruction/crafting. See `Review/INTEGRATION.md` for requirements before release.

Telegram’s supplied channel welcome message asks for a video of at most 30 seconds, a link to working code, and a title plus description of at most 250 characters. The ZIP is a local handoff/backup; a publicly accessible code repository link is required for the actual submission. The prepared title and description total 199 characters.

The chat wallpaper comes from Telegram Web A; see `ThirdParty/ATTRIBUTION.md` and its preserved license. The original Swift code and scripts are MIT licensed.

The proposal is suitable for review as a working feature prototype. Telegram's acceptance of it under its ready-to-implement-code requirement is their decision; this package cannot promise selection, payment, or a production rollout.
