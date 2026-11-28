# Arborescence 0.14.0 — New Game+

Le jeu complet gagne un **New Game+ par cycles** : une fois la Flétrissure vaincue, l'aventure
recommence dans un monde fané, plus dur, avec des boss exaltés et des greffes neuves. La démo ne
change pas (Ronce seule, pas de New Game+). Builds Windows et Linux, avec Steam (App ID de test 480).

## Ce qui a changé depuis 0.13.0

### Le New Game+ (jeu complet seulement)
- **Entrée par le fruit** : après le générique, un fruit pousse sur la graine ; le tenir 1 s lance
  le cycle suivant, sans écran ni texte. Le menu titre affiche « niveau N · cycle C ».
- **Ce qui se garde** : niveau, arbre, builds, greffes, couronne et carte. Cœurs, boss, sanctuaires,
  purification et objectifs repartent à zéro (les points des boss et des Cœurs sont redonnés).
- **Monde fané** : une vague de flétrissure part du héros et ternit tout le décor à la teinte du cycle
  (plus sombre et plus cendrée au cycle 3) ; l'oasis de la graine reste verte.
- **Monstres** : menace plus haute dès le départ, Flétris des autres régions mêlés à chaque région,
  élites plus fréquents, et trois affixes nouveaux : voile (saut annoncé), siphon (cercle qui soigne),
  rémanent (souffle à la mort).
- **Boss exaltés** : chaque boss a une **phase 4** et une attaque nouvelle, calée sur sa musique
  (étreinte de la Mère-Ronce, anneaux de l'Amanite-Mère, passage rasant du Harfang, liane et siphon
  du Saule, balayage de la Phalène, foulée de l'Ancien, reflux de la Flétrissure). Au cycle 3, cette
  attaque arrive dès la phase 3. Leur vie suit le niveau du héros.
- **Greffes de cycle** : 8 greffes nouvelles (6 dès le cycle 2, 2 au cycle 3), données par les
  sanctuaires et les boss quand la greffe prévue est déjà possédée. Couronne : +1 emplacement par
  cycle (jusqu'à 20).
- **Steam** : succès `CYCLE_2` et `CYCLE_3` (Flétrissure vaincue au cycle 2 / 3), avec leurs icônes.
- Cycles illimités ; le contenu nouveau s'arrête au cycle 3, la difficulté monte encore un peu ensuite.

### Son
- Musiques de boss d'Antoine : Mère-Ronce (intro qui monte à l'approche, drop au combat) et
  Amanite-Mère.
- Tous les sons du jeu transposés dans la gamme de la zone (plus de dissonance avec la musique) ;
  l'ambiance se tait pendant les combats de boss.

### Performances et fiabilité
- Finale allégée (textures cuites rognées), bord du monde préparé hors du fil principal au siège des Cœurs.
- Sauvegarde v9 (cycle en cours) ; migration des sauvegardes v1 à v9 vérifiée.
- Quelques erreurs « Invalid polygon data » évitées dans les effets de compétences.

## Points connus (à surveiller, pas des bugs)

- **Équilibrage reporté à la fin** : au cycle 2, le héros gardé (niveau 40 et plus) écrase les monstres ;
  le robot y finit sans mourir. La vie des boss suit le niveau, mais leurs dégâts ne sont pas encore revus.
  L'Ancien exalté reste court (ses mécaniques le limitent plus que sa vie).
- Siège des Cœurs encore ~+19 % de temps de frame par rapport à avant la refonte (choix d'Antoine : on garde).
- Les sons propres au New Game+ (vague de flétrissure, annonce de l'Exaltation) sont des points
  d'accroche : ils reprennent des sons existants en attendant la passe d'Antoine.

## Robot d'aventure sur ce build

ROBOT

## Bancs contre 0.13.0

BANCS
