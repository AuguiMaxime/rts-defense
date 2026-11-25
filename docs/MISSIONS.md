# Créer une mission

L'éditeur s'ouvre depuis le menu principal, bouton **ÉDITEUR**. Il n'est visible que tant que `Content.DEV_TOOLS` vaut `true`.

## 0. L'écran de l'éditeur (PC, souris et clavier)

- **En haut** : Menu, Fichier (nouvelle, ouvrir, enregistrer, enregistrer sous, paramètres de la carte, raccourcis), nom de la carte, onglets **Carte / Objets / Objectifs / Événements / Vagues / Mission** (touches 1 à 6), annuler / rétablir, copier, coller, dupliquer, supprimer, Valider, Enregistrer, **▶ Tester** (F5).
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

**Chaque type est un modèle.** Choisir un type génère ses objectifs (et quelques déclencheurs), marqués « modèle » dans les onglets Objectifs et Événements. Tu peux les modifier, en ajouter, en supprimer :
- les objectifs du modèle visent la carte de façon générique (« le VIP », « la zone d'arrivée », « les zones de prise », « la durée de l'onglet Mission ») : poser ou déplacer ces objets ne casse rien ;
- changer de type remplace les objectifs du modèle et **garde tes ajouts** ; **Régénérer le modèle** remet ceux d'origine ;
- poser un **bâtiment à défendre** ajoute l'objectif « Défendre les bâtiments » (détruit = défaite) ;
- les missions d'une ancienne version et les 7 cartes de la campagne sont converties automatiquement à l'ouverture.

- **Vagues ennemies** : se règlent dans l'onglet **Vagues** (touche 5).
- Le **briefing** s'affiche au lancement de la mission.
- Les **objectifs bonus** (train, convoi, bateau) se combinent avec n'importe quel type de mission.

La validation, en bas à droite, signale ce qui manque : base, chemins, VIP, zone, etc.

## 3b. Onglet OBJECTIFS (touche 3)

- **+ Ajouter ▾** propose 40 modèles prêts (détruire, capturer, survivre, escorter, récolter, construire…). 17 types au total.
- **Importance** : ◆ principal, ◇ secondaire, ○ bonus. **Départ** : visible, caché (révélé par un déclencheur) ou « après » d'autres objectifs (objectifs successifs).
- **Combinaisons** : un objectif peut regrouper d'autres objectifs en ET, OU, « X sur Y », ou NON.
- **Récompense** (métal, essence) et **délai** optionnel (échec si le temps est écoulé).
- Les champs « objet » proposent une liste ou le bouton **◎** pour cliquer l'objet sur la carte. Les objets concernés sont surlignés en or.
- **Règles de la mission** (en haut) : victoire = tous les objectifs principaux réussis, ou manuelle (action « Victoire ») ; défaite si la base est détruite et/ou si un objectif principal échoue.
- En jeu, la liste s'affiche à droite : ◆ / ◇ / ○ avec la progression et les chronos ⏱.

## 3c. Onglet ÉVÉNEMENTS (touche 4)

**Déclencheurs** : QUAND (un événement : début, temps écoulé, unité dans une zone, objet détruit, objectif réussi, variable changée…) → SI (conditions en ET/OU, chacune inversable avec NON) → ALORS (actions) / SINON (actions si les conditions sont fausses).
- Réglages : actif ou non au départ, une seule fois ou répété, priorité, délai avant les actions. L'action **Attendre** crée des séquences.
- Actions : messages, alertes, sons, ping sur la carte, faire apparaître des unités ou des objets « absents au départ », réveiller un ennemi « en attente », ouvrir/fermer des portes, révéler/réussir/échouer un objectif, modifier une variable, activer/forcer un autre déclencheur, chronos, victoire, défaite…
- Modèles rapides : message d'introduction, renforts quand le joueur entre dans une zone, compte à rebours puis vague.
- Anti-boucle : 300 actions par image et 20 déclenchements par seconde au maximum.

**Variables** : nombre, booléen, texte ou référence à un objet (`$nom`). Renommer une variable met à jour tous les déclencheurs.

**Dépendances** : vue en lecture seule qui relie déclencheurs, variables et objectifs (QUAND, SI, ALORS, après, fait partie de).

**Fiche d'un objet** : « Au départ : Absent » le fait apparaître plus tard via un déclencheur ; le comportement ennemi « En attente » le garde immobile jusqu'à ce qu'on le réveille.

La validation signale en plus : paramètres manquants, références cassées, aucune condition de victoire, objectif caché jamais révélé, déclencheur désactivé jamais réactivé, variable ou zone inutilisée, objet absent jamais activé.

## 3d. Onglet VAGUES (touche 5)

