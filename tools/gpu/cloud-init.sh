#!/bin/bash
# Script de post-installation de l'instance GPU d'OVH (champ « script de post-installation » à la
# création, docs/gpu-ovh.md) : clone le dépôt et lance tools/gpu/setup.sh sans surveillance (pilote,
# redémarrage, puis VirtualGL, Godot et la veille). Le runner GitHub s'inscrit ensuite à la main
# (sudo RUNNER_TOKEN=… /opt/arborescence-gpu/Tree/tools/gpu/setup.sh). Journal :
# /var/log/arborescence-gpu-setup.log
set -eux
mkdir -p /opt/arborescence-gpu
cd /opt/arborescence-gpu
[ -d Tree ] || git clone --depth 1 --branch "${BRANCHE:-develop}" https://github.com/Dranto/Tree
chown -R ubuntu:ubuntu Tree
SUDO_USER=ubuntu AUTO_REBOOT=1 Tree/tools/gpu/setup.sh > /var/log/arborescence-gpu-setup.log 2>&1
