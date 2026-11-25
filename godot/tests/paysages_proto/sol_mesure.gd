## Mesures et captures du prototype du sol en trois couches (refonte du monde, vague 0 P).
## Le sol seul (ground.gd), sans le jeu : construction d'un carré, carrés construits en marchant et
## en courant (Ruée), entrée dans une région, mémoire des carrés. Le banc du jeu (main.gd, en paires)
## reste la mesure qui fait foi ; celle-ci isole le coût du sol.
## Lancer (rendu logiciel, comme le banc) :
##   LIBGL_ALWAYS_SOFTWARE=1 tools/godot.sh --xvfb --audio-driver Dummy --resolution 1920x1080 \
##     -s res://tests/paysages_proto/sol_mesure.gd -- [--paysage-sol] [--sol-tile=512] [--shot=x.png] [--court]
##   --court : captures seulement (pas de mesures).
extends SceneTree

const Ground = preload("res://scripts/ground.gd")
const Regions = preload("res://scripts/regions.gd")
const GroundLayers = preload("res://scripts/world_bake/ground_layers.gd")

var ground
var cam: Camera2D
## Échelle du jeu en 1920x1080 (1600x900 logique).
const VIEW := 1.2


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Temps de n images (ms), chacune mesurée de la fin du rendu à la fin du rendu suivant.
func _timed(n: int, each: Callable) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	await RenderingServer.frame_post_draw
	var last := Time.get_ticks_usec()
	for i in n:
		each.call(i)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		out.append((now - last) / 1000.0)
		last = now
	return out


static func _mean(a: PackedFloat32Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(1.0, a.size())


static func _p99(a: PackedFloat32Array) -> float:
	var b := a.duplicate()
	b.sort()
	return b[clampi(int(b.size() * 0.99), 0, b.size() - 1)] if b.size() > 0 else 0.0


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var shot := ""
	var court := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.get_slice("=", 1)
		elif a == "--court":
			court = true
	ground = Ground.new()
	root.add_child(ground)
	ground.tile_budget = 0
	cam = Camera2D.new()
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	cam.zoom = Vector2(VIEW, VIEW)
	root.add_child(cam)
	cam.make_current()
	var axis := Vector2.from_angle(Regions.angle_of("ronce"))
	var spot := axis * 1150.0
	cam.position = spot
	# Une clairière ravivée à droite de l'écran : terre morte, front de vie et terre ravivée.
	var side := axis.orthogonal()
	ground.paint(spot + side * 330.0, 420.0, 1.6)
	ground.paint(spot - side * 520.0 + axis * 260.0, 160.0, 1.2)
	await _frames(4)
	await RenderingServer.frame_post_draw
	var label := "couches" if GroundLayers.enabled else "develop"
	if shot != "":
		root.get_texture().get_image().save_png(shot)
		print("SOL capture %s : %s" % [label, shot])
	if court:
		quit()
		return
	print("SOL réglage : %s, carré %d px, %d carrés à l'écran" % [label, ground.tile_px, ground._tiles.size()])
	# 1. Construction d'un carré : k carrés refaits par image, contre 0.
	var tiles: Array = ground._tiles.values()
	var base := await _timed(90, func(_i): pass)
	var res := {}
	for k in [1, 4]:
		GroundLayers.reset_stats()
		var tk := await _timed(90, func(i):
			for j in k:
				ground._rerender(tiles[(i * k + j) % tiles.size()]))
		res[k] = tk
		var st := GroundLayers.stats()
		print("SOL refaire %d carré(s) par image : %.2f ms (sans : %.2f ms) → %.2f ms par carré ; calque dessiné %.2f ms par carré, %d sommets par carré" % [k, _mean(tk), _mean(base), (_mean(tk) - _mean(base)) / k, st["usec"] / 1000.0 / maxf(1.0, st["draws"]), st["verts"] / maxi(1, st["draws"])])
	# 2. Marche, course, Ruée : la caméra traverse le Roncier en ligne droite (perpendiculaire à l'axe).
	for v in [220.0, 400.0, 1400.0]:
		cam.position = axis * 1600.0 - side * 900.0
		ground._clear_tiles()
		await _frames(3)
		var b0: int = ground.tiles_built
		var dur := 5.0
		var n := int(dur * 60.0)
		var t0 := Time.get_ticks_usec()
		var tv := await _timed(n, func(_i): cam.position += side * v / 60.0)
		var secs := (Time.get_ticks_usec() - t0) / 1e6
		print("SOL déplacement %.0f px/s (pas fixe 1/60 s) : %.1f carrés construits par seconde de jeu, image %.2f ms, 99e centile %.2f ms, pire %.2f ms (%.1f s réelles)" % [v, (ground.tiles_built - b0) / dur, _mean(tv), _p99(tv), _max(tv), secs])
	# 3. Entrée dans une région : la caméra saute dans une zone jamais vue, tous les carrés d'un coup.
	ground._clear_tiles()
	cam.position = axis * 2400.0
	var b1: int = ground.tiles_built
	var te := await _timed(6, func(_i): pass)
	print("SOL entrée (saut de caméra) : %d carrés construits, première image %.1f ms, suivantes %.1f ms" % [ground.tiles_built - b1, te[0], _mean(te.slice(1))])
	# 4. Mémoire : textures des carrés (RGBA8, sans mipmaps).
	var mem: int = ground._tiles.size() * ground.tile_px * ground.tile_px * 4
	print("SOL mémoire : %d carrés gardés au plus (%d à l'écran + %d de réserve) ≈ %.1f Mo" % [ground._tiles.size(), ground._tiles.size() - ground.TILE_SPARE, ground.TILE_SPARE, mem / 1048576.0])
	quit()


static func _max(a: PackedFloat32Array) -> float:
	var m := 0.0
	for v in a:
		m = maxf(m, v)
	return m
