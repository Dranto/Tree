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
| `borders/<a>-<b>.json` | Une frontière hybride entre deux branches voisines : grappes à cheval sur la limite des deux secteurs. Voir « Frontières hybrides ». |
| `grafts.json` | Les greffes : objets à poser dans un emplacement de greffe de l'arbre (nom, effets, d'où elles viennent, dessin). |
| `regions/<id>.json` | Une région du monde, tout entière : sol, décor, apparitions, sanctuaires, autels, secret, Cœur, boss, fin. Voir « Régions ». |
| `skills.json` | Réglages des compétences actives (recharge, rayon, dégâts, texte). |
| `builds.json` | Builds types joués par le robot d'équilibrage (`tools/balance.sh`), chacun avec sa branche (`branch`). |
| `conditions.json` | États utilisables dans un `if`, avec leur texte d'affichage. |
| `difficulty.json` | Difficulté (`scripts/difficulty.gd`) : menace des ennemis (`threat` : par niveau, selon la profondeur dans la région, par Cœur purifié, plafond), effet de la menace sur leurs statistiques (`scaling`), courbe d'expérience et durée visée par niveau (`xp`), apparitions (`spawn` : cadence, plafond d'ennemis et salves près de la graine et au fond de la région), modes Facile / Normal / Difficile (`modes`), élites (`elites` : chance près/loin, niveau minimal, nombre en vie, chance d'un second modificateur, multiplicateurs de vie, dégâts, taille et expérience, chance de greffe, sortes exclues, et `affixes` : nom affiché, couleur, poids et réglages de chaque modificateur). Vérifiée par `check_data.gd` ; le rythme se mesure avec `tools/balance.sh --run`. |
| `objectives.json` | Les objectifs : principaux (dans l'ordre), facultatifs, chacun rattaché à sa région, et la fin de l'aventure. Voir « Objectifs ». |
| `attack.json` | L'attaque de base du Porte-Graine (`scripts/attack.gd`) : forme de départ, formes (graine, échardes, fouet, ronces vives, spores lobées, dards fongiques) et modificateurs cumulables, réglage des formes en écho. Voir « L'attaque de base ». |
| `synergies.json` | Synergies de l'attaque de base : bonus quand deux formes, familles ou modificateurs se croisent (`scripts/attack.gd`). Voir « L'attaque de base ». |
| `feel.json` | Ressenti du combat (`scripts/fx.gd`), réglages d'image seulement (aucune puissance) : arrêt sur image dosé par coup (`hitstop` : critique, coup lourd, critique sur un boss, morts, mort d'élite, changement de phase et mort d'un boss ; un arrêt « fort » passe outre le délai), secousse (`shake`), seuil d'un coup lourd (`heavy`, part de la vie maximale), recul visible et éclair du coup (`recoil`), éclats et étoile des critiques (`sparks`), traits et voile des morts (`death`). Les options `Settings.shake_strength()`, `flash_strength()` et `hitstop_strength()` multiplient ces valeurs. Vérifié par `tests/feel_test.gd`, qui contrôle aussi que toute attaque annoncée dure au moins `Anim.DUREE["annonce_min"]`. |
| `enemies.json` | Sortes d'ennemis (`kinds` : statistiques, comportement `chase`/`shooter`/`charger`/`nest`/`kite`/`guard`/`bomber`/`puddler`/`splitter`/`lichen` et ses réglages, `region`, `resist` par branche, `poison_resist` : part du poison ignorée, `no_affix` : modificateurs d'élite interdits, `art` : silhouette dessinée par `scripts/enemy_art/<art>.gd` au lieu de `fletri_art.gd`), Flétris ordinaires (`ordinary` : poids, `min_level` niveau d'apparition, `max_alive` nombre maximal en vie) Le comportement `<nom>` est le fichier `scripts/enemy_behaviors/<nom>.gd` (classe `EnemyBehavior`). Les apparitions de chaque région sont dans son fichier (`regions/<id>.json`, `spawn`). Les élites sont réglées dans `difficulty.json`. Les trois premières sortes sont les Flétris d'origine. |

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

Compétences actuelles : `nova` (Couronne d'épines), `cloud` (Nuage de spores ; `follow` : le nuage naît sur le joueur et le suit), `bloom` (Floraison), pour Spore `vesse` (Vesse-de-loup : champignon-piège planté au point visé, `max` à la fois, armé après `arm` s, éclate quand un ennemi entre dans `trigger` px ou au bout de `life` s : coup de zone puis nuage `cloud_damage` pendant `cloud_duration` s ; `poison` : l'éclatement empoisonne), `essaim` (Essaim : une spore vivante touche l'ennemi le plus proche du point visé, l'empoisonne — `poison` × dégâts par seconde pendant `duration` s — puis saute `jumps` fois vers le plus proche à moins de `reach` px, un saut toutes les `hop` s ; `split` : il se divise en deux au premier ennemi) et `eclosion` (Éclosion : chaque ennemi empoisonné à moins de `radius` px subit `burst` × le poison qui lui restait, qui est consommé sauf la part `keep` ; ses spores empoisonnent les ennemis à moins de `splash` px), et pour Ronce `fouet` (arc au corps à corps qui fait saigner), `racines` (immobilisent les ennemis à l'endroit visé) `volee` (Volée d'épines : éventail d'épines perforantes qui font saigner) et `saignee` (Saignée : fait éclater les saignements des ennemis proches en dégâts immédiats, une part soigne). ; pour Vent `tornade` (une tornade avance vers l'endroit visé, aspire et blesse par à-coups : `damage` par seconde, `duration`, `speed`, `radius`, `tick`, `pull` ; mutations `count`, `speed` 0, `orbit`), `ruee` (Ruée : le joueur fend l'air sur `length` pixels, intouchable, et frappe une fois chaque ennemi du passage ; `dash` vrai : compte comme une esquive ; `wake` : une tornade naît à l'arrivée) et `appel_air` (Appel d'air : aspire les ennemis du `radius` vers l'endroit visé pendant `pull_time`, puis éclate ; `root` : immobilise ensuite) ; pour Sève `liane` (Liane buveuse : `count` lianes s'accrochent aux ennemis les plus proches du point visé, dans `radius`, pendant `duration` s ; à-coups toutes les `tick` s, `drain` × les dégâts infligés soignent le joueur ; une liane casse au-delà de `leash` px ; `jump` : elle saute au plus proche quand son ennemi meurt ; `root` : immobilise ; un ennemi `"no_drain": true` dans `enemies.json`, ou un boss dont le script déclare `no_drain`, est blessé sans rien rendre), `fontaine` (Fontaine de sève : une source de `radius` px pendant `duration` s ; dedans, le joueur régénère `regen` × sa vie maximale par seconde et les ennemis sont blessés par à-coups ; `follow` : elle suit le joueur ; `geyser` : à la fin, coup de zone de `geyser` × dégâts) et `cocon` (Cocon de sève : bouclier de `shield` × la vie maximale pendant `duration` s, qui boit les coups après l'armure ; à la fin ou percé, le reste soigne (`convert` ×) et le cocon éclate : `damage`, `radius`, `knockback` ; `reflect` : part des dégâts absorbés renvoyée à l'agresseur) ; pour Aube `aurore` (Aurore : onde de lumière autour du joueur qui blesse et éblouit les ennemis du `radius` — `dazzle` de chance de critique en plus contre eux pendant `dazzle_time` s ; `waves` 2 : une seconde onde à 60 % ; `heal` : soin par ennemi touché, 5 au plus), `prisme` (Prisme : cristal posé au point visé, à `range` px au plus, pendant `life` s ; toutes les `every` s il tire `beams` rayon(s) sur les ennemis les plus proches à moins de `reach` px ; `max` à la fois ; `dazzle` : chance d'éblouir ; `follow` : il suit le joueur) et `lance_aube` (Lance d'aube : après `windup` s, un rayon de `length` × `width` px vers le point visé ; `crit_dazzled` de chance de critique en plus contre un ennemi ébloui ; `dazzle` : éblouit ce qu'elle touche pendant ces secondes ; `repeat` : lances en plus à 70 %) ; pour Racine `ecorce` (Bouclier d'écorce : bouclier de `shield` × la vie maximale pendant `duration` s, bu après l'armure et le cocon ; chaque coup absorbé renvoie `riposte` × les dégâts de la compétence à l'agresseur ; à la fin ou percé, l'écorce éclate : `damage`, `radius`, `knockback` ; `regrow` : le bouclier repousse de cette part de la vie maximale par seconde), `ancrage` (Ancrage : le joueur prend racine `duration` s — il ne marche plus, ou à `walk` × sa vitesse ; l'esquive arrache les racines ; état `enracine` des conditions vrai pendant ce temps — et toutes les `tick` s ses racines blessent et immobilisent (`root_duration` × durée d'immobilisation) les ennemis du `radius` autour de lui ; `heal` : soin par ennemi tenu, 10 au plus ; `uproot` : à la fin, coup de zone de `uproot` × dégâts) et `pieux` (Pieux : `count` pieux jaillissent l'un après l'autre (`gap` s) en ligne vers le point visé, à `range` px au plus ; chacun blesse et cloue `root_duration` s les ennemis du `radius` ; `ring` : en cercle autour du joueur ; `stay` : ils restent ces secondes et blessent ce qui les frôle). Un ennemi `"no_root": true` dans `enemies.json` n'est jamais immobilisé (racines, pieux, ancrage, modificateur `enracine`). Le vent ne déplace pas un ennemi ancré, un boss, ni une sorte marquée `"no_push": true` dans `enemies.json` (`scripts/vent.gd`). Champs communs de `skills.json` :

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
| `cloud` | `radius`, `duration`, `factor`, `at` | Nuage de spores au sol autour du joueur ou de l'ennemi (`at`: `enemy`) : `factor` × dégâts du joueur × dégâts de zone par seconde, et un peu de poison, pendant `duration` s (rayon × taille des zones). Coup de Spore |
| `gust` | `radius`, `factor`, `push`, `at` | Rafale de Vent autour du joueur ou de l'ennemi : `factor` × dégâts du joueur × dégâts de zone, et recul de `push` pixels |
| `tornado` | `factor`, `at` | Fait naître une tornade (réglages de `tornade`, dégâts et durée × `factor`) sur le joueur ou l'ennemi de l'évènement, même sans la compétence |
| `ray` | `factor`, `reach` | Rayon d'Aube : part de l'ennemi de l'évènement vers l'ennemi le plus proche à moins de `reach` px (260 par défaut) : `factor` × dégâts du joueur × dégâts des projectiles. Coup d'Aube |
| `attack_salvo` | `count` | Salve de l'attaque de base tout autour du joueur, en `count` directions, avec sa forme et ses modificateurs actuels (par exemple `{"on": "hurt", "do": "attack_salvo", "count": 8, "cooldown": 0.6, "text": "…"}`) |

### États des ennemis

`enemy.apply_status(nom, valeur, durée)` : `saignement` (dégâts par seconde, cumulable 5 fois ; au-delà la piqûre la plus faible est remplacée), `enracine` (immobile, frappe toujours au contact) et `ebloui` (Aube : `valeur` = chance de critique en plus contre lui, il avance 25 % moins vite et frappe 25 % moins fort au contact ; un boss n'en prend que la moitié, 2 s au plus). `main.dazzle_of(e)` donne le bonus en cours. `status_area` et `apply_status` savent poser `ebloui`. La statistique `bleed` fait saigner à chaque coup du joueur (fraction des dégâts par seconde, 4 s × `bleed_duration`), comme `poison`.

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

L'effet ne s'applique que si l'état vaut au moins `min`. `if` peut aussi être une liste de conditions qui doivent toutes être vraies (par exemple « la cible saigne et elle est empoisonnée » : `"if": [{"state": "cible_saignante", "min": 1}, {"state": "cible_empoisonnee"}]`) ; l'infobulle les relie par « et ». États actuels : `immobile` (secondes passées sans bouger), `en_mouvement` (secondes passées à bouger sans s'arrêter), `sous_cocon` (1 tant que le Cocon de sève tient), et pour les évènements qui visent un ennemi (`kill`, `crit`, `melee_hit`, `bleed_tick`, `root`) : `cible_empoisonnee`, `cible_saignante` (nombre de piqûres), `cible_enracinee` (secondes restantes) et `cible_eblouie` (1 si la cible est éblouie).

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

## Frontières hybrides

Entre deux branches voisines, une frontière mêle les deux : ses grappes sont à cheval sur la limite des deux secteurs, ses nœuds ont les couleurs des deux branches et lisent les états des deux (par exemple des épines qui empoisonnent entre Ronce et Spore). Une frontière par fichier, `data/borders/<a>-<b>.json`, où `<a>` et `<b>` sont deux branches **voisines** dans l'ordre de `tree.json` (`ronce-spore`, `spore-seve`, `seve-vent`, `vent-aube`, puis `aube-racine` et `racine-ronce`).

```json
{
  "id": "ronce-spore",
  "between": ["ronce", "spore"],
  "name": "Frontière Ronce–Spore",
  "theme": "Épines empoisonnées",
  "clusters": [
    {"id": "dard", "name": "Ronce vénéneuse", "ring": 1.8, "angle": 0, "entry": ["d1", "d2"],
     "nodes": [
       {"id": "d1", "type": "small", "name": "Épine moisie", "at": [0, -0.5], "effects": [...]},
       {"id": "d2", "type": "small", "name": "Dard sanglant", "at": [0, 0.5], "effects": [...]},
       {"id": "d5", "type": "notable", "name": "Plaie infectée", "at": [1.0, 0], "links": ["d1", "d2"], "effects": [...]}
     ]}
  ]
}
```

| Champ | Rôle |
| --- | --- |
| `id` | `<a>-<b>`, comme le nom du fichier, les deux branches dans l'ordre de `tree.json` (la seconde suit la première dans le sens des aiguilles d'une montre). |
| `between` | Les deux branches. Elles doivent être voisines : `check_data.gd` refuse une frontière entre deux secteurs qui ne se touchent pas, et deux fichiers pour la même paire. |
| `name`, `theme` | Nom affiché et thème (commentaire). |
| `clusters` | Les grappes, au format des « Grappes écrites à la main », à une différence près : `angle` est l'écart du point d'ancrage à la limite, en fraction de secteur (0 : sur la limite, négatif du côté de `<a>`, entre -0,5 et 0,5). `y` négatif va vers `<a>`, `y` positif vers `<b>`. |

Chaque nœud appartient à la branche du secteur où il tombe (un nœud posé exactement sur la limite va à `<a>` ; `"side": "<branche>"` l'impose) et porte l'autre branche dans `border`. Règles :

- **Résonance : un nœud de frontière compte pour les deux branches** (choix du jalon 9 : une frontière fait avancer les deux résonances, ce qui rend un build hybride viable sans pénaliser celui qui reste dans une branche). Le résumé du personnage le compte aussi dans les deux branches.
- **Identifiant de sauvegarde** : `c:<frontière>:<grappe>:<nœud>` (par exemple `c:ronce-spore:dard:d5`), ou `key:<key>` pour un nœud clé.
- **Placement** : les nœuds générés qui gênent sont écartés comme pour une grappe de branche. Une grappe de branche voisine ne s'en trouve pas déformée : un nœud écarté par une frontière seulement continue de borner son écartement.
- **Accessibilité** : `check_data.gd` vérifie que chaque grappe de frontière a des nœuds des deux côtés de la limite et qu'elle est reliée aux deux branches (au moins une entrée de chaque côté, comme `"entry": ["d1", "d2"]`).
- **Dessin** : un nœud de frontière prend la couleur de sa branche mêlée d'un peu de l'autre (`SkillTree.BORDER_MIX`) et un anneau en deux moitiés, chacune à la couleur de la branche qui est de son côté (`TreeArt.border_seam`). L'infobulle indique « frontière X et Y » et le prochain palier de résonance des deux branches.
- **Robots** : les builds automatiques d'une seule branche (arène de boss, banc, robot de zone) ignorent les nœuds de frontière ; un build de `builds.json` peut les viser par leur identifiant.

Frontières actuelles (25 nœuds chacune : une couture de 12 nœuds avec un notable et une maîtrise, une couronne de 13 nœuds près du bord avec deux notables et un nœud clé) : Ronce–Spore (épines empoisonnées), Spore–Sève (humus : le poison qui soigne), Sève–Vent (la sève qui court : `en_mouvement`, `sous_cocon`), Vent–Aube (vent solaire : critiques en mouvement, esquive qui éblouit).

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
| `kind` | `projectile` (éventail de projectiles), `melee` (coup en arc autour du joueur) ou `beam` (rayon instantané qui traverse tout jusqu'à la portée : `width` sa largeur, `spread` l'écart entre rayons, la statistique `projectiles` leur nombre). |
| `crit` | Chance de critique ajoutée aux coups de la forme (le rayon d'aube vise juste). |
| `tags` | Familles du coup : chacune multiplie les dégâts par sa statistique (`projectile_damage`, `melee_damage`, `area_damage`), comme pour les compétences. `trap_tags` : familles du piège d'une ronce vive. |
| `branch` | Branche du coup (`ronce`, `spore`) : résistance des ennemis de sa région, bonus « se battre chez soi ». |
| `element` | Élément de la charte pour le dessin (`seve`, `epine`, `saignement`…). |
| `priority` | Règle de priorité entre formes, voir plus bas. |
| `damage`, `rate`, `range` | Facteur des dégâts de base, facteur de la vitesse d'attaque (`fire_rate`), portée en pixels. |
| `speed`, `spread`, `pierce`, `size` | Projectiles : vitesse, écart entre projectiles de l'éventail (la statistique `projectiles` en donne le nombre), perforation ajoutée à `pierce`, facteur de `projectile_size`. |
| `burst`, `burst_gap`, `jitter` | Rafale : nombre de tirs par attaque, écart entre eux (s), petit écart d'angle d'un tir à l'autre. |
| `arc`, `knockback` | Corps à corps : ouverture de l'arc (radians), recul. |
| `lob`, `burst_radius`, `cloud_radius`, `cloud_duration`, `cloud_damage`, `cloud_tick`, `cloud_max` | Spores lobées : la spore vole en cloche jusqu'à la cible (au plus la portée), sans rien toucher en vol ; à l'arrivée elle blesse tout dans `burst_radius` (× `area`, × `taille`) et laisse un petit nuage (`cloud_damage` : part des dégâts du coup par seconde). |
| `trap_radius`, `trap_duration`, `trap_damage`, `trap_tick`, `trap_root`, `trap_max` | Ronce vive : le piège planté là où la graine tombe (rayon × `area`, durée, dégâts par seconde en part des dégâts de base, à-coups, immobilisation à l'entrée, nombre de pièges à la fois). |

**Formes cumulées (échos).** Toutes les formes acquises tirent. La **forme principale** est choisie par la règle de priorité : la `priority` la plus haute l'emporte (celle de l'effet si elle est écrite, `{"attack_form": "fouet", "priority": 5}`, sinon celle de la forme dans `attack.json` : la graine vaut 0, les autres 2) ; à égalité, le nœud le plus loin de la graine (anneau le plus grand) ; à égalité encore, la dernière source dans l'ordre du moteur. Elle tire à la cadence du joueur, vers sa cible, et fixe la portée de l'attaque automatique. Chaque **autre forme acquise tire en écho** (`Game.attack()["echoes"]`) : avec ses propres chiffres et à sa propre cadence (`rate` × `fire_rate`), vers la cible du joueur si elle est à sa portée, sinon vers l'ennemi le plus proche à sa portée ; sans ennemi à sa portée, elle attend. `"echo": {"damage": 1.0, "offset": 0.5}` dans `attack.json` : part des dégâts des échos (1 = plein bonus ; `echo_damage` sur une forme passe devant) et décalage de leur premier tir (part de leur recharge). La graine de départ disparaît dès qu'une forme est acquise. Les modificateurs agissent sur toutes les formes où ils s'appliquent (`forms`).

**Modificateurs.** `{"attack_mod": "<nom>", "value": v}`. Tous se cumulent selon leur `stack` : `sum` additionne les valeurs, `min` garde la plus petite (une attaque sur N), `max` la plus grande. Tous les modificateurs agissent sur toutes les formes (aucun n'a plus de `forms`, qui reste possible pour limiter un futur modificateur ; l'infobulle signale alors un modificateur sans effet sur toutes les formes actives). Ceux qui étaient pensés pour une sorte de forme prennent une forme commune au **premier ennemi touché** par un tir (`attack.gd › first_hit`) : `fourche` lance des éclats en éventail depuis l'impact (coup au corps à corps, spore lobée) ou des rayons obliques (rayon) ; `ricochet` et `saut` font passer le coup d'ennemi en ennemi (chaîne, `reach` et `factor` du modificateur) quand la forme n'est pas un projectile qui s'arrête ; `trainee` pose une touffe d'épines au point d'impact (un projectile en sème aussi en vol) ; `refraction` fait partir des rayons obliques de l'impact ; `secousse` soulève le sol au point d'impact. Ce qui en naît ne refait pas ces effets (pas de boucle). `melee_arc_per_projectile` (0,25) : au corps à corps, chaque projectile en plus (statistique `projectiles`) ouvre l'arc de 25 %. Dans `text`, `{v}` est la valeur, `{p}` la valeur en pourcentage, `{n}` le N d'« une sur N », `{f}` le facteur.

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
| `saut` | sauts | Quand il ne perfore plus, le projectile saute vers l'ennemi empoisonné le plus proche (`reach`, dégâts × `factor`), avant tout ricochet. |
| `bouffee` | part des dégâts par seconde | Un ennemi tué par l'attaque libère un petit nuage de spores (`radius`, `duration`, `max`). |
| `elan` | +x % | Tant que le joueur bouge (ou vient de bouger), l'attaque fait x % de dégâts en plus (Vent). |
| `repousse` | pixels | Chaque coup repousse l'ennemi touché, à l'opposé du joueur (Vent). |
| `eblouit` | chance | Chance d'éblouir l'ennemi touché (`duration` s, `crit` de chance de critique en plus contre lui), plafonnée à `cap` (Aube). |
| `refraction` | rayons | Rayon d'aube seulement : au premier ennemi touché, le rayon se brise en rayons obliques (`angle`, longueur × `length`, dégâts × `factor`). |
| `incandescence` | +x % | Les coups critiques de l'attaque font x % de dégâts en plus (Aube). |
| `sangsue` | part des dégâts | Chaque coup de l'attaque rend cette part de ses dégâts au joueur (Sève). |
| `rosee` | part de la vie maximale | Un ennemi tué par l'attaque rend cette part de la vie maximale, au plus `per_second` fois par seconde (Sève). |

Forme d'Aube : `rayon` (Rayon d'aube, `kind` `beam` : `attack.gd › beam_line` frappe chaque ennemi traversé une fois, du plus proche au plus loin ; la lance d'aube, le prisme et l'action `ray` s'en servent aussi). Dessins dans `scripts/aube_fx.gd`, élément `lumiere` de la charte.

Formes de Vent : `lame` (Lames de vent : `"return": true`, la lame part jusqu'à sa portée puis revient au joueur en frappant de nouveau ; elle perfore tout) et `bourrasque` (cône au corps à corps qui repousse ; `fx` et `sfx` nomment sa signature et son son).

Forme de Racine : `massue` (Massue de bois, `kind` `melee` : lent et lourd, `fx` `massue` dessiné par `scripts/racine_fx.gd`). Modificateurs de Racine : `secousse` (une fois par coup au corps à corps qui porte, le sol se soulève devant le joueur : part des dégâts aux ennemis à moins de `radius` px × taille des zones) et `aubier` (chaque coup de l'attaque donne cette part de ses dégâts en bouclier d'écorce, `player.bark`, au plus `cap` × la vie maximale ; bu après le bouclier d'écorce).

Forme de Sève : `perle` (Perles de sève : lourdes gouttes lentes ; à l'impact, `splash` × les dégâts éclaboussent les ennemis à moins de `splash_radius` px (× taille des zones), et `leech` × les dégâts soignent le joueur).

**Synergies** (`synergies.json`, `attack.gd › active_synergies`). Une synergie donne un bonus quand deux formes, familles ou modificateurs se croisent :

```json
"aube_tranchante": {"name": "Aube tranchante", "desc": "les coups critiques…",
  "needs": [{"form": "rayon"}, {"form": "lame"}],
  "effects": [{"attack_mod": "incandescence", "value": 0.25}, {"stat": "crit", "op": "add", "value": 0.04}]}
```

Conditions (`needs`, toutes vraies, au moins deux sauf `forms`) : `{"form": id}` une forme active (principale ou écho), `{"mod": nom}` un modificateur reçu de l'arbre, `{"family": "corps_a_corps" | "projectile" | "zone"}` une forme de cette famille, `{"branch": id}` une forme de cette branche, `{"forms": N}` au moins N formes actives. Les conditions se lisent sur ce que donne l'arbre, pas sur ce qu'ajoutent les synergies. `effects` : effets comme ceux des nœuds (`stat`, `attack_mod`, `on`), sans `attack_form`. Les synergies actives sont dans `Game.attack()["synergies"]` ; l'infobulle d'un nœud d'attaque cite les synergies où il entre (en or si elles sont actives), l'aperçu annonce « Synergie : + … », le HUD montre au-dessus de la vie les formes (principale, échos) et un losange doré par synergie, et annonce chaque nouvelle synergie.

L'infobulle d'un nœud montre l'aperçu avant → après de l'attaque (« Attaque : Graines → Fouet », « Attaque : + fouet, en écho », « Attaque : + fourche… »), comme pour les statistiques. Pour essayer une attaque sans passer par l'arbre : `tools/godot.sh --xvfb -- --attack=fouet,repetition:1,saignement:0.3` (marche aussi avec `--autotest`). `tools/godot.sh --headless --fixed-fps 60 -s res://tests/attack_test.gd` teste le moteur.

## Résonance de branche

```json
"resonance": [
  {"count": 10, "name": "Ronce éveillée", "effects": [{"stat": "damage", "op": "inc", "value": 0.1}]},
  {"count": 25, "effects": [...]},
  {"count": 50, "effects": [...]}
]
```

Chaque palier donne ses effets dès que `count` nœuds de la branche sont appris (nœuds de grappe compris, nœuds des frontières hybrides de la branche compris, la graine ne compte pas). Les paliers se cumulent. L'infobulle de chaque nœud de la branche rappelle le prochain palier.

## Greffes

`grafts.json` : `{"<id>": {"name", "desc", "sources", "shape", "color", "effects": [...]}}` (les clés qui commencent par `_` sont des commentaires).

| Champ | Rôle |
| --- | --- |
| `sources` | D'où la greffe peut venir : `autel`, `boss`, `secret`, `elite`, `quete`. `Game.roll_graft(source)` tire une greffe de cette source, ni possédée ni déjà au sol (les élites en font tomber une avec `main.drop_graft(pos)`). |
| `shape`, `color` | Dessin au sol, dans l'inventaire et dans l'emplacement : `feuille`, `epine`, `racine`, `fleur` ou `coeur`. |
| `effects` | Mêmes effets qu'un nœud. Une greffe n'agit que posée dans un emplacement appris. |

Chaque greffe existe en un exemplaire. On la trouve au sol (`graft_pickup.gd`), elle entre dans l'inventaire (`Game.give_graft(id)`, signal `Game.graft_found`), puis on la pose dans l'écran de l'arbre : glisser depuis l'inventaire (en bas à gauche) jusqu'à un emplacement, ou clic sur la greffe puis sur l'emplacement. Un clic sur un emplacement appris et occupé retire la greffe. L'infobulle de l'emplacement montre l'effet de la greffe tenue (statistiques avant → après). En code : `Game.place_graft(emplacement, greffe)` (greffe possédée, déplacée si elle était ailleurs), `Game.set_graft` (outil bas niveau des tests).

## Régions

Une région est décrite tout entière par `regions/<id>.json`. `scripts/regions.gd` lit tous les fichiers de ce dossier et les range dans l'ordre des branches de `tree.json` : ajouter une région, c'est ajouter son fichier (et le script de son boss), sans toucher au moteur. Six régions au plus, une par branche. `check_data.gd` vérifie chaque fichier (`Regions.validate()`). Pas à pas : « Ajouter une région » dans le README du projet.

| Champ | Contenu |
| --- | --- |
| `id`, `branch` | Identifiant (celui des drapeaux : `<id>_coeur_purifie`, `<id>_boss_vaincu`, `<id>_fin_vue`) et branche de l'arbre dont la région occupe le secteur. |
| `name`, `place`, `map_name`, `color` | Noms affichés (« Région de Ronce », « le roncier », « Roncier » sur la carte) et couleur de la région sur la carte. |
| `art` | Dessins propres à la région : son Cœur de flétrissure (flétri, puis purifié) et le mur de l'arène de son boss, par `scripts/region_art/<art>.gd`, qui étend `scripts/region_art.gd` et n'en remplace que ce qui change (`draw_heart`, `draw_heart_purified`, `draw_arena_floor`, `draw_arena_wall`). Sans `art`, ceux du roncier (la rose, le mur de ronces). Exemples : `spore.gd` (amanite, cercle de champignons), `vent.gd` (pierre levée aux rubans, muret de pierres levées). La planche `galerie_coeurs` des tests visuels les montre tous. |
| `ground` | Palette du sol : `dead_dark`/`dead_light` (terre morte tant que le Cœur vit), `purified_dark`/`purified_light` (terre morte apaisée après la purification), `alive_dark`/`alive_light` (herbe), `dot` (petits points sur l'herbe) et leurs réglages (`dot_cell`, `dot_rarity`, `dot_salt`, `dot_size`, `dot_strength`, `alive_mix`, `alive_mix_purified`). `colors` : couleurs nommées, citées ensuite par `$nom`. |
| `decor` | Décor propre : `kind` (le script `scripts/decor_<kind>.gd`, comme `decor_roncier.gd`) et ses réglages. Sans `decor`, la région a les arbres ordinaires. |
| `edge` | Décor du bord du monde, au-delà de ±2900 px (`scripts/world_edge.gd`) : `ronce`, `spore`, `vent`, `seve`, `aube` ou `racine`. Par défaut le thème du même nom que la région, sinon le roncier. Un nouveau thème s'ajoute dans `world_edge_painter.gd` (couleurs dans `THEMES`, une fonction de dessin). |
| `landmarks` | Grands repères (`grand_arbre`, `ruine`, `rocher`) : `kind`, position, `size`. |
| `spawn` | Apparitions : sortes et poids (`kinds`), part près/loin de la graine (`share_near`, `share_far`, `far`), nids (`nest_min_dist`, `max_nests`, `nest_fallback`), colosses tenus loin de la graine (`min_dist` : sorte → distance minimale à la graine, en deçà on tire parmi les autres sortes), effet de la purification du Cœur (`purified_factor`). |
| `sanctuaries` | Sanctuaires : `id` (unique dans le monde), `name` (« de la Lisière »), position. |
| `altars`, `secrets` | Autels cachés et secret : `id`, `name`, position, `points`, `graft` (vide : une greffe tirée parmi celles de la source). |
| `heart` | Les Cœurs de flétrissure : `name`, `zone`, `hold_time`, vagues (`waves` : `every`, `base`, `growth`, `kinds`, `second_share`, `big`, `big_from`), ennemis au repos (`idle`), `reward` (donnée avec le dernier Cœur), `life_radius` et `life_color` (vague de vie), bannières (`wake_banner`, `purified_banner` pour le dernier Cœur, `part_banner` pour les autres avec deux `%d` : purifiés, total). `spots` : un emplacement par Cœur (`dist` et `side` ou `angle`, comme les autres lieux ; `zone`, `hold_time`, `life_radius`, `name` et `size`, la taille du Cœur, y remplacent les réglages communs). Trois Cœurs par région depuis le jalon 10 ; le plus proche du centre de la région est le Grand Cœur, au pied de l'arène. Sans `spots`, un seul Cœur au centre. Chaque Cœur pose `<région>_coeur<n>_purifie` ; le dernier pose aussi `<région>_coeur_purifie`, qui ouvre l'arène (et vaut pour tous les Cœurs : une partie d'avant le jalon 10 les retrouve tous purifiés). `check_data` refuse une zone qui sort du secteur, touche une autre zone, l'arène, un sanctuaire, un autel ou un secret. |
| `boss` | Le boss : `script` (un fichier qui étend `BossBase`, voir `scripts/boss_base.gd`), `name`, `bar_color`, `phases` (noms affichés), `arena` (`radius`, `radius_min`, `offset` depuis le Cœur, `life_color`), `reward`, bannières. |
| `ending` | Séquence « région purifiée » : `sub`, `title`, `body`. |
| `ambience`, `music` | Humeur de l'ambiance sonore et de la musique. |
| `wind` | Rafales de la région (Vent : `scripts/wind.gd`, posé par `decor_plateau.gd`) : `angle` (écart du vent dominant au milieu du secteur, en radians), `calm` (durée du calme, [min, max] s), `warn` (annonce, s), `gust` (rafale, s), `player_push` (px/s au plus fort), `projectile_push` (px/s²), `streaks` (traînées dessinées). Le joueur règle leur force dans les options (« Rafales », `Settings.wind`, de 0 à 1). |

**Positions.** `dist` : distance à la graine en pixels. `side` : écart au milieu du secteur, de -1 (bord gauche) à 1 (bord droit), ou `angle` : écart en radians.

**Place dans le monde.** Le monde est un carré de ±2900 px autour de la graine (`Regions.WORLD_HALF`), partagé en six secteurs de 60°, un par branche, dans l'ordre du cercle de l'arbre : Ronce (nord-est), Spore (est), Sève (sud-est), Vent (sud-ouest), Aube (ouest), Racine (nord-ouest). Le Cœur se dresse à 1650 px de la graine dans l'axe du secteur, et l'arène de son boss à `offset` px au-delà. Les secteurs de Spore et d'Aube ne touchent aucun coin du carré : leur bord est à 2900 px dans l'axe (`offset` + `radius` de l'arène au plus 1190, comme Spore : 700 + 440), contre 3349 px pour les quatre autres (`offset` + `radius` au plus 1640). `check_data.gd` refuse un lieu hors du monde (à moins de 60 px du bord), une zone de Cœur qui déborde du secteur, une arène qui sortirait du monde (elle glisserait de biais vers une région voisine), dont le mur déborde du secteur ou qui empiète sur la zone du Cœur. `tests/world_test.gd` remplit les six secteurs (avec les régions du jeu, les régions factices des branches qui n'en ont pas encore, et la région d'essai sur la branche Racine) et vérifie que tout tient.

**Couleurs.** Partout dans un fichier de région, une couleur s'écrit `"#rrggbb"`, avec un rôle de la charte (`"sol_mort"`), un élément et sa variante (`"cendre/sombre"`, `"vent"`), une couleur nommée (`"$rouille"`), ou une recette qui reprend les calculs de la charte : `{"mix": [a, b, t]}`, `{"dark": [a, part]}`, `{"light": [a, part]}`.

## Son et ambiance

`data/audio.json` (clé `regions`, une entrée par identifiant de région) règle ce qu'on entend et voit d'une région. La région peut aussi porter une section `audio` dans son propre fichier, qui prime. Une région sans réglage garde la musique et les particules de Ronce. `check_data.gd` vérifie tout (sons connus, boucle de musique, formes et couleurs).

```json
"spore": {
  "music": {
    "seed": 23, "roots": [-2, -7, -4, -9],
    "dark":   {"chord": [0, 3, 6, 10], "wind": 0.5, "wind_lp": 0.012, "wind_period": 4.0},
    "bright": {"chord": [0, 3, 7, 10], "pattern": [0, 3, 7, 10, 14, 10, 7, 3]}
  },
  "ambience": {
    "butterflies": 0,
    "dead":  {"shape": "glow", "color": "poison/sombre", "alpha": 0.5, "vel": [4, -14], "sway": [10, 3], "size": [1.6, 3.4]},
    "alive": {"shape": "streak", "color": "vent/clair", "alpha": 0.7, "vel": [170, 8], "sway": [24, 8], "size": [1, 1.8], "length": 26}
  },
  "boss": {"eveil": "spore_boss_eveil", "phase": "spore_boss_phase", "mort": "spore_boss_mort"}
}
```

- **`music`** : `roots` (quatre fondamentales en demi-tons depuis le ré, une par accord de 3 s), `seed` (hasard du vent), puis `dark` (terre morte) et `bright` (terre vivante), dont chaque réglage est facultatif (valeurs de Ronce par défaut, `Synth.DEFAULT_DARK` et `DEFAULT_BRIGHT`). `dark` : `chord` (demi-tons), `vol`, `vol2`, `detune`, `wind` (niveau du vent), `wind_lp` (clarté du vent), `wind_period` (**doit diviser 12 s**, pour que la boucle ne claque pas), `wind_fade` (estompe du vent aux bouts, pour un vent fort), `bell`. `bright` : `chord`, `octave`, `pattern` (1 à 24 notes réparties sur 3 s), `pad`, `pluck`, `sparkle`, `sparkle_note`. `tools/gen-sounds.sh` écrit `assets/music/<id>_sombre.wav` et `<id>_lumineux.wav` ; commiter les `.wav` (`sound_test.gd` échoue s'ils sont périmés).
- **`ambience`** : `dead` et `alive` (terre morte ou vivante là où naît la particule), chacun avec `shape` (`dot`, `glow` halo qui scintille, `streak` brin qui file), `color` (couleur de région : `"#rrggbb"`, `"élément/variante"`…), `alpha`, `vel` (vitesse en pixels par seconde), `sway` (ondulation), `size` (min, max) et `length` (pour `streak`). `butterflies` à 0 supprime les papillons dans la région. « Réduire les effets » coupe toutes les particules.
- **Sons choisis par les données** : `"sound"` dans une compétence (`skills.json`, joué après son lancement) ou dans une forme d'attaque (`attack.json`, remplace `tir`), `"sound_hit"`, `"sound_crit"` et `"sound_death"` dans une sorte d'ennemi (`enemies.json`). Le nom doit exister dans `Synth.SOUNDS` (`check_data.gd` le vérifie).
- **Sons prêts pour Sève et Aube** (jalon 8, provisoires) : Sève `seve_goutte`, `seve_pousse`, `seve_soin`, `seve_source`, `seve_eclosion`, `seve_lien` ; Aube `aube_rayon`, `aube_eclat`, `aube_halo`, `aube_levant`, `aube_cloche`, `aube_nova` ; chaque région a aussi `<id>_boss_eveil`, `_phase` et `_mort`. Les compétences des branches s'y branchent par `"sound"` ; musique et ambiance de `seve` et `aube` sont dans `data/audio.json`.
- **`boss`** : sons d'éveil (le combat commence), de phase (le boss change de phase) et de mort, joués par le socle `BossBase`. Un boss peut en jouer d'autres lui-même (`Sfx.play`).
- **Finale et générique** (crochets pour la musique de la fin) : deux entrées qui ne sont pas des régions. `finale` : sous la graine, le jeu demande la musique de `finale` (`Music.set_mood(vie, "finale")`, couche lumineuse après la victoire) et ses sons `boss` ; `generique` : pendant l'épilogue et le générique, `Music.set_mood(1.0, "generique")`. Il suffit d'y écrire une section `music` et de lancer `tools/gen-sounds.sh` (pistes `finale_sombre.wav`, `finale_lumineux.wav`, `generique_*.wav`) ; sans pistes, la musique du monde.

## Points et greffes du monde

Chaque région décrit ce qu'elle donne, hors des niveaux : `heart › reward` et `boss › reward` (`{"points": 2, "graft": "greffe_mere"}`), `altars` et `secrets` :

```json
"altars":  [{"id": "ronce_1", "name": "Autel des épines", "dist": 980, "side": -0.85, "points": 1, "graft": "greffe_soeurs"}],
"secrets": [{"id": "ronce", "name": "La graine enfouie", "dist": 2380, "side": 0.95, "points": 1, "graft": "greffe_graine"}]
```

`Content.rewards()` les rassemble (`boss`, `coeur` par région ; `altars`, `secrets` avec leur `region`).

Un autel (`altar.gd`) est placé à `dist` pixels de la graine, `side` (de -1 à 1) le décale vers un bord du secteur de la région ; il est poussé hors des buissons. On le devine à 520 px, on le ravive en s'y tenant 1,5 s (2,5 s et 230 px pour un secret, presque invisible). `graft` vide : une greffe tirée parmi celles de la source.

Les points passent par `Game.grant_points(n, source, clé)` : une même clé ne donne qu'une fois par partie (drapeau `points_<clé>`), le HUD annonce la source (signal `Game.points_granted`). Drapeaux posés : `autel_<id>_vu` et `secret_<id>_vu` (aperçu), `autel_<id>` et `secret_<id>` (ravivé), `points_<région>_boss`, `points_<région>_coeur`, `points_hors_niveau` (total). Les autels et secrets sont dans les groupes `autel` et `secret` (propriétés `id` et `region`).

## Objectifs

`objectives.json` : `{"adventure_ending": {...}, "objectives": [...]}`. Chaque objectif a un `id`, une `region` (sauf les objectifs communs, comme le premier nœud), un `title`, un `text`, `"main": true` pour la suite principale (ordre du fichier), une `condition`, éventuellement une `target` (cible de la flèche et de la carte) et une `reward` (`text` affiché, `points` donnés une seule fois). Un objectif est accompli dès que sa condition est vraie, dans n'importe quel ordre ; l'objectif en cours est le premier principal qui ne l'est pas, après la dernière étape marquée `"milestone": true` déjà accomplie (le Cœur, le boss) : un joueur qui purifie le Cœur avant d'avoir ravivé un sanctuaire n'est pas renvoyé en arrière, et l'étape sautée reste ouverte dans le journal (« étape passée »). Les drapeaux qui finissent par `_vu` (autel ou secret seulement aperçu) ne comptent pas dans `flag_count`.

| `condition.type` | Vrai quand |
| --- | --- |
| `nodes` (`count`) | au moins `count` nœuds sont appris (la graine ne compte pas) |
| `flag` (`flag`) | `Game.flags[flag]` est vrai |
| `flag_count` (`prefix`, `count`, `exclude`, `region_only`) | au moins `count` drapeaux vrais commencent par `prefix` (sauf ceux de `exclude`) ; avec `"region_only": true`, sans ceux des lieux des autres régions |
| `counter` (`flag`, `count`) | `Game.flags[flag]` vaut au moins `count` |
| `keystone` (`branch`) | un nœud clé de la branche est appris |
| `hearts` | tous les Cœurs de la région de l'objectif sont purifiés ; le journal et le cadre montrent le compte (« 1 / 3 ») |

`target.type` : `none`, `seed`, `heart` (le Cœur de la région le plus proche du joueur parmi ceux qui restent) et `arena` (celle de la région de l'objectif), `finale` (la brèche au pied de la graine, puis la Flétrissure une fois descendu), ou `group` (le plus proche des nœuds du groupe `group`, dans la région de l'objectif, dont le drapeau `<done_prefix><id>` n'est pas levé). `needs_group` masque l'objectif tant que le groupe est vide (le monde n'a pas encore de sanctuaire ou d'autel) ; `needs_flag` le masque tant que ce drapeau n'est pas posé (l'objectif `finale` attend `finale_ouverte`).

**Ce que les autres systèmes doivent poser** : `sanctuaire_<id>` à la ravivation d'un sanctuaire (le sanctuaire de la graine s'appelle `sanctuaire_graine` et ne compte pas), `autel_<id>` à la découverte d'un autel, `secret_<id>` pour un secret, `<région>_coeur<n>_purifie`, `<région>_coeur_purifie` et `<région>_boss_vaincu` (déjà posés). Les sanctuaires et les autels se rangent dans les groupes `sanctuaire` et `autel` (nœuds Node2D avec une propriété `id`) pour que la carte et la flèche les trouvent. Un élite vaincu émet `main.elite_killed(enemy)` : `Objectives` le compte dans `elites_tuees`. Les points des objectifs facultatifs passent par `Game.grant_points(n, "quete")` quand il existe.

La célébration « région purifiée » se lance sur place peu après la victoire sur le boss d'une région (`<région>_boss_vaincu`), sans écran plein ni pause (depuis le jalon 10, `region_fanfare.gd`) : la région reverdit, le titre et le sous-titre de `ending` de son fichier s'affichent par-dessus le jeu avec un médaillon des régions où la sienne reverdit et son sceau se brise, puis on continue à jouer. Elle pose `<région>_fin_vue` dès le début et ne revient plus ; la carte du monde rejoue la région qui reverdit et le sceau brisé à sa prochaine ouverture. Quand le boss de chaque région est vaincu, la dernière célébration montre `adventure_ending` (avec son texte) : la Flétrissure se retire sous la graine, et la finale s'ouvre (voir « Finale »). L'écran plein (`epilogue.gd`) reste pour la fin de la finale. L'objectif en cours d'une région se lit avec `Objectives.current(région)`. `tools/godot.sh --headless -s res://scripts/check_data.gd` contrôle le fichier.

## Finale

`finale.json` décrit le combat final et la fin de l'aventure. Il se joue avec n'importe quel nombre de régions : la finale s'ouvre quand `Regions.all_purified` est vrai.

```json
"boss": {"script": "res://scripts/boss_finale.gd", "name": "La Flétrissure", "bar_color": "cendre",
         "phases": ["…", "…", "…"], "arena": {"radius": 520, "radius_min": 370, "radius_collapse": 380, "life_color": "seve/clair"},
         "wake_banner": "…", "defeated_banner": "…", "reward": {"points": 3}},
"opened_banner": "…", "descent_banner": "…", "ascent_banner": "…",
"epilogue": {"sub": "…", "title": "…", "body": "…"},
"credits": [{"title": "Sève"}, {"head": "Une aventure de", "lines": ["…"]}, {"head": "Régions", "auto": "regions"}, {"head": "Gardiens", "auto": "bosses"}]
```

- **Ouverture** (`finale_arena.gd`, `main.finale`) : toutes les régions purifiées, le drapeau `finale_ouverte` est posé et `opened_banner` annoncé ; une brèche s'ouvre au pied de la graine (`descent_point()`, 150 px au sud du sanctuaire de la Graine). S'y tenir une seconde fait descendre le joueur **sous la graine** : l'arène est un creux hors du carré du monde (`CAVE`), où rien ne naît et qu'aucun Flétri du monde ne suit. Le puits de lumière où l'on arrive fait remonter (hors combat) ; s'avancer vers le centre réveille le boss.
- **Combat** : comme une arène de région (`finale_arena.gd` étend `boss_arena.gd`) : barre, phases (`phases`, trois). En phase 3, la Flétrissure prend sa seconde forme (invulnérable le temps de la transformation) et le creux s'effondre : il ne reste qu'une île de `radius_collapse` au-dessus du gouffre (`radius_min` sert seulement au resserrement des arènes de région). Mourir ramène au dernier sanctuaire, la sève attend près de la brèche (`entrance()`), le boss se rendort ; `stat_finale_essais` compte les combats perdus. Une partie sauvegardée sous la graine reprend au pied de la graine.
- **Victoire** : `finale_vaincue`, `reward › points` (une seule fois, clé `finale_boss`), `stat_finale_fin` (temps de jeu) ; le creux refleurit, puis l'épilogue (`epilogue.gd`, `quest_ui.epilogue`) : le monde entier reverdit, les textes d'`epilogue`, les statistiques de toute l'aventure, le générique (`credits` : `title` en grand, ou `head` et ses `lines` ; `auto` : `regions` ou `bosses` remplit la liste avec les régions du monde et leurs gardiens, plus la Flétrissure), puis « Continuer à jouer » / « Retour au titre ». Il pose `fin_aventure_vue` et ne revient plus.
- **Boss** (`boss_finale.gd`, sur `BossBase`) : un trait de chaque région, deux nouveaux par phase : épines (Ronce) et spores (Spore), puis sève (siphon qui la soigne) et vent (rafale qui repousse), puis lumière (rayons) et racines (ligne qui jaillit jusqu'au joueur) ; des rejetons dès la phase 2. Robot : `tools/godot.sh --headless --fixed-fps 60 -- --autotest=boss --region=finale` (build de test au niveau 20, points dans la première branche).
- **Musique** (crochets de la tâche H) : `data/audio.json › regions › finale` (sons `boss`, et `music` pour le combat) et `› generique` (`music` du générique). Sans `music`, la musique du monde.
- **Sauvegarde** : format 5. Une sauvegarde plus ancienne qui avait vu l'ancienne fin (`fin_aventure_vue` sans `finale_vaincue`) perd ce drapeau : la finale s'ouvre au chargement.

`check_data.gd` contrôle le fichier (script BossBase, trois phases, couleurs, textes, générique).

## Ajouter du contenu

- **Un nœud clé ou modifier une branche** : éditer `branches/<id>.json`. Les nœuds clés sont placés dans l'ordre aux anneaux 4, 8 et 12.
- **Une grappe, une maîtrise, une mutation, un nœud flétri** : ajouter une entrée à `clusters` dans la branche (voir « Grappes écrites à la main »).
- **Une frontière hybride** : un fichier `borders/<a>-<b>.json` entre deux branches voisines (voir « Frontières hybrides »).
- **Une région** : voir « Régions » et « Ajouter une région » dans le README du projet.
- **Une compétence** : son fichier `scripts/skills/<id>.gd` (classe `Skill` : `cast`, `tick` facultatif) et ses réglages dans `skills.json`.
- **Un comportement d'ennemi** : `scripts/enemy_behaviors/<nom>.gd` (classe `EnemyBehavior` : `step`, `draw_attack`, `on_death`), nommé par `behavior` dans `enemies.json`.
- **Le dessin d'une sorte hors de `fletri_art.gd`** : `"art": "<nom>"` dans sa sorte de `enemies.json`, et le fichier `scripts/enemy_art/<nom>.gd` (fonctions statiques `body_color(kind_id)` et `draw(ci, kind_id, pos, r, face, t, o)`). Les Flétris des plateaux sont dans `enemy_art/vent.gd`.
- **Comportements des plateaux de Vent** : `diver` (le Piqueur tourne autour du joueur puis plonge en ligne droite : `orbit`, `windup`, `dive_speed`, `dive_dist`, `charge_damage`, `recover`), `blower` (le Souffleur garde ses distances et souffle en cône : `keep_min`, `keep_max`, `range`, `cone`, `windup`, `blow_damage`, `blow_push`, `blow_time`), `glider` (le Planeur prend de la hauteur quand on l'approche et esquive alors tout coup direct, `EnemyBehavior.dodge` : `reach`, `flee`, plumes `shots`, `spread`, `shot_speed`, `shot_damage`, `shot_life`). `"no_push": true` : la sorte ne recule ni ne se laisse aspirer (le Menhir).
- **Comportements de la forêt pétrifiée (Racine)** : `burrower` (la Mandragore s'enfonce sous terre et file sous le joueur, au plus `burrow_time` s à `burrow_speed`, intouchable par les coups directs, inoffensive au contact (`EnemyBehavior.harmless`) et ignorée par le tir automatique (`EnemyBehavior.hidden`) ; elle marque son cercle (`windup`), jaillit (`burst_radius`, `burst_damage`) et reste sonnée (`recover`) ; `range`, `cooldown`), `slam` (le Tertre lève les poings et frappe le sol autour de lui : `range`, `windup`, `slam_radius`, `slam_damage`, `recover`) ; le Termite suit `chase`, le Scarabée `charger`. `"armor_pierce": 0.6` : part de l'armure du joueur que les coups de la sorte ignorent (`player.take_hit` lit `armor_pierce` sur la source du coup ; un boss la pose le temps d'un coup, comme le pieu de l'Ancien pétrifié). `"no_root": true` : l'enracinement de Racine ne tient pas la sorte (le Tertre ; un boss le déclare dans son script).
- **Une statistique** : l'ajouter dans `stats.json`, puis la lire dans le code avec `Game.stats["nom"]`.
- **Une action ou un évènement** : écrire l'action dans `scripts/effect_actions.gd` et la déclarer dans `Content.ACTIONS` (`scripts/content.gd`) ; pour un évènement, l'ajouter à `Content.EVENTS` et appeler `Game.fire("nom", {...})` à l'endroit voulu.
- **Un état pour les conditions** : le déclarer dans `conditions.json` et le tenir à jour avec `Game.set_state("nom", valeur)`.

Pour une version exportée du jeu, ajouter `*.json` aux fichiers à inclure dans les réglages d'export de Godot.

## Équilibrage des builds

`builds.json` décrit des builds types : une liste de nœuds visés (`targets`, identifiants stables comme `key:nova` ou `c:ronce:sang:s1`), les choix des maîtrises et mutations (`choices`) et la façon de jouer du robot (`style` : `distance`, `melee` pour aller au contact, `tank` pour rester au milieu des ennemis). Le robot passe au niveau 20, apprend à chaque point le prochain nœud du plus court chemin vers la première cible pas encore acquise, puis complète avec les nœuds de sa branche (`branch`, Ronce par défaut) les plus proches de la graine.

```
tools/godot.sh --headless --fixed-fps 60 -- --autotest=build:fouet --build-time=180 --build-level=20 --seed=1
tools/balance.sh                 # epines, fouet et saignement, graines 1 à 3, sans affichage et en parallèle
SEEDS="1 2 3 4 5 6 7 8 9 10" tools/balance.sh
```

Pendant la mesure, le niveau reste figé (mêmes points et même difficulté pour tous les builds) et une mort ne vide pas l'écran : le robot repart sur place avec toute sa vie, et chaque mort compte 10 s de plus dans le temps de jeu. Le score est le nombre d'ennemis vaincus par minute ; `tools/balance.sh` compare les builds d'une même branche (échec si le meilleur dépasse le moins bon de plus de 30 %) puis les branches entre elles (moyenne de chaque branche, échec au-delà de 35 %). `tools/zone.sh --region=<id>` joue une région de bout en bout. Une cible absente de l'arbre est ignorée et signalée.
