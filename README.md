# Sève

Action-RPG en vue de dessus dans un monde fantastique désolé. Tu incarnes le Porte-Graine, et la vie revient au fil de ton aventure.
L'élément central du jeu est l'**Arbre de vie**, un arbre de compétences géant d'environ 600 nœuds. Chaque nœud appris renforce le personnage **et ravive la région du monde située dans sa direction** : la carte du monde et l'arbre ne font qu'un.

## Lancer le prototype Godot

1. Installer [Godot 4.3 ou plus récent](https://godotengine.org/download) (version standard, pas .NET).
2. Dans Godot : **Importer**, choisir `godot/project.godot`, puis **F5** pour lancer.

### Commandes

| Action | Clavier / souris |
| --- | --- |
| Se déplacer | Z Q S D (W A S D en QWERTY) ou les flèches par défaut ; autres modes dans les options (**Déplacement**), voir ci-dessous |
| Attaque de base | **Automatique** : part toute seule à sa cadence sur l'ennemi à portée le plus proche du curseur (à défaut, du héros). Options → **Visée** : « Vers le curseur » tire toujours vers la souris, même sans ennemi |
| Compétences principales | Clic gauche et clic droit, lancées vers le curseur (tenir le clic relance la compétence dès qu'elle est prête) |
| Compétences secondaires | A, E, R, F (AZERTY) / Q, E, R, F (QWERTY), et 1 à 4 |
| Esquive | Espace ou Maj (Espace seulement en mode MOBA) |
| Barre de compétences (6 emplacements) | 2 emplacements « souris » puis 4 secondaires ; commandes réassignables dans les options (touche ou bouton de souris). Clic sur un emplacement : y mettre une compétence acquise qui n'a pas de place |
| Arbre de vie | Tab ou T (le jeu se met en pause) |
| Journal des objectifs | J (le jeu se met en pause) |
| Carte du monde | M (le jeu se met en pause) |

L'ennemi visé par l'attaque automatique est marqué au sol par trois arcs à la couleur du héros ; quand des ennemis approchent sans être à portée (600 px), un cercle pointillé discret montre la portée.

**Modes de déplacement** (Options → Déplacement, enregistré avec les autres réglages ; un choix déjà enregistré est gardé) :

- **Clavier** (par défaut) : Z Q S D (W A S D en QWERTY) ou les flèches ; la souris vise les compétences.
- **Suivre le curseur** : le héros marche vers la souris et s'arrête quand elle est tout près de lui (zone morte d'environ 46 px, plein régime 70 px plus loin). Les clics restent des compétences. Il ne suit la souris qu'une fois qu'elle a bougé dans la fenêtre, et s'arrête si elle en sort.
- **Clic droit (MOBA)** : un clic droit fixe une destination, marquée par un repère au sol ; clic droit tenu, la destination suit le curseur. Le héros s'arrête pile sur le point, et abandonne la destination s'il bute (buisson d'épines, mur de l'arène). Un clic droit sur l'interface ne compte pas. Dans ce mode seulement, la compétence du clic droit passe sur une touche (Maj par défaut, réglable), et l'esquive reste sur Espace.

Dans les deux modes à la souris, les touches de direction marchent aussi et prennent la main (elles annulent la destination). L'esquive part vers le curseur, au clavier dans la direction de marche.

Dans l'arbre : clic pour apprendre, clic droit pour oublier, glisser pour se déplacer, molette pour zoomer. Une maîtrise ou une mutation ouvre une fenêtre de choix quand on l'apprend ; un clic sur une maîtrise apprise permet d'en changer. Les greffes trouvées dans le monde (autels cachés du roncier, secret, boss, élites) apparaissent en bas à gauche : glisser une greffe sur un emplacement de greffe (anneau creux) l'y pose, un clic sur l'emplacement la retire. L'arbre s'ouvre en vue d'ensemble ; en zoomant apparaissent tous les nœuds, puis les icônes et les noms des notables.

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

### Mort et sanctuaires

Mourir ne fait jamais perdre l'arbre : les points et les nœuds appris restent. Le Porte-Graine renaît au **dernier sanctuaire** ravivé ou visité, avec toute sa vie, et son **expérience non dépensée reste au sol** là où il est tombé, sous forme de sève perdue (une flèche au bord de l'écran la montre). La toucher rend toute l'expérience ; mourir une seconde fois avant de la reprendre la perd pour de bon. Un court écran de mort dit ce qui est perdu et où le reprendre.

