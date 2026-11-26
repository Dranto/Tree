## Planche rapprochée des lieux (refonte du monde, vague 1 C) : chaque Cœur (Roncier, Marais, Cœur
## commun d'une région de la vague 2) flétri, à mi-siège et purifié, puis le sanctuaire éteint, à
## mi-chemin et ravivé, et l'autel éteint et ravivé, dessinés par world_art/lieux.gd à ×2, avec le héros
## pour l'échelle. Rien du jeu n'est lancé.
##   tools/godot.sh --xvfb --audio-driver Dummy -s res://tests/paysages/lieux_zoom.gd -- --out=lieux.png
extends SceneTree

const Lieux = preload("res://scripts/world_art/lieux.gd")
const Esprit = preload("res://scripts/creature_art/heros/esprit.gd")

const SS := 2
const CELL := Vector2(300, 260)


class Sheet extends Node2D:
	var t := 1.0

	func _draw() -> void:
		var bg := [Color("2a2022"), Color("2a2430"), Color("263028")]
		var regs := ["ronce", "spore", "vent"]
		for row in 3:
			var reg: String = regs[row]
			for col in 3:
				var o := Vector2(col * CELL.x, row * CELL.y)
				var pur := col == 2
				var k := 0.5 if col == 1 else (1.0 if pur else 0.0)
				draw_rect(Rect2(o, CELL), bg[row].lightened(0.12) if pur else bg[row])
				var c := o + Vector2(CELL.x * 0.5, CELL.y * 0.78)
				Lieux.heart_body(self, reg, c, 1.0, pur, k)
				Lieux.heart_live(self, reg, c, 1.0, pur, k, t, col == 1)
				Esprit.draw(self, c + Vector2(-120, 30), Esprit.HEIGHT, {"t": t, "look": 0.0, "build": "aucun"})
		# Sanctuaire (Roncier, et la Graine) et autel.
		for col in 3:
			var o := Vector2(900, col * CELL.y)
			var lit := col == 2
			var kk := 0.5 if col == 1 else (1.0 if lit else 0.0)
			draw_rect(Rect2(o, Vector2(320, CELL.y)), Color("2a2022").lightened(0.12) if lit else Color("2a2022"))
			var c := o + Vector2(160, 140)
			Lieux.sanct_dalle(self, "ronce", c, 80.0, lit)
			var items := []
			for i in Lieux.STONES:
				var a := TAU * i / Lieux.STONES - PI / 2.0
				var p := c + Vector2.from_angle(a) * Lieux.SANCT_R
				var on := clampf((kk * Lieux.STONES - i) * 1.5, 0.0, 1.0)
				items.append([p.y, i, p, on])
			items.append([c.y + 4.0, -1, c + Vector2(0, 4), kk])
			items.append([c.y + 2.0, -2, c + Vector2(6, 2), 0.0])
			items.sort_custom(func(x, y): return x[0] < y[0])
			for it in items:
				var i: int = it[1]
				var p: Vector2 = it[2]
				if i == -1:
					Lieux.sanct_vasque(self, "ronce", p, lit)
					Lieux.sanct_flame(self, p, lit, kk, t)
				elif i == -2:
					Esprit.draw(self, p, Esprit.HEIGHT, {"t": t, "look": 0.0, "build": "aucun"})
				else:
					var lean := cos(TAU * i / Lieux.STONES - PI / 2.0) * 0.08
					var on: float = it[3]
					Lieux.sanct_stone(self, "ronce", p, i, on >= 0.5, on >= 0.5, lean)
					Lieux.sanct_rune(self, p, i, on, t, lean)
		for col in 2:
			var o := Vector2(1220, col * CELL.y)
			draw_rect(Rect2(o, Vector2(260, CELL.y)), Color("2a2022").lightened(0.12 * col))
			var c := o + Vector2(130, 170)
			Lieux.altar_table(self, "ronce", c, col == 1)
			Lieux.altar_glyph(self, c, float(col), t)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var size := Vector2i(1480, 780)
	var vp := SubViewport.new()
	vp.size = size * SS
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var sh := Sheet.new()
	sh.scale = Vector2(SS, SS)
	vp.add_child(sh)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var out := "/tmp/lieux.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	img.save_png(out)
	print("LIEUX planche : ", out)
	quit(0)
