# Architecture

Belt Walkie-Talkie, mod `batman_BeltRadio`, version 1.2.0, Build 42.21. État décrit d'après le code du dépôt (2026-10-21).

## Vue d'ensemble

Le mod ne crée aucun objet ni aucune commande réseau. Il complète le comportement vanilla des radios d'inventaire par des gestionnaires d'événements et une enveloppe de fenêtre, chacun sur la machine qui fait autorité pour l'état concerné :

```
                       solo / client MP                                   solo / serveur
 ┌───────────────────────────────────────────────────────────┐   ┌────────────────────────────┐
 │ Core ── menu « Options de l'appareil »                    │   │ MainsPlaced                │
 │      ── enveloppe ISRadioWindow.update                    │   │  LoadGridsquare,           │
 │      ── écoute solo (OnTick) ──► deliver ─┬─► BeltNoise.emit   │  OnObjectAdded,            │
 │      ── bulle MP (OnDeviceText)           └─► BeltAudio.onReceive  EveryOneMinute         │
 │ BeltNoise ── OnAddMessage (client MP) ──► emit + BeltAudio│   │  pile des IsoRadio posés   │
 │ BeltBattery ── OnTick : DeviceData.update à la ceinture   │   └─────────────┬──────────────┘
 │ BeltAudio ── OnTick : émetteur libre (grésillement, émission)│               │
 │ MainsCarried ── OnTick : pile des radios portées          │                 │
 │ MainsTooltip ── fournisseur TooltipLib                    │                 │
 └──────────────┬────────────────────────────────────────────┘                 │
                │ require                                                      │ require
 ┌──────────────▼──────────────────────────────────────────────────────────────▼──────────┐
 │ shared : Support (VERSION, options, canTransmitWith) · Mains (règles secteur, recette) │
 │          Compat (Better Walkie Talkies)                                                │
 └────────────────────────────────────────────────────────────────────────────────────────┘
```

## Arborescence du mod

```
Contents/mods/batman_BeltRadio/
├── common/README.txt          dossier common exigé par la Build 42 (aucun fichier chargé)
└── 42.21/
    ├── mod.info               id=batman_BeltRadio, versionMin=42.21, require=\TooltipLib, modversion=1.2.0
    ├── poster.png, icon.png
    └── media/
        ├── sandbox-options.txt              6 options, page BeltRadio
        ├── scripts/BatmanRadio_recipes.txt  craftRecipe BatmanRadio_AdaptRadioMains (module Base)
        └── lua/
            ├── client/BatmanRadio/   BeltAudio, BeltBattery, BeltNoise, Core, MainsCarried, MainsTooltip
            ├── server/BatmanRadio/   MainsPlaced
            └── shared/
                ├── BatmanRadio/      Compat, Mains, Support
                └── Translate/<LANGUE>/  Recipes.json, Sandbox.json, UI.json (CN DE EN ES FR PT PTBR RU)
```

