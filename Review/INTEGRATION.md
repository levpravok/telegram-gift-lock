# Integration proposal — not an existing Telegram API

## Boundary

`GiftLockService` isolates the presentation flow from the authority that approves and commits an operation. The included `DemoGiftService` is local, volatile and deliberately uses a known sample password. The bracelet artwork and displayed attributes are public reference assets; they do not provide access to the real gift or its owner’s account. It demonstrates state transitions; it is not an implementation of Telegram authentication, a secure server or an adapter that can currently call a production Gift Lock endpoint.

Telegram's iOS client uses its own components, engine and asynchronous infrastructure. The SwiftUI screens can run independently or be hosted as a prototype, but a production patch would need to follow those conventions, themes, localization, accessibility and navigation. No unverified patch against Telegram's repository is included.

## Proposed server transaction

This is a design contract for Telegram to implement, not a claim that these RPCs already exist:

1. Resolve an authenticated account/session and read the lock policy from durable server storage.
2. Accept an intent containing a stable gift reference plus recipient peer ID, or a real offer message ID. Derive every financial field from authoritative server state. Never trust a message's prose, a deep-link label, a username alone or a client-supplied “net proceeds” value.
3. Return an opaque, short-lived challenge and review details: operation, gift ID, destination ID, currency, amount, fee, net proceeds, validity and policy revision. Bind it to the account, session and immutable transaction fingerprint. Make the displayed destination distinguishable from another account with a similar display name.
4. At commit, require a fresh SRP proof for the account's existing 2-Step password whenever the account policy requires it. Scope the successful proof to the same challenge. Do not allow a successful general password check to become a reusable “gifts unlocked” session flag. Reuse Telegram's existing, reviewed SRP/KDF implementation. [Official SRP specification](https://core.telegram.org/api/srp)
5. In a single atomic server transaction, validate proof, challenge ownership, expiration, non-consumption, lock revision, offer validity, gift ownership, recipient eligibility and all pricing/cooldown constraints. Consume the challenge and mutate gift ownership/payment together. Invalidate or re-review changed quotes. Apply server-side account-wide abuse controls.
6. Return a stable receipt/update. For a network timeout, reconcile by challenge/operation ID before retrying. Production must retain the outcome long enough to make retries idempotent; the local prototype rejects replay but does not implement durable result lookup.

No client-only prompt can satisfy steps 1–6. Installing this prototype changes no real Telegram account settings.

## Existing endpoints to consider

| Existing operation | Integration requirement |
| --- | --- |
| `payments.resolveStarGiftOffer` | Gate acceptance through the policy; declining should remain easy. [Reference](https://core.telegram.org/method/payments.resolveStarGiftOffer) |
| `payments.transferStarGift` | Apply the policy to free transfers and every alternative invocation path. [Reference](https://core.telegram.org/method/payments.transferStarGift) |
| Paid gift transfers | Gate both review and final ownership mutation in the invoice/payment flow. A password screen only around the free-transfer method would leave a gap. [Gift transfer flow](https://core.telegram.org/api/gifts#transferring-collectible-gifts) |
| `payments.getStarGiftWithdrawalUrl` | Preserve its existing password and age/cooldown checks; harmonize presentation without weakening them. [Reference](https://core.telegram.org/method/payments.getStarGiftWithdrawalUrl) |
| Resale listings, conversion, deletion, crafting, channel-owned gifts and automation | Audit all operations that can remove, destroy or later sell the owner's gifts. Require equivalent authorization or explicitly restrict them while locked. These paths are not implemented in this prototype. |

The public API schemas for free transfers and offer acceptance do not expose the proposed transaction-bound challenge. A new API layer or equivalent server extension would be needed. Do not invent an optional password argument in an existing generated RPC and claim it already works.

## Enrollment, recovery and cross-device behavior

The prototype assumes an existing 2-Step password and starts enabled. A production opt-in should first check whether a password exists and route through Telegram's established setup when absent. The setup and opt-in should be separately understandable.

Lock changes must be enforced at account level, authorized remotely and propagated to all clients. Unsupported clients should receive an explicit update-required/auth-required error instead of succeeding through a legacy route. Audit business connections, bots and any delegated ability to manage gifts.

Recovery cannot silently disable the policy. Telegram must define how lock state interacts with 2FA removal, email recovery, resets and newly authorized sessions; use existing security delays/notifications where appropriate rather than the prototype's arbitrary timing. Revoke outstanding reviews on policy/password/session changes. The provided 60-second review and 30-second retry delay are sample values, not recommended replacements for Telegram's established controls.

## Deliberate scope choices

- No password for simply receiving or viewing a gift, declining an offer, or hiding a gift.
- Opt-in protection, with no “remember authorization” option in the first version.
- Password authorization instead of relying on the app passcode, a local boolean or simulated biometric success.
- Fixed fictional recipient and Stars-only quote in the demo. Production needs recipient resolution/search, currency-safe amounts (including TON where supported), live fees, localization and server receipts.
- No promise of recovery or reversal after an authorized transfer.

## Release verification still needed

Validate policy enforcement using a second client and direct authorized API requests, paid and free transfer paths, stale prices, concurrent offer acceptance, network failure after commit, credential changes, old clients, business connections and recovery. Test Dynamic Type, VoiceOver, supported themes, translated strings and device sizes in Telegram's actual client. The included tests validate only the standalone prototype's stated scope.
