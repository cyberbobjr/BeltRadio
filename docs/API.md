# API Lua de Belt Walkie-Talkie (`BatmanRadioSupport`)

Mod `batman_BeltRadio`, Build 42.21. Niveau d'API documenté ici : **`VERSION = 1`** (1.0.0).

La table globale `BatmanRadioSupport` est complétée par deux fichiers :

| Fichier | Chargé | Contenu |
|---|---|---|
| `media/lua/shared/BatmanRadio/BatmanRadio_Support.lua` | solo, client MP, serveur dédié | `VERSION`, `MOD_ID`, options (`option`, `enabled`), `canTransmitWith` |
| `media/lua/client/BatmanRadio/BatmanRadio_Core.lua` | solo, client MP (un dédié ne l'exécute pas) | récepteur : `register`, menu, fenêtre, écoute solo, bulle MP, aides |
| `media/lua/client/BatmanRadio/BatmanRadio_BeltBattery.lua` | solo, client MP | pile à la ceinture (globale `BatmanBeltRadioBattery`) |
| `media/lua/shared/BatmanRadio/BatmanRadio_Compat.lua` | partout | compatibilité Better Walkie Talkies (module renvoyé par `require`) |

Chemins et globale identiques aux copies embarquées jusqu'ici dans Military Drop et Opération Artemis : une ancienne copie de même chemin chargée **après** ce mod le remplace (le dernier mod chargé gagne, quel que soit sa version). Un mod qui embarque une copie de secours doit donc la ranger sous **son propre chemin** (voir « Copie de secours »).

## Version

```lua
BatmanRadioSupport.VERSION   -- entier, augmenté à chaque ajout ou changement de l'API
BatmanRadioSupport.MOD_ID    -- "batman_BeltRadio"
```

Contrôle conseillé dans un mod qui en dépend, sans `pcall` global, message en anglais :

```lua
local REQUIRED = 1
if (BatmanRadioSupport and BatmanRadioSupport.VERSION or 0) < REQUIRED then
    print("[MonMod] WARN: Belt Walkie-Talkie API " .. REQUIRED .. " required, found "
        .. tostring(BatmanRadioSupport and BatmanRadioSupport.VERSION))
end
```

⚠ `VERSION` est défini par le fichier `shared`. Si une ancienne copie de `BatmanRadio_Core.lua` (même chemin, sans options) est chargée après ce mod, `VERSION` existe quand même : il atteste la partie partagée, pas le récepteur. Ce cas ne se produit qu'avec une ancienne version publiée de Military Drop ou d'Opération Artemis.

## Fournisseur : `register(id, provider)` (client)

```lua
local Support = require "BatmanRadio/BatmanRadio_Core"
Support.register("MonMod", provider)
```

Un fournisseur est remplacé par son identifiant (rechargement Lua sans doublon). Tous les champs sont facultatifs.

| Champ | Signature | Rôle |
|---|---|---|
| `channels` | `function() -> { RadioChannel }` | Chaînes du mod que la ceinture doit suivre en solo, en plus du registre vanilla (`getZomboidRadio():getScriptManager():getChannelsList()`, qui contient déjà les chaînes ajoutées par `AddChannel`). Utile pour une chaîne créée hors du registre ou pour la retrouver vite. Sur un client MP, peut renvoyer `{}`. |
| `frequencies` | `function() -> { { frequency, r, g, b } }` | Fréquences **publiques** connues de ce client (option sandbox fixée), avec la couleur de leurs lignes (0-1), pour la bulle MP. Ne jamais y mettre une fréquence secrète tirée par le serveur. |
| `recognize` | `function(codes) -> { r, g, b } \| nil` | Fréquence secrète : reconnaît une ligne du mod à ses codes (`RadioLine` effects, 4 caractères conseillés, posés sur **chaque** ligne). Le client retient alors la fréquence de la radio qui l'a reçue jusqu'à la déconnexion (lignes suivantes brouillées par l'orage comprises). |
| `isStowed` | `function(player, item) -> boolean` | Radio rangée (inventaire, sac) pour laquelle le mod veut proposer « Options de l'appareil ». |
| `open` | `function(player, item)` | Action de ce menu pour une radio rangée (par exemple prise en main puis `ISRadioAndTvMenu.openRadioPanel`). |
| `takingActions` | `{ [Type d'action] = "champ" }` | Actions chronométrées du mod qui prennent la radio en main : la fenêtre radio reste ouverte et la radio allumée pendant qu'elles sont en file (`action[champ]` = la radio). `ISEquipWeaponAction = "item"` est déjà inscrit. |

Couleur MP : celle de `frequencies`, sinon celle de `recognize`, sinon blanc (`DEFAULT_LINE_COLOR`) ; `OnDeviceText` ne transmet pas la couleur de la ligne.

Ne pas remplacer `deliver`, `onTick` ni les autres fonctions du récepteur : elles ne font pas partie de l'API.

## Émission : `canTransmitWith(player, radio)` (client et serveur)

```lua
local ok, reason = BatmanRadioSupport.canTransmitWith(player, radio)
```

Vrai si la radio est une radio portative émettrice (`getIsTwoWay`, pas `NoTransmit`), **en main** (principale ou secondaire) **ou sur le dos**, allumée, alimentée, micro ouvert. **Jamais accrochée à la ceinture ni rangée** (décision 4, commune à tous les mods). Raisons du refus : `"notRadio"`, `"notTransmitter"`, `"belt"`, `"stowed"`, `"off"`, `"battery"`, `"micMuted"`. Un mod affiche sa propre phrase traduite (par exemple « prenez le talkie en main » pour `"belt"`).

Limites (base `pz-knowledge`, `multiplayer.md`) :
- sur un serveur, le micro n'est **pas** vérifié (`setMicIsMuted` n'est jamais transmis) ;
- sur un serveur, l'état allumé et la fréquence d'une radio d'inventaire ne sont à jour que pour une radio **en main** : une autorité serveur stricte exige la main (cas de Military Drop) ;
- côté client, le micro passe par `BatmanRadio_Compat.microphoneAvailable` (le silence de repos de Better Walkie Talkies n'est pas un micro coupé).

## Options sandbox

```lua
BatmanRadioSupport.option("MPBubble")    -- valeur (true par défaut)
BatmanRadioSupport.enabled("BeltBattery") -- false seulement si l'option vaut false
```

| Option | Défaut | Fausse (comportement vanilla) |
|---|---|---|
| `BeltRadio.MPBubble` | vrai | MP : la ligne reçue par un talkie à la ceinture n'apparaît que dans le chat radio |
| `BeltRadio.BeltBattery` | vrai | pile figée à la ceinture, consommation rattrapée par `Radio.update` à la reprise en main |
| `BeltRadio.BeltListening` | vrai | solo : un talkie à la ceinture n'entend rien |

Lecture par `getSandboxOptions():getOptionByName("BeltRadio.X"):getValue()` à chaque usage (à jour après un changement en cours de partie), repli `SandboxVars.BeltRadio.X`, puis défaut. Le menu « Options de l'appareil » et la fenêtre gardée ouverte ne dépendent d'aucune option.

## Aides stables (client)

| Fonction | Rôle |
|---|---|
| `isPortableRadio(item)` | radio d'inventaire portative |
| `isAttachedOnly(player, item)` | radio portative accrochée, ni en main ni sur le dos |
| `receives(radio, frequency)` | la radio recevrait la fréquence en main (allumée, volume, pile, pas de média) |
| `listeningRadio(player, frequency)` | radio accrochée qui doit afficher la ligne, ou `nil` |
| `weathered(line)` | texte, couleur et codes d'une ligne après le brouillage de l'orage |

Module `require "BatmanRadio/BatmanRadio_Compat"` : `hasBWT()`, `features()`, `microphoneAvailable(data)`, `say(player, text)`.

## Exemple d'adaptateur

```lua
-- media/lua/client/MonMod/MonMod_BeltRadio.lua
require "MonMod/MonMod_Core"
local Support = require "BatmanRadio/BatmanRadio_Core"
if not Support or not Support.register then return end

local COLOR = { r = 0.70, g = 0.85, b = 0.55 }

Support.register("MonMod", {
    channels = function()
        return MonMod.channel and { MonMod.channel } or {}
    end,
    -- Fréquence fixée par une option sandbox : publique, connue du client MP.
    frequencies = function()
        local frequency = SandboxVars.MonMod and SandboxVars.MonMod.Frequency
        if not frequency or frequency <= 0 then return {} end
        return { { frequency = math.floor(frequency * 1000 + 0.5), r = COLOR.r, g = COLOR.g, b = COLOR.b } }
    end,
    -- Fréquence secrète : chaque ligne de la chaîne porte le code "MMTX".
    recognize = function(codes)
        if string.sub(codes, 1, 4) == "MMTX" then return COLOR end
    end,
})

-- Émission (client ou serveur) : jamais depuis la ceinture.
function MonMod.canCall(player, radio)
    local ok, reason = BatmanRadioSupport.canTransmitWith(player, radio)
    if not ok and reason == "belt" then
        return false, getText("IGUI_MonMod_TakeInHand")
    end
    return ok
end
```

## Copie de secours (mods qui n'exigent pas Belt Walkie-Talkie)

Décision 7 : Military Drop et Opération Artemis utilisent ce mod s'il est actif, sinon leur comportement embarqué, sans `require=`. Leur copie doit vivre sous un **chemin propre** (par exemple `media/lua/client/MilitaryDrop/BeltRadioFallback/...`) et ne rien installer si `batman_BeltRadio` est actif :

```lua
local function beltRadioActive()
    local mods = getActivatedMods()
    for i = 0, mods:size() - 1 do
        if string.gsub(mods:get(i), "^\\", "") == "batman_BeltRadio" then return true end
    end
    return false
end
if beltRadioActive() then return end -- le mod commun s'en charge
```

Pièges :
- la copie ne doit rien faire (ni globale, ni événement) quand le mod commun est actif, ni utiliser les chemins `BatmanRadio/...` (elle masquerait le mod commun). Ses `require` internes pointent vers ses propres chemins ;
- mod commun absent : la copie **garde** les globales `BatmanRadioSupport` et `BatmanBeltRadioBattery`. Deux copies de secours (Military Drop et Opération Artemis actifs ensemble) se remplacent alors l'une l'autre au lieu de s'additionner : au chargement, le Core retire les gestionnaires inscrits par la copie précédente (`onTick`, `onGameStart`, `onFillInventoryContextMenu`, `onDeviceTextMP`, `reset`, rangés dans la table) et n'enveloppe `ISRadioWindow.update` qu'une fois ; les fournisseurs inscrits sont conservés. La dernière copie chargée l'emporte, comme aujourd'hui avec un chemin commun ;
- `getActivatedMods()` est fixe pendant une partie : le résultat peut être mis en cache ;
- un mod qui exige ce mod (`require=batman_BeltRadio`) ne doit embarquer aucune copie.

Génération : `python tools/sync_fallback.py [MilitaryDrop] [OperationArtemis]` écrit les copies de secours depuis les fichiers de ce mod (`<mod>/BeltRadioFallback/BatmanRadio_*.lua` sous `client/` et `shared/`), avec la garde ci-dessus en tête et les `require "BatmanRadio/…"` réécrits ; le reste est identique (fins de ligne mises à part). `--check` compare sans écrire ; les tests de Military Drop et d'Opération Artemis importent ce module pour vérifier leur copie (ignoré sans ce dépôt). Après toute modification des fichiers Lua de ce mod : relancer l'outil, puis les tests et un commit dans chaque mod. Côté mod, un petit module (`MilitaryDrop_RadioLib.lua`, `Artemis_RadioLib.lua`) choisit `BatmanRadio/…` ou la copie (`require` du bon chemin), vérifie `VERSION` (un `WARN` unique en anglais) et expose `canTransmitWith`.
