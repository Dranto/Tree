# CI et fusions

Ce qui tourne sur chaque PR vers `develop`, combien de temps, et comment fusionner vite.

## Ce qui tourne (26/11)

| Workflow | Jobs en parallèle | Durée d'un job | Lancé quand la PR touche |
| --- | --- | --- | --- |
| Banc de performance | 4 (jeu 1600×900, jeu 1280×800, pics + six régions, pics à six régions + finale) | ≈ 4 min | le jeu (`godot/` hors `godot/tests/`, sauf `tests/regions/`), les outils du banc |
| Tests visuels | 4 parts + rapport | ≈ 4 min | tout sauf la documentation |
| Tests de logique | 2 parts | ≈ 4 min | tout sauf la documentation |
| Builds | 2 (jeu, démo ; Windows puis Linux) | ≈ 4 min | le jeu hors `godot/tests/` et `steam/` |
| Arbre de vie | 1 | ≈ 2 min | tout sauf la documentation |

« Documentation » : `docs/`, tous les `*.md`, `prototype-web/`, `.claude/`.

Avant ce découpage, le banc de performance tenait en un seul job de 14 minutes : c'était lui qui
fixait la durée de la CI. Les tests de logique (5 minutes de tests) et les tests visuels (deux parts
de 6 minutes 30) suivaient. Maintenant chaque job dure environ 4 minutes, installation comprise.

Garde-fous gardés tels quels : seuls les **bancs en paires** (jeu 1600×900 et 1280×800, mesurés
contre la branche visée sur la même machine) font échouer le banc ; chaque banc tourne seul sur sa
machine (deux bancs sur une machine fausseraient les mesures). Les autres bancs sont pour information.

Un nouveau push sur une PR **annule** les runs en cours de l'ancien commit. Sur `develop`, les runs
s'enchaînent sans annulation, mais un run en attente est remplacé par le plus récent.

Limite du compte GitHub gratuit : 20 jobs à la fois. Une PR en occupe 14 au plus ; deux PR poussées
au même moment font donc attendre quelques jobs.

## Répartition des parts

- Tests visuels : `SHARD=k/4 tools/visual-tests.sh`, répartition selon `WEIGHT` (durée de chaque
  scénario) dans `tools/visual-tests.sh`. Ajouter le poids d'un nouveau scénario long.
- Tests de logique : `SHARD=k/2 tools/unit-tests.sh`, répartition selon `WEIGHT` dans
  `tools/unit-tests.sh` ; les plus longs sont aussi lancés en premier. Un test sans poids compte 10 s.
  Les contrôles de traduction (`tools/i18n.sh`) tournent dans la part 1.

## Références visuelles sans les refaire en local

Après un rebase ou une fusion de `develop`, les tests visuels signalent souvent des écarts attendus.
Au lieu de `tools/visual-tests.sh --update` en local (10 minutes, et le rendu d'une autre machine
diffère un peu de celui de la CI, si bien que tout est réécrit) :

```
git push                              # la branche de la PR
tools/refs-from-ci.sh --in-ci         # ou --in-ci <branche> ; ≈ 5 minutes
tools/refs-from-ci.sh --pull          # une fois le run fini
git push
```

La CI rejoue les tests visuels de la branche, copie les captures changées dans
`godot/tests/visual/reference/` et commite le tout sur une branche à part, `ci-refs/<branche>`.
`--pull` reprend ce commit sur la branche courante (seulement si le code n'a pas bougé depuis) ; le
push qui suit relance toute la CI normalement. Regarder les images avant de pousser : le rapport
(`rapport.html`) est dans l'artefact « tests-visuels » du run.

Le commit n'est pas poussé directement sur la branche de la PR : poussé par le jeton de la CI, il y
laissait des runs « en attente d'approbation » au lieu de la CI (vu le 26/11). Une session cloud
ne peut pas supprimer `ci-refs/<branche>` ensuite : la branche reste, et le run suivant l'écrase.

Là où le stockage des artefacts de GitHub est joignable (poste d'Antoine), `tools/refs-from-ci.sh`
sans option copie les captures changées du dernier run du commit courant, à committer soi-même.

## Fusionner par lots

Quand plusieurs PR attendent, les fusionner une par une force chacune à se remettre à jour, refaire
ses références et repasser la CI. Un lot ne fait tout cela qu'une fois :

```
git checkout -B <branche-du-lot>      # branche neuve
tools/merge-batch.sh 152 153 154      # repart de origin/develop et fusionne les PR dans l'ordre
git push -u origin <branche-du-lot>
```

1. Ouvrir la PR du lot vers `develop`, titre « Lot : #152, #153, #154 ».
2. Si les tests visuels montrent des écarts attendus : `tools/refs-from-ci.sh --in-ci`, puis `--pull` et `git push`.
3. CI verte : fusionner la PR du lot **par un commit de fusion** (pas de squash ni de rebase). GitHub
   marque alors chaque PR du lot comme fusionnée, puisque ses commits sont dans `develop`.

Un conflit qui ne touche que des références visuelles est résolu en gardant la version de la PR (la
CI les refait à l'étape 2). Tout autre conflit laisse la PR de côté : le script la signale, elle se
rebase à part ou entre dans le lot suivant. Une PR qui reçoit un commit après la création du lot
reste ouverte : la remettre dans un lot ou la fusionner à part.

Pas de file de fusion GitHub (merge queue) : elle n'existe que pour les dépôts d'une organisation.

## Rendus lourds sur la machine GPU

Films, bande-annonce, grandes captures et robot d'aventure peuvent tourner sur une instance GPU
d'OVH allumée à la demande (workflow « Rendus GPU », `tools/gpu-run.sh`) : voir
[gpu-ovh.md](gpu-ovh.md). Les tests visuels et les bancs des PR restent sur les machines de GitHub.
