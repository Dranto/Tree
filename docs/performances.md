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
| `--hide=sol,ennemis,…` | cache des calques : la différence de temps donne leur coût. Calques : `sol`, `decor`, `fleurs`, `ennemis`, `joueur`, `acteurs`, `effets`, `ambiance`, `hud`, `monde`, `sol_ennemis`, `bord` (bord du monde), `vivant` et `vivant_dessus` (monde vivant), `competences` |
| `--profile` | temps de chaque `_process`, `_physics_process` et `_draw`, à lancer par `tools/perf-profile.sh` |
| `--bench-scene=coeur` | banc des pics : le siège du Cœur (vagues toutes les 6 s), jusqu'à la purification (40 morts d'un coup, vague de vie) ; 36 s, héros au build du robot du boss |
| `--bench-scene=zones` | le tour des six régions : le héros marche (220 px/s, `--bench-run=V`) sur un cercle de 1 300 px autour de la graine (`--bench-orbit=R`) et franchit chaque frontière ; Flétris nés comme en jeu ; liste les images de plus de 50 ms (`A-COUP`, avec ce qui a coûté sous `--profile`). `--preparation` lance d'abord l'écran de chargement du jeu (voir « Changements de zone ») |
| `--bench-scene=boss` | le combat de la Mère-Ronce, 60 s (`--region=<id>` : le boss de cette région, `finale` : la Flétrissure). Le combat commence quand le bord du monde et l’arène sont cuits (au plus 900 images) |

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
| Sol (carrés en cache, une texture plein écran) | ~5,5 ms (~9 ms sans le cache) ; la recopie opaque des carrés (tâche A) retire ~1 ms. Sol en couches (refonte du monde S, 25/11) : chaque carré porte un calque d'éléments tiré une fois (géométrie des cases en cache, état choisi par le shader du calque), l'herbe du front et l'herbe rase sont peintes par le shader du sol ; banc en paires sans écart mesurable | `ground.gd`, `shaders/ground.gdshader`, `shaders/ground_layer.gdshader`, `shaders/ground_tile.gdshader`, `world_bake/ground_layers.gd` |
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

Le rendu direct à l'écran rend l'image illisible par `get_viewport().get_texture()`. Il n'est
actif que dans le banc, ou en jeu avec l'option `--rendu-direct`, jamais pendant une capture
(robot `--autotest`, tests visuels, scripts de test lancés par `-s`). Il n'est plus actif par défaut
en jeu depuis le 18/11 : chez un joueur sous Windows avec Godot 4.7, la fenêtre restait figée sur
l'écran titre (le jeu tournait, le son aussi, mais l'image n'était plus mise à jour). Sur une vraie
carte graphique, le gain est négligeable.

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

## Ce qui coûte dans la région de Vent (jalon 7, tâche E)

Mesures en paires alternées base (c0b53e1) / branche, même machine (logiciel, llvmpipe) :

| Banc | Base : moyenne | Branche : moyenne |
| --- | --- | --- |
| 120 Flétris (6 paires) | 24,4 · 26,5 · 23,0 · 23,3 · 25,9 · 25,3 ms | 30,9 · 28,2 · 27,0 · 27,1 · 26,7 · 28,7 ms |
| Siège du Cœur de Ronce (2 paires) | 39,4 · 38,1 ms | 38,9 · 37,7 ms |
| Combat de la Mère-Ronce (2 paires) | 25,2 · 24,4 ms | 27,7 · 24,7 ms |
| Siège du Cœur des rafales (`--region=vent`) | — | 34,5 · 34,2 ms (99e centile 54–58 ms) |
| Combat du Harfang (`--region=vent`) | — | 21,9 · 21,0 ms (99e centile 30–33 ms) |

Les deux dernières paires du banc ont été mesurées après la correction du Planeur (ci-dessous).

Le banc des 120 Flétris coûte environ 2 ms de plus, parce que la graine touche maintenant deux régions :

