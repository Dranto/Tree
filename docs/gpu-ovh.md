# Machine GPU chez OVH (rendus lourds)

Les machines des sessions cloud et de la CI n'ont pas de carte graphique : Godot y dessine en
logiciel (mesa llvmpipe), et les films, bandes-annonces et grandes captures prennent des heures.
Une instance GPU d'OVH Public Cloud, facturée à l'heure et allumée seulement pour ces travaux, les
fait sur une vraie carte NVIDIA. Elle sert de runner GitHub Actions (étiquette `gpu`) au workflow
**Rendus GPU** (`.github/workflows/gpu-rendus.yml`).

Ce guide dit ce qu'Antoine commande et règle lui-même (compte, paiement, clés). Aucune clé ne
passe par une session : elles vont dans les secrets du dépôt et sur la machine.

## Ce qui va sur la carte, ce qui reste où il est

| Travail | Où | Pourquoi |
| --- | --- | --- |
| Films (`boss-film.sh`, `eclat-film.sh`, `tour-film.sh`…), bande-annonce (`steam-trailer.sh`), art Steam, planches | **machine GPU** | Le rendu est le goulot : la carte le fait bien plus vite, en qualité au moins égale. |
| Robot d'aventure (`aventure.sh`) | **machine GPU** (pour ses cœurs) | Le robot tourne en `--headless`, sans rendu : la carte ne l'accélère pas, mais la machine conseillée a 22 cœurs contre 4, donc 5 à 10 passages en parallèle au lieu de 2. |
| Bancs pour information, profils | machine GPU sur demande | Mesure du jeu sur une vraie carte, plus proche d'un joueur. Chiffres à ne comparer **qu'entre eux** (voir plus bas). |
| Tests visuels des PR | machines de GitHub | Les références sont rendues en logiciel : sur la carte, toutes les captures différeraient. `tools/visual-tests.sh` force le rendu logiciel même sur la machine GPU. |
| Bancs en paires des PR | machines de GitHub | Budgets calibrés sur ces machines ; la base et la PR sont mesurées dans le même job. |
| Builds (avec GodotSteam) | machines de GitHub | 4 minutes, rien à gagner. GodotSteam n'est donc pas installé sur la machine GPU. |

Le jeu utilise le moteur de rendu **Compatibilité** (OpenGL 3.3), pas Vulkan : la machine doit
fournir l'OpenGL de la carte NVIDIA. C'est ce que fait VirtualGL : Godot ouvre sa fenêtre dans un
écran virtuel Xvfb comme aujourd'hui, mais dessine sur la carte (`tools/gpu/bin/xvfb-run`).

## 1. Commander l'instance (espace client OVH)

Dans le projet Public Cloud existant (ou un nouveau, séparé du VPS du site) :
**Public Cloud > Instances > Créer une instance**.

1. **Modèle** : onglet **GPU**, **L4-90** (1 × NVIDIA L4 24 Go, 22 vCores, 90 Go de mémoire),
   environ 0,75 à 1 € HT de l'heure selon la grille d'OVH au moment de la commande.
   - Moins cher, pour les films seulement : **RTX5000-28** (Quadro RTX 5000, 4 vCores, ≈ 0,36 €/h).
     Le robot n'y gagne rien (4 cœurs, comme aujourd'hui).
   - À éviter : A100, H100, V100. Cartes de calcul, l'OpenGL y est absent ou limité, et bien plus chères.
2. **Région** : une région où le L4 est proposé (la console ne montre que celles-là), en Europe
   (Gravelines, Strasbourg ou Paris par exemple).
3. **Image** : **Ubuntu 24.04** (la même que les machines de la CI). Pas d'image « NVIDIA » :
   le script installe le pilote complet avec OpenGL.
4. **Clé SSH** : la clé publique du poste d'Antoine (sinon la créer : `ssh-keygen -t ed25519`).
5. **Réseau** : réseau public par défaut. Aucun port à ouvrir : le runner se connecte vers GitHub.
6. **Facturation** : **à l'heure**. Pas au mois : une instance mensuelle est facturée même en réserve.
7. Nom : `arborescence-gpu`. Créer.

