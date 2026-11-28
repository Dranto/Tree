#!/usr/bin/env bash
# Installation de la machine GPU d'OVH (Ubuntu 24.04, docs/gpu-ovh.md). À lancer une fois, en root,
# sur la machine neuve ; relançable sans danger (chaque étape vérifie ce qui est déjà fait).
#
#   sudo tools/gpu/setup.sh                       # pilote NVIDIA, VirtualGL, Xvfb, ffmpeg, Godot 4.7
#   sudo RUNNER_TOKEN=XXXX tools/gpu/setup.sh     # + le runner GitHub Actions (étiquette « gpu »)
#   sudo EXPORT_TEMPLATES=1 tools/gpu/setup.sh    # + les modèles d'export (builds : inutile d'habitude)
#
# RUNNER_TOKEN : jeton d'inscription à usage unique, valable une heure, que donne GitHub (Settings >
# Actions > Runners > New self-hosted runner). Il ne sert qu'ici et n'est écrit nulle part.
# Le pilote NVIDIA demande un redémarrage : le script le dit, il suffit de le relancer après.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "À lancer en root (sudo)"; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_URL="${REPO_URL:-https://github.com/Dranto/Tree}"
RUNNER_USER="${RUNNER_USER:-runner}"
RUNNER_NAME="${RUNNER_NAME:-ovh-gpu}"
RUNNER_LABELS="${RUNNER_LABELS:-gpu}"
GODOT_VERSION="${GODOT_VERSION:-4.7-stable}"
export DEBIAN_FRONTEND=noninteractive

echo "== Paquets de base"
apt-get update -q
apt-get install -yq curl ca-certificates gnupg unzip git jq python3 xvfb xauth ffmpeg mesa-utils \
  libgl1-mesa-dri libglx-mesa0 libegl1 libvulkan1 ubuntu-drivers-common

# L'utilisateur qui lance le script (ubuntu) accède aussi à la carte, pour tools/gpu/verifier.sh
# (effet à la prochaine connexion, donc après le redémarrage du pilote).
[ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ] && usermod -aG video,render "$SUDO_USER"

echo "== Pilote NVIDIA"
if ! command -v nvidia-smi >/dev/null || ! nvidia-smi >/dev/null 2>&1; then
  # Le pilote complet (avec OpenGL et EGL), pas la variante « calcul seul » (--gpgpu) sans OpenGL.
  ubuntu-drivers install
  echo
  echo "Pilote installé : redémarrer (sudo reboot), puis relancer ce script pour la suite."
  exit 0
fi
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader

echo "== VirtualGL (rendu OpenGL sur la carte depuis un écran virtuel Xvfb)"
if ! command -v vglrun >/dev/null; then
  curl -fsSL https://packagecloud.io/dcommander/virtualgl/gpgkey | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/VirtualGL.gpg
  curl -fsSL -o /etc/apt/sources.list.d/VirtualGL.list https://raw.githubusercontent.com/VirtualGL/repo/main/VirtualGL.list
  apt-get update -q
  apt-get install -yq virtualgl
fi
# vglrun n'est pas toujours dans le PATH (paquet officiel : /opt/VirtualGL/bin).
[ -x /usr/bin/vglrun ] || ln -sf /opt/VirtualGL/bin/vglrun /usr/local/bin/vglrun

echo "== Utilisateur du runner : $RUNNER_USER (sans sudo, accès à la carte)"
id "$RUNNER_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$RUNNER_USER"
usermod -aG video,render "$RUNNER_USER"

