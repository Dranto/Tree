## Scénario « plateaux » du banc visuel (runner.gd) : la région de Vent morte, ravivée puis
## purifiée, une rafale, ses quatre Flétris en pleine attaque, le Cœur des rafales, l'aire et le
## Harfang de cendre à chaque attaque, sa mort et l'aire refleurie. Tout est figé à un instant précis.
extends RefCounted

var r
var main


func run(runner) -> void:
	r = runner
	main = r.main
	main.autotest = false
	main.spawn_timer = 1.0e9
	var p = main.player
	p.set_physics_process(false)
	var Wind = load("res://scripts/wind.gd")
	var spot: Vector2 = main.region_center("vent") * 0.62
	await _place(spot)
	var w = Wind.active
	# Une rafale en plein souffle : les traînées filent dans le sens du vent.
	w.state = "rafale"
	w.timer = float(w.cfg["gust"]) * 0.6
	w.set_physics_process(false)
	w.strength = 0.9
	await r._frames(30)
	await r._shot("plateaux_mort")
	main.revive(spot + Vector2(-120, 40), 560.0, Art.ec("vent", "clair"))
	await r._frames(200)
	await r._shot("plateaux_ravive")
	w.strength = 0.0
	w.state = "calme"
	Game.flags["vent_coeur_purifie"] = true
	await _place(main.region_center("vent") + Vector2(-260, -200))
	await r._frames(40)
	_quiet()
	await r._frames(2)
	await r._shot("plateaux_purifie")
	Game.flags.erase("vent_coeur_purifie")

	# Les quatre Flétris des plateaux, chacun pendant son attaque.
	var at: Vector2 = main.region_center("vent") * 0.8 + Vector2(500, 0)
	await _place(at)
	var diver = _frozen("plongeur", at + Vector2(-260, -160), {"state": "windup", "state_t": 0.25, "attack_dir": Vector2(0.85, 0.55).normalized()})
	_frozen("plongeur", at + Vector2(240, 150), {"state": "charge", "travelled": 140.0, "attack_dir": Vector2(-0.6, -0.8)})
	_frozen("souffleur", at + Vector2(220, -150), {"state": "windup", "state_t": 0.3, "attack_dir": Vector2(-0.8, 0.6).normalized()})
	_frozen("planeur", at + Vector2(-330, 170), {})
	_frozen("planeur", at + Vector2(90, -90), {"state": "vol", "attack_dir": Vector2(0.7, -0.7).normalized()})
	_frozen("menhir", at + Vector2(-90, 210), {})
	diver.queue_redraw()
	_quiet()
	await r._frames(6)
	await r._shot("plateaux_fletris", "jeu")
	_clear()

	# Le Cœur des rafales assiégé, puis l'aire ouverte (le Harfang endormi sur son rocher).
	var heart = main.hearts["vent"]
	var arena = main.arenas["vent"]
	heart.frozen = true
	arena.frozen = true
	heart.state = "siege"
	heart.progress = 17.0
	heart.update_bar(true)
	for i in 6:
		_frozen("fletri" if i % 2 else "plongeur", heart.center + Vector2.from_angle(-0.5 + i * 0.26) * (heart.zone + 60.0 + 30.0 * (i % 3)), {})
	await _shot_at("vent_coeur_siege", heart.center + Vector2(-190, 150), heart.center)
	_clear()
	heart.state = "fletri"
	heart.progress = 0.0
	heart.update_bar(false)
	Game.flags["vent_coeur_purifie"] = true
	heart._set_purified(false)
	var gate: Vector2 = (heart.center - arena.center).normalized()
	arena.state = "ouverte"
	arena.gap_open = 1.0
	await _shot_at("vent_aire_ouverte", arena.center + gate * (arena.max_radius + 60.0), arena.center)

	# Le combat : le joueur au sud-est du Harfang.
	var pos: Vector2 = arena.center + Vector2(130, 160)
	p.position = pos
	arena._start_fight()
	arena.gap_open = 0.0
	var boss = arena.boss
	boss.frozen = true
	boss.intro = 0.0
	boss.t = 0.7
	main.hud.banner_time = 0.0
	main.fx.rings = []
	boss._begin("plumes")
	boss.timer = 0.25
	await _shot_at("harfang_plumes", pos, arena.center)
	boss._strike()
	boss._fire_volley(false)
	for f in boss.feathers:
		f["pos"] += f["vel"] * 0.3
	boss._end_attack()
	boss._begin("battement")
	boss.timer = 0.35
	await _shot_at("harfang_battement", pos, arena.center)
	boss.feathers = []
	boss._end_attack()
	boss.phase = 2
	boss.hp = boss.max_hp * 0.5
	boss._begin("pique")
	boss.dive_step = "fige"
	boss.dive_t = 0.2
	boss.dive_target = pos + Vector2(-30, -10)
	await _shot_at("harfang_pique", pos, arena.center)
	boss.dive_step = "pose"
	boss.dive_t = boss.DIVE["ground"] - 0.1
	boss.anchor = boss.dive_target + Vector2(-60, -40)
	boss.position = boss.anchor
	boss.radius = boss.body_radius
	await _shot_at("harfang_pose", pos + Vector2(60, 60), arena.center)
	boss.anchor = arena.center
	boss.position = arena.center
	boss._end_attack()
	boss.phase = 3
	boss.hp = boss.max_hp * 0.2
	boss.swirl = 1.0
	boss._begin("tempete")
	boss._strike()
	for i in boss.tornadoes.size():
		boss.tornadoes[i]["life"] = boss.STORM["life"] - 1.5
		boss.tornadoes[i]["pos"] = arena.center + Vector2.from_angle(0.6 + i * 2.4) * 220.0
	boss._begin("plumes")
	boss.timer = 0.5
	await _shot_at("harfang_tempete", pos, arena.center)
	_clear([boss])
	boss.take_damage(boss.max_hp * 2.0, false)
	boss.dying = boss.DEATH_TIME * 0.55
	main.fx.rings = []
	main.hud.banner_time = 0.0
	boss.redraw()
	await _shot_at("harfang_mort", pos, arena.center)
	boss.queue_free()
	arena.life_wave = -1.0
	main.ground.paint(arena.center, arena.max_radius * 1.25, 1.0)
	main.flora.spawn_patch(arena.center, arena.max_radius, 70, Art.ec("vent", "clair"))
	main.fx.rings = []
	main.hud.banner_time = 0.0
	await _shot_at("harfang_vaincu", pos, arena.center)


