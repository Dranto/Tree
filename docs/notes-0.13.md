# Arborescence 0.13.0 — candidat démo

Version stable et jouable, avec tout le contenu : le jeu complet (six régions et la finale) et la
démo (Ronce seule, jusqu'au sceau de la graine). Builds Windows et Linux, avec Steam (App ID de test 480).

Le son (passe d'Antoine) et le New Game+ viendront après cette version.

## Ce qui a changé depuis 0.12.0

### Nouveau look : « Bestiaire d'herbier » et « Paysages d'herbier »
- Tous les Flétris redessinés région par région, plus vivants, encre plus fine ; morts et impact frames cuits.
- Héros « Esprit masqué » : sa tenue et son arme évoluent selon le build (branches, modifications d'attaque).
- Boss refaits : Mère-Ronce, Ancien, Harfang, Phalène, et une Flétrissure plus imposante à chaque phase
  (gestes en trois temps, taille 1,3 / 1,5 / 1,75).
- Faune, décor composé et cuit, monde vivant (balancement, événements), lieux, frontières entre régions,
  bord du monde, arènes de boss en décor, creux sous la graine enrichi.
- Palettes de régions revues et mode daltonien des Flétris.

### Effets et combat
- Jalon « Éclat » : signatures de boss, morts par élément, effets des compétences et de l'esquive,
  écrans de greffe, de build, de clé et d'oubli plus marquants. Ralenti réservé aux Cœurs et aux boss.
- Musiques de boss faites à la main ; combat de la Flétrissure calé sur le breakcore.
- Musiques et bruitages par région (boucles, signatures, registre grave).

### Steam et sortie
- Nom du jeu et des exécutables : **Arborescence** (`Arborescence.exe`, `Arborescence-demo.exe`).
- GodotSteam 4.24 embarqué dans les builds : statut « En jeu », overlay, Cloud par l'API, succès BOSS_*
  (actifs avec le vrai App ID). Sans client Steam, le jeu tourne pareil.
- Captures et bandes-annonces de la page Steam au nouveau look (FR et EN, Ronce seule).

### Fiabilité et confort
- Écran de chargement aux changements de zone : plus de gels à la purification ni aux passages.
- Performances : Mère-Ronce revenue au niveau d'avant la refonte, finale −9 %.
- Steam Deck et anglais revus en 1280×800 à la manette (sous-titre de la barre de boss plus grand).
- Démo : un Flétri pouvait apparaître juste à côté du héros contre la haie ; corrigé.
- Tests plus fiables en CI ; migration des sauvegardes v1 à v8 vérifiée.

## Points connus (à surveiller, pas des bugs)

- **Équilibrage reporté à la fin** : avec les builds Épines (Ronce) et Saignement, le robot meurt en masse
  aux sièges des Cœurs (Ronce pour Épines, Aube pour Saignement). Depuis la correction du chemin
  d'Épines dans l'arbre, les builds de Ronce vont droit à leur nœud clé sans le détour par Racine
  qui leur donnait 110 PV. Les autres builds passent jusqu'au générique (14 à 17 morts).
- Siège du Cœur ~+18 % de temps de frame par rapport à avant la refonte (cuissons du bord), non bloquant.
- Rare : « Invalid polygon data, triangulation failed » vu une fois dans la console de la démo, sans effet visible.
- Steam : les succès, la présence enrichie et le Cloud ne sont vérifiables qu'avec le vrai App ID.

## Robot d'aventure sur ce build

ROBOT_RESULTATS
