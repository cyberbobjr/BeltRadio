# Spécifications techniques

Contrats de Belt Walkie-Talkie 1.2.0 pour Project Zomboid **Build 42.21**. Fonctionnalités `Fnn` : [specifications-fonctionnelles.md](../specifications-fonctionnelles.md). Architecture : [architecture.md](../architecture.md).

| Page | Contenu |
|---|---|
| Ce fichier | `mod.info`, recette, objets, ModData, options sandbox, traductions, globales Lua, réseau, compatibilités |
| [api-publique.md](api-publique.md) | API Lua publique `BatmanRadioSupport` (niveau `VERSION = 2`) pour les autres mods |

## `mod.info`

Fichier `Contents/mods/batman_BeltRadio/42.21/mod.info` (seule variante ; `common/` ne contient qu'un `README.txt`).

| Clé | Valeur |
|---|---|
| `id` | `batman_BeltRadio` |
| `name` | `Belt Walkie-Talkie` |
| `versionMin` | `42.21` |
| `require` | `\TooltipLib` |
| `modversion` | `1.2.0` |
| `poster`, `icon` | `poster.png`, `icon.png` |
| `incompatible` | `\KeepRadioOnVanillaFriendly` — **présent seulement dans la copie de travail** au 2026-10-21 (non commité, non publié) |

Workshop : `3817018338` (`workshop.txt`). Objet requis Steam : TooltipLib `3694097672`.

## Recette

`media/scripts/BatmanRadio_recipes.txt`, `module Base` :

```
craftRecipe BatmanRadio_AdaptRadioMains
    timedAction = MakingElectrical, time = 100, SkillRequired = Electricity:1,
    OnTest = BatmanRadioMains.onTestAdapt, OnCreate = BatmanRadioMains.onCreateAdapt,
    Tags = InHandCraft;Electrical, category = Electrical, xpAward = Electricity:10,
    AllowBatchCraft = false
    inputs
        item 1 [Base.WalkieTalkie1..5; Base.WalkieTalkieMakeShift; Base.HamRadio1; Base.HamRadio2;
                Base.HamRadioMakeShift; Base.ManPackRadio] mode:keep flags[NoBrokenItems]
        item 2 [Base.ElectronicsScrap] flags[NoBrokenItems]
        item 1 [Base.ElectricWire] flags[NoBrokenItems]
        item 1 tags[base:screwdriver] mode:keep flags[NoBrokenItems]
```

- `OnTest(item, character)` : faux pour un appareil éligible déjà modifié, vrai sinon.
- `OnCreate(craftRecipeData, character)` (solo ou serveur) : pour chaque objet gardé (`getAllKeepInputItems`) éligible et non modifié, écrit `ModData.BatmanMains = { useDelta = getUseDelta() × 60 }` (repli `0.014` si ≤ 0), puis `syncItemFields(character, item)`.
- Éligible (`Mains.isEligible`) : `instanceof(item, "Radio")`, type complet listé dans `Mains.ITEM_TYPES` (les 10 types ci-dessus), `DeviceData:getIsBatteryPowered()`.

Aucun objet ni modèle nouveau.

## ModData

| Porteur | Clé | Format | Écrit par |
|---|---|---|---|
| objet d'inventaire `Radio` | `BatmanMains` | `{ useDelta = number }` (usure d'origine par heure) | `Mains.onCreateAdapt` |
| `IsoRadio` posé comme tuile | `BatmanMains` | idem, recopiée de l'objet par `ISMoveableSpriteProps` à la pose | moteur vanilla |
| `IsoRadio` posé comme tuile | `movableData.BatmanMains` | idem | `Mains.keepOnPickup` (rendu par le ramassage) |
| `IsoRadio` objet 3D | `RadioItemID` (clé vanilla, lue seulement) | identifiant de l'objet d'inventaire posé sur la case | moteur vanilla |

`Mains.state(item)` cherche `BatmanMains` à la racine puis dans `movableData`. Règle appliquée par `Mains.apply(state, data, onMains, minutes)` :

- hors secteur : `setUseDelta(useDelta d'origine)` si différent (`getUseDelta` rend l'usure par minute, `setUseDelta` attend l'usure par heure) ;
- sur secteur : `setUseDelta(0)` ; si une pile est présente et `getPower() < 1`, `setPower(min(1, power + minutes / (MainsRechargeHours × 60)))`.

Case électrifiée (`Mains.isPoweredSquare`) : `square:haveElectricity()`, ou `square:hasGridPower()` et `square:getRoom() ~= nil` (règle de `DeviceData.canBePoweredHere`).

## Options sandbox

`media/sandbox-options.txt`, `VERSION = 1`, page `BeltRadio`.

| Option | Type | Défaut | Bornes | Lue par |
|---|---|---|---|---|
| `BeltRadio.MPBubble` | boolean | `true` | — | `Core.onDeviceTextMP` |
| `BeltRadio.BeltBattery` | boolean | `true` | — | `BeltBattery.onTick` |
| `BeltRadio.BeltListening` | boolean | `true` | — | `Core.onTick` |
| `BeltRadio.BeltNoise` | boolean | `true` | — | `BeltNoise.emit` |
| `BeltRadio.BeltAudio` | boolean | `true` | — | `BeltAudio.onReceive`, `BeltAudio.onTick` |
| `BeltRadio.MainsRechargeHours` | integer | `10` | 1 à 240 (code : au moins 1) | `Mains.rechargeHours` |

