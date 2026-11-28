#!/usr/bin/env bash
# Allume, éteint et interroge la machine GPU d'OVH Public Cloud (docs/gpu-ovh.md) par l'API d'OVH.
#   tools/ovh-gpu.sh status   # affiche l'état (ACTIVE, SHELVED_OFFLOADED, UNSHELVING…)
#   tools/ovh-gpu.sh start    # rallume (unshelve) puis attend ACTIVE ; code 1 si elle ne démarre pas
#   tools/ovh-gpu.sh stop     # remise en réserve (shelve) : plus de facturation horaire, seul le
#                             # disque sauvegardé est facturé. Un simple arrêt resterait facturé.
#
# Variables (secrets du dépôt dans la CI, /etc/arborescence-gpu.env sur la machine elle-même) :
#   OVH_APPLICATION_KEY, OVH_APPLICATION_SECRET, OVH_CONSUMER_KEY   clés de l'API (créées par Antoine)
#   OVH_PROJECT_ID    identifiant du projet Public Cloud (« serviceName »)
#   OVH_INSTANCE_ID   identifiant de l'instance GPU
#   OVH_ENDPOINT      https://eu.api.ovh.com/1.0 par défaut
#   START_TIMEOUT     secondes d'attente de ACTIVE (1800 par défaut : rallumer une machine remise
#                     en réserve recopie son disque, compter 5 à 15 minutes)
# Le script ne fait que GET sur l'instance et POST shelve, unshelve et start : la clé d'API peut
# être limitée à ces seuls droits (voir le guide).
set -euo pipefail
: "${OVH_APPLICATION_KEY:?}" "${OVH_APPLICATION_SECRET:?}" "${OVH_CONSUMER_KEY:?}" "${OVH_PROJECT_ID:?}" "${OVH_INSTANCE_ID:?}"
EP="${OVH_ENDPOINT:-https://eu.api.ovh.com/1.0}"
BASE="/cloud/project/$OVH_PROJECT_ID/instance/$OVH_INSTANCE_ID"

# Appel signé ($1 méthode, $2 chemin). Signature : "$1$" suivi du SHA1 de
# secret+clé consommateur+méthode+URL+corps+horodatage (horodatage pris sur le serveur d'OVH).
ovh() {
  local method="$1" url="$EP$2" body="" ts hash
  ts=$(curl -fsS --retry 3 "$EP/auth/time")
  hash=$(printf '%s' "$OVH_APPLICATION_SECRET+$OVH_CONSUMER_KEY+$method+$url+$body+$ts" | sha1sum | cut -d' ' -f1)
  curl -fsS --retry 3 -X "$method" "$url" \
    -H "X-Ovh-Application: $OVH_APPLICATION_KEY" -H "X-Ovh-Consumer: $OVH_CONSUMER_KEY" \
    -H "X-Ovh-Timestamp: $ts" -H "X-Ovh-Signature: \$1\$$hash" -H "Content-Type: application/json"
}

status() { ovh GET "$BASE" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status","INCONNU"))'; }

case "${1:-status}" in
  status) status ;;
  start)
    s=$(status)
    echo "Machine GPU : $s"
    case "$s" in
      ACTIVE) exit 0 ;;
      SHELVED|SHELVED_OFFLOADED) ovh POST "$BASE/unshelve" >/dev/null; echo "Rallumage demandé (unshelve)" ;;
      SHUTOFF|STOPPED) ovh POST "$BASE/start" >/dev/null; echo "Démarrage demandé" ;;
      UNSHELVING|BUILD|BUILDING|REBOOT|HARD_REBOOT|SHELVING) echo "Déjà en cours de changement d'état" ;;
      *) echo "État inattendu : $s"; exit 1 ;;
    esac
    deadline=$(( $(date +%s) + ${START_TIMEOUT:-1800} ))
    while [ "$(date +%s)" -lt "$deadline" ]; do
      sleep 20
      s=$(status)
      case "$s" in
        ACTIVE) echo "Machine GPU allumée"; exit 0 ;;
        ERROR) echo "La machine GPU est en erreur (plus de carte libre dans la région ?)"; exit 1 ;;
        SHELVED|SHELVED_OFFLOADED) echo "Toujours en réserve : le rallumage a échoué (pas de carte libre ?)"; exit 1 ;;
      esac
    done
    echo "Pas allumée après ${START_TIMEOUT:-1800} s (état : $s)"; exit 1 ;;
  stop)
    s=$(status)
    case "$s" in
      SHELVED|SHELVED_OFFLOADED|SHELVING) echo "Déjà en réserve ($s)" ;;
      ACTIVE|SHUTOFF|STOPPED) ovh POST "$BASE/shelve" >/dev/null; echo "Remise en réserve demandée (shelve), était $s" ;;
      *) echo "Pas de remise en réserve dans l'état $s"; exit 1 ;;
    esac ;;
  *) echo "Usage : tools/ovh-gpu.sh status|start|stop"; exit 2 ;;
esac
