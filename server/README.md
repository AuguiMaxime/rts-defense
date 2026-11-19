# Serveur relais — coop en ligne

Petit serveur Node.js (paquet `ws`) qui met en relation deux joueurs par un **code de salon de 4 lettres**
et leur transmet les messages de jeu. La partie elle-même tourne chez l'hôte : le serveur ne fait que relayer,
il consomme très peu (quelques Ko/s par partie).

## Tester en local
```bash
cd server
npm install
npm test          # test automatique : salon, invité, messages dans les deux sens
npm start         # serveur sur le port 8080
```
Dans le jeu : COOP → EN LIGNE → champ « Serveur » : `ws://127.0.0.1:8080` (Entrée pour valider).
Sur un téléphone du même réseau, mets l'IP du PC à la place de 127.0.0.1.

## Mettre en ligne (gratuit) avec Render
1. Crée un compte sur render.com et connecte ton GitHub.
2. **New → Blueprint**, choisis le repo `rts-defense` : le fichier `render.yaml` configure tout.
   (Ou **New → Web Service** : Root Directory `server`, Build `npm install`, Start `npm start`.)
3. Render te donne une adresse du type `https://rts-defense-relay.onrender.com`.
4. Dans le jeu, l'adresse du serveur est `wss://rts-defense-relay.onrender.com` (wss, pas https).
   C'est la valeur par défaut ; si ton adresse est différente, dis-la-moi et je la mets dans le jeu,
   ou entre-la dans le champ « Serveur » du salon.

Sur l'offre gratuite, le serveur s'endort après 15 min sans activité : la première connexion
peut alors prendre 30 à 60 secondes. Pour éviter ça : offre payante (~7 $/mois) ou un autre
hébergeur (Railway, Fly.io, un VPS…). N'importe quel hébergeur Node.js avec WebSocket convient.

## Protocole
- Texte (JSON) : `{"op":"host"}` → `{"op":"room","code":"ABCD"}` ;
  `{"op":"join","code":"ABCD"}` → `{"op":"joined"}` côté invité, `{"op":"partner"}` côté hôte ;
  ensuite `left` (l'invité est parti), `closed` (l'hôte a fermé), `error`.
- Binaire : messages de jeu, transmis tels quels à l'autre joueur.
