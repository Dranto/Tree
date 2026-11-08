# Sève

Jeu incrémental dont tout le gameplay tient dans un **arbre de compétences géant** : 1 567 nœuds répartis en six branches et 18 anneaux concentriques, à explorer en zoomant et en se déplaçant.

## Jouer

Ouvrir `index.html` dans un navigateur. Aucune installation ni étape de build.

- Glisser pour se déplacer, molette ou pincement pour zoomer.
- Cliquer un nœud voisin de ta zone pour l'acheter avec de la sève.
- `Espace` ou le bouton **Récolter** pour gagner de la sève à la main.
- **Hiver** : l'arbre repart de zéro contre des graines (+10 % de production chacune) et le givre recule de 3 anneaux.

## Les branches

| Branche | Rôle |
| --- | --- |
| Racines | Production de sève brute |
| Feuilles | Multiplicateurs de production |
| Fleurs | Puissance de récolte manuelle |
| Écorce | Réduction des coûts |
| Mycélium | Synergie : chaque nœud possédé renforce la production |
| Fruits | Graines, saisons et gains hors ligne |

Chaque branche a des **nœuds notables** (plus puissants) et trois **nœuds clés** (losanges, anneaux 5, 10 et 15) qui changent les règles.
Chaque achat augmente légèrement le prix des suivants, donc l'ordre dans lequel on explore compte.

## Code

- `src/tree.js` : génération procédurale et déterministe de l'arbre (positions, liens, effets).
- `src/game.js` : état, économie, hivers (prestige), sauvegarde locale et gains hors ligne.
- `src/render.js` : rendu Canvas, caméra, état visuel des nœuds.
- `src/main.js` : boucle de jeu, interface, contrôles souris et tactiles.

Les constantes d'équilibrage sont en tête de `src/game.js` et dans `nodeEffects` de `src/tree.js`.
