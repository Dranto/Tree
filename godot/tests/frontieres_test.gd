## Test des frontières entre régions dans le monde (refonte du monde, vague 3 B ;
## scripts/world_art/frontieres.gd, data/world_borders.json) : chaque point de la bande appartient à
## une seule région, les îlots ne sortent pas de la bande, la part de la voisine passe de 0 à 1 ;
## chaque paire a son élément de passage (deux ou trois), posé dans la bande, loin du bord du monde, hors
## des clairières et des obstacles ; le décor des deux régions se mêle dans la bande.
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 -s res://tests/frontieres_test.gd
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
var Frontieres
var Compose

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
	Frontieres = load("res://scripts/world_art/frontieres.gd")
	Compose = load("res://scripts/world_bake/decor_compose.gd")
	print("Géométrie")
	var pairs: Array = Frontieres.pairs()
	check(pairs.size() == Regions.ids().size(), "une frontière par paire de régions voisines (%d)" % pairs.size())
	var one := true
	var outside := true
	var mixed := 0
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for pr in pairs:
		var dir := Vector2.from_angle(pr[2])
		var across := dir.orthogonal()
		var seen := {}
		for i in 400:
			var d := r.randf_range(Regions.INNER + 200.0, 2600.0)
			var off := r.randf_range(-Frontieres.HALF * 1.3, Frontieres.HALF * 1.3)
			var p := dir * d + across * off
			if absf(p.x) > Regions.WORLD_HALF or absf(p.y) > Regions.WORLD_HALF:
				continue
			var n := 0
			for id in Regions.ids():
				if Frontieres.inside(p, id) > 0.0:
					n += 1
			if n != 1:
				one = false
			var reg: String = Frontieres.region_at(p)
			# Hors de la bande, la région des îlots est celle du secteur.
			if absf(off) > Frontieres.HALF + 1.0 and reg != Regions.region_at(p):
				outside = false
			if absf(off) < Frontieres.HALF * 0.5:
				seen[reg] = true
		if seen.has(pr[0]) and seen.has(pr[1]):
			mixed += 1
	check(one, "chaque point appartient à une seule région")
	check(outside, "les îlots restent dans la bande")
	check(mixed == pairs.size(), "les deux sols se mêlent au milieu de chaque bande (%d/%d)" % [mixed, pairs.size()])
	var p0: Vector2 = Vector2.from_angle(pairs[0][2]) * 1500.0 + Vector2.from_angle(pairs[0][2]).orthogonal() * 0.5
	var m: Dictionary = Frontieres.mix(p0)
	check(absf(m["w"] - 0.5) < 0.02, "fondu doux : moitié sur la demi-droite")
	var deep: Dictionary = Frontieres.mix(Regions.center(pairs[0][0]))
	check(deep["w"] < 0.001, "fondu doux : rien au cœur de la région")

	print("Éléments de passage")
	var main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	for i in 2:
		await process_frame
	var by_pair := {}
	for e in Compose.passages:
		by_pair[e["pair"]] = by_pair.get(e["pair"], 0) + 1
	for pr in pairs:
		var key: String = pr[0] + "-" + pr[1]
		check(by_pair.get(key, 0) >= 2, "%s : %d éléments de passage" % [key, by_pair.get(key, 0)])
	var ok_edge := true
	var ok_band := true
	var ok_clear := true
	var ok_obst := true
	for e in Compose.passages:
		var p: Vector2 = e["pos"]
		if absf(p.x) > Regions.WORLD_HALF - Compose.PASSAGE_EDGE or absf(p.y) > Regions.WORLD_HALF - Compose.PASSAGE_EDGE:
			ok_edge = false
		var mx: Dictionary = Frontieres.mix(p)
		if mx.is_empty() or absf(mx["s"]) > Frontieres.HALF:
			ok_band = false
			print("    hors bande : %s %s %s" % [e["pair"], p, mx])
		for reg in str(e["pair"]).split("-"):
			if Compose.clear_dist(p, Compose.clearings(reg)) < 0.0:
				ok_clear = false
		for b in main.flora.bushes:
			if p.distance_to(b.position) < float(b.radius):
				ok_obst = false
	check(ok_edge, "à %d px au moins du bord du monde" % Compose.PASSAGE_EDGE)
	check(ok_band, "dans la bande de leur frontière")
	check(ok_clear, "hors des clairières et des lieux des deux régions")
	check(ok_obst, "sur aucun obstacle")
	# Décor mêlé : dans la bande, des objets composés des deux régions.
	var mix_ok := 0
	for pr in pairs:
		var regs := {}
		for t in main.flora.trees:
			if not is_instance_valid(t) or t.bake_region == "":
				continue
			var mx: Dictionary = Frontieres.mix(t.position)
			if mx.is_empty() or absf(mx["s"]) > Frontieres.HALF:
				continue
			if (mx["a"] == pr[0] and mx["b"] == pr[1]) or (mx["a"] == pr[1] and mx["b"] == pr[0]):
				regs[t.bake_region] = regs.get(t.bake_region, 0) + 1
		if regs.get(pr[0], 0) > 0 and regs.get(pr[1], 0) > 0:
			mix_ok += 1
		else:
			print("    %s-%s : %s" % [pr[0], pr[1], regs])
	check(mix_ok == pairs.size(), "le décor des deux régions se mêle dans chaque bande (%d/%d)" % [mix_ok, pairs.size()])
	# Pas de sortie pendant une cuisson (décor, créatures) : Godot s'arrêterait sur un abort.
	var DecorBake = load("res://scripts/world_bake/decor_bake.gd")
	for i in 600:
		if not DecorBake._busy and i > 60:
			break
		await process_frame
	print("frontieres_test : %s" % ("OK" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
