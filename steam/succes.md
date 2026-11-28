# Succès Steam (jalon 12 D, jalon 14 S)

Neuf succès : un par boss et deux pour le New Game+. Un succès de boss est débloqué à la mort du boss (et rattrapé au chargement d'une sauvegarde où il est déjà vaincu).
À créer sur Steamworks › Statistiques et succès › Succès, avec ces **identifiants exacts** (API Name).
Textes anglais alignés sur le glossaire validé par Antoine (`godot/locale/glossaire.md`, 25/11).
`CYCLE_2` et `CYCLE_3` se débloquent à la mort de la Flétrissure pendant le cycle 2 (ou 3) ; finir le cycle 3 donne
aussi `CYCLE_2`, et les cycles suivants n'ont pas de succès de plus. Rattrapés au chargement d'une sauvegarde
de ce cycle dont la Flétrissure est déjà vaincue.
Seul `BOSS_RONCE` existe dans la démo (pas de New Game+ dans la démo : ni `CYCLE_2` ni `CYCLE_3`) (la démo a son propre App ID et donc ses propres succès).

| API Name | Nom (FR) | Description (FR) | Name (EN) | Description (EN) | Caché |
| --- | --- | --- | --- | --- | --- |
| `BOSS_RONCE` | La ronce apaisée | Vaincre la Mère-Ronce. | The Bramble Soothed | Defeat the Bramble Mother. | non |
| `BOSS_SPORE` | Le marais respire | Vaincre l'Amanite-Mère. | The Marsh Breathes | Defeat the Amanita Mother. | non |
| `BOSS_VENT` | Les cendres retombent | Vaincre le Harfang de cendre. | The Ashes Settle | Defeat the Ash Owl. | non |
| `BOSS_SEVE` | La sève remonte | Vaincre le Saule exsangue. | The Sap Rises | Defeat the Bloodless Willow. | non |
| `BOSS_AUBE` | Le verre se brise | Vaincre la Phalène de verre. | The Glass Breaks | Defeat the Glass Moth. | non |
| `BOSS_RACINE` | La pierre s'éveille | Vaincre l'Ancien pétrifié. | The Stone Awakens | Defeat the Petrified Elder. | non |
| `BOSS_FINALE` | Le monde refleurit | Vaincre la Flétrissure sous la graine. | The World Blooms Again | Defeat the Blight beneath the seed. | oui (révèle la fin) |
| `CYCLE_2` | L'aventure recommence | Vaincre la Flétrissure au deuxième cycle. | The Adventure Begins Anew | Defeat the Blight in the second cycle. | non |
| `CYCLE_3` | Le cycle se referme | Vaincre la Flétrissure au troisième cycle. | The Cycle Closes | Defeat the Blight in the third cycle. | non |

Icônes : 64×64 px, `steam/art/fr/succes/<API Name>.png` (débloqué) et `<API Name>_gris.png` (verrouillé), le boss dans une médaille d'or ; refaites par `tools/steam-art.sh` (tâche H).

**À faire pour `CYCLE_2` et `CYCLE_3`** : leurs icônes (`steam/art/fr/succes/CYCLE_2.png`, `CYCLE_2_gris.png`, idem `CYCLE_3`) n'existent pas
encore ; `tools/steam-art.sh` ne sait faire que les médailles de boss. Steamworks les demande à la création des succès.
