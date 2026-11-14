## Banc de tests visuels : rejoue une partie à l'identique, prend des captures du jeu et de l'arbre
## à des moments fixés, puis les compare aux images de référence.
##
## Ne pas lancer directement : passer par tools/visual-tests.sh, qui fixe la graine, le pas de temps
## (--fixed-fps 60) et la résolution pour que deux exécutions donnent les mêmes pixels.
##
## Arguments (après « -- ») :
##   --scenario=NOM  scénario à jouer (voir SCENARIOS)
##   --update        enregistre les captures comme nouvelles références au lieu de comparer
extends Node

const MainScene = preload("res://scenes/main.tscn")

const REFERENCE_DIR := "res://tests/visual/reference"
const OUT_DIR := "res://tests/visual/out"
## Écart (0-255, sur le canal le plus touché) au-delà duquel un pixel compte comme différent.
## Absorbe les petites variations d'anticrénelage entre deux machines.
const PIXEL_TOLERANCE := 24
## Part maximale de pixels différents tolérée pour qu'une capture soit jugée identique.
const MAX_DIFF_RATIO := 0.0005

## Chaque scénario est une partie lancée dans un processus neuf (l'état global repart de zéro).
const SCENARIOS := ["depart", "combat", "resolution", "galerie"]
const GalleryScript = preload("res://tests/visual/gallery.gd")
const TitleScene = preload("res://scenes/title.tscn")
## Défauts d'interface déjà connus (un par ligne : « résolution|écran|type|libellés »).
## Un défaut absent de cette liste fait échouer le banc ; un défaut listé qui a disparu est signalé.
const KNOWN_PATH := "res://tests/visual/defauts_connus.txt"
## Niveaux de zoom de l'arbre capturés : vue d'ensemble, moyen, proche.
const ZOOMS := {"ensemble": 0.15, "moyen": 0.55, "proche": 1.6}

var main
var update := false
var failures := 0
var known: Array = []
var seen_issues: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scenario := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.get_slice("=", 1)
		elif arg == "--update":
			update = true
	if not scenario in SCENARIOS:
		printerr("VISUEL scénario inconnu « %s » (attendus : %s)" % [scenario, ", ".join(SCENARIOS)])
		get_tree().quit(2)
		return
	if Game.forced_seed < 0:
		printerr("VISUEL il faut une graine fixe (-- --seed=N) : passer par tools/visual-tests.sh")
		get_tree().quit(2)
		return
	UiAudit.enabled = true
	if FileAccess.file_exists(KNOWN_PATH):
		for l in FileAccess.get_file_as_string(KNOWN_PATH).split("\n"):
			if l.strip_edges() != "" and not l.begins_with("#"):
				known.append(l.strip_edges())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REFERENCE_DIR))

	main = MainScene.instantiate()
	# Le robot du mode autotest joue à la place de la souris, sans ses captures ni sa fin de partie.
	# Activé avant l'ajout à la scène : la partie ne lit ni n'écrit aucune sauvegarde.
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	add_child(main)

	match scenario:
		"depart":
			await _scenario_depart()
		"combat":
			await _scenario_combat()
		"resolution":
			await _scenario_resolution()
		"galerie":
			await _scenario_galerie()
	_finish_audit()
	get_tree().quit(1 if failures > 0 else 0)


# --- Scénarios ---

## Début de partie : le jeu, puis l'arbre fermé à l'origine, un survol de nœud et la vue d'ensemble.
func _scenario_depart() -> void:
	await _frames(60)
	await _shot("jeu_depart")
	main.tree_ui.toggle()
	await _frames(10)
	await _shot("arbre_depart")
	_hover(_first_neighbor_of_root())
	await _frames(2)
	await _shot("arbre_survol")
	_hover(-1)
	main.tree_ui.zoom = ZOOMS["ensemble"]
	main.tree_ui.cam = Vector2.ZERO
	await _frames(2)
	await _shot("arbre_ensemble")
	# Zoom proche, centré sur le premier nœud notable.
	main.tree_ui.zoom = ZOOMS["proche"]
	main.tree_ui.cam = Game.tree.nodes[_first_of_type("notable")]["pos"]
	await _frames(2)
	await _shot("arbre_zoom_proche")


