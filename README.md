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
| Compétences débloquées par l'arbre | A, E, R (AZERTY) / Q, E, R (QWERTY) |
| Arbre de vie | Tab ou T (le jeu se met en pause) |

Dans l'arbre : clic pour apprendre, clic droit pour oublier, glisser pour se déplacer, molette pour zoomer.

### Tester sans écran (Linux, sessions Claude)

`tools/godot.sh` télécharge Godot 4.3 une fois puis le lance sur le projet :

- `tools/godot.sh --headless --editor --quit` : importe le projet et affiche les erreurs de script.
- `tools/godot.sh --xvfb -- --autotest` : un robot joue une minute, apprend des nœuds et enregistre des captures dans `godot/autotest/`.

La règle dans `.claude/settings.json` autorise ce script pour les sessions Claude.

### Tests visuels

`tools/visual-tests.sh` rejoue deux parties à l'identique (graine fixe, pas de temps fixe, rendu logiciel) et compare six captures du jeu et de l'Arbre de vie aux images de référence de `godot/tests/visual/reference/` :

| Capture | Ce qu'elle montre |
| --- | --- |
| `jeu_depart` | le jeu après 1 s : oasis de départ, joueur, interface |
| `jeu_combat` | le jeu après 30 s de partie jouée par le robot : Flétris, sol ravivé, fleurs |
| `arbre_depart` | l'arbre ouvert en début de partie |
| `arbre_survol` | l'infobulle d'un nœud survolé |
| `arbre_ensemble` | l'arbre entier dézoomé |
| `arbre_progression` | l'arbre après 30 s, avec des nœuds appris |

- `tools/visual-tests.sh` : compare. Échoue si plus de 0,05 % des pixels d'une capture ont changé. Les captures, les écarts en rouge (`*.diff.png`) et `rapport.html` sont dans `godot/tests/visual/out/`.
- `tools/visual-tests.sh --update` : remplace les références après un changement graphique voulu. Vérifier les nouvelles images, puis les committer avec le changement.

La CI (GitHub Actions, workflow « Tests visuels ») lance la comparaison sur chaque pull request et publie les captures et le rapport en artefact. Les scénarios sont dans `godot/tests/visual/runner.gd`.

## Ce que contient le prototype

- **Arbre de vie** : 6 branches (Ronce, Spore, Sève, Vent, Aube, Racine), environ 600 nœuds, des nœuds notables et 18 nœuds clés qui changent les règles ou donnent des compétences (Couronne d'épines, Nuage de spores, Floraison).
- **Le monde reprend vie** : le sol passe de la cendre craquelée à la prairie, les arbres morts reverdissent et des fleurs éclosent. Trois sources de vie : les nœuds de l'arbre, chaque Flétri purifié et la compétence Floraison.
- **La vie a un effet en jeu** : sur l'herbe, ta régénération est triplée, les Flétris ralentissent et ils naissent plutôt en terre morte.
- **Ennemis** : Flétris, Cendreux (rapides) et Colosses (massifs), de plus en plus forts avec ton niveau et le temps.
- **Progression** : chaque Flétri laisse une essence de vie, et chaque niveau donne un point d'arbre.

## Structure

- `godot/` : le jeu (Godot 4, GDScript). Les scènes sont construites par le code, dans `godot/scripts/`.
  - `skill_tree.gd` : génération de l'arbre, effets et nœuds clés.
  - `game.gd` : état global (niveau, points, statistiques).
  - `main.gd`, `player.gd`, `enemy.gd`, `projectile.gd`, `orb.gd` : le jeu.
  - `ground.gd` + `shaders/ground.gdshader` : la carte de vie et le rendu du sol.
  - `flora.gd`, `fx.gd`, `hud.gd`, `tree_ui.gd` : décor, effets et interface.
- `prototype-web/` : le premier prototype (jeu incrémental dans le navigateur), conservé pour référence.
