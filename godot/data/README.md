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
| `branches/<id>.json` | Une branche : nom, couleur, effets des petits nœuds, bonus et noms des nœuds notables, nœuds clés. |
| `skills.json` | Réglages des compétences actives (recharge, rayon, dégâts, texte). |
| `conditions.json` | États utilisables dans un `if`, avec leur texte d'affichage. |

## Les effets

Un nœud porte une liste `effects`. Chaque effet est d'une de ces trois sortes.

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

### 3. Réagir à un évènement

```json
{"on": "kill", "do": "reduce_cooldown", "target": "dash", "value": 0.3,
 "text": "Chaque ennemi vaincu réduit la recharge de l'esquive de 0,3 s."}
```

- `on` : `kill` (ennemi vaincu), `crit` (coup critique), `lethal_hit` (coup mortel reçu).
- `do` : l'action à lancer, avec ses paramètres.
- `cooldown` (facultatif) : durée en secondes avant que l'effet puisse se relancer.
- `text` (obligatoire) : la phrase affichée au joueur.

| Action | Paramètres | Effet |
| --- | --- | --- |
| `reduce_cooldown` | `target` (`dash` ou une compétence), `value` | Réduit une recharge |
| `spread_poison` | `radius`, `duration`, `color` | L'ennemi vaincu transmet son poison autour de lui |
| `explode` | `radius`, `factor`, `color` | Le coup touche aussi les ennemis proches |
| `survive` | `hp`, `invuln`, `label`, `color` | Le coup mortel laisse le joueur en vie |

### Conditions

Tout effet accepte une condition :

```json
{"stat": "damage", "op": "more", "value": 1.4, "if": {"state": "immobile", "min": 0.5}}
```

L'effet ne s'applique que si l'état vaut au moins `min`. États actuels : `immobile` (secondes passées sans bouger) et `cible_empoisonnee` (pour l'évènement `kill`).

## Ajouter du contenu

- **Un nœud clé ou modifier une branche** : éditer `branches/<id>.json`. Les nœuds clés sont placés dans l'ordre aux anneaux 4, 8 et 12.
- **Une statistique** : l'ajouter dans `stats.json`, puis la lire dans le code avec `Game.stats["nom"]`.
- **Une action ou un évènement** : écrire l'action dans `scripts/effect_actions.gd` et la déclarer dans `Content.ACTIONS` (`scripts/content.gd`) ; pour un évènement, l'ajouter à `Content.EVENTS` et appeler `Game.fire("nom", {...})` à l'endroit voulu.
- **Un état pour les conditions** : le déclarer dans `conditions.json` et le tenir à jour avec `Game.set_state("nom", valeur)`.

Pour une version exportée du jeu, ajouter `*.json` aux fichiers à inclure dans les réglages d'export de Godot.