| Objet | Coût mesuré | Remarque |
| --- | --- | --- |
| Flétris des plateaux (Piqueur, Souffleur, Planeur, Menhir) qui apparaissent près de la graine | ~2 ms sur le banc (banc avec seulement des Flétris ordinaires dans Vent : +1,5 ms au lieu de +4) | sortes en plus = ~700 maillages de silhouette en plus dans le cache. Le Planeur en vol haut était redessiné en direct à chaque image : `EnemyBehavior.calm` le ramène au rythme ordinaire (12 dessins/s) |
| Cœur des rafales et sanctuaires de Vent redessinés quand le joueur est à moins de 1 600 / 1 300 px (règle de heart.gd et sanctuary.gd) | ~0,3 ms près de la graine | 0 hors de portée |
| Traînées de vent (`wind.gd`) : 26 polylignes, un appel de rendu, seulement dans la région | ~0,07 ms par image | `Settings.reduce_effects` en garde un tiers |
| Herbe couchée et rochers (`decor_plateau.gd`) : ~380 objets fixes dessinés une fois (lot fidèle), redessinés seulement pendant leur pousse | pas mesurable sur le banc (±2 ms de bruit) | obstacles dans la grille des buissons |
| Tornades et plumes du Harfang : dessinées dans le `_draw` du boss | banc du Harfang 21–22 ms | sous la Mère-Ronce (24–25 ms) |
| Arbre de vie (`tests/tree_bench.gd`) | immobile 14,9 → 16,3 ms, survol 18,9 → 19,8 ms, déplacement 27,7 → 26,7 ms | dans le bruit |

## Cinq régions (jalon 8, tâche P)

`REGIONS=cinq tools/bench.sh` (aujourd'hui `REGIONS=six`, même banc) (aussi `-- --benchmark --regions=res://tests/regions/`) ajoute les régions
factices de `tests/regions/` (Sève, Aube, Racine) à celles de `data/regions/` : une vraie région
l'emporte sur sa factice, donc le banc suit la vraie Sève et la vraie Aube dès leur fusion. La CI
lance ce banc (budget 34 ms) et le banc des pics du Cœur dans ce monde.

Constat (machine des tests, paires alternées, 20 à 40 s) :
- Le monde lui-même ne coûte rien : le sol (shader à N régions) et les Cœurs ne changent pas.
- Ce qui coûte, ce sont les sortes d'ennemis des nouvelles régions : les factices tirent des
  Chargeurs et des Cracheurs, qui passent plus de temps en pose d'action (annonce, charge), tracée
  en direct (~10 silhouettes par image, ~60 µs pièce) et lancent des projectiles. Le banc des
  120 Flétris passe de ~32 à ~33–44 ms selon la vitesse de la machine du jour (±10 ms d'un jour à
  l'autre : ne comparer qu'en paires).
- Le cache des silhouettes atteignait son plafond (8 000 maillages) en une quarantaine de secondes à
  cinq régions et se vidait d'un coup (pire image 112 ms). Il garde maintenant deux générations de
  6 000 : la récente, et l'ancienne dont les maillages encore utilisés sont repris (pire image 61 ms
  sur la même paire, moyenne inchangée dans le bruit).
- Pistes non faites : poses d'action en cache (peu de réemploi : regard × étape × sorte) ; interface
  en texture (les emplacements coûtent ~3 à 5 ms de rendu d'après `--hide`, mais ils reçoivent la
  souris et les infobulles).

## Six régions et finale (jalon 9, tâche P)

`REGIONS=six tools/bench.sh` (alias de `cinq`) : avec Racine factice, le banc joue déjà à six régions ;
la CI le lance (120 Flétris et siège du Cœur). `SCENE=finale tools/bench.sh` joue le combat du colosse
sous la graine (`--bench-scene=boss --region=finale`), à six régions dans la CI (budget 36 ms, 99e centile 50 ms).

Constat : la finale coûtait ~44 ms contre ~22 ms pour un boss ordinaire. Le coût venait des pixels :
la terre du creux (un rectangle de 5 600 px) et dix disques opaques empilés pour le sol redessinaient dix
fois le centre de l'écran. Ils sont maintenant tracés en couronnes (`DrawBatch.ring`, mode exact : mêmes
64 points que `draw_circle`), sans rien changer aux pixels (références inchangées). Paires alternées
base/branche : 44,7 → 37,9 ms (99e centile 59 → 54 ms).

