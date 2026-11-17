# Charte graphique

Ce document fixe le langage visuel du jeu. Il vaut pour la zone de Ronce et pour les branches à venir. Tout est dessiné par le code. Les valeurs vivent dans `godot/scripts/art.gd` (classe `Art`) et `godot/scripts/anim.gd` (classe `Anim`), et la planche `godot/tests/visual/reference/charte.png` les montre toutes. Aucune couleur, épaisseur, ombre ou durée n'est écrite en dur ailleurs.

![Planche de la charte](../godot/tests/visual/reference/charte.png)

![Personnages et objets en détail](../godot/tests/visual/reference/charte_details.png)

## 1. Hiérarchie de lecture

On doit lire l'écran en une seconde, dans cet ordre :

1. **Ce qui fait mal** est saturé et contrasté : rouge `danger`, éclair blanc chaud, Flétris sombres à contour clair.
2. **Ce qui se ramasse ou s'utilise** est clair et chaud : `interactif` (pierre claire), `butin` (or).
3. **Le héros** est clair et rond, crème avec un accent de sève.
4. **Le fond** est sourd, sombre et désaturé : sol, brume, décor. Il ne doit jamais attirer l'œil plus qu'un ennemi.

Le test `art_test.gd` vérifie ces règles : le fond reste sombre et peu saturé, ce qui est utile reste clair, le danger reste vif, et le contour des Flétris contraste avec le sol mort.

## 2. Palette par rôle

On demande une couleur par son rôle, jamais par sa teinte : `Art.c("ennemi")`, pas un code hexadécimal.

| Groupe | Rôles |
| --- | --- |
| Fond | `sol_mort`, `sol_vivant`, `brume`, `decor`, `decor_vivant` |
| Héros et alliés | `joueur`, `joueur_accent`, `allie` |
| Flétris | `ennemi`, `ennemi_contour`, `ennemi_oeil`, `elite` |
| Danger | `danger`, `danger_annonce` (voile), `danger_eclair` (frappe) |
| Utile | `interactif`, `butin` |
| Interface | `texte`, `texte_doux`, `accent`, `or`, `panneau` (repris tels quels par `ui_theme.gd`) |
| Traits | `contour`, `ombre` |

## 3. Éléments

