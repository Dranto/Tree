## Test du décor composé et cuit (refonte du monde, vague 1 D : world_bake/decor_compose.gd et
## decor_bake.gd) : les obstacles n'ont pas bougé, les clairières et les lieux restent dégagés, au plus
## 80 éléments par écran, les grands éléments sont assez espacés ; l'atlas d'une région couvre tout son
## décor, mort et vivant, le cache disque le rend à l'identique, une pousse se dessine sans repli
## direct ; le premier plan s'efface quand le héros passe derrière ; decor_near (monde vivant, tâche V).
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 -s res://tests/decor_test.gd
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
const Ground = preload("res://scripts/ground.gd")
# Chargés à l'exécution : ils citent des autoloads, inconnus quand ce script est compilé.
var Flora
var DecorBake
var Compose

var failures := 0
var main


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	Flora = load("res://scripts/flora.gd")
	DecorBake = load("res://scripts/world_bake/decor_bake.gd")
	Compose = load("res://scripts/world_bake/decor_compose.gd")
	DecorBake.clear_disk_cache()
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(2)
	main.autotest = false
	main.spawn_timer = 1.0e9
	var flora = main.flora

	print("Composition")
	# Le semis d'avant, à part : mêmes obstacles, aux mêmes places, de mêmes rayons.
	Compose.enabled = false
	var g0 = Ground.new()
	root.add_child(g0)
	var old = Flora.new()
	old.ground = g0
	var old_layer := Node2D.new()
	old.trees_parent = old_layer
	root.add_child(old_layer)
	root.add_child(old)
	Compose.enabled = true
	var same: bool = old.bushes.size() == flora.bushes.size()
	if same:
		for i in old.bushes.size():
			if old.bushes[i].position != flora.bushes[i].position or old.bushes[i].radius != flora.bushes[i].radius:
				same = false
				break
	check(same, "les obstacles n'ont pas bougé (%d / %d)" % [flora.bushes.size(), old.bushes.size()])
	var p0 := Vector2(1300, -240)
	check(old.push_out(p0, 20.0) == flora.push_out(p0, 20.0), "push_out inchangé")
	old.free()
	old_layer.free()
	g0.free()
	var obstacles := {}
	for b in flora.bushes:
		obstacles[b] = true
	for reg in Regions.ids():
		var rep: Dictionary = Compose.report.get(reg, {})
		check(rep.get("placed", 0) > 120, "%s : décor composé (%s)" % [reg, rep])
		var geo: Dictionary = Compose.clearings(reg)
		var inside := 0
		var big := []
		for t in flora.trees:
			if not is_instance_valid(t) or obstacles.has(t) or t in flora.landmarks or not t.has_meta("foot") or Regions.region_weighted(t.position) != reg:
				continue
			if Compose.clear_dist(t.position, geo) < 0.0:
				inside += 1
			if t.tall > 0.0 and t.shade < 1.0:
				big.append(t.position)
		check(inside == 0, "%s : rien dans les clairières ni sur les passages (%d)" % [reg, inside])
		var close := 0
		for i in big.size():
			for j in range(i + 1, big.size()):
				if big[i].distance_to(big[j]) < Compose.BIG_GAP - 1.0:
					close += 1
		check(big.size() > 6 and close == 0, "%s : %d grands éléments de premier plan, espacés" % [reg, big.size()])
		var worst := 0
		for d in range(700, 2700, 250):
			for side in [-0.7, -0.35, 0.0, 0.35, 0.7]:
				worst = maxi(worst, Compose.count_in_screen(flora, Regions.place(reg, {"dist": float(d), "side": side})))
		check(worst <= Compose.MAX_SCREEN and worst > 15, "%s : au plus %d éléments par écran (%d)" % [reg, Compose.MAX_SCREEN, worst])
	# Lieux dégagés : aucun élément composé sur un sanctuaire.
	var blocked := 0
	for reg in Regions.ids():
		for s in Regions.def(reg).get("sanctuaries", []):
			for t in flora.decor_near(Regions.place(reg, s), 150.0):
				if t.has_meta("foot") and not t in flora.landmarks:
					blocked += 1
	check(blocked == 0, "sanctuaires dégagés (%d)" % blocked)

	print("decor_near")
	var c: Vector2 = Compose.test_center()
	var near: Array = flora.decor_near(c, 600.0)
	var ok := not near.is_empty()
	for t in near:
		ok = ok and t.position.distance_to(c) <= 600.0
	var brute := 0
	for t in flora.trees:
		if is_instance_valid(t) and t.position.distance_to(c) <= 600.0:
			brute += 1
	check(ok and near.size() == brute, "decor_near rend le décor du disque (%d / %d)" % [near.size(), brute])

	print("Cuisson")
	DecorBake.atlases.clear()
	var before: int = DecorBake.jobs_baked
	await DecorBake.bake(main, flora, "ronce")
	var a = DecorBake.atlases.get("ronce")
	check(a != null and DecorBake.jobs_baked > before, "atlas du Roncier cuit (%d images, %.1f Mo)" % [DecorBake.jobs_baked - before, a.bytes / 1048576.0 if a != null else 0.0])
	var missing := 0
	var keys := {}
	for t in flora.trees:
		if is_instance_valid(t) and DecorBake.region_of(t) == "ronce":
			keys[DecorBake.key_of(t)] = true
			if a == null or not a.cells.has(DecorBake.key_of(t) + "|0") or not a.cells.has(DecorBake.key_of(t) + "|1"):
				missing += 1
	check(missing == 0, "chaque élément du Roncier a ses images morte et vivante (%d manquants)" % missing)
	check(a != null and a.bytes < 32 * 1024 * 1024, "atlas sous 32 Mo")
	var cells: Dictionary = a.cells if a != null else {}
	DecorBake.atlases.erase("ronce")
	var hits: int = DecorBake.cache_hits
	await DecorBake.bake(main, flora, "ronce")
	var b = DecorBake.atlases.get("ronce")
	check(DecorBake.cache_hits == hits + 1 and b != null and b.cells.size() == cells.size(), "cache disque relu")
	var same_px := false
	if a != null and b != null:
		same_px = a.tex.get_image().get_data() == b.tex.get_image().get_data()
	check(same_px, "le cache rend les mêmes pixels")
	main.player.position = c
	await _frames(3)
	var fb: int = DecorBake.fallback
	var grow = null
	for t in flora.decor_near(c, 500.0):
		if t.has_meta("foot") and not t.alive:
			grow = t
			break
	check(grow != null, "un élément mort près du banc")
	if grow != null:
		grow.revive(true)
		var d0: int = DecorBake.drawn
		await _frames(4)
		check(DecorBake.drawn > d0 and DecorBake.fallback == fb, "la pousse se dessine depuis l'atlas (fondu, sans dessin direct)")

	print("Premier plan")
	var tall = null
	for t in flora.decor_near(c, 1200.0):
		if t.tall > 0.0 and DecorBake.region_of(t) == "ronce":
			tall = t
			break
	check(tall != null, "un grand élément près du banc")
	if tall != null:
		main.player.position = tall.position + Vector2(0, -tall.tall * 0.45)
		await _frames(30)
		check(tall.fade < 0.6, "le héros derrière un grand élément : il s'efface (%.2f)" % tall.fade)
		main.player.position = tall.position + Vector2(0, 160)
		await _frames(40)
		check(tall.fade > 0.99, "le héros devant : il revient (%.2f)" % tall.fade)

	# Enveloppe de chaque atlas (vague 2) et plafond commun : toutes les régions cuites tiennent dessous.
	var total := 0
	for reg in Regions.ids() + [DecorBake.COMMUN]:
		if not DecorBake.atlases.has(reg):
			await DecorBake.bake(main, flora, reg)
		var at = DecorBake.atlases.get(reg)
		var mb: float = at.bytes / 1048576.0 if at != null else 0.0
		total += at.bytes if at != null else 0
		print("  atlas %s : %.1f Mo (enveloppe %.0f Mo)" % [reg, mb, DecorBake.envelope(reg) / 1048576.0])
		check(at == null or at.bytes <= DecorBake.envelope(reg), "atlas %s dans son enveloppe (%.1f Mo / %.0f Mo)" % [reg, mb, DecorBake.envelope(reg) / 1048576.0])
	check(total <= DecorBake.budget, "tous les atlas sous le plafond (%.1f Mo / %.0f Mo)" % [total / 1048576.0, DecorBake.budget / 1048576.0])
	# Une région en vue n'est jamais rendue, même au-delà du plafond (sinon elle se recuit en boucle).
	var saved: int = DecorBake.budget
	var saved_view: Dictionary = DecorBake.in_view
	var n0: int = DecorBake.atlases.size()
	DecorBake.budget = 1
	DecorBake.in_view = {}
	for reg in DecorBake.atlases:
		DecorBake.in_view[reg] = true
	DecorBake.trim(flora)
	check(DecorBake.atlases.size() == n0, "trim garde les régions en vue (%d / %d)" % [DecorBake.atlases.size(), n0])
	DecorBake.budget = saved
	DecorBake.in_view = saved_view

	DecorBake.clear_disk_cache()
	print("DÉCOR %s" % ("réussi" if failures == 0 else "%d échecs" % failures))
	quit(1 if failures > 0 else 0)
