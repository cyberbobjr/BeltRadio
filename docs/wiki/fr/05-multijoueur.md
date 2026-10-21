# Multijoueur

Belt Walkie-Talkie fonctionne sur serveur dédié ou hébergé. Il n'envoie aucune commande réseau propre ; le serveur et chaque client ont besoin du mod et de TooltipLib.

- **Écoute :** en multijoueur, le jeu fait déjà recevoir toutes les radios allumées de l'inventaire principal, mais seulement dans le chat radio. Le mod ajoute la **bulle radio** au-dessus du personnage pour un talkie accroché (option « Bulle pour une radio non tenue »). Une radio rangée n'a pas de bulle. Une même ligne n'est pas affichée deux fois en 2 secondes.
- **Couleur de la bulle :** blanche, ou celle que déclare le mod de la station (par exemple Military Drop, Opération Artemis, Radio Survivor). Le brouillage de l'orage ne la rend pas grise.
- **Pile, bruit, son :** comme en solo, gérés par votre client. Le bruit est envoyé au serveur et attire les zombies ; le son n'est entendu que par vous.
- **Secteur :** une radio portée est gérée par votre client ; le serveur apprend sa charge par les mises à jour de pile vanilla envoyées quand elle est allumée. Les radios posées sont gérées par le serveur.
- **Parler** depuis la ceinture : prenez le talkie en main.

Pas encore testé en jeu : bruit et son pour les messages radio des autres joueurs (ils passent par l'événement du chat radio).

> Capture à faire : bulle radio au-dessus d'un joueur en multijoueur, talkie à la ceinture.