Essayé et écarté : tracer le colosse et la grotte entiers dans un lot « exact » ramène les objets de
6 900 à 1 150 mais perd l'anticrénelage des traits (0,1 à 0,5 % de pixels en écart, bords d'une largeur d'un
pixel) pour ~3 à 5 ms ; le lot n'est gardé que pour ce qui est rempli.
Pistes non faites : poses d'action en cache (peu de réemploi, voir ci-dessus) ; interface en texture (les
emplacements reçoivent la souris et les infobulles).

## Jalon 11 (tâche E) : un banc fiable sur la CI

- **La machine de la CI varie de ±15 %** d'un job à l'autre : le même code (develop c725f6e) a mesuré
  27,5 ms puis 31,5 ms au banc des 120 Flétris (24/11). Un budget fixe échouait donc sans régression.
  Sur une PR, `benchmark.yml` mesure maintenant le banc **en paires** : `BASE_DIR=../base tools/bench.sh`
  alterne la branche visée (copie dans `../base`) et la PR, sur la même machine. Le banc échoue
  seulement si la PR dépasse la limite (budget + 15 %) **et** la base de plus de 8 % (`REGRESSION`).
  Au-dessus de la limite mais pas plus lente que la base : avertissement (machine lente), pas d'échec.
  Les autres bancs (Cœur, six régions, finale) gardent leurs budgets, qui ont de la marge.
