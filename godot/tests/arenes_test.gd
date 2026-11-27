## Test des arènes en décor (refonte du monde, vague 3 A, puis 3b A2) : Roncier, Marais, Vallée, Forêt.
##   - le mur est fait de pièces dans le calque trié en profondeur, cuites par lieux_bake (« arene/ ») ;
##   - la brèche s'ouvre : les pièces du côté du Cœur rentrent sous terre, les autres restent ;
##   - quand le mur se resserre, les pièces suivent le rayon ; les repères restent au fond ;
##   - une pièce qui cache le héros s'estompe ;
##   - phase et coup du boss : le mur tremble, le monde vivant reçoit « boss_phase » et « boss_hit » ;
##   - après la victoire, les pièces se fondent dans leur image ravivée ;
##   - les autres régions gardent leur ancien mur (vague 3b) ; rien du combat ne change.
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 -s res://tests/arenes_test.gd
extends SceneTree

const LieuxBake = preload("res://scripts/world_bake/lieux_bake.gd")
const Regions = preload("res://scripts/regions.gd")

var failures := 0
var main
## Aire moyenne d'une image cuite par région (budget lieux_bake : pas plus que le Roncier).
var areas := {}


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _steps(n: int) -> void:
	for i in n:
		await process_frame


func _put(pos: Vector2) -> void:
	main.player.position = pos
	main.player.invuln = 1.0e6
	main.player.reset_physics_interpolation()
	main.camera.reset_smoothing()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _steps(3)

	for reg in ["ronce", "spore", "seve", "racine"]:
		await _region(reg)

	print("Autres régions : ancien mur")
	for reg in ["vent", "aube"]:
		if main.arenas.has(reg):
			var a = main.arenas[reg]
			check(not a.baked and a.pieces.is_empty(), "%s : pas encore en décor (vague 3b)" % reg)

	LieuxBake.clear()
	main.queue_free()
	await _steps(2)
	print("ÉCHECS : %d" % failures if failures else "Tout est vert.")
	quit(1 if failures else 0)


func _region(reg: String) -> void:
	print("Arène « %s »" % reg)
	var a = main.arenas[reg]
	check(a.baked, "en décor")
	var ring := 0
	var marks := 0
	for d in a._descs:
		if d["ring"]:
			ring += 1
		else:
			marks += 1
	check(ring >= 30 and marks >= 1, "mur de %d pièces et %d repère(s)" % [ring, marks])
	var pc = a.pieces[0]
	check(pc.get_parent() == main.actors_layer, "pièces dans le calque trié en profondeur")
	check(a.max_radius == float(Regions.section(reg, "boss").get("arena", {}).get("radius", a.max_radius)), "rayon inchangé")

	# Approche : le jeu fermé est cuit.
	_put(a.center + (a.heart.center - a.center).normalized() * (a.max_radius + 200.0))
	await _steps(8)
	check(LieuxBake.ready(a.bake_key("fletri")), "jeu « %s » cuit à l'approche" % a.bake_key("fletri"))
	var cells: Dictionary = LieuxBake.sets[a.bake_key("fletri")]["cells"]
	check(cells.size() == a.art.arena_piece_keys(reg).size(), "une image par pièce (%d)" % cells.size())
	var area := 0.0
	for k in cells:
		area += cells[k][1].get_area()
	print("    aire moyenne d'une image : %.0f px²" % (area / cells.size()))
	areas[reg] = area / cells.size()
	if reg != "ronce" and areas.has("ronce"):
		check(areas[reg] <= areas["ronce"] * 1.05, "images pas plus grandes que celles du Roncier (budget lieux_bake)")

	# Brèche : ouverte, les pièces du côté du Cœur rentrent, celles d'en face restent.
	a.state = "ouverte"
	a.gap_open = 1.0
	await _steps(2)
	var gate: float = a.art.gate_angle(a)
	var gap_hidden := true
	var back_up := true
	for p in a.pieces:
		var d: Dictionary = a._descs[p.i]
		if not d["ring"]:
			continue
		var off := absf(wrapf(float(d["ang"]) - gate, -PI, PI))
		if off < 0.25 and p.visible:
			gap_hidden = false
		if off > 1.0 and (not p.visible or p.scale.y < 0.5):
			back_up = false
	check(gap_hidden, "brèche ouverte : les pièces du côté du Cœur sont sous terre")
	check(back_up, "le reste du mur debout")
	a.gap_open = 0.5
	await _steps(1)
	var mid := false
	for p in a.pieces:
		if p.visible and p.scale.y < 0.9 and a._descs[p.i]["ring"]:
			mid = true
	check(mid, "brèche à demi ouverte : des pièces à demi rentrées (animation)")
	a.gap_open = 0.0

	# Combat : resserrement, transparence, phases et coups.
	a.frozen = true
	a.state = "combat"
	a.radius = a.min_radius
	await _steps(1)
	var r_ok := true
	var mark_ok := true
	for p in a.pieces:
		var d: Dictionary = a._descs[p.i]
		var dist: float = p.position.distance_to(a.center)
		if d["ring"] and dist > a.min_radius + 60.0:
			r_ok = false
		if not d["ring"] and dist < a.max_radius:
			mark_ok = false
	check(r_ok, "mur resserré : les pièces suivent le rayon")
	check(mark_ok, "repères au fond, hors du mur")
	a.radius = a.max_radius
	# Le héros juste derrière une pièce du sud : elle s'estompe.
	var south = null
	for p in a.pieces:
		if a._descs[p.i]["ring"] and sin(float(a._descs[p.i]["ang"])) > 0.95:
			south = p
	await _steps(1)
	_put(south.position + Vector2(0, -25))
	await _steps(2)
	check(south.modulate.a < 0.6, "pièce devant le héros estompée (%.2f)" % south.modulate.a)

	# Événements : le boss est simulé (phase, vie) ; le monde vivant les reçoit.
	var life = main.world_fx.life
	var fake := FakeBoss.new()
	fake.position = a.center
	a.boss = fake
	a.frozen = false
	a._seen_phase = 0
	a._seen_hp = -1.0
	a._watch_boss(0.1)
	var before: int = life.events.size()
	fake.phase = 2
	a._watch_boss(0.1)
	var got := false
	for e in life.events:
		if e["kind"] == "boss_phase":
			got = true
	check(got or life.still, "changement de phase : world_life « boss_phase »")
	check(a.quake > 0.9, "le mur tremble à la phase")
	fake.hp = 50.0
	a._watch_boss(0.3)
	check(a.shiver > 0.9, "coup reçu : le mur frissonne")
	a.boss = null
	fake.free()
	a.frozen = true

	# Victoire : fondu vers le ravivé.
	a.state = "vaincue"
	a.gap_open = 1.0
	a.revive_k = 0.0
	a.frozen = false
	await _steps(4)
	check(a.revive_k > 0.0 and a.revive_k < 1.0, "fondu vers le ravivé en cours (%.2f)" % a.revive_k)
	await _steps(140)
	check(LieuxBake.ready(a.bake_key("ravive")), "jeu ravivé cuit")
	check(a.revive_k >= 1.0, "fondu terminé")
	a.state = "fermee"
	a.gap_open = 0.0
	a.revive_k = 1.0
	_put(Vector2.ZERO)
	await _steps(2)


class FakeBoss extends Node2D:
	var phase := 1
	var hp := 100.0
