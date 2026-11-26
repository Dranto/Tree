## Planche des boss refaits (refonte des personnages, vague 2 B3) : chaque pose du nouveau dessin, en grand,
## sur fond neutre, une image par boss et par mode de couleur (vision normale, puis un mode daltonien).
## tools/godot.sh --xvfb -s res://tests/bestiaire/boss/poses.gd -- DOSSIER [deuteranopie]
## Images : DOSSIER/<boss>_<mode>.png (une rangée de poses, légendes à ajouter par la planche).
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")

const BOSSES := {
	"harfang": {"art": "vent/_harfang", "poses": [
		{"t": 1.0, "flap": 0.3},
		{"t": 1.0, "flap": 0.9, "k": 0.9, "bristle": 1.0},
		{"t": 1.0, "flap": 1.4, "k": 1.0, "cri": 0.4},
		{"t": 1.0, "fold": 1.0, "dive": 1.0, "k": 1.0, "alt": 20.0},
		{"t": 1.0, "flap": -0.45, "fold": 0.55, "tired": 1.0, "alt": 8.0, "rage": 0.5},
		{"t": 1.0, "flap": 1.25, "k": 1.0, "bristle": 1.0, "rage": 1.0},
		{"t": 1.0, "flap": -0.2, "fold": 0.8, "dk": 0.5, "tired": 0.5, "alt": 8.0, "rage": 1.0},
	]},
	"phalene": {"art": "aube/_phalene", "poses": [
		{"t": 1.0, "beat": 0.2},
		{"t": 1.0, "beat": 0.35, "open": 1.25, "glow": 1.0, "k": 1.0},
		{"t": 1.0, "beat": 0.7, "glow": 0.6, "rage": 0.5},
		{"t": 1.0, "beat": 1.0, "glow": 0.5, "k": 1.0, "rage": 1.0},
		{"t": 1.0, "beat": -0.4, "rage": 1.0},
		{"t": 1.0, "beat": -0.3, "open": 0.7, "dk": 0.5, "crack": 0.7, "rage": 1.0},
		{"t": 1.0, "beat": -0.1, "open": 0.6, "sleep": 1.0, "alt": 10.0},
	]},
}


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var modes := ["aucun"]
	if args.size() > 1:
		modes.append(args[1])
	var b := Bake.new(self)
	var cell := 620
	for mode in modes:
		Art.set_access(mode)
		for id in BOSSES:
			var art = load("res://scripts/creature_art/%s.gd" % BOSSES[id]["art"])
			var poses: Array = BOSSES[id]["poses"]
			var canvas := Image.create(cell * poses.size(), cell, false, Image.FORMAT_RGBA8)
			canvas.fill(Color(0, 0, 0, 0))
			for i in poses.size():
				var o: Dictionary = poses[i]
				var img := await b.bake(Vector2i(cell, cell), func(ci): art.draw(ci, Vector2(cell / 2.0, cell - 40.0), art.HEIGHT * 1.45, o))
				canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * cell, 0))
				Ink.flash = 0.0
				Ink.ash = 0.0
			canvas.save_png("%s/%s_%s.png" % [out, id, mode])
	Art.set_access("aucun")
	quit(0)
