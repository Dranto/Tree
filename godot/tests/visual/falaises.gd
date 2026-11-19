## Scénario « falaises » du banc visuel (runner.gd) : la région d'Aube morte, ravivée puis
## purifiée, ses quatre Flétris en pleine attaque (et un joueur ébloui), le Cœur de l'aurore, le
## cercle ouvert et la Phalène de verre à chaque attaque, sa mort et le cercle refleuri. Tout est
## figé à un instant précis.
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
	var spot: Vector2 = main.region_center("aube") * 0.62
	await _place(spot)
	await r._frames(30)
	await r._shot("falaises_mort")
	main.revive(spot + Vector2(120, 40), 560.0, Color("fff4cf"))
	await r._frames(200)
	await r._shot("falaises_ravive")
	Game.flags["aube_coeur_purifie"] = true
	await _place(main.region_center("aube") + Vector2(260, -200))
	await r._frames(40)
	_quiet()
	await r._frames(2)
	await r._shot("falaises_purifie")
	Game.flags.erase("aube_coeur_purifie")

	# Les quatre Flétris des falaises, chacun pendant son attaque ; le joueur est ébloui.
	var at: Vector2 = main.region_center("aube") * 0.72 + Vector2(0, -60)
	await _place(at)
	p.dazzle = 1.5
	_frozen("luciole", at + Vector2(-120, -90), {})
	_frozen("luciole", at + Vector2(-150, -40), {})
	_frozen("luciole", at + Vector2(-90, -130), {})
	_frozen("miroitier", at + Vector2(220, -150), {"state": "windup", "state_t": 0.3, "attack_dir": Vector2(-0.8, 0.6).normalized()})
	_frozen("miroitier", at + Vector2(-260, 160), {"state": "recover", "state_t": 0.15, "attack_dir": Vector2(0.85, -0.5).normalized(), "strike_t": 0.05})
	_frozen("prismeur", at + Vector2(330, 120), {"state": "windup", "state_t": 0.35, "attack_dir": Vector2(-1.0, -0.3).normalized()})
	_frozen("prismeur", at + Vector2(-330, -200), {"state": "recover", "state_t": 0.2, "attack_dir": Vector2(0.9, 0.45).normalized(), "strike_t": 0.04})
	_frozen("quartz", at + Vector2(80, 220), {})
	_quiet()
	await r._frames(6)
	await r._shot("falaises_fletris", "jeu")
	_clear()
	p.dazzle = 0.0

	# Le Cœur de l'aurore assiégé, puis le cercle ouvert (la Phalène endormie sur son aiguille).
	var heart = main.hearts["aube"]
	var arena = main.arenas["aube"]
	heart.frozen = true
	arena.frozen = true
	heart.state = "siege"
	heart.progress = 17.0
	heart.update_bar(true)
	for i in 6:
		_frozen("fletri" if i % 2 else "luciole", heart.center + Vector2.from_angle(2.6 + i * 0.26) * (heart.zone + 60.0 + 30.0 * (i % 3)), {})
	await _shot_at("aube_coeur_siege", heart.center + Vector2(190, 150), heart.center)
	_clear()
	heart.state = "fletri"
	heart.progress = 0.0
	heart.update_bar(false)
	Game.flags["aube_coeur_purifie"] = true
	heart._set_purified(false)
	var gate: Vector2 = (heart.center - arena.center).normalized()
	arena.state = "ouverte"
	arena.gap_open = 1.0
	await _shot_at("aube_cercle_ouvert", arena.center + gate * (arena.max_radius + 60.0), arena.center)

	# Le combat : le joueur au sud-est de la Phalène.
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
	boss._begin("ecailles")
	boss.timer = 0.25
	await _shot_at("phalene_ecailles", pos, arena.center)
	boss._strike()
	boss._fire_volley(false)
	for f in boss.scales:
		f["pos"] += f["vel"] * 0.3
	boss._end_attack()
	boss._begin("eclair")
	boss.timer = 0.3
	await _shot_at("phalene_eclair", pos, arena.center)
	boss.scales = []
	boss._end_attack()
	boss.phase = 2
	boss.hp = boss.max_hp * 0.5
	boss._begin("rayons")
	boss.timer = 0.3
	await _shot_at("phalene_rayons", pos, arena.center)
	boss._strike()
	boss.timer = boss.BEAM["frappe"] * 0.7
	main.fx.rings = []
	await _shot_at("phalene_rayons_frappe", pos, arena.center)
	boss._end_attack()
	boss.phase = 3
	boss.hp = boss.max_hp * 0.2
	boss._begin("pluie")
	boss.timer = 0.4
	await _shot_at("phalene_pluie", pos, arena.center)
	_clear([boss])
	boss._end_attack()
	boss.take_damage(boss.max_hp * 2.0, false)
	boss.dying = boss.DEATH_TIME * 0.55
	main.fx.rings = []
	main.hud.banner_time = 0.0
	boss.redraw()
	await _shot_at("phalene_mort", pos, arena.center)
	boss.queue_free()
	arena.life_wave = -1.0
	main.ground.paint(arena.center, arena.max_radius * 1.25, 1.0)
	main.flora.spawn_patch(arena.center, arena.max_radius, 70, Color("fff4cf"))
	main.fx.rings = []
	main.hud.banner_time = 0.0
	await _shot_at("phalene_vaincue", pos, arena.center)


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
	var heart = main.hearts["aube"]
	var arena = main.arenas["aube"]
	heart.t = 1.0
	arena.t = 1.0
	if is_instance_valid(arena.boss) and arena.state == "combat":
		arena.update_bar()
		arena.boss.redraw()
	heart.queue_redraw()
	heart.body.queue_redraw()
	arena.queue_redraw()
	if not shot_name.begins_with("phalene_mort") and not shot_name.begins_with("phalene_vaincue"):
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
	e.queue_redraw()
	return e


func _clear(keep: Array = []) -> void:
	for e in main.enemies:
		if is_instance_valid(e) and not e in keep:
			e.queue_free()
	main.enemies = keep.duplicate()
