## Test du bord du monde (jalon 10, tâche G) : poids des régions (somme 1, un seul décor à cœur de secteur),
## couleur de fond (transparente au bord, opaque et sombre au loin), tuiles dessinées pour chaque
## côté et région avec un temps de construction borné, même dessin à chaque construction, décor du
## roncier pour une région sans thème, bord de la carte du monde.
## Lancer : tools/godot.sh --headless -s res://tests/world_edge_test.gd
extends SceneTree

const Painter = preload("res://scripts/world_edge_painter.gd")
const WorldEdge = preload("res://scripts/world_edge.gd")
const Regions = preload("res://scripts/regions.gd")
const DrawBatch = preload("res://scripts/draw_batch.gd")

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Painter.load_regions()
	var ids := Regions.ids()
	check(ids.size() == 6, "six régions")
	# Poids : somme 1 partout, 1 au milieu du secteur, mélange à la frontière.
	var sum_ok := true
	for k in 360:
		var a := TAU * k / 360.0
		var s := 0.0
		for id in ids:
			s += Painter.weight(id, a)
		if absf(s - 1.0) > 0.001:
			sum_ok = false
	check(sum_ok, "les poids des régions font 1 dans toutes les directions")
	for id in ids:
		check(Painter.weight(id, Regions.angle_of(id)) == 1.0, "poids 1 au milieu du secteur de " + id)
		var edge := Regions.angle_of(id) + Regions.half_width()
		check(absf(Painter.weight(id, edge) - 0.5) < 0.01, "poids 0,5 à la frontière de " + id)
	# Couleurs de fond.
	var near := Painter.base_color(0.0, 0.0)
	var mid := Painter.base_color(0.0, 450.0)
	var deep := Painter.base_color(0.0, Painter.DEPTH)
	check(near.a == 0.0 and mid.a == 1.0 and deep.a == 1.0, "fond transparent au bord du monde, opaque ensuite")
	check(deep.get_luminance() < 0.1, "fond sombre au loin (%.3f)" % deep.get_luminance())
	# Chaque tuile se dessine, vite, et à l'identique.
	var worst := 0.0
	var total_tris := 0
	var built := 0
	var same := true
	for side in 4:
		for i in Painter.chunk_count():
			var b := DrawBatch.new()
			var t0 := Time.get_ticks_usec()
			Painter.build(b, side, i, Painter.DEPTH, false)
			Painter.build(b, side, i, Painter.DEPTH, true)
			worst = maxf(worst, (Time.get_ticks_usec() - t0) / 1000.0)
			total_tris += b.indices.size() / 3
			if b.points.size() > 0:
				built += 1
			if i == 5:
				var c := DrawBatch.new()
				Painter.build(c, side, i, Painter.DEPTH, false)
				Painter.build(c, side, i, Painter.DEPTH, true)
				same = same and c.points == b.points
	print("  tuile la plus lente : %.0f ms ; %d triangles en tout" % [worst, total_tris])
	check(built >= 4 * 8, "des tuiles dessinées sur les quatre côtés (%d)" % built)
	check(worst < 400.0, "construction d'une tuile sous 400 ms (%.0f)" % worst)
	check(same, "le dessin d'une tuile est le même à chaque construction")
	# Région sans thème : décor du roncier, sans erreur.
	Regions.set_extra_dirs(["res://tests/regions/"])
	Painter.load_regions()
	var b2 := DrawBatch.new()
	Painter.build(b2, 1, 5, Painter.DEPTH, true)
	check(b2.points.size() > 0, "le monde à régions d'essai se dessine aussi")
	Regions.set_extra_dirs([])
	Painter.load_regions()
	# Carte du monde : le lot existe et reste dans le cadre.
	var mb := WorldEdge.map_batch(520.0, true)
	var lim := Regions.WORLD_HALF + 520.0 + 1200.0
	var inside := true
	for p in mb.points:
		if absf(p.x) > lim or absf(p.y) > lim:
			inside = false
	check(mb.points.size() > 100 and inside, "bord de la carte : %d sommets, dans le cadre" % mb.points.size())
	print("Échecs : ", failures)
	quit(1 if failures > 0 else 0)
