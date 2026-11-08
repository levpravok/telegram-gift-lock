# Third-party asset

`Source/GiftLock/Assets.xcassets/ChatPattern.imageset/pattern.svg` is Telegram Web A's chat pattern, obtained from:

https://github.com/Ajaxy/telegram-tt/blob/master/src/assets/pattern.svg

The source repository distributes it under GNU GPL version 3. The complete license is preserved in `Telegram-WebA-GPL-3.0.txt`; the original SVG is included unmodified. The MIT license at this project's root applies to the original Swift implementation and scripts, not to this third-party asset. No Telegram client source code was copied into the Swift implementation.

## Public collectible artwork

The Nail Bracelet #4465 animation, Chili Pepper symbol and backdrop colours come from Telegram’s public gift preview at https://t.me/nft/NailBracelet-4465, retrieved on 8 November 2026. `Source/GiftLock/NailBracelet.json` is the original TGS animation decompressed from its gzip container without altering its vector artwork. `PepperPattern.imageset/pepper.png` is the public symbol image decoded from WebP to PNG. The original gift artwork remains the property of its respective creators; it is not covered by this project’s MIT license. It is used here as a reference asset for a Telegram feature proposal at the gift owner’s request.

The displayed owner, model, rarity, provenance and issued quantity reproduce the public preview and supplied screenshot. The displayed ₪834 value is the value shown in that screenshot, not a live quote. The screenshot itself, account credentials and private Telegram profile data are not included in this repository.

## Animation renderer

Lottie 4.6.1 is resolved from Airbnb’s official `lottie-spm` package. It is Apache 2.0 licensed; see `Lottie-Apache-2.0.txt`. The app bundles the gift JSON and pattern and does not contact Telegram at runtime.
