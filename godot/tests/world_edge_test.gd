## Test du bord du monde (refonte du monde, vague 3 K) : champ de distance au bord (coins arrondis, ligne
## qui ondule : pas de coupure droite), régions du bord (celle du secteur au milieu, les langues de la
## frontière prolongées au-delà du carré), fond opaque au-delà du bord et transparent loin dedans, voile
## de profondeur, tirage des éléments (même tirage à chaque fois, rapide, chaque région a son paysage,
## un élément n'appartient qu'à une tuile), état des tuiles qui change à la purification, thème du
## roncier pour une région d'essai, bord de la carte du monde.
## Lancer : tools/godot.sh --headless -s res://tests/world_edge_test.gd
extends SceneTree

const Painter = preload("res://scripts/world_edge_painter.gd")
const WorldEdge = preload("res://scripts/world_edge.gd")
const Regions = preload("res://scripts/regions.gd")
const Bord = preload("res://scripts/world_art/bord.gd")
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
	var ids := Regions.ids()
	var half := Regions.WORLD_HALF
	check(ids.size() == 6, "six régions")
	# Champ du bord : 0 sur le carré (aux arrondis près), coins arrondis, ligne qui ondule.
	check(absf(Painter.edge_dist(Vector2(half, 0))) < 0.01 and absf(Painter.edge_dist(Vector2(0, -half - 100.0)) - 100.0) < 0.01, "distance au bord sur les côtés")
	var corner := Painter.edge_dist(Vector2(half, half))
	check(corner > 30.0 and corner < 120.0, "coin arrondi (%.0f px au-delà de la ligne)" % corner)
	var lo := 1.0e9
	var hi := -1.0e9
	for k in 200:
		var o := Painter.lip_off(Vector2(-half + k * 29.0, -half))
		lo = minf(lo, o)
		hi = maxf(hi, o)
	check(hi - lo > 25.0, "la ligne du bord ondule (%.0f px d'écart)" % (hi - lo))
	var on_line := true
	for side in 4:
		for u in [-2500.0, -900.0, 0.0, 1300.0, 2850.0]:
			var p := Painter.place(side, u, 0.0)
			if absf(Painter.beyond(p)) > 1.0:
				on_line = false
	check(on_line, "place() pose un point sur la ligne du bord (coins compris)")
	# Régions du bord : celle du secteur au milieu de son côté, deux voisines mêlées sur la frontière.
	var own := true
	for id in ids:
		var dir := Vector2.from_angle(Regions.angle_of(id))
		for extra in [0.0, 400.0, 1500.0]:
			var p: Vector2 = dir * (Regions.reach(Regions.angle_of(id)) + extra)
			if Painter.region_of(p) != id or Painter.theme_of(id) != id:
				own = false
	check(own, "au milieu d'un secteur, le bord est à sa région (jusqu'au loin)")
	var mixed := true
	for pr in Painter.Fr.pairs():
		var dir := Vector2.from_angle(float(pr[2]))
		var p := dir * (Regions.reach(float(pr[2])) + 300.0)
		var m := Painter.mix(p)
		if absf(float(m["w"]) - 0.5) > 0.02 or not ([m["a"], m["b"]].has(pr[0]) and [m["a"], m["b"]].has(pr[1])):
			mixed = false
		# Les langues : les deux régions de part et d'autre, dans la bande.
		var seen := {}
		for k in 41:
			var q := p + dir.orthogonal() * lerpf(-260.0, 260.0, k / 40.0)
			seen[Painter.region_of(q)] = true
		if seen.size() != 2:
			mixed = false
	check(mixed, "sur chaque frontière, le bord mêle les deux régions voisines (même bande que le sol)")
	# Fond : transparent loin dans le monde, opaque au-delà du bord ; voile nul près du bord.
	var empty := {}
	var ok_base := true
	var ok_veil := true
	for k in 72:
		var a := TAU * k / 72.0
		var dir := Vector2.from_angle(a)
		var r := Regions.reach(a)
		if Painter.field_color(dir * (r - 400.0), empty, false).a > 0.01:
			ok_base = false
		for extra in [60.0, 300.0, 1800.0]:
			if Painter.field_color(dir * (r + float(extra)), empty, false).a < 0.99:
				ok_base = false
		if Painter.field_color(dir * (r + 40.0), empty, true).a > 0.01 or Painter.field_color(dir * (r + 1900.0), empty, true).a < 0.5:
			ok_veil = false
	check(ok_base, "fond transparent dans le monde, opaque au-delà du bord")
	check(ok_veil, "voile nul au bord, épais au loin")
	var far := Painter.field_color(Vector2(0, -half - 1990.0), empty, false)
	check(far.get_luminance() < 0.12, "le loin se perd dans le noir (%.3f)" % far.get_luminance())
	# Tirage des éléments : même tirage, rapide, chaque région a son paysage, une seule tuile par pied.
	var worst := 0.0
	var by_theme := {}
	var same := true
	var once := true
	var feet := {}
	for side in 4:
		for i in Painter.chunk_count():
			for band in [Painter.NEAR, Painter.FAR]:
				var t0 := Time.get_ticks_usec()
				var it := Painter.items(side, i, band, empty)
				worst = maxf(worst, (Time.get_ticks_usec() - t0) / 1000.0)
				for x in it:
					if x[1] == 0:
						by_theme[x[6]] = int(by_theme.get(x[6], 0)) + 1
						var key := "%s/%d/%d" % [x[2], int(x[3].x * 10.0), int(x[3].y * 10.0)]
						if feet.has(key):
							once = false
						feet[key] = true
				if i == 4 and band == Painter.NEAR:
					var again := Painter.items(side, i, band, empty)
					same = same and again.size() == it.size() and (it.is_empty() or again[it.size() / 2][3] == it[it.size() / 2][3])
	print("  tirage le plus lent d'une bande : %.1f ms" % worst)
	check(worst < 120.0, "tirage d'une bande sous 120 ms (%.0f)" % worst)
	check(same, "le tirage d'une tuile est le même à chaque fois")
	check(once, "chaque élément a son pied dans une seule tuile (aucun doublon aux coutures)")
	var all_themes := true
	for th in ["ronce", "spore", "vent", "seve", "aube", "racine"]:
		if int(by_theme.get(th, 0)) < 40:
			all_themes = false
			print("    trop peu d'éléments pour ", th, " : ", by_theme.get(th, 0))
	check(all_themes, "chaque région a son paysage au bord (%s)" % str(by_theme))
	# Toutes les sortes connues de bord.gd ont une région.
	var kinds_ok := true
	for k in Bord.KINDS:
		if k["region"] != "*" and not ids.has(k["region"]):
			kinds_ok = false
	check(kinds_ok, "chaque sorte d'élément appartient à une région")
	# État d'une tuile : change quand une région présente est purifiée, pas pour une région absente.
	var key0 := Painter.state_key(0, 6, empty)
	var present := Painter.present(0, 6)
	var absent := ""
	for id in ids:
		if not present.has(id):
			absent = id
			break
	check(Painter.state_key(0, 6, {present[0]: true}) != key0, "purifier une région présente change l'état de la tuile")
	check(absent == "" or Painter.state_key(0, 6, {absent: true}) == key0, "purifier une région absente ne le change pas")
	# Fond d'une tuile, et le même ravivé (autres couleurs).
	var b := DrawBatch.new()
	Painter.build_field(b, 0, 6, empty, false)
	var b2 := DrawBatch.new()
	var all := {}
	for id in ids:
		all[id] = true
	Painter.build_field(b2, 0, 6, all, false)
	check(b.points.size() > 100 and b.colors != b2.colors, "le fond d'une tuile change de couleurs une fois la région purifiée")
	# Région d'essai sans paysage à elle : le roncier, sans erreur.
	Regions.set_extra_dirs(["res://tests/regions/"])
	var test_ids := Regions.ids()
	var themed := true
	for id in test_ids:
		if not ["ronce", "spore", "vent", "seve", "aube", "racine"].has(Painter.theme_of(id)):
			themed = false
	var it2 := Painter.items(1, 5, Painter.NEAR, {})
	check(themed and it2.size() > 0, "le monde à régions d'essai a un bord (%d éléments)" % it2.size())
	Regions.set_extra_dirs([])
	# Carte du monde : le lot existe et reste dans le cadre.
	var mb := WorldEdge.map_batch(520.0, {})
	var lim := half + 520.0 + 1200.0
	var inside := true
	for p in mb.points:
		if absf(p.x) > lim or absf(p.y) > lim:
			inside = false
	check(mb.points.size() > 100 and inside, "bord de la carte : %d sommets, dans le cadre" % mb.points.size())
	print("Échecs : ", failures)
	quit(1 if failures > 0 else 0)