Noter deux identifiants (ils ne sont pas secrets, mais vont dans les secrets avec le reste) :
- **identifiant du projet** : en haut de la page du projet Public Cloud (copier l'ID, 32 caractères) ;
- **identifiant de l'instance** : page de l'instance, champ « ID ».

## 2. Installer la machine (≈ 20 minutes)

```
ssh ubuntu@<adresse IP de l'instance>
git clone https://github.com/Dranto/Tree && cd Tree && git checkout develop
sudo tools/gpu/setup.sh        # paquets et pilote NVIDIA, puis demande un redémarrage
sudo reboot
ssh ubuntu@<adresse IP> ; cd Tree
sudo tools/gpu/setup.sh        # VirtualGL, Godot 4.7, veille ; le runner vient à l'étape 3
tools/gpu/verifier.sh          # sans sudo
```

`verifier.sh` doit finir par « OK : la machine GPU rend le jeu sur la carte ». Il montre la carte,
l'OpenGL vu par Godot (« NVIDIA L4 »), filme une même scène sur la carte puis en logiciel, compare
les durées et la ressemblance des images (SSIM ; 1 = identiques). Une petite différence de lissage
est normale ; des images noires ne le sont pas (voir Dépannage).

## 3. Brancher le runner GitHub

1. GitHub, dépôt **Dranto/Tree > Settings > Actions > Runners > New self-hosted runner**, **Linux**,
   **x64**. Dans la commande `./config.sh … --token XXXX` affichée, copier seulement le jeton `XXXX`
   (usage unique, valable une heure).
2. Sur la machine : `sudo RUNNER_TOKEN=XXXX tools/gpu/setup.sh`. Le runner s'inscrit sous le nom
   `ovh-gpu` avec l'étiquette `gpu`, et démarre avec la machine (service systemd).
3. Il apparaît « Idle » dans la page Runners.

**Sécurité (dépôt public)** : dans **Settings > Actions > General > Fork pull request workflows
from outside collaborators**, choisir **Require approval for all external contributors**. Sinon
une PR d'un inconnu pourrait faire tourner du code sur la machine. Le workflow « Rendus GPU » ne se
lance qu'à la main (`workflow_dispatch`), donc seulement par quelqu'un qui a l'accès en écriture.
L'utilisateur `runner` n'a pas sudo. Le passage du dépôt en privé, prévu à la fin, règle la question.

## 4. Clés d'API d'OVH (allumer et éteindre)

Éteindre une instance ne coupe pas la facture : seule la **remise en réserve** (shelve, « Suspendre »
dans la console) l'arrête. Le disque est alors gardé en sauvegarde (quelques centimes par mois pour
une vingtaine de Go) ; le rallumage (unshelve) prend 5 à 15 minutes.

Créer deux clés sur **https://eu.api.ovh.com/createToken/** (connexion avec le compte OVH), validité
**Unlimited**, en remplaçant `<projet>` et `<instance>` par les identifiants notés plus haut :

- **Clé de la CI** (allume et éteint) :
  - `GET /cloud/project/<projet>/instance/<instance>`
  - `POST /cloud/project/<projet>/instance/<instance>/unshelve`
  - `POST /cloud/project/<projet>/instance/<instance>/shelve`
  - `POST /cloud/project/<projet>/instance/<instance>/start`
- **Clé de la machine** (elle se met en réserve seule quand elle ne sert plus) :
  - `GET /cloud/project/<projet>/instance/<instance>`
  - `POST /cloud/project/<projet>/instance/<instance>/shelve`

Chaque création donne trois valeurs : Application Key, Application Secret, Consumer Key.

## 5. Ranger les clés

**Secrets du dépôt** (**Settings > Secrets and variables > Actions > New repository secret**), avec
la clé de la CI :

| Secret | Valeur |
| --- | --- |
| `OVH_APPLICATION_KEY` | Application Key |
| `OVH_APPLICATION_SECRET` | Application Secret |
| `OVH_CONSUMER_KEY` | Consumer Key |
| `OVH_PROJECT_ID` | identifiant du projet |
| `OVH_INSTANCE_ID` | identifiant de l'instance |
| `GPU_RUNNER_PAT` (facultatif, conseillé) | jeton GitHub « fine-grained » : **Settings (du compte) > Developer settings > Fine-grained tokens**, dépôt **Dranto/Tree** seulement, permission **Administration : Read-only**. Il permet de vérifier que le runner est en ligne avant de lui confier le rendu ; sans lui, le workflow attend 90 secondes et fait confiance. |

**Sur la machine**, avec la clé de la machine : `sudo nano /etc/arborescence-gpu.env` (fichier créé
par `setup.sh`, lisible par root seulement), remplir les cinq lignes `OVH_…`. `IDLE_MINUTES=30` :
sans job ni connexion SSH pendant 30 minutes, la machine se met en réserve.

