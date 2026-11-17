# Performances

Le jeu doit rester fluide en **rendu logiciel** (llvmpipe), la machine des tests et de la CI. Ce qui
tient là tient partout. Ce document donne le budget de chaque poste, les règles à suivre pour tout
nouvel objet animé, et la façon de mesurer.

## Le banc de jeu

`tools/godot.sh --xvfb -- --benchmark` : le robot joue face à **120 Flétris** pendant 30 s
(fenêtre 1600x900), puis affiche :

- le temps moyen par image, le 99e centile et le pire ;
- le découpage de chaque image : **scripts et dessins** (de `process_frame` au début du rendu, ce
  qui comprend tous les `_process` et `_draw`) et **rendu** (le travail du serveur de rendu et de
  llvmpipe) ;
- le nombre d'appels de rendu et d'objets de la dernière image.

Le moniteur `_process` de Godot (`Performance.TIME_PROCESS`), aussi affiché, compte le rendu : il
est toujours plus grand que les scripts seuls. Pour le coût des scripts, lire le découpage.

Options :

| Option | Effet |
| --- | --- |
| `--bench-time=S` | durée de la mesure (30 s par défaut) |
| `--hide=sol,ennemis,…` | cache des calques : la différence de temps donne leur coût. Calques : `sol`, `decor`, `fleurs`, `ennemis`, `joueur`, `acteurs`, `effets`, `ambiance`, `hud`, `monde` |
| `--profile` | temps de chaque `_process`, `_physics_process` et `_draw`, à lancer par `tools/perf-profile.sh` |

`tools/perf-profile.sh` copie le projet dans un dossier temporaire, y enveloppe chaque fonction
`_process`, `_physics_process` et `_draw` d'une mesure (`tools/perf_instrument.py`,
`scripts/prof.gd`), puis lance le banc. Le projet n'est pas modifié. `FUNCS="_separate _push"`
mesure aussi ces fonctions.

**Le temps par image varie de ±2 ms d'un lancement à l'autre** sur la même machine (la partie du
robot n'est pas toujours la même). Pour comparer deux versions, alterner les lancements (base,
branche, base, branche) et comparer les moyennes.

## Budget

Mesures du 17/11 (llvmpipe, 4 cœurs, 1600x900, 120 Flétris). Le coût d'un poste est la différence
de temps par image quand on le cache (`--hide`).

| Poste | Coût par image | Où |
| --- | --- | --- |
| Socle : image vide, logique de jeu (pas fixe) | ~4 ms | moteur, `main.gd`, `enemy.gd` |
| Flétris (silhouettes, états, élites) | ~8,5 ms (dont ~3 ms de calcul des silhouettes) | `enemy.gd`, `fletri_art.gd` |
| Sol (shader plein écran) | ~9 ms | `ground.gd`, `shaders/ground.gdshader` |
| Interface (HUD) | ~2,5 ms | `hud.gd`, `hud_widgets.gd` |
| Décor et fleurs | ~1,5 ms | `flora.gd` |
| Héros, effets, ambiance, lieux | ~1,5 ms | `player.gd`, `fx.gd`, `skill_fx.gd`… |
| **Total** | **~25 ms** (47 ms avant le jalon 6) | |

Budget de la CI : **25 ms** en moyenne, échec au-delà de 15 % de plus (`tools/bench.sh`,
`.github/workflows/benchmark.yml`). La CI garde la meilleure de deux mesures.

## Règles pour tout nouvel objet animé

1. **Annoncer son coût.** Avant d'ajouter un objet nombreux ou plein écran, le mesurer avec le banc
   (`--hide`, ou `tools/perf-profile.sh`) et noter son coût dans le tableau ci-dessus, dans la PR.
2. **Un seul appel de rendu par objet.** Les petites formes (`draw_circle`, `draw_colored_polygon`,
   `draw_line`, `draw_polyline`, `draw_arc`) passent par un lot de triangles (`draw_batch.gd`) :
   - `exact = true` : découpage identique à celui de Godot 4.3, mêmes pixels (décor, fleurs).
     `tests/draw_batch_test.gd` le vérifie pixel à pixel ;
   - `exact = false` : découpage allégé (silhouettes des Flétris).

   Les traits lissés (`antialiased = true`) ne passent pas par le lot : ils coûtent cher en rendu
   logiciel. Les réserver aux objets uniques (héros, interface).
3. **Ne redessiner que ce qui change.**
   - Un dessin fixe (décor, fleurs, pierres d'un sanctuaire) n'est redessiné que quand il change :
     pas de `queue_redraw()` à chaque image.
   - Une silhouette animée est redessinée une douzaine de fois par seconde au plus, et pas hors de
     l'écran ; entre deux dessins, elle tourne avec son nœud (voir `enemy.gd › _redraw_parts`).
   - Un objet qui n'a plus rien à animer appelle `set_process(false)`.
4. **Pas de remplissage plein écran de plus.** Chaque couche plein écran (texture, voile, vignette)
   coûte plusieurs millisecondes en rendu logiciel. Le sol en est déjà une.
5. **Durée bornée.** Restes d'ennemis, particules, textes flottants : chaque objet a une durée de vie
   et un nombre maximal (voir `fx.gd`, `enemy_remains.gd`).
6. **Logique à pas fixe sur des tableaux.** Une boucle sur des centaines de paires lit les
   positions dans des tableaux locaux et les réécrit à la fin (`main.gd › _separate`) : lire et
   écrire la position d'un nœud coûte cher.
7. **Pas de fils pour le dessin en GDScript.** L'essai des silhouettes calculées sur plusieurs fils
   (`WorkerThreadPool`) a été plus lent : les fils se gênent sur les allocations du moteur.

## Ce qui a été fait au jalon 6 (tâche E)

| Changement | Gain | Image |
| --- | --- | --- |
| Rendu direct à l'écran en jeu (`main.gd › _set_direct_to_screen`) : plus de texture intermédiaire recopiée à chaque image | ~15 ms | identique (`tests/direct_screen_test.gd`, 3 résolutions) |
| Décor et fleurs en un appel de rendu par arbre et par carré (`flora.gd`, lot fidèle) | ~1 ms | identique |
| Séparation des Flétris sur tableaux locaux (`main.gd › _separate`) | ~1 ms | identique (même partie du robot à graine fixe) |
| Lot de triangles allégé : disques et joints en cache, polyligne en une forme (`draw_batch.gd`) | ~1 ms | identique |
| Sol sans mélange de couleurs (`render_mode blend_disabled`, il est opaque) | <1 ms | identique |

Le rendu direct à l'écran rend l'image illisible par `get_viewport().get_texture()`. Il n'est donc
actif que dans la scène de jeu lancée normalement et dans le banc, jamais pendant une capture
(robot `--autotest`, tests visuels, scripts de test lancés par `-s`).

## Pistes suivantes

- **Sol** (~9 ms) : le dessiner par carrés mis en cache dans des textures, au lieu de calculer
  chaque pixel à chaque image. Gain estimé ~5 ms, mais décalage de moins d'un pixel sur les petits
  motifs (cailloux, baies, fleurs) : références à régénérer.
- **Interface** (~2,5 ms) : passer les formes du HUD par le lot de triangles.
- **Silhouettes** (~3 ms de calcul) : mettre en cache la triangulation des formes fixes.
