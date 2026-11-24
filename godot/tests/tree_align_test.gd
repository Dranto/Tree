## Test : pendant qu'on se déplace dans l'Arbre de vie, le fond, les nœuds (image en cache) et la couche
## de vie (halos, sève) restent calés les uns sur les autres, image par image, à 1 px près.
##
## Des repères de couleur pure (tree_ui.test_marks) sont posés à des points connus de l'arbre, dans
## le fond, dans la couche fixe et dans la couche de vie. À chaque image, on cherche leur centre dans
## la capture et on le compare à to_screen() (l'état exact avec lequel l'image a été dessinée).
##
## La fréquence physique est abaissée (et le test se lance avec --fixed-fps) : plusieurs images par pas
## physique, comme sur une vraie carte graphique à 144 Hz. C'est là que l'interpolation physique de
## Godot décalait l'image en cache et les couches vivantes (défaut vu par Antoine, jalon 10).
##
## Lancer : tools/godot.sh --xvfb --fixed-fps 144 --resolution 1280x720 -s res://tests/tree_align_test.gd
##   -- --out=DOSSIER : enregistre les images fautives ; --ticks=N : fréquence physique (30 par défaut).
## ALIGN_DEBUG=1 : affiche l'écart de chaque repère.
extends SceneTree

const SPACING := 430.0
const LIMIT_PX := 1.0
const COLORS := {
	"backdrop": Color(0, 1, 1),
	"world": Color(1, 0, 1),
	"life": Color(1, 1, 0),
}
const OFFSETS := {
	"backdrop": Vector2(140, 95),
	"world": Vector2(0, 0),
	"life": Vector2(285, 190),
}

var main
var ui
var out := ""
var px_scale := 1.0
var worst := {}
var failures := 0
var frames := 0
var measured := 0
var holes := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _run() -> void:
	var ticks := 30
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
			DirAccess.make_dir_recursive_absolute(out)
		elif arg.begins_with("--ticks="):
			ticks = int(arg.get_slice("=", 1))
	Engine.physics_ticks_per_second = ticks
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(5)
	main.autotest = false
	main.autosave_enabled = false
	main.spawn_paused = true
	var game = root.get_node("Game")
	game.add_xp(2000.0)
	ui = main.tree_ui
	ui.play_intro = true
	var ext: float = ui._extent()
	for layer in COLORS:
		var pts: Array = []
		var n := int(ext / SPACING) + 1
		for i in range(-n, n + 1):
			for j in range(-n, n + 1):
				var p: Vector2 = Vector2(i, j) * SPACING + OFFSETS[layer]
				if layer == "backdrop":
					# Le fond est une image de basse définition : le repère est calé sur ses texels.
					var k: float = ui.BACKDROP_PX / (2.0 * ui._backdrop_radius())
					p = (p * k).round() / k
				if p.length() < ext * 1.1:
					pts.append(p)
		ui.test_marks[layer] = {"points": pts, "color": COLORS[layer], "min_half": 6.0 if layer == "backdrop" else 0.0}
	ui.toggle()
	px_scale = root.get_final_transform().get_scale().x
	print("ALIGN fenêtre %s, %.2f px par unité, %d pas physiques par seconde" % [root.size, px_scale, ticks])

	# 1. Ouverture : l'arbre grandit de 94 à 100 % et s'éclaire.
	for i in 24:
		await _check("ouverture", i)
	while ui._intro < ui.TreeArt.INTRO_DUR or ui._open < 1.0:
		await process_frame
	ui.zoom = 0.7
	ui.cam = Vector2(250, -180)
	await _frames(12)

	# 2. Glisser à la souris, à des vitesses variées (événements réels).
	_press(true, ui.view_center())
	var pos: Vector2 = ui.view_center()
	for i in 90:
		var speed := 4.0 + 26.0 * absf(sin(i * 0.11))
		var rel := Vector2(cos(i * 0.07), sin(i * 0.05)) * speed
		pos += rel
		var ev := InputEventMouseMotion.new()
		ev.position = pos
		ev.relative = rel
		ui._gui_input(ev)
		await _check("glisser", i)
	_press(false, pos)
	for i in 10:
		await _check("arret", i)

	# 3. Molette : zoom avant puis arrière, au curseur, par à-coups.
	for i in 40:
		if i % 2 == 0:
			var ev := InputEventMouseButton.new()
			ev.pressed = true
			ev.position = ui.view_center() + Vector2(180, -60)
			ev.button_index = MOUSE_BUTTON_WHEEL_UP if i < 20 else MOUSE_BUTTON_WHEEL_DOWN
			ui._gui_input(ev)
		await _check("molette", i)

	# 4. Trajets : vue d'ensemble (bouton), puis vers un nœud lointain (recherche).
	ui.glide_fit()
	for i in 90:
		await _check("ensemble", i)
		if ui._glide.is_empty():
			break
	ui.glide_to(game.tree.nodes[game.tree.nodes.size() / 3]["pos"], 1.8)
	for i in 90:
		await _check("trajet", i)
		if ui._glide.is_empty():
			break
	# 5. Sauts de vue instantanés (le cas des captures et des tests).
	ui._interactive = true
	ui.fit_view()
	for i in 6:
		await _check("saut_ensemble", i)
	ui._interactive = true
	ui.zoom = 1.8
	ui.cam = game.tree.nodes[game.tree.nodes.size() / 2]["pos"]
	for i in 6:
		await _check("saut", i)

	var lines := []
	for k in worst:
		lines.append("%s %.2f px" % [k, worst[k]])
	print("ALIGN pire écart : ", ", ".join(lines))
	print("ALIGN %d images, %d mesures, %d au-delà de %.1f px, %d avec un vide" % [frames, measured, failures, LIMIT_PX, holes])
	if holes > 0:
		print("ÉCHEC : l'image de l'arbre ne couvrait pas tout l'écran pendant le mouvement")
		quit(1)
		return
	if measured < 100:
		print("ÉCHEC : trop peu de repères mesurés (%d)" % measured)
		quit(1)
		return
	if failures > 0:
		print("ÉCHEC : le fond, les nœuds et la couche de vie se décalent pendant le mouvement")
		quit(1)
		return
	print("OK : fond, nœuds et couche de vie calés à %.1f px près" % LIMIT_PX)
	quit(0)


