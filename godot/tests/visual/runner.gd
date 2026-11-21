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
const SCENARIOS := ["depart", "combat", "resolution", "galerie", "competences", "boss", "roncier", "quetes", "charte", "interactions", "heros", "monde", "attaque", "regions", "marais", "plateaux", "carte5", "falaises", "vallee", "finale", "foret"]
const GalleryScript = preload("res://tests/visual/gallery.gd")
const CharteScript = preload("res://tests/visual/charte.gd")
const HerosScript = preload("res://tests/visual/galerie_heros.gd")
const MondeScript = preload("res://tests/visual/monde.gd")
const AttaqueScript = preload("res://tests/visual/galerie_attaque.gd")
const RegionsScript = preload("res://tests/visual/galerie_regions.gd")
const HeartsScript = preload("res://tests/visual/galerie_coeurs.gd")
const PlateauxScript = preload("res://tests/visual/plateaux.gd")
const FalaisesScript = preload("res://tests/visual/falaises.gd")
const ValleeScript = preload("res://tests/visual/vallee.gd")
const ForetScript = preload("res://tests/visual/foret.gd")
const FinaleScript = preload("res://tests/visual/finale.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Orb = preload("res://scripts/orb.gd")
const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")
const RegionUi = preload("res://scripts/region_ui.gd")
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

	# Commandes par défaut (clavier, visée automatique, clics et A E R F), quelles que soient les
	# options du poste : l'aide de départ et la barre des captures en dépendent.
	Settings.set_move_mode(Settings.MOVE_MODE_DEFAULT)
	Settings.aim_mode = "auto"
	Settings.bindings = Settings.BINDING_DEFAULTS.duplicate()
	Settings.moba_main_2_key = Settings.MOBA_MAIN_2_DEFAULT
	Settings.apply_bindings()
	if scenario == "carte5":
		# Monde à cinq régions et plus : les régions factices des tests complètent celles des données.
		Regions.set_extra_dirs(["res://tests/regions/"])
	main = MainScene.instantiate()
	# Le robot du mode autotest joue à la place de la souris, sans ses captures ni sa fin de partie.
	# Activé avant l'ajout à la scène : la partie ne lit ni n'écrit aucune sauvegarde.
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	add_child(main)
	main.tree_ui.play_intro = false   # pas d'onde d'ouverture : les captures de l'arbre sont prises tout de suite

	match scenario:
		"depart":
			await _scenario_depart()
		"combat":
			await _scenario_combat()
		"resolution":
			await _scenario_resolution()
		"galerie":
			await _scenario_galerie()
		"competences":
			await _scenario_competences()
		"boss":
			await _scenario_boss()
		"roncier":
			await _scenario_roncier()
		"quetes":
			await _scenario_quetes()
		"charte":
			await _scenario_charte()
		"interactions":
			await _scenario_interactions()
		"heros":
			await _scenario_heros()
		"monde":
			await _scenario_monde()
		"regions":
			await _scenario_regions()
		"attaque":
			await _scenario_attaque()
		"marais":
			await _scenario_marais()
		"plateaux":
			await PlateauxScript.new().run(self)
		"carte5":
			await _scenario_carte5()
		"falaises":
			await FalaisesScript.new().run(self)
		"vallee":
			await ValleeScript.new().run(self)
		"foret":
			await ForetScript.new().run(self)
		"finale":
			await FinaleScript.new().run(self)
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


## Planche de la charte graphique (tests/visual/charte.gd) : palette, éléments, icônes, annonces,
## silhouettes par rôle. Jouée en 2560x1440 pour que les petits détails restent lisibles.
func _scenario_charte() -> void:
	main.set_process(false)
	var layer := CanvasLayer.new()
	layer.layer = 100
	var sheet = CharteScript.new()
	sheet.view = get_viewport().get_visible_rect().size
	layer.add_child(sheet)
	add_child(layer)
	await _frames(3)
	await _shot("charte")
	sheet.page = "details"
	sheet.t = 1.2   # milieu de la boucle : attaques annoncées, graine en vol
	sheet.queue_redraw()
	await _frames(3)
	await _shot("charte_details")
	# -- --charte-anim : enregistre une boucle complète (20 images/s) dans out/charte_anim/,
	# pour en faire une animation (tools/charte-anim.sh). Pas de comparaison.
	if "--charte-anim" in OS.get_cmdline_user_args():
		var dir := ProjectSettings.globalize_path(OUT_DIR + "/charte_anim")
		DirAccess.make_dir_recursive_absolute(dir)
		var n := int(sheet.PERIODE * 20.0)
		for i in n:
			sheet.t = i * sheet.PERIODE / n
			sheet.queue_redraw()
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png("%s/%03d.png" % [dir, i])


## Héros et attaques : poses du Porte-Graine, puis la graine et chaque compétence en trois temps.
## -- --heros-anim : enregistre aussi la page animée (20 images/s) dans out/heros_anim/.
func _scenario_heros() -> void:
	main.set_process(false)
	for pg in ["heros", "competences_1", "competences_2", "competences_3", "competences_4", "competences_5", "competences_6"]:
		var layer := _pixel_layer()
		var sheet = HerosScript.new()
		sheet.view = Vector2(DisplayServer.window_get_size())
		sheet.page = pg.get_slice("_", 0)
		if pg.contains("_"):
			sheet.part = int(pg.get_slice("_", 1))
		sheet.t = 0.6
		layer.add_child(sheet)
		add_child(layer)
		await _frames(3)
		await _shot("galerie_" + pg)
		layer.queue_free()
		await _frames(1)
	if "--heros-anim" in OS.get_cmdline_user_args():
		var layer := _pixel_layer()
		var sheet = HerosScript.new()
		sheet.view = Vector2(DisplayServer.window_get_size())
		sheet.page = "anim"
		layer.add_child(sheet)
		add_child(layer)
		var dir := ProjectSettings.globalize_path(OUT_DIR + "/heros_anim")
		DirAccess.make_dir_recursive_absolute(dir)
		var n := int(sheet.PERIODE * 20.0)
		for i in n:
			sheet.t = i * sheet.PERIODE / n
			sheet.queue_redraw()
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png("%s/%03d.png" % [dir, i])


## Calque dessiné en pixels de la fenêtre (la galerie du héros se met en page en vrais pixels).
func _pixel_layer() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var k: float = get_viewport().get_visible_rect().size.x / float(DisplayServer.window_get_size().x)
	layer.scale = Vector2(k, k)
	return layer


## Monde de Ronce : chaque lieu dans chaque état et le décor (planche tests/visual/monde.gd).
func _scenario_monde() -> void:
	main.set_process(false)
	var layer := CanvasLayer.new()
	layer.layer = 100
	var sheet = MondeScript.new()
	sheet.view = get_viewport().get_visible_rect().size
	layer.add_child(sheet)
	add_child(layer)
	await _frames(3)
	await _shot("galerie_monde")


## Régions : la planche de chaque région (sol, ennemis, boss), puis son décor dans le vrai jeu, mort d'un côté
## et vivant de l'autre. Générique : une région ajoutée par ses fichiers a ses captures (à refaire avec --update).
func _scenario_regions() -> void:
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	main.hud.hint_time = 0.0
	main.set_process(false)
	var layer := CanvasLayer.new()
	layer.layer = 100
	var sheet = RegionsScript.new()
	sheet.view = get_viewport().get_visible_rect().size
	layer.add_child(sheet)
	add_child(layer)
	await _frames(3)
	await _shot("galerie_regions")
	layer.queue_free()
	await _frames(1)
	main.set_process(true)
	for id in Regions.ids():
		var spot: Vector2 = Regions.place(id, {"dist": 1500.0, "side": -0.45})
		await _place_player(spot)
		main.ground.paint(spot + Vector2(420, 0), 420.0, 1.0)
		main.hud.banner_time = 0.0
		await _frames(40)
		await _shot("decor_" + id, "jeu")
	# Les Cœurs et les arènes de chaque région (dessins de la région, scripts/region_art/), en dernier
	# pour ne pas décaler les captures du décor.
	main.set_process(false)
	var hearts_layer := CanvasLayer.new()
	hearts_layer.layer = 100
	var hearts_sheet = HeartsScript.new()
	hearts_sheet.view = get_viewport().get_visible_rect().size
	hearts_layer.add_child(hearts_sheet)
	add_child(hearts_layer)
	await _frames(3)
	await _shot("galerie_coeurs")
	hearts_layer.queue_free()
	await _frames(1)


## Carte et journal d'un monde à cinq régions et plus (celles des données et les régions factices de
## tests/regions/) : la légende, les secteurs et les sections du journal doivent tenir à l'écran.
## Les régions sans objectifs dans les données reçoivent ici des objectifs factices de même forme.
func _scenario_carte5() -> void:
	var q = main.quest_ui
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	main.hud.hint_time = 0.0
	var objs: Array = Content._load("objectives")["objectives"]
	for id in Regions.ids():
		if not Objectives.for_region(id).is_empty():
			continue
		for e in [["sanctuaire", "Raviver un sanctuaire", true], ["coeur", "Purifier le Cœur", true], ["boss", "Vaincre le boss", true], ["autels", "Réveiller tous les autels", false]]:
			objs.append({"id": "%s_%s" % [id, e[0]], "region": id, "main": e[2], "title": "%s (%s)" % [e[1], RegionUi.short_name(id)], "text": "Objectif factice du banc visuel.", "condition": {"type": "flag", "flag": "%s_%s_fait" % [id, e[0]]}, "target": {"type": "none"}})
	Game.flags["sanctuaire_graine"] = true
	Game.flags["sanctuaire_lisiere"] = true
	Game.flags["autel_ronce_1"] = true
	Game.flags["ronce_coeur_purifie"] = true
	Game.flags["ronce_boss_vaincu"] = true
	Game.flags["spore_coeur_purifie"] = true
	# La brèche sous la graine est ouverte : la légende, l'anneau de la carte et la section « sous la graine ».
	Game.flags["finale_ouverte"] = true
	for id in Regions.ids():
		for spot in Regions.def(id).get("sanctuaries", []).slice(0, 2):
			Game.flags["sanctuaire_" + str(spot.get("id", ""))] = true
		for spot in Regions.def(id).get("altars", []).slice(0, 1):
			Game.flags["autel_" + str(spot.get("id", ""))] = true
	main.player.position = Regions.place("seve", {"dist": 900.0, "side": 0.0})
	await _frames(10)
	Objectives.check()
	Objectives.main = main
	var tag := _res_tag()
	q.toggle("journal")
	await _frames(3)
	UiAudit.begin("journal")
	UiAudit.scan_controls("journal", q.journal)
	await _shot("journal5_" + tag, "journal")
	q.toggle("carte")
	await _frames(3)
	await _shot("carte5_" + tag, "carte")
	q.close()
	await _frames(2)


## Attaque de base : chaque forme et chaque modificateur (planche tests/visual/galerie_attaque.gd).
func _scenario_attaque() -> void:
	main.set_process(false)
	var layer := CanvasLayer.new()
	layer.layer = 100
	var sheet = AttaqueScript.new()
	sheet.view = get_viewport().get_visible_rect().size
	layer.add_child(sheet)
	add_child(layer)
	await _frames(3)
	await _shot("galerie_attaque")


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
	await _frames(1)
	layer = CanvasLayer.new()
	layer.layer = 100
	gallery = GalleryScript.new()
	gallery.view = get_viewport().get_visible_rect().size
	gallery.page = "roncier"
	layer.add_child(gallery)
	add_child(layer)
	await _frames(3)
	await _shot("galerie_roncier")
	layer.queue_free()
	await _frames(1)
	layer = CanvasLayer.new()
	layer.layer = 100
	gallery = GalleryScript.new()
	gallery.view = get_viewport().get_visible_rect().size
	gallery.page = "varies"
	layer.add_child(gallery)
	add_child(layer)
	await _frames(3)
	await _shot("galerie_varies")
	layer.queue_free()
	await _frames(1)
	layer = CanvasLayer.new()
	layer.layer = 100
	gallery = GalleryScript.new()
	gallery.view = get_viewport().get_visible_rect().size
	gallery.page = "silhouettes"
	layer.add_child(gallery)
	add_child(layer)
	await _frames(3)
	await _shot("galerie_silhouettes")
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
		var c: Vector2i = ui.view_center().round()
		var src := Rect2i(c.x - cw / 2, c.y - ch / 2, cw, ch)
		sheet.blit_rect(img, src, Vector2i((i % 3) * cw, (i / 3) * ch))
		print("VISUEL cellule %s -> nœud %d" % [cells[i][0], id])
	await _shot_image("galerie_noeuds", sheet)
	await _galerie_types(ui, cw, ch)
	await _galerie_formes(ui)


## Planche des formes de nœuds : chaque type (dont le nœud « attack » qui change l'attaque de base)
## dans ses trois états, tel que l'arbre le dessine de près.
func _galerie_formes(ui) -> void:
	var kinds := ["notable", "keystone", "skill", "mutation", "mastery", "graft", "withered", "attack"]
	var ronce := 0
	for bi in Game.tree.BRANCHES.size():
		if Game.tree.BRANCHES[bi]["id"] == "ronce":
			ronce = bi
	var board := Control.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(board)
	board.draw.connect(func():
		board.draw_rect(Rect2(Vector2.ZERO, ui.size), ui.BG)
		var font: Font = ui.font
		var states := ["locked", "available", "owned"]
		var names := ["verrouillé", "disponible", "appris"]
		for si in states.size():
			board.draw_string(font, Vector2(40, 210 + si * 200), names[si], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.85, 0.8))
		for ki in kinds.size():
			var kind: String = kinds[ki]
			var x := 230.0 + ki * 170.0
			board.draw_string(font, Vector2(x - 80, 110), ui.KIND_LABEL[kind], HORIZONTAL_ALIGNMENT_CENTER, 160, 13, Color(0.8, 0.85, 0.8))
			var real := _first_of_type(kind)
			var n: Dictionary
			if Game.tree.nodes[real]["type"] == kind and kind != "withered":
				n = Game.tree.nodes[real]
			else:
				n = {"id": -2 - ki, "type": kind, "branch": ronce, "effects": [{"attack_form": "fouet"}] if kind == "attack" else [],
					"choices": [], "requires_flag": "", "uid": "galerie:" + kind, "name": kind}
			for si in states.size():
				var p := Vector2(x, 200 + si * 200)
				ui.draw_node(board, n, p, ui.RADIUS[kind] * 2.2, states[si], 1.0, ui.LOD_CLOSE))
	await _frames(2)
	await _shot("galerie_formes", "")
	board.queue_free()
	await _frames(1)