## Après 30 s de jeu : le combat (ennemis, sol ravivé, fleurs) puis l'arbre avec des nœuds appris.
func _scenario_combat() -> void:
	await _frames(30 * 60)
	await _shot("jeu_combat")
	main.tree_ui.toggle()
	await _frames(10)
	await _shot("arbre_progression")


## Le jeu, l'arbre et l'écran titre à la résolution de la fenêtre (fixée par tools/visual-tests.sh).
func _scenario_resolution() -> void:
	var tag := _res_tag()
	await _frames(60)
	await _shot("jeu_" + tag, "jeu")
	main.tree_ui.toggle()
	await _frames(10)
	await _shot("arbre_" + tag, "arbre")
	main.tree_ui.toggle()
	main.queue_free()
	get_tree().paused = false
	await _frames(2)
	var title = TitleScene.instantiate()
	add_child(title)
	await _frames(30)
	UiAudit.scan_controls("titre", title)
	await _shot("titre_" + tag, "titre")


## Galerie : ennemis et effets, puis les six états d'un nœud de l'arbre sur une planche.
func _scenario_galerie() -> void:
	main.set_process(false)   # pas de robot : l'état des nœuds est celui qu'on prépare ici
	var layer := CanvasLayer.new()
	layer.layer = 100
	var gallery = GalleryScript.new()
	gallery.view = get_viewport().get_visible_rect().size
	layer.add_child(gallery)
	add_child(layer)
	await _frames(3)
	await _shot("galerie_ennemis_fx")
	layer.queue_free()

	Game.points = 5
	var root_neighbors: Array = Game.tree.nodes[0]["neighbors"].duplicate()
	root_neighbors.sort()
	Game.allocate(root_neighbors[0])
	var cells := [
		["verrouillé", _far_small(), false],
		["disponible", root_neighbors[1], false],
		["appris", root_neighbors[0], false],
		["survolé", _far_small(1), true],
		["clé", _first_of_type("keystone"), false],
		["notable", _first_of_type("notable"), false],
	]
	var ui = main.tree_ui
	ui.toggle()
	ui.zoom = 1.6
	var cw := 520
	var ch := 340
	var sheet := Image.create(cw * 3, ch * 2, false, Image.FORMAT_RGB8)
	for i in cells.size():
		var id: int = cells[i][1]
		ui.cam = Game.tree.nodes[id]["pos"]
		ui.t = 0.4
		_hover(id if cells[i][2] else -1)
		await _frames(2)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var c: Vector2i = (ui.size / 2.0).round()
		var src := Rect2i(c.x - cw / 2, c.y - ch / 2, cw, ch)
		sheet.blit_rect(img, src, Vector2i((i % 3) * cw, (i / 3) * ch))
		print("VISUEL cellule %s -> nœud %d" % [cells[i][0], id])
	await _shot_image("galerie_noeuds", sheet)


# --- Outils ---

func _res_tag() -> String:
	var s := DisplayServer.window_get_size()
	return "%dx%d" % [s.x, s.y]


func _first_of_type(kind: String) -> int:
	for n in Game.tree.nodes:
		if n["type"] == kind:
			return n["id"]
	return 0


## Un petit nœud éloigné de l'origine et sans voisin appris (état « verrouillé »).
func _far_small(skip := 0) -> int:
	for n in Game.tree.nodes:
		if n["type"] == "small" and n["ring"] >= 6:
			if skip == 0:
				return n["id"]
			skip -= 1
	return 0


## Contrôles sans image : aucun texte hors écran, aucun libellé qui en recouvre un autre.
func _audit(screen: String, strict := true) -> void:
	var tag := _res_tag()
	for issue in UiAudit.check(screen, get_viewport().get_visible_rect(), strict):
		var key := "%s|%s" % [tag, issue["key"]]
		if key in seen_issues:
			continue
		seen_issues.append(key)
		var is_known := key in known
		if not is_known:
			failures += 1
		var line := "%s|%s|%s" % ["connu" if is_known else "NOUVEAU", key, issue["msg"]]
		print("VISUEL audit " + line)
		_append(OUT_DIR + "/audit.txt", line)


