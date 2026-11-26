## Test des règles communes aux cuissons des boss (boss_art/cuisson.gd) :
##   - changer de mode daltonien (SpriteBake.palette_changed) fait jeter ce qui a été cuit par chacune des
##     cuissons (boss_body_cache, pose_cache, live_bake ; boss_bake a le mode dans sa clé) ;
##   - « --no-sprites » (SpriteBake.enabled faux) coupe aussi la cuisson des boss : dessin direct ;
##   - l'échelle de cuisson suit la fenêtre, bornée.
## Rendu réel : tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/boss_cuisson_test.gd
extends SceneTree

const Cuisson = preload("res://scripts/boss_art/cuisson.gd")
const SpriteBake = preload("res://scripts/sprite_bake.gd")
const BodyCache = preload("res://scripts/boss_body_cache.gd")
const PoseCache = preload("res://scripts/pose_cache.gd")
const LiveBake = preload("res://scripts/boss_art/live_bake.gd")
const BossBake = preload("res://scripts/boss_bake.gd")

var failures := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _square(ci: CanvasItem, _o = null) -> void:
	ci.draw_rect(Rect2(-10, -20, 20, 20), Art.bc("ronce", "clair"))


func _run() -> void:
	check(Cuisson.active(), "cuisson active avec un écran")
	var host := Node2D.new()
	root.add_child(host)

	# Cache par pose (Amanite-Mère, Saule).
	var bc = BodyCache.new(host, Rect2(-16, -32, 32, 40), _square)
	bc.texture("a", {})
	bc.texture("b", {})
	await _frames(2)
	check(bc.entries.size() == 2, "deux poses cuites")
	var e0 := Cuisson.epoch
	SpriteBake.palette_changed()
	check(Cuisson.epoch == e0 + 1, "SpriteBake.palette_changed prévient les boss")
	bc.texture("a", {})
	check(bc.entries.size() == 1, "mode daltonien changé : les poses cuites du corps sont jetées")

	# Poses vectorielles (Harfang, Phalène).
	var pc = PoseCache.on(host)
	pc.show_pose("x", func(ci): _square(ci), Transform2D.IDENTITY)
	pc.show_pose("y", func(ci): _square(ci), Transform2D.IDENTITY)
	await _frames(2)
	check(pc.size() == 2, "deux poses gardées")
	Cuisson.palette_changed()
	pc.show_pose("x", func(ci): _square(ci), Transform2D.IDENTITY)
	check(pc.size() == 1, "mode daltonien changé : les poses vectorielles sont redessinées")

	# Cuisson vivante (Flétrissure) : la même clé est redessinée tout de suite après un changement.
	var lb = LiveBake.new(host, Rect2(-16, -32, 32, 40), func(ci): _square(ci))
	await _frames(1)
	lb.update("k", 10.0)
	var last: float = lb._last
	lb.update("k", 10.01)
	check(lb._last == last, "même clé, trop tôt : pas de nouveau rendu")
	Cuisson.palette_changed()
	lb.update("k", 10.02)
	check(lb._last > last, "mode daltonien changé : nouveau rendu tout de suite")
	lb.free_viewport()

	# Atlas (Mère-Ronce, Ancien) : le mode est dans la clé.
	var mode := Art.mode_daltonien
	var k1: String = BossBake.key_of(load("res://scripts/creature_art/ronce/_mere_ronce.gd"))
	Art.set_access("deuteranopie")
	var k2: String = BossBake.key_of(load("res://scripts/creature_art/ronce/_mere_ronce.gd"))
	Art.set_access(mode)
	check(k1 != k2, "atlas : le mode daltonien est dans la clé")

	# « --no-sprites » coupe toutes les cuissons de boss.
	SpriteBake.enabled = false
	check(not Cuisson.active() and BodyCache.headless() and not LiveBake.available(), "--no-sprites : boss en dessin direct")
	check(BossBake.get_atlas(host, load("res://scripts/creature_art/ronce/_mere_ronce.gd")) == null, "--no-sprites : pas d'atlas")
	SpriteBake.enabled = true

	var s := Cuisson.window_scale(1.1, 1.0, 3.0)
	check(s >= 1.0 and s <= 3.0 and is_equal_approx(fmod(s, 0.25), 0.0), "échelle bornée, au pas de 0,25 (%.2f)" % s)

	bc.clear()
	host.queue_free()
	await _frames(2)
	print("BOSS_CUISSON %s (%d échec(s))" % ["OK" if failures == 0 else "ÉCHEC", failures])
	quit(1 if failures > 0 else 0)
