# Belt Walkie-Talkie : améliorations et idées

- Mod : **Belt Walkie-Talkie**, `id=batman_BeltRadio`, Workshop 3817018338
- Version analysée : **1.2.0** (`CHANGELOG.md`, `modversion=1.2.0`), Build 42.21
- Date : 2026-10-21
- Périmètre lu : `Contents/mods/batman_BeltRadio/**` (10 fichiers Lua, `sandbox-options.txt`, recette, 8 langues de traduction, `mod.info`), `README.md`, `CHANGELOG.md`, `README.steam*`, `workshop.txt`, `docs/` (décisions, API, spécifications), `tests/` (harnais lupa, 9 fichiers de tests), `.github/workflows/checks.yml`, `.luacheckrc`, `tools/`.
- Sources de contrôle : base `.claude/pz-knowledge` (`radio-dynamic.md`, `multiplayer.md`, `power-and-lights.md`, `kahlua-lua.md`, `sounds-and-noise.md`, `mod-loading.md`, `api-42-21.md`), Lua vanilla installé, Java décompilé `E:\pz-decompiled\42.21.0\java`.

Statuts employés : **confirmé statiquement** (lecture du code du mod et du code vanilla ou décompilé), **à vérifier en jeu** (déduit, non reproduit), **hypothèse**. Rien dans ce document n'a été testé en jeu.

Décisions déjà actées et non reproposées ici : pas d'émission depuis la ceinture (décision 4), aucune réception pour une radio rangée en solo (décision 3, `pocketChannels` non retenu), son de la ceinture local au porteur comme le vanilla (décision du 2026-10-14), pas de copie de secours générée par ce dépôt (outil retiré le 2026-10-10).

---

## Partie 1 — Améliorations de code

### C01 — Fournisseur sans `channels` : erreur Lua à chaque tick en solo
- **Problème** : `BeltRadio.channels()` appelle `provider.channels()` sans tester son existence, alors que `docs/specifications-techniques/api-publique.md` (« Tous les champs sont facultatifs ») et `scenarioFrequencies()` (qui garde bien `provider.channels and …`) le tiennent pour facultatif. Même défaut, moins grave, sur `provider.open` : un fournisseur qui déclare `isStowed` sans `open` ajoute une option de menu sans action.
- **Preuve** : `client/BatmanRadio/BatmanRadio_Core.lua:303-306` (appel non gardé), à comparer à `:441` (appel gardé) ; `:85-88` (`onSelect = provider.open` sans contrôle).
- **Risque** : bug. Un mod tiers qui n'inscrit que `recognize` ou `frequencies` (cas typique d'une chaîne à fréquence secrète en MP) fait échouer `BeltRadio.onTick` à chaque image en solo : plus aucune ligne livrée à la ceinture, journal saturé. Les trois mods actuels fournissent `channels`, d'où l'absence de symptôme.
- **Correction** : `for _, channel in ipairs(provider.channels and provider.channels() or {})`, et `if provider.isStowed and provider.open and provider.isStowed(player, item)`. Ajouter un test lupa « fournisseur réduit à `recognize` ».
- Statut : confirmé statiquement. Priorité **haute**, effort **S**.

### C02 — Radio posée sur secteur : charge jamais envoyée aux clients
- **Problème** : `Mains.apply` recharge par `DeviceData.setPower`, qui ne transmet rien (`DeviceData.java:587-596`). Le vanilla n'envoie la pile d'une radio posée qu'à `update` quand elle est **allumée** (paquet de type 3 tous les 10 min ou à chaque pas de 1 %, `DeviceData.java:777-786`). Une radio HAM bricolée et éteinte sur un générateur se recharge sur le serveur, mais la fenêtre radio du client affiche l'ancienne charge.
- **Preuve** : `server/BatmanRadio/BatmanRadio_MainsPlaced.lua:73-77` puis `shared/BatmanRadio/BatmanRadio_Mains.lua:134` ; méthode publique `DeviceData.transmitBatteryChangeServer()` (`DeviceData.java:312-314`), reçue par les clients (`receiveDeviceDataStatePacket`, cas 2, `:1117-1129`).
- **Risque** : MP, affichage trompeur (le joueur croit la recharge en panne).
- **Correction** : sur le serveur seulement, quand `Mains.apply` rend vrai et que la charge a franchi un pas de 1 % (ou passe à 1), appeler `data:transmitBatteryChangeServer()`. Aucun effet en solo.
- Statut : confirmé statiquement, rendu client à vérifier en jeu. Priorité **haute**, effort **S**.

