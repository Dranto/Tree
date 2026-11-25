# Succès Steam (jalon 12 D)

Un succès par boss, débloqué à sa mort (et rattrapé au chargement d'une sauvegarde où il est déjà vaincu).
À créer sur Steamworks › Statistiques et succès › Succès, avec ces **identifiants exacts** (API Name).
Textes anglais provisoires : la tâche B (anglais) les alignera sur la liste de noms validée.
Seul `BOSS_RONCE` existe dans la démo (la démo a son propre App ID et donc ses propres succès).

| API Name | Nom (FR) | Description (FR) | Name (EN) | Description (EN) | Caché |
| --- | --- | --- | --- | --- | --- |
| `BOSS_RONCE` | La ronce apaisée | Vaincre la Mère-Ronce. | The Bramble Soothed | Defeat the Mother Bramble. | non |
| `BOSS_SPORE` | Le marais respire | Vaincre l'Amanite-Mère. | The Marsh Breathes | Defeat the Mother Amanita. | non |
| `BOSS_VENT` | Les cendres retombent | Vaincre le Harfang de cendre. | The Ashes Settle | Defeat the Ash Owl. | non |
| `BOSS_SEVE` | La sève remonte | Vaincre le Saule exsangue. | The Sap Rises | Defeat the Bloodless Willow. | non |
| `BOSS_AUBE` | Le verre se brise | Vaincre la Phalène de verre. | The Glass Breaks | Defeat the Glass Moth. | non |
| `BOSS_RACINE` | La pierre s'éveille | Vaincre l'Ancien pétrifié. | The Stone Awakens | Defeat the Petrified Elder. | non |
| `BOSS_FINALE` | Le monde refleurit | Vaincre la Flétrissure sous la graine. | The World Blooms Again | Defeat the Blight beneath the seed. | oui (révèle la fin) |

Icônes : 64×64 px, `steam/art/fr/succes/<API Name>.png` (débloqué) et `<API Name>_gris.png` (verrouillé), le boss dans une médaille d'or ; refaites par `tools/steam-art.sh` (tâche H).
