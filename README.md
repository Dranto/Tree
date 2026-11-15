# Sève

Action-RPG en vue de dessus dans un monde fantastique désolé. Tu incarnes le Porte-Graine, et la vie revient au fil de ton aventure.
L'élément central du jeu est l'**Arbre de vie**, un arbre de compétences géant d'environ 600 nœuds. Chaque nœud appris renforce le personnage **et ravive la région du monde située dans sa direction** : la carte du monde et l'arbre ne font qu'un.

## Lancer le prototype Godot

1. Installer [Godot 4.3 ou plus récent](https://godotengine.org/download) (version standard, pas .NET).
2. Dans Godot : **Importer**, choisir `godot/project.godot`, puis **F5** pour lancer.

### Commandes

| Action | Clavier / souris |
| --- | --- |
| Se déplacer | Z Q S D (AZERTY) ou W A S D (QWERTY), ou flèches |
| Lancer des graines | Clic gauche maintenu (vise la souris) |
| Esquive | Espace ou Maj |
| Barre de compétences (6 emplacements) | 1 à 6, et A, E, R (AZERTY) / Q, E, R (QWERTY) pour les trois premiers ; touches réassignables dans les options. Clic sur un emplacement : y mettre une compétence acquise qui n'a pas de place |
| Arbre de vie | Tab ou T (le jeu se met en pause) |

Dans l'arbre : clic pour apprendre, clic droit pour oublier, glisser pour se déplacer, molette pour zoomer. Une maîtrise ou une mutation ouvre une fenêtre de choix quand on l'apprend ; un clic sur une maîtrise apprise permet d'en changer. L'arbre s'ouvre en vue d'ensemble ; en zoomant apparaissent tous les nœuds, puis les icônes et les noms des notables.

Outils de l'arbre (barre sous l'en-tête) :

- **Recherche** (Ctrl+F) : un mot du nom, d'une statistique ou d'un effet. Les nœuds trouvés sont entourés, Entrée passe au suivant.
- **Chemin** : survoler un nœud éloigné montre le chemin le plus court, son coût et les statistiques avant → après. Un clic apprend tout le chemin si les points suffisent.
- **Mode plan** : tracer un chemin sans dépenser de points, puis « Valider le plan » quand les points sont là. Le plan est sauvegardé avec la partie.
- **Annuler** (Ctrl+Z) : défait le dernier choix (nœud appris, oublié, ou modification du plan).
- **Résumé** : statistiques finales, compétences, nœuds clés et nombre de nœuds par branche, plan compris.

### Son et musique

Rien n'est enregistré : tous les sons sont **calculés par le code** (`godot/scripts/synth.gd`, synthèse façon sfxr : oscillateurs, glissandos, bruit filtré, enveloppes) et écrits en `.wav` dans `godot/assets/sounds/` et `godot/assets/music/` par `tools/gen-sounds.sh`. Pas d'échantillon externe, donc aucune licence à créditer. Pour changer un son, modifier son réglage dans `synth.gd` (tableau `SOUNDS`), relancer `tools/gen-sounds.sh` et commiter les `.wav` (le test `sound_test.gd` échoue si les `.wav` ne correspondent plus au code).

- **Bruitages** (`Sfx.play("nom", position)`, autoload `sfx.gd`) : tir, impact, critique, mort, nœud appris, niveau, esquive, dégâts reçus, nova, nuage, floraison, clics et survol des menus. Déjà prêts pour la suite, à brancher quand les compétences et le boss arriveront : `fouet`, `racines`, `volee`, `saignee`, `annonce` (attaque annoncée du boss), `coeur` (Cœur purifié). Au plus 3 sons identiques par 50 ms, hauteur variée de ±6 %, volume atténué avec la distance au joueur.
- **Musique** (`Music.set_mood(vie)`, autoload `music.gd`) : deux couches de 12 s jouées ensemble en boucle, l'une sombre (accords mineurs, vent), l'autre lumineuse (accords majeurs, arpèges). Le jeu appelle `set_mood` à chaque pas avec la vie du sol sous le joueur ; le fondu entre couches dure environ 2 s.
- **Options** : volume général, musique et effets (bus `Musique` et `Effets`, créés au démarrage).
- **En test** : sans écran, dans le banc visuel (graine fixe) ou avec `-- --silent`, plus rien n'est joué.

### Sauvegarde

