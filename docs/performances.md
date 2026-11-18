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
| `--bench-scene=coeur` | banc des pics : le siège du Cœur (vagues toutes les 6 s), jusqu'à la purification (40 morts d'un coup, vague de vie) ; 36 s, héros au build du robot du boss |
| `--bench-scene=boss` | le combat de la Mère-Ronce, 60 s |

`tools/perf-profile.sh` copie le projet dans un dossier temporaire, y enveloppe chaque fonction
`_process`, `_physics_process` et `_draw` d'une mesure (`tools/perf_instrument.py`,
`scripts/prof.gd`), puis lance le banc. Le projet n'est pas modifié. `FUNCS="_separate _push"`
mesure aussi ces fonctions.

**Le temps par image varie de ±2 ms d'un lancement à l'autre** sur la même machine (la partie du
robot n'est pas toujours la même). Pour comparer deux versions, alterner les lancements (base,
branche, base, branche) et comparer les moyennes.

## Budget

Mesures du 18/11, jalon 7 (llvmpipe, 4 cœurs, 1600x900, 120 Flétris). Le coût d'un poste est la
différence de temps par image quand on le cache (`--hide`). Cette machine était plus lente que celle
du jalon 6 : la base y mesurait ~28 ms (23,5 ms au jalon 6).

| Poste | Coût par image | Où |
| --- | --- | --- |
| Socle : image vide, logique de jeu (pas fixe) | ~4 ms | moteur, `main.gd`, `enemy.gd` |
| Flétris (silhouettes en cache, états, élites) | ~6,5 ms (~0,6 ms de calcul des silhouettes, le reste en rendu) | `enemy.gd`, `silhouette_cache.gd`, `fletri_art.gd` |
| Sol (carrés en cache, une texture plein écran) | ~5,5 ms (~9 ms sans le cache) ; la recopie opaque des carrés (tâche A) retire ~1 ms | `ground.gd`, `shaders/ground.gdshader`, `shaders/ground_tile.gdshader` |
| Interface (HUD) | ~2,3 ms (~0,2 ms de scripts, le reste : ~240 appels de rendu, traits lissés) | `hud.gd`, `hud_widgets.gd` |
| Héros | ~2,5 ms (traits lissés, ~80 appels de rendu) | `player.gd`, `hero_art.gd` |
| Décor et fleurs | ~1,5 ms | `flora.gd` |
| Effets, ambiance, lieux | ~1 ms | `fx.gd`, `skill_fx.gd`… |
| **Total** | **~22 ms** (~28 ms avant le jalon 7 sur la même machine) | |

Budget de la CI : **26 ms** en moyenne sur le banc, échec au-delà de 15 % de plus (`tools/bench.sh`,
`.github/workflows/benchmark.yml`), et un banc des pics (siège du Cœur) avec un budget pour la
moyenne et le 99e centile. La CI garde la meilleure de deux mesures. Sa machine est plus lente que
celle des tests (34,9 ms mesurés sur la base du jalon 7) : ses budgets sont ceux de sa machine.
Jusqu'au jalon 7, le pas de la CI se terminait par `| tee` sans `pipefail` : un dépassement était
affiché mais ne faisait pas échouer le job.

