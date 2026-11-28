#!/usr/bin/env bash
# Rendus lourds sur la machine GPU d'OVH depuis une session (docs/gpu-ovh.md) : lance le workflow
# « Rendus GPU » sur la branche courante (déjà poussée), puis récupère ses sorties.
#
#   tools/gpu-run.sh lancer NOM "COMMANDE" [auto|gpu|cpu]
#       ex. tools/gpu-run.sh lancer boss-ronce "tools/boss-film.sh rendus/boss ronce"
#           tools/gpu-run.sh lancer robot "VARIANTES='0 1 2 3' tools/aventure.sh"
#   tools/gpu-run.sh etat NOM               # où en est le dernier run de ce nom
#   tools/gpu-run.sh recuperer NOM DOSSIER  # copie les sorties (branche ci-rendus/NOM) dans DOSSIER
#
# La commande tourne à la racine du dépôt ; ce qu'elle écrit dans rendus/ et godot/autotest/ revient.
# Sans gh : le même workflow se lance avec l'outil GitHub de la session (déclenchement du workflow
# gpu-rendus.yml sur la branche, entrées commande, nom, machine).
# Il faut gh (REST suffit) ; GH_REPO change de dépôt (Dranto/Tree par défaut).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="${GH_REPO:-Dranto/Tree}"
case "${1:-}" in
  lancer)
    nom="${2:?nom}"; cmd="${3:?commande}"; machine="${4:-auto}"
    branch=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)
    [ "$branch" != HEAD ] || { echo "Pas sur une branche"; exit 1; }
    if [ "$(git -C "$ROOT" rev-parse HEAD)" != "$(git -C "$ROOT" rev-parse "origin/$branch" 2>/dev/null)" ]; then
      echo "Attention : HEAD n'est pas poussé, le rendu portera sur origin/$branch."
    fi
    gh api -X POST "repos/$REPO/actions/workflows/gpu-rendus.yml/dispatches" -f ref="$branch" \
      -f "inputs[commande]=$cmd" -f "inputs[nom]=$nom" -f "inputs[machine]=$machine" >/dev/null
    echo "Rendu « $nom » lancé sur $branch (allumage de la machine GPU : 5 à 15 minutes)."
    echo "Suivi : https://github.com/$REPO/actions/workflows/gpu-rendus.yml"
    echo "Ensuite : tools/gpu-run.sh recuperer $nom <dossier>"
    ;;
  etat)
    nom="${2:?nom}"
    gh api "repos/$REPO/actions/workflows/gpu-rendus.yml/runs?per_page=20" \
      --jq '.workflow_runs[:5][] | "\(.status) \(.conclusion // "-") \(.head_branch) \(.html_url)"'
    git -C "$ROOT" ls-remote origin "refs/heads/ci-rendus/$nom" | grep -q . \
      && echo "Sorties de « $nom » disponibles : tools/gpu-run.sh recuperer $nom <dossier>" \
      || echo "Pas encore de sorties pour « $nom »"
    ;;
  recuperer)
    nom="${2:?nom}"; dest="$(realpath -m "${3:?dossier}")"
    git -C "$ROOT" fetch -q --depth 1 origin "ci-rendus/$nom" || { echo "Pas de ci-rendus/$nom (run pas fini ?)"; exit 1; }
    mkdir -p "$dest"
    git -C "$ROOT" archive FETCH_HEAD | tar -x -C "$dest"
    git -C "$ROOT" log -1 --format='%s' FETCH_HEAD
    find "$dest" -type f \( -name '*.gif' -o -name '*.mp4' -o -name '*.png' -o -name 'journal.txt' \) | head -30
    echo "Sorties dans $dest"
    ;;
  *) sed -n '2,13p' "$0"; exit 2 ;;
esac
