## Test du moteur multi-régions : une région factice (tests/regions/essai.json et son boss
## tests/regions/boss_essai.gd) s'ajoute au monde avec des fichiers seulement. On y vérifie le sol
## teinté, un sanctuaire, un Cœur, un boss minimal, la récompense et la fin de la région, et que
## Ronce n'a pas bougé.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/region_engine_test.gd
## Ne lit ni n'écrit la sauvegarde par défaut.
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
const Ground = preload("res://scripts/ground.gd")
const Content = preload("res://scripts/content.gd")

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


func _steps(n: int) -> void:
	for i in n:
		await physics_frame


func _until(cond: Callable, limit := 900) -> bool:
	for i in limit:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _place(pos: Vector2) -> void:
	main.player.position = pos
	main.player.hp = 1.0e6


func _run() -> void:
	var game = root.get_node("Game")
	var objectives = root.get_node("Objectives")

	print("Fichiers")
	var ronce_center := Regions.center("ronce")
	Regions.set_extra_dirs(["res://tests/regions/"])
	check(Regions.ids() == ["ronce", "essai"], "la région d'essai s'ajoute après Ronce, dans l'ordre des branches (%s)" % [Regions.ids()])
	check(Regions.validate().is_empty(), "ses fichiers sont valides (check_data) %s" % [Regions.validate()])
	check(Regions.center("ronce") == ronce_center, "Ronce ne bouge pas")
	var c := Regions.center("essai")
	check(Regions.region_at(c) == "essai" and Regions.region_at(ronce_center) == "ronce", "region_at reconnaît les deux régions")

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	await _steps(3)

	print("Sol teinté")
	var mat: ShaderMaterial = main.ground.mat
	check(int(mat.get_shader_parameter("region_count")) == 2, "le shader reçoit deux régions")
	var pal := Ground.region_palette("essai")
	var dead: PackedVector3Array = mat.get_shader_parameter("region_dead_dark")
	check(dead.size() == 2 and dead[1].is_equal_approx(Vector3(pal["dead_dark"].r, pal["dead_dark"].g, pal["dead_dark"].b)), "la terre morte de la région d'essai a sa couleur")
	check(dead.size() == 2 and not dead[1].is_equal_approx(dead[0]), "et elle diffère de celle de Ronce")

	print("Sanctuaire")
	var s = main.sanctuary("essai_halte")
	check(s != null and s.region == "essai", "le sanctuaire de la Halte est posé dans la région d'essai")
	check(s != null and Regions.region_at(s.position) == "essai", "à l'intérieur de son secteur")

	print("Objectifs")
	game.flags["sanctuaire_essai_halte"] = true
	var count := {"prefix": "sanctuaire_", "exclude": ["sanctuaire_graine"], "region_only": true}
	check(objectives._count_flags(count, {"region": "ronce"}) == 0, "un sanctuaire d'essai ne compte pas pour les objectifs de Ronce")
	check(objectives._count_flags(count, {"region": "essai"}) == 1, "il compte pour ceux de la région d'essai")
	game.flags.erase("sanctuaire_essai_halte")

	print("Cœur")
	var heart = main.hearts.get("essai")
	var arena = main.arenas.get("essai")
	check(heart != null and arena != null, "un Cœur et une arène pour la région d'essai")
	check(main.heart == main.hearts["ronce"] and main.arena == main.arenas["ronce"], "main.heart et main.arena restent ceux de Ronce")
	check(heart.title == "Cœur d'essai" and heart.hold_time == 5.0 and heart.center == c, "réglages du Cœur lus dans le fichier")
	_place(heart.center + Vector2(heart.zone * 0.5, 0))
	check(await _until(func(): return heart.state == "siege"), "tenir la zone lance le siège")
	check(main.siege_heart() == heart, "main.siege_heart trouve le Cœur d'essai")
	heart.progress = heart.hold_time - 0.1
	check(await _until(func(): return heart.state == "purifie"), "Cœur purifié")
	check(game.flags.get("essai_coeur_purifie", false) == true, "drapeau essai_coeur_purifie")
	check(game.flags.get("points_essai_coeur", false) == true, "récompense du Cœur donnée (heart › reward)")
	check(main.hearts["ronce"].state == "fletri", "le Cœur de Ronce reste flétri")
	check(arena.state == "ouverte", "l'arène d'essai s'ouvre")
	await _steps(30)
	check(main.regions_purified.get("essai", false) and not main.regions_purified.get("ronce", false), "seule la région d'essai est purifiée pour le sol")

	print("Boss minimal")
	_place(arena.center + Vector2(0, 150))
	check(await _until(func(): return arena.state == "combat"), "entrer dans l'arène réveille le boss")
	var boss = arena.boss
	check(boss.get_script().resource_path == "res://tests/regions/boss_essai.gd" and boss.get_script().get_base_script().resource_path == "res://scripts/boss_base.gd", "le boss est celui du fichier de la région")
	check(main.in_boss_fight() and main.active_arena() == arena, "main.active_arena trouve l'arène d'essai")
	check(arena.bar.marks == [0.5], "la barre montre les phases du boss")
	check(await _until(func(): return boss._warn >= 0.0), "le boss annonce son onde")
	boss.take_damage(boss.max_hp * 0.6, false)
	check(await _until(func(): return boss.phase == 2), "sous la moitié de sa vie : phase 2")
	var points: int = game.points
	boss.take_damage(boss.max_hp + 1.0, false)
	check(boss.dead and game.flags.get("essai_boss_vaincu", false) == true, "boss vaincu : drapeau essai_boss_vaincu")
	check(game.points == points + 2, "2 points (boss › reward)")
	check(arena.state == "vaincue" and not main.in_boss_fight(), "l'arène refleurit")

	print("Fin")
	check(objectives.ending_region() == "essai", "la fin de la région d'essai est due")
	check(objectives.ending_texts("essai").get("title", "") == "La clairière respire", "avec ses textes")
	check(not Regions.all_purified(game.flags), "l'aventure n'est pas finie : Ronce reste à purifier")
	objectives.mark_ending_seen("essai")
	game.flags["ronce_boss_vaincu"] = true
	check(Regions.all_purified(game.flags), "les deux boss vaincus : toutes les régions sont purifiées")
	check(objectives.ending_region() == "ronce" and objectives.ending_texts("ronce").get("sub", "") == Content._load("objectives").get("adventure_ending", {}).get("sub", "?"), "la dernière fin est celle de l'aventure")

	Regions.set_extra_dirs([])
	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