## Les types de nœuds des grappes écrites à la main, chacun dans ses deux états, puis la grappe
## avec une infobulle et la fenêtre de choix d'une mutation.
func _galerie_types(ui, cw: int, ch: int) -> void:
	var skill := _first_of_type("skill")
	var mutation := _first_of_type("mutation")
	var mastery := _first_of_type("mastery")
	var withered := _first_of_type("withered")
	var graft := _first_of_type("graft")
	var sheet := Image.create(cw * 4, ch * 2, false, Image.FORMAT_RGB8)
	var cells := [["compétence", skill], ["mutation verrouillée", mutation], ["flétri", withered], ["greffe vide", graft]]
	for i in cells.size():
		await _cell(ui, sheet, cells[i][0], cells[i][1], i, cw, ch)
	# Tout apprendre : la maîtrise reçoit un choix, la mutation attend le sien, le drapeau libère le nœud flétri.
	# Juste les points qu'il faut à chaque fois, pour que le robot n'ait rien à dépenser entre deux images.
	var planner = ui.panels.planner
	Game.flags[Game.tree.nodes[withered]["requires_flag"]] = true
	for id in [skill, mastery, mutation, withered, graft]:
		if not Game.allocated.has(id):
			var path: Array = planner.path_to(id)
			Game.points = path.size()
			planner.learn_path(path)
	Game.points = 0
	Game.set_choice(mastery, 1)
	Game.set_graft(graft, "greffe_soeurs")
	await _frames(2)
	ui._choice_queue.clear()
	ui.close_choice(false)
	cells = [["maîtrise choisie", mastery], ["mutation à choisir", mutation], ["flétri libéré", withered], ["greffe posée", graft]]
	for i in cells.size():
		await _cell(ui, sheet, cells[i][0], cells[i][1], 4 + i, cw, ch)
	await _shot_image("galerie_types", sheet)

	ui.zoom = 1.2
	ui.cam = Game.tree.nodes[mutation]["pos"]
	ui.t = 0.4
	_hover(mastery)
	await _frames(2)
	await _shot("arbre_grappe")
	_hover(-1)
	ui.open_choice(mutation)
	await _frames(3)
	await _shot("arbre_choix")
	ui.close_choice(false)


