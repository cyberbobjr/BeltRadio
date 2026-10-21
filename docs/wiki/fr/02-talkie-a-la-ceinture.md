# Talkie-walkie à la ceinture

Un talkie-walkie est « à la ceinture » quand il est accroché à un emplacement d'accroche, ni en main ni sur le dos. En vanilla, un tel talkie ne se règle pas, s'éteint dès que sa fenêtre est ouverte et n'entend rien en solo.

## Options de l'appareil

Clic droit sur le talkie accroché : **Options de l'appareil** ouvre la fenêtre radio habituelle (fréquence, allumage, volume, préréglages).

![« Options de l'appareil » dans le menu contextuel](../../images/screenshots/belt-device-options-menu.png)

La fenêtre n'éteint plus le talkie, même pendant que vous le prenez en main.

## Écoute (solo)

Un talkie accroché, allumé, avec du volume et une pile chargée, entend la station sur laquelle il est réglé : stations vanilla, diffusion d'urgence et stations ajoutées par des mods. Les lignes s'affichent dans une bulle radio au-dessus du personnage. L'orage les brouille (texte gris) comme pour un talkie en main. Publicités et pauses s'affichent en gris.

![Diffusion d'urgence entendue à la ceinture](../../images/screenshots/belt-emergency-broadcast-bubble.png)

![Station d'un mod entendue à la ceinture, fenêtre ouverte](../../images/screenshots/belt-window-and-bubble.png)

Si la radio en main reçoit déjà la même fréquence, la ceinture n'ajoute rien.

## Pile

Un talkie accroché allumé consomme sa pile chaque minute de jeu, comme en main.

## Bruit

Chaque ligne reçue fait un bruit qui attire les zombies, comme en main : même volume et même portée, aucun avec des écouteurs ou à volume nul, au plus un bruit toutes les 2 secondes par radio. En vanilla, seule la première ligne faisait du bruit.

## Son

Un talkie accroché allumé fait entendre le son de la radio comme en main : grésillement en attente, puis le son de l'émission à chaque ligne reçue (son de diffusion d'urgence sur le canal d'urgence) pendant environ 5 secondes, puis un bref « zap » au retour au grésillement. Vous seul l'entendez, comme en main. Les lignes de grésillement écrites (« Bzzt ») d'une radio en main ne sont pas reproduites.

## Parler

On ne parle pas depuis la ceinture : prenez le talkie en main ou portez une radio sur le dos. Les mods construits sur Belt Walkie-Talkie (Military Drop, Opération Artemis, Radio Survivor) refusent un appel depuis une radio accrochée et demandent de la prendre en main.

## Radios rangées

Une radio rangée dans l'inventaire ou dans un sac (ni accrochée ni tenue) n'entend rien en solo, comme en vanilla.

Écoute, pile, bruit et son peuvent chacun revenir au comportement vanilla par les [options sandbox](04-options-sandbox.md).
