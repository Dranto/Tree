# Liste de test Windows — Arborescence 0.13.0

Environ 30 minutes pour la démo, puis le jeu complet aussi longtemps que tu veux.
Note chaque souci avec l'heure et ce que tu faisais ; une capture (Win+Maj+S) aide beaucoup.

## 0. Télécharger (2 min)

Artefacts du build 0.13.0 : ARTEFACTS_LIEN

- `arborescence-windows-demo` : la démo (Ronce seule).
- `arborescence-windows` : le jeu complet.

Dézippe **tout le dossier** de chaque artefact (l'exe a besoin des fichiers Steam à côté).
Si Windows SmartScreen bloque : « Informations complémentaires » › « Exécuter quand même » (le jeu n'est pas signé).

## 1. Démo (~30 min) — `Arborescence-demo.exe`

Lance Steam avant, pour tester aussi Steam en même temps.

- [ ] Le jeu démarre, écran titre Herbier, pas de fenêtre noire ni d'erreur.
- [ ] Steam : ton statut affiche « En jeu : Spacewar » (App ID de test, normal) ; Maj+Tab ouvre l'overlay.
- [ ] Options : plein écran / fenêtré, volume, langue FR puis EN puis FR ; les textes restent lisibles.
- [ ] Nouvelle partie : les premiers pas guident sans écran de texte (glyphes discrets).
- [ ] Combat à la souris, puis à la manette si tu en as une (menus et arbre compris).
- [ ] Monter de niveau, ouvrir l'arbre, prendre une greffe ; l'écran de greffe s'affiche bien.
- [ ] Changer de zone : écran de chargement court, **pas de gel**.
- [ ] Siège du Cœur de Ronce, puis la Mère-Ronce. **À surveiller** : avec un build Épines pur, le siège
      est très dur (écart d'équilibrage connu, pas un bug). Dis-moi si tu y meurs beaucoup.
- [ ] Purification : le bord de la carte reverdit, pas de saccade.
- [ ] Fin de la démo au sceau de la graine ; le reste de l'arbre reste illisible sous la ronce.
- [ ] Quitter en pleine partie, relancer, « Continuer » : la partie reprend au même endroit.
- [ ] Fluidité générale : note les endroits qui saccadent (surtout siège du Cœur et boss).

## 2. Jeu complet — `Arborescence.exe`

- [ ] La sauvegarde de la démo est-elle reprise ? (même dossier de sauvegarde ; dis-moi ce que tu vois).
- [ ] Nouvelle partie, puis au moins une autre région que Ronce (Spore, Vent, Sève, Aube ou Racine).
- [ ] Un boss d'une autre région et son arène.
- [ ] Builds multiples : changer de build au sanctuaire (gratuit), oublier un nœud (payant hors anneaux 1-3).
- [ ] Si tu vas loin : la finale (la Flétrissure grandit à chaque phase, combat sur le breakcore) puis le générique dans l'herbe.
- [ ] **À surveiller** : build Saignement au siège du Cœur d'Aube (écart d'équilibrage connu).

## 3. Steam en détail (5 min, facultatif)

Voir `docs/steam.md`, partie 1. Vérification rapide, Steam ouvert, dans PowerShell depuis le dossier dézippé :

```
.\Arborescence.exe --headless --log-file steam.txt -- --steam-probe
type steam.txt
```

On doit lire `STEAM-PROBE bibliotheque=oui statut=actif app_id=480` et `fonctions manquantes : aucune`.

## Ce qui n'est pas encore à juger

- Le son : ta passe viendra plus tard.
- L'équilibrage : réglé à la toute fin (note juste ce qui te paraît trop dur ou trop facile).
- Succès Steam, présence enrichie, Cloud : seulement avec le vrai App ID.
