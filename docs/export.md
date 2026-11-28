# Export et builds

Quatre presets dans `godot/export_presets.cfg` : **Windows**, **Linux**, **Windows démo**, **Linux démo** (x86_64, release, PCK embarqué : un seul fichier). La démo porte la fonctionnalité `demo` (`Game.is_demo()`, ou `-- --demo` en test). Version : `application/config/version` dans `project.godot` (0.13.0) ; à garder alignée avec `file_version` / `product_version` des presets Windows.

## Lancer le build Windows (pour Antoine)

**Sans rien installer** : sur GitHub, ouvrir la PR ou l'exécution du workflow « Builds », section *Artifacts*, télécharger `arborescence-windows` (jeu) ou `arborescence-windows-demo` (démo), dézipper, lancer `Arborescence.exe` (ou `Arborescence-demo.exe`). Windows peut afficher « Windows a protégé votre ordinateur » (le fichier n'est pas signé) : *Informations complémentaires* → *Exécuter quand même*.

**Depuis son propre poste** (Godot 4.7 installé) : Projet → Exporter… → preset *Windows* → *Exporter le projet*. Les modèles d'export 4.7 s'installent depuis Éditeur → Gérer les modèles d'export. Ou, sous Linux/macOS/WSL : `tools/export.sh windows`.

## Depuis la ligne de commande

    tools/export.sh windows | linux | windows-demo | linux-demo | all
    tools/export.sh --icon          # régénère l'icône et l'écran de démarrage
    tools/export-smoke.sh           # lance le build Linux sous xvfb : démarrage + 60 s de robot + sortie propre

Les modèles d'export (≈ 1,2 Go à télécharger, seuls les x86_64 Windows/Linux sont gardés) sont installés une fois dans `~/.local/share/godot/export_templates/4.7.stable`, comme le binaire dans `tools/godot.sh`. Les binaires vont dans `build/<preset>/` (ignoré par git).

## CI

`.github/workflows/build.yml` : à chaque PR vers `develop`, exporte les quatre presets en artefacts. Les deux builds Linux sont ensuite lancés sous xvfb (`tools/export-smoke.sh`) ; le journal est publié (`journal-linux*`).

## Icône et écran de démarrage

Dessinés par le code (`godot/tools/gen_icon.gd`) aux couleurs Herbier : `godot/assets/icon/icon.png`, `icon.ico` (16/32/48/256), `splash.png` (affiché au démarrage, fond papier brun). Le nom du jeu n'est écrit que dans `application/config/name`.

## Sauvegardes (`user://`)

Le dossier utilisateur ne dépend que de `application/config/name` (« Arborescence », choisi le 25/11) : **identique en éditeur et dans le build exporté**.
- Windows : `%APPDATA%\Godot\app_userdata\Arborescence\`
- Linux : `~/.local/share/godot/app_userdata/Arborescence/`
- Contenu : `saves/partie.json`, `settings.cfg`.

Renommage : au premier lancement, l'autoload `UserDirMigration` (`scripts/user_dir_migration.gd`) recopie l'ancien dossier (`…/app_userdata/Sève/`) si le nouveau n'a ni partie ni options ; l'ancien reste intact. À chaque nouveau renommage, ajouter l'ancien nom à `OLD_NAMES`.
- Windows : `%APPDATA%\Godot\app_userdata\Sève\`
- Linux : `~/.local/share/godot/app_userdata/Sève/`
- Contenu : `saves/partie.json`, `settings.cfg`.

Attention : renommer le jeu (choix du nom définitif) change ce dossier ; prévoir alors `application/config/use_custom_user_dir` + `custom_user_dir_name="Seve"` **avant** la sortie pour figer l'emplacement, ou une migration.