func _place(pos: Vector2) -> void:
	var p = main.player
	p.position = pos
	p.reset_physics_interpolation()
	main.camera.reset_smoothing()
	await r._frames(2)


## Place le joueur (tourné vers « look »), redessine les poses figées, puis capture l'écran de jeu.
func _shot_at(shot_name: String, pos: Vector2, look: Vector2) -> void:
	var p = main.player
	p.position = pos
	p.aim = (look - pos).normalized()
	p.reset_physics_interpolation()
	main.camera.reset_smoothing()
	var heart = main.hearts["vent"]
	var arena = main.arenas["vent"]
	heart.t = 1.0
	arena.t = 1.0
	if is_instance_valid(arena.boss) and arena.state == "combat":
		arena.update_bar()
		arena.boss.redraw()
	heart.queue_redraw()
	heart.body.queue_redraw()
	arena.queue_redraw()
	if not shot_name.begins_with("harfang_mort") and not shot_name.begins_with("harfang_vaincu"):
		_quiet()
	await r._frames(6)
	await r._shot(shot_name, "jeu")


## Retire les annonces (objectif accompli, cri du boss) : la capture montre la scène, pas le texte.
func _quiet() -> void:
	main.hud.banner_queue = []
	main.hud.banner_time = 0.0


## Un Flétri immobile, figé dans un état donné (propriétés de enemy.gd).
func _frozen(kind: String, pos: Vector2, props: Dictionary):
	var e = main.spawn_enemy_kind(kind, pos, 1.0)
	e.t = 0.5
	for k in props:
		e.set(k, props[k])
	e.cd = 99.0
	e.set_process(false)
	e.set_physics_process(false)
	return e


func _clear(keep: Array = []) -> void:
	for e in main.enemies:
		if is_instance_valid(e) and not e in keep:
			e.queue_free()
	main.enemies = keep.duplicate()
