# Tests en jeu automatiques

Parcours nominal de Belt Walkie-Talkie exécuté dans le vrai jeu (Build 42.21) par le lanceur générique pz-autotest
(`C:\Users\cyber\Zomboid\Workshop\.claude\tools\pz-autotest`, voir son `README.md` et le skill `pz-autotest`). Cas
limites : plus tard.

- Configuration : [`autotest.json`](../../../autotest.json) (TooltipLib, prérequis `require=`, lu dans le Workshop Steam
  `3694097672` et copié ; puis `batman_BeltRadio`).
- Hooks : [`autotest/br_hooks.lua`](../../../autotest/br_hooks.lua), une vérification par fonctionnalité principale de
  [specifications-fonctionnelles.md](../../specifications-fonctionnelles.md).
- Résultats : `runs/<date>-<mode>-<jeton>/summary.txt` (ignoré par git).

## Commandes

Depuis `C:\Users\cyber\Zomboid\Workshop`, un seul jeu à la fois (`--wait-idle` attend que le jeu et les serveurs
lancés par d'autres soient fermés) :

```powershell
python .claude/tools/pz-autotest/pz_autotest.py check  BeltRadio                                   # config, mods, hooks
python .claude/tools/pz-autotest/pz_autotest.py sp     BeltRadio --wait-idle 3600                   # solo
python .claude/tools/pz-autotest/pz_autotest.py server BeltRadio --wait-idle 3600                   # serveur dédié seul
python .claude/tools/pz-autotest/pz_autotest.py mp     BeltRadio --clients 1 --client-run --wait-idle 3600  # serveur + client
```

Paramètre : `-P waitSec=90` (secondes réelles au plus pour voir passer deux minutes de jeu, F05).
Codes de sortie : 0 OK, 1 vérification en échec, 2 délai / démarrage / erreur des hooks, 3 jeu déjà lancé.

## Vérifications

Deux talkies-walkies (`Base.WalkieTalkie2`, pile chargée, allumés, fréquence 99,9 MHz) sont ajoutés au joueur :
A accroché à `Walkie Belt Left`, B rangé puis en main. Ils sont retirés à la fin.

| Fonction | Client solo | Client MP | Serveur |
|---|---|---|---|
| API chargée (`BatmanRadioSupport.VERSION >= 2`) | oui | oui | oui |
| F01 option « Options de l'appareil » pour A | oui | oui | — |
| F02 enveloppe de `ISRadioWindow.update`, fenêtre gardée et radio allumée | oui | oui | — |
| F03 récepteur solo démarré, A choisie pour sa fréquence, ligne livrée | oui | — | — |
| F04 bulle MP (`onDeviceTextMP`) | — | oui | — |
| F05 pile de A qui baisse en deux minutes de jeu | oui | oui | — |
| F06 bruit, F07 son armés pour A | oui (par la ligne livrée) | oui (appel direct) | — |
| F08 `canTransmitWith` : `belt`, `stowed`, en main autorisé | oui | oui | — |
| F10 recette enregistrée, `OnTest` puis `OnCreate` puis refus | oui | oui (fonctions locales) | oui |
| F11 sur secteur : usure nulle et recharge ; hors secteur : usure d'origine | oui | oui | — |
| F12 appareil posé (`IsoRadio` non ajouté au monde) suivi, règle de sa case, `movableData` | oui | — | oui (joueur connecté) |
| F13 fournisseur TooltipLib inscrit | oui | oui | — |
| Aucune nouvelle erreur Lua pendant le test | oui | oui | oui |

## Limites

- F03, F06, F07 sont vérifiés par l'état du mod (ligne livrée, bruit noté, son armé), pas à l'œil ni à l'oreille : la
  bulle et le son restent à contrôler en jeu.
- F04 et F06 en MP appellent les fonctions du mod directement, sans vraie ligne de station ni chat radio.
- Client MP : les radios sont créées côté client seulement (objets inconnus du serveur) ; `server` seul n'a pas de
  joueur et saute F12.
- F11 est vérifié par `Mains.apply`, pas par une vraie zone électrifiée (la case du joueur est notée en `INFO`).
