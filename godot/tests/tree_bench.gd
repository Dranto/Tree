## Banc de performance de l'écran de l'Arbre de vie : ouvre l'arbre et mesure le temps par image
## dans trois situations (arbre immobile, souris qui survole les nœuds, déplacement et zoom).
## Lancer : tools/godot.sh --xvfb -s res://tests/tree_bench.gd
## Affiche, pour chaque situation, le temps moyen et le pire temps par image (en ms).
extends SceneTree


const FRAMES := 240

var main


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	print("BANC début")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(10)
	var game = root.get_node("Game")
	game.add_xp(2000.0)  # des points à placer : les nœuds disponibles pulsent
	main.tree_ui.toggle()
	await _frames(30)
	var ui = main.tree_ui
	print("BANC arbre ouvert")
	await _measure("immobile", func(_i): pass)
	var nodes: Array = game.tree.nodes
	await _measure("survol", func(i):
		var n: Dictionary = nodes[(i * 7) % nodes.size()]
		var p: Vector2 = (n["pos"] - ui.cam) * ui.zoom + ui.size / 2.0
		var ev := InputEventMouseMotion.new()
		ev.position = p
		ui._gui_input(ev))
	await _measure("deplacement", func(i):
		var ev := InputEventMouseButton.new()
		ev.pressed = true
		ev.position = ui.size / 2.0 + Vector2(sin(i * 0.1), cos(i * 0.1)) * 200.0
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if (i / 20) % 2 == 0 else MOUSE_BUTTON_WHEEL_DOWN
		ui._gui_input(ev))
	quit(0)


func _measure(label: String, step: Callable) -> void:
	var times := PackedFloat64Array()
	var last := Time.get_ticks_usec()
	for i in FRAMES:
		step.call(i)
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	var total := 0.0
	var worst := 0.0
	for t in times.slice(5):
		total += t
		worst = maxf(worst, t)
	print("BANC arbre %-12s moyenne %6.2f ms   pire %6.2f ms" % [label, total / (times.size() - 5), worst])
