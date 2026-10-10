# Décisions de conception

Recopie des décisions de l'utilisateur du 2026-10-10 (fichier de travail `beltradio-decisions.md`), appliquées par la version 0.1.0. L'analyse de référence (« Récepteur radio commun BatmanRadio : extraire en mod séparé ? », 2026-10-10) a retenu l'option A (mod séparé) avec copies de secours pour Military Drop et Opération Artemis.

Objectif : extraire le comportement du talkie-walkie (récepteur commun « BatmanRadio », aujourd'hui recopié dans
Military Drop, Opération Artemis et RadioSurvivor) dans un mod Workshop séparé, pour mutualiser code et comportement.
Analyse de référence : `analyse-mod-radio-commun.md` (fichier de travail, hors dépôt).

1. **Identité** : id `batman_BeltRadio`, nom affiché « Belt Walkie-Talkie », dossier `C:\Users\cyber\Zomboid\Workshop\BeltRadio`.
2. **Chemins et globales Lua** : on garde `media/lua/client/BatmanRadio/…`, `media/lua/shared/BatmanRadio/…` et la globale
   `BatmanRadioSupport` (une ancienne copie embarquée au même chemin est remplacée proprement).
3. **Radio rangée** (inventaire principal, ni en main, ni sur le dos, ni accrochée) : **ne reçoit aucune chaîne**, dans aucun
   mod. (Limite : en MP, le vanilla fait recevoir toutes les radios allumées de l'inventaire principal ; la règle ne
   s'applique qu'en solo.) RadioSurvivor perd sa réception « radio rangée » (`RS_PocketRadio.lua`).
4. **Émission avec un talkie à la ceinture : interdite partout** (Military Drop, Artemis, RadioSurvivor) : il faut le
   prendre en main (ou une radio sur le dos). Le mod commun fournit le prédicat partagé.
5. **Réglages** : options **sandbox serveur** du mod commun (proposées par l'analyse : bulle MP pour une radio non tenue,
   usure de la pile à la ceinture, écoute à la ceinture en solo) ; traductions dans les langues de Military Drop.