### C03 — Radio portée à la ceinture : la limite MP documentée est inexacte
- **Problème** : la limite connue dit que « la charge d'une radio portée n'arrive au serveur que par les paquets de pile vanilla envoyés quand elle est allumée ». En réalité, le serveur n'applique un paquet d'état d'une radio d'inventaire que si elle est **en main** (octet de main 1 ou 2) ; pour une radio à la ceinture (main 0 + identifiant), il ne fait rien. La charge gagnée (secteur) ou perdue (`BeltBattery`) à la ceinture n'existe que sur le client jusqu'à la prochaine prise en main.
- **Preuve** : `GameServer.java:3499-3516` (seuls `hand == 1` et `hand == 2` sont traités) ; `DeviceData.java:1000-1014` (le client envoie bien `putByte(0)` + `getID()`) ; limite citée dans `CHANGELOG.md` (1.1.0, « Known limits »), `docs/` (décisions, spécifications fonctionnelles).
- **Risque** : MP, persistance. Une radio posée au sol ou passée à un autre joueur sans avoir été reprise en main repart avec la charge connue du serveur.
- **Correction** : corriger la phrase dans la documentation et les notes de version. Option de code (à valider) : commande cliente `sendClientCommand("BeltRadio", "power", { id, power })` une fois par pas de 1 %, appliquée par le serveur à l'objet de même ID dans l'inventaire du joueur, bornée à la charge plausible (charge serveur ± usure maximale écoulée). Sur un serveur entre amis, la confiance au client est acceptable.
- Statut : confirmé statiquement. Priorité **moyenne**, effort **S** (doc) / **M** (code).

### C04 — `Compat.features()` parcourt la liste des mods actifs à chaque image
- **Problème** : `Compat.hasBWT()` relit `getActivatedMods()` et applique un `gsub` à chaque identifiant à chaque appel. `features()` est appelé par `Battery.onTick` et `BeltRadio.onTick` à **chaque image**, et à chaque `OnDeviceText`. Avec une centaine de mods, cela fait plusieurs centaines d'appels de chaîne par image pour un résultat fixe pendant toute la partie (`docs/specifications-techniques/api-publique.md`, « `getActivatedMods()` est fixe pendant une partie »).
- **Preuve** : `shared/BatmanRadio/BatmanRadio_Compat.lua:5-15, 17-35` ; appels `client/BatmanRadio/BatmanRadio_BeltBattery.lua:43`, `BatmanRadio_Core.lua:388, 487`.
- **Risque** : performance (Kahlua environ 3,6 fois plus lent que Lua 5.1 sur les chaînes, `kahlua-lua.md`).
- **Correction** : mémoriser `hasBWT` dans une variable locale, remise à `nil` à `OnMainMenuEnter`/`OnDisconnect` (et au rechargement du fichier). Garder le calcul de `radioTextBridge` à l'appel (la fonction BWT peut apparaître plus tard, commentaire `:32`).
- Statut : confirmé statiquement. Priorité **moyenne**, effort **S**.