func _finish_audit() -> void:
	# Défauts connus de cette résolution qui n'apparaissent plus : à retirer de la liste.
	var tag := _res_tag() + "|"
	var screens_checked := _screens_checked
	for k in known:
		if k.begins_with(tag) and k.split("|")[1] in screens_checked and not k in seen_issues:
			var line := "CORRIGÉ|%s|plus constaté : retire-le de defauts_connus.txt" % k
			print("VISUEL audit " + line)
			_append(OUT_DIR + "/audit.txt", line)


var _screens_checked: Array = []

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Place la souris virtuelle de l'arbre sur un nœud (ou nulle part avec -1) pour afficher son infobulle.
func _hover(id: int) -> void:
	var ui = main.tree_ui
	ui.hover = id
	if id >= 0:
		ui.mouse = (Game.tree.nodes[id]["pos"] - ui.cam) * ui.zoom + ui.size / 2.0
	ui.queue_redraw()


func _first_neighbor_of_root() -> int:
	var neighbors: Array = Game.tree.nodes[0]["neighbors"]
	return neighbors.min()


func _shot(shot_name: String, screen := "") -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if screen == "" and shot_name.begins_with("arbre"):
		screen = "arbre"
	if screen != "":
		if screen == "jeu":
			UiAudit.scan_controls("jeu", main)
		if not screen in _screens_checked:
			_screens_checked.append(screen)
		_audit(screen, not shot_name.ends_with("proche"))
	await _shot_image(shot_name, img)


func _shot_image(shot_name: String, img: Image) -> void:
	var ref_path := ProjectSettings.globalize_path("%s/%s.png" % [REFERENCE_DIR, shot_name])
	var out_path := ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, shot_name])
	img.save_png(out_path)
	if update:
		img.save_png(ref_path)
		_report(shot_name, "maj", 0.0)
		return
	if not FileAccess.file_exists(ref_path):
		failures += 1
		_report(shot_name, "absente", 1.0)
		return
	var ref := Image.load_from_file(ref_path)
	ref.convert(Image.FORMAT_RGB8)
	if ref.get_size() != img.get_size():
		failures += 1
		_report(shot_name, "taille", 1.0)
		return
	var ratio := _diff(ref, img, ProjectSettings.globalize_path("%s/%s.diff.png" % [OUT_DIR, shot_name]))
	if ratio > MAX_DIFF_RATIO:
		failures += 1
		_report(shot_name, "diff", ratio)
	else:
		_report(shot_name, "ok", ratio)


## Compte la part de pixels qui diffèrent et écrit une image où ils ressortent en rouge
## sur la capture atténuée. Renvoie la part de pixels différents (0 à 1).
func _diff(ref: Image, img: Image, diff_path: String) -> float:
	var a := ref.get_data()
	var b := img.get_data()
	if a == b:
		return 0.0
	var out := PackedByteArray()
	out.resize(b.size())
	var count := 0
	for i in range(0, b.size(), 3):
		var d := maxi(absi(a[i] - b[i]), maxi(absi(a[i + 1] - b[i + 1]), absi(a[i + 2] - b[i + 2])))
		if d > PIXEL_TOLERANCE:
			count += 1
			out[i] = 255
			out[i + 1] = 0
			out[i + 2] = 60
		else:
			var g := (b[i] + b[i + 1] + b[i + 2]) / 9
			out[i] = g
			out[i + 1] = g
			out[i + 2] = g
	if count > 0:
		Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGB8, out).save_png(diff_path)
	return float(count) / float(b.size() / 3)


## Une ligne par capture, lue par tools/visual-tests.sh pour le bilan et le rapport HTML.
func _report(shot_name: String, status: String, ratio: float) -> void:
	var line := "%s %s %.5f" % [shot_name, status, ratio]
	print("VISUEL " + line)
	_append(OUT_DIR + "/results.txt", line)


func _append(res_path: String, line: String) -> void:
	var path := ProjectSettings.globalize_path(res_path)
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(line)
	f.close()
