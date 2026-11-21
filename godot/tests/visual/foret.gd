## Scénario « foret » du banc visuel (runner.gd) : la région de Racine morte, ravivée puis purifiée,
## ses quatre Flétris en pleine action, le Cœur des cernes, la clairière ouverte et l'Ancien pétrifié
## à chaque attaque, sa mort et la clairière reverdie. Tout est figé à un instant précis.
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
	var spot: Vector2 = main.region_center("racine") * 0.72
	await _place(spot)
	await r._frames(30)
	await r._shot("foret_mort")
	main.revive(spot + Vector2(120, 40), 560.0, Art.ec("racine", "clair"))
	await r._frames(200)
	await r._shot("foret_ravive")
	Game.flags["racine_coeur_purifie"] = true
	await _place(main.region_center("racine") + Vector2(260, -200))
	await r._frames(40)
	_quiet()
	await r._frames(2)
	await r._shot("foret_purifie")
	Game.flags.erase("racine_coeur_purifie")

	# Les quatre Flétris de la forêt, chacun pendant son action.
	var at: Vector2 = main.region_center("racine") * 0.78
	await _place(at)
	for i in 3:
		_frozen("termite", at + Vector2(-260 + 34 * i, -170 + 22 * (i % 2)), {"walk": 0.6 * i})
	var burrow = _frozen("mandragore", at + Vector2(-80, 150), {"state": "sous", "state_t": 0.5, "attack_dir": Vector2(0.6, -0.8).normalized()})
	var rising = _frozen("mandragore", at + Vector2(140, -40), {"state": "windup", "state_t": 0.25})
	rising.set_meta("cible", rising.position)
	_frozen("mandragore", at + Vector2(-300, 60), {"state": "recover", "state_t": 0.5})
	_frozen("scarabee", at + Vector2(260, 150), {"state": "windup", "state_t": 0.3, "attack_dir": Vector2(-0.8, -0.6).normalized()})
	_frozen("scarabee", at + Vector2(-160, -40), {"state": "charge", "travelled": 120.0, "attack_dir": Vector2(0.9, 0.4).normalized()})
	_frozen("tertre", at + Vector2(330, -120), {"state": "windup", "state_t": 0.4})
	burrow.queue_redraw()
	_quiet()
	await r._frames(6)
	await r._shot("foret_fletris", "jeu")
	_clear()

	# Le Cœur des cernes assiégé, puis la clairière ouverte (l'Ancien endormi).
	var heart = main.hearts["racine"]
	var arena = main.arenas["racine"]
	heart.frozen = true
	arena.frozen = true
	heart.state = "siege"
	heart.progress = 17.0
	heart.update_bar(true)
	for i in 6:
		_frozen("fletri" if i % 2 else "termite", heart.center + Vector2.from_angle(-0.5 + i * 0.26) * (heart.zone + 60.0 + 30.0 * (i % 3)), {})
	await _shot_at("racine_coeur_siege", heart.center + Vector2(190, 150), heart.center)
	_clear()
	heart.state = "fletri"
	heart.progress = 0.0
	heart.update_bar(false)
	Game.flags["racine_coeur_purifie"] = true
	heart._set_purified(false)
	var gate: Vector2 = (heart.center - arena.center).normalized()
	arena.state = "ouverte"
	arena.gap_open = 1.0
	await _shot_at("racine_clairiere_ouverte", arena.center + gate * (arena.max_radius + 60.0), arena.center)

	# Le combat : le joueur au sud-est de l'Ancien.
	var pos: Vector2 = arena.center + Vector2(140, 150)
	p.position = pos
	# Les frappes montrées ne doivent pas blesser le héros (pas d'éclair rouge sur l'image).
	p.invuln = 1.0e6
	arena._start_fight()
	arena.gap_open = 0.0
	var boss = arena.boss
	boss.frozen = true
	boss.intro = 0.0
	boss.t = 0.7
	main.hud.banner_time = 0.0
	main.fx.rings = []
	boss._begin("racines")
	boss.timer = 0.3
	await _shot_at("ancien_racines", pos, arena.center)
	boss._strike()
	boss.strike_flash = 0.08
	await _shot_at("ancien_racines_frappe", pos, arena.center)
	boss._clear_attacks()
	boss._begin("eboulis")
	boss.timer = 0.3
	await _shot_at("ancien_eboulis", pos, arena.center)
	boss._clear_attacks()
	boss._begin("pieu")
	boss.timer = 0.2
	await _shot_at("ancien_pieu", pos, arena.center)
	boss._strike()
	boss.strike_flash = 0.08
	await _shot_at("ancien_pieu_frappe", pos, arena.center)
	boss._clear_attacks()
	boss.phase = 2
	boss.hp = boss.max_hp * 0.5
	boss._begin("chute")
	boss.timer = 0.4
	await _shot_at("ancien_chute", pos + Vector2(60, 60), arena.center)
	boss._clear_attacks()
	boss._begin("invocation")
	boss.timer = 0.4
	await _shot_at("ancien_invocation", pos, arena.center)
	boss._clear_attacks()
	boss.phase = 3
	boss.hp = boss.max_hp * 0.2
	boss._begin("racines")
	boss.timer = 0.2
	await _shot_at("ancien_phase3", pos, arena.center)
	_clear([boss])
	boss._clear_attacks()
	boss.take_damage(boss.max_hp * 2.0, false)
	boss.dying = boss.death_time * 0.55
	main.fx.rings = []
	main.hud.banner_time = 0.0
	boss.redraw()
	await _shot_at("ancien_mort", pos, arena.center)
	boss.queue_free()
	arena.life_wave = -1.0
	main.ground.paint(arena.center, arena.max_radius * 1.25, 1.0)
	main.flora.spawn_patch(arena.center, arena.max_radius, 70, Art.ec("racine", "clair"))
	main.fx.rings = []
	main.hud.banner_time = 0.0
	await _shot_at("ancien_vaincu", pos, arena.center)


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
	var heart = main.hearts["racine"]
	var arena = main.arenas["racine"]
	heart.t = 1.0
	arena.t = 1.0
	if is_instance_valid(arena.boss) and arena.state == "combat":
		arena.update_bar()
		arena.boss.redraw()
	heart.queue_redraw()
	heart.body.queue_redraw()
	arena.queue_redraw()
	if not shot_name.begins_with("ancien_mort") and not shot_name.begins_with("ancien_vaincu"):
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
