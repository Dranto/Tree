# Cuisson des boss (refonte des personnages, vague 2)

Les sept boss « Bestiaire d'herbier » sont dessinés par le code (encre, deux tons, reflets) : un dessin
direct coûte plusieurs millisecondes par image. Chacun est donc « cuit », mais pas tous de la même façon :
leurs besoins diffèrent, et chaque choix a été mesuré au banc en paires par la tâche qui l'a fait.

| Boss | Cuisson | Principe | Pourquoi |
| --- | --- | --- | --- |
| Mère-Ronce, Ancien pétrifié | `scripts/boss_bake.gd` | atlas de poses cuites d'avance, par groupe (sol, corps, endormi…), comme le héros | poses en nombre fini, connues d'avance ; aucun à-coup en combat |
| Amanite-Mère, Saule exsangue | `scripts/boss_body_cache.gd` | une texture par pose, faite à la demande, cache LRU (24) ; ce qui bouge sans cesse reste en direct (couche « live ») | poses nombreuses mais répétées ; corps lourd, détails vivants légers |
| Harfang de cendre, Phalène de verre | `scripts/pose_cache.gd` | une pose = un nœud qui garde ses commandes de dessin, sans texture | grandes ailes : un atlas prenait trop de mémoire ; le dessin reste vectoriel et net |
| La Flétrissure | `scripts/boss_art/live_bake.gd` | une seule texture redessinée ~20 fois par seconde, tout de suite quand la clé change | elle change sans cesse avec la musique (combat calé sur le breakcore) |

## Règles communes (`scripts/boss_art/cuisson.gd`)

- **Quand cuire** : `Cuisson.active()` = un écran est présent et la cuisson n'est pas coupée. Sans écran
  (`--headless`, tests de logique), rien n'est rendu. Avec `-- --no-sprites` (comparaisons, comme pour les
  Flétris), les boss se dessinent en direct.
- **À quelle échelle** : `Cuisson.window_scale(mult, min, max)`, d'après la hauteur de la fenêtre.
- **Quand tout refaire** : le mode daltonien change les couleurs du bestiaire (`Art.bc`).
  `Settings.set_colorblind_mode` → `SpriteBake.palette_changed()` → `Cuisson.palette_changed()` : chaque
  cuisson compare `Cuisson.epoch` et jette ce qu'elle a cuit (l'atlas de `boss_bake.gd` a le mode dans sa
  clé). Avant, l'Amanite, le Saule, le Harfang et la Phalène gardaient leurs anciennes couleurs jusqu'à la
  fin du combat.

Test : `tests/boss_cuisson_test.gd` (dans `tools/unit-tests.sh`).

## Un nouveau boss

Choisir la cuisson selon ses poses : finies et connues → atlas (`boss_bake.gd`) ; nombreuses et
répétées → `boss_body_cache.gd` ; très grandes → `pose_cache.gd` ; qui changent à chaque image →
`live_bake.gd`. Passer par `Cuisson` pour les trois règles ci-dessus, et mesurer au banc en paires.