func _cell(ui, sheet: Image, label: String, id: int, index: int, cw: int, ch: int) -> void:
	ui.cam = Game.tree.nodes[id]["pos"]
	ui.t = 0.4
	_hover(-1)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var c: Vector2i = ui.view_center().round()
	sheet.blit_rect(img, Rect2i(c.x - cw / 2, c.y - ch / 2, cw, ch), Vector2i((index % 4) * cw, (index / 4) * ch))
	print("VISUEL cellule %s -> nœud %d" % [label, id])


## Compétences de Ronce en action : racines qui immobilisent un groupe, coup de fouet
## (arc et saignement) sur un autre, et volée d'épines en vol vers un troisième. La barre montre 4 compétences et 2 emplacements verrouillés.
func _scenario_competences() -> void:
	var p = main.player
	Game.test_skills = {}
	for id in Content.skills():
		Game.test_skills[id] = true
	Game.flags["barre"] = "fouet,racines,volee,saignee"
	Game.recompute()
	p.sync_bar()
	main.hud.hint_time = 0.0
	main.autotest = false   # ni robot ni expérience gagnée : rien ne bouge en dehors de ce qu'on lance
	p.set_physics_process(false)   # le joueur ne bouge pas : les compétences sont lancées ici
	p.invuln = 0.4   # figé (pas de pas physique) : aucun coup ne passe, sans le voile d'invulnérabilité
	main.spawn_timer = 1e9
	await _frames(2)
	var s: Dictionary = Game.stats
	# Groupe en bas, visé par la volée ; groupe en haut à gauche, enraciné.
	for i in 4:
		_spawn_at(Vector2(-90 + i * 60, 250), 0)
	for i in 3:
		_spawn_at(Vector2(-300 + i * 40, -220 + (i % 2) * 40), 1)
	await _frames(2)   # la grille des ennemis est reconstruite au pas suivant
	p.aim_point = Vector2(-260, -200)
	p.cast("racines", s)
	await _frames(90)
	# Groupe à droite, frappé par le fouet.
	for i in 3:
		_spawn_at(Vector2(110, -50 + i * 50), 0 if i != 1 else 2)
	await _frames(2)
	p.aim = Vector2.DOWN
	p.cast("volee", s)
	await _frames(2)
	p.aim = Vector2.RIGHT
	p.cast("fouet", s)
	await _frames(6)
	await _shot("competences", "jeu")


