#!/usr/bin/env bash
# Références visuelles prises dans la CI : copie dans godot/tests/visual/reference/ les captures que
# les tests visuels de la CI ont trouvées changées (diff, absente, taille), au lieu de tout refaire
# en local avec tools/visual-tests.sh --update (10 minutes, et le rendu de la machine locale diffère
# un peu de celui de la CI : --update y réécrit toutes les images).
#
#   tools/refs-from-ci.sh            # dernier run « Tests visuels » du commit courant (HEAD)
#   tools/refs-from-ci.sh 123456789  # ce run-là (numéro dans l'URL du run)
#   tools/refs-from-ci.sh --list     # montre seulement les captures changées, sans rien copier
#   tools/refs-from-ci.sh --in-ci [branche]  # tout se fait dans la CI (sessions cloud : le stockage des
#                                    # artefacts n'y est pas joignable) : les tests visuels de la branche
#                                    # (par défaut la branche courante, déjà poussée) prennent leurs
#                                    # captures changées comme références et les commitent sur
#                                    # ci-refs/<branche> (≈ 5 minutes) ;
#   tools/refs-from-ci.sh --pull     # puis : reprend ce commit sur la branche courante ; il reste à pousser.
#
# Ensuite : regarder les images changées (git diff --stat, rapport.html de l'artefact), committer,
# pousser. Les tests visuels du commit suivant comparent alors aux captures de la CI elle-même.
# Il faut gh (REST suffit) ; GH_REPO change de dépôt (Dranto/Tree par défaut).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF="$ROOT/godot/tests/visual/reference"
REPO="${GH_REPO:-Dranto/Tree}"
LIST=0
RUN=""
if [ "${1:-}" = "--in-ci" ]; then
  branch="${2:-$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)}"
  case "$branch" in develop|main|master|HEAD) echo "Refusé sur « $branch » : seulement une branche de PR."; exit 1 ;; esac
  gh api -X POST "repos/$REPO/actions/workflows/visual-tests.yml/dispatches" \
    -f ref="$branch" -f 'inputs[references]=true' >/dev/null
  echo "Tests visuels lancés sur $branch avec prise des références (≈ 5 minutes)."
  echo "Ensuite : tools/refs-from-ci.sh --pull, vérifier les images, git push."
  echo "Suivi : https://github.com/$REPO/actions/workflows/visual-tests.yml?query=branch%3A$branch"
  exit 0
fi
if [ "${1:-}" = "--pull" ]; then
  branch=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)
  git -C "$ROOT" fetch -q origin "ci-refs/$branch" || { echo "Pas de ci-refs/$branch : le run --in-ci est-il fini, avec des captures changées ?"; exit 1; }
  parent=$(git -C "$ROOT" rev-parse FETCH_HEAD^)
  if [ "$parent" != "$(git -C "$ROOT" rev-parse HEAD)" ]; then
    echo "ci-refs/$branch a été fait sur $(git -C "$ROOT" rev-parse --short "$parent"), pas sur HEAD : le code a changé depuis,"
    echo "les captures risquent d'être fausses. Relancer tools/refs-from-ci.sh --in-ci."
    exit 1
  fi
  git -C "$ROOT" merge -q --ff-only FETCH_HEAD
  git -C "$ROOT" show --stat --format='%s' HEAD | head -20
  git -C "$ROOT" push -q origin --delete "ci-refs/$branch" 2>/dev/null || true
  echo "Références reprises. Vérifier les images, puis git push."
  exit 0
fi
for a in "$@"; do
  case "$a" in
    --list) LIST=1 ;;
    *) RUN="$a" ;;
  esac
done

if [ -z "$RUN" ]; then
  sha=$(git -C "$ROOT" rev-parse HEAD)
  RUN=$(gh api "repos/$REPO/actions/workflows/visual-tests.yml/runs?head_sha=$sha&per_page=5" \
    --jq '[.workflow_runs[] | select(.status == "completed")][0].id // empty')
  if [ -z "$RUN" ]; then
    echo "Aucun run « Tests visuels » terminé pour $sha : pousser le commit, attendre la fin du run,"
    echo "ou donner le numéro d'un run (tools/refs-from-ci.sh <run>)."
    exit 1
  fi
fi
echo "Run $RUN (https://github.com/$REPO/actions/runs/$RUN)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# Une part qui plante ne bloque pas les autres : on prend les captures de chaque part.
gh run download "$RUN" -R "$REPO" -p 'tests-visuels-part-*' -D "$TMP" >/dev/null
results=$(cat "$TMP"/*/results.txt 2>/dev/null || true)
[ -n "$results" ] || { echo "Pas de results.txt dans les artefacts du run $RUN."; exit 1; }

changed=$(echo "$results" | awk '$2 != "ok" && $2 != "maj" {print $1, $2}')
if [ -z "$changed" ]; then
  echo "Aucune capture changée dans ce run : rien à copier."
  exit 0
fi
n=0
while read -r name status; do
  src=$(ls "$TMP"/*/"$name.png" 2>/dev/null | head -1)
  if [ -z "$src" ]; then
    echo "  $name ($status) : capture absente de l'artefact, ignorée"
    continue
  fi
  echo "  $name ($status)"
  [ "$LIST" = 1 ] || cp "$src" "$REF/$name.png"
  n=$((n + 1))
done <<<"$changed"
if [ "$LIST" = 1 ]; then
  echo "$n captures changées (rien copié : --list)."
else
  echo "$n références remplacées par les captures de la CI. Vérifier puis committer godot/tests/visual/reference/."
fi
