## Contrôles de lisibilité de l'écran de l'Arbre de vie, à la résolution de la fenêtre :
## à l'ouverture, en vue moyenne et en vue proche, aucun libellé hors de l'écran ni sur un autre,
## les six noms de branches visibles à l'ouverture, et une infobulle toujours dans l'écran.
## Lancer : tools/godot.sh --xvfb --resolution 1600x900 -s res://tests/tree_ui_test.gd [-- --shots=DOSSIER]
## Avec --shots, enregistre une capture de chaque vue dans DOSSIER.
extends SceneTree

var failures := 0
var shots := ""
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


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots = arg.get_slice("=", 1)
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(5)
	var game = root.get_node("Game")
	game.add_xp(300.0)
	var ui = main.tree_ui
	var res := "%dx%d" % [root.size.x, root.size.y]
	print("Arbre de vie à %s (zone d'interface %s)" % [res, ui.size])
	ui.toggle()
	await _frames(3)
	check(not main.hud.is_visible_in_tree(), "le HUD est masqué quand l'arbre est ouvert")
	await _view(ui, "ouverture", res, 6)
	var zooms := {"moyen": 0.5, "proche": 1.1}
	for z in zooms:
		ui.zoom = zooms[z]
		ui.cam = game.tree.nodes[0]["pos"] + Vector2(260, 120)
		await _view(ui, z, res, 0)
	ui.zoom = 0.1
	check(ui.zoom >= ui.fit_zoom() * 0.8, "le zoom ne descend pas sous la vue d'ensemble")
	ui.cam = Vector2(100000, 0)
	check(ui.cam.length() <= ui._extent() + 1.0, "on ne peut pas s'éloigner de l'arbre")
	# Infobulles aux quatre coins et sur un nœud clé au texte long.
	ui.fit_view()
	for m in [Vector2(5, 70), Vector2(ui.size.x - 5, 70), Vector2(5, ui.size.y - 5), ui.size - Vector2(5, 5)]:
		for id in [1, _keystone(game)]:
			ui.hover = id
			ui.mouse = m
			var lines: Array = ui.tooltip_lines(game.tree.nodes[id], ui._states[id])
			var r: Rect2 = ui.tooltip_rect(lines)
			check(Rect2(Vector2.ZERO, ui.size).encloses(r), "infobulle du nœud %d dans l'écran (souris en %s)" % [id, m])
	ui.hover = _keystone(game)
	ui.mouse = ui.size - Vector2(5, 5)
	await _shot("infobulle_coin", res)
	ui.toggle()
	await _frames(2)
	check(main.hud.is_visible_in_tree(), "le HUD réapparaît à la fermeture")
	print("RÉSULTAT ", "ok" if failures == 0 else "%d échec(s)" % failures)
	quit(1 if failures > 0 else 0)


func _keystone(game) -> int:
	for n in game.tree.nodes:
		if n["type"] == "keystone" and n["key"] == "pas_du_vent":
			return n["id"]
	return 1


func _view(ui, view_name: String, res: String, branches: int) -> void:
	await _frames(3)
	var rects: Array = ui.label_rects
	var area: Rect2 = ui._view_area()
	var inside := true
	var overlap := 0
	for i in rects.size():
		if not area.encloses(rects[i]):
			inside = false
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				overlap += 1
	print("  vue %s : zoom %.3f, %d libellés" % [view_name, ui.zoom, rects.size()])
	check(rects.size() > 0, "vue %s : des libellés sont affichés" % view_name)
	check(inside, "vue %s : aucun libellé hors de l'écran" % view_name)
	check(overlap == 0, "vue %s : aucun libellé sur un autre (%d chevauchements)" % [view_name, overlap])
	if branches > 0:
		var names := 0
		for l in ui.layout_labels():
			if l[2] == ui.FONT_BRANCH:
				names += 1
		check(names == branches, "vue %s : les %d noms de branches sont visibles (%d)" % [view_name, branches, names])
	await _shot(view_name, res)


func _shot(shot_name: String, res: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png("%s/arbre_%s_%s.png" % [shots, res, shot_name])