Le jeu s'ouvre sur l'écran titre : **Continuer** reprend la partie sauvegardée, **Nouvelle partie** repart de zéro (la sauvegarde précédente est remplacée dès la première sauvegarde automatique, l'avant-dernière reste en `.bak`). La partie se sauvegarde toute seule : montée de niveau, nœud appris ou oublié, toutes les 60 s, en revenant au titre et en quittant.
Le fichier est un JSON lisible dans le dossier de données de Godot (`user://saves/partie.json`, sous Windows `%APPDATA%\Godot\app_userdata\Sève\saves\`), avec la sauvegarde précédente en `.bak`.

### Tester sans écran (Linux, sessions Claude)

`tools/godot.sh` télécharge Godot 4.3 une fois puis le lance sur le projet :

- `tools/godot.sh --headless --editor --quit` : importe le projet et affiche les erreurs de script.
- `tools/godot.sh --headless -s res://scripts/check_data.gd` : vérifie les fichiers de données de l'arbre.
- `tools/godot.sh --xvfb -- --autotest` : un robot joue une minute, apprend des nœuds et enregistre des captures dans `godot/autotest/` (sans lire ni écrire de sauvegarde).
- `tools/godot.sh --headless -s res://tests/save_test.gd -- --new-game` : teste la sauvegarde (aller-retour, nœuds disparus, formats anciens ou trop récents).
- `tools/godot.sh --xvfb -s res://tests/tree_ui_test.gd` : vérifie la lisibilité de l'Arbre de vie à la résolution choisie (`--resolution 1280x720` avant `-s`) : aucun libellé hors de l'écran ni sur un autre, les six branches visibles à l'ouverture, infobulle dans l'écran. `-- --shots=DOSSIER` enregistre les captures.
- `tools/godot.sh --xvfb -s res://tests/tree_bench.gd` : mesure le temps par image de l'écran de l'arbre (immobile, survol, déplacement et zoom).
- `tools/godot.sh --headless -s res://tests/sound_test.gd` : teste le son (synthèse, boucle de musique, `.wav` à jour, limite de sons identiques, mélange selon la vie du sol, volumes).
- `tools/godot.sh --headless -s res://tests/planner_test.gd` : teste les outils de l'arbre (plus court chemin, simulation sans effet de bord, annulation, recherche, plan sauvegardé et rechargé).
- `tools/godot.sh --xvfb -s res://tests/planner_captures.gd` : enregistre une capture de chaque outil de l'arbre dans `godot/tests/visual/out/`.
- `tools/godot.sh --headless -s res://tests/node_types_test.gd` : teste les grappes écrites à la main et les types de nœuds (compétence, maîtrise, mutation, nœud flétri, greffe, exclusion, grappe complète, résonance, sauvegarde et migration de la version 1).
- `tools/godot.sh --headless -s res://tests/skills_test.gd` : teste les compétences de Ronce, le saignement, l'enracinement, les nouveaux évènements et la barre de compétences.
- `tools/godot.sh --xvfb -- --autotest --skills=all` : donne toutes les compétences sans passer par l'arbre (`--skills=fouet,racines,volee,saignee` pour en choisir), pour les essayer ; marche aussi sans `--autotest`.
- `tools/godot.sh --headless -s res://tests/flow_test.gd` : teste le parcours des menus (Nouvelle partie, Retour au titre qui sauvegarde, Continuer qui reprend). Remplace la sauvegarde par défaut.
- `tools/godot.sh --xvfb -- --autotest=boss` : le robot est posé dans l'arène de la Mère-Ronce avec un build de test (niveau 12, points placés dans Ronce) et joue le combat. Le test réussit si le combat se termine, par une victoire ou une défaite, en moins de 3 minutes ; captures de chaque phase dans `godot/autotest/`. Avec `--headless --fixed-fps 60` à la place de `--xvfb`, le combat se joue en quelques secondes, sans captures.
- `tools/godot.sh --headless --fixed-fps 60 -s res://tests/boss_test.gd` : teste le Cœur de flétrissure et la Mère-Ronce (siège et purification, ouverture de l'arène, phases, mort du joueur, victoire, drapeaux sauvegardés).
- `tools/godot.sh --headless -s res://tests/region_test.gd` : teste la région du roncier (géométrie, résistance aux dégâts de Ronce, buissons d'épines, vague de vie, apparitions, comportements du Tireur, du Chargeur et du Nid).
- `tools/balance.sh` : équilibrage. Le robot joue les builds types de Ronce (`godot/data/builds.json` : épines, fouet, saignement) depuis le niveau 20, sur plusieurs graines, et compare les ennemis vaincus par minute ; échec si l'écart dépasse 30 %. Un seul build : `tools/godot.sh --xvfb -- --autotest=build:fouet --build-time=180`.
- `tools/godot.sh --xvfb -s res://tests/ronce_captures.gd` : captures de la branche Ronce et de chacune de ses grappes dans `godot/tests/visual/out/`.
- `tools/godot.sh --xvfb -- --benchmark` : banc de performance. Le robot joue face à 120 Flétris pendant 30 s, puis le temps moyen, le 99e centile et le pire temps par image s'affichent.

La règle dans `.claude/settings.json` autorise ce script pour les sessions Claude.

### Tests visuels

`tools/visual-tests.sh` rejoue des parties à l'identique (graine fixe, pas de temps fixe, rendu logiciel), compare les captures aux images de `godot/tests/visual/reference/` et fait des contrôles sans image. Une exécution complète dure environ 2 minutes (limite en CI : 5).

| Scénario | Captures |
| --- | --- |
| `depart` | `jeu_depart`, `arbre_depart`, `arbre_survol`, `arbre_ensemble` (zoom 0,15), `arbre_zoom_proche` (zoom 1,6) ; l'arbre ouvert (`arbre_depart`) montre le zoom par défaut |
| `combat` | `jeu_combat` après 30 s de partie jouée par le robot, `arbre_progression` |
| `competences` | `competences` : racines, fouet et volée d'épines de Ronce en action, barre de compétences (4 emplacements pleins, 2 verrouillés) |
| `boss` | Le Cœur de flétrissure (`coeur_fletri`, `coeur_siege`, `coeur_purifie`), l'arène (`arene_ouverte`, `boss_vaincu`) et la Mère-Ronce dans chaque phase et chaque attaque annoncée (`boss_volee`, `boss_racines`, `boss_fouets`, `boss_fouets_frappe`, `boss_invocation`, `boss_phase3`) |
| `galerie` | `galerie_ennemis_fx` (3 ennemis × 6 états dont saignant et enraciné, ondes, textes flottants, nuage), `galerie_roncier` (4 ennemis du roncier × 4 états dont l'attaque annoncée, épine tirée, ronces et buissons morts et vivants), `galerie_noeuds` (nœud verrouillé, disponible, appris, survolé, clé, notable), `galerie_types` (compétence, mutation, maîtrise, nœud flétri, greffe, avant et après), `arbre_grappe` (grappe et infobulle d'une maîtrise) et `arbre_choix` (fenêtre de choix d'une mutation) |
| `roncier` | `roncier_mort`, `roncier_vague_1` à `_3` (la vague de vie avance), `roncier_ravive`, `roncier_purifie` (drapeau `ronce_coeur_purifie`) |
| `resolution` | `jeu_`, `arbre_` et `titre_` en 1280x720, 1920x1080, 2560x1440 et 3440x1440 (un processus par résolution) |

- `tools/visual-tests.sh` : compare. Échoue si plus de 0,05 % des pixels d'une capture ont changé, ou si un défaut d'interface nouveau est détecté. Résultats, écarts en rouge (`*.diff.png`), `rapport.html` et `resume.md` dans `godot/tests/visual/out/`.
- `tools/visual-tests.sh --update` : remplace les références après un changement graphique voulu. Vérifier les nouvelles images, puis les committer avec le changement.
- `TEST_ONLY=galerie tools/visual-tests.sh` : ne joue qu'un scénario.

**Contrôles sans image (`UiAudit`).** L'autoload `ui_audit.gd` est un registre où les écrans déclarent les rectangles de texte qu'ils dessinent : `UiAudit.draw_text(...)` à la place de `draw_string` pour un écran dessiné à la main (voir `tree_ui.gd`), ou `UiAudit.scan_controls("écran", racine)` pour des nœuds Control (Label, Button…). Le banc vérifie qu'aucun texte n'est coupé par le bord de l'écran, qu'aucun texte « requis » (noms des branches, en-têtes) n'est hors écran, et qu'aucun libellé n'en recouvre un autre. Hors tests le registre est inactif. Les défauts déjà présents sont listés dans `godot/tests/visual/defauts_connus.txt` : un défaut qui n'y figure pas fait échouer le banc, un défaut listé qui a disparu est signalé « CORRIGÉ » (retirer alors la ligne). Pas encore couvert : le HUD dessiné à la main (`hud.gd`) et l'écran titre dessiné ; la tâche C les branchera.

La CI (workflow « Tests visuels ») lance le tout sur chaque pull request, écrit le résultat dans le résumé du job et publie captures et rapport en artefact. Les scénarios sont dans `godot/tests/visual/runner.gd`.

## Ce que contient le prototype

- **Arbre de vie** : 6 branches (Ronce, Spore, Sève, Vent, Aube, Racine), environ 600 nœuds, des nœuds notables et 18 nœuds clés qui changent les règles ou donnent des compétences (Couronne d'épines, Nuage de spores, Floraison).
- **Le monde reprend vie** : le sol passe de la cendre craquelée à la prairie, les arbres morts reverdissent et des fleurs éclosent. Trois sources de vie : les nœuds de l'arbre, chaque Flétri purifié et la compétence Floraison.
- **La vie a un effet en jeu** : sur l'herbe, ta régénération est triplée, les Flétris ralentissent et ils naissent plutôt en terre morte.
- **Ennemis** : Flétris, Cendreux (rapides) et Colosses (massifs), de plus en plus forts avec ton niveau et le temps.
- **Région de Ronce** : au nord-est de la graine, un Cœur de flétrissure fait naître des Flétris. Tenir la zone qui l'entoure pendant 30 s, sous des vagues d'ennemis, le purifie : une grande vague de vie se répand et l'arène voisine s'ouvre. La Mère-Ronce y attend : trois phases, des attaques toujours annoncées au sol (volée d'épines, fouets, racines, invocation, arène qui rétrécit), 3 points d'arbre à la clé. Mourir face à elle ramène à la graine, le Cœur reste purifié.
- **Le roncier** (région de Ronce, au nord-est, dans la direction de la branche Ronce de l'arbre) : sol rouillé, ronces mortes qui fleurissent quand la terre revit, buissons d'épines qui bloquent le passage (et arrêtent les charges). Ses ennemis : le Tireur d'épines (garde ses distances, vise avant de tirer), le Chargeur (marque son couloir au sol avant de charger) et le Nid de ronces (immobile, fait naître des Rejetons). Ils ignorent 25 % des dégâts de Ronce et sont plus nombreux loin de la graine.
- **Vague de vie** : un nœud appris ravive sa région en vague (environ 1,75 s) ; arbres et ronces se couvrent de feuilles au passage.
- **Progression** : chaque Flétri laisse une essence de vie, et chaque niveau donne un point d'arbre.

## Structure

- `godot/` : le jeu (Godot 4, GDScript). Les scènes sont construites par le code, dans `godot/scripts/`.
  - `skill_tree.gd` : génération de la forme de l'arbre, puis insertion des grappes écrites à la main.
  - `content.gd`, `effects.gd`, `effect_actions.gd` : lecture des données et moteur d'effets des nœuds.
  - `game.gd` : état global (niveau, points, statistiques, drapeaux d'aventure).
  - `save_game.gd` : sauvegarde versionnée (format 2 : choix des maîtrises et mutations, greffes posées). Les nœuds y sont notés par identifiant stable (`uid`), pour qu'une sauvegarde survive aux changements de l'arbre.
  - `main.gd`, `player.gd`, `enemy.gd`, `projectile.gd`, `orb.gd` : le jeu. La logique avance à pas fixe (`_physics_process`, 60 pas par seconde) et l'affichage est interpolé entre deux pas ; l'animation pure reste dans `_process`.
  - `heart.gd`, `boss_arena.gd`, `boss.gd`, `boss_bar.gd` : le Cœur de flétrissure, l'arène et la Mère-Ronce, boss de la région de Ronce, avec leur barre en haut de l'écran. Ils posent `Game.flags["ronce_coeur_purifie"]` et `Game.flags["ronce_boss_vaincu"]`.
  - `regions.gd` : les régions du monde (secteur de chaque branche) ; `main.region_at(pos)` et `main.region_center(id)`.
  - `enemy.gd`, `enemy_thorn.gd` : comportements des ennemis (sortes décrites dans `data/enemies.json`) et épine tirée.
  - `spatial_grid.gd` : grille spatiale des Flétris (collisions, séparation, zones de dégâts), via `main.enemies_near()`.
  - `ground.gd` + `shaders/ground.gdshader` : la carte de vie et le rendu du sol (bruit précalculé en texture, même rendu sur toutes les cartes graphiques).
  - `flora.gd`, `fx.gd`, `hud.gd`, `tree_ui.gd` : décor, effets et interface.
  - `sfx.gd`, `music.gd`, `synth.gd` : le son (voir « Son et musique »).
  - `tree_planner.gd`, `tree_panels.gd` : outils de planification de l'arbre (logique pure, puis interface).
- `godot/data/` : ce que font les nœuds (statistiques, branches, nœuds clés, compétences), en fichiers JSON. Le format est décrit dans [`godot/data/README.md`](godot/data/README.md).
- `prototype-web/` : le premier prototype (jeu incrémental dans le navigateur), conservé pour référence.
