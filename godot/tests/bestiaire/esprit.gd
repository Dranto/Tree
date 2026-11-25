## Planche du héros retenu, « Esprit masqué » (piste A) : la tenue suit les branches prises, l'arme suit
## la forme d'attaque et chaque modification d'attaque y ajoute un ornement (cumulables).
## Lancer (depuis la racine du dépôt) :
##   tools/godot.sh --xvfb --resolution 2560x1440 -s res://tests/bestiaire/esprit.gd -- sortie.png
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")
const Esprit = preload("res://scripts/creature_art/heros/esprit.gd")

const W := 2560
const H := 1440
const TOP := 150
const CW := 421
const RH := 428
const BIG := 3.0 * C.S1080

const BR := {"ronce": "Ronce", "seve": "Sève", "racine": "Racine", "vent": "Vent", "spore": "Spore", "aube": "Aube"}

var b
var font: FontFile
var canvas: Image
var labels: Array = []
var att: Dictionary


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	att = JSON.parse_string(FileAccess.get_file_as_string("res://data/attack.json"))
	b = Bake.new(self)
	font = load("res://assets/fonts/CormorantGaramond-Herbier.ttf")
	canvas = Image.create(W, H, false, Image.FORMAT_RGBA8)
	canvas.fill(Art.c("papier_sombre"))
	_text("Porte-Graine : l'Esprit masqué", Vector2(24, 14), 44, Art.c("or"))
	_text("Le masque et le corps restent les mêmes du début à la fin. La tenue suit les branches prises (un build hybride mêle deux tenues, l'écharpe prend la couleur de la deuxième branche).\nL'arme suit la forme d'attaque, et chaque modification d'attaque prise y ajoute un ornement qui se cumule avec les autres. En grand : ×3 la taille à l'écran en 1080p.", Vector2(24, 66), 19, Art.c("texte_doux"))
	var rows := [
		["Une tenue par branche (branche maîtrisée, arme de la branche)", [
			[{"build": "ronce"}, []], [{"build": "seve"}, []], [{"build": "racine"}, []],
			[{"build": "vent"}, []], [{"build": "spore"}, []], [{"build": "aube"}, []]]],
		["Un parcours Ronce, palier par palier, puis deux builds hybrides", [
			[{"build": "ronce", "evol": 0.0}, []],
			[{"build": "ronce", "evol": 0.33, "forme": "echarde"}, ["fourche"]],
			[{"build": "ronce", "evol": 0.66, "forme": "echarde"}, ["fourche", "saignement"]],
			[{"build": "ronce", "evol": 1.0, "forme": "fouet"}, ["fourche", "saignement", "volee", "incandescence"]],
			[{"voie": {"ronce": 0.6, "vent": 0.4}, "forme": "lame"}, ["trainee", "eclat"]],
			[{"voie": {"seve": 0.55, "aube": 0.45}, "forme": "rayon"}, ["rosee", "refraction"]]]],
		["L'arme suit la forme d'attaque et ses modifications", [
			[{"voie": {"racine": 0.6, "spore": 0.4}, "forme": "massue"}, ["enracine", "renforcee", "secousse"]],
			[{"build": "spore", "evol": 0.8, "forme": "dard"}, ["poison", "bouffee", "portee"]],
			[{"build": "vent", "evol": 0.8, "forme": "bourrasque"}, ["elan", "ricochet"]],
			[{"build": "ronce", "evol": 0.8, "forme": "ronce_vive"}, ["sangsue", "aubier"]],
			[{"build": "seve", "evol": 0.8, "forme": "graine"}, ["volee", "repetition", "taille"]],
			[{"voie": {"aube": 0.6, "ronce": 0.4}, "forme": "spore_lobee"}, ["eblouit", "repousse"]]]],
	]
	for r in rows.size():
		var y := TOP + r * RH
		_text(rows[r][0], Vector2(24, y - 4), 24, Art.c("texte"))
		var cells: Array = rows[r][1]
		for i in cells.size():
			var o: Dictionary = cells[i][0].duplicate()
			o["mods"] = cells[i][1]
			o["t"] = 0.5 + i * 0.37 + r * 0.2
			o["look"] = 0.2
			if not o.has("evol"):
				o["evol"] = 1.0
			var x := 16 + i * CW
			var img: Image = await b.bake(Vector2i(CW - 8, RH - 42), func(ci):
				ci.draw_rect(Rect2(0, 0, CW - 8, RH - 42), Art.c("papier"))
				var dom := _dom(o)
				C.draw_ground(ci, Rect2(CW - 128, RH - 150, 112, 100), dom if dom in ["ronce", "racine", "vent"] else "ronce", 3 + i)
				Esprit.draw(ci, Vector2(CW * 0.4, RH - 80), Esprit.HEIGHT * BIG, o)
				Esprit.draw(ci, Vector2(CW - 72, RH - 66), Esprit.HEIGHT * C.S1080, o)
				C.Ink.flash = 0.0)
			canvas.blend_rect(img, Rect2i(0, 0, CW - 8, RH - 42), Vector2i(x, y + 30))
			_text(_caption(o), Vector2(x + 12, y + 36), 17, Art.c("or"))
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(canvas)
	root.add_child(tex)
	for l in labels:
		root.add_child(l)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit(0)


func _dom(o: Dictionary) -> String:
	if o.has("build"):
		return o["build"]
	var best := ""
	for k in o["voie"]:
		if best == "" or o["voie"][k] > o["voie"][best]:
			best = k
	return best


func _caption(o: Dictionary) -> String:
	var who := ""
	if o.has("build"):
		who = BR[o["build"]]
	else:
		var parts := []
		for k in o["voie"]:
			parts.append(BR[k])
		who = " + ".join(parts)
	var p: float = o["evol"]
	var stage := "départ" if p <= 0.0 else ("maîtrisée" if p >= 1.0 else "palier %d %%" % roundi(p * 100.0))
	var forme: String = o.get("forme", "graine" if p < 0.3 else Esprit.FORME_DE[_dom(o)])
	var s := "%s · %s\n%s" % [who, stage, att["forms"][forme]["name"]]
	var mods: Array = o["mods"]
	if not mods.is_empty():
		var names := []
		for m in mods:
			names.append(att["mods"][m]["name"])
		s += "\n+ " + ", ".join(names)
	return s


func _text(s: String, pos: Vector2, size: int, col: Color) -> void:
	var l := Label.new()
	l.text = s
	l.position = pos
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = col
	ls.outline_size = 4
	ls.outline_color = Art.c("papier")
	l.label_settings = ls
	labels.append(l)