- **Sanctuaires** (`godot/scripts/sanctuary.gd`) : celui de la Graine, ravivé dès le départ, et quatre dans le roncier (Lisière, Ravin, Veille, Épine). On en ravive un en restant trois secondes dans son cercle de pierres ; il devient le point de renaissance et rend toute la vie. Revenir dans un sanctuaire déjà ravivé en refait le point de renaissance et rend aussi toute la vie.
- **Combats remis à zéro** : mourir pendant le siège du Cœur de flétrissure le rendort (siège à recommencer) ; mourir face à la Mère-Ronce la rendort avec toute sa vie, et la sève attend devant l'entrée de l'arène (la reprendre ne relance pas le combat). Une partie quittée en plein combat de boss reprend devant l'arène, vie pleine.
- **Messages à l'écran** : une seule annonce à la fois, dans une file ; pendant le combat de boss et l'écran de mort, les annonces ordinaires (objectifs, points, niveaux) attendent la fin, et le cadre d'objectif, l'aide de départ et le coin d'informations s'effacent. L'aide de départ disparaît dès que le joueur s'est déplacé et a tiré, a appris un nœud, ou qu'un combat commence.
- Tout tient dans `Game.flags` : `sanctuaire_<id>`, `renaissance` (sanctuaire courant), `seve_perdue`, `seve_perdue_x`, `seve_perdue_y`.
- Le robot d'équilibrage n'est pas concerné : il renaît sur place, sans rien perdre.

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
- `TEST_ONLY=heros tools/visual-tests.sh` : galerie du héros (chaque pose et chaque état) et des attaques (la graine et les sept compétences, en trois temps) ; `tools/heros-anim.sh` en fait un GIF animé.
- `tools/godot.sh --headless -s res://tests/skills_test.gd` : teste les compétences de Ronce, le saignement, l'enracinement, les nouveaux évènements et la barre de compétences.
- `tools/godot.sh --xvfb -- --autotest --skills=all` : donne toutes les compétences sans passer par l'arbre (`--skills=fouet,racines,volee,saignee` pour en choisir), pour les essayer ; marche aussi sans `--autotest`.
- `tools/godot.sh --headless -s res://tests/flow_test.gd` : teste le parcours des menus (Nouvelle partie, Retour au titre qui sauvegarde, Continuer qui reprend). Remplace la sauvegarde par défaut.
- `tools/godot.sh --xvfb -- --autotest=boss` : le robot est posé dans l'arène de la Mère-Ronce avec un build de test (niveau 12, points placés dans Ronce) et joue le combat. Le test réussit si le combat se termine, par une victoire ou une défaite, en moins de 3 minutes ; captures de chaque phase dans `godot/autotest/`. Avec `--headless --fixed-fps 60` à la place de `--xvfb`, le combat se joue en quelques secondes, sans captures.
- `tools/godot.sh --headless --fixed-fps 60 -s res://tests/boss_test.gd` : teste le Cœur de flétrissure et la Mère-Ronce (siège et purification, ouverture de l'arène, phases, mort du joueur, victoire, drapeaux sauvegardés).
- `tools/godot.sh --headless --fixed-fps 60 -s res://tests/objectives_test.gd` : teste les objectifs (suite principale, facultatifs et leur point, flèche, journal et carte, fin déclenchée une seule fois, sauvegarde aller-retour).
- `tools/godot.sh --headless --fixed-fps 60 -s res://tests/death_test.gd` : teste la mort et les sanctuaires (sanctuaire ravivé, renaissance, sève laissée au sol, sauvegarde entre la mort et le ramassage, sève reprise ou perdue, siège du Cœur remis à zéro, robot inchangé).
- `tools/godot.sh --headless -s res://tests/region_test.gd` : teste la région du roncier (géométrie, résistance aux dégâts de Ronce, buissons d'épines, vague de vie, apparitions, comportements du Tireur, du Chargeur et du Nid).
- `tools/godot.sh --headless -s res://tests/enemies_test.gd` : teste les ennemis variés et les élites (fuite et tir du Cracheur, protection du Gardien, poche de spores du Boursouflé, tirage par niveau, chaque modificateur d'élite, `main.elite_killed` et butin).
- `tools/balance.sh` : équilibrage. Le robot joue les builds types de Ronce (`godot/data/builds.json` : épines, fouet, saignement) au niveau 20, sur plusieurs graines, sans affichage et en parallèle (moins de 2 minutes), et compare les ennemis vaincus par minute ; échec si l'écart dépasse 30 %. Un seul build : `tools/godot.sh --headless --fixed-fps 60 -- --autotest=build:fouet`.
- `tools/balance.sh --run` : partie complète. Le robot part du niveau 1 avec chaque build, apprend ses nœuds au fil des niveaux, s'enfonce dans le roncier à mesure qu'il progresse (il assiège le Cœur au niveau 15), esquive les épines tirées et les charges, se replie quand sa vie baisse, et note chaque minute son niveau, la menace des ennemis, le temps pour tuer un Flétri, les dégâts reçus et ses morts (journaux dans `godot/autotest/balance-run/`, environ 20 minutes par graine). Échec si un niveau prend plus de deux fois la durée visée, si un build meurt plus de trois fois avant le niveau 20, ou si les builds atteignent le niveau 20 avec plus de 30 % d’écart. Un seul build : `tools/godot.sh --headless --fixed-fps 60 -- --autotest=run:fouet` (`--run-freeze --build-level=12` : niveau figé, pour mesurer l'expérience gagnée par minute à ce niveau).
- `tools/godot.sh --xvfb --fixed-fps 60 --audio-driver Dummy -s res://tests/move_test.gd` : teste les modes de déplacement (suivi du curseur et sa zone morte, tir posté, clic droit et repère, arrivée, obstacle, clic sur l'interface, clavier prioritaire, esquive, sanctuaire ravivé dans chaque mode, option enregistrée et relue, aide de départ).
- `tools/godot.sh --headless -s res://tests/art_test.gd` : teste la charte graphique (`art.gd`, `anim.gd`) : palette et hiérarchie de lecture, éléments distincts aussi pour les daltoniens, icônes, formes d'annonce, courbes d'animation.
- `tools/godot.sh --headless -s res://tests/difficulty_test.gd` : teste la difficulté (menace indépendante du temps, selon le niveau, la zone et les Cœurs purifiés ; plafonds d'apparition ; courbe d'expérience ; Facile / Normal / Difficile).
- `tools/godot.sh --headless --fixed-fps 60 -s res://tests/grafts_test.gd` : teste les points et greffes du monde (points donnés une seule fois par source, inventaire, tirage des élites, pose et retrait, autels et secret, Cœur et boss, effets des greffes, sauvegarde et migration d'une sauvegarde du jalon 3).
- `tools/godot.sh --xvfb -s res://tests/grafts_captures.gd` : captures d'un autel (avant et après), d'une greffe au sol et de l'inventaire de l'arbre dans `godot/tests/visual/out/`.
- `tools/godot.sh --xvfb -s res://tests/ronce_captures.gd` : captures de la branche Ronce et de chacune de ses grappes dans `godot/tests/visual/out/`.
- `tools/zone.sh` : robot « zone complète » (`godot/tests/zone_test.gd`, `scripts/zone_bot.gd`). Sur 5 graines en parallèle, sans affichage (environ 2 minutes), le robot part d'une nouvelle partie et suit l'objectif en cours jusqu'à la Mère-Ronce et la fin de la tranche (il gagne de l'expérience plus vite qu'un joueur). En route : sauvegarde et reprise après chaque objectif principal, en plein siège, en plein combat de boss et avec la sève au sol ; une mort pendant le siège et une face au boss ; une greffe ramassée Arbre ouvert et pendant la fin ; trois changements de résolution. À chaque image il vérifie qu'une seule annonce est visible, jamais sur le cadre d'objectif ni sur une barre de combat, que rien ne passe sur l'écran de mort ni sur la fin, et que pendant le boss seules les informations du combat restent. Échoue sur une erreur de script, un blocage, un état incohérent (cadre, journal, Cœur, arène, autels, sanctuaires, sève) ou une reprise qui ne retrouve pas la partie. Une graine : `SEEDS=3 tools/zone.sh` ; journaux dans `godot/autotest/zone/`.
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
| `galerie` | `galerie_ennemis_fx` (3 ennemis × 6 états dont saignant et enraciné, ondes, textes flottants, nuage), `galerie_roncier` (4 ennemis du roncier × 4 états dont l'attaque annoncée, épine tirée, ronces et buissons morts et vivants), `galerie_varies` (Cracheur de cendre et Boursouflé dans leurs états, boule de cendre, poche de spores, Gardien d'écorce et ses protégés, une élite par modificateur et une à deux modificateurs), `galerie_noeuds` (nœud verrouillé, disponible, appris, survolé, clé, notable), `galerie_types` (compétence, mutation, maîtrise, nœud flétri, greffe, avant et après), `arbre_grappe` (grappe et infobulle d'une maîtrise) et `arbre_choix` (fenêtre de choix d'une mutation) |
| `roncier` | `roncier_mort`, `roncier_vague_1` à `_3` (la vague de vie avance), `roncier_ravive`, `roncier_purifie` (drapeau `ronce_coeur_purifie`), puis `sanctuaire_reprise` (sanctuaire à moitié ravivé), `sanctuaire_ravive`, `mort_ecran` (écran de mort et flèche vers la sève) et `seve_perdue` |
| `resolution` | `jeu_`, `arbre_` et `titre_` en 1280x720, 1920x1080, 2560x1440 et 3440x1440 (un processus par résolution) |
| `charte` | `charte` en 2560x1440 : la planche de la charte graphique (palette, éléments et leur rendu pour trois daltonismes, icônes, annonces de danger, silhouettes par rôle, règle d'une action), voir `docs/charte-graphique.md` |
| `quetes` | Le journal (`journal_`), la carte (`carte_`) et la fin de la tranche (`fin_`) en 1280x720, 1920x1080, 2560x1440 et 3440x1440 ; en 1920x1080 aussi `jeu_objectif` (suivi et flèche vers le Cœur) et `fin_arbre` (l'Arbre en train de fleurir) |

- `tools/visual-tests.sh` : compare. Échoue si plus de 0,05 % des pixels d'une capture ont changé, ou si un défaut d'interface nouveau est détecté. Résultats, écarts en rouge (`*.diff.png`), `rapport.html` et `resume.md` dans `godot/tests/visual/out/`.
- `tools/visual-tests.sh --update` : remplace les références après un changement graphique voulu. Vérifier les nouvelles images, puis les committer avec le changement.
- `TEST_ONLY=galerie tools/visual-tests.sh` : ne joue qu'un scénario.

**Contrôles sans image (`UiAudit`).** L'autoload `ui_audit.gd` est un registre où les écrans déclarent les rectangles de texte qu'ils dessinent : `UiAudit.draw_text(...)` à la place de `draw_string` pour un écran dessiné à la main (voir `tree_ui.gd`), ou `UiAudit.scan_controls("écran", racine)` pour des nœuds Control (Label, Button…). Le banc vérifie qu'aucun texte n'est coupé par le bord de l'écran, qu'aucun texte « requis » (noms des branches, en-têtes) n'est hors écran, et qu'aucun libellé n'en recouvre un autre. Hors tests le registre est inactif. Les défauts déjà présents sont listés dans `godot/tests/visual/defauts_connus.txt` : un défaut qui n'y figure pas fait échouer le banc, un défaut listé qui a disparu est signalé « CORRIGÉ » (retirer alors la ligne). Pas encore couvert : le HUD dessiné à la main (`hud.gd`) et l'écran titre dessiné ; la tâche C les branchera.

La CI (workflow « Tests visuels ») lance le tout sur chaque pull request, écrit le résultat dans le résumé du job et publie captures et rapport en artefact. Les scénarios sont dans `godot/tests/visual/runner.gd`.

## Ce que contient le prototype

- **Arbre de vie** : 6 branches (Ronce, Spore, Sève, Vent, Aube, Racine), environ 600 nœuds, des nœuds notables et 18 nœuds clés qui changent les règles ou donnent des compétences (Couronne d'épines, Nuage de spores, Floraison).
- **Le monde reprend vie** : le sol passe de la cendre craquelée à la prairie, les arbres morts reverdissent et des fleurs éclosent. Trois sources de vie : les nœuds de l'arbre, chaque Flétri purifié et la compétence Floraison.
- **La vie a un effet en jeu** : sur l'herbe, ta régénération est triplée, les Flétris ralentissent et ils naissent plutôt en terre morte.
- **Ennemis** : Flétris, Cendreux (rapides) et Colosses (massifs), puis, à mesure que tu montes de niveau, le Cracheur de cendre (fuit et crache un éventail de braises annoncé), le Gardien d'écorce (protège les ennemis autour de lui : à abattre en premier) et le Boursouflé (laisse en mourant une poche de spores qui éclate après une annonce au sol, et blesse aussi les Flétris voisins). Leur menace suit ton niveau, la profondeur de l'endroit où ils naissent dans une région et les Cœurs purifiés, jamais le temps passé : calmes près de la graine, nombreux et coriaces au fond du roncier (`godot/data/difficulty.json`).
- **Élites** : à partir du niveau 3, un ennemi rare reçoit un ou deux modificateurs (rapide, enragé, cuirassé d'écorce, épineux, invocateur), un liseré doré, son nom au-dessus de lui, plus de vie, et laisse une gerbe d'essences et parfois une greffe.
- **Difficulté** : Facile, Normal (par défaut) ou Difficile, dans les options : multiplie la vie et les dégâts des ennemis et de la Mère-Ronce. La courbe d'expérience vise une durée par niveau à peu près constante (1 minute au début, puis 2,5 minutes à partir du niveau 7) ; une essence de vie oubliée finit par rejoindre le joueur.
- **Région de Ronce** : au nord-est de la graine, un Cœur de flétrissure fait naître des Flétris. Tenir la zone qui l'entoure pendant 30 s, sous des vagues d'ennemis, le purifie : une grande vague de vie se répand et l'arène voisine s'ouvre. La Mère-Ronce y attend : trois phases, des attaques toujours annoncées au sol (volée d'épines, fouets, racines, invocation, arène qui rétrécit), 2 points d'arbre et une greffe à la clé. Mourir face à elle ramène à la graine, le Cœur reste purifié.
- **Le roncier** (région de Ronce, au nord-est, dans la direction de la branche Ronce de l'arbre) : sol rouillé, ronces mortes qui fleurissent quand la terre revit, buissons d'épines qui bloquent le passage (et arrêtent les charges). Ses ennemis : le Tireur d'épines (garde ses distances, vise avant de tirer), le Chargeur (marque son couloir au sol avant de charger) et le Nid de ronces (immobile, fait naître des Rejetons). Ils ignorent 25 % des dégâts de Ronce et sont plus nombreux loin de la graine.
- **Objectifs, journal, carte et fin** : en haut à droite, l'objectif en cours et, quand la cible est loin, une flèche dorée au bord de l'écran. **J** ouvre le journal (6 objectifs principaux, du premier nœud à la Mère-Ronce, et 3 facultatifs : trois élites, tous les autels, le secret du roncier), **M** la carte (terre ravivée, région de Ronce, sanctuaires, autels découverts, Cœur, arène, objectif). Une fois la Mère-Ronce vaincue, quelques secondes plus tard, le monde reverdit : texte de fin, statistiques de la partie, puis « Continuer à jouer » ou « Retour au titre ». La fin ne se montre qu'une fois par partie.
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
  - `objectives.gd` (autoload `Objectives`) et `data/objectives.json` : les objectifs de la tranche. Aucun état propre : tout est dans `Game.flags` (`obj_<id>`, `elites_tuees`, `stat_morts`, `fin_ronce_vue`), donc dans la sauvegarde. `quest_ui.gd` assemble le suivi et la flèche (`objective_tracker.gd`), le journal (`journal.gd`), la carte (`world_map.gd`) et la fin (`ending.gd`). `Objectives.complete("<id>")` accomplit un objectif à la main ; les autres systèmes n'ont rien d'autre à faire que de poser leurs drapeaux (voir `data/README.md`, « Objectifs »).
  - `regions.gd` : les régions du monde (secteur de chaque branche) ; `main.region_at(pos)` et `main.region_center(id)`.
  - `enemy.gd`, `enemy_thorn.gd`, `enemy_blast.gd` : comportements des ennemis et des élites (sortes et modificateurs décrits dans `data/enemies.json`), épine ou boule de cendre tirée, poche de spores du Boursouflé. `main.elite_killed(enemy)` est émis à la mort d'une élite.
  - `spatial_grid.gd` : grille spatiale des Flétris (collisions, séparation, zones de dégâts), via `main.enemies_near()`.
  - `ground.gd` + `shaders/ground.gdshader` : la carte de vie et le rendu du sol (bruit précalculé en texture, même rendu sur toutes les cartes graphiques).
  - `art.gd`, `anim.gd` : la charte graphique en code (palette par rôle, éléments, traits, ombres, icônes, annonces de danger, petites animations). Toute couleur ou durée vient de là ; l'intention est dans [`docs/charte-graphique.md`](docs/charte-graphique.md).
  - `flora.gd`, `fx.gd`, `hud.gd`, `tree_ui.gd` : décor, effets et interface.
  - `sfx.gd`, `music.gd`, `synth.gd` : le son (voir « Son et musique »).
  - `tree_planner.gd`, `tree_panels.gd` : outils de planification de l'arbre (logique pure, puis interface).
- `godot/data/` : ce que font les nœuds (statistiques, branches, nœuds clés, compétences), en fichiers JSON. Le format est décrit dans [`godot/data/README.md`](godot/data/README.md).
- `prototype-web/` : le premier prototype (jeu incrémental dans le navigateur), conservé pour référence.