echo "== Godot $GODOT_VERSION (même cache que tools/godot.sh)"
sudo -u "$RUNNER_USER" -H bash -c "
  set -e
  c=\$HOME/.cache/godot/$GODOT_VERSION
  b=\$c/Godot_v${GODOT_VERSION}_linux.x86_64
  if [ ! -x \"\$b\" ]; then
    mkdir -p \"\$c\"
    curl -fsSL --retry 3 -o \"\$c/godot.zip\" https://github.com/godotengine/godot-builds/releases/download/$GODOT_VERSION/Godot_v${GODOT_VERSION}_linux.x86_64.zip
    unzip -oq \"\$c/godot.zip\" -d \"\$c\" && rm -f \"\$c/godot.zip\" && chmod +x \"\$b\"
  fi
  \"\$b\" --version
"
if [ "${EXPORT_TEMPLATES:-0}" = 1 ]; then
  sudo -u "$RUNNER_USER" -H bash -c "
    set -e
    d=\$HOME/.local/share/godot/export_templates/${GODOT_VERSION/-/.}
    [ -f \"\$d/version.txt\" ] && exit 0
    mkdir -p \"\$d\" && cd \"\$(mktemp -d)\"
    curl -fsSL --retry 3 -o t.tpz https://github.com/godotengine/godot-builds/releases/download/$GODOT_VERSION/Godot_v${GODOT_VERSION}_export_templates.tpz
    unzip -q t.tpz && mv templates/* \"\$d/\"
  "
fi

echo "== Mise en réserve automatique quand la machine ne sert plus"
install -d -m 755 /opt/arborescence-gpu
install -m 755 "$HERE/veille.sh" "$HERE/../ovh-gpu.sh" /opt/arborescence-gpu/
cat > /etc/systemd/system/arborescence-gpu-veille.service <<UNIT
[Unit]
Description=Remet la machine GPU en réserve (shelve) quand elle ne sert plus
[Service]
Type=oneshot
ExecStart=/opt/arborescence-gpu/veille.sh
UNIT
cat > /etc/systemd/system/arborescence-gpu-veille.timer <<UNIT
[Unit]
Description=Vérifie toutes les 5 minutes si la machine GPU sert encore
[Timer]
OnBootSec=10min
OnUnitActiveSec=5min
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now arborescence-gpu-veille.timer
if [ ! -f /etc/arborescence-gpu.env ]; then
  install -m 600 /dev/null /etc/arborescence-gpu.env
  cat > /etc/arborescence-gpu.env <<'ENV'
# Clé d'API d'OVH de la machine elle-même (droits : GET sur l'instance, POST shelve). À remplir par Antoine.
# Tant que ce fichier est vide, la veille ne fait rien (la CI éteint quand même la machine après chaque run).
OVH_APPLICATION_KEY=
OVH_APPLICATION_SECRET=
OVH_CONSUMER_KEY=
OVH_PROJECT_ID=
OVH_INSTANCE_ID=
# Minutes sans travail avant la remise en réserve.
IDLE_MINUTES=30
ENV
  echo "À remplir : /etc/arborescence-gpu.env (sudo nano /etc/arborescence-gpu.env)"
fi

echo "== Runner GitHub Actions"
RDIR="/home/$RUNNER_USER/actions-runner"
if [ -f "$RDIR/.runner" ]; then
  echo "Runner déjà inscrit ($(jq -r .agentName "$RDIR/.runner" 2>/dev/null))"
elif [ -n "${RUNNER_TOKEN:-}" ]; then
  ver=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name | sed 's/^v//')
  sudo -u "$RUNNER_USER" -H bash -c "
    set -e
    mkdir -p '$RDIR' && cd '$RDIR'
    curl -fsSL -o r.tgz https://github.com/actions/runner/releases/download/v$ver/actions-runner-linux-x64-$ver.tar.gz
    tar xzf r.tgz && rm r.tgz
    ./config.sh --unattended --url '$REPO_URL' --token '$RUNNER_TOKEN' --name '$RUNNER_NAME' \
      --labels '$RUNNER_LABELS' --work _work --replace
  "
  (cd "$RDIR" && ./bin/installdependencies.sh >/dev/null && ./svc.sh install "$RUNNER_USER" && ./svc.sh start)
else
  echo "Pas de RUNNER_TOKEN : runner non inscrit (relancer avec sudo RUNNER_TOKEN=… tools/gpu/setup.sh)"
fi

echo
echo "Fini. Vérifier le rendu (sans sudo) : tools/gpu/verifier.sh"