6. **Workshop** : public.
7. **Migration de Military Drop et Opération Artemis** : ils **utilisent le mod commun s'il est actif, sinon leur propre
   comportement embarqué** (pas de `require=`). Leur copie de secours doit donc vivre sous un **chemin propre à chaque mod**
   et ne s'activer que si `batman_BeltRadio` n'est pas activé (sinon même chemin = une copie masque l'autre).
8. **Dépôt** : nouveau dépôt `cyberbobjr/BeltRadio` (git dans `Workshop\BeltRadio`), tests déplacés depuis Military Drop,
   versions indépendantes.
9. **RadioSurvivor** (non publié) : **dépendance obligatoire** `require=batman_BeltRadio`, plus aucune copie embarquée.

## Application dans 0.1.0

- Décision 3 : le récepteur solo ne sert que la radio accrochée (`isAttachedOnly`) ; aucune réception « radio rangée » (`pocketChannels` proposé par l'analyse non retenu). En MP, le vanilla fait quand même recevoir la ligne à une radio rangée de l'inventaire principal (chat radio) : la règle ne s'applique qu'en solo, mais la bulle ajoutée par ce mod est réservée au talkie accroché à la ceinture (`isAttachedOnly`, 0.1.1), une radio rangée n'en a pas.
- Décision 4 : `BatmanRadioSupport.canTransmitWith(player, radio)` dans `media/lua/shared` (client et serveur), raison `"belt"` pour une radio accrochée. Chaque mod l'appelle et affiche son propre message.
- Décision 5 : options `BeltRadio.MPBubble`, `BeltRadio.BeltBattery`, `BeltRadio.BeltListening`, vraies par défaut, fausses = vanilla, lues à chaque usage ; traductions dans les 8 langues de Military Drop (CN, DE, EN, ES, FR, PT, PTBR, RU).
- Décision 2 : chemins `media/lua/client/BatmanRadio/…`, `media/lua/shared/BatmanRadio/…` et globale `BatmanRadioSupport` conservés ; nouveau fichier `shared/BatmanRadio/BatmanRadio_Support.lua` (VERSION, options, prédicat d'émission).

## Fonction « secteur » (décisions du 2026-10-10, appliquées par la version 1.1.0)

Bricoler un talkie-walkie, une radio HAM ou une radio dorsale pour qu'il fonctionne sur le courant d'une zone électrifiée.

1. **Recette** : garde l'appareil (`mode:keep`, canal, pile et ID conservés), consomme 2 `Base.ElectronicsScrap` et 1 `Base.ElectricWire`, garde un tournevis (`tags[base:screwdriver]`), exige `Electricity:1`, rapporte `xpAward = Electricity:10`, connue d'emblée (pas de `NeedToBeLearn`). `OnTest` refuse un appareil déjà modifié ; `OnCreate` (solo ou serveur) écrit `ModData.BatmanMains = { useDelta = <valeur d'origine> }` puis `syncItemFields`.
2. **Appareils** : `WalkieTalkie1` à `5`, `WalkieTalkieMakeShift`, `HamRadio1`, `HamRadio2`, `HamRadioMakeShift`, `ManPackRadio`.
3. **Zone électrifiée** : même règle que `DeviceData.canBePoweredHere` (`DeviceData.java:518-529`) : générateur (`haveElectricity`), ou réseau (`hasGridPower`) dans une pièce. Case du joueur pour une radio portée, case de l'`IsoRadio` pour un appareil posé.
4. **Pile** : il faut une pile dans l'appareil. Sur le secteur, elle ne s'use plus (`setUseDelta(0)`, valeur d'origine remise hors zone) et **se recharge**, appareil allumé ou éteint, jusqu'à 1.
5. **Durée de recharge** : option sandbox `BeltRadio.MainsRechargeHours` (heures de jeu de 0 à plein, 10 par défaut), lue à chaque usage.
6. **Marquage** : ligne d'infobulle par TooltipLib (« Branché sur secteur », « en charge » le cas échéant).
7. **TooltipLib devient un prérequis** : `require=\TooltipLib` dans `mod.info`, objet requis Steam (3694097672) et descriptions mises à jour.

8. **Appareil posé comme tuile** (1.1.1, signalé par un joueur sur serveur dédié) : les radios HAM n'ont qu'une tuile (`WorldObjectSprite`) et se posent par `ISMoveableSpriteProps`, qui crée un `IsoRadio` avec sprite sans `RadioItemID`, recopie la ModData de l'objet à la pose (`:2423-2429`) et ne rend que `movableData` au ramassage (`:1403-1404`). Le suivi des appareils posés lit donc aussi l'état dans la ModData de l'`IsoRadio`, et l'y note sous `movableData.BatmanMains` (`Mains.keepOnPickup`) pour que l'objet ramassé reste modifié ; `Mains.state` cherche la clé à la racine puis dans `movableData`. Une radio déjà ramassée en 1.1.0 a perdu sa marque : la bricoler de nouveau.

Autorité : client ou solo pour une radio portée (main, dos, ceinture) ; serveur ou solo pour un appareil posé. Limite MP à vérifier : la charge d'une radio portée n'est transmise au serveur que par les paquets de pile vanilla envoyés quand elle est allumée.

## Bruit d'un talkie à la ceinture qui reçoit (décision du 2026-10-10, appliquée par la version 1.1.0)

Constat (confirmé statiquement, 42.21) : la réception passe bien par `DeviceData.doReceiveSignal` (solo : `BeltRadio.deliver` → `Radio.AddDeviceText` ; MP : `ZomboidRadio.DistributeToPlayerOnClient` → `WaveSignalDevice.AddDeviceText`), qui émet `WorldSoundManager.addSound` seulement si `soundCounter <= 0`, puis le met à 120. Ce compteur ne baisse que dans `DeviceData.updateSimple`, appelé à chaque image pour la radio équipée, jamais par le vanilla pour une radio accrochée (notre gestionnaire de pile l'appelle une fois par minute de jeu). Résultat : un bruit à la première ligne de la session, puis presque plus rien.

Décision (option A) : le mod émet son propre bruit à chaque réception d'un talkie allumé accroché à la ceinture, avec la formule vanilla (volume `100 × getDeviceVolume()`, portée `getDeviceSoundVolumeRange()`, aucun bruit avec écouteurs, volume nul exclu), limité à un bruit environ toutes les 2 s par radio, via `addSound` (transmis au serveur en MP). Détection : solo dans `deliver` ; MP par `OnDeviceText` (lignes de chaîne) et, à vérifier, `OnAddMessage` de l'onglet radio (messages radio des autres joueurs). Option sandbox `BeltRadio.BeltNoise`, vraie par défaut, fausse = vanilla.
