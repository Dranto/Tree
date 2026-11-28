## Captures des greffes et des autels, pour les joindre à une PR : un autel aperçu puis ravivé, la
## greffe tombée au sol, et la couronne de greffes de l'écran de l'arbre (en cours d'aventure, avec
## une greffe tenue au-dessus d'un emplacement libre, puis pleine en fin d'aventure).
## Lancer : tools/godot.sh --xvfb --resolution 1280x720 -s res://tests/grafts_captures.gd
## Les images vont dans godot/tests/visual/out/greffes_*.png (dossier ignoré par git).
extends SceneTree

const Content = preload("res://scripts/content.gd")
const OUT := "res://tests/visual/out"

var main
var game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(5)
	main.autotest = false
	main.autosave_enabled = false
	main.spawn_paused = true
	main.hud.glyphs.hide()

	# Un autel aperçu, encore couvert de cendre, puis ravivé : sa greffe tombe au sol.
	var altar = main.altars[1]
	_place(altar.position + Vector2(-150, 120))
	await _physics(30)
	await _shot("greffes_autel_cendre")
	_place(altar.position + Vector2(-190, 40))
	altar.activate()
	await _physics(50)
	await _shot("greffes_autel_ravive")

	# Couronne de greffes, en cours d'aventure : Ronce purifiée et son boss vaincu (quatre emplacements
	# ouverts, dont deux neufs qui luisent), trois greffes posées, une tenue au-dessus d'un emplacement libre.
	var Regions = load("res://scripts/regions.gd")
	var ids: Array = Content.grafts().keys()
	ids.sort()
	for g in ids.slice(0, 22):
		game.give_graft(g)
	game.flags[Regions.heart_flag("ronce")] = true
	game.flags[Regions.boss_flag("ronce")] = true
	var ui = main.tree_ui
	game.place_graft(0, ids[0])
	game.place_graft(1, ids[2])
	game.place_graft(2, ids[7])
	ui.toggle()
	await _frames(3)
	var gp = ui.grafts_panel
	gp.held = "greffe_ecorce"
	gp.refresh()
	gp.set_hover_slot(3)
	await _frames(20)
	await _shot("greffes_couronne_" + _res())
	gp.held = ""
	gp.set_hover_slot(-1)
	ui.toggle()
	await _frames(3)

	# En fin d'aventure : toutes les régions purifiées, la finale gagnée, la couronne pleine.
	for r in Regions.ids():
		game.flags[Regions.heart_flag(r)] = true
		game.flags[Regions.boss_flag(r)] = true
	game.flags["finale_vaincue"] = true
	for g in Content.grafts().keys():
		game.give_graft(g)
	for i in game.crown_size():
		game.place_graft(i, ids[i])
	game.flags["couronne_vue"] = game.crown_size()
	ui.toggle()
	await _frames(3)
	gp.set_hover_graft(ids[20])
	await _frames(3)
	await _shot("greffes_couronne_fin_" + _res())

	# New Game+ (jalon 14 G) : couronne du cycle 2 (16 emplacements et le bourgeon du cycle 3), puis
	# au plafond (20), avec les greffes de cycle posées et la fiche de l'une d'elles.
	var cycles = root.get_node("Cycles")
	var cg: Array = ids.filter(func(id): return game.graft_min_cycle(id) >= 2)
	var plain: Array = ids.filter(func(id): return game.graft_min_cycle(id) < 2)
	game.crown_kept = game.crown_size()
	if ui.visible:
		ui.toggle()
		await _frames(3)
	for n in [2, 6]:
		cycles.forced = n
		game._fit_crown()
		var order: Array = cg + plain
		for i in game.crown_size():
			game.place_graft(i, order[i])
		game.flags["couronne_vue"] = game.crown_size() - 1
		gp.refresh()
		ui.toggle()
		await _frames(3)
		gp.set_hover_graft(cg[0] if n == 2 else cg[cg.size() - 1])
		await _frames(3)
		await _shot("greffes_couronne_cycle%d_%s" % [n, _res()])
		if n == 2:
			gp.set_hover_graft("")
			gp.set_hover_slot(game.crown_max())
			await _frames(3)
			await _shot("greffes_couronne_cycle2_bourgeon_" + _res())
			gp.set_hover_slot(-1)
		ui.toggle()
		await _frames(3)

	# Les greffes de cycle au sol, en rang devant le héros (leurs dessins à l'encre de l'herbier).
	cycles.forced = 2
	for g in cg:
		game.graft_inventory.erase(g)
		if game.crown.has(g):
			game.crown[game.crown.find(g)] = ""
	_place(main.player.position + Vector2(0, 160))
	var at: Vector2 = main.player.position + Vector2(-70.0 * (cg.size() - 1) / 2.0, -240)
	for i in cg.size():
		main.drop_graft(at + Vector2(70.0 * i, 0), cg[i])
	await _physics(40)
	await _shot("greffes_cycle_sol_" + _res())
	quit(0)


func _res() -> String:
	var sz := DisplayServer.window_get_size()
	return "%dx%d" % [sz.x, sz.y]


func _place(pos: Vector2) -> void:
	main.player.position = pos
	main.player.hp = 1.0e6
	main.player.reset_physics_interpolation()


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _physics(k: int) -> void:
	for i in k:
		await physics_frame


func _shot(shot_name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])
	print("CAPTURE ", shot_name)
