# Données du jeu

Ce dossier décrit ce que font les nœuds de l'Arbre de vie. Le code (`scripts/skill_tree.gd`) ne décide que de la forme de l'arbre ; les statistiques, les branches, les nœuds clés et les compétences se modifient ici, sans toucher au code.

Après chaque modification, vérifier les données :

```
tools/godot.sh --headless -s res://scripts/check_data.gd
```

La commande signale les fautes de frappe (statistique, opération ou action inconnue), les nœuds qui ne seraient plus reliés à la graine, et renvoie le code 1 en cas d'erreur. Le jeu affiche les mêmes erreurs au lancement.

## Fichiers

| Fichier | Contenu |
| --- | --- |
| `tree.json` | Ordre des branches autour de la graine, progression des valeurs par anneau (`ring_scale`), force des nœuds notables (`notable_factor`), nœud de la graine. |
| `stats.json` | Les statistiques du personnage : libellé, valeur de base, bornes, arrondi. |
| `branches/<id>.json` | Une branche : nom, couleur, effets des petits nœuds, bonus et noms des nœuds notables, nœuds clés, résonance, grappes écrites à la main. |
| `grafts.json` | Les greffes : objets à poser dans un emplacement de greffe de l'arbre (nom, effets, d'où elles viennent, dessin). |
| `rewards.json` | Points d'arbre et greffes gagnés dans le monde : boss, Cœurs, autels cachés et secrets de chaque région. |
| `skills.json` | Réglages des compétences actives (recharge, rayon, dégâts, texte). |
| `builds.json` | Builds types joués par le robot d'équilibrage (`tools/balance.sh`). |
| `conditions.json` | États utilisables dans un `if`, avec leur texte d'affichage. |
| `difficulty.json` | Difficulté (`scripts/difficulty.gd`) : menace des ennemis (`threat` : par niveau, selon la profondeur dans la région, par Cœur purifié, plafond), effet de la menace sur leurs statistiques (`scaling`), courbe d'expérience et durée visée par niveau (`xp`), apparitions (`spawn` : cadence, plafond d'ennemis et salves près de la graine et au fond de la région), modes Facile / Normal / Difficile (`modes`), élites (`elites` : chance près/loin, niveau minimal, nombre en vie, chance d'un second modificateur, multiplicateurs de vie, dégâts, taille et expérience, chance de greffe, sortes exclues, et `affixes` : nom affiché, couleur, poids et réglages de chaque modificateur). Vérifiée par `check_data.gd` ; le rythme se mesure avec `tools/balance.sh --run`. |
| `objectives.json` | Les objectifs de la tranche : principaux (dans l'ordre), facultatifs, drapeau de fin. Voir « Objectifs ». |
| `attack.json` | L'attaque de base du Porte-Graine (`scripts/attack.gd`) : forme de départ, formes (graine, échardes, fouet, ronces vives) et modificateurs cumulables. Voir « L'attaque de base ». |
| `enemies.json` | Sortes d'ennemis (`kinds` : statistiques, comportement `chase`/`shooter`/`charger`/`nest`/`kite`/`guard`/`bomber` et ses réglages, `region`, `resist` par branche, `no_affix` : modificateurs d'élite interdits), Flétris ordinaires (`ordinary` : poids, `min_level` niveau d'apparition, `max_alive` nombre maximal en vie) et apparitions par région (`spawn` : sortes et poids, part près/loin de la graine, nombre de nids, effet de la purification du Cœur). Les élites sont réglées dans `difficulty.json`. Les trois premières sortes sont les Flétris d'origine. |

## Les effets

Un nœud porte une liste `effects`. Chaque effet est d'une de ces cinq sortes.

### 1. Modifier une statistique

```json
{"stat": "damage", "op": "inc", "value": 0.05}
```

La valeur finale d'une statistique est :

```
(base + somme des add) × (1 + somme des inc) × produit des more + somme des flat
```

| `op` | Rôle | Affichage |
| --- | --- | --- |
| `add` | S'ajoute à la base, avant les multiplicateurs | `+10 Vie maximale` |
| `inc` | Pourcentage additif (0.05 = +5 %, une valeur négative réduit) | `+5 % Dégâts` |
| `more` | Multiplicateur indépendant (1.4 = ×1,4) | `Dégâts ×1,4` |
| `flat` | S'ajoute après les multiplicateurs | `+15 Épines` |

Dans `stats.json`, une statistique peut avoir `percent` (afficher les `add` en pourcentage), `min`, `max` (un nombre ou le nom d'une autre statistique, comme `armor_cap` pour l'armure), `inc_min` (réduction maximale) et `"round": "floor"` (valeur entière).

Le texte de l'infobulle est produit à partir de l'effet : il ne peut donc pas contredire ce que le nœud fait réellement. `"hidden": true` masque une ligne technique.

### 2. Donner une compétence active

```json
{"skill": "nova"}
```

L'identifiant renvoie à `skills.json`. Le comportement de la compétence reste écrit dans `scripts/player.gd` ; ses réglages sont dans les données.

Compétences actuelles : `nova` (Couronne d'épines), `cloud` (Nuage de spores), `bloom` (Floraison), et pour Ronce `fouet` (arc au corps à corps qui fait saigner), `racines` (immobilisent les ennemis à l'endroit visé) `volee` (Volée d'épines : éventail d'épines perforantes qui font saigner) et `saignee` (Saignée : fait éclater les saignements des ennemis proches en dégâts immédiats, une part soigne). Champs communs de `skills.json` :

| Champ | Rôle |
| --- | --- |
| `name`, `short`, `desc`, `color` | Nom, nom court (barre de compétences), texte de l'infobulle, couleur |
| `cooldown` | Recharge en secondes |
| `damage` | Facteur des dégâts de base du joueur |
| `branch` | Branche d'origine : les compétences de `ronce` gagnent +15 % de dégâts sur une terre ravivée de la région de Ronce (« se battre chez soi ») |
| `tags` | Familles d'attaque : `corps_a_corps`, `projectile`, `zone`. Chaque famille multiplie les dégâts par sa statistique (`melee_damage`, `projectile_damage`, `area_damage`) ; les graines du tir de base sont des `projectile` |

Les compétences acquises se rangent dans la barre de compétences (6 emplacements, dont `skill_slots` débloqués : 4 au départ, 6 au plus). Le rangement est gardé dans `Game.flags["barre"]`.

### 3. Réagir à un évènement

```json
{"on": "kill", "do": "reduce_cooldown", "target": "dash", "value": 0.3,
 "text": "Chaque ennemi vaincu réduit la recharge de l'esquive de 0,3 s."}
```

- `on` : `kill` (ennemi vaincu), `crit` (coup critique), `lethal_hit` (coup mortel reçu), `melee_hit` (coup au corps à corps, `base` = dégâts du coup), `bleed_tick` (à-coup de saignement toutes les 0,5 s, `base` = dégâts de l'à-coup), `root` (ennemi enraciné, `base` = dégâts du coup qui enracine), `hurt` (le joueur est touché, `base` = dégâts du coup), `dash` (le joueur esquive).
- `do` : l'action à lancer, avec ses paramètres.
- `cooldown` (facultatif) : durée en secondes avant que l'effet puisse se relancer.
- `text` (obligatoire) : la phrase affichée au joueur.

| Action | Paramètres | Effet |
| --- | --- | --- |
| `reduce_cooldown` | `target` (`dash` ou une compétence), `value` | Réduit une recharge |
| `spread_poison` | `radius`, `duration`, `color` | L'ennemi vaincu transmet son poison autour de lui |
| `explode` | `radius`, `factor`, `color` | Le coup touche aussi les ennemis proches |
| `survive` | `hp`, `invuln`, `label`, `color` | Le coup mortel laisse le joueur en vie |
| `apply_status` | `status` (`saignement` ou `enracine`), `value`, `duration`, `scale` | Pose un état sur l'ennemi de l'évènement. `saignement` : `value` dégâts par seconde (avec `"scale": "base"`, fraction des dégâts du coup). Durées multipliées par `bleed_duration` / `root_duration` |
| `heal` | `value` | Soigne une fraction de la vie maximale |
| `burst` | `radius`, `factor`, `at` (`player` par défaut, ou `enemy`), `color` | Onde d'épines autour du joueur ou de l'ennemi de l'évènement : `factor` × dégâts du joueur × dégâts de zone, rayon × taille des zones. Coup de Ronce |
| `status_area` | `status`, `value`, `duration`, `radius`, `at`, `scale` (`damage`) | Pose un état sur tous les ennemis de la zone (mêmes règles que `apply_status`) |
| `attack_salvo` | `count` | Salve de l'attaque de base tout autour du joueur, en `count` directions, avec sa forme et ses modificateurs actuels (par exemple `{"on": "hurt", "do": "attack_salvo", "count": 8, "cooldown": 0.6, "text": "…"}`) |

### États des ennemis

`enemy.apply_status(nom, valeur, durée)` : `saignement` (dégâts par seconde, cumulable 5 fois ; au-delà la piqûre la plus faible est remplacée) et `enracine` (immobile, frappe toujours au contact). La statistique `bleed` fait saigner à chaque coup du joueur (fraction des dégâts par seconde, 4 s × `bleed_duration`), comme `poison`.

### 4. Transformer une compétence (mutation)

```json
{"skill_mod": "nova", "param": "radius", "op": "more", "value": 1.4,
 "text": "Couronne d'épines : rayon ×1,4."}
```

Modifie un réglage d'une compétence de `skills.json`. `op` vaut `add`, `inc`, `more` (même calcul que pour une statistique : `(réglage + add) × (1 + inc) × more`) ou `set` (remplace la valeur, y compris par un texte ou un booléen, pour un réglage que le code de la compétence sait lire). `text` est obligatoire, sauf avec `"hidden": true` quand une autre ligne décrit déjà l'ensemble. Le code lit les réglages par `Game.skill("nova")` au moment du lancer.

### 5. Transformer l'attaque de base

```json
{"attack_form": "fouet"}
{"attack_mod": "fourche", "value": 1}
```

`attack_form` change la forme de l'attaque de base, `attack_mod` lui ajoute un modificateur. Les formes et les modificateurs sont décrits dans `attack.json` (voir « L'attaque de base »). Le texte de l'infobulle est produit à partir de `attack.json` ; `text` le remplace si besoin. Ces deux effets n'acceptent pas de condition.

### Conditions

Tout effet accepte une condition :

```json
{"stat": "damage", "op": "more", "value": 1.4, "if": {"state": "immobile", "min": 0.5}}
```

L'effet ne s'applique que si l'état vaut au moins `min`. États actuels : `immobile` (secondes passées sans bouger), et pour les évènements qui visent un ennemi (`kill`, `crit`, `melee_hit`, `bleed_tick`, `root`) : `cible_empoisonnee`, `cible_saignante` (nombre de piqûres) et `cible_enracinee` (secondes restantes).

## Grappes écrites à la main

Une branche peut déclarer des `clusters` : des groupes de nœuds écrits à la main, placés au milieu des petits nœuds générés. Le générateur écarte les petits nœuds et les notables générés qui les gênent (à moins de 0,62 anneau d'un nœud de grappe), puis recoud l'arbre pour que tout reste relié à la graine. Le reste de l'arbre ne bouge pas.

```json
"clusters": [{
  "id": "sang", "name": "Ronce sanglante", "ring": 3, "angle": 0.35,
  "entry": ["s1"],
  "nodes": [
    {"id": "s1", "type": "notable", "name": "Première épine", "at": [0, 0], "effects": [...]},
    {"id": "s2", "type": "mastery", "name": "Maîtrise du sang", "at": [0.7, 0.4], "links": ["s1"],
     "choices": [{"id": "a", "name": "...", "effects": [...]}, {...}, {...}]},
    {"id": "s3", "type": "mutation", "mutates": "nova", "at": [1.4, 0], "links": ["s2"],
     "choices": [{"name": "...", "effects": [...]}, {"name": "...", "effects": [...]}]},
    {"id": "s4", "type": "withered", "name": "...", "requires_flag": "ronce_boss_vaincu",
     "requires_text": "vaincs la Mère-Ronce.", "at": [2.1, -0.4], "links": ["s3"], "effects": [...]},
    {"id": "s5", "type": "graft", "at": [2.1, 0.4], "links": ["s3"]}
  ],
  "complete": {"effects": [...]}
}]
```

| Champ de la grappe | Rôle |
| --- | --- |
| `id`, `name` | Identifiant (unique dans la branche, sans `:` ni virgule) et nom affiché. |
| `ring`, `angle` | Point d'ancrage : l'anneau (1 à 12, décimales permises) et la fraction du secteur de la branche (0 = bord gauche, 1 = bord droit en regardant depuis la graine ; peut dépasser pour une grappe à la frontière de la branche voisine). |
| `entry` | Nœuds reliés aux nœuds générés voisins : le plus proche côté graine dans la branche, plus un second s'il y en a un à moins de 1,3 anneau. |
| `nodes` | Les nœuds (voir ci-dessous). Chacun doit rejoindre une entrée par les `links`. |
| `complete` | Facultatif : `effects` gagnés quand tous les nœuds de la grappe sont appris. |

Chaque nœud a un `id` local, un `type`, une position `at: [x, y]` en unités d'anneau par rapport à l'ancrage (x vers l'extérieur de l'arbre, y le long de l'anneau, dans le sens des aiguilles d'une montre) et des `links` vers d'autres nœuds de la grappe. Son identifiant stable de sauvegarde est `c:<branche>:<grappe>:<nœud>` (ou `key:<key>` pour un nœud clé). Les valeurs des effets sont prises telles quelles, sans la progression par anneau des nœuds générés.

| `type` | Champs propres | Comportement | Forme dans l'arbre |
| --- | --- | --- | --- |
| `small`, `notable` | `effects` (et `name` pour un notable) | Nœud ordinaire. | Cercle |
| `keystone` | `key`, `name`, `effects` ou `desc`, `excludes` facultatif | Nœud clé en plus des trois générés aux anneaux 4, 8 et 12. | Losange |
| `skill` | `skill` (ou un effet `{"skill": …}`) | Donne une compétence. Le nom par défaut est celui de la compétence. | Hexagone |
| `mutation` | `mutates` (compétence), 2 ou 3 `choices` | Verrouillé tant que la compétence n'est pas acquise. Un seul choix, définitif tant que le nœud reste appris (l'oublier permet de rechoisir). | Triangle |
| `mastery` | `name`, exactement 3 `choices` | Un bonus à choisir, modifiable ensuite sans rien dépenser. | Carré à trois points |
| `graft` | aucun effet | Emplacement qui reçoit une greffe de `grafts.json` (`Game.set_graft(id, greffe)`). La greffe n'agit que si l'emplacement est appris. | Anneau creux |
| `withered` | `name`, `effects`, `requires_flag`, `requires_text` facultatif | Verrouillé et couvert de cendre tant que `Game.flags[requires_flag]` n'est pas vrai. `requires_text` complète la phrase « Couvert de cendre : … ». | Cercle fissuré |
| `attack` | `name`, `effects` avec au moins un `attack_form` ou `attack_mod` | Change la forme ou le comportement de l'attaque de base. Icône `Art.icon("attaque_<forme>")`, ou `attaque_mod` s'il n'ajoute que des modificateurs. | Pointe de flèche (provisoire) |

Un choix s'écrit `{"id": "...", "name": "...", "effects": [...]}`. `id` est facultatif (par défaut la position du choix dans la liste) mais conseillé : c'est lui que la sauvegarde retient, et il permet de réordonner les choix plus tard. Tant qu'aucun choix n'est fait, le nœud ne donne que ses `effects` propres ; la fenêtre de choix s'ouvre à l'apprentissage, et le nœud pulse en doré tant que le choix reste à faire.

`excludes` (sur n'importe quel nœud de grappe) liste des nœuds incompatibles : un identifiant local de la même grappe, la `key` d'un nœud clé ou un identifiant stable complet. L'exclusion vaut dans les deux sens : apprendre l'un verrouille l'autre.

Une grappe ne doit recouvrir ni la graine, ni un nœud clé généré (anneaux 4, 8 et 12, au milieu du secteur), ni une autre grappe : `check_data.gd` le signale.

## L'attaque de base

L'attaque de base part toute seule à sa cadence. Elle a une **forme** et des **modificateurs**, donnés par les nœuds (`attack_form`, `attack_mod`), les choix des maîtrises et les greffes. Rien n'est sauvegardé en plus : l'attaque est recalculée depuis les nœuds appris (`Game.attack()`, `scripts/attack.gd`). Sans aucun effet, c'est la forme `start` (`graine`), avec exactement les chiffres de l'ancien tir.

```json
{
  "start": "graine",
  "forms": {"fouet": {"name": "Fouet", "desc": "…", "kind": "melee", "tags": ["corps_a_corps"], "branch": "ronce",
                      "element": "epine", "priority": 2, "damage": 1.5, "rate": 0.8, "range": 135, "arc": 1.9, "knockback": 12}},
  "mods": {"fourche": {"name": "Fourche", "text": "… +{v} branche(s).", "stack": "sum", "forms": ["graine", "echarde", "ronce_vive"], "angle": 0.42, "factor": 0.6}}
}
```

**Champs d'une forme**

| Champ | Rôle |
| --- | --- |
| `name`, `desc` | Nom et phrase de l'infobulle. |
| `kind` | `projectile` (éventail de projectiles) ou `melee` (coup en arc autour du joueur). |
| `tags` | Familles du coup : chacune multiplie les dégâts par sa statistique (`projectile_damage`, `melee_damage`, `area_damage`), comme pour les compétences. `trap_tags` : familles du piège d'une ronce vive. |
| `branch` | `ronce` : coup de Ronce (résistance des ennemis du roncier, bonus « se battre chez soi »). |
| `element` | Élément de la charte pour le dessin (`seve`, `epine`, `saignement`…). |
| `priority` | Règle de priorité entre formes, voir plus bas. |
| `damage`, `rate`, `range` | Facteur des dégâts de base, facteur de la vitesse d'attaque (`fire_rate`), portée en pixels. |
| `speed`, `spread`, `pierce`, `size` | Projectiles : vitesse, écart entre projectiles de l'éventail (la statistique `projectiles` en donne le nombre), perforation ajoutée à `pierce`, facteur de `projectile_size`. |
| `burst`, `burst_gap`, `jitter` | Rafale : nombre de tirs par attaque, écart entre eux (s), petit écart d'angle d'un tir à l'autre. |
| `arc`, `knockback` | Corps à corps : ouverture de l'arc (radians), recul. |
| `trap_radius`, `trap_duration`, `trap_damage`, `trap_tick`, `trap_root`, `trap_max` | Ronce vive : le piège planté là où la graine tombe (rayon × `area`, durée, dégâts par seconde en part des dégâts de base, à-coups, immobilisation à l'entrée, nombre de pièges à la fois). |

**Règle de priorité.** Une seule forme est active. La `priority` la plus haute l'emporte : celle de l'effet si elle est écrite (`{"attack_form": "fouet", "priority": 5}`, pour un nœud clé), sinon celle de la forme dans `attack.json` (la graine vaut 0, les autres 2). À égalité, le nœud le plus loin de la graine (anneau le plus grand) l'emporte : sur un même chemin, on l'a forcément pris après. À égalité encore, la dernière source dans l'ordre du moteur.

**Modificateurs.** `{"attack_mod": "<nom>", "value": v}`. Tous se cumulent selon leur `stack` : `sum` additionne les valeurs, `min` garde la plus petite (une attaque sur N), `max` la plus grande. `forms` limite les formes sur lesquelles le modificateur agit (toutes par défaut) ; l'infobulle signale un modificateur sans effet sur la forme active. Dans `text`, `{v}` est la valeur, `{p}` la valeur en pourcentage, `{n}` le N d'« une sur N », `{f}` le facteur.

| Modificateur | `value` | Effet |
| --- | --- | --- |
| `fourche` | branches en plus | Au premier coup, le projectile se divise (`angle`, dégâts × `factor`). |
| `ricochet` | rebonds | Quand il ne perfore plus, le projectile rebondit vers l'ennemi le plus proche (`reach`, dégâts × `factor` à chaque rebond). |
| `eclat` | facteur de dégâts | Un ennemi tué par l'attaque éclate en `count` épines. |
| `saignement` | part des dégâts par seconde | Chaque coup fait saigner (`duration` × durée du saignement). Vaut aussi pour les ennemis qui traversent une ronce vive. |
| `enracine` | chance | Chance d'enraciner l'ennemi touché (`duration` × durée d'immobilisation), plafonnée à `cap`. |
| `trainee` | part des dégâts par seconde | Le projectile sème une touffe d'épines au sol tous les `every` pixels. |
| `renforcee` | N | Une attaque sur N est renforcée : dégâts × `factor` (le plus grand `factor` écrit sur les effets, sinon celui d'`attack.json`), taille × `size`, `extra` projectiles en plus, arc plus large. |
| `taille`, `portee` | +x % | Taille des projectiles, du piège et de l'arc ; portée (durée de vol, allonge du fouet). |
| `repetition` | coups en plus | L'attaque repart après `delay` secondes (le fouet frappe deux fois). |
| `volee` | N | Une attaque sur N part en couronne tout autour du joueur (`count` directions). |
| `poison` | part des dégâts par seconde | Chaque coup empoisonne (`duration`). |

L'infobulle d'un nœud montre l'aperçu avant → après de l'attaque (« Attaque : Graines → Fouet », « Attaque : + fourche… »), comme pour les statistiques. Pour essayer une attaque sans passer par l'arbre : `tools/godot.sh --xvfb -- --attack=fouet,repetition:1,saignement:0.3` (marche aussi avec `--autotest`). `tools/godot.sh --headless --fixed-fps 60 -s res://tests/attack_test.gd` teste le moteur.

## Résonance de branche

```json
"resonance": [
  {"count": 10, "name": "Ronce éveillée", "effects": [{"stat": "damage", "op": "inc", "value": 0.1}]},
  {"count": 25, "effects": [...]},
  {"count": 50, "effects": [...]}
]
```

Chaque palier donne ses effets dès que `count` nœuds de la branche sont appris (nœuds de grappe compris, la graine ne compte pas). Les paliers se cumulent. L'infobulle de chaque nœud de la branche rappelle le prochain palier.

## Greffes

`grafts.json` : `{"<id>": {"name", "desc", "sources", "shape", "color", "effects": [...]}}` (les clés qui commencent par `_` sont des commentaires).

| Champ | Rôle |
| --- | --- |
| `sources` | D'où la greffe peut venir : `autel`, `boss`, `secret`, `elite`, `quete`. `Game.roll_graft(source)` tire une greffe de cette source, ni possédée ni déjà au sol (les élites en font tomber une avec `main.drop_graft(pos)`). |
| `shape`, `color` | Dessin au sol, dans l'inventaire et dans l'emplacement : `feuille`, `epine`, `racine`, `fleur` ou `coeur`. |
| `effects` | Mêmes effets qu'un nœud. Une greffe n'agit que posée dans un emplacement appris. |

Chaque greffe existe en un exemplaire. On la trouve au sol (`graft_pickup.gd`), elle entre dans l'inventaire (`Game.give_graft(id)`, signal `Game.graft_found`), puis on la pose dans l'écran de l'arbre : glisser depuis l'inventaire (en bas à gauche) jusqu'à un emplacement, ou clic sur la greffe puis sur l'emplacement. Un clic sur un emplacement appris et occupé retire la greffe. L'infobulle de l'emplacement montre l'effet de la greffe tenue (statistiques avant → après). En code : `Game.place_graft(emplacement, greffe)` (greffe possédée, déplacée si elle était ailleurs), `Game.set_graft` (outil bas niveau des tests).

## Points et greffes du monde

`rewards.json` décrit ce que donne chaque région, hors des niveaux :

```json
"boss":  {"ronce": {"points": 2, "graft": "greffe_mere"}},
"coeur": {"ronce": {"points": 1}},
"altars":  [{"id": "ronce_1", "region": "ronce", "name": "Autel des épines", "dist": 820, "side": -0.62, "points": 1, "graft": "greffe_soeurs"}],
"secrets": [{"id": "ronce", "region": "ronce", "name": "La graine enfouie", "dist": 2380, "side": 0.95, "points": 1, "graft": "greffe_graine"}]
```

Un autel (`altar.gd`) est placé à `dist` pixels de la graine, `side` (de -1 à 1) le décale vers un bord du secteur de la région ; il est poussé hors des buissons. On le devine à 520 px, on le ravive en s'y tenant 1,5 s (2,5 s et 230 px pour un secret, presque invisible). `graft` vide : une greffe tirée parmi celles de la source.

Les points passent par `Game.grant_points(n, source, clé)` : une même clé ne donne qu'une fois par partie (drapeau `points_<clé>`), le HUD annonce la source (signal `Game.points_granted`). Drapeaux posés : `autel_<id>_vu` et `secret_<id>_vu` (aperçu), `autel_<id>` et `secret_<id>` (ravivé), `points_ronce_boss`, `points_ronce_coeur`, `points_hors_niveau` (total). Les autels et secrets sont dans les groupes `autel` et `secret` (propriété `id`).

## Objectifs

`objectives.json` : `{"ending_flag": "...", "objectives": [...]}`. Chaque objectif a un `id`, un `title`, un `text`, `"main": true` pour la suite principale (ordre du fichier), une `condition`, éventuellement une `target` (cible de la flèche et de la carte) et une `reward` (`text` affiché, `points` donnés une seule fois). Un objectif est accompli dès que sa condition est vraie, dans n'importe quel ordre ; l'objectif en cours est le premier principal qui ne l'est pas, après la dernière étape marquée `"milestone": true` déjà accomplie (le Cœur, le boss) : un joueur qui purifie le Cœur avant d'avoir ravivé un sanctuaire n'est pas renvoyé en arrière, et l'étape sautée reste ouverte dans le journal (« étape passée »). Les drapeaux qui finissent par `_vu` (autel ou secret seulement aperçu) ne comptent pas dans `flag_count`.

| `condition.type` | Vrai quand |
| --- | --- |
| `nodes` (`count`) | au moins `count` nœuds sont appris (la graine ne compte pas) |
| `flag` (`flag`) | `Game.flags[flag]` est vrai |
| `flag_count` (`prefix`, `count`, `exclude`) | au moins `count` drapeaux vrais commencent par `prefix` (sauf ceux de `exclude`) |
| `counter` (`flag`, `count`) | `Game.flags[flag]` vaut au moins `count` |
| `keystone` (`branch`) | un nœud clé de la branche est appris |

`target.type` : `none`, `seed`, `heart`, `arena`, ou `group` (le plus proche des nœuds du groupe `group` dont le drapeau `<done_prefix><id>` n'est pas levé). `needs_group` masque l'objectif tant que le groupe est vide (le monde n'a pas encore de sanctuaire ou d'autel).

**Ce que les autres systèmes doivent poser** : `sanctuaire_<id>` à la ravivation d'un sanctuaire (le sanctuaire de la graine s'appelle `sanctuaire_graine` et ne compte pas), `autel_<id>` à la découverte d'un autel, `secret_<id>` pour un secret, `ronce_coeur_purifie` et `ronce_boss_vaincu` (déjà posés). Les sanctuaires et les autels se rangent dans les groupes `sanctuaire` et `autel` (nœuds Node2D avec une propriété `id`) pour que la carte et la flèche les trouvent. Un élite vaincu émet `main.elite_killed(enemy)` : `Objectives` le compte dans `elites_tuees`. Les points des objectifs facultatifs passent par `Game.grant_points(n, "quete")` quand il existe.

La fin de la tranche se déclenche cinq secondes après `ending_flag` ; elle pose `fin_ronce_vue` et ne revient plus. `tools/godot.sh --headless -s res://scripts/check_data.gd` contrôle le fichier.

## Ajouter du contenu

- **Un nœud clé ou modifier une branche** : éditer `branches/<id>.json`. Les nœuds clés sont placés dans l'ordre aux anneaux 4, 8 et 12.
- **Une grappe, une maîtrise, une mutation, un nœud flétri** : ajouter une entrée à `clusters` dans la branche (voir « Grappes écrites à la main »).
- **Une statistique** : l'ajouter dans `stats.json`, puis la lire dans le code avec `Game.stats["nom"]`.
- **Une action ou un évènement** : écrire l'action dans `scripts/effect_actions.gd` et la déclarer dans `Content.ACTIONS` (`scripts/content.gd`) ; pour un évènement, l'ajouter à `Content.EVENTS` et appeler `Game.fire("nom", {...})` à l'endroit voulu.
- **Un état pour les conditions** : le déclarer dans `conditions.json` et le tenir à jour avec `Game.set_state("nom", valeur)`.

Pour une version exportée du jeu, ajouter `*.json` aux fichiers à inclure dans les réglages d'export de Godot.

## Équilibrage des builds

`builds.json` décrit des builds types : une liste de nœuds visés (`targets`, identifiants stables comme `key:nova` ou `c:ronce:sang:s1`), les choix des maîtrises et mutations (`choices`) et la façon de jouer du robot (`style` : `distance`, `melee` pour aller au contact, `tank` pour rester au milieu des ennemis). Le robot passe au niveau 20, apprend à chaque point le prochain nœud du plus court chemin vers la première cible pas encore acquise, puis complète avec les nœuds de Ronce les plus proches de la graine.

```
tools/godot.sh --headless --fixed-fps 60 -- --autotest=build:fouet --build-time=180 --build-level=20 --seed=1
tools/balance.sh                 # epines, fouet et saignement, graines 1 à 3, sans affichage et en parallèle
SEEDS="1 2 3 4 5 6 7 8 9 10" tools/balance.sh
```

Pendant la mesure, le niveau reste figé (mêmes points et même difficulté pour tous les builds) et une mort ne vide pas l'écran : le robot repart sur place avec toute sa vie, et chaque mort compte 10 s de plus dans le temps de jeu. Le score est le nombre d'ennemis vaincus par minute ; `tools/balance.sh` échoue si le meilleur build dépasse le moins bon de plus de 30 %. Une cible absente de l'arbre est ignorée et signalée.