### C05 — Enveloppe de `ISRadioWindow.update` reposée par-dessus un autre mod
- **Problème** : `installWindowWrapper` réenveloppe dès que `ISRadioWindow.update` n'est plus notre fonction, et il est rappelé à chaque menu contextuel d'inventaire. Si un autre mod enveloppe `update` après nous, on enveloppe son enveloppe, qui appelle déjà la nôtre : `keepsWindow` est évalué deux fois. Avec un mod qui suit la même stratégie (« réenvelopper si ce n'est plus la mienne »), la chaîne s'allonge à chaque clic droit. Un tel mod est installé : `KeepRadioOn_Unofficial` (Workshop 3688705444) enveloppe `ISRadioWindow.update`.
- **Preuve** : `client/BatmanRadio/BatmanRadio_Core.lua:73, 170-187` ; `…/3688705444/mods/KeepRadioOn_Unofficial/42/media/lua/client/RadioCom/KeepThatRadioOn.lua:14-20` (lecture seule).
- **Risque** : compatibilité, récursion de hooks (`kahlua-lua.md`).
- **Correction** : ne réenvelopper que si la **classe** a changé (rechargement de `ISRadioWindow.lua` crée une nouvelle table) : retenir `BeltRadio.wrappedClass = ISRadioWindow` et comparer l'identité de la table plutôt que celle de la fonction.
- Statut : confirmé statiquement, comportement combiné à vérifier en jeu. Priorité **moyenne**, effort **S**.

### C06 — `incompatible=` non commité, identifiant introuvable
- **Problème** : la copie de travail ajoute `incompatible=\KeepRadioOnVanillaFriendly`. Aucun mod abonné ne porte cet identifiant ; le mod voisin installé s'appelle `KeepRadioOn_Unofficial`. Un identifiant erroné rend la déclaration inopérante. `tests/run_all.py` (`check_mod_info`) ne contrôle pas cette ligne, et le `CHANGELOG` ne la mentionne pas.
- **Preuve** : `Contents/mods/batman_BeltRadio/42.21/mod.info:8` (diff non commité) ; `…/3688705444/mods/KeepRadioOn_Unofficial/42/mod.info:2`.
- **Risque** : compatibilité ; `incompatible=` n'est appliqué que par le sélecteur de mods (`mod-loading.md`).
- **Correction** : relever l'`id` exact du mod visé sur sa page Workshop (et lister aussi `KeepRadioOn_Unofficial` si le conflit est confirmé, C05) ; ajouter une note de version joueur ; autoriser la ligne dans `check_mod_info`.
- Statut : confirmé statiquement (dossier Workshop local seulement). Priorité **moyenne**, effort **S**.

### C07 — Radio bricolée = chargeur de piles infini
- **Problème** : la pile d'une radio sur secteur remonte jusqu'à 1. En la retirant, le joueur obtient une `Base.Battery` à pleine charge (`getBattery` recopie `powerDelta`). Avec un générateur, toute lampe, tout talkie et toute radio non bricolée deviennent alimentés sans limite.
- **Preuve** : `shared/BatmanRadio/BatmanRadio_Mains.lua:113-136` ; `DeviceData.java:294-306` (`bat.setCurrentUses(maxUses × powerDelta)`).
- **Risque** : équilibrage (gameplay), non signalé dans les décisions.
- **Correction** : décision à prendre (assumer et le documenter côté joueur, ou option sandbox « Recharge limitée aux piles dans l'appareil » qui plafonne la charge à celle d'origine quand la pile est retirée puis remise). Voir aussi I14.
- Statut : confirmé statiquement. Priorité **moyenne**, effort **S** (doc) / **M** (option).

### C08 — Appareils posés suivis après le déchargement de leur chunk
- **Problème** : `Placed.everyMinute` ne retire une entrée que si `getSquare()` est `nil` ou `getObjectIndex() == -1`. Au déchargement d'un chunk, l'`IsoWaveSignal` quitte le monde (`UnRegisterDevice`, `power-and-lights.md`) mais rien ne garantit que sa case perde la référence. Le serveur continuerait alors de mettre à jour un objet fantôme, et, au retour du chunk, un nouvel objet est ajouté par `LoadGridsquare` : deux entrées pour le même appareil, mémoire qui croît avec les déplacements des joueurs.
- **Preuve** : `server/BatmanRadio/BatmanRadio_MainsPlaced.lua:92-106`.
- **Risque** : mémoire et charge serveur sur un dédié longue durée.
- **Correction** : vérifier en plus `getCell():getGridSquare(x, y, z) == object:getSquare()` (case encore chargée et identique). Ajouter le cas au test `placed_device_added_in_play_is_tracked_then_released_when_picked_up`.
- Statut : **hypothèse** (comportement de la case après déchargement à confirmer en jeu). Priorité **moyenne**, effort **S**.

### C09 — `canTransmitWith` côté serveur accepte une radio dorsale périmée
- **Problème** : sur un serveur, l'état allumé, la fréquence et la pile d'une radio d'inventaire ne sont tenus à jour que pour une radio **en main** (C03 ; `multiplayer.md`, « dos et ceinture périmés »). `canTransmitWith` accepte pourtant la radio dorsale au même titre que la main, puis lit `getIsTurnedOn` et `getPower` périmés.
- **Preuve** : `shared/BatmanRadio/BatmanRadio_Support.lua:85-102` ; `GameServer.java:3499-3516`.
- **Risque** : autorité serveur (un mod dépendant qui fait confiance au prédicat sur le serveur peut accepter une radio dorsale éteinte ou refuser une radio rallumée).
- **Correction** : paramètre facultatif `canTransmitWith(player, radio, { strictServer = true })` qui, sur `isServer()`, exige la main ; ou nouvelle raison `"backOnServer"`. Documenter dans l'API et augmenter `VERSION`.
- Statut : confirmé statiquement. Priorité **moyenne**, effort **S**.

### C10 — Écoute déclarée et registre des chaînes reconstruits à chaque image
- **Problème** : en solo, `onTick` appelle `notifyListening` (un `PlayerListensChannel` par fréquence de talkie) puis reconstruit la liste des chaînes et suit chacune, à chaque image. Le vanilla ne déclare l'écoute que toutes les 5 minutes de jeu (`listenCnt == 0 or 5`, `DeviceData.java:774-776`).
- **Preuve** : `client/BatmanRadio/BatmanRadio_Core.lua:313-338, 387-405`.
- **Risque** : performance faible mais permanente.
- **Correction** : `notifyListening` une fois par minute de jeu (`getMinutesStamp`) ou au changement de fréquence ; mettre en cache la liste des chaînes et la recalculer quand `getChannelsList():size()` change. Garder le suivi des lignes à chaque image.
- Statut : confirmé statiquement. Priorité **basse**, effort **S**.

### C11 — Pile sur secteur portée : tout le calcul tourne à chaque image
- **Problème** : `Carried.onTick` recalcule à chaque image `isPoweredSquare` et la liste des appareils de chaque joueur, alors que le travail n'a lieu qu'au changement de minute.
- **Preuve** : `client/BatmanRadio/BatmanRadio_MainsCarried.lua:45-73`.
- **Risque** : performance, allocations de tables (ramasse-miettes).
- **Correction** : sortir aussitôt si `getMinutesStamp()` n'a pas changé depuis le dernier passage (ou passer à `EveryOneMinute`, déclenché aussi en solo et sur un client).
- Statut : confirmé statiquement. Priorité **basse**, effort **S**.

### C12 — Son à la ceinture : nouvel essai à chaque image si `playSoundImpl` rend 0
- **Problème** : si la boucle ne démarre pas (`play` rend 0 : client `-nosound`, événement FMOD absent, `DummySoundEmitter`), la condition `state.loop == 0` relance `playSoundImpl` à chaque image.
- **Preuve** : `client/BatmanRadio/BatmanRadio_BeltAudio.lua:53-57, 129-135` ; `sounds-and-noise.md` (« `-nosound` : `playSoundImpl` d'un émetteur libre rend toujours 0 »).
- **Risque** : performance (tests automatisés `pz-autotest` en `-nosound`), aucun effet audible.
- **Correction** : noter l'échec (`state.failedUntil = getTimestampMs() + 5000`) et ne réessayer qu'après ce délai.
- Statut : confirmé statiquement. Priorité **basse**, effort **S**.

### C13 — Grésillement à la ceinture même quand l'écoute solo est désactivée
- **Problème** : en solo, avec `BeltListening = false`, aucune ligne n'est livrée mais `BeltAudio` joue quand même le grésillement continu : le joueur entend une radio qui ne recevra jamais rien.
- **Preuve** : `client/BatmanRadio/BatmanRadio_BeltAudio.lua:142-158` (seule `BeltAudio` est testée) ; `BatmanRadio_Core.lua:392-395`.
- **Risque** : cohérence de l'expérience.
- **Correction** : en solo (`Compat.features().scenarioReception`), exiger aussi `enabled("BeltListening")` pour démarrer le son.
- Statut : confirmé statiquement. Priorité **basse**, effort **S**.

### C14 — Cadence du bruit en temps réel, et non en temps de jeu
- **Problème** : le délai entre deux bruits est de 2 000 ms réelles. Le vanilla décompte `soundCounter` (120) de 1,25 × `getMultiplier()` par image : en accéléré, le vanilla fait plus de bruits par heure de jeu, la ceinture moins.
- **Preuve** : `client/BatmanRadio/BatmanRadio_BeltNoise.lua:21, 44-49` ; `radio-dynamic.md` (`updateSimple`).
- **Risque** : équilibrage marginal (avance rapide en solo).
- **Correction** : compteur par radio décrémenté dans un `OnTick` existant avec `getGameTime():getMultiplier()`, comme `BeltAudio.SIGNAL_DECAY`.
- Statut : confirmé statiquement. Priorité **basse**, effort **S**.

### C15 — Libellé de l'option de bulle MP en décalage avec son effet
- **Problème** : l'option s'appelle « Bubble for an unheld radio (multiplayer) » / « Bulle pour une radio non tenue », alors que depuis 0.1.1 la bulle est réservée au talkie **accroché à la ceinture** (une radio rangée n'en a pas). La description Steam dit déjà « Bubble for a walkie-talkie on the belt ».
- **Preuve** : `shared/Translate/EN/Sandbox.json` et `FR/Sandbox.json` (`Sandbox_BeltRadio_MPBubble`) ; `README.steam` (liste des options) ; `docs/` (décision 3, application 0.1.1).
- **Risque** : traduction, compréhension par l'administrateur.
- **Correction** : renommer dans les 8 langues (« Bubble for a walkie-talkie on the belt (multiplayer) »).
- Statut : confirmé statiquement. Priorité **basse**, effort **S**.

### C16 — Documentation du dépôt périmée
- **Problème** : la partie française de `README.md` a une virgule manquante (« en multijoueur use sa pile ») ; `.luacheckrc` liste deux globales alors que le mod en définit sept (`BatmanBeltRadioAudio`, `BatmanBeltRadioNoise`, `BatmanRadioMains`, `BatmanRadioMainsCarried`, `BatmanRadioMainsPlaced` en plus) ; l'ancien `docs/API.md` omettait `BeltNoise`/`BeltAudio` dans son tableau d'options.
- **Preuve** : `README.md:68` ; `.luacheckrc:3` ; `BatmanRadio_Support.lua:26-29` (défauts des six options).
- **Risque** : maintenabilité, confusion pour les moddeurs.
- **Correction** : mettre à jour ces lignes (la mention « not published yet » du README a déjà été corrigée par la réorganisation en cours, qui couvre aussi l'API) ; ajouter à `run_all.py` un contrôle « toute option de `sandbox-options.txt` figure dans la page API ».
- Statut : confirmé statiquement. Priorité **basse**, effort **S**.

### C17 — Deux listes d'appareils éligibles à tenir à la main
- **Problème** : les types bricolables sont écrits deux fois, dans `Mains.ITEM_TYPES` et dans l'entrée de la recette. Un ajout d'un seul côté donne une recette proposée mais sans effet (ou l'inverse). Aucun test ne compare les deux.
- **Preuve** : `shared/BatmanRadio/BatmanRadio_Mains.lua:23-28` ; `media/scripts/BatmanRadio_recipes.txt:16`.
- **Risque** : maintenabilité.
- **Correction** : test Python qui extrait la liste `item 1 [ … ] mode:keep` du script et la compare aux clés de `ITEM_TYPES`.
- Statut : confirmé statiquement. Priorité **basse**, effort **S**.

### C18 — Pas de rattrapage de recharge pour un appareil posé hors zone chargée
- **Problème** : un appareil suivi pour la première fois (chargement de son chunk) reçoit `minutes = 0` : une radio HAM bricolée laissée sur le générateur d'une base se recharge seulement quand un joueur est à proximité. Comportement voulu (« Aucun rattrapage après un chargement ») mais invisible pour le joueur, qui suppose une recharge continue.
- **Preuve** : `server/BatmanRadio/BatmanRadio_MainsPlaced.lua:61-77` ; `client/BatmanRadio/BatmanRadio_MainsCarried.lua:43-44`.
- **Risque** : attente du joueur, pas un bug.
- **Correction** : soit le dire dans l'infobulle et la description, soit I13 (rattrapage par horodatage).
- Statut : confirmé statiquement. Priorité **basse**, effort **S** (doc).

### C19 — Validation en jeu des trois limites ouvertes
- **Problème** : trois mécanismes livrés reposent sur des hypothèses jamais vérifiées en jeu : `OnAddMessage` du chat radio pour le bruit et le son en MP (`radio-dynamic.md`, « hypothèse ») ; paramètre FMOD `DeviceVolume` sur un émetteur libre ; effet sur la VOIP vanilla d'un talkie accroché.
- **Preuve** : `client/BatmanRadio/BatmanRadio_BeltNoise.lua:59-86` ; `BatmanRadio_BeltAudio.lua:42-49` ; « Limites connues » de `docs/`.
- **Risque** : MP, régression silencieuse.
- **Correction** : scénario `pz-autotest` MP à deux clients (un talkie à la ceinture sur la fréquence d'un autre joueur qui parle ; vérifier `addSound` côté serveur, lecture de `getLuaDebuggerErrorCount`, bulle) ; contrôle d'oreille court en solo pour le volume.
- Statut : à vérifier en jeu. Priorité **moyenne**, effort **M**.

### C20 — Outillage : dossier `tools/` vide et couverture des tests
- **Problème** : `tools/` ne contient plus qu'un `__pycache__` (outil retiré) ; les tests ne couvrent ni un fournisseur partiel (C01), ni une enveloppe étrangère de la fenêtre (C05), ni le cache de compatibilité (C04), ni la déduplication de la bulle MP (`MP_BUBBLE_DEDUP_MS`).
- **Preuve** : `tools/__pycache__/sync_fallback.cpython-312.pyc` ; `tests/lua/test_beltradio.lua:189-205` (seul fournisseur testé, complet).
- **Risque** : maintenabilité.
- **Correction** : supprimer `tools/` localement ; ajouter les quatre tests lupa.
- Statut : confirmé statiquement. Priorité **basse**, effort **S**.

---

## Partie 2 — Idées de fonctionnalités

### I01 — Raccourcis du talkie à la ceinture
- **Description** : une touche (configurable dans les options du jeu) allume ou éteint le talkie accroché ; une autre passe au préréglage suivant de la radio.
- **Intérêt** : le geste naturel « tâter la radio sans la décrocher », sans menu contextuel ni fenêtre.
- **Faisabilité** : `addKeyBinding`/`isKey` (`ui-windows.md`) ; `DeviceData:setIsTurnedOn`, préréglages `getDevicePresets()` / `setChannel` ; son `RadioButton` joué sur l'émetteur de F-son. Reprendre `isAttachedOnly` pour choisir le talkie.
- **MP** : la réception MP est décidée par le client (`DistributeToPlayerOnClient`) ; le serveur ignore l'état d'une radio non tenue (C03), sans conséquence pour la réception.
- **Dépendances** : aucune ; avec BWT, laisser son raccourci PTT intact.
- **Effort** : S.

### I02 — Silencieux (squelch)
- **Description** : réglage par talkie « Silencieux » : plus de grésillement continu, seulement le son d'émission quand une ligne arrive.
- **Intérêt** : un vrai talkie coupe le souffle entre deux messages ; la boucle `RadioStatic` permanente de la 1.2.0 peut lasser.
- **Faisabilité** : drapeau en ModData de l'objet (`syncItemFields` transporte la ModData), lu par `Audio.update` qui saute la boucle statique ; option dans le menu « Options de l'appareil » déjà fourni.
- **MP** : son local seulement, aucune autorité requise.
- **Dépendances** : aucune.
- **Effort** : S.

### I03 — Talkie coupé en mode furtif
- **Description** : option sandbox : accroupi en furtif, le talkie à la ceinture ne fait plus de bruit pour les zombies (le porteur baisse instinctivement le volume) ; texte et son local conservés.
- **Intérêt** : le geste « s'accroupir pour se cacher » suffit, sans gérer le volume à la main.
- **Faisabilité** : `player:isSneaking()` dans `Noise.emit` ; aucune API nouvelle.
- **MP** : `addSound` part du client, la condition se lit sur le client.
- **Dépendances** : aucune. Désactivée par défaut pour garder la fidélité vanilla.
- **Effort** : S.

### I04 — Alerte de pile faible
- **Description** : à 15 % puis 5 % de pile, un bip court et un halo « Pile du talkie faible » au-dessus du personnage.
- **Intérêt** : à la ceinture, le joueur ne voit pas la jauge ; il découvre la pile vide trop tard.
- **Faisabilité** : seuils dans `Battery.onTick` (déjà une fois par minute) ; halo `HaloTextHelper` avec clé traduite (`clothing-and-character-state.md`, halos `IGUI_HaloNote_*`) ; son vanilla `RadioButton`.
- **MP** : local au client propriétaire.
- **Dépendances** : traductions dans les 8 langues.
- **Effort** : S.

### I05 — Infobulle d'état du talkie
- **Description** : ligne TooltipLib sur tout talkie : fréquence, nom de la station si elle est connue, charge en %.
- **Intérêt** : savoir ce qu'écoute le talkie à la ceinture d'un survol, sans ouvrir la fenêtre.
- **Faisabilité** : TooltipLib est déjà un prérequis (`BatmanRadio_MainsTooltip.lua`) ; `getDeviceData():getChannel()`, `getPower()` ; `getZomboidRadio():getChannelName(f)` (`radio-dynamic.md`).
- **MP** : ne jamais afficher le nom d'une chaîne secrète d'un fournisseur : n'afficher que les noms publics (une chaîne secrète a son nom retiré par `removeChannelName`).
- **Dépendances** : TooltipLib.
- **Effort** : S.

### I06 — Journal des dernières lignes reçues
- **Description** : « Options de l'appareil » gagne un onglet ou un bouton « Derniers messages » : les 20 dernières lignes captées par ce talkie, avec l'heure de jeu.
- **Intérêt** : une bulle disparaît vite ; en solo il n'y a pas de chat radio. Retrouver une fréquence ou un code entendu en courant.
- **Faisabilité** : tampon circulaire alimenté par `BeltRadio.deliver` (solo) et `OnDeviceText` (MP) ; section de mod dans la fenêtre radio (`ui-windows.md`, modules `RWM*` de `ISRadioWindow`).
- **MP** : local ; en MP le chat radio existe déjà, l'intérêt est surtout solo.
- **Dépendances** : ne stocker que des lignes déjà affichées (rien de secret en plus).
- **Effort** : M.

### I07 — Recharge dans un véhicule moteur allumé
- **Description** : une radio bricolée pour le secteur se recharge aussi quand son porteur est dans un véhicule dont le moteur tourne.
- **Intérêt** : geste naturel (« je branche le talkie sur l'allume-cigare »), utile avant le générateur.
- **Faisabilité** : étendre `Mains.isPoweredSquare` en `Mains.isPowered(player)` : `player:getVehicle()` puis `isEngineRunning()` ; éventuellement puiser dans la batterie du véhicule (`getBattery():getInventoryItem()`).
- **MP** : calcul côté client comme `MainsCarried` ; même limite de synchronisation (C03).
- **Dépendances** : aucune.
- **Effort** : S.

### I08 — Balayage des fréquences (talkies haut de gamme)
- **Description** : bouton « Balayer » sur `WalkieTalkie4`, `WalkieTalkie5` et `ManPackRadio` : la radio parcourt sa bande et s'arrête sur la première station qui émet.
- **Intérêt** : trouver la diffusion d'urgence ou une station sans tourner le bouton à l'aveugle.
- **Faisabilité** : en solo, registre `getScriptManager():getChannelsList()` et `getAiringBroadcast()` ; en MP le gestionnaire vaut `nil` sur le client : balayer seulement les fréquences publiques (`provider.frequencies`, stations vanilla).
- **MP** : **exclure les chaînes secrètes** des fournisseurs (Military Drop, Artemis) pour ne pas révéler une fréquence tirée par le serveur.
- **Dépendances** : bornes `MinChannel`/`MaxChannel` (`radio-dynamic.md`).
- **Effort** : M.

### I09 — Bip de fin de message
- **Description** : bip court (« roger beep ») à la fin d'un message radio d'un autre joueur reçu à la ceinture.
- **Intérêt** : signale qu'on vous répond, sans lire le chat.
- **Faisabilité** : `Noise.onAddMessage` repère déjà les messages radio de joueurs ; jouer `RadioZap` ou `RadioButton` sur l'émetteur de `BeltAudio`.
- **MP** : local.
- **Dépendances** : option `BeltAudio`.
- **Effort** : S.

### I10 — Module « Secteur » dans la fenêtre radio
- **Description** : la fenêtre « Options de l'appareil » d'une radio bricolée affiche « Branchée sur secteur » / « En charge » et le temps restant avant la charge pleine.
- **Intérêt** : l'infobulle ne dit pas quand la pile sera pleine ; la fenêtre est l'endroit où le joueur regarde la pile.
- **Faisabilité** : module de mod dans `ISRadioWindow` (`ui-windows.md`, `readFromObject`), à côté de `RWMPower` ; temps = `(1 - power) × rechargeHours`.
- **MP** : appareil posé : charge à jour seulement avec C02.
- **Dépendances** : C02.
- **Effort** : M.

### I11 — Bricolage des talkies d'autres mods
- **Description** : rendre bricolable tout talkie portatif à pile et émetteur, pas seulement la liste vanilla.
- **Intérêt** : les packs d'équipement militaire ajoutent des radios que la recette ignore.
- **Faisabilité** : `Mains.isEligible` par propriétés (`getIsPortable`, `getIsTwoWay`, `getIsBatteryPowered`) ; l'entrée de la recette, elle, liste des types : générer la liste au démarrage (`ScriptManager` et `DoParam`, à confirmer) ou accepter un tag ajouté aux scripts.
- **MP** : recette exécutée sur le serveur, rien de nouveau.
- **Dépendances** : supprime C17 si la liste devient générée.
- **Effort** : M.

### I12 — « Prendre pour parler » et retour à la ceinture
- **Description** : option de menu « Parler » sur le talkie accroché : il passe en main, puis retourne à la ceinture quand le joueur le range ou après un délai sans parole.
- **Intérêt** : respecte la décision 4 (émission seulement en main) tout en réduisant les étapes du geste « décrocher, parler, raccrocher ».
- **Faisabilité** : `ISEquipWeaponAction` (déjà suivi par `TAKING_ACTIONS`) puis action d'accroche vanilla de la barre d'objets (`ISHotbar`) au même emplacement ; délai par horloge de jeu.
- **MP** : actions chronométrées vanilla, autorité du serveur respectée.
- **Dépendances** : BWT gère son propre PTT : désactiver le retour automatique avec lui.
- **Effort** : M.

### I13 — Rattrapage de recharge d'un appareil posé
- **Description** : une radio posée sur un générateur rattrape au retour du joueur la charge qu'elle aurait gagnée pendant son absence.
- **Intérêt** : correspond à l'attente du joueur (C18) ; la base reste équipée.
- **Faisabilité** : noter `getWorldAgeHours()` en ModData de l'`IsoRadio` à chaque passage ; au chargement, créditer le temps écoulé si la case est encore électrifiée. Le générateur rattrape lui aussi son carburant au rechargement (`power-and-lights.md`) ; ne pas créditer au-delà de son autonomie projetée (`getFuel()` / `getTotalPowerUsing()`).
- **MP** : serveur seulement ; envoyer la charge (C02).
- **Dépendances** : C02.
- **Effort** : M.

### I14 — Pile retirée d'une radio bricolée : charge plafonnée (option)
- **Description** : option sandbox « La recharge sur secteur ne profite qu'à l'appareil » : une pile retirée retrouve la charge qu'elle avait à son insertion.
- **Intérêt** : ferme le chargeur infini (C07) pour les serveurs qui le jugent trop généreux.
- **Faisabilité** : noter la charge à l'insertion (ModData), envelopper l'action vanilla de retrait de pile côté autorité et réécrire `setCurrentUses` sur la pile rendue.
- **MP** : retrait fait sur le serveur, objet rendu à resynchroniser (`syncItemFields`).
- **Dépendances** : décision d'équilibrage (C07).
- **Effort** : M.

### I15 — Réveil par la radio (solo)
- **Description** : option : un talkie allumé à la ceinture qui reçoit la diffusion d'urgence ou une ligne d'une chaîne de mod réveille le personnage endormi.
- **Intérêt** : dormir près de sa radio en attendant un signal, sans rater l'événement d'un scénario.
- **Faisabilité** : dans `deliver`, `player:isAsleep()` puis `forceAwake()` côté client (`staging-effects.md`, « réveil par `forceAwake` à faire côté client ») ; filtre sur `isEmergencyBroadcast` ou les fréquences des fournisseurs.
- **MP** : en MP le sommeil est géré par le serveur ; idée limitée au solo d'abord.
- **Dépendances** : utile à Military Drop, Artemis, Radio Survivor (champ de fournisseur `wakes = true`).
- **Effort** : S.

### I16 — Multiplicateur d'usure à la ceinture
- **Description** : option entière « Usure de la pile à la ceinture (%) », 100 par défaut.
- **Intérêt** : les serveurs qui trouvent la vie d'un talkie trop courte (ou trop longue) l'ajustent sans couper l'usure.
- **Faisabilité** : `BeltBattery` appelle déjà `DeviceData.update` une fois par minute ; compenser l'écart par `setPower` après l'appel (ou `setUseDelta` temporaire, en prenant garde à `Mains.apply`).
- **MP** : client seulement (C03).
- **Dépendances** : cohérence avec les radios bricolées (usure 0 sur secteur prioritaire).
- **Effort** : S.

### I17 — Fournisseur : couleur et bulle par ligne en MP
- **Description** : champ d'API `colorOf(codes)` qui rend la couleur exacte d'une ligne (au lieu d'une couleur par fréquence), y compris le gris d'une ligne brouillée.
- **Intérêt** : en MP la bulle d'une chaîne de mod perd ses couleurs de personnages (limite F04 des spécifications).
- **Faisabilité** : `OnDeviceText` transmet les codes ; un fournisseur peut y coder un index de couleur (4 caractères réservés + suffixe). Extension de `recognize`, `VERSION = 3`.
- **MP** : aucune donnée secrète en plus (les codes arrivent déjà au client).
- **Dépendances** : adoption par les mods dépendants.
- **Effort** : S.

---

## Partie 3 — Priorisation

| Rang | Action | Pourquoi | Effort |
|---|---|---|---|
| 1 | **C01** garder `provider.channels` et `provider.open` | bug confirmé : un mod tiers casse l'écoute solo à chaque image | S |
| 2 | **C02** envoyer la charge d'un appareil posé aux clients | la recharge secteur paraît en panne en MP | S |
| 3 | **C04** mettre en cache la détection de BWT | coût par image supprimé, sans risque | S |
| 4 | **C05 + C06** enveloppe de fenêtre par identité de classe, `incompatible=` exact | compatibilité avec un mod voisin réellement installé | S |
| 5 | **C03** corriger la limite MP documentée (puis décider de la commande cliente) | documentation fausse sur l'autorité serveur | S |

Ensuite, côté joueur : I02 (silencieux), I04 (pile faible) et I05 (infobulle d'état), trois ajouts courts qui suivent le geste naturel du talkie à la ceinture.

---

Ce document propose seulement. Aucune correction ni fonctionnalité n'est implémentée sans validation explicite de l'utilisateur.
