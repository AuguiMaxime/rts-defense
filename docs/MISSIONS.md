# Créer une mission

L'éditeur s'ouvre depuis le menu principal, bouton **ÉDITEUR**. Il n'est visible que tant que `Content.DEV_TOOLS` vaut `true`.

## 0. L'écran de l'éditeur (PC, souris et clavier)

- **En haut** : Menu, Fichier (nouvelle, ouvrir, enregistrer, enregistrer sous, paramètres de la carte, raccourcis), nom de la carte, onglets **Carte / Objets / Mission** (touches 1, 2, 3), annuler / rétablir, copier, coller, dupliquer, supprimer, Valider, Enregistrer, **▶ Tester** (F5).
- **À gauche** : les outils et le contenu de l'onglet.
- **À droite** : les réglages de l'outil ou de la sélection, les **calques** (œil = afficher, cadenas = verrouiller ; un calque masqué ou verrouillé ne peut pas être modifié), la grille et la **vérification des passages** (chemins des vagues en orange, zones inaccessibles et gisements bloqués en rouge).
- **En bas** : la case sous la souris, l'aide de l'outil, l'état d'enregistrement, la validation (clic = liste des problèmes) et le zoom.
- **Vue** : molette = zoom sur le curseur, clic milieu / clic droit / Espace + glisser = déplacer, flèches, Ctrl+0 = cadrer.
- **Historique** : Ctrl+Z / Ctrl+Y sur 100 actions. Le travail est sauvegardé automatiquement toutes les 30 s ; s'il n'a pas été enregistré, l'éditeur propose de le reprendre à la prochaine ouverture. Tester puis revenir garde l'historique, les outils et la vue.
- F1 affiche tous les raccourcis.

### Sélection (V), commune aux onglets Carte et Objets

Clic sur un objet pour le choisir, Maj+clic pour en ajouter, glisser sur du vide pour un rectangle (dans Carte, le rectangle prend aussi le terrain ; dans Objets, seulement les objets). Glisser la sélection la déplace. Ctrl+C / Ctrl+X / Ctrl+V / Ctrl+D, Suppr, Ctrl+A. **R** pivote d'un quart de tour, **M** fait un miroir gauche-droite, **Maj+M** haut-bas (aussi pendant un collage). Le sol nu n'est jamais collé : copier un groupe de rochers ne recouvre pas le terrain autour. Les bases ne se dupliquent pas.

Un seul objet sélectionné : son nom (unique, modifiable) et ses réglages s'affichent à droite.

## 1. Onglet CARTE : le terrain

Outils : **Sélection (V)**, **Pinceau (B)** (Maj+clic = ligne droite, Alt+clic = pipette, [ ] = taille 1×1 à 7×7), **Remplissage (F)** (remplit la zone de même terrain), **Pipette (I)**. **E** prend la gomme de terrain.

| Terrain | Effet |
|---|---|
| Gomme | Remet du sol libre |
| Rocher, Mur | Bloquent le passage. On ne peut pas construire dessus |
| Métal, Essence | Gisements, 1200 unités chacun |
| Base joueur 1 | Base du joueur (obligatoire, une seule, 3x3) |
| Base joueur 2 | Base du 2e joueur en coop. En solo, c'est du sol libre |
| Apparition | Point d'arrivée des vagues ennemies |
| Eau, Route, Rails | Les ponts se posent tout seuls quand une route ou des rails traversent l'eau |

Le sol se choisit entre herbe, sable, terre, Mars et métal. La taille de la carte se règle dans Fichier → Paramètres de la carte.

## 2. Onglet OBJETS : ce qu'on pose sur la carte

Outils : **Sélection (V)**, **Poser (P)**, **Gomme (E)**, **Pipette (I)** (reprend un objet et ses réglages). Le catalogue a une recherche et des catégories repliables. Choisis un objet, règle-le à droite, puis clique sur la carte ; en glissant, il se pose sur chaque case libre. Poser sur un autre objet le remplace. Recliquer un objet avec **le même outil** lui applique les réglages affichés. Chaque objet reçoit un nom unique (« Tourelle canon 2 ») modifiable dans la sélection.

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

### Fiche d'un objet (clic droit)

Clic droit sur un objet (ou sélection d'un seul objet) : sa fiche s'affiche à droite. Double clic : renommer.

- **Comportement** (ennemis) : garde son poste, immobile, patrouille (bouton *Tracer…* puis clique les points dans l'ordre), défend une structure, attaque à vue, attaque une cible (une tourelle, une unité ou un bâtiment allié), attaque une zone, suit une unité, marche sur la base. **Repli sous X %** : l'ennemi retourne à son point de départ quand ses PV passent sous ce seuil.
- **Comportement** (unités alliées) : garde, tient la position, patrouille, suit une unité. **Contrôle** : joueur ou *IA alliée* (non sélectionnable). Les chars peuvent démarrer **en siège**.
- **Statistiques** : points de vie, dégâts, portée, vitesse en pourcentage (100 % = normal). **Invulnérable**. Tourelles : niveau ; tourelles et bâtiments : *en chantier* (les ouvriers doivent le terminer).
- **Liens** : bouton *Choisir…* puis clic sur l'objet voulu sur la carte (les candidats clignotent). Une flèche relie l'objet à sa cible.

### Objets interactifs

| Objet | Effet en jeu |
|---|---|
| Porte | Infranchissable tant qu'elle est fermée. Longueur 1 à 8, horizontale ou verticale, ouverte ou fermée au départ. S'ouvre quand son lien est activé (terminal) ou détruit (générateur, structure, ennemi) |
| Générateur ennemi | Structure 2×2 sans arme, à détruire |
| Bouclier | Rend invulnérables les ennemis dans son rayon tant que son générateur est en vie |
| Terminal | S'active quand une unité du joueur reste à côté le temps indiqué |
| Prisonniers | Libérés au contact d'une unité du joueur : ils la rejoignent (nombre et type réglables) |
| Objet à récupérer | Ramassé quand une unité du joueur passe dessus |

Les zones ont maintenant cinq rôles : prise, arrivée, extraction, passage, déclencheur. Extraction, passage et déclencheur serviront aux objectifs et déclencheurs (livraison 3).

### Catalogue

Clic droit sur un objet du catalogue : l'ajoute aux **★ Favoris** (ou l'en retire). Les 8 derniers objets posés apparaissent dans **Récents**.

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
