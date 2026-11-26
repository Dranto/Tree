## Planche rapprochée des repères du Roncier et du Marais (refonte du monde, vague 2 R) : grand arbre,
## ruine, chapeau géant, flétris puis ravivés, dessinés par world_art/decor.gd, avec le héros pour
## l'échelle. Rien du jeu n'est lancé.
##   tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/paysages/reperes_zoom.gd -- --out=reperes.png
extends SceneTree

const Decor = preload("res://scripts/world_art/decor.gd")
const Esprit = preload("res://scripts/creature_art/heros/esprit.gd")

const CELL := Vector2(380, 380)
const ITEMS := [["ronce", "grand_arbre", 1.0], ["ronce", "ruine", 1.15], ["spore", "chapeau_geant", 1.05]]


class Etat extends RefCounted:
	var region := "ronce"
	var etat := "fletri"

	func region_at(_p: Vector2) -> String:
		return region

	func decor_etat_at(_p: Vector2) -> String:
		return etat


class Sheet extends Node2D:
	func _draw() -> void:
		for row in 2:
			for col in ITEMS.size():
				var it: Array = ITEMS[col]
				var o := Vector2(col * CELL.x, row * CELL.y)
				var m := Etat.new()
				m.region = it[0]
				m.etat = "ravive" if row == 1 else "fletri"
				var bg: Color = Art.mc(it[0], m.etat, "sol")
				draw_rect(Rect2(o, CELL), bg)
				var c := o + Vector2(CELL.x * 0.55, CELL.y * 0.9)
				Decor.draw(self, {"kind": it[1], "at": c, "size": it[2], "seed": hash([it[0], it[1], 0]), "flip": false}, m)
				Esprit.draw(self, c + Vector2(-140, 0), Esprit.HEIGHT, {"t": 1.0, "look": 0.0, "build": "aucun"})


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var vp := SubViewport.new()
	vp.size = Vector2i(int(CELL.x * ITEMS.size()), int(CELL.y * 2))
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(Sheet.new())
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var out := "/tmp/reperes.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	vp.get_texture().get_image().save_png(out)
	print("REPERES planche : ", out)
	quit(0)
