## Pics des morts en série (jalon Éclat B) : 40 Flétris tués d'un coup devant le héros, puis temps
## moyen et pire image pendant les 1,5 s qui suivent. Une fois en « cendre » (coup sans élément,
## comme avant), une fois par élément. Rien n'est comparé : comparer les lignes entre elles.
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --fixed-fps 60 -s res://tests/morts_pics.gd
extends SceneTree

var main


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	root.get_node("Settings").hitstop_scale = 0.0   # pas d'arrêt sur image : on mesure le dessin
	for i in 10:
		await process_frame
	main.player.invuln = 1.0e6
	main.player.position = Vector2(0, 320)
	main.player.set_physics_process(false)   # pas d'attaque : seule la mort en série compte
	for round in 2:
		for branch in ["", "ronce", "aube", "racine", "spore", "vent", "seve", ""]:
			for e in main.enemies.duplicate():
				if is_instance_valid(e):
					e.queue_free()
			main.enemies.clear()
			for i in 30:
				await process_frame
			var es: Array = []
			for i in 40:
				es.append(main.spawn_enemy_kind("fletri", Vector2(80 + (i % 8) * 34, 200 + int(i / 8) * 34), 1.0))
			for i in 10:
				await process_frame
			es = es.filter(func(e): return is_instance_valid(e) and not e.dead)
			for e in es:
				e.set_physics_process(false)
			var t0 := Time.get_ticks_usec()
			var last := t0
			var worst := 0
			var n := es.size()
			for e in es:
				main.player_hit_enemy(e, 1.0e5, false, branch)
			for f in 90:
				await process_frame
				var now := Time.get_ticks_usec()
				worst = maxi(worst, now - last)
				last = now
			if round == 1:
				print("PICS %-7s %d morts : moyenne %.2f ms, pire image %.2f ms" % [branch if branch != "" else "cendre", n, (last - t0) / 90000.0, worst / 1000.0])
	quit(0)