## 6. Premier essai, puis mise en réserve

1. **Actions > Rendus GPU > Run workflow**, branche `develop`, commande `tools/gpu/verifier.sh`,
   machine `gpu`. Le résumé du run donne la carte, la durée et le journal.
2. Puis un vrai rendu : commande `tools/boss-film.sh rendus/boss ronce`, nom `essai-ronce`.
   Le GIF est dans l'artefact `rendus-essai-ronce` et sur la branche `ci-rendus/essai-ronce`.
3. À la fin, le job « eteindre » remet la machine en réserve. Vérifier une fois dans la console que
   l'instance est bien « Shelved » : c'est l'état normal entre deux rendus.

## Utilisation au quotidien

Depuis une session (ou le poste d'Antoine), sur une branche poussée :

```
tools/gpu-run.sh lancer boss "tools/boss-film.sh rendus/boss ronce,spore"
tools/gpu-run.sh lancer robot "VARIANTES='0 1 2 3 4 5' tools/aventure.sh"
tools/gpu-run.sh lancer bande-annonce "tools/steam-trailer.sh --out=rendus/steam"
tools/gpu-run.sh etat boss
tools/gpu-run.sh recuperer boss /mnt/project-files/captures/boss
```

- Les sorties vont dans `rendus/` ; `godot/autotest/` (journaux du robot, bancs) revient aussi.
  Les images numérotées des films (`000.png`…) ne reviennent pas, seulement les GIF, MP4 et captures.
- Un fichier de plus de 95 Mo ne va que dans l'artefact (téléchargeable par Antoine), pas sur la branche.
- Plusieurs rendus lancés à la suite attendent leur tour sur la machine ; le dernier l'éteint.
- Si la machine ne démarre pas (plus de carte libre dans la région, secrets absents), le rendu part
  sur une machine de GitHub en rendu logiciel, comme avant (machine `auto`, par défaut) ; `gpu` fait
  alors échouer le run, `cpu` force la machine de GitHub. Sur une machine de GitHub, un rendu ne
  peut pas dépasser 6 heures.

**Bancs en paires** : ils ne valent que sur une même machine. Sur la machine GPU, la base et la
branche passent toutes les deux par la carte (le remplaçant de `xvfb-run` vaut aussi pour la copie
de base), donc une paire mesurée dans **un même rendu** reste juste :

```
tools/gpu-run.sh lancer banc "git worktree add ../base origin/develop && BASE_DIR=../base RUNS=3 INFO_ONLY=1 tools/bench.sh"
```

Ne jamais comparer un chiffre de la machine GPU à un chiffre en rendu logiciel (CI, session) : le
banc l'écrit en tête (« Rendu : carte graphique »).

## Coûts

À l'heure, par heure entamée de fonctionnement (prix HT indicatifs, à vérifier sur la grille d'OVH) :
L4-90 ≈ 0,75 à 1 €, RTX5000-28 ≈ 0,36 €. Un film de boss ou une bande-annonce tient dans l'heure,
allumage compris ; un robot à six passages, une à deux heures. En réserve : seulement la sauvegarde
du disque. La veille (30 minutes) et le job « eteindre » évitent d'oublier la machine allumée.

## Dépannage

- `verifier.sh` : « l'OpenGL n'est pas celui de la carte » : `nvidia-smi` doit répondre ;
  `ls -l /dev/dri` doit montrer une carte du groupe `render` ; l'utilisateur `runner` doit être dans
  `video` et `render` (`id runner`). Si la détection prend la mauvaise carte : `GPU_CARD=/dev/dri/card1`.
- Images noires sur la carte : essayer `VGL_DISPLAY=egl` (premier périphérique EGL) au lieu du
  chemin de la carte, ou signaler le problème dans un fil : le plan B est un vrai serveur X sur la
  carte (`nvidia-xconfig --use-display-device=None --virtual=3440x1440`), un seul rendu à la fois.
- Le runner n'apparaît pas : `sudo systemctl status 'actions.runner.*'` ; un jeton d'inscription
  expiré se remplace par un nouveau (`sudo RUNNER_TOKEN=… tools/gpu/setup.sh` après avoir supprimé
  le runner dans la page Runners et `~runner/actions-runner/.runner`).
- La machine reste allumée : `journalctl -t arborescence-gpu` (veille), et
  `/etc/arborescence-gpu.env` rempli ? Sinon la remettre en réserve à la main dans la console.
- Mise à jour de Godot : `sudo GODOT_VERSION=4.x-stable tools/gpu/setup.sh`.