- **Vagues automatiques : oui / non.** « Non » : aucune vague ne part seule, seulement par des déclencheurs (toujours « oui » en Défense).
- **Mode automatique** : nombre de vagues, difficulté, intervalle. La composition grossit à chaque vague, avec un boss toutes les 5 vagues.
- **Mode personnalisé** : la première fois, les vagues automatiques sont converties en liste, que tu modifies une par une. Chaque vague a :
  - un **nom** et un **lancement** : après la précédente (+ délai), quand la précédente est éliminée (+ délai), par un déclencheur, ou quand un objectif est réussi (+ délai) ;
  - une **arrivée** progressive (écart entre ennemis) ou simultanée, et un multiplicateur de **PV** ;
  - un **comportement** : marche sur la base, chasse les unités, attaque une cible ou une zone ;
  - des **répétitions** (nombre et intervalle) ;
  - des **groupes d'ennemis** : type (ou « Aléatoire »), nombre, point d'apparition, et une **escorte** optionnelle (chaque ennemi du groupe arrive avec N ennemis d'un autre type, pratique pour un boss).
- **+ Ajouter** propose aussi : vague de boss avec escorte, embuscade (déclencheur, simultanée, agressive), harcèlement (répétée).
- **Points d'apparition** : nomme-les (« Nord », « Rivière »…) et ◎ pour les voir. Le nom s'affiche sur la carte, et ceux de la vague sélectionnée sont surlignés en or.
- **Déclencheurs** : QUAND « Vague commencée / éliminée » (par numéro ou par nom), SI « Ennemis des vagues restants », ALORS « Lancer une vague », « Arrêter une vague » (ou toutes), « Suspendre », « Reprendre », « Accélérer » (×2 = deux fois plus vite).
- En jeu, le panneau des vagues affiche le compte à rebours et les **ennemis restants**. Les outils de test (F2) permettent de lancer ▶ ou d'arrêter ■ chaque vague.

## 3e. Factions et relations (onglet Mission, bouton « Factions et relations… »)

- **6 factions de base** : Joueur 1, Joueur 2, Alliés IA, Civils (camp du joueur) ; Ennemis, Neutres (camp ennemi). Tu peux ajouter des **factions personnalisées** (nom, couleur, camp).
- **Deux camps.** Les factions d'un même camp sont toujours alliées. Entre les deux camps, le tableau règle chaque paire : **Ennemi**, **Neutre** (on s'ignore) ou **Hostile si attaqué** (neutre jusqu'à ce que cette faction du joueur tire dessus). Par défaut : tout le monde est ennemi, sauf les Neutres.
- **Fiche d'un objet** : champ **Faction** (ennemis, structures, unités alliées, VIP). Joueur 1 / 2 = contrôlée par le joueur ; Alliés IA, Civils et factions personnalisées = pilotées par l'ordinateur, avec leur comportement (dont **Chasse les ennemis** : l'allié part seul vers l'ennemi hostile le plus proche).
- **Vagues** : chaque vague personnalisée a sa faction (camp ennemi).
- **Déclencheurs** : QUAND « Relation changée », SI « Relation entre factions » / « Faction d'un objet », ALORS « Changer une relation », « Changer la faction d'un objet » (dans le même camp : un soldat du joueur peut passer aux Alliés IA, un ennemi aux Neutres), « Créer des unités » avec une faction.
- En jeu, une unité ou un ennemi d'une autre faction porte un anneau à sa couleur (en pointillé s'il n'est pas hostile).
- Limite : deux factions du même camp ne peuvent pas se battre entre elles.

## 3f. Paramètres de la partie et aperçu (onglet Mission)

- **Métal, essence, ouvriers de départ, PV de la base** : remplacent les valeurs du jeu. Les technos du joueur (Réserves, Coque…) s'ajoutent toujours.
- **Unités et bâtiments de départ** : pose-les dans l'onglet Objets (Alliés · unités, tourelles, et la nouvelle catégorie **Alliés · bâtiments de départ** : caserne, usine, maison… construits ou en chantier).
- **Durée maximale** (0 = aucune) : au bout du temps, défaite ou victoire au choix. Le temps restant s'affiche avec les objectifs.
- **Joueurs** : solo, coop ou les deux (en coop, la base du joueur 2 est obligatoire). **Difficulté affichée** : de 1 à 5 étoiles.
- **Aperçu** : « Générer depuis la carte » ou « Choisir une image… ». L'image est rangée dans le fichier de la mission.

## 3g. Validation (bouton Valider ou statut en bas à droite)

Chaque problème a un bouton **Aller** qui ouvre le bon onglet et montre l'élément : l'objet (sélectionné, la case clignote), l'objectif, le déclencheur, la vague ou la case de la carte. Les **erreurs** (rouge) empêchent de tester ; les **avertissements** (orange) signalent un oubli probable.

Vérifié notamment : base, apparitions, chemins vers la base, gisements accessibles, base du joueur 2 ; objets hors carte, sur un obstacle, sur la même case, noms en double, liens cassés ; objectifs, déclencheurs, variables, vagues et factions incomplets ou introuvables ; victoire et défaite possibles ; paramètres incohérents (durée maximale plus courte que la survie, départ sans ressources) ; nom, briefing et aperçu manquants.

## 3h. Affichage debug (outils de test F2)

Pendant un test : **Zones** (cercle, nom, rôle, progression de prise, noms des apparitions), **Chemins** (trajet de chaque ennemi et unité), **Portées** (tourelles, unités, ennemis). Le panneau F2 affiche aussi l'état des objectifs, des déclencheurs, des variables et des vagues.

## 4. Tester puis m'envoyer la mission

1. **▶ TESTER** lance la mission tout de suite. Le menu de fin ramène dans l'éditeur.
2. **ENREGISTRER** écrit le fichier `maps/custom/<nom>.json` quand le jeu est lancé depuis Godot.
3. Envoie-moi ce fichier `.json`, ou pousse-le sur git. Je l'ajoute à la campagne : ordre, déblocage, récompenses.

### Outils de test (F2 ou bouton TEST)

Pendant un test lancé depuis l'éditeur : pause, x1, x2, x4, invincible, ressources illimitées, vague suivante, faire apparaître 5 ennemis, avancer de 30 s, redémarrer. Le panneau liste aussi les objectifs (✔ / ✖ pour les forcer), les déclencheurs (▶ pour les forcer), les variables et le journal des événements.
