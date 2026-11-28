## Préparation du monde (27/11, « gels aux changements de zone ») : un vrai écran de chargement au
## lancement d'une partie (Nouvelle partie, Continuer), pendant lequel tout ce qui se cuisait jusque-là
## à l'entrée d'une zone est cuit d'avance. Ensuite, changer de région ne cuit plus rien.
##
## Ce qui gelait l'image (banc « -- --benchmark --bench-scene=zones », rendu logiciel) :
## - les Flétris de la région, cuits tous dans la même image à l'entrée (250 à 1 100 ms) ;
## - les pièces et le sol d'une arène, dessinés en direct tant qu'ils ne sont pas cuits (70 à 145 ms) ;
## - les tuiles du bord du monde, construites à l'approche (60 à 95 ms chacune) ;
## - la faune et les formes guéries (world_life_vie.gd, 35 à 65 ms) ;
## - les pierres des sanctuaires, les Cœurs et les autels dessinés en direct en attendant leur cuisson ;
## - les pistes de musique et d'ambiance de la région, lues du disque à l'entrée ;
## - les shaders, compilés par le pilote à leur premier dessin (sur une vraie carte graphique).
##
## L'écran couvre le monde (arbre en pause) et montre l'avancée. Les cuissons ont des caches disque
## (Flétris, décor) : le premier lancement après une mise à jour est plus long, les suivants courts.
## Les budgets mémoire des cuissons sont relevés pour que rien de ce qui est préparé ne soit rendu
## puis recuit en jeu (BUDGETS). Ce qui manquerait encore se cuit en jeu comme avant, étalé.
##
## Actif en jeu seulement (pas dans les tests, les robots, les captures ni le banc, sauf celui du siège du Cœur) ; « -- --preparation »
## le force (banc « zones » : avant / après), « -- --sans-preparation » le coupe.
extends CanvasLayer

