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
| `grafts.json` | Les greffes : objets à poser dans un emplacement de greffe de l'arbre (nom, effets). |
| `skills.json` | Réglages des compétences actives (recharge, rayon, dégâts, texte). |
| `conditions.json` | États utilisables dans un `if`, avec leur texte d'affichage. |

## Les effets

Un nœud porte une liste `effects`. Chaque effet est d'une de ces quatre sortes.

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

Compétences actuelles : `nova` (Couronne d'épines), `cloud` (Nuage de spores), `bloom` (Floraison), et pour Ronce `fouet` (arc au corps à corps qui fait saigner), `racines` (immobilisent les ennemis à l'endroit visé) et `haie` (mur d'épines temporaire qui bloque et blesse). Champs communs de `skills.json` :

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

- `on` : `kill` (ennemi vaincu), `crit` (coup critique), `lethal_hit` (coup mortel reçu), `melee_hit` (coup au corps à corps, `base` = dégâts du coup), `bleed_tick` (à-coup de saignement toutes les 0,5 s, `base` = dégâts de l'à-coup), `root` (ennemi enraciné, `base` = dégâts du coup qui enracine).
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

### États des ennemis

`enemy.apply_status(nom, valeur, durée)` : `saignement` (dégâts par seconde, cumulable 5 fois ; au-delà la piqûre la plus faible est remplacée) et `enracine` (immobile, frappe toujours au contact). La statistique `bleed` fait saigner à chaque coup du joueur (fraction des dégâts par seconde, 4 s × `bleed_duration`), comme `poison`.

### 4. Transformer une compétence (mutation)

```json
{"skill_mod": "nova", "param": "radius", "op": "more", "value": 1.4,
 "text": "Couronne d'épines : rayon ×1,4."}
```

Modifie un réglage d'une compétence de `skills.json`. `op` vaut `add`, `inc`, `more` (même calcul que pour une statistique : `(réglage + add) × (1 + inc) × more`) ou `set` (remplace la valeur, y compris par un texte ou un booléen, pour un réglage que le code de la compétence sait lire). `text` est obligatoire, sauf avec `"hidden": true` quand une autre ligne décrit déjà l'ensemble. Le code lit les réglages par `Game.skill("nova")` au moment du lancer.

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

Un choix s'écrit `{"id": "...", "name": "...", "effects": [...]}`. `id` est facultatif (par défaut la position du choix dans la liste) mais conseillé : c'est lui que la sauvegarde retient, et il permet de réordonner les choix plus tard. Tant qu'aucun choix n'est fait, le nœud ne donne que ses `effects` propres ; la fenêtre de choix s'ouvre à l'apprentissage, et le nœud pulse en doré tant que le choix reste à faire.

`excludes` (sur n'importe quel nœud de grappe) liste des nœuds incompatibles : un identifiant local de la même grappe, la `key` d'un nœud clé ou un identifiant stable complet. L'exclusion vaut dans les deux sens : apprendre l'un verrouille l'autre.

Une grappe ne doit recouvrir ni la graine, ni un nœud clé généré (anneaux 4, 8 et 12, au milieu du secteur), ni une autre grappe : `check_data.gd` le signale.

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

`grafts.json` : `{"<id>": {"name": "...", "desc": "...", "effects": [...]}}`. Il n'y a pas encore de greffes à trouver dans le monde ; `greffe_test` sert aux tests.

## Ajouter du contenu

- **Un nœud clé ou modifier une branche** : éditer `branches/<id>.json`. Les nœuds clés sont placés dans l'ordre aux anneaux 4, 8 et 12.
- **Une grappe, une maîtrise, une mutation, un nœud flétri** : ajouter une entrée à `clusters` dans la branche (voir « Grappes écrites à la main »).
- **Une statistique** : l'ajouter dans `stats.json`, puis la lire dans le code avec `Game.stats["nom"]`.
- **Une action ou un évènement** : écrire l'action dans `scripts/effect_actions.gd` et la déclarer dans `Content.ACTIONS` (`scripts/content.gd`) ; pour un évènement, l'ajouter à `Content.EVENTS` et appeler `Game.fire("nom", {...})` à l'endroit voulu.
- **Un état pour les conditions** : le déclarer dans `conditions.json` et le tenir à jour avec `Game.set_state("nom", valeur)`.

Pour une version exportée du jeu, ajouter `*.json` aux fichiers à inclure dans les réglages d'export de Godot.
