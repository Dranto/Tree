## Capture d'une impact frame avec les sprites cuits (refonte des personnages, tâche M) : un groupe de
## Flétris autour du héros, l'un vient d'être frappé (éclair du coup reçu), un autre vient de mourir.
## --avant : l'image cuite passe par la silhouette d'avant (silhouette.gdshader), comme dans le
## prototype #125 ; sans : par silhouette_sprite.gdshader et le Flétri mort est redessiné depuis son image.
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --resolution 1600x900 -s res://tests/impact_sprites_planche.gd -- --sprites=3 --out=x.png [--avant] [--style=region]
extends SceneTree

const Sprites = preload("res://scripts/sprite_bake.gd")


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var out := "user://impact.png"
	var before := false
	var style := "encre"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a == "--avant":
			before = true
		elif a.begins_with("--style="):
			style = a.get_slice("=", 1)
	var Remains = load("res://scripts/enemy_remains.gd")
	var main = load("res://scenes/main.tscn").instantiate()
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
	for i in 30:
		if Sprites.atlases.has("menhir"):
			break
		await _frames(1)
	var at: Vector2 = main.player.position
	var es := []
	var spots := [["menhir", Vector2(110, -20)], ["tireur", Vector2(-90, 40)], ["scarabee", Vector2(60, 80)], ["fletri", Vector2(-40, -90)], ["chargeur", Vector2(150, 70)]]
	for s in spots:
		var e = main.spawn_enemy_kind(s[0], at + s[1], 1.0)
		e.set_physics_process(false)
		es.append(e)
	await _frames(20)
	var m = main.moments
	if before:
		m._mat_sprite = m._mat
	# Un Flétri mort juste avant (on_elite_kill le redessine depuis son image).
	var dead = es[3]
	var ghost := {"kind": dead.kind_id, "pos": dead.position, "r": float(dead.radius), "face": dead.face, "sprite": {} if before else Remains.enemy_frame(dead)}
	dead.queue_free()
	es[0].take_damage(1.0, false)
	es[1].take_damage(1.0, false)
	await _frames(1)
	m.impact_frame(0.6, [es[0], ghost], style, "vent")
	m.frozen = true
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit(0)