func _press(on: bool, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = on
	ev.position = at
	ui._gui_input(ev)


## Attend l'image suivante et mesure, pour chaque couche, l'écart entre les repères vus et attendus.
func _check(phase: String, step: int) -> void:
	await RenderingServer.frame_post_draw
	frames += 1
	var img: Image = root.get_texture().get_image()
	var area: Rect2 = ui._view_area().grow(-30.0)
	var bad := false
	# L'image en cache doit toujours couvrir la zone de l'arbre (sinon une bande vide apparaît).
	if not ui._cache_rect().grow(0.5).encloses(ui._view_area()):
		holes += 1
		print("ALIGN %s %d : vide au bord de l'image" % [phase, step])
	var report := []
	for layer in COLORS:
		var errs: Array = []
		for p in ui.test_marks[layer]["points"]:
			var e: Vector2 = _expected(p)
			if not area.has_point(e):
				continue
			var half: float = _half(layer)
			# Un repère sous un libellé (et son fond sombre) n'est pas mesurable.
			var box := Rect2(e - Vector2.ONE * (half + 3.0), Vector2.ONE * (2.0 * half + 6.0))
			if ui.label_rects.any(func(r: Rect2): return r.intersects(box)):
				continue
			var found = _find(img, e * px_scale, COLORS[layer], half * px_scale + 10.0, half * px_scale)
			if found == null:
				continue
			errs.append((found - e * px_scale).length())
		if errs.is_empty():
			continue
		if OS.get_environment("ALIGN_DEBUG") != "":
			print("  %s %d %s : %s" % [phase, step, layer, errs])
		errs.sort()
		# Médiane : un repère caché par un nœud ou un libellé ne compte pas.
		var med: float = errs[(errs.size() - 1) / 2]
		measured += 1
		var key := "%s/%s" % [phase, layer]
		worst[key] = maxf(worst.get(key, 0.0), med)
		report.append("%s %.2f" % [layer, med])
		if med > _limit(layer):
			bad = true
	if bad:
		failures += 1
		print("ALIGN %s %d : %s" % [phase, step, ", ".join(report)])
		if out != "":
			img.save_png("%s/%s_%03d.png" % [out, phase, step])


## Écart permis : 1 px. Le fond est une image de basse définition (2048 px pour tout l'arbre) : de près,
## un de ses texels couvre plus de 10 px et son lissage, refait quand l'image en cache est agrandie,
## déplace un peu le centre d'un repère. On lui laisse 1/10 de texel en plus au-delà de 4 px par texel.
## De même, pendant un zoom, l'image en cache est montrée agrandie (k fois) en attendant d'être refaite :
## ses pixels font alors k pixels à l'écran, et un bord net s'y place au demi-pixel près.
func _limit(layer: String) -> float:
	if layer == "life":
		return LIMIT_PX
	if layer == "world":
		return LIMIT_PX + 0.5 * maxf(ui.zoom / ui._cache_zoom - 1.0, 0.0)
	var texel: float = ui.zoom * px_scale / (ui.BACKDROP_PX / (2.0 * ui._backdrop_radius()))
	return LIMIT_PX + (0.1 * texel if texel > 4.0 else 0.0)


## Place attendue d'un point de l'arbre à l'écran, avec l'agrandissement de l'ouverture.
func _expected(p: Vector2) -> Vector2:
	return (p - ui.cam) * ui.zoom * ui._open_scale() + ui.view_center() + ui._snap


## Demi-taille d'un repère à l'écran (unités de l'interface).
func _half(layer: String) -> float:
	var s: float = ui._open_scale()
	match layer:
		"world":
			return 3.0 / ui._rec.get("zoom", ui.zoom) * ui.zoom * s
		"life":
			return 3.0
		_:
			return maxf(4.0 / ui._backdrop.scale.x, 6.0) * ui.zoom * s


## Centre des pixels de la couleur cherchée autour de c (pixels réels), ou null si le repère est en
## partie caché (par un nœud, un libellé) : moins des deux tiers de sa surface attendue (demi-côté half).
func _find(img: Image, c: Vector2, col: Color, r: float, half := 0.0):
	var x0 := maxi(0, int(c.x - r))
	var x1 := mini(img.get_width() - 1, int(c.x + r))
	var y0 := maxi(0, int(c.y - r))
	var y1 := mini(img.get_height() - 1, int(c.y + r))
	var sw := 0.0
	var sp := Vector2.ZERO
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := img.get_pixel(x, y)
			# Teinte pure (magenta, cyan ou jaune), même atténuée par la transparence de l'ouverture.
			var hi := minf(p.r if col.r > 0.5 else 1.0, minf(p.g if col.g > 0.5 else 1.0, p.b if col.b > 0.5 else 1.0))
			var lo := maxf(p.r if col.r < 0.5 else 0.0, maxf(p.g if col.g < 0.5 else 0.0, p.b if col.b < 0.5 else 0.0))
			var w := clampf((hi - lo - 0.25) / 0.25, 0.0, 1.0)
			if w > 0.0:
				sw += w
				sp += Vector2(x + 0.5, y + 0.5) * w
	if sw < maxf(3.0, 0.66 * 4.0 * half * half):
		return null
	return sp / sw
