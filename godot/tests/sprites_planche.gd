## Planche du prototype des sprites cuits (refonte des personnages, vague 0 T) : chaque sorte de
## Flétri, dessin direct d'aujourd'hui (à gauche) et image cuite (à droite), à la taille du jeu.
## Rien n'est comparé : la planche sert aux captures zoomées avant/après.
## Lancer : tools/godot.sh --xvfb --audio-driver Dummy --resolution 1920x1080 -s res://tests/sprites_planche.gd -- --out=planche.png [--view=1.2] [--sprites=4] [--pose=walk|idle|windup]
##   --view : agrandissement du jeu (1,2 en 1920x1080, 0,8 sur le Deck en 1280x800).
extends SceneTree

const DrawBatch = preload("res://scripts/draw_batch.gd")
const FletriArt = preload("res://scripts/fletri_art.gd")
const Sprites = preload("res://scripts/sprite_bake.gd")
const Cache = preload("res://scripts/silhouette_cache.gd")


class Cell extends Node2D:
	var kind_id := ""
	var r := 10.0
	var baked := false
	var o := {}
	var t := 1.2

	func _draw() -> void:
		if baked:
			Sprites.draw(self, kind_id, r, 1.0, 0.0, t, o)
		else:
			Cache.draw(self, kind_id, r, r, Vector2.RIGHT, t, o)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var out := "user://sprites_planche.png"
	var view := 1.2
	var pose := "walk"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--view="):
			view = a.get_slice("=", 1).to_float()
		elif a.begins_with("--pose="):
			pose = a.get_slice("=", 1)
	Sprites.configure()
	var kinds := Sprites.all_kinds()
	var t0 := Time.get_ticks_usec()
	await Sprites.bake(root, kinds)
	print("PLANCHE cuisson de %d sortes ×%.0f (marche %d, ss %d) : %.0f ms (calcul %.0f ms, lecture et mipmaps %.0f ms), %.1f Mo" % [kinds.size(), Sprites.scale, Sprites.walk_frames, Sprites.ss, (Time.get_ticks_usec() - t0) / 1000.0, Sprites.build_usec / 1000.0, Sprites.finish_usec / 1000.0, Sprites.total_bytes() / 1048576.0])
	for a in Sprites.atlases.values():
		print("PLANCHE %s : %d images (%d uniques), case %dx%d, atlas %dx%d, %.2f Mo" % [a.kind_id, a.total, a.unique, a.cell.x, a.cell.y, a.tex.get_width(), a.tex.get_height(), a.bytes / 1048576.0])
	var size := Vector2(root.size)
	var bg := ColorRect.new()
	bg.color = Art.c("sol_mort")
	bg.size = size
	root.add_child(bg)
	var o := {"walk": 0.9, "moving": 1.0}
	if pose == "idle":
		o = {}
	elif pose == "windup":
		o = {"state": "windup", "k": 0.7}
	var cols := 6
	var w := size.x / cols
	var h := size.y / ceili(kinds.size() / float(cols))
	for i in kinds.size():
		for side in 2:
			var c := Cell.new()
			c.kind_id = kinds[i][0]
			c.r = kinds[i][1]
			c.baked = side == 1
			c.o = o
			c.scale = Vector2(view, view)
			c.position = Vector2((i % cols) * w + w * (0.3 + 0.4 * side), (i / cols) * h + h * 0.5)
			root.add_child(c)
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("PLANCHE écrite : ", out)
	quit()