func _spawn_at(pos: Vector2, kind: int) -> void:
	var e = Enemy.new()
	e.main = main
	e.position = pos
	e.setup(kind, 3.0)
	e.t = 0.0
	main.enemies_layer.add_child(e)
	main.enemies.append(e)


## Région de Ronce : le Cœur de flétrissure (flétri, assiégé, purifié), l'arène ouverte, puis la
## Mère-Ronce dans chaque phase et chaque attaque annoncée. La logique est figée ; chaque image
## est une pose précise du vrai Cœur (heart.gd), de la vraie arène et du vrai boss (boss.gd).
func _scenario_boss() -> void:
	await _frames(2)
	var heart = main.heart
	var arena = main.arena
	var p = main.player
	main.set_physics_process(false)   # ni robot, ni naissances
	p.set_physics_process(false)
	heart.frozen = true
	arena.frozen = true

	# Le Cœur flétri, deux Flétris qu'il vient de faire naître.
	var near: Vector2 = heart.center + Vector2(-190, 150)
	_frozen_enemy(heart.center + Vector2(90, 40), 0)
	_frozen_enemy(heart.center + Vector2(-60, 95), 0)
	await _boss_shot("coeur_fletri", near)

	# Le siège : zone tenue depuis 17 s, une vague arrive.
	heart.state = "siege"
	heart.progress = 17.0
	heart.update_bar(true)
	for i in 7:
		_frozen_enemy(heart.center + Vector2.from_angle(-0.5 + i * 0.22) * (heart.zone + 60.0 + 37.0 * (i % 3)), 2 if i == 3 else i % 2)
	await _boss_shot("coeur_siege", near)

	# Purifié : la vague de vie est passée.
	_clear_enemies()
	Game.flags[heart.flag] = true
	heart._set_purified(false)
	main.ground.paint(heart.center, heart.life_radius, 1.0)
	main.flora.spawn_patch(heart.center, heart.life_radius * 0.8, 90, Color("e0675e"))
	await _boss_shot("coeur_purifie", near)

	# L'arène ouverte : la brèche du côté du Cœur, la Mère-Ronce endormie.
	var gate: Vector2 = (heart.center - arena.center).normalized()
	arena.state = "ouverte"
	arena.gap_open = 1.0
	await _boss_shot("arene_ouverte", arena.center + gate * (arena.max_radius + 60.0))

	# Le combat. Le joueur se tient au sud-est du boss.
	var spot: Vector2 = arena.center + Vector2(120, 150)
	p.position = spot
	arena._start_fight()
	arena.gap_open = 0.0
	var boss = arena.boss
	boss.frozen = true
	boss.intro = 0.0
	boss.t = 0.6
	main.hud.banner_time = 0.0
	main.fx.rings = []

	# Phase 1 : volée d'épines annoncée (le corps recule, l'éventail est verrouillé).
	boss._begin("volee")
	boss.timer = 0.2
	await _boss_shot("boss_volee", spot)
	# Phase 1 : la volée en vol, et des racines annoncées sous le joueur (une vient de jaillir).
	boss._strike()
	boss._fire_volley(false)
	for th in boss.thorns:
		th["pos"] += th["vel"] * 0.35
	boss._end_attack()
	boss.roots = [
		{"pos": spot + Vector2(10, 6), "fuse": 0.25, "burst": -1.0},
		{"pos": spot + Vector2(-150, 30), "fuse": 0.7, "burst": -1.0},
		{"pos": spot + Vector2(120, -130), "fuse": 0.0, "burst": 0.16},
	]
	await _boss_shot("boss_racines", spot)

	# Phase 2 : deux fouets annoncés, qui se refermeront sur le joueur.
	boss.thorns = []
	boss.roots = []
	boss.phase = 2
	boss.hp = boss.max_hp * 0.55
	boss._begin("fouets")
	boss.timer = 0.4
	await _boss_shot("boss_fouets", spot)
	# Phase 2 : les fouets en plein balayage.
	boss._strike()
	boss.timer = boss.stage_time * 0.45
	boss._strike_step(0.0)
	await _boss_shot("boss_fouets_frappe", spot)
	# Phase 2 : invocation annoncée (bourgeons au sol), deux petits déjà éclos.
	boss._end_attack()
	boss._begin("invocation")
	boss.timer = 0.3
	_frozen_enemy(arena.center + Vector2(-150, 120), 1)
	_frozen_enemy(arena.center + Vector2(40, 230), 1)
	await _boss_shot("boss_invocation", spot)

	# Phase 3 : le resserrement de l'arène est annoncé, les fouets couvrent presque tout.
	boss.buds = []
	boss._end_attack()
	boss.phase = 3
	boss.hp = boss.max_hp * 0.22
	boss.cycle = 0
	arena.shrinking = true
	arena.shrink_warn = 0.8
	boss._begin("fouets")
	boss.timer = 0.5
	await _boss_shot("boss_phase3", spot)

	# Victoire : l'arène refleurit.
	_clear_enemies([boss])
	boss.take_damage(boss.max_hp, false)
	# Sa mort, à mi-chemin : les pétales tombent en cendre, la vie reprend au cœur de la rose.
	boss.dying = boss.DEATH_TIME * 0.55
	main.fx.rings = []
	main.hud.banner_time = 0.0
	boss.redraw()
	await _boss_shot("boss_mort", spot)
	boss.queue_free()
	arena.life_wave = -1.0
	main.ground.paint(arena.center, arena.max_radius * 1.25, 1.0)
	main.flora.spawn_patch(arena.center, arena.max_radius, 70, Color("e0675e"))
	main.fx.rings = []
	main.hud.banner_time = 0.0
	await _boss_shot("boss_vaincu", spot)


