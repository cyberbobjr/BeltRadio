# Belt Walkie-Talkie

**Project Zomboid Build 42.21 · Singleplayer & Multiplayer · No other mod required**

A walkie-talkie hooked on the belt can be tuned, stays on when its window is open, hears the station it is tuned to in singleplayer, shows a radio bubble in multiplayer and drains its battery. It never transmits from the belt: take it in hand (or wear a radio on the back) to talk. A radio stored in the inventory hears nothing in singleplayer.

This mod is also the shared receiver (`BatmanRadio`) of Military Drop, Operation Artemis and Radio Survivor, extracted from Military Drop (`source/radio`, commit `15d1066`).

- Mod ID: `batman_BeltRadio` (Workshop ID: not published yet)
- Lua API for other mods (in French): [docs/API.md](docs/API.md)
- Design decisions (in French): [docs/DECISIONS.md](docs/DECISIONS.md)
- Changes: [CHANGELOG.md](CHANGELOG.md)

## Sandbox options

Page `BeltRadio`, all `true` by default; `false` gives back the vanilla behaviour, read at each use (a change in the middle of a game applies at once).

| Option | Effect |
|---|---|
| `BeltRadio.MPBubble` | Multiplayer: radio bubble above the player for a line received by a walkie-talkie on the belt |
| `BeltRadio.BeltBattery` | Battery drain of a switched-on walkie-talkie at the belt |
| `BeltRadio.BeltListening` | Singleplayer: a walkie-talkie at the belt hears its station |

## Repository layout

```
Contents/mods/batman_BeltRadio/
  common/          Build 42 common folder
  42.21/           mod.info, poster, icon and media (Lua, sandbox options, translations)
    media/lua/client/BatmanRadio/   receiver (menu, window, singleplayer listening, MP bubble, battery)
    media/lua/shared/BatmanRadio/   API shared with the server (VERSION, options, canTransmitWith) and BWT compatibility
docs/              API and design decisions (French)
tests/             checks without the game (lupa)
tools/check_case.py  path case check for Linux servers
tools/sync_fallback.py  writes the fallback copies embedded in Military Drop and Operation Artemis (--check compares)
README.steam*      Steam Workshop descriptions (English = workshop.txt)
```

## Checks

```
pip install lupa pillow
python tests/run_all.py
```

Luacheck (if installed), Lua 5.1 syntax and Kahlua constraints, `mod.info`, sandbox options and translations, Steam descriptions (8,000-byte limit), path case (Linux), and the Lua tests (game API simulated with `lupa`). Nothing here is an in-game test.

## License

MIT, see [LICENSE](LICENSE).

---

## Français

Un talkie-walkie accroché à la ceinture se règle, reste allumé quand sa fenêtre est ouverte, entend en solo la station sur laquelle il est réglé, affiche une bulle radio en multijoueur et use sa pile. Il n'émet jamais depuis la ceinture : il faut le prendre en main (ou porter une radio sur le dos) pour parler. Une radio rangée dans l'inventaire n'entend rien en solo.

Ce mod est aussi le récepteur commun (`BatmanRadio`) de Military Drop, Opération Artemis et Radio Survivor, extrait de Military Drop (`source/radio`, commit `15d1066`).

- Identifiant : `batman_BeltRadio` (pas encore publié)
- API Lua pour les autres mods : [docs/API.md](docs/API.md)
- Décisions de conception : [docs/DECISIONS.md](docs/DECISIONS.md)
- Vérifications hors jeu : `python tests/run_all.py`
