# Steam : tester avec ton compte, et le jour du vrai App ID

Les builds de la CI (workflow « Builds », artefacts `seve-windows`, `seve-windows-demo`, `seve-linux`,
`seve-linux-demo`) embarquent **GodotSteam** : à côté de l'exécutable, `libgodotsteam…` et
`steam_api64.dll` (Windows) ou `libsteam_api.so` (Linux). Steam reste **facultatif** : sans client
Steam, ou si ces fichiers manquent, le jeu tourne exactement pareil.

Pour l'instant le jeu se présente à Steam avec l'App ID de test **480** (« Spacewar », fourni par Valve).

## 1. Tester avec ton compte (5 minutes, Windows)

1. Ouvre la page de la PR ou du dernier passage de « Builds » sur develop, onglet *Checks* › *Builds* ›
   *Artifacts*, et télécharge `seve-windows` (ou `seve-windows-demo`).
2. Dézippe **tout le dossier** (l'exe seul ne suffit pas : la DLL Steam doit rester à côté).
3. Lance Steam et connecte-toi, puis double-clique sur `Seve.exe`.
4. Ce que tu dois voir :
   - dans ta liste d'amis, ton statut « En jeu : Spacewar » (c'est l'App ID 480, normal) ;
   - Maj+Tab ouvre l'overlay Steam par-dessus le jeu.
5. Ce que tu ne verras **pas** encore : les succès BOSS_* et la présence « Dans la région de Ronce ».
   Ils n'existent pas dans Spacewar ; ils apparaîtront avec le vrai App ID, une fois créés sur Steamworks.
   Le Steam Cloud de Spacewar n’est pas garanti non plus : à vérifier avec le vrai App ID.
   Sur le Steam Deck, le jeu se reconnaît à la variable SteamDeck=1 que Steam pose (GodotSteam 4.24
   n’a plus isSteamRunningOnSteamDeck).

Vérifier sans rien lancer à la main : `Seve.exe --headless -- --steam-probe` (dans un terminal) écrit
`STEAM-PROBE bibliotheque=oui statut=actif app_id=480`. Sans Steam ouvert, `statut=refusé : …` : normal.

Si l'overlay ne s'ouvre pas : Steam › Paramètres › En jeu › « Activer l'overlay Steam en jeu ».
Lancé hors de Steam, un jeu n'a parfois pas l'overlay sur certaines machines ; il l'aura une fois
installé depuis Steam.

## 2. Le jour où tu as l'App ID du jeu

Un seul fichier à changer : **`godot/data/steam.json`**.

```json
{
	"app_id": 480,          ← l'App ID du jeu
	"demo_app_id": 480,     ← l'App ID de la démo (Steamworks › Créer une démo : elle a le sien)
	"demo_achievements": ["BOSS_RONCE"]
}
```

Le jeu transmet cet identifiant à Steam lui-même : **pas** de `steam_appid.txt` à poser ni à livrer.

Ensuite, sur Steamworks (détails dans `steam/mise-en-place.md`) :
- **Succès** : les 7 de `steam/succes.md` (identifiants exacts BOSS_RONCE … BOSS_FINALE) dans le
  jeu ; dans la démo, seulement BOSS_RONCE. Puis « Publier ».
- **Steam Cloud** : activer, quota 20 Mo / 10 fichiers. Le jeu envoie lui-même `partie.json` et
  `settings.cfg` par l'API : ne pas configurer l'Auto-Cloud.
- **Présence enrichie** : déposer `steam/rich_presence.vdf`.
- **Dépôts** : un Windows et un Linux par application (jeu, démo) ; envoyer le contenu du dossier
  d'artefact tel quel (exe + bibliothèques).

À tester alors : un succès (battre la Mère-Ronce, ou charger une partie où elle est déjà vaincue :
le succès est rattrapé), la présence chez un ami, la sauvegarde reprise sur un second PC.

## 3. Pour les threads et la CI

- `tools/steam-fetch.sh` pose GodotSteam 4.24 dans `godot/addons/godotsteam` (hors dépôt). Version
  épinglée par URL + SHA-256 dans le script ; `--list` montre les versions publiées sur Codeberg,
  `--remove` revient au jeu sans Steam. Le conteneur des threads ne peut pas le télécharger
  (Codeberg et les versions GitHub sont bloqués) : seule la CI le fait.
- La CI vérifie que la bibliothèque se charge et qu'elle offre toutes les fonctions dont
  `SteamBridge` se sert (`-- --steam-probe`, liste `SteamBridge.API`) : sous Linux dans
  `tools/export-smoke.sh`, sous Windows dans le job `steam windows`.
- Tests sans Steam : `tools/unit-tests.sh steam` (faux Steam, `tests/steam_fake.gd`).
