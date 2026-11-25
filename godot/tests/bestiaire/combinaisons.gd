## Planche de contrôle : chaque arme (colonnes) × chaque tenue de branche (lignes), au moment du coup,
## puis une ligne avec toutes les modifications d'attaque cumulées. Le test complet est
## tests/heros_test.gd. Lancer (depuis la racine du dépôt) :
##   tools/godot.sh --xvfb --resolution 2560x1440 -s res://tests/bestiaire/combinaisons.gd -- sortie.png
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")
const Esprit = preload("res://scripts/creature_art/heros/esprit.gd")
const Arme = preload("res://scripts/creature_art/heros/arme.gd")

const BR := {"ronce": "Ronce", "seve": "Sève", "racine": "Racine", "vent": "Vent", "spore": "Spore", "aube": "Aube"}


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var att: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/attack.json"))
	var b := Bake.new(self)
	var font: FontFile = load("res://assets/fonts/CormorantGaramond-Herbier.ttf")
	var canvas := Image.create(2560, 1440, false, Image.FORMAT_RGBA8)
	canvas.fill(Art.c("papier_sombre"))
	var labels := []
	labels.append(_label(font, "Esprit masqué : toutes les armes × toutes les tenues", Vector2(24, 10), 38, Art.c("or")))
	labels.append(_label(font, "Au moment du coup, branche maîtrisée. Dernière ligne : les 23 modifications d'attaque cumulées sur chaque arme. Vérifié aussi par tests/heros_test.gd (hybrides, paliers, chaque modification seule).", Vector2(24, 58), 18, Art.c("texte_doux")))
	var X0 := 110
	var CW := 222
	var RH := 186
	var Y0 := 120
	var rows: Array = Esprit.BRANCHES.duplicate()
	rows.append("tout")
	for c in Arme.FORMES.size():
		labels.append(_label(font, att["forms"][Arme.FORMES[c]]["name"], Vector2(X0 + c * CW + 8, Y0 - 26), 17, Art.c("texte")))
	for r in rows.size():
		var br: String = rows[r] if rows[r] != "tout" else "ronce"
		labels.append(_label(font, BR[rows[r]] if rows[r] != "tout" else "+ 23 modifs", Vector2(12, Y0 + r * RH + RH * 0.4), 19, Art.c("or")))
		var img: Image = await b.bake(Vector2i(Arme.FORMES.size() * CW, RH - 6), func(ci):
			for c in Arme.FORMES.size():
				ci.draw_rect(Rect2(c * CW, 0, CW - 6, RH - 6), Art.c("papier"))
				var o := {"build": br, "evol": 1.0, "a": 0.6, "forme": Arme.FORMES[c], "t": 0.4 + c * 0.2, "look": 0.0, "mods": Arme.ORNEMENTS if rows[r] == "tout" else []}
				Esprit.draw(ci, Vector2(c * CW + 56, RH - 22), Esprit.HEIGHT * 1.55 * C.S1080, o)
			C.Ink.flash = 0.0, 2)
		canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(X0, Y0 + r * RH))
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(canvas)
	root.add_child(tex)
	for l in labels:
		root.add_child(l)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit(0)


func _label(font: FontFile, s: String, pos: Vector2, size: int, col: Color) -> Label:
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