## Place le joueur et la caméra, redessine les poses figées, puis capture l'écran de jeu.
func _boss_shot(shot_name: String, player_pos: Vector2) -> void:
	var p = main.player
	p.position = player_pos
	p.aim = (main.arena.center - player_pos).normalized() if shot_name.begins_with("boss") else (main.heart.center - player_pos).normalized()
	p.reset_physics_interpolation()
	for c in p.get_children():
		if c is Camera2D:
			c.reset_smoothing()
	main.heart.t = 1.0
	main.arena.t = 1.0
	if is_instance_valid(main.arena.boss) and main.arena.state == "combat":
		main.arena.update_bar()
		main.arena.boss.redraw()
	main.heart.queue_redraw()
	main.heart.body.queue_redraw()
	main.arena.queue_redraw()
	await _frames(6)
	await _shot(shot_name, "jeu")


## Un Flétri immobile, à un instant précis de son animation.
func _frozen_enemy(pos: Vector2, kind: int) -> void:
	var e = main.spawn_enemy_at(pos, kind)
	e.t = 0.5
	e.set_process(false)
	e.set_physics_process(false)


func _clear_enemies(keep: Array = []) -> void:
	for e in main.enemies:
		if is_instance_valid(e) and not e in keep:
			e.queue_free()
	main.enemies = keep.duplicate()


## Roncier : la région de Ronce morte, puis une vague de vie (trois images), la région ravivée
## une fois les feuilles poussées, et enfin purifiée (drapeau de la tâche D).
## Sans robot ni Flétris : le joueur est posé dans la région, à l'arrêt.
func _scenario_roncier() -> void:
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	var spot: Vector2 = main.region_center("ronce") * 0.62
	main.player.position = spot
	main.player.reset_physics_interpolation()
	for c in main.player.get_children():
		if c is Camera2D:
			c.reset_smoothing()
	await _frames(30)
	await _shot("roncier_mort")
	main.revive(spot + Vector2(-140, 60), 520.0, Game.tree.branch_color(0))
	for step in [[24, "roncier_vague_1"], [30, "roncier_vague_2"], [51, "roncier_vague_3"]]:
		await _frames(step[0])
		await _shot(step[1])
	await _frames(90)
	await _shot("roncier_ravive")
	Game.flags["ronce_coeur_purifie"] = true
	main.player.position = main.region_center("ronce") + Vector2(0, 260)
	main.player.reset_physics_interpolation()
	await _frames(40)
	await _shot("roncier_purifie")
	await _death_shots()