Chaque élément a une couleur principale, une couleur claire (reflet, cœur d'une lueur), une couleur sombre (contour, fond de motif), un **motif** et une **icône**. La couleur seule ne suffit jamais : le motif porte aussi l'information.

| Élément | Couleur | Motif | Sens |
| --- | --- | --- | --- |
| Épine | ocre et blanc os | pointes | physique : pointes, perforation, dégâts renvoyés |
| Saignement | rouge profond | gouttes qui perlent et tombent | dégâts dans la durée, cumulables |
| Racine | brun et vert mousse | traits noueux | immobilise, tient, protège |
| Poison | violet | bulles qui montent | affaiblit, se répand en nuage |
| Cendre | orange braise | braises qui s'envolent | brûle, explose : l'arme des Flétris |
| Sève | vert lumineux | lueur douce qui respire | la vie : soins, essences, sol ravivé |
| Vent | bleu ciel pâle | rafales qui filent et s'enroulent | pousse, disperse, accélère : souffles et rafales |

**Daltonisme.** Les couleurs sont choisies pour rester distinctes en protanopie, en deutéranopie et en tritanopie (simulation de Machado 2009). Le rouge du saignement est très sombre, la racine est d'un brun moyen, la cendre est vive et l'épine est claire. Ainsi, même quand les teintes se confondent, les clartés restent différentes. Le test exige un écart perçu (ΔE) d'au moins 20 entre deux éléments, pour chaque forme de daltonisme. Le pire cas actuel est d'environ 21. Le vent, d'un bleu gris pâle, reste à au moins 30 de tous les autres. La planche montre chaque élément tel que le voit chaque forme de daltonisme.

**Compétences.** Chaque compétence prend l'élément qui la domine (`Art.ELEMENT_DE_COMPETENCE`) :
- Couronne d'épines, Fouet de ronce, Volée d'épines : épine ;
- Racines voraces : racine ;
- Saignée : saignement ;
- Nuage de spores : poison ;
- Floraison : sève.

Fonctions : `Art.ec(element, "couleur" | "clair" | "sombre")`, `Art.motif(ci, element, rect, t)` (échantillon ou tuile), `Art.status(ci, element, pos, r, t)` (marque d'état animée autour d'un acteur : Flétri saignant, enraciné, empoisonné…).

## 4. Formes par rôle

- **Le héros et ses alliés sont ronds et organiques.** Ils ont des feuilles, des courbes et des contours doux. Le héros est un corps rond avec deux feuilles en cape. Une graine lumineuse devant lui indique où il vise.
- **Les Flétris sont anguleux et cassés.** Leurs polygones sont irréguliers, avec des encoches et des yeux fendus couleur de braise. Leur rôle se lit à la silhouette :
  - la **mêlée** est compacte, avec des griffes vers l'avant ;
  - le **tireur** est effilé et porte une longue pointe-canon ;
  - le **lourd** est un gros bloc à plaques, au trait fort ;
  - l'**élite** est un Flétri couronné de pointes, dans une aura magenta. Chaque modificateur garde son propre signe, à la couleur de son élément.
- **Les dangers sont pointus.** Ce sont des épines, des cônes et des lignes.
- **Ce qui s'utilise** est un cercle de pierres claires avec un anneau de progression. Le **butin** est une petite forme dorée qui flotte et scintille.

Toutes ces silhouettes doivent se reconnaître **en noir sur blanc**. La planche les montre aussi ainsi. Les silhouettes de la planche sont des exemples : la vague 2 dessine les vraies.

## 5. Traits, ombres, lumière

- Traits : `Art.TRAIT_FIN` (1,5 px : détails, motifs, petites icônes), `Art.TRAIT` (2,5 px : contour des acteurs), `Art.TRAIT_FORT` (4 px : lourds, boss, contour au moment de la frappe). `Art.outline(ci, points, couleur, épaisseur)`.
- Ombre portée : une ellipse aplatie sous l'acteur, légèrement vers le bas. La lumière vient d'en haut, un peu de face. `Art.shadow(ci, pos, r)`.
- Lueur : trois halos qui s'éclaircissent vers le centre, puis un cœur à la couleur claire de l'élément. `Art.glow(ci, pos, r, element)`. On la réserve à ce qui est vivant ou utile (sève, essences, sanctuaires). Un ennemi n'a pas de lueur, sauf l'aura d'une élite.
- Volume : les acteurs et objets importants ne sont pas des aplats. `Art.volume(ci, points, couleur)` et `Art.volume_circle(ci, pos, r, couleur)` donnent un côté ombre, une face éclairée (en haut à gauche) et un reflet. On ajoute ensuite les détails propres au rôle : nervures des feuilles du héros, fentes d'écorce où couve la braise chez les Flétris, plaques du Colosse, runes des sanctuaires (voir la planche « en détail »).
- Ordre de dessin (`Art.COUCHE`, valeurs de `z_index`) : sol < décor bas < objets interactifs < acteurs < projectiles < effets < décor haut < interface.

## 6. Annonce d'une attaque : une seule grammaire

Toutes les attaques des ennemis, des élites et du boss s'annoncent de la même façon, avec `Art.telegraph(ci, forme, progression, frappe, t)` :

1. **Annonce** (la progression va de 0 à 1) : la forme apparaît en contour rouge sur un voile léger. Un voile plus dense la remplit depuis l'origine de l'attaque. Pour un cercle, il part du centre ; pour un cône, de son sommet ; pour une ligne, de son départ.
2. **Dernier quart** : le contour clignote, le coup est imminent.
3. **Frappe** (de 0 à 1) : un éclair blanc chaud couvre toute la forme et prend un contour fort, puis s'éteint vers le rouge.

Il existe trois formes : `cercle` (zone), `cone` (éventail, souffle, coup de griffe) et `ligne` (charge, fouet, couloir). Une annonce dure au moins `Anim.DUREE["annonce_min"]`, soit 0,5 s. Le joueur ne doit jamais encaisser une attaque qu'il n'a pas pu voir venir.

## 7. Animation

Toute action suit trois temps :
- l'**anticipation** : l'acteur se ramasse et on voit l'action venir ;
- l'**impact** : un temps très court et marqué, souvent avec un éclair ;
- le **retour** : souple, amorti.

`Anim.squash(t)` donne l'échelle (écrasé, puis étiré, puis rebond qui s'éteint) en gardant l'aire. `Anim.phase(temps)` découpe une action selon ces durées.