Lecture (`Support.option`) à chaque usage : `getSandboxOptions():getOptionByName("BeltRadio.<nom>"):getValue()`, repli `SandboxVars.BeltRadio.<nom>`, puis `Support.OPTION_DEFAULTS`. `Support.enabled(nom)` est faux seulement si la valeur vaut `false`.

## Traductions

`media/lua/shared/Translate/<LANGUE>/`, langues `CN`, `DE`, `EN`, `ES`, `FR`, `PT`, `PTBR`, `RU` (référence `EN`, mêmes clés vérifiées par `tests/run_all.py`).

| Fichier | Clés |
|---|---|
| `Recipes.json` | `BatmanRadio_AdaptRadioMains` |
| `Sandbox.json` | `Sandbox_BeltRadio` (page), `Sandbox_BeltRadio_<Option>` et `Sandbox_BeltRadio_<Option>_tooltip` pour les 6 options |
| `UI.json` | `UI_BeltRadio_TooltipProvider`, `UI_BeltRadio_MainsAdapted`, `UI_BeltRadio_MainsCharging` |

Clé vanilla réutilisée : `IGUI_DeviceOptions` (menu). Messages de journal en anglais, préfixe `[BeltRadio]`.

## Globales Lua

| Globale | Fichier | Statut |
|---|---|---|
| `BatmanRadioSupport` | `shared/…/BatmanRadio_Support.lua` + `client/…/BatmanRadio_Core.lua` | API publique |
| `BatmanRadioMains` | `shared/…/BatmanRadio_Mains.lua` | API publique (niveau 2) ; `onTestAdapt`/`onCreateAdapt` référencés par la recette |
| `BatmanBeltRadioNoise` | `client/…/BatmanRadio_BeltNoise.lua` | API publique (`emit`, niveau 2) |
| `BatmanBeltRadioBattery` | `client/…/BatmanRadio_BeltBattery.lua` | interne (conservée pour les anciennes copies de secours) |
| `BatmanBeltRadioAudio`, `BatmanRadioMainsCarried`, `BatmanRadioMainsPlaced` | client, client, server | internes |

Modules `require` : `BatmanRadio/BatmanRadio_Core`, `…_Support`, `…_Compat`, `…_Mains`, `…_BeltNoise`, `…_BeltAudio`, `…_BeltBattery`, `…_MainsCarried`, `…_MainsPlaced`.

Fournisseur TooltipLib : `id = "batman_BeltRadio_Mains"`, `target = "item"`, activé si `Mains.isModified(item)`.

## Réseau

Aucune commande `sendClientCommand`/`sendServerCommand`. Synchronisations utilisées : `syncItemFields` (ModData de la recette), `addSound` (bruit relayé au serveur par le moteur), paquets vanilla de `DeviceData.update` (pile, extinction). Contrôles côté serveur : ceux du moteur (recette), `canTransmitWith` pour les mods qui l'appellent sur le serveur (micro non vérifié).

## Constantes

| Constante | Valeur | Rôle |
|---|---|---|
| `BatmanRadioSupport.MP_BUBBLE_DEDUP_MS` | 2000 | même texte non répété en bulle MP pendant ce délai |
| `BatmanRadioSupport.DEFAULT_LINE_COLOR` | `{1, 1, 1}` | couleur d'une ligne de chaîne inconnue (bulle MP) |
| `BatmanBeltRadioNoise.COOLDOWN_MS` | 2000 | délai minimal entre deux bruits d'une radio |
| `BatmanBeltRadioAudio.SIGNAL`, `SIGNAL_DECAY` | 300, 1,25 | compteur d'émission vanilla, baisse × `getMultiplier()` par image |
| `BatmanRadioMains.DEFAULT_USE_DELTA` | 0,014 | usure par heure de repli |

## Compatibilités vérifiées dans le code

- **TooltipLib** : `require "TooltipLib/Core"` ; sans `TooltipLib.registerProvider`, message `[BeltRadio] TooltipLib missing: no mains power line in tooltips` et pas de ligne d'infobulle.
- **Better Walkie Talkies** (`BetterWalkieTalkies`, `BetterWalkieTalkiesDev`) : `Compat.features()` → `beltBattery = not server and not bwt`, `mpBubble = client and not server and not bwt`, `scenarioReception = solo`, pont `BetterWalkieTalkies.RadioTextBridgeHandler` pour `microphoneAvailable` et `say`.
- **Anciennes copies embarquées** (Military Drop, Opération Artemis) au même chemin `BatmanRadio/…` : remplacent ce mod si chargées après lui ; voir [api-publique.md](api-publique.md#copie-de-secours-mods-qui-nexigent-pas-belt-walkie-talkie).
- **KeepRadioOnVanillaFriendly** : déclaré incompatible dans la copie de travail seulement (voir `mod.info`).

## Contraintes de version

Code écrit et vérifié statiquement contre les sources 42.21 (références `DeviceData.java`, `Radio.java`, `ZomboidRadio.java`, `ISRadioWindow.lua`, `ISEquipWeaponAction.lua`, `ISMoveableSpriteProps.lua` citées en commentaire). Signatures sensibles : `Radio:AddDeviceText` à 7 arguments (texte en premier), `playSoundImpl(nom, false, nil)` à 3 arguments, `addLineChatElement` à 13 arguments, `PlayerListensChannel(freq, true, false)`, `craftRecipeData:getAllKeepInputItems()`.
