# Créer une mission

L'éditeur s'ouvre depuis le menu principal, bouton **ÉDITEUR**. Il n'est visible que tant que `Content.DEV_TOOLS` vaut `true`.

## 1. Onglet TERRAIN : le sol

| Pinceau | Effet |
|---|---|
| Gomme | Remet du sol libre |
| Rocher, Mur | Bloquent le passage. On ne peut pas construire dessus |
| Métal, Essence | Gisements, 1200 unités chacun |
| Base 3x3 | Base du joueur (obligatoire, une seule) |
| Base J2 | Base du 2e joueur en coop. En solo, c'est du sol libre |
| Apparition | Point d'arrivée des vagues ennemies |
| Eau, Route, Rails | Les ponts se posent tout seuls quand une route ou des rails traversent l'eau |

Les tailles de pinceau vont de 1 à 3. Le sol se choisit entre herbe, sable, terre, Mars et métal. Les dimensions de la carte se règlent en haut.

## 2. Onglet OBJETS : ce qu'on pose sur la carte

Choisis un objet, puis touche la carte. Toucher un objet déjà posé le remplace. **GOMME OBJETS** retire ce que tu touches.

- **Ennemis · structures** : tourelle, canon, lance-missiles, laser, char en siège (portée 8), bunker (2x2), caserne ennemie (2x2, envoie un ennemi toutes les 30 s), **base ennemie** (3x3, la cible des missions « Détruire la base », envoie un blindé toutes les 45 s).
- **Ennemis · unités** : tous les ennemis du jeu. Ils gardent leur poste, attaquent ce qui s'approche, puis reviennent. Avec **IMMOBILE**, ils ne bougent plus du tout.
- **Alliés · tourelles** : déjà construites au début de la partie. **NIV** règle leur niveau, de 1 à 3.
- **Alliés · unités** : déjà présentes. **IMMOBILE** les poste en « TENIR ».
- **Mission** :
  - **VIP à escorter** : le Commandant, pour une mission Escorte ;
  - **Convoi allié** : véhicule non contrôlable, pour une mission Protéger le convoi ;
  - **Point de passage** : le trajet du convoi allié, dans l'ordre de pose (numérotés 1, 2, 3…) ;
  - **Zone d'arrivée** : là où amener le VIP ;
  - **Zone de prise** : pour une mission Prise de position.
- **Décor** : chaque image PNG mise dans `assets/deco/` apparaît automatiquement ici. **BLOQUE** rend l'objet infranchissable.

## 3. Onglet MISSION : les règles

| Type | Victoire | Défaite |
|---|---|---|
| Défense | Toutes les vagues repoussées | Base détruite |
| Survie | Tenir la durée choisie. Les vagues continuent sans fin | Base détruite |
| Détruire la base | Toutes les bases ennemies détruites | Base détruite |
| Attaque de convois | Détruire « À détruire » convois sur « Nb de convois ». Choix : train, camions ou bateau, heure de départ, écart entre deux convois | Trop de convois passent |
| Escorte | Le VIP entre dans la zone d'arrivée | VIP tué ou base détruite |
| Protéger le convoi | Le convoi allié arrive au dernier point de passage | Convoi détruit ou base détruite |
| Prise de position | Chaque zone de prise tenue « X » secondes (des unités dedans, aucun ennemi) | Base détruite |

- **VAGUES ENNEMIES : OUI/NON** active ou coupe les vagues. Leur nombre, leur difficulté et leur intervalle se règlent à droite.
- Le **briefing** s'affiche au lancement de la mission.
- Les **objectifs bonus** (train, convoi, bateau) se combinent avec n'importe quel type de mission.

La validation, en bas à droite, signale ce qui manque : base, chemins, VIP, zone, etc.

## 4. Tester puis m'envoyer la mission

1. **▶ TESTER** lance la mission tout de suite. Le menu de fin ramène dans l'éditeur.
2. **ENREGISTRER** écrit le fichier `maps/custom/<nom>.json` quand le jeu est lancé depuis Godot.
3. Envoie-moi ce fichier `.json`, ou pousse-le sur git. Je l'ajoute à la campagne : ordre, déblocage, récompenses.
