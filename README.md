# RTS Defense

Tower defense mobile façon RTS, en Godot 4.7 (rendu Compatibilité, 2D vue du dessus, paysage).
Tu récoltes du métal et de l'essence avec tes ouvriers, tu construis des tourelles en temps réel
et tu tiens ta base face aux vagues.

## Tester
1. Fermer Godot, puis `git pull`.
2. Ouvrir le projet dans Godot, puis **F5** (le jeu démarre sur le menu principal).

## Contrôles
| Action | Mobile | PC |
| --- | --- | --- |
| Sélectionner des ouvriers | glisser un doigt (zone) ou toucher un ouvrier | clic glissé / clic |
| Donner un ordre | toucher un gisement, un chantier, une tourelle abîmée ou le sol | clic |
| Construire | carte en bas, puis toucher une case libre | idem |
| Caméra | 2 doigts pour déplacer, pincer pour zoomer | clic droit glissé, ZQSD, molette |

## Contenu
- **Écrans** : menu principal, campagne (5 secteurs), boutique, technologies, paramètres, pause, fin de partie.
- **Modes** : campagne, Survie (vagues infinies, débloquée après chaque secteur, record sauvegardé),
  **Coop à deux** en réseau local (même Wi-Fi) : même base, mêmes ressources.
- **Tutoriel** guidé à la première partie.
- **Tourelles** : mitrailleuse (sol + air), canon lourd (zone, sol), anti-air, laser (boutique).
  Chaque tourelle s'améliore jusqu'au niveau 3, se répare et se vend (touche-la).
- **Bâtiments** : habitat (+3 de population). **Pouvoir** : frappe orbitale (techno).
- **Ennemis** : normal, rapide, blindé (armure), volant (ignore le labyrinthe), boss toutes les 5 vagues.
- **Progression** : crédits gagnés en mission → technos permanentes et augments ; or → laser et skins.

## Sur téléphone
Voir [docs/ANDROID.md](docs/ANDROID.md) : installation des outils et déploiement en un clic.

## Organisation du code
```
scripts/sim/    Simulation pure (aucun affichage) : grille, chemins, flow field, monde, vagues.
                C'est ce bloc qui tournera sur un serveur pour le multijoueur.
scripts/view/   Affichage de la map et des unités, caméra.
scripts/ui/     Thème, écrans, HUD, sons (autoloads Ui et Sfx).
scripts/data/   Sauvegarde (autoload Save) et catalogue du contenu (Content).
scripts/net/    Coop : autoload Net (ENet, découverte LAN) et NetSync (photos d'état hôte -> client).
maps/           Maps en texte (une lettre par case).
assets/         Kenney Tower Defense (CC0), polices OFL, sons générés.
tests/          Tests headless : godot --headless --script res://tests/run_tests.gd
```

Tous les chiffres d'équilibrage sont dans `scripts/sim/balance.gd` et `scripts/data/content.gd`.

## Coop
Menu → COOP. Un joueur crée la partie, l'autre la voit apparaître (ou entre l'adresse IP affichée).
L'hôte fait tourner la simulation ; l'invité envoie ses ordres et reçoit l'état 10 fois par seconde.
Pour tester sur un seul PC : lancer deux fois le jeu (Débogage → Exécuter plusieurs instances dans Godot).

## À brancher avant publication
- Paiements Google Play (packs d'or : boutons en place, achat non actif).
- AdMob pour la pub récompensée (simulée pour l'instant dans `scripts/ui/shop.gd`).
