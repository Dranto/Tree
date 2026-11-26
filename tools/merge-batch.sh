#!/usr/bin/env bash
# Fusion par lots : réunit plusieurs PR vers develop sur une seule branche, pour ne faire tourner la
# CI qu'une fois et ne refaire les références visuelles qu'une fois, au lieu d'une cascade (chaque
# fusion obligeait les PR suivantes à se remettre à jour, refaire leurs références et repasser la CI).
#
#   tools/merge-batch.sh 152 153 154   # sur la branche courante, repartie de origin/develop
#
# Pour chaque PR, dans l'ordre : fusion (--no-ff) de sa tête dans la branche du lot. Un conflit qui ne
# touche que des références visuelles (godot/tests/visual/reference/) est résolu en gardant la version
# de la PR : ces images sont refaites ensuite par la CI. Tout autre conflit : la PR est laissée de côté
# (fusion annulée) et signalée à la fin ; elle se rebase à part, ou entre dans le lot suivant.
#
# Ensuite (docs/ci.md) :
#   1. git push, puis ouvrir la PR du lot vers develop (titre « Lot : #152, #153, #154 ») ;
#   2. si les tests visuels signalent des écarts attendus : tools/refs-from-ci.sh --in-ci, puis git pull ;
#   3. CI verte : fusionner la PR du lot par un commit de fusion (pas de squash ni de rebase) ; GitHub
#      marque alors chaque PR du lot comme fusionnée, puisque ses commits sont dans develop. Une PR qui a
#      reçu un commit après la création du lot reste ouverte : la refaire entrer ou la fusionner à part.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REPO="${GH_REPO:-Dranto/Tree}"
BASE="${BASE:-develop}"
REFS="godot/tests/visual/reference/"
[ $# -gt 0 ] || { sed -n '2,20p' "$0"; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "Arbre de travail modifié : committer ou ranger d'abord."; exit 1; }
branch=$(git rev-parse --abbrev-ref HEAD)
case "$branch" in develop|main|master|HEAD) echo "Créer d'abord une branche pour le lot (pas « $branch »)."; exit 1 ;; esac

git fetch -q origin "$BASE"
# La branche du lot repart de develop : refuser d'effacer du travail qui n'y est pas.
if [ -n "$(git rev-list FETCH_HEAD..HEAD)" ] && [ -z "${FORCE:-}" ]; then
  echo "$branch a des commits absents de origin/$BASE : prendre une branche neuve (ou FORCE=1 pour les effacer)."
  exit 1
fi
git reset -q --hard FETCH_HEAD
echo "Lot sur $branch, depuis origin/$BASE ($(git rev-parse --short HEAD))"

merged=()
skipped=()
for n in "$@"; do
  n="${n#\#}"
  title=$(gh api "repos/$REPO/pulls/$n" --jq '.title' 2>/dev/null || echo "PR $n")
  git fetch -q origin "pull/$n/head"
  sha=$(git rev-parse --short FETCH_HEAD)
  if git merge -q --no-ff --no-edit -m "Lot : fusion de #$n ($title)" FETCH_HEAD >/dev/null 2>&1; then
    echo "ok     #$n $sha $title"
    merged+=("#$n")
    continue
  fi
  conflicts=$(git diff --name-only --diff-filter=U)
  others=$(echo "$conflicts" | grep -v "^$REFS" || true)
  if [ -n "$conflicts" ] && [ -z "$others" ]; then
    echo "$conflicts" | xargs git checkout --theirs --
    echo "$conflicts" | xargs git add --
    git commit -q --no-edit
    echo "ok     #$n $sha $title ($(echo "$conflicts" | wc -l) références en conflit : version de la PR, à refaire par la CI)"
    merged+=("#$n")
  else
    git merge --abort
    echo "ÉCART  #$n $sha $title : conflit hors des références"
    echo "$others" | head -10 | sed 's/^/         /'
    skipped+=("#$n")
  fi
done

echo
echo "Dans le lot : ${merged[*]:-aucune}"
[ ${#skipped[@]} -eq 0 ] || echo "Laissées de côté (conflit à résoudre à part) : ${skipped[*]}"
[ ${#merged[@]} -gt 0 ] || exit 1
echo "Suite : git push -u origin $branch (--force-with-lease si la branche existait), PR « Lot : ${merged[*]} » vers $BASE,"
echo "puis tools/refs-from-ci.sh --in-ci si les tests visuels montrent des écarts attendus (docs/ci.md)."
