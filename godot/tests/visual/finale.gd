## Scénario « finale » du banc visuel (runner.gd) : la brèche ouverte au pied de la graine, le creux
## sous la graine et la Flétrissure endormie, chacune de ses attaques dans ses trois phases, sa
## transformation (le creux qui s'effondre), ses attaques combinées, sa seconde forme entière, sa mort
## et le creux refleuri, puis l'épilogue (textes et statistiques), le générique et sa fin.
## Tout est figé à un instant précis.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")

var r
var main


func run(runner) -> void:
	r = runner
	main = r.main
	main.autotest = false
	main.spawn_timer = 1.0e9
	var p = main.player
	p.set_physics_process(false)
	var finale = main.finale
	# Toutes les régions purifiées : la Flétrissure s'est retirée sous la graine.
	for id in Regions.ids():
		Game.flags[Regions.heart_flag(id)] = true
		Game.flags[Regions.boss_flag(id)] = true
		Game.flags[Regions.ending_flag(id)] = true
	Game.level = 24
	Game.kills = 4210
	Game.flags[Objectives.STAT_DEATHS] = 9
	Game.flags[Objectives.ELITES] = 31
	main.elapsed = 5.0 * 3600.0 + 23.0 * 60.0
	await r._frames(4)
	finale.frozen = true
	finale._open()
	finale.hold = 0.55
	await _shot_at("finale_breche", finale.descent_point() + Vector2(10, 4), finale.descent_point() + Vector2(0, -200))

	# Sous la graine : le creux, la Flétrissure endormie, le puits de lumière où l'on arrive.
	finale.descend()
	main.screen_fx.fade(Color(0, 0, 0), 0.0, 0.0, 0.01)
	await _shot_at("finale_arene", finale.landing() + Vector2(0, -20), finale.center)

	# Le combat. Le joueur se tient au sud-est d'elle.
	var pos: Vector2 = finale.center + Vector2(150, 160)
	p.position = pos
	finale._start_fight()
	var boss = finale.boss
	# Captures du combat lui-même : sans l'attente calée sur le morceau (invocation, drops ; boss_sync.gd).
	if finale.sync != null:
		finale.sync.stop()
	boss.frozen = true
	boss.intro = 0.0
	boss.t = 0.7
	main.fx.rings = []
	# Phase 1 : éventail d'épines annoncé, et des nuages de spores déjà posés.
	boss.clouds = [{"pos": finale.center + Vector2(-210, 120), "time": 2.0}, {"pos": finale.center + Vector2(-120, 250), "time": 2.0}]
	boss._begin("epines")
	boss.timer = 0.25
	await _shot_at("finale_epines", pos, finale.center)
	# Phase 1 : les épines en vol, des spores annoncées autour du joueur.
	boss._strike()
	boss._strike_step(0.0)
	for th in boss.thorns:
		th["pos"] += th["vel"] * 0.4
	boss._end_attack()
	boss._begin("spores")
	boss.spore_marks = [pos + Vector2(10, 0), pos + Vector2(-150, 70), pos + Vector2(60, -160)]
	boss.timer = 0.35
	await _shot_at("finale_spores", pos, finale.center)

	# Phase 2 : le siphon (elle boit), puis la rafale annoncée.
	boss.thorns = []
	boss.clouds = []
	boss._end_attack()
	boss.spore_marks = []
	boss.phase = 2
	boss.hp = boss.max_hp * 0.55
	boss._begin("siphon")
	boss._strike()
	boss.timer = 1.1
	await _shot_at("finale_siphon", pos + Vector2(60, 60), finale.center)
	boss._end_attack()
	boss._begin("rafale")
	boss.timer = 0.3
	await _shot_at("finale_rafale", pos, finale.center)
	boss._end_attack()

	# Phase 3 : la transformation, à mi-chemin : le manteau et la couronne tombent, le creux s'effondre.
	boss.phase = 3
	boss.hp = boss.max_hp * 0.33
	boss.unbound = true
	boss.morph_time = boss.TRANSFORM["time"] * 0.22
	finale.collapse_t = finale.collapse_time * 0.6
	finale._collapse_step(0.0)
	main.fx.rings = []
	await _shot_at("finale_effondrement", pos, finale.center)

	# La seconde forme : l'île au-dessus du gouffre.
	boss.morph_time = -1.0
	finale.collapse_t = -1.0
	finale.collapse_k = 1.0
	finale.radius = finale.collapse_radius
	boss.hp = boss.max_hp * 0.25
	pos = finale.center + Vector2(130, 140)
	# Tempête (Vent + Ronce) : la rafale et l'éventail d'épines annoncés ensemble.
	boss._begin("tempete")
	boss.timer = 0.3
	await _shot_at("finale_tempete", pos, finale.center)
	boss._end_attack()
	# Floraison (Spore + Sève) : des nuages qui boivent déjà posés, d'autres annoncés.
	boss.clouds = [{"pos": finale.center + Vector2(-180, 110), "time": 2.0, "drain": true}, {"pos": finale.center + Vector2(-60, 230), "time": 2.0, "drain": true}]
	boss._begin("floraison")
	boss.spore_marks = [pos + Vector2(10, 0), pos + Vector2(-140, 60), pos + Vector2(60, -150)]
	boss.timer = 0.4
	await _shot_at("finale_floraison", pos, finale.center)
	boss._end_attack()
	boss.clouds = []
	boss.spore_marks = []
	# Rayons de lumière annoncés.
	boss._begin("lumiere")
	boss.timer = 0.3
	await _shot_at("finale_lumiere", pos, finale.center)
	boss._end_attack()
	boss.rays = []
	# Aurore (Aube + Racine) : l'éclair des rayons, puis les racines qui jaillissent le long de chacun.
	boss._begin("aurore")
	# (sans _strike : le rayon qui vise le joueur le toucherait.)
	boss.stage = "frappe"
	boss.flash_kind = "lumiere"
	for r in boss.roots:
		r["fuse"] = maxf(0.0, float(r["fuse"]) - boss.LIGHT["annonce"] - 0.4)
		if r["fuse"] <= 0.0:
			r["burst"] = 0.1
	boss.strike_flash = 0.1
	await _shot_at("finale_aurore", pos, finale.center)
	boss._clear_attacks()
	boss.strike_flash = -1.0
	boss._begin("racines")
	boss._strike()
	for i in boss.roots.size():
		boss.roots[i]["fuse"] = -1.0 if i < 2 else 0.15 * (i - 1)
		boss.roots[i]["burst"] = 0.12 if i < 2 else -1.0
	await _shot_at("finale_racines", pos, finale.center)
	# Le colosse en entier, en seconde forme, entre deux coups : les éclats des six gardiens.
	boss._clear_attacks()
	await _shot_at("finale_colosse", finale.center + Vector2(250, 30), finale.center)

	# Sa mort, à mi-chemin : les bras retombent en cendre, la sève jaillit des fentes.
	boss._clear_attacks()
	boss.take_damage(boss.max_hp * 2.0, false)
	# La pose de la mort seule : sans le dernier coup (impact frame tenue, ralenti, distorsion).
	main.moments.stop_all()
	boss.dying = boss.death_time * 0.5
	main.fx.rings = []
	boss.redraw()
	await _shot_at("finale_mort", pos, finale.center, false)
	boss.queue_free()
	finale.life_wave = -1.0
	finale.bloom = 1.0
	# La floraison a refermé le gouffre.
	finale.collapse_k = 0.0
	finale.radius = finale.max_radius
	main.fx.rings = []
	await _shot_at("finale_vaincue", pos, finale.center)

	# La fin jouée dans le monde (world_ending.gd) : le joueur au pied de la graine, les vagues de
	# vie, le générique qui s'écrit dans l'herbe, puis tous les noms écrits.
	var q = main.quest_ui
	q.start_epilogue()
	finale.finish_ascent()
	var ending = q.world_ending
	ending.set_time(ending.STEP * 3.0 + 1.0)
	main.ground.finish_waves()
	await r._frames(3)
	await r._shot("fin_generique", "jeu")
	ending.set_time(ending.duration() + 1.0)
	main.ground.finish_waves()
	await r._frames(3)
	await r._shot("fin_monde", "jeu")


## Place le joueur (tourné vers « look »), redessine les poses figées, puis capture l'écran de jeu.
func _shot_at(shot_name: String, pos: Vector2, look: Vector2, quiet := true) -> void:
	var p = main.player
	var finale = main.finale
	p.position = pos
	p.aim = (look - pos).normalized()
	p.reset_physics_interpolation()
	main.camera.reset_smoothing()
	finale.t = 1.0
	if is_instance_valid(finale.boss) and finale.state == "combat":
		finale.update_bar()
		finale.boss.redraw()
	finale.queue_redraw()
	if quiet:
		main.hud.banner_queue = []
		main.hud.banner_time = 0.0
	await r._frames(6)
	await r._shot(shot_name, "jeu")
