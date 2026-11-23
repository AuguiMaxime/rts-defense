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

Choisis un objet, puis touche la carte. Toucher un autre objet le remplace. Retoucher un objet avec **le même outil** lui applique les réglages affichés (pause, durée, rayon, rotation…). **GOMME OBJETS** retire ce que tu touches. Sous la palette, seuls les réglages utiles à l'outil choisi s'affichent.

- **Ennemis · structures** : tourelle, canon, lance-missiles, laser, char en siège (portée 8), bunker (2x2), caserne ennemie (2x2, envoie un ennemi toutes les 30 s), **base ennemie** (3x3, la cible des missions « Détruire la base », envoie un blindé toutes les 45 s).
- **Ennemis · unités** : tous les ennemis du jeu. Ils gardent leur poste, attaquent ce qui s'approche, puis reviennent. Avec **IMMOBILE**, ils ne bougent plus du tout.
- **Alliés · tourelles** : déjà construites au début de la partie. **NIV** règle leur niveau, de 1 à 3.
- **Alliés · unités** : déjà présentes. **IMMOBILE** les poste en « TENIR ».
- **Mission** :
  - **VIP à escorter** : le Commandant, pour une mission Escorte ;
  - **Départ convoi allié** (optionnel) : d'où partent les convois alliés. Sans lui, ils partent du point 1 ;
  - **Point de passage** : le trajet des convois, dans l'ordre de pose (numérotés 1, 2, 3…). **PAUSE** (0 à 60 s) arrête le convoi sur ce point. Trajet **vert** = convois alliés, **rouge** = convois ennemis (mission Attaque de convois) ;
  - **Zone d'arrivée** : là où amener le VIP (**RAYON** réglable) ;
  - **Zone de prise** : une position à prendre. **TENIR** (10 à 180 s) et **RAYON** se règlent zone par zone.
- **Mission · bâtiment à défendre** : habitat, caserne, usine, forge, centre de recherche ou labo, déjà construit. Les ennemis le visent en priorité, on ne peut pas le vendre, et sa destruction fait **perdre** la mission (quel que soit le type).
- **Décor** : chaque image PNG mise dans `assets/deco/` apparaît automatiquement ici. Sa taille vient de son nom : `hangar_2x2.png` couvre 2x2 cases (`_2x1`, `_1x2`, `_3x3`, `_4x4`… ; sans suffixe = 1 case). **PIVOTER** le tourne par quarts de tour, **BLOQUE** rend toutes ses cases infranchissables. Les prompts pour générer ces images sont dans le doc « RTS Defense — Prompts décors ».

## 3. Onglet MISSION : les règles

| Type | Victoire | Défaite |
|---|---|---|
| Défense | Toutes les vagues repoussées | Base ou bâtiment à défendre détruit |
| Survie | Tenir la durée choisie. Les vagues continuent sans fin | Base détruite |
| Détruire la base | Toutes les bases ennemies (posées où tu veux, autant que tu veux) détruites | Base détruite |
| Attaque de convois | Détruire « À détruire » convois sur « Nb de convois ». Choix : train, camions ou bateau, heure de départ, écart. Trajet tracé avec les points de passage et leurs pauses ; sans points, trajet automatique sur rails / route / eau | Trop de convois arrivent au bout |
| Escorte | Le VIP entre dans la zone d'arrivée | VIP tué ou base détruite |
| Protéger le convoi | « À faire arriver » convois alliés sur « Nb de convois » atteignent le dernier point. Départ et écart réglables, pauses sur les points. Les ennemis visent les convois en priorité, puis le joueur quand aucun convoi ne roule | Trop de convois détruits ou base détruite |
| Prise de position | Chaque zone tenue sa propre durée (des unités dedans, aucun ennemi) | Base détruite |

Pour chaque type, l'onglet Mission rappelle quoi poser et propose un bouton raccourci (POSER LA BASE ENNEMIE, TRACER LE TRAJET, POSER LE BÂTIMENT À DÉFENDRE…).

- **VAGUES ENNEMIES : OUI/NON** active ou coupe les vagues. Leur nombre, leur difficulté et leur intervalle se règlent à droite.
- Le **briefing** s'affiche au lancement de la mission.
- Les **objectifs bonus** (train, convoi, bateau) se combinent avec n'importe quel type de mission.

La validation, en bas à droite, signale ce qui manque : base, chemins, VIP, zone, etc.

## 4. Tester puis m'envoyer la mission

1. **▶ TESTER** lance la mission tout de suite. Le menu de fin ramène dans l'éditeur.
2. **ENREGISTRER** écrit le fichier `maps/custom/<nom>.json` quand le jeu est lancé depuis Godot.
3. Envoie-moi ce fichier `.json`, ou pousse-le sur git. Je l'ajoute à la campagne : ordre, déblocage, récompenses.
