## Images d'un GIF de la faune et des formes guéries d'une région : tout le monde marche, vole ou saute sur le
## sol ravivé, à la taille ×2. tools/godot.sh --xvfb -s res://tests/vie/gif.gd -- <dossier> <région>
## (puis ffmpeg -framerate 12 -i dossier/%03d.png …)
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const Vie = preload("res://scripts/world_life_vie.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const W := 900
const H := 260
const N := 48


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(a[0])
	var reg: String = a[1]
	var list := Vie.forms(reg)
	var b := Bake.new(self)
	var r := reg if Art.MONDE.get(reg, {}).has("ravive") else "ronce"
	var soil: Color = Art.MONDE[r]["ravive"]["sol"]
	for f in range(N):
		var img: Image = await b.bake(Vector2i(W, H), func(ci):
			Ink.no_shadow = false
			ci.draw_rect(Rect2(0, 0, W, H), soil)
			for k in list.size():
				var e: Dictionary = list[k]
				var poses: Dictionary = e["poses"]
				var pose := "marche" if poses.has("marche") else ("vol" if poses.has("vol") else "saut")
				var n := int(poses[pose])
				var u := fposmod(f / float(N) * 2.0 + k * 0.17, 1.0)
				var i := int(f / 3.0 + k) % n
				var o := Vie.pose_of(e["id"], pose, i, n)
				var x := 40.0 + (W - 80.0) * (k + 0.5) / list.size() + sin(f / float(N) * TAU + k) * 22.0
				e["script"].draw(ci, Vector2(x, H - 50), e["h"] * 2.2, o), 2)
		img.save_png("%s/%03d.png" % [a[0], f])
	quit(0)