## Marais de Spore : la région morte, une vague de vie, ravivée puis purifiée ; ses Flétris et
## leurs annonces ; son Cœur (flétri, assiégé, purifié), l'arène ouverte, puis l'Amanite-Mère dans
## chaque phase et chaque attaque annoncée, sa mort et sa victoire. Poses figées, comme « boss ».
func _scenario_marais() -> void:
	main.autotest = false
	main.spawn_timer = 1.0e9
	var p = main.player
	p.set_physics_process(false)
	var spot: Vector2 = main.region_center("spore") * 0.62
	await _place_player(spot)
	await _frames(30)
	await _shot("marais_mort")
	main.revive(spot + Vector2(-140, 60), 520.0, Game.tree.branch_color(1))
	await _frames(30)
	await _shot("marais_vague")
	await _frames(120)
	await _shot("marais_ravive")

	# Les Flétris du marais, figés : Traîne-vase et sa flaque, Scissipore qui gonfle, Sporules,
	# Lichen cuirassé qui se dresse (élite), sur la terre morte au fond de la région.
	var far: Vector2 = main.region_center("spore") + Vector2(-260, -420)
	await _place_player(far)
	main.set_physics_process(false)
	var puddles = load("res://scripts/marsh_puddles.gd").of(main)
	var tv = main.spawn_enemy_at(far + Vector2(-230, -60), Enemy.kind_index("traine_vase"))
	puddles.add(tv, far + Vector2(-150, -40), 46.0, 6.0, 8.0)
	puddles.add(tv, far + Vector2(-90, -10), 46.0, 6.0, 8.0)
	for pd in puddles.puddles:
		pd["age"] = 1.0
	var sc = main.spawn_enemy_at(far + Vector2(150, -90), Enemy.kind_index("scissipore"))
	sc.state = "windup"
	sc.state_t = float(sc.data["windup"]) * 0.35
	for i in 3:
		main.spawn_enemy_at(far + Vector2(60 + 34 * i, 90 + 14 * (i % 2)), Enemy.kind_index("sporule"))
	var li = main.spawn_enemy_at(far + Vector2(-120, 150), Enemy.kind_index("lichen"))
	main.make_elite(li)
	li.state = "windup"
	li.state_t = float(li.data["windup"]) * 0.3
	for e in main.enemies:
		e.t = 0.5
		e.set_physics_process(false)
		e.face = (p.position - e.position).normalized()
	await _frames(8)
	for e in main.enemies:
		e.set_process(false)
	puddles.set_process(false)
	puddles.set_physics_process(false)
	await _frames(2)
	await _shot("marais_ennemis", "jeu")
	_clear_enemies()
	puddles.puddles = []
	puddles.queue_redraw()

	# Le Cœur de moisissure et l'arène de l'Amanite-Mère (ceux de la région de Spore).
	main.heart = main.hearts["spore"]
	main.arena = main.arenas["spore"]
	var heart = main.heart
	var arena = main.arena
	heart.frozen = true
	arena.frozen = true
	var near: Vector2 = heart.center + Vector2(-190, 150)
	_frozen_enemy(heart.center + Vector2(90, 40), Enemy.kind_index("traine_vase"))
	_frozen_enemy(heart.center + Vector2(-60, 95), Enemy.kind_index("scissipore"))
	await _boss_shot("spore_coeur_fletri", near)
	heart.state = "siege"
	heart.progress = 17.0
	heart.update_bar(true)
	var wave := ["fletri", "scissipore", "fletri", "lichen", "scissipore", "fletri", "sporule"]
	for i in wave.size():
		_frozen_enemy(heart.center + Vector2.from_angle(-0.5 + i * 0.22) * (heart.zone + 60.0 + 37.0 * (i % 3)), Enemy.kind_index(wave[i]))
	await _boss_shot("spore_coeur_siege", near)
	_clear_enemies()
	Game.flags[heart.flag] = true
	heart._set_purified(false)
	main.ground.paint(heart.center, heart.life_radius, 1.0)
	main.flora.spawn_patch(heart.center, heart.life_radius * 0.8, 90, Art.ec("poison", "clair"))
	await _boss_shot("spore_coeur_purifie", near)
	var gate: Vector2 = (heart.center - arena.center).normalized()
	arena.state = "ouverte"
	arena.gap_open = 1.0
	await _boss_shot("spore_arene_ouverte", arena.center + gate * (arena.max_radius + 60.0))

	# Le combat : le joueur au sud-ouest de l'Amanite-Mère.
	var at: Vector2 = arena.center + Vector2(-130, 150)
	p.position = at
	arena._start_fight()
	arena.gap_open = 0.0
	var boss = arena.boss
	boss.frozen = true
	boss.intro = 0.0
	boss.t = 0.6
	main.hud.banner_time = 0.0
	main.fx.rings = []
	seed(7)
	# Phase 1 : nuages annoncés sous le joueur, puis crevés.
	boss._begin("nuages")
	boss.timer = 0.3
	for c in boss.clouds:
		c["fuse"] = 0.3
	await _boss_shot("spore_boss_nuages", at)
	for c in boss.clouds:
		c["fuse"] = 0.0
		c["life"] = 2.0
	boss._end_attack()
	# Phase 1 : salve annoncée (cône), avec les nuages qui restent.
	boss._begin("salve")
	boss.timer = 0.25
	await _boss_shot("spore_boss_salve", at)
	# La salve en vol.
	boss._strike()
	boss._strike_step(0.0)
	for s in boss.spores:
		s["pos"] += s["vel"] * 0.35
	boss.clouds = []
	boss._end_attack()
	# L'onde annoncée.
	boss._begin("onde")
	boss.timer = 0.2
	await _boss_shot("spore_boss_onde", at)
	# Phase 2 : lamelles ouvertes, spirale annoncée puis en cours.
	boss.spores = []
	boss._end_attack()
	boss.phase = 2
	boss.hp = boss.max_hp * 0.55
	boss._begin("spirale")
	boss.timer = 0.3
	await _boss_shot("spore_boss_spirale", at)
	boss._strike()
	for i in 12:
		boss._strike_step(1.0 / 12.0)
	for s in boss.spores:
		s["pos"] += s["vel"] * 0.2
	await _boss_shot("spore_boss_spirale_frappe", at)
	boss.spores = []
	boss._end_attack()
	boss._begin("invocation")
	boss.timer = 0.3
	_frozen_enemy(arena.center + Vector2(-150, 120), Enemy.kind_index("scissipore"))
	_frozen_enemy(arena.center + Vector2(40, 230), Enemy.kind_index("sporule"))
	await _boss_shot("spore_boss_invocation", at)
	# Phase 3 : le chapeau fendu, le mycélium annoncé, l'arène qui se resserre.
	boss.buds = []
	boss._end_attack()
	boss.phase = 3
	boss.hp = boss.max_hp * 0.22
	arena.shrinking = true
	arena.shrink_warn = 0.8
	boss._begin("mycelium")
	boss.timer = 0.35
	await _boss_shot("spore_boss_mycelium", at)
	# Mort, à mi-chemin, puis victoire.
	_clear_enemies([boss])
	boss.take_damage(boss.max_hp, false)
	boss.dying = boss.death_time * 0.5
	main.fx.rings = []
	main.hud.banner_time = 0.0
	boss.redraw()
	await _boss_shot("spore_boss_mort", at)
	boss.queue_free()
	arena.life_wave = -1.0
	main.ground.paint(arena.center, arena.max_radius * 1.25, 1.0)
	main.flora.spawn_patch(arena.center, arena.max_radius, 70, Art.ec("poison", "clair"))
	main.fx.rings = []
	main.hud.banner_time = 0.0
	await _boss_shot("spore_boss_vaincu", at)

	# La région purifiée, loin du Cœur.
	main.arena = main.arenas["ronce"]
	main.heart = main.hearts["ronce"]
	await _place_player(main.region_center("spore") * 0.62 + Vector2(0, 260))
	main.set_physics_process(true)
	await _frames(40)
	await _shot("marais_purifie")