- Cœurs (`heart.gd`) et sanctuaires (`sanctuary.gd`) redessinés comme les autres objets animés :
  30 fois par seconde au plus pendant le siège, 15 sinon (le sanctuaire reste à chaque image pendant
  l'onde du ravivement). Profil (`tools/perf-profile.sh`) : dessin du Cœur 1,8 → 0,9 ms par image,
  sanctuaires 0,34 → 0,16 ms, sur le banc à ~25 images/s (le gain est plus grand en jeu à 60 images/s).
  Références visuelles refaites (décors et marais : 0,07 à 0,14 % de pixels, l'anneau du Cœur à un
  autre instant).

## Jalon 12 (tâche G) : fiabilité avant la démo

- **Banc en 1280×800** : `RESOLUTION=1280x800 tools/bench.sh` (et une étape de `benchmark.yml`, mesurée en
  paires avec la base comme le banc principal). Machine du conteneur du 25/11 (4 cœurs, ~1,8 fois plus lente
  que la CI) : **1600×900 : 44,0 ms ; 1280×800 : 41,5 ms** (−6 %), le coût du rendu logiciel suit les pixels.
  La fenêtre 1280×800 se met à l'échelle 0,8 : la vue logique est de 1600×1000.
- **Où va le temps** (mêmes conditions, 120 Flétris, `--hide`) : Flétris ~19 ms (dont ~7 de scripts),
  sol ~10 ms, décor ~6 ms, héros ~5 ms, interface ~4 ms, ambiance ~3 ms, fleurs ~3 ms, effets ~1 ms.
  Scripts : `enemy.Part._draw` 3,8 ms, `main._physics_process` 3,3 ms (dont `_separate` 1,4 et
  `_push_out_of_bushes` 0,6) pour ~2,9 pas de jeu par image, `player._physics_process` 1,4 ms (le robot du
  banc), `enemy._physics_process` 1,2 ms.
- **Essai refusé** : ne réécrire la position d'un Flétri ou du joueur dans `_push_out_of_bushes` que quand
  un buisson la change. Gain non mesurable (44,0 contre 44,6 ms, bruit de ±5 %) et **les images ne sont plus
  identiques** (les tests visuels `roncier_purifie` et `bord_aube` bougent de 1,5 et 2,8 % des pixels) : écrire
  la position, même inchangée, a un effet sur l'interpolation physique. Ne pas y revenir sans les références.
- Chantiers restants pour passer sous 26 ms sur la CI (aucun n'est sans changer d'image) : interface en texture
  (estimé à ~2,4 ms sur la CI d'après les 4,3 ms mesurés ici avec `--hide=hud`), mutualiser la grille de `_rebuild_grid` et celle de
  `_separate` (~0,5 ms), clé de cache des silhouettes en entier plutôt qu'en texte (~0,2 ms).

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

## Godot 4.7 (19/11)

Le projet, les outils et la CI tournent en Godot 4.7 (`tools/godot.sh`, `GODOT_VERSION=4.3-stable` pour comparer).
- Les 26 tests passent ; le découpage « exact » de `draw_batch.gd` donne toujours les mêmes pixels qu'en 4.3.
- **SubViewport en `UPDATE_ONCE`** : en 4.7, l'image est faite avec l'état des nœuds de l'image précédente si le rendu
  est demandé dans la même image que leur changement. `tree_ui.gd` (image de la couche fixe et du fond) et `ground.gd`
  (carrés du sol) repassent par `UPDATE_DISABLED` et demandent le rendu à l'image suivante ; la géométrie de l'image de
  l'arbre change à ce moment-là. Sans cela, l'arbre affichait des nœuds décalés et un fond absent.
- Même machine, banc de jeu : 4.7 donne ~31 ms contre ~33 ms en 4.3 (la machine de la CI reste la référence du budget).
- Les références visuelles ont été refaites en 4.7 : les écarts (0,2 à 5 % de pixels) viennent du texte et des bords
  des panneaux, décalés d'un pixel.

## Prototype : silhouettes cuites en sprites (refonte des personnages, vague 0 T, 25/11)

Réglage interne `-- --sprites` (`--sprites=3` : résolution, `--sprites-walk=8`, `--sprites-ss=2`),
éteint par défaut. Au chargement, `scripts/sprite_bake.gd` dessine chaque sorte une fois (dessins
d'aujourd'hui), suréchantillonnée dans un SubViewport (pas de MSAA 2D en rendu Compatibility), en
31 poses (repos 6, marche 12, annonce 6, élan 2, retour 1, frappe 4 ; doublons retirés), dans un
atlas par sorte avec mipmaps. En jeu, un quadrilatère texturé par Flétri, retourné gauche/droite ;
teinte d'état et éclair par `shaders/sprite_tint.gdshader`. Planche : `tests/sprites_planche.gd`.
Options du banc ajoutées : `--bench-kinds=fletri,tireur` (seules ces sortes naissent),
`--bench-shot=x.png` (capture finale, sans rendu direct).

Banc en paires (5 tours, machine lente) : develop 58,4 ms (p99 99,5) ; sprites ×4 48,2 ms (p99 79,0).
Atlas des 30 sortes : 27 Mo à ×2, 59 Mo à ×3, 103 Mo à ×4 ; cuisson 0,8 / 1,4 / 2-3 s (llvmpipe).
Mesures et recommandation complètes dans la PR.

## Moteur de créatures : rendu cuit par défaut (refonte des personnages, vague 1 A, 25/11)

`scripts/sprite_bake.gd` est devenu le rendu des Flétris (`-- --no-sprites` revient au dessin direct, pour comparer).
- Une sorte qui a son script `scripts/creature_art/<région>/<id>.gd` (contrat :
  /mnt/project-files/plans/refonte-persos-contrat-moteur.md) est cuite depuis ce dessin, vue de trois quarts, pieds à
  0,45 × rayon sous la position ; les autres gardent l'ancien dessin, cuit lissé.
- Cuisson ×3, suréchantillonnée ×2, en deux passes : une petite pour la place de chaque image (et les doublons, l'ombre
  relevée), puis une case ajustée par image, rangées par étagères. Marche 12 images, repos 4 et annonce 4 (chacun en trois
  regards), charge 2, retour 1, frappe 3, coup reçu 2, poses propres (`const CUSTOM`).
- Quand : sortes communes au démarrage, celles d'une région à son entrée, toute autre à sa première apparition (dessin
  direct en attendant, une ou deux images). Cache disque `user://sprites/` (zstd), invalidé par une empreinte des scripts
  de dessin (texte, ou fichier compilé d'un export), d'`art.gd` et des réglages : 30 sortes relues en ~60 ms.
- Mémoire : 52 Mo pour les 30 sortes aujourd'hui (3 dessinées, ~4 à 9 Mo chacune). Budget de 64 Mo en jeu : au-delà, les
  atlas qui n'ont pas servi depuis 3 s sont rendus et relus du cache s'ils reviennent ; une sorte vise 3,5 Mo : au-delà elle est cuite moins fin, de ×3 jusqu'à ×2 (`KIND_TARGET`, `MIN_SCALE`), et le test la plafonne à 5 Mo ; `const LOOKS := false` cuit un seul regard pour un dessin qui ne suit pas la cible.
- Ombres, annonces d'attaque, auras : couche `enemy_ground_layer` sous tous les acteurs (les comportements dessinent sur
  `e.gc`). Élite : ×1,15, liseré doré (shader), collier de la région au point `NECK`, ou atlas d'élite (`DRAWS_ELITE`).
- Banc en paires (4 tours, machine lente) : develop 53,5 ms (p99 92,8) ; rendu cuit 48,1 ms (p99 81,6), soit −10 %.
- `tools/sprites-determinisme.sh` : même empreinte de l'état du jeu avec et sans rendu cuit (graine et pas fixes).

## Prototype : sol en couches et décor cuit (refonte du monde, vague 0 P, 25/11)

Réglages internes, éteints par défaut (aucune référence visuelle ne change) : `--paysage-sol`
(scripts/world_bake/ground_layers.gd : lavis dans le shader, matière et détails dessinés une fois par
carré de sol), le décor cuit et composé est passé en rendu par défaut en vague 1 D (section suivante). Bancs : `--bench-at=ronce`,
`--bench-run=1400`. Mesures en paires (Roncier, 120 Flétris) : sol en couches +5 %, décor composé en
direct +19 %, cuit +8 % ; un carré de sol 5,5 ms au lieu de 2,5. Tableau complet et recommandation :
/mnt/project-files/captures/refonte-monde/P/mesures.md (projet). Test : tests/paysages_proto_test.gd.

## Décor composé et cuit (refonte du monde, vague 1 D, 25/11)

Rendu par défaut ; `--decor-direct` revient au dessin direct, `--decor-ancien` au semis d'avant.
- Composition (scripts/world_bake/decor_compose.gd) : clairières autour des lieux, clairières de combat,
  passages entre les lieux ; lisières en grappes autour d'un grand élément ; repères du fichier ; au plus
  80 éléments debout par écran (fenêtres d'un écran et un cinquième ; les détails plats au sol ne comptent
  pas). Les obstacles du semis restent où ils sont (test : tests/decor_test.gd).
- Cuisson (scripts/world_bake/decor_bake.gd) : un atlas par région, ×1,5 lissé (ss 2), 3 variantes,
  paliers de taille ×1,6, images morte et vivante ; un quadrilatère par élément, un seul matériau.
  Cuite quand la région entre dans le champ (Runtime) ; cache `user://decor/` (zstd) invalidé par une
  empreinte des scripts de dessin. Première cuisson ~0,5-1,3 s par région, relue du cache en ~50 ms.
  Mémoire 10 à 22 Mo par région (budget 96 Mo, régions hors du champ rendues au-delà).
- Pousse d'une vague de vie : fondu de l'image morte à la vivante, sans dessin direct.
- Premier plan : grands éléments à demi transparents (self_modulate, sans redessin) quand le héros ou
  un Flétri passe derrière ; relevé des voisins toutes les 6 images, des Flétris toutes les 3.
- `--decor-verbeux` : une ligne par région cuite. Vues : tests/paysages/decor_vues.gd.

## Changements de zone (27/11)

Antoine voyait de petits gels en passant d'une région à l'autre. Banc `--bench-scene=zones` sous
`tools/perf-profile.sh` (le profil donne, pour chaque image de plus de 50 ms, ce qui a coûté, et
`PIC` le pire temps de chaque fonction) :

| Cause | Pire image | Correction |
| --- | --- | --- |
| Toutes les sortes de Flétris de la région cuites dans la même image à l'entrée (`sprite_bake.pump`) ; même depuis le cache disque : 50 à 80 ms | 250 à 1 100 ms | cuites au chargement (en jeu, ce qui manquerait se cuit encore par lot : une sorte à la fois rallongeait le banc des 120 Flétris à froid, plus de dessins directs) |
| Pièces et sol d'une arène dessinés en direct tant qu'ils ne sont pas cuits | 70 à 145 ms | cuits au chargement |
| Fond et voile d'une tuile du bord du monde construits à l'approche (`world_edge.ensure`) | 60 à 95 ms | construits au chargement, gardés en mémoire (~1,5 Mo) et en cache disque (`user://bord/`) |
| Bande de décor du bord : lecture du SubViewport puis réduction de l'image | 50 à 100 ms (réduction ~45 ms) | réduction sur un autre fil (`WorkerThreadPool`) ; la lecture reste (~35 ms en rendu logiciel) |
| Purification d'un Cœur : toutes les tuiles du bord de sa région refaites dans la même image (`world_edge._sync_states`, signalé par le banc du siège) | 550 à 650 ms | en jeu, un fond ou un voile par image, tuiles proches de l'écran d'abord, l'ancienne image reste jusqu'au fondu (pire étape ~75 ms en rendu logiciel) ; captures et tests : tout de suite, comme avant |
| Faune et formes guéries d'une région (`world_life_vie.gd`) | 35 à 65 ms | cuites au chargement, gardées (`Vie.pinned`) |
| Pierres des sanctuaires, Cœurs, autels dessinés en direct en attendant leur cuisson | 10 à 20 ms | cuits au chargement |
| Pistes de musique et d'ambiance lues du disque à l'entrée | ~7 ms | lues au chargement |
| Shaders compilés par le pilote à leur premier dessin (carte graphique réelle, invisible en rendu logiciel) | — | chacun dessiné une fois sous l'écran de chargement |

**L'écran de chargement** (`scripts/world_preload.gd`) s'affiche au lancement d'une partie (Nouvelle
partie, Continuer), arbre en pause, et prépare tout cela. Il n'est actif qu'en jeu (pas dans les
tests, les robots, les captures ni le banc, sauf `-- --preparation` ; `-- --sans-preparation` le coupe).
Les budgets mémoire des cuissons sont relevés pour que rien de préparé ne soit rendu puis recuit :
Flétris 256 Mo (~210 Mo utilisés, élites des sortes régionales comprises), décor 160 Mo (~107),
lieux 96 Mo (~62), faune ~30 Mo. Le décor des bandes du bord, lui, reste cuit à l'approche : tout
cuire prendrait ~400 Mo.

