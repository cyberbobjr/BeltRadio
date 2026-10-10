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