## Sanctuaire de la Lisière à moitié ravivé puis ravivé, et l'écran de mort : renaissance au
## sanctuaire, sève perdue au loin (flèche au bord de l'écran).
func _death_shots() -> void:
	var s = main.sanctuary("lisiere")
	s.frozen = true
	s.progress = s.LIGHT_TIME * 0.55
	main.player.position = s.position + Vector2(-130, 50)
	main.player.aim = Vector2.RIGHT
	main.player.reset_physics_interpolation()
	main.camera.reset_smoothing()
	main.hud.banner_time = 0.0
	await _frames(20)
	await _shot("sanctuaire_reprise", "jeu")
	s.light()
	await _frames(100)
	await _shot("sanctuaire_ravive", "jeu")
	main.hud.banner_time = 0.0
	Game.xp = 37.0
	main.player.position = s.position + Vector2(-1100, -300)
	main.player_died()
	main.hud.banner_time = 0.0
	await _frames(30)
	await _shot("mort_ecran", "jeu")
	# La sève perdue, là où le joueur est tombé.
	main.player.position = main.lost_sap.position + Vector2(-160, 40)
	main.player.reset_physics_interpolation()
	main.camera.reset_smoothing()
	await _frames(int(main.hud.death_screen.time_left * 60.0) + 10)
	await _shot("seve_perdue", "jeu")


## Interactions et retours (tâche G du jalon 5) : un ramassage d'essence, une greffe, la sève perdue,
## un coup reçu, un critique, l'invite d'un sanctuaire, le repère du clic droit, l'ouverture de l'arbre, la mort et la
## renaissance. Le jeu est figé (ni robot ni Flétris) ; chaque image est prise à un instant précis.
func _scenario_interactions() -> void:
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	var s = main.sanctuary("lisiere")
	s.frozen = true
	var spot: Vector2 = s.position + Vector2(-380, 120)
	await _place_player(spot)
	main.hud.banner_time = 0.0
	# Essences de vie : l'aimant les attire, puis elles éclatent au contact.
	for i in 5:
		var o = Orb.new()
		o.main = main
		o.value = 3.0
		o.position = spot + Vector2.from_angle(TAU * i / 5.0 + 0.4) * (55.0 + 8.0 * i)
		main.orbs_layer.add_child(o)
	await _frames(3)
	await _shot("interaction_orbe_1")
	await _frames(9)
	await _shot("interaction_orbe_2")
	await _frames(20)
	# Greffe : saut d'apparition, attirance, ramassage.
	var gid: String = str(Content.grafts().keys()[0])
	main.drop_graft(spot + Vector2(110, -30), gid)
	await _frames(20)
	await _shot("interaction_greffe_1")
	await _frames(34)
	await _shot("interaction_greffe_2")
	await _frames(14)
	await _shot("interaction_greffe_3")
	main.hud.banner_time = 0.0
	# Coup reçu : vignette rouge, secousse, puis retour au calme.
	main.player.invuln = 0.0
	main.player.hp = Game.stats["max_hp"]
	main.player.take_hit(Game.stats["max_hp"] * 0.2, null)
	await _frames(4)
	await _shot("interaction_degats_1")
	await _frames(40)
	await _shot("interaction_degats_2")
	# Critique sur un Flétri : chiffre, étincelles, onde.
	_clear_enemies()
	var old_crit = Game.stats["crit"]
	Game.stats["crit"] = 1.0
	var e = main.spawn_enemy_at(spot + Vector2(120, -10), 0)
	e.set_process(false)
	e.set_physics_process(false)
	main.player_hit_enemy(e, 40.0, false, "ronce")
	await _frames(4)
	await _shot("interaction_impact")
	Game.stats["crit"] = old_crit
	_clear_enemies()
	await _frames(40)
	# Sanctuaire : l'invite à l'approche, puis l'anneau qui se remplit.
	await _place_player(s.position + Vector2(-300, 90))
	main.hud.banner_time = 0.0
	await _frames(20)
	await _shot("interaction_sanctuaire_approche")
	await _place_player(s.position + Vector2(-20, 20))
	s.progress = s.LIGHT_TIME * 0.6
	await _frames(12)
	await _shot("interaction_sanctuaire_anneau")
	await _place_player(spot)
	# Déplacement au clic droit (mode « moba ») : le repère se resserre sur le point, puis reste posé.
	Settings.set_move_mode("moba")
	main.player.set_destination(spot + Vector2(190, -70), true)
	await _frames(4)
	await _shot("interaction_destination_clic")
	await _frames(30)
	await _shot("interaction_destination")
	main.player.clear_destination()
	Settings.set_move_mode(Settings.MOVE_MODE_DEFAULT)
	await _frames(15)
	# Transitions : ouverture de l'arbre (avec son onde de sève), puis mort et renaissance.
	main.tree_ui.play_intro = true
	main.tree_ui.toggle()
	await _frames(3)
	await _shot("interaction_arbre_ouverture")
	await _frames(30)
	main.tree_ui.toggle()
	await _frames(3)
	await _shot("interaction_arbre_fermeture")
	await _frames(30)
	Game.xp = 20.0
	main.player_died()
	main.hud.banner_time = 0.0
	await _frames(5)
	await _shot("interaction_renaissance")


