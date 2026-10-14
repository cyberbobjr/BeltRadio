# Changelog

## 1.2.0 — 2026-10-14

### For players
- **Sound at the belt:** a switched-on walkie-talkie hooked on the belt now plays the radio sound as in hand: static while it waits, then the broadcast sound for each line received (emergency broadcast sound on the emergency channel). In vanilla a walkie-talkie at the belt was silent and only showed text. Only you hear it, as in hand. Sandbox option **Sound of a walkie-talkie at the belt**, on by default.

## 1.1.1 — 2026-10-10

### For players
- **Mains power, HAM radios placed down:** a HAM radio adapted for mains power and placed as furniture (or a walkie-talkie placed with **Place**) is now powered by the mains: no more battery drain, and the battery recharges in an electrified area. Radios already placed with 1.1.0 are handled automatically once their area is loaded.
- An adapted radio placed as furniture and picked up again stays adapted (tooltip line kept). A radio already picked up with 1.1.0 lost its adaptation: craft **Adapt Radio for Mains Power** on it again.

## 1.1.0 — 2026-10-10

### For players
- **Noise at the belt:** a switched-on walkie-talkie hooked on the belt now makes a noise that attracts zombies each time it receives a line, as in hand (same volume and range, none with headphones). In vanilla it only made noise for the first line. Sandbox option **Noise of a walkie-talkie at the belt**, on by default.
- **Mains power:** new recipe **Adapt Radio for Mains Power** (Electrical 1, a screwdriver kept, 2 electronics scraps, 1 electric wire, 10 Electrical XP) for walkie-talkies, HAM radios and the military backpack radio. In an electrified area (generator, or grid power inside a building), an adapted radio no longer drains its battery and recharges it, even switched off; a battery must still be inside. Works carried (hand, back, belt) and placed on the ground. Sandbox option **Mains recharge time** (10 in-game hours by default).
- The item tooltip shows an adapted radio and when it is charging.
- **New requirement:** [TooltipLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3694097672).

### For modders
- API level `VERSION = 2`: global `BatmanRadioMains` (`isModified`, `isPoweredSquare`, `state`) and `BatmanBeltRadioNoise.emit`. See `docs/API.md`.

### Known limits
- Multiplayer: the charge of a carried radio reaches the server only through the vanilla battery updates sent while it is switched on.
- Multiplayer noise for lines from other players relies on the radio chat event; not tested in game yet.

## 1.0.0 — 2026-10-10

First release. The walkie-talkie behaviour shared by Military Drop, Operation Artemis and Radio Survivor, now as its own mod.

### For players
- **Device Options** on a walkie-talkie hooked on the belt; its window no longer switches it off, even while you take it in hand.
- Singleplayer: a switched-on walkie-talkie at the belt hears the station it is tuned to and shows its lines in a radio bubble above your character; storms scramble it like in hand.
- Multiplayer: a line received by a walkie-talkie hooked on the belt also shows in a radio bubble above your character (the game alone only puts it in the radio chat).
- The battery drains at the belt, as in hand.
- To talk, take the walkie-talkie in hand (or carry the radio on your back): transmitting from the belt is refused. A radio stored in the inventory hears nothing in singleplayer.
- Three sandbox options (page **Belt Walkie-Talkie**), on by default; off gives back the vanilla behaviour: radio bubble (multiplayer), battery drain at the belt, listening at the belt (singleplayer).
- Translations: English, French, German, Spanish, Portuguese, Brazilian Portuguese, Russian, Simplified Chinese.

### For modders
- Lua API `BatmanRadioSupport` (same paths and global as the copies embedded in Military Drop and Operation Artemis): `VERSION`, `register` (channels, public frequencies, recognition of secret frequencies by line codes, opening of a stored radio, taking actions), `canTransmitWith` shared with the server, `option` / `enabled`. See `docs/API.md`.
- Optional dependency pattern: a mod can embed a fallback copy under its own path that stays inactive while Belt Walkie-Talkie is enabled (`tools/sync_fallback.py`).