Durée en rendu logiciel (machine des tests) : ~45 s au premier lancement après une mise à jour (les
caches disque des Flétris, du décor et du bord sont refaits), ~10 s ensuite.

Paires alternées base (develop a7544b4) / branche, `--bench-scene=zones --bench-time=40`, chaque côté
avec son propre `user://` (caches à chaud, sauf la 1re paire, à froid) :

| Paire | Base : moyenne / 99e centile / pire ; images > 100 ms / > 200 ms | Branche (préparée) |
| --- | --- | --- |
| 1 (froid) | 69,8 / 449 / 1 119 ms ; 92 / 26 | 51,8 / 146 / 342 ms ; 27 / 4 |
| 2 | 65,7 / 231 / 341 ms ; 91 / 14 | 46,3 / 108 / 131 ms ; 11 / 0 |
| 3 | 59,6 / 198 / 339 ms ; 81 / 7 | 39,6 / 86 / 110 ms ; 3 / 0 |
| 4 | 59,5 / 223 / 289 ms ; 83 / 13 | 45,6 / 102 / 127 ms ; 12 / 0 |

Ce qui reste au-dessus de 100 ms en rendu logiciel est du rendu (cuisson des bandes du bord, carrés du
sol), sans pic de script de plus de ~25 ms. `tests/preparation_test.gd` vérifie que tout est cuit après
le chargement et qu'un tour des régions ne cuit plus ni Flétri, ni lieu, ni fond du bord.
