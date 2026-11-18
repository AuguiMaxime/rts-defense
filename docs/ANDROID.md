# Tester RTS Defense sur ton téléphone Android

La configuration d'export est déjà dans le projet (`export_presets.cfg`). Il reste à installer
trois outils sur ton PC, une seule fois. Compte environ 30 minutes, surtout du téléchargement.

## 1. Modèles d'export Godot
Dans Godot : **Éditeur → Gérer les modèles d'export → Télécharger et installer** (environ 1 Go).

## 2. Java (JDK 17)
Télécharge et installe **OpenJDK 17**, par exemple « Temurin 17 » sur adoptium.net (version Windows x64, `.msi`).

## 3. SDK Android
Le plus simple : installe **Android Studio**. Au premier lancement, laisse-le installer le SDK.
Ensuite, dans Android Studio → *SDK Manager*, vérifie que ces éléments sont cochés :
- Android SDK Platform-Tools
- Android SDK Build-Tools (la dernière version)
- Android SDK Command-line Tools

Le SDK s'installe en général dans `C:\Users\CaptainSmegma\AppData\Local\Android\Sdk`.

## 4. Relier Godot aux outils
Dans Godot : **Éditeur → Paramètres de l'éditeur → Export → Android** :
- **Java SDK Path** : le dossier du JDK 17, par exemple `C:\Program Files\Eclipse Adoptium\jdk-17...`
- **Android SDK Path** : `C:\Users\CaptainSmegma\AppData\Local\Android\Sdk`

Godot crée tout seul la clé de signature de debug.

## 5. Préparer le téléphone
1. *Paramètres → À propos du téléphone* : touche 7 fois **Numéro de build** pour activer le mode développeur.
2. *Paramètres → Options pour les développeurs* : active **Débogage USB**.
3. Branche le téléphone en USB et accepte l'autorisation qui s'affiche sur l'écran du téléphone.

## 6. Lancer le jeu sur le téléphone
- **Le plus rapide** : en haut à droite de Godot, l'icône Android (« Déploiement en un clic »)
  apparaît quand le téléphone est branché. Un clic suffit : le jeu s'installe et se lance.
- **Ou un fichier APK** : *Projet → Exporter → Android → Exporter le projet*. Le fichier
  `build/rts-defense.apk` peut s'envoyer sur n'importe quel téléphone Android.

## Pour la publication sur le Play Store (plus tard)
- Créer une clé de release (`keytool`) et la renseigner dans le preset (jamais dans Git).
- Passer `gradle_build/use_gradle_build` à `true` et exporter en **AAB**.
- Brancher AdMob (pub récompensée) et Google Play Billing (packs d'or).
