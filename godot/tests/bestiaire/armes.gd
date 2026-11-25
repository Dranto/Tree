## Armes de l'Esprit masqué : une planche (préparation et coup de chaque arme) ou les images d'un GIF
## (toutes les attaques en boucle). Lancer (depuis la racine du dépôt) :
##   tools/godot.sh --xvfb --resolution 2560x1440 -s res://tests/bestiaire/armes.gd -- planche.png
##   tools/godot.sh --xvfb --resolution 1280x720 -s res://tests/bestiaire/armes.gd -- --gif dossier/
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")
const Esprit = preload("res://scripts/creature_art/heros/esprit.gd")

const ARMES := [
	["graine", "aucun", "Fronde"], ["echarde", "ronce", "Échardes d'os"], ["fouet", "ronce", "Fouet de ronce"],
	["ronce_vive", "ronce", "Arc de ronce"], ["spore_lobee", "spore", "Encensoir-champignon"], ["dard", "spore", "Sarbacane"],
	["lame", "vent", "Faucilles de plume"], ["bourrasque", "vent", "Éventail de plumes"], ["perle", "seve", "Calice-lotus"],
	["rayon", "aube", "Prisme d'aube"], ["massue", "racine", "Massue de racines"],
]

var b
var font: FontFile
var att: Dictionary


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _pose(i: int, a: float, t: float) -> Dictionary:
	var bd: String = ARMES[i][1]
	return {"t": t, "look": 0.0, "build": bd, "evol": 0.85, "forme": ARMES[i][0], "a": a, "mods": []}


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	att = JSON.parse_string(FileAccess.get_file_as_string("res://data/attack.json"))
	b = Bake.new(self)
	font = load("res://assets/fonts/CormorantGaramond-Herbier.ttf")
	if args.has("--gif"):
		await _gif(args[args.find("--gif") + 1])
	else:
		await _planche(args[0])
	quit(0)


func _planche(out: String) -> void:
	var W := 2560
	var canvas := Image.create(W, 1440, false, Image.FORMAT_RGBA8)
	canvas.fill(Art.c("papier_sombre"))
	var labels := []
	labels.append(_label("Esprit masqué : une vraie arme par forme d'attaque", Vector2(24, 14), 44, Art.c("or")))
	labels.append(_label("Chaque forme d'attaque a son arme et son geste. À gauche de chaque case : la préparation ; à droite : le coup, avec le projectile en vol.\nLes modifications d'attaque ajoutent ensuite leurs ornements sur l'arme (voir la planche de l'Esprit masqué). En grand : ×2,8 la taille à l'écran en 1080p.", Vector2(24, 66), 19, Art.c("texte_doux")))
	var CW := 636
	var RH := 424
	var S := 2.8 * C.S1080
	for i in ARMES.size():
		var x := 16 + (i % 4) * CW
		var y := 150 + (i / 4) * RH
		var img: Image = await b.bake(Vector2i(CW - 10, RH - 10), func(ci):
			ci.draw_rect(Rect2(0, 0, CW - 10, RH - 10), Art.c("papier"))
			Esprit.draw(ci, Vector2(100, RH - 60), Esprit.HEIGHT * S * 0.75, _pose(i, 0.42, 0.3))
			Esprit.draw(ci, Vector2(270, RH - 46), Esprit.HEIGHT * S, _pose(i, 0.62, 0.6))
			C.Ink.flash = 0.0)
		canvas.blend_rect(img, Rect2i(0, 0, CW - 10, RH - 10), Vector2i(x, y))
		labels.append(_label("%s · %s" % [ARMES[i][2], att["forms"][ARMES[i][0]]["name"]], Vector2(x + 14, y + 8), 22, Art.c("or")))
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(canvas)
	root.add_child(tex)
	for l in labels:
		root.add_child(l)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)


func _gif(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var CWg := 320
	var CH := 240
	var S := 1.45 * C.S1080
	var N := 48
	for f in N:
		var a := float(f) / 36.0 if f < 36 else -1.0
		var t := f / 24.0
		var canvas := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
		canvas.fill(Art.c("papier_sombre"))
		for i in ARMES.size():
			var img: Image = await b.bake(Vector2i(CWg - 6, CH - 6), func(ci):
				ci.draw_rect(Rect2(0, 0, CWg - 6, CH - 6), Art.c("papier"))
				Esprit.draw(ci, Vector2(80, CH - 34), Esprit.HEIGHT * S, _pose(i, a, t))
				C.Ink.flash = 0.0)
			canvas.blend_rect(img, Rect2i(0, 0, CWg - 6, CH - 6), Vector2i((i % 4) * CWg + 3, (i / 4) * CH + 3))
		canvas.save_png("%s/%03d.png" % [dir, f])


func _label(s: String, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.position = pos
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = col
	l.label_settings = ls
	return l
