## Test des morts et des impact frames depuis les sprites cuits (refonte des personnages, tâche M) :
## un Flétri dessiné depuis son image cuite laisse des restes qui partent de cette image (même côté,
## même taille), chacune des huit morts se dessine depuis l'image sans erreur et suit sa recette
## (teinte, cendre, effritement, tranche en deux moitiés), la découpe du quadrilatère garde l'aire,
## et l'impact frame passe l'image cuite en silhouette par son propre shader (un Flétri dont l'éclair
## du coup reçu est en cours garde sa forme), puis rend le matériau d'origine ; un Flétri mort est
## redessiné depuis son image. Sans sprites, rien ne change (les restes gardent la silhouette).
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 -s res://tests/remains_sprite_test.gd -- --sprites=3
extends SceneTree

const Sprites = preload("res://scripts/sprite_bake.gd")

var failures := 0
var main
var Remains


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


func _remains() -> Array:
	return main.enemies_layer.get_children().filter(func(n): return n.get_script() == Remains and not n.is_queued_for_deletion())


func _run() -> void:
	Remains = load("res://scripts/enemy_remains.gd")
	var settings = root.get_node("Settings")
	var saved := [settings.reduce_effects, settings.flash_scale]
	settings.reduce_effects = false
	settings.flash_scale = 1.0

	print("Découpe du quadrilatère")
	var quad := PackedVector2Array([Vector2(-10, -20), Vector2(10, -20), Vector2(10, 10), Vector2(-10, 10)])
	var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var n := Vector2(1, -0.4).normalized()
	var a: Array = Remains.clip_poly(quad, uv, n)
	var b: Array = Remains.clip_poly(quad, uv, -n)
	var area := func(p: PackedVector2Array) -> float:
		var s := 0.0
		for i in p.size():
			s += p[i].cross(p[(i + 1) % p.size()])
		return absf(s) * 0.5
	check(absf(area.call(a[0]) + area.call(b[0]) - 600.0) < 0.01, "les deux moitiés font le quadrilatère entier")
	var ok_uv := true
	for i in a[0].size():
		var want: Vector2 = (a[0][i] - Vector2(-10, -20)) / Vector2(20, 30)
		ok_uv = ok_uv and a[1][i].is_equal_approx(want)
	check(ok_uv, "coordonnées de texture interpolées sur la coupe")

	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _frames(3)
	main.autotest = false
	main.player.invuln = 1.0e9
	main.player.set_physics_process(false)
	check(Sprites.enabled, "sprites cuits activés (-- --sprites=3)")
	# Les sortes d'une région ne sont cuites qu'à l'entrée : on cuit d'avance celles du test.
	await Sprites.bake(main, ["fletri", "menhir", "tireur", "scarabee", "colosse", "chargeur", "gardien"])
	check(Sprites.atlases.has("fletri") and Sprites.atlases.has("menhir"), "sortes cuites au chargement")

	print("Restes depuis l'image cuite")
	var at: Vector2 = main.player.position + Vector2(90, 0)
	var e = main.spawn_enemy_kind("fletri", at, 1.0)
	await _frames(4)
	check(e._sprite != null, "le Flétri est dessiné depuis l'atlas")
	var f: Dictionary = Remains.enemy_frame(e)
	check(not f.is_empty() and f["tex"] is Texture2D and f["rect"].size.x > 0.0, "image cuite du Flétri lisible")
	check(f.get("side", 0.0) == e._side, "même côté que l'image affichée")
	var big: Rect2 = Rect2(f["rect"])
	check(big.size.y >= 2.0 * e.radius * 0.9, "l'image couvre au moins le Flétri entier")
	for r in _remains():
		r.free()
	main.player_hit_enemy(e, 1.0e5, false, "ronce")
	await _frames(3)
	var list := _remains()
	check(list.size() == 1, "un reste")
	if list.size() == 1:
		var r = list[0]
		check(not r.sprite.is_empty() and r.sprite["tex"] == f["tex"], "le reste part de l'image cuite")
		check(r._spr != null and r._spr.material != null and r._spr.material.shader.resource_path.ends_with("remains_sprite.gdshader"), "dessiné par le shader des restes")
		check(r._r() > r.radius * 0.99, "les morceaux suivent la taille du dessin")
		check(r.style == "sang", "toujours la mort de l'élément (%s)" % r.style)

	print("Les huit morts depuis l'image")
	var holder := Node2D.new()
	main.enemies_layer.add_child(holder)
	var kinds := ["fletri", "menhir", "tireur", "scarabee", "colosse", "fletri", "chargeur", "gardien"]
	for i in Remains.STYLES.size():
		var s: String = Remains.STYLES[i]
		var r = Remains.new()
		r.style = s
		r.kind_id = kinds[i]
		r.radius = 16.0
		r.dir = Vector2(1, -0.3).normalized()
		r.sprite = Remains.frame_for(kinds[i], {}, 0.3)
		r.side = -1.0 if i % 2 == 1 else 1.0
		r.elite = i == 5
		r.region = "aube" if i == 5 else ""
		r.position = at + Vector2(i * 60, 80)
		r._styled = true
		holder.add_child(r)
		r.set_process(false)
		check(not r.sprite.is_empty() and r._spr != null, "%s : image cuite (%s)" % [s, kinds[i]])
		var seen := {}
		for k in 12:
			r.t = r.duration() * k / 11.0
			r.queue_redraw()
			r._spr.queue_redraw()
			await _frames(1)
			var m: ShaderMaterial = r._smat
			for key in ["tint", "ash", "crumble", "alpha"]:
				var v = m.get_shader_parameter(key)
				var x: float = v.w if v is Vector4 else float(v)
				seen[key] = maxf(float(seen.get(key, 0.0)), x)
		match s:
			"cendre":
				check(seen["ash"] > 0.9 and seen["crumble"] > 0.5, "cendre : éteint puis effrité par le haut")
			"venin", "sang", "aube", "racine", "seve":
				check(seen["tint"] > 0.5, "%s : teinte de la mort sur l'image" % s)
			"vent", "tranche":
				check(seen["ash"] > 0.3, "%s : grisé en cendre" % s)
		r.t = r.duration() + 1.0
		r._spr.queue_redraw()
		await _frames(1)
		check(float(r._smat.get_shader_parameter("alpha")) <= 0.01, "%s : l'image a disparu à la fin" % s)
	holder.queue_free()

	print("Impact frame sur une image cuite")
	var m = main.moments
	var e2 = main.spawn_enemy_kind("menhir", at + Vector2(0, -60), 1.0)
	await _frames(4)
	e2.take_damage(1.0, false)   # l'éclair du coup reçu est en cours
	await _frames(1)
	check(e2.hit_flash > 0.0, "éclair du coup reçu en cours")
	check(m.impact_frame(0.5, [e2], "encre"), "impact frame lancée")
	check(e2._sprite.material == m._mat_sprite, "l'image cuite prend la silhouette des sprites")
	check(e2._body.material == m._mat, "le reste du Flétri garde la silhouette d'avant")
	check(m._mat_sprite.get_shader_parameter("tint") == m.shown_sil, "même encre que les autres silhouettes")
	m._end_frame()
	check(e2._sprite.material == Sprites.material() and e2._body.material == null, "matériaux rendus après l'impact frame")
	var ghost := {"kind": "menhir", "pos": e2.position, "r": float(e2.radius), "face": Vector2.RIGHT, "sprite": Remains.enemy_frame(e2)}
	check(not ghost["sprite"].is_empty(), "un Flétri mort garde son image pour l'impact frame")
	check(m.impact_frame(0.85, [ghost], "region", "vent"), "impact frame d'un Flétri mort")
	await _frames(1)
	check(m._ghosts.size() == 1 and not m._ghosts[0]["sprite"].is_empty(), "redessiné depuis son image")
	m._end_frame()

	print("Sans sprites")
	Sprites.enabled = false
	var e3 = main.spawn_enemy_kind("fletri", at + Vector2(-80, 40), 1.0)
	await _frames(3)
	check(e3._sprite == null and Remains.enemy_frame(e3).is_empty(), "pas d'image : la mort garde la silhouette calculée")

	settings.reduce_effects = saved[0]
	settings.flash_scale = saved[1]
	print("RESTES SPRITES %s" % ("réussi" if failures == 0 else "%d échecs" % failures))
	quit(1 if failures > 0 else 0)
