# Changelog

## 0.1.0 — 2026-10-10

First version, extracted from Military Drop (shared receiver `BatmanRadio`).

### For players
- **Device Options** on a walkie-talkie hooked on the belt; its window no longer switches it off, even while you take it in hand.
- Singleplayer: a switched-on walkie-talkie at the belt hears the station it is tuned to, with the radio bubble; storms scramble it like in hand.
- Multiplayer: a line received by a radio you are not holding also shows in a radio bubble above your character.
- The battery drains at the belt, as in hand.
- You cannot transmit from the belt; a radio stored in the inventory hears nothing in singleplayer.
- Three sandbox options (page **Belt Walkie-Talkie**), on by default; off gives back the vanilla behaviour: bubble for an unheld radio (multiplayer), battery drain at the belt, listening at the belt (singleplayer).
- Translations: English, French, German, Spanish, Portuguese, Brazilian Portuguese, Russian, Simplified Chinese.

### For modders
- Lua API `BatmanRadioSupport` (same paths and global as the copies embedded in Military Drop and Operation Artemis): `VERSION`, `register` (channels, public frequencies, recognition of secret frequencies by line codes, opening of a stored radio, taking actions), `canTransmitWith` shared with the server, `option` / `enabled`. See `docs/API.md`.