Vocabulaire des coûts mesurés au jalon 7 (profil `perf` de llvmpipe) : un objet dessiné coûte ~4 µs,
un appel de rendu de forme (polygone, maillage) ~4 µs de plus, un sommet ~0,1 µs (calculé par le
processeur sur le fil principal), et le remplissage ~3,5 ns par pixel : un calque plein écran à
1600x900 coûte donc ~5 ms.

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
| Sol dessiné par carrés de 512 px mis en cache (`ground.gd`, `SubViewport` mis à jour seulement quand le sol change ; `--sol-direct` pour l'ancien chemin) | ~2 à 3 ms | écart de 0,011 % au plus, sous le seuil des tests visuels : références inchangées |
| Carrés du sol recopiés sans mélange ni lumière (`shaders/ground_tile.gdshader`, `blend_disabled, unshaded`) ; le shader du sol calcule l'appartenance aux régions une seule fois par pixel pour N régions (jalon 7) | ~1 ms (sol : 6,5 → 5,4 ms, mesuré par paires avec `--hide=sol`) | identique |
| Carrés du sol salis refaits au plus deux par image, les plus proches du centre d'abord (`ground.tile_budget`, en jeu et dans le banc, pas en capture) | pics : 99e centile ~46 → ~42 ms ; moyenne avec la ligne précédente : ~26,3 → ~24,8 ms (4 paires) | identique en capture ; en jeu, un carré lointain peut garder l'ancien sol quelques images |

Le rendu direct à l'écran rend l'image illisible par `get_viewport().get_texture()`. Il n'est donc
actif que dans la scène de jeu lancée normalement et dans le banc, jamais pendant une capture
(robot `--autotest`, tests visuels, scripts de test lancés par `-s`).

## Ce qui a été fait au jalon 7 (tâche P)

Mesures en paires alternées base / branche (même machine, 3 paires pour le banc, 2 par scène) :

| Banc | Base : moyenne / 99e centile | Branche : moyenne / 99e centile |
| --- | --- | --- |
| 120 Flétris | 28,1 ms / 49,0 ms | 22,3 ms / 37,6 ms |
| Siège du Cœur | 35,1 ms / 70,0 ms | 34,3 ms / 63,5 ms |
| Combat du boss | 24,8 ms / 34,8 ms | 23,8 ms / 33,5 ms |

| Changement | Gain | Image |
| --- | --- | --- |
| Silhouettes des Flétris en cache (`silhouette_cache.gd`) : une silhouette au repos ou en marche est calculée une fois par sorte, rayon, teinte, regard (1/32 de tour), phase de marche (1/8) et phase lente (1/6 de respiration), gardée en maillage ; l'écrasement de la marche et la respiration restent exacts (transformation au dessin). Les poses d'action sont calculées comme avant | scripts −2,6 ms (85 % des dessins servis par le cache) | Flétris en jeu à peine différents (arrondis ci-contre) ; Flétris figés (galeries, charte) tracés comme avant : références inchangées |
| Tracé « économe » des silhouettes en cache (`draw_batch.gd › lean`) : polylignes en bande à joints en onglet, petits disques à moins de côtés | rendu ~−1 ms (moitié moins de sommets) | idem |
| Interface redessinée seulement quand ce qu'elle montre change (emplacements, barre de vie, coin) ; noms des touches et infobulles gardés jusqu'au prochain changement des réglages | scripts −2 ms | identique |
| Restes des Flétris (`enemy_remains.gd`) en un appel de rendu (lot fidèle) au lieu d'une trentaine | pics des morts en série | identique (galerie des silhouettes) |
| Lot fidèle : les traits plus fins qu'un pixel gardent leur largeur, comme Godot (ils étaient élargis à 1 px) | — | plus fidèle |
| Effets de mort étalés (`main.death_fx`) : au plus 6 par pas de jeu, les autres aux pas suivants ; la vie rendue au sol reste immédiate (le sol regroupe les retouches d'une image) | pics des morts en série | identique hors mort en série |

## Pistes suivantes

- **Objectif de 20 ms** : atteint à ~2 ms près sur la machine des tests du jalon 7 (22,3 ms, dont
  le sol ~5,5 ms) ; sur la machine du jalon 6, la même baisse de 21 % donne ~18,5 ms.
- **Pics (99e centile sous 33 ms)** : atteint pour le boss, pas pour le banc (37,6 ms) ni pour le
  siège du Cœur (63,5 ms). Au Cœur, les pics viennent du sol : chaque mort refait 1 à 4 carrés de
  512 px (~1 ms chacun), la vague de vie de la purification les refait tous pendant 2 s (images de
  55 à 100 ms). Le budget de carrés refaits par image (tâche A, `ground.tile_budget`, deux par image en
  jeu et dans le banc) s'attaque à cela. Viennent ensuite le décor dense du roncier (~7 ms au Cœur, ~50 ronces à l'écran) et les
  fleurs après la purification (~4 ms).
- **Héros** (~2,5 ms) et **interface** (~2,3 ms) : leurs traits lissés ne passent pas par le lot ;
  les mettre en texture une fois (médaillons, icônes) avec un mélange prémultiplié.
- **Nouvelles régions (tâches C et E)** : mesurer leur décor avec `--bench-scene` avant fusion.
