# Belt Walkie-Talkie (`batman_BeltRadio`) — documentation

Un talkie-walkie accroché à la ceinture se règle, reste allumé, entend sa station en solo, affiche une bulle en multijoueur, use sa pile, sonne et fait du bruit comme en main ; les radios se bricolent pour le secteur. Le mod est aussi le récepteur radio commun (`BatmanRadio`) de Military Drop, Opération Artemis et Radio Survivor.

| Document | Rôle |
|---|---|
| [architecture.md](architecture.md) | Architecture logicielle : arborescence du mod, modules Lua par côté, événements, autorité, persistance, intégrations, outillage |
| [specifications-fonctionnelles.md](specifications-fonctionnelles.md) | Ce que fait le mod pour le joueur et l'administrateur (fonctionnalités `F01`…), options sandbox, solo/MP, limites connues |
| [specifications-techniques/](specifications-techniques/README.md) | Contrats techniques : recette, objets, ModData, options sandbox, traductions, globales, compatibilités, version |
| [specifications-techniques/api-publique.md](specifications-techniques/api-publique.md) | API Lua publique `BatmanRadioSupport` pour les autres mods (fournisseurs, `canTransmitWith`, secteur, bruit) |
| [decisions.md](decisions.md) | Journal des décisions de conception (2026-10-10 au 2026-10-14) |
| [ameliorations-et-idees.md](ameliorations-et-idees.md) | Améliorations de code et idées de fonctionnalités (propositions, à valider) |
| [annexes/tests/autotest.md](annexes/tests/autotest.md) | Tests en jeu automatiques (pz-autotest) : commandes, vérifications par fonctionnalité, limites |
| [wiki/en/Home.md](wiki/en/Home.md) | Wiki joueur et administrateur, anglais (source du wiki GitHub) |
| [wiki/fr/Home.md](wiki/fr/Home.md) | Wiki joueur et administrateur, français |
| [images/screenshots/](images/screenshots/) | Captures en jeu utilisées par le README, le wiki et la page Steam |

Hors de `docs/` : [README.md](../README.md) (présentation GitHub), [CHANGELOG.md](../CHANGELOG.md), descriptions Workshop `README.steam*` et `workshop.txt` à la racine.