Une seule variante de version (`42.21`). `mod.info` ne déclare ni `loadModAfter` ni `loadModBefore`. La copie de travail contient en plus `incompatible=\KeepRadioOnVanillaFriendly` (modification non commitée au 2026-10-21, voir [specifications-techniques](specifications-techniques/README.md#modinfo)).

## Modules Lua

### `shared` (solo, client MP, serveur dédié)

| Fichier | Globale / module | Responsabilité |
|---|---|---|
| `BatmanRadio_Support.lua` | `BatmanRadioSupport` | `VERSION = 2`, `MOD_ID`, lecture des options (`option`, `enabled`), prédicat d'émission `canTransmitWith` |
| `BatmanRadio_Mains.lua` | `BatmanRadioMains` | appareils éligibles, état secteur en ModData, case électrifiée, application `useDelta`/recharge, `OnTest`/`OnCreate` de la recette |
| `BatmanRadio_Compat.lua` | module rendu par `require` | détection de Better Walkie Talkies (`BetterWalkieTalkies`, `BetterWalkieTalkiesDev`) et politique par machine (`features()`), micro, `say` |

### `client` (solo, client MP ; un serveur dédié ne les exécute pas)

| Fichier | Globale | Responsabilité |
|---|---|---|
| `BatmanRadio_Core.lua` | `BatmanRadioSupport` (même table) | menu contextuel, enveloppe `ISRadioWindow.update`, écoute solo des chaînes, bulle MP, registre des fournisseurs (`register`) |
| `BatmanRadio_BeltBattery.lua` | `BatmanBeltRadioBattery` | usure de la pile d'un talkie accroché (`DeviceData:update(false, true)` une fois par minute de jeu, puis `cleanSoundsAndEmitter`) |
| `BatmanRadio_BeltNoise.lua` | `BatmanBeltRadioNoise` | bruit pour les zombies à chaque ligne reçue (`addSound`, 2 s entre deux bruits par radio) ; détection MP par `OnAddMessage` |
| `BatmanRadio_BeltAudio.lua` | `BatmanBeltRadioAudio` | son local de la radio à la ceinture : reproduction de `DeviceData.updateEmitter` sur un émetteur libre gardé |
| `BatmanRadio_MainsCarried.lua` | `BatmanRadioMainsCarried` | pile des radios bricolées portées (main, dos, ceinture), case du joueur |
| `BatmanRadio_MainsTooltip.lua` | — | fournisseur TooltipLib `batman_BeltRadio_Mains` (« Bricolée pour le secteur », « En charge sur le secteur ») |

### `server` (solo, serveur ; chargé aussi par un client MP mais inactif : `if not isClient()`)

| Fichier | Globale | Responsabilité |
|---|---|---|
| `BatmanRadio_MainsPlaced.lua` | `BatmanRadioMainsPlaced` | pile des `IsoRadio` posés (objet 3D lié par `RadioItemID` ou tuile), marque gardée pour le ramassage |

### Dépendances `require`

- `Core` → `ISUI/ISRadioAndTvMenu`, `RadioCom/ISRadioWindow`, `BeltBattery`, `BeltNoise`, `BeltAudio`, `Support`, `Compat`.
- `BeltNoise` → `Support`, `BeltAudio` ; `BeltAudio` → `Support` ; `BeltBattery` → `Compat`, `Support`.
- `Support` → `Compat` ; `Mains` → `Support` ; `MainsCarried`, `MainsPlaced` → `Mains` ; `MainsTooltip` → `TooltipLib/Core`, `Mains`.

Chaque module garde sa table globale au rechargement Lua et retire ses anciens abonnés avant de s'inscrire de nouveau (pas de doublon d'événement, enveloppe de fenêtre posée une seule fois).

## Flux de données

### Événements

| Événement | Module | Machine | Rôle |
|---|---|---|---|
| `OnGameStart` | Core | solo | inscrit `OnTick` du récepteur (seulement si `Compat.features().scenarioReception`, c'est-à-dire solo) |
| `OnTick` | Core | solo | `PlayerListensChannel` pour les fréquences des talkies accrochés, puis suivi des lignes diffusées par chaque chaîne |
| `OnFillInventoryObjectContextMenu` | Core | client | option « Options de l'appareil » |
| `OnDeviceText` | Core | client MP | bulle radio d'un talkie accroché |
| `OnAddMessage` | BeltNoise | client MP | bruit et son d'émission à chaque ligne du chat radio reçue par un talkie accroché |
| `OnTick` | BeltBattery, BeltAudio, MainsCarried | solo, client MP | pile à la ceinture, son, pile secteur des radios portées |
| `LoadGridsquare`, `OnObjectAdded`, `EveryOneMinute` | MainsPlaced | solo, serveur | repérage et mise à jour des appareils posés |
| `OnDisconnect`, `OnMainMenuEnter` | Core, BeltBattery, BeltNoise, BeltAudio, MainsCarried | client | remise à zéro des états en mémoire |

Fonction vanilla enveloppée : `ISRadioWindow.update` (Core), pour garder ouverte la fenêtre d'un talkie accroché ou en cours de prise en main au lieu de l'éteindre. L'enveloppe n'est reposée que si la classe `ISRadioWindow` a changé (rechargement de son fichier) : celle d'un autre mod posée après nous est laissée en place.

### Écoute solo

`Core.onTick` parcourt le registre de chaînes (`getZomboidRadio():getScriptManager():getChannelsList()`) plus les chaînes des fournisseurs, suit `getAiringBroadcast()` et le numéro de ligne courant de chaque chaîne, et livre chaque nouvelle ligne (`deliver`) au premier talkie accroché qui la recevrait en main, sauf si la radio équipée la reçoit déjà. La ligne passe par le brouillage de l'orage (`weathered`) puis `Radio:AddDeviceText` à 7 arguments (bulle et `OnDeviceText`), `BeltNoise.emit` et `BeltAudio.onReceive`. Les publicités et pauses, qui n'avancent pas le compteur principal, sont livrées en gris d'après `getLastAiredLine`.

### Multijoueur et autorité

- **Aucune commande réseau** (`sendClientCommand`/`sendServerCommand` absents).
- Réception MP : faite par le vanilla (toutes les radios allumées de l'inventaire principal) ; le mod n'ajoute que la bulle (`OnDeviceText`), le bruit et le son (`OnAddMessage`).
- Bruit : `addSound` depuis le client, relayé au serveur par le moteur.
- Pile à la ceinture et secteur des radios portées : client (ou solo), qui décompte la pile d'une radio d'inventaire ; le serveur l'apprend par les paquets de pile vanilla envoyés quand la radio est allumée.
- Recette : `OnCreate` sur le solo ou le serveur, puis `syncItemFields(character, item)` vers le client.
- Appareils posés : solo ou serveur (`MainsPlaced`).
- Prédicat `canTransmitWith` : partagé ; sur un serveur, le micro n'est pas vérifié.

## Persistance

| Donnée | Emplacement | Format |
|---|---|---|
| Radio bricolée (objet d'inventaire) | ModData de l'objet, clé `BatmanMains` | `{ useDelta = <usure d'origine par heure> }` |
| Appareil posé comme tuile | ModData de l'`IsoRadio` : clé `BatmanMains` (recopiée à la pose) et `movableData.BatmanMains` (ajoutée par `Mains.keepOnPickup`) | même table |
| Objet 3D posé au sol | lu sur l'objet d'inventaire lié par la clé vanilla `RadioItemID` de l'`IsoRadio` | — |

Les autres états (chaînes suivies, dernière bulle, fréquences reconnues, minutes de pile, émetteurs) sont en mémoire et remis à zéro à la déconnexion ou au menu principal. Aucune ModData globale, aucun fichier. Migration : une radio ramassée sous 1.1.0 a perdu sa marque (`movableData` absente) et doit être bricolée de nouveau ; les appareils déjà posés sous 1.1.0 reçoivent `movableData.BatmanMains` à leur prochain chargement.

## Points d'extension et intégrations

- **API publique** `BatmanRadioSupport` (niveau 2) : fournisseurs de chaînes, fréquences publiques et secrètes, radios rangées, actions de prise en main ; `canTransmitWith` ; `BatmanRadioMains` ; `BatmanBeltRadioNoise.emit`. Contrat : [api-publique.md](specifications-techniques/api-publique.md).
- **Mods dépendants** (`require=batman_BeltRadio`) : Military Drop (depuis 0.5.1), Opération Artemis (depuis 0.4.1), Radio Survivor.
- **TooltipLib** (prérequis, `require=\TooltipLib`) : ligne d'infobulle des radios bricolées.
- **Better Walkie Talkies** : détecté par ses identifiants ; quand il est actif, ce mod laisse la pile à la ceinture et la bulle MP à BWT et passe par son pont micro (`RadioTextBridgeHandler`).

## Outillage

- `tests/run_all.py` : luacheck (`.luacheckrc`, exigé en CI par `--require-luacheck`), syntaxe Lua 5.1 et contraintes Kahlua (`next`, littéraux non ASCII), `mod.info`, options sandbox et traductions, descriptions Steam (8 000 octets, liens, `workshop.txt` = `README.steam`), tests Lua `tests/lua/test_*.lua` sous `lupa` avec l'API du jeu simulée (`tests/lua_harness.py`). Vérifications lisant le jeu installé (`PZ_MEDIA`) ou BWT (`BWT_LUA`) ignorées s'ils sont absents. Aucun test en jeu.
- CI : `.github/workflows/checks.yml` (Ubuntu 24.04, Python 3.12, `lua-check`, `lupa`, `pillow`).
- `tools/` : vide dans le dépôt (l'outil `sync_fallback.py` a été retiré le 2026-10-10).