| Durée type | Valeur |
| --- | --- |
| anticipation | 140 ms |
| impact | 60 ms |
| retour | 200 ms |
| éclair (coup reçu, frappe) | 100 ms |
| apparition (pop) | 250 ms |
| disparition | 350 ms |
| respiration du repos | période de 2,4 s |

Les courbes disponibles sont `Anim.ease_in`, `ease_out`, `ease_in_out` et `ease_out_back`. On a aussi `Anim.flash(t)` (de 1 à 0), `Anim.pop(t)` (dépasse un peu puis se pose), `Anim.breathe(temps)` et `Anim.blink(temps)`. L'animation pure reste dans `_process` et ne change jamais le jeu.

La planche « en détail » s'anime en boucle de 2,4 s (respiration, cape, braises, lueurs, runes, butin qui flotte, attaques annoncées puis frappées, recharge des médaillons) : `tools/charte-anim.sh` en fait un GIF. Les animations de la vague 2 reprennent ces mouvements.

## 8. Icônes

`Art.icon(ci, id, rect, couleur)` dessine une icône. Ce sont des silhouettes pleines, lisibles à 20 px, avec au plus un détail clair. **La même icône sert partout** : barre de compétences, arbre, infobulles, journal, ramassage. Une icône prend par défaut la couleur de son élément ou de son rôle. À partir de 20 px environ, elle prend du relief (une tranche sombre sous la forme). `Art.icon_badge(ci, id, rect)` la pose dans un médaillon (disque sombre, anneau à sa couleur, reflet) : c'est la forme à utiliser dans la barre de compétences, les infobulles et le journal.

