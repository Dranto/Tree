# Mettre le jeu sur Steam : ce qu'il reste à faire (Antoine)

Le code Steam est prêt et **facultatif** : sans la bibliothèque GodotSteam ni le client Steam, le jeu tourne exactement pareil. Il utilise pour l'instant l'App ID de test **480** (« Spacewar », fourni par Valve).

## 1. Compte Steamworks
1. Créer le compte développeur sur https://partner.steamgames.com (identité, banque, fiscalité).
2. Payer le Steam Direct fee (100 $ par jeu, récupérable après 1 000 $ de revenus).
3. Attendre la validation (quelques jours), puis créer l'application : on obtient **l'App ID du jeu**.
4. Créer la **démo** depuis la page du jeu (Steamworks › Tous les produits associés › Créer une démo) : elle a **son propre App ID**.

## 2. Mettre l'App ID dans le jeu
Un seul fichier : `godot/data/steam.json` (`app_id` pour le jeu, `demo_app_id` pour la démo, qui a le
sien). Le jeu transmet lui-même l'identifiant à Steam : pas de `steam_appid.txt`. Voir `docs/steam.md`.

## 3. Bibliothèque GodotSteam
- La CI (workflow « Builds ») pose GodotSteam 4.24 dans chaque build Windows et Linux et vérifie
  qu'il se charge : les artefacts sont prêts pour Steam (exe + `libgodotsteam…` + `steam_api64.dll`).
- En local : `tools/steam-fetch.sh` (Git Bash sous Windows), ou l'archive « GDExtension plugin » de
  https://codeberg.org/godotsteam/godotsteam/releases (dossier `addons/godotsteam` dans `godot/addons/`).
- Tester avec ton compte : `docs/steam.md`.

## 4. Réglages Steamworks
- **Succès** : créer les 7 succès de `steam/succes.md` (identifiants exacts), puis « Publier ».
- **Steam Cloud** (Steamworks › Application › Steam Cloud) : activer, quota 20 Mo et 10 fichiers par utilisateur. Le jeu envoie lui-même `partie.json` (sauvegarde) et `settings.cfg` (options) par l'API ; **ne pas** configurer l'Auto-Cloud en plus.
- **Présence enrichie** : déposer `steam/rich_presence.vdf` (Communauté › Présence enrichie). Les amis voient « Dans la région de Ronce », etc.
- **Steam Deck** : remplir le questionnaire de compatibilité. Le jeu grossit le texte par défaut sur le Deck et ouvre le clavier de Steam pour renommer un build (bouton « Renommer » à la manette).
- **Dépôts** (Steamworks › SteamPipe › Dépôts) : un dépôt Windows et un Linux par application (jeu et démo), puis envoyer les builds avec SteamCMD ou l'outil ContentBuilder du SDK.

## 5. Tester
- Avec l'App ID 480, Steam montre le jeu comme « Spacewar » : normal. Les succès BOSS_* n'existent pas dans Spacewar, donc rien ne s'affiche ; ils fonctionneront avec le vrai App ID.
- Tests sans Steam : `tools/unit-tests.sh steam` (faux Steam, pas besoin du client).