const Regions = preload("res://scripts/regions.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const LieuxBake = preload("res://scripts/world_bake/lieux_bake.gd")
const DecorBake = preload("res://scripts/world_bake/decor_bake.gd")
const Vie = preload("res://scripts/world_life_vie.gd")
const Sprites = preload("res://scripts/sprite_bake.gd")
const EdgePainter = preload("res://scripts/world_edge_painter.gd")

## Budgets mémoire relevés pendant une partie préparée (octets) : tout le monde y tient (mesures du
## 27/11 à ×3 : Flétris ~190 Mo avec les élites des sortes régionales, ~210 Mo après une partie, décor ~107 Mo, lieux ~62 Mo, faune ~30 Mo).
const BUDGETS := {"sprites": 256 * 1024 * 1024, "decor": 160 * 1024 * 1024, "lieux": 96 * 1024 * 1024}
## Au plus ce temps par étape (une étape bloquée ne retient pas la partie).
const STEP_MAX_MSEC := 30000
## Temps minimal à l'écran : pas de clignement quand tout vient du cache.
const MIN_SHOW_MSEC := 400

signal finished

var main
## Avancée (0 à 1) et nom de l'étape en cours, montrés par l'écran.
var progress := 0.0
var step_name := ""
## Durée de chaque étape (ms), affichée dans la sortie à la fin.
var timings := {}
var done := false
## Force la préparation (tests/preparation_test.gd).
static var force := false
var _screen: Control
var _t := 0.0


## Vrai si la partie doit être préparée (voir l'en-tête).
static func wanted(m) -> bool:
	var args := OS.get_cmdline_user_args()
	if "--sans-preparation" in args or DisplayServer.get_name() == "headless":
		return false
	if force or "--preparation" in args:
		return true
	# Banc du siège du Cœur : préparé comme en jeu (main.bench_prepared).
	if m.benchmark and m.bench_scene == "coeur" and m.get_tree().current_scene == m:
		return true
	return m.get_tree().current_scene == m and not m.autotest and not m.benchmark


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screen = Screen.new()
	_screen.prep = self
	add_child(_screen)


## Pendant la préparation, aucune touche n'atteint le jeu (le menu pause relancerait l'arbre).
func _input(event: InputEvent) -> void:
	if not done:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	_screen.queue_redraw()


## Prépare tout, puis rend la main au jeu (l'arbre est en pause pendant ce temps).
func run() -> void:
	var t_start := Time.get_ticks_msec()
	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	_raise_budgets()
	# Deux images : l'écran s'affiche avant le premier gros travail.
	await tree.process_frame
	await tree.process_frame
	var steps := [
		["Les Flétris", _step_sprites, 0.35],  # i18n
		["Le décor", _step_decor, 0.2],  # i18n
		["Les lieux", _step_lieux, 0.15],  # i18n
		["La faune", _step_vie, 0.08],  # i18n
		["Le bord du monde", _step_edge, 0.12],  # i18n
		["La musique", _step_music, 0.05],  # i18n
		["Les couleurs", _step_shaders, 0.05],  # i18n
	]
	var base := 0.0
	for s in steps:
		step_name = s[0]
		var t0 := Time.get_ticks_msec()
		await s[1].call(base, s[2])
		timings[s[0]] = Time.get_ticks_msec() - t0
		base += s[2]
		progress = base
	progress = 1.0
	while Time.get_ticks_msec() - t_start < MIN_SHOW_MSEC:
		await tree.process_frame
	var parts := PackedStringArray()
	for k in timings:
		parts.append("%s %d ms" % [k, timings[k]])  # i18n: non
	print("PRÉPARATION du monde : %d ms (%s)" % [Time.get_ticks_msec() - t_start, ", ".join(parts)])  # i18n: non
	var vie := 0
	for r in Vie.sheets:
		vie += int(Vie.sheets[r].bytes)
	print("PRÉPARATION mémoire : Flétris %.0f Mo (%d atlas), décor %.0f Mo, lieux %.0f Mo, bord %.1f Mo (fonds), faune %.0f Mo" % [  # i18n: non
		Sprites.total_bytes() / 1048576.0, Sprites.atlases.size(), DecorBake.total_bytes() / 1048576.0, LieuxBake.bytes / 1048576.0,
		main.world_edge.fields_bytes / 1048576.0 if main.world_edge != null else 0.0, vie / 1048576.0])
	tree.paused = was_paused
	done = true
	finished.emit()
	# Le monde apparaît en fondu sous l'écran qui s'efface.
	var tw := create_tween()
	tw.tween_property(_screen, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


static func _raise_budgets() -> void:
	Sprites.budget = maxi(Sprites.budget, BUDGETS["sprites"])
	DecorBake.budget = maxi(DecorBake.budget, BUDGETS["decor"])
	LieuxBake.budget = maxi(LieuxBake.budget, BUDGETS["lieux"])


func _expired(t0: int) -> bool:
	return Time.get_ticks_msec() - t0 > STEP_MAX_MSEC


# --- Étapes ---

## Toutes les sortes de Flétris, une par une (cache disque ou cuisson), et l'atlas d'élite de chaque
## sorte régionale qui dessine ses marques (elle naît presque toujours dans sa région).
func _step_sprites(base: float, share: float) -> void:
	var S = Sprites
	if not S.enabled:
		return
	var todo: Array = []
	for kr in S.all_kinds():
		todo.append(kr)
	for kr in S.all_kinds():
		var reg := str(S._kinds()[kr[0]].get("region", ""))
		var art = S.script_of(kr[0])
		if reg != "" and art != null and bool(S._const(art, "DRAWS_ELITE", false)):
			todo.append([kr[0], kr[1], {"elite": true, "region": reg}])
	var t0 := Time.get_ticks_msec()
	for i in todo.size():
		if _expired(t0):
			break
		await S.bake(self, [todo[i]])
		progress = base + share * (i + 1) / float(todo.size())
	# Les demandes faites pendant la préparation (sortes de la région du départ) sont déjà servies.
	S._wanted.clear()


## Le décor de chaque région (et le commun), cuit ou lu du cache disque.
func _step_decor(base: float, share: float) -> void:
	if not DecorBake.enabled or main.flora == null:
		return
	var regs := {}
	for t in main.flora.trees:
		if is_instance_valid(t):
			regs[DecorBake.region_of(t)] = true
	var list := regs.keys()
	var t0 := Time.get_ticks_msec()
	for i in list.size():
		if _expired(t0):
			break
		while DecorBake._busy and not _expired(t0):
			await get_tree().process_frame
		if not DecorBake.atlases.has(list[i]):
			DecorBake._wanted.erase(list[i])
			await DecorBake.bake(self, main.flora, list[i])
		progress = base + share * (i + 1) / float(list.size())
	DecorBake.install(main.flora)


## Cœurs, sanctuaires, autels et arènes : leurs images cuites (LieuxBake), toutes demandées puis attendues.
func _step_lieux(base: float, share: float) -> void:
	if not LieuxBake.enabled:
		return
	for h in main.all_hearts:
		if is_instance_valid(h) and h.has_method("_keep_baked"):
			h._keep_baked()
	for s in main.sanctuaries:
		if is_instance_valid(s):
			s._keep_baked()
	for a in main.altars:
		if is_instance_valid(a):
			a._keep_baked()
	for id in main.arenas:
		var a = main.arenas[id]
		if is_instance_valid(a) and a.has_method("_sync_pieces") and a.baked:
			a._sync_pieces()
	var total := maxi(1, LieuxBake._pending.size())
	var t0 := Time.get_ticks_msec()
	while not LieuxBake._pending.is_empty() and not _expired(t0):
		progress = base + share * (1.0 - LieuxBake._pending.size() / float(total))
		await get_tree().process_frame


## Faune et formes guéries de chaque région (world_life_vie.gd), gardées toute la partie.
func _step_vie(base: float, share: float) -> void:
	if main.world_fx == null or DisplayServer.get_name() == "headless":
		return
	var regs: Array = Regions.ids().duplicate()
	regs.append("commun")
	Vie.pinned = regs
	var t0 := Time.get_ticks_msec()
	for i in regs.size():
		Vie.bake(self, regs[i])
		while Vie._pending.has(regs[i]) and not _expired(t0):
			await get_tree().process_frame
		progress = base + share * (i + 1) / float(regs.size())


## Le fond et le voile de chaque tuile du bord du monde (une par image : chacune coûte des dizaines de
## ms). Leurs bandes de décor, elles, restent cuites à l'approche, étalées sur plusieurs images (toutes
## cuites d'avance, elles prendraient ~400 Mo).
func _step_edge(base: float, share: float) -> void:
	var we = main.world_edge
	if we == null:
		return
	var total := 8.0 * EdgePainter.chunk_count()
	var made := 0
	var t0 := Time.get_ticks_msec()
	while we.prepare_fields() and not _expired(t0):
		made += 1
		progress = base + share * minf(1.0, made / total)
		await get_tree().process_frame


## Pistes de musique et d'ambiance de chaque région, lues une fois (une par image).
func _step_music(base: float, share: float) -> void:
	if not Music.enabled:
		return
	var regs: Array = Regions.ids()
	for i in regs.size():
		Music._ensure_group(regs[i])
		Music._ensure_bed(regs[i])
		progress = base + share * (i + 1) / float(regs.size())
		await get_tree().process_frame


## Chaque shader du jeu dessiné une fois sous l'écran : le pilote les compile ici, pas au premier
## Flétri, au premier sol ravivé ou à la première arène.
func _step_shaders(_base: float, _share: float) -> void:
	var warm := ShaderWarm.new()
	for f in ResourceLoader.list_directory("res://shaders/"):
		if f.ends_with(".gdshader"):
			var sh = load("res://shaders/" + f)
			if sh is Shader and sh.get_mode() == Shader.MODE_CANVAS_ITEM:
				var m := ShaderMaterial.new()
				m.shader = sh
				warm.mats.append(m)
	add_child(warm)
	move_child(warm, 0)
	warm.build()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	warm.queue_free()


## Un petit carré par shader, sous l'écran de chargement (il est opaque).
class ShaderWarm extends Node2D:
	var mats: Array = []

	func build() -> void:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		var tex := ImageTexture.create_from_image(img)
		for i in mats.size():
			var s := Sprite2D.new()
			s.texture = tex
			s.material = mats[i]
			s.position = Vector2(8 + (i % 20) * 6, 8 + (i / 20) * 6)
			add_child(s)
			# Le même shader en filtrage avec mipmaps (cuissons : décor, lieux).
			var s2 := Sprite2D.new()
			s2.texture = tex
			s2.material = mats[i]
			s2.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			s2.position = s.position + Vector2(0, 40)
			add_child(s2)


## L'écran : papier sombre, nom du jeu, étape en cours et filet d'or qui se remplit.
class Screen extends Control:
	var prep

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var sz := get_viewport_rect().size
		# Opaque : le monde en préparation (et les carrés de compilation des shaders) restent cachés.
		var bg := UiTheme.PANEL_BG.darkened(0.35)
		bg.a = 1.0
		draw_rect(Rect2(Vector2.ZERO, sz), bg)
		var k := sz.y / UiTheme.BASE_VIEW.y
		var title_font := UiTheme.display(500, 2)
		var font := UiTheme.serif()
		var c := Vector2(sz.x * 0.5, sz.y * 0.5)
		draw_string(title_font, Vector2(0, c.y - 40.0 * k), Loc.game_name(), HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(54 * k), UiTheme.PAPER)
		var w := 360.0 * k
		var y := c.y + 10.0 * k
		draw_line(Vector2(c.x - w * 0.5, y), Vector2(c.x + w * 0.5, y), UiTheme.FILET_NORMAL, maxf(1.0, 2.0 * k))
		draw_line(Vector2(c.x - w * 0.5, y), Vector2(c.x - w * 0.5 + w * clampf(prep.progress, 0.0, 1.0), y), UiTheme.GOLD, maxf(2.0, 3.0 * k))
		# Une feuille qui se balance au bout du filet : l'écran vit, même pendant une longue cuisson.
		var tip := Vector2(c.x - w * 0.5 + w * clampf(prep.progress, 0.0, 1.0), y)
		draw_colored_polygon(UiTheme.leaf_points(tip + Vector2(0, -2.0 * k), -PI / 2.0 + sin(prep._t * 3.0) * 0.35, 16.0 * k, 7.0 * k), UiTheme.LEAF)
		var line := tr("Le monde se prépare…")
		if prep.step_name != "":
			line = tr(prep.step_name)
		draw_string(font, Vector2(0, y + 40.0 * k), line, HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(22 * k), UiTheme.SOFT_NORMAL)