func _place_player(pos: Vector2) -> void:
	main.player.position = pos
	main.player.reset_physics_interpolation()
	main.camera.reset_smoothing()
	await _frames(2)


## Objectifs : le journal et la carte en cours de tranche, la flèche vers l'objectif, puis la fin.
## Le jeu est figé (ni robot ni Flétris) et la partie est mise en scène par appels directs.
## Journal, carte et fin sont capturés à chaque résolution ; la flèche et le monde qui reverdit
## seulement en 1920x1080 (le suivi et la flèche font déjà partie des captures « jeu_ » de « resolution »).
func _scenario_quetes() -> void:
	var tag := _res_tag()
	var q = main.quest_ui
	main.autotest = false
	main.spawn_timer = 1.0e9
	main.player.set_physics_process(false)
	main.hud.hint_time = 0.0
	var fake := load("res://tests/objectives_fake.gd")
	var ronce: Vector2 = main.region_center("ronce")
	for e in [["sanctuaire", "ronce_1", ronce * 0.45], ["sanctuaire", "ronce_2", ronce * 0.8 + Vector2(260, -180)],
			["autel", "ronce_a", ronce * 0.6 + Vector2(-320, 240)], ["autel", "ronce_b", ronce * 0.9 + Vector2(-380, -300)],
			["autel", "ronce_c", ronce * 0.3 + Vector2(420, 380)]]:
		var n = fake.new()
		n.id = e[1]
		n.position = e[2]
		n.add_to_group(e[0])
		main.add_child(n)
	# Une partie déjà bien entamée : terre ravivée jusqu'au premier sanctuaire, un autel trouvé.
	Game.points = 4
	var neighbors: Array = Game.tree.nodes[0]["neighbors"].duplicate()
	neighbors.sort()
	Game.allocate(neighbors[0])
	main.ground.paint(ronce * 0.45, 330.0, 1.0)
	main.ground.paint(ronce * 0.6 + Vector2(-320, 240), 200.0, 1.0)
	Game.flags["sanctuaire_graine"] = true
	Game.flags["sanctuaire_lisiere"] = true
	Game.flags["autel_ronce_1"] = true
	Game.flags[Objectives.ELITES] = 2
	Game.level = 14
	Game.kills = 312
	Game.flags[Objectives.STAT_DEATHS] = 3
	main.elapsed = 4380.0
	main.player.position = ronce * 0.45 + Vector2(40, 60)
	main.player.reset_physics_interpolation()
	for c in main.player.get_children():
		if c is Camera2D:
			c.reset_smoothing()
	await _frames(30)
	Objectives.check()
	Objectives.main = main

	q.toggle("journal")
	await _frames(3)
	UiAudit.begin("journal")
	UiAudit.scan_controls("journal", q.journal)
	await _shot("journal_" + tag, "journal")
	q.toggle("carte")
	await _frames(3)
	await _shot("carte_" + tag, "carte")
	q.close()
	await _frames(2)

	if tag == "1920x1080":
		# Le Cœur est l'objectif : il est loin, la flèche borde l'écran.
		Objectives.complete("noeud_cle", true)
		await _frames(30)
		await _shot("jeu_objectif", "jeu")

	Game.flags["ronce_coeur_purifie"] = true
	Game.flags["ronce_boss_vaincu"] = true
	Objectives.check()
	q.start_ending()
	if tag == "1920x1080":
		q.ending.set_time(6.0)
		await _frames(2)
		await _shot("fin_arbre", "fin")
	q.ending.set_time(10.0)
	await _frames(2)
	await _shot("fin_" + tag, "fin")


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
		ui.mouse = ui.to_screen(Game.tree.nodes[id]["pos"])
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
			UiAudit.begin("jeu")
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
