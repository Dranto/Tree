## Planche rapprochée des Falaises (région d'Aube, refonte du monde vague 2 P5) : le décor de la région
## (arbre blanchi, bouquet d'éclats, grappe de cristaux, bloc de falaise, éclats au sol, aiguille et arche
## des repères), flétri puis ravivé, et le Cœur (géode fermée, à mi-siège, ouverte), avec le héros pour
## l'échelle, dessinés en direct à ×2 sur les tons du sol. Rien du jeu n'est lancé.
##   tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/paysages/falaises_zoom.gd -- --out=falaises.png
## Avec -s, Game n'est pas visible à la compilation : les scripts du décor sont chargés à l'exécution.
extends SceneTree

const SS := 2
const W := 1700.0
const ROW := 300.0

var F
var Art_aube
var Esprit


class FakeHeart:
	var region := "aube"
	var t := 1.0
	var state := "dormant"
	var k := 0.0

	func ratio() -> float:
		return k


class Sheet extends Node2D:
	var art
	var esprit
	var t := 1.0

	func _draw() -> void:
		for row in 2:
			var etat := "ravive" if row == 1 else "fletri"
			draw_rect(Rect2(0, row * ROW, W, ROW), Art.mc("aube", etat, "sol"))
		draw_rect(Rect2(0, 2 * ROW, W, ROW * 1.2), Art.mc("aube", "fletri", "sol"))
		draw_rect(Rect2(W * 2.0 / 3.0, 2 * ROW, W / 3.0, ROW * 1.2), Art.mc("aube", "ravive", "sol"))
		for col in 3:
			var c := Vector2(W * (col + 0.5) / 3.0, 2 * ROW + ROW * 0.95)
			var pur := col == 2
			var h = FakeHeart.new()
			h.t = t
			h.state = "purifie" if pur else ("siege" if col == 1 else "dormant")
			h.k = 0.5 if col == 1 else (1.0 if pur else 0.0)
			draw_set_transform(c)
			art.heart_body(self, "aube", 1.0, pur, h.k)
			art.heart_live(self, h, 1.0)
			draw_set_transform(Vector2.ZERO)
			esprit.draw(self, c + Vector2(-170, 40), esprit.HEIGHT, {"t": t, "look": 0.0, "build": "aucun"})
		for row in 2:
			esprit.draw(self, Vector2(60, row * ROW + ROW * 0.85), esprit.HEIGHT, {"t": t, "look": 0.0, "build": "aucun"})


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	F = load("res://scripts/decor_falaise.gd")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var size := Vector2i(int(W), int(ROW * 3.2))
	var vp := SubViewport.new()
	vp.size = size * SS
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var sh := Sheet.new()
	sh.art = load("res://scripts/region_art/aube.gd")
	sh.esprit = load("res://scripts/creature_art/heros/esprit.gd")
	sh.scale = Vector2(SS, SS)
	vp.add_child(sh)
	# [classe, taille ou rayon, x]
	var items := [["Bleached", 3.0, 190], ["Bleached", 1.5, 360], ["Cluster", 3.2, 470], ["Cluster", 6.0, 590],
		["Crystals", 22.0, 720], ["Cliff", 34.0, 860], ["Shards", 1.2, 980], ["Spire", 14.0, 1150], ["Arch", 11.0, 1450]]
	for row in 2:
		for it in items:
			var t = F.get_script_constant_map()[it[0]].new()
			if t.get("radius") != null:
				t.radius = it[1]
			else:
				t.size = it[1]
			t.tree_seed = 7 + int(it[2])
			t.alive = row == 1
			t.position = Vector2(it[2], row * ROW + ROW * 0.88)
			sh.add_child(t)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var out := "/tmp/falaises.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	img.save_png(out)
	print("FALAISES planche : ", out)
	quit(0)