- Éléments : épine, saignement, racine, poison, cendre, sève, vent (trois rafales qui s'enroulent).
- Arme et compétences : `graine` (l'arme de base), `nova`, `fouet`, `racines`, `volee`, `saignee`, `cloud`, `bloom`. Chacune a une forme propre à 20 px (couronne hérissée, liane en S, trois racines, éventail d'épines, goutte et gouttelettes qui convergent, volutes et bulles, fleur à cinq pétales) et des détails clairs qui n'apparaissent qu'en grand.
- Statistiques : dégâts, vitesse d'attaque, projectiles, critique, vie, régénération, armure, déplacement, esquive, zones, collecte, compétence.
- Monde : sanctuaire, autel, Cœur de flétrissure, arène, secret, sève perdue, essence de vie, greffe.

Le poison se représente par des bulles, et non plus par une goutte : la goutte est réservée au saignement. L'arbre suit cette règle (section 10).

## 9. Le héros et ses attaques

Le Porte-Graine est dessiné par `godot/scripts/hero_art.gd` (classe `HeroArt`), ses attaques par `godot/scripts/skill_fx.gd` (classe `SkillFx`). Ce sont des dessins purs : ils ne changent jamais le jeu.

- **Poses** : repos qui respire, marche (rebond, pieds-racines qui alternent, cape qui traîne derrière le mouvement), esquive (corps étiré, silhouettes fantômes, traînée de feuilles), tir (recul et éclat de la lanterne), lancer (la lanterne s'embrase à la couleur de l'élément lancé, rayons en éventail), coup reçu (éclair, anneau rouge, yeux plissés, deux feuilles arrachées), mort (il se fane puis part en feuilles mortes), renaissance (une pousse sort de terre au sanctuaire, puis il se déploie).
- **États visibles sur lui** : vie basse (battement rouge en deux temps, lanterne qui vacille), invulnérable (anneau de feuilles de sève qui tourne ; pas pour le court répit après un coup), chez soi (tapis de mousse et lueurs qui montent). La barre de vie sous ses pieds n'apparaît que s'il est blessé.
- **Signatures** : chaque attaque a ses trois temps. Graine : collerette de feuilles au départ, traînée, corolle de sève à l'impact. Couronne d'épines : la couronne se dresse, file au bord de la zone, les épines se plantent. Fouet : la liane recule, claque en arc (secteur balayé visible), se rétracte en projetant du sang. Racines : le sol se fend en cercle, les racines jaillissent et enserrent, ondulent tant qu'elles tiennent, puis rentrent sous terre. Volée : éventail d'os et traits de visée, épines d'os tachées de sang, éclats à l'impact. Saignée : l'anneau se resserre, les saignements éclatent en couronnes de gouttes, le sang revient au héros. Nuage : volutes qui gonflent, tournent, crachent des bulles, bord en pointillés. Floraison : une fleur s'ouvre, l'onde de vie fait pousser l'herbe, les pétales s'envolent.
- La partie au sol (fissures, taches, secteur balayé) est dessinée sous les acteurs, le reste au-dessus des projectiles.
- Galerie : `TEST_ONLY=heros tools/visual-tests.sh` (captures `galerie_heros`, `galerie_competences_1` et `_2`) ; `tools/heros-anim.sh` en fait un GIF animé.

## 10. L'Arbre de vie

L'écran de l'arbre suit la même charte. Le dessin est dans `godot/scripts/tree_art.gd` ; `tree_ui.gd` choisit seulement quoi dessiner, où et à quel niveau de détail.

- **Fond** : une lueur verte part de la graine et se fond dans le secteur de chaque branche, teinté de sa couleur. Les anneaux de l'arbre sont des cernes de croissance légèrement ondulés, et une fine racine sépare deux branches. Tout reste sourd : le fond n'attire jamais l'œil plus qu'un nœud.
- **Nœuds** : les petits nœuds sont des perles, bombées une fois apprises (`Art.volume_circle`). Les autres sont des **médaillons**, avec la forme de leur type (cercle, losange du nœud clé et sa seconde couronne, hexagone de compétence, triangle de mutation, carré de maîtrise). Ils ont un double trait (contour sombre et anneau à la couleur de la branche). Un nœud verrouillé est sombre et terne. Un nœud disponible est sombre, avec un anneau vif. Un nœud appris est plein, avec du volume, et son icône est sombre.
- **Icônes** : ce sont celles de la charte (`Art.icon`). Une compétence montre sa propre icône (couronne, fouet, racines, volée, saignée, nuage, floraison), une statistique montre la sienne. Le poison est représenté par des bulles, le saignement par une goutte et les épines par une pointe. Les icônes n'apparaissent qu'au zoom proche.
- **Liens** : les liens verrouillés sont en brume. Ceux qui partent d'un nœud appris sont teintés de leur branche. Une branche apprise a une écorce sombre, un cœur coloré et un filet de lumière, et des feuilles y poussent au zoom proche.
- **Animations** : toutes sont de pures animations de dessin.
  - À l'ouverture, une onde de sève part de la graine et l'arbre se dévoile (0,75 s).
  - Du pollen monte doucement à l'écran.
  - La graine d'origine rayonne.
  - Les nœuds appris respirent, sur la période de respiration de la charte.
  - Quand on a des points à placer, les nœuds disponibles invitent au clic : leur anneau pulse et trois arcs tournent autour.
  - Le survol montre un anneau clair, une onde au premier instant et quatre épines qui tournent.
  - Un nœud qu'on apprend éclôt : il se gonfle, un éclair part, puis une onde, des feuilles qui s'ouvrent et des graines lumineuses.
  - La sève circule dans les branches apprises.
  - Les nœuds flétris couverts de cendre fument : des braises en montent.
  Avec l'option « réduire les effets », il n'y a ni pollen ni onde d'ouverture.
- **Performance** : les couches fixes ne sont redessinées qu'au zoom. Les ombres, le volume et les reflets n'apparaissent qu'au zoom proche, et les animations ne dessinent que ce qui est à l'écran. Le banc `tests/tree_bench.gd` doit rester au niveau d'avant.
- `tools/arbre-anim.sh` produit un GIF de ces animations.

## 11. Vérifier

- `tools/godot.sh --headless -s res://tests/art_test.gd` vérifie :
  - la palette et la hiérarchie de lecture ;
  - les éléments distincts, aussi pour les daltoniens ;
  - une icône et un élément par compétence ;
  - les formes d'annonce et les courbes d'animation.
- `TEST_ONLY=charte tools/visual-tests.sh` compare la planche (2560x1440) à sa référence.
