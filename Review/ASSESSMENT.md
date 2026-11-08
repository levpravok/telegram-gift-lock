# Is the idea worth submitting?

Reviewed against public primary sources on **8 November 2026**.

**Yes, as a focused refinement.** The useful idea is an optional, consistently enforced authorization policy for outgoing collectible gifts. A general suggestion to add “a password before accepting gifts” is too ambiguous and partly overlaps existing safeguards. Receiving a gift should remain easy; accepting an offer means selling a gift, which is the action this proposal protects.

## What already exists

| Verified behavior | Why it matters |
| --- | --- |
| Telegram already has gift purchase offers with reserved payment, refunds for rejection/expiry, and a sale confirmation step. | Avoid claiming that all existing offer acceptance is an unprotected single tap. [Official announcement](https://telegram.org/blog/passkeys-and-gift-offers) |
| The documented offer-resolution method takes an offer message ID and a decline flag, without an explicit password field. | A fresh password check for accepting an offer is a plausible extension. This schema does not prove the absence of every other server-side restriction. [API method](https://core.telegram.org/method/payments.resolveStarGiftOffer) |
| The documented free-transfer method takes the gift and destination, without an explicit password field. | Ordinary transfers are a relevant place to propose consistent authorization. [API method](https://core.telegram.org/method/payments.transferStarGift) |
| Gift withdrawal to the blockchain already requires a 2FA password. | The proposal extends existing protection instead of inventing a first password safeguard. [Withdrawal API](https://core.telegram.org/method/payments.getStarGiftWithdrawalUrl) |
| The public iOS engine exposes gift transfer and offer resolution separately from withdrawal; withdrawal accepts a password. | There are identifiable integration boundaries in the client. [Telegram iOS source](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/TelegramCore/Sources/TelegramEngine/Payments/TelegramEnginePayments.swift) |

The current source and published APIs were inspected. This was not an exhaustive audit of every Telegram client, private server implementation, experiment or region, and no real gift transaction was attempted. I did not establish that nobody has proposed a similar idea before.

## The stronger version of your idea

**Gift Lock:** an account-level opt-in setting that asks for the existing 2-Step Verification password immediately before an outgoing gift transaction. The review shows the specific gift, the destination and exactly what the owner receives. A free transfer prominently says that the owner receives zero Stars. Turning the setting off also requires authorization.

Use the existing 2-Step password initially. A separate gift PIN would add enrollment, forgotten-PIN recovery and another secret to manage. Those costs are difficult to justify for a small first version. Local Face ID could improve convenience later, but it cannot independently authenticate an account-wide transaction to Telegram's servers.

## What is convincing

- **A narrow, understandable benefit:** a mistaken confirmation is less likely to become an irreversible action.
- **Clear transaction meaning:** a purported paid offer that actually initiates a free transfer becomes easier to notice.
- **A coherent setting:** owners who want extra friction can choose it, with the same rule on every participating client.
- **A natural fit:** it builds on an authentication mechanism Telegram already uses for sensitive operations. [Telegram's SRP documentation](https://core.telegram.org/api/srp)

These are product hypotheses, not measured results. No user research or incident-rate study was conducted. The demo shows behavior, not evidence of a quantified reduction in scams. The current presentation matches the supplied real Nail Bracelet #4465 panel using publicly downloadable gift assets, with all transactions still simulated locally.

## Where the idea is weaker

Repeated password entry can annoy frequent traders and create authorization fatigue. Some people will still approve harmful transactions after a scammer coaches them. A fresh check can resist a stolen logged-in session only if the attacker lacks the required secret and Telegram rejects alternate routes on the server. It does not protect against stolen passwords, malware controlling an authorized device, compromised recovery, or coercion.

A client-only lock would be bypassable. An account lock also needs a plan for old clients, business automation, recovery and every path that can remove or destroy gifts. Those are substantial server changes for Telegram, even though the visible interface is small.

## Submission fit

Telegram's current Designers × AI post asks for working code plus a video of it running. This package supplies both. The channel welcome message supplied by the user further requires a video of at most 30 seconds, a code link, and a title plus description of at most 250 characters. The revised package follows those limits; a source ZIP alone does not replace the requested link. [Verified submission post](https://t.me/designers/266)

However, the code is a standalone SwiftUI prototype and an in-memory policy model, rather than a patch already integrated with Telegram's client architecture and server. That gap should be stated openly. It may still be useful to the team, but strict interpretation of “ready-to-implement” could favor a submission already implemented inside their codebase. There is no public evidence here that guarantees their acceptance or estimates its chances.

**Recommendation:** submit the refined Gift Lock concept with the runnable native implementation, actual recording and explicit integration notes. Do not describe it as complete anti-scam protection or as a feature already securing your account.
