# Installation

- **Jeu :** Project Zomboid Build 42.21 ou plus récent (`versionMin=42.21`).
- **Prérequis :** [TooltipLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3694097672), à installer et activer aussi.
- **Workshop :** [Belt Walkie-Talkie](https://steamcommunity.com/sharedfiles/filedetails/?id=3817018338), identifiant de mod `batman_BeltRadio`.

## Solo

Activez **Belt Walkie-Talkie** et **TooltipLib** dans la liste des mods, ou dans les mods de votre sauvegarde. Le mod n'ajoute aucun objet au monde : il peut être ajouté à une sauvegarde existante.

## Serveur dédié

Ajoutez les deux mods aux réglages du serveur, à côté de ceux qu'il utilise déjà :

```
WorkshopItems=3694097672;3817018338
Mods=\TooltipLib;\batman_BeltRadio
```

Les options sont sur la page sandbox **Talkie-walkie à la ceinture** (voir [Options sandbox](04-options-sandbox.md)).

## Retirer le mod

Le mod ne stocke qu'une marque sur les radios bricolées pour le secteur. Son retrait d'une partie en cours n'a pas été testé : une radio vue en dernier sur le secteur peut garder une pile qui ne s'use plus.

> Capture à faire : les lignes Belt Walkie-Talkie et TooltipLib dans la liste des mods.
