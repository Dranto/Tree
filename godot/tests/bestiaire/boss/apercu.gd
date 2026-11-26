## Aperçu de travail des boss redessinés (refonte des personnages, vague 2) : poses variées en grand
## (×1,6) et à la taille réelle 1080p à côté de l'Esprit masqué, sur le sol de la région, plus le
## sommeil et la forme guérie.
##   tools/godot.sh --xvfb -s res://tests/bestiaire/boss/apercu.gd -- sortie.png spore|seve [gris|protanopie|deuteranopie|tritanopie]
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")
const ARTS := {"spore": "res://scripts/creature_art/spore/_amanite_mere.gd", "seve": "res://scripts/creature_art/seve/_saule_exsangue.gd"}
const POSES := {
	"spore": [{"t": 0.4}, {"t": 1.1, "attack": "nuages", "k": 0.85}, {"t": 2.0, "phase": 2, "lift": 1.0, "attack": "spirale", "k": 0.7},
		{"t": 0.7, "phase": 3, "lift": 1.0, "attack": "onde", "k": 0.9, "swell": 1.09}, {"t": 0.2, "hit": 1.0, "phase": 2, "lift": 1.0},
		{"t": 1.5, "phase": 3, "die": 0.5, "ash": 0.6}, {"t": 0.9, "flip": true, "phase": 2, "lift": 1.0, "attack": "invocation", "k": 0.8}],
	"seve": [{"t": 0.4}, {"t": 1.1, "attack": "rideau", "k": 0.85, "aim": 1.0}, {"t": 2.0, "phase": 2, "attack": "siphon", "k": 0.6, "stage": "frappe"},
		{"t": 0.7, "phase": 3, "attack": "graines", "k": 0.9}, {"t": 0.2, "hit": 1.0, "phase": 2},
		{"t": 1.5, "phase": 3, "die": 0.5, "ash": 0.6}, {"t": 0.9, "flip": true, "phase": 2, "attack": "racines", "k": 0.8}],
}


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var id: String = args[1]
	var grey := args.size() > 2 and args[2] == "gris"
	# Mode daltonien (protanopie, deuteranopie, tritanopie) : palettes du bestiaire décalées.
	if args.size() > 2 and not grey:
		Art.set_access(args[2])
	var art = load(ARTS[id])
	var b := Bake.new(self)
	var poses: Array = POSES[id]
	var cell := 420
	var canvas := Image.create(cell * 5, cell * 2 + 300, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("3b3631"))
	var big: float = art.HEIGHT * 1.6
	for i in poses.size() + 2:
		var at := Vector2i((i % 5) * cell, (i / 5) * cell)
		var img := await b.bake(Vector2i(cell, cell), func(ci):
			C.draw_ground(ci, Rect2(0, 0, cell, cell), id, 3 + i)
			if i < poses.size():
				art.draw(ci, Vector2(cell * 0.5, cell * 0.86), big, poses[i])
			elif i == poses.size():
				art.draw_sleeper(ci, Vector2(cell * 0.5, cell * 0.8), big, 0.5, true)
			else:
				art.draw_healed(ci, Vector2(cell * 0.5, cell * 0.7), 2.0, 0.5))
		canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	# Taille réelle 1080p, avec l'Esprit masqué pour l'échelle.
	var real := await b.bake(Vector2i(cell * 3, 300), func(ci):
		C.draw_ground(ci, Rect2(0, 0, cell * 3, 300), id, 21)
		C.draw_after(ci, "heros", Vector2(260, 250), C.S1080, {"t": 0.4, "look": 0.1})
		art.draw(ci, Vector2(560, 250), art.HEIGHT * C.S1080, poses[0])
		art.draw(ci, Vector2(960, 250), art.HEIGHT * C.S1080, poses[3]))
	canvas.blend_rect(real, Rect2i(Vector2i.ZERO, real.get_size()), Vector2i(cell * 2, cell * 2 - 0))
	if grey:
		canvas.convert(Image.FORMAT_L8)
	canvas.save_png(out)
	quit(0)
