## Planche de direction « Bestiaire d'herbier » (refonte des personnages, vague 0) : pour chaque personnage,
## avant / après en grand et à la taille réelle sur le sol de sa région, silhouettes noires, niveaux de gris.
## Lancer (depuis la racine du dépôt) :
##   tools/godot.sh --xvfb --resolution 2560x1440 -s res://tests/bestiaire/planche.gd -- sortie.png
extends SceneTree

const Bake = preload("res://tests/bestiaire/bake.gd")
const C = preload("res://tests/bestiaire/commun.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")

const W := 2560
const H := 1440
const TOP := 178
const ROW := 314
## Colonnes : [x, largeur].
const COLS := {
	"nom": [24, 236], "avant": [270, 300], "avant_reel": [580, 250],
	"apres": [870, 420], "apres_reel": [1300, 330], "silhouette": [1650, 300], "gris": [1966, 570],
}
## Agrandissement des colonnes « en grand » : ×3 la taille à l'écran en 1080p.
const BIG := 3.0 * C.S1080

var b
var font: FontFile
var canvas: Image
var labels: Array = []


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	b = Bake.new(self)
	font = load("res://assets/fonts/CormorantGaramond-Herbier.ttf")
	canvas = Image.create(W, H, false, Image.FORMAT_RGBA8)
	canvas.fill(Art.c("papier_sombre"))
	_text("Bestiaire d'herbier : planche de direction (vague 0)", Vector2(24, 14), 44, Art.c("or"))
	_text("Même personnage, même pose : à gauche le dessin d'aujourd'hui (develop), à droite la direction proposée (trois quarts, encre commune, couleur de la région, braise = ennemi, vert sève = vivant).\n« En grand » : ×3 la taille à l'écran en 1080p. « Taille réelle » : pixels d'un écran 1920×1080, sur le sol mort de la région, le héros à côté pour l'échelle.", Vector2(24, 64), 19, Art.c("texte_doux"))
	var heads := {"avant": "Avant, en grand", "avant_reel": "Avant, taille réelle", "apres": "Après, en grand", "apres_reel": "Après, taille réelle", "silhouette": "Silhouettes (avant · après)", "gris": "Niveaux de gris (avant · après)"}
	for k in heads:
		_text(heads[k], Vector2(COLS[k][0], TOP - 34), 24, Art.c("texte"))
	for i in C.CAST.size():
		await _row(i, C.CAST[i], TOP + i * ROW)
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(canvas)
	root.add_child(tex)
	for l in labels:
		root.add_child(l)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit(0)


func _text(s: String, pos: Vector2, size: int, col: Color, width := 0) -> void:
	var l := Label.new()
	l.text = s
	l.position = pos
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = col
	l.label_settings = ls
	# Noms de la planche en français, tels quels (pas de traduction automatique).
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if width > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
		l.size = Vector2(width, 0)
	labels.append(l)


func _blit(img: Image, x: int, y: int) -> void:
	canvas.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, y))


func _row(i: int, c: Dictionary, y: int) -> void:
	var id: String = c["id"]
	var hero := id == "heros"
	var region: String = c["region"]
	var panel := Image.create(W - 32, ROW - 10, false, Image.FORMAT_RGBA8)
	panel.fill(Art.c("papier"))
	_blit(panel, 16, y)
	# Nom, région, rôle, tailles.
	var art = C.art_of(id)
	var before_px := roundi(2.4 * float(c["r"]))
	var after_px := roundi(art.HEIGHT * C.S1080)
	_text(c["nom"], Vector2(28, y + 10), 28, Art.c("texte"), 230)
	var sub := "héros · selon le build\n(Ronce, Sève)" if hero else "%s · %s" % [region.capitalize(), c["role"]]
	_text(sub, Vector2(28, y + 104), 21, Art.c("or"), 230)
	_text("À l'écran (1080p) :\n~%d px aujourd'hui\n~%d px de haut après\nCollision inchangée (r %d)" % [before_px, after_px, int(c["r"])], Vector2(28, y + 168), 19, Art.c("texte_doux"), 230)
	var cy := y + 6
	var gc: Array = C.ground_colors(region)
	# Avant, en grand (rendu brut, comme en jeu).
	var r: float = c["r"]
	var face := Vector2(1, 0.3).normalized()
	var pose_b := {"t": 0.5} if not hero else {"t": 0.5}
	var big_b: Image = await b.bake(Vector2i(300, 300), func(ci): C.draw_before(ci, id, r, Vector2(150, 150), BIG, pose_b, face), 1)
	_blit(big_b, COLS["avant"][0], cy)
	# Avant, taille réelle sur le sol (le héros d'aujourd'hui à côté).
	var real_b: Image = await b.bake(Vector2i(250, 300), func(ci):
		C.draw_ground(ci, Rect2(0, 0, 250, 300), region, 11 + i)
		if not hero:
			C.draw_before(ci, "heros", 14.0, Vector2(62, 160), C.S1080, {"t": 0.5}, Vector2(1, 0.1).normalized())
			C.draw_before(ci, id, r, Vector2(160, 150), C.S1080, pose_b, Vector2(-1, 0.3).normalized())
		else:
			C.draw_before(ci, id, r, Vector2(125, 150), C.S1080, pose_b, face), 1)
	_blit(real_b, COLS["avant_reel"][0], cy)
	# Après, en grand (lissé).
	var builds := ["ronce", "seve"] if hero else [""]
	var after_big := []
	for k in builds.size():
		var bw := 420 / builds.size()
		var o := {"t": 0.4, "look": 0.25, "build": builds[k]}
		var img: Image = await b.bake(Vector2i(bw, 300), func(ci): C.draw_after(ci, id, Vector2(bw * 0.5 - (8 if hero else 0), 238 if hero else 268), BIG * (0.85 if hero else 1.0), o))
		_blit(img, COLS["apres"][0] + k * bw, cy)
		after_big.append(img)
		if hero:
			_text("build Ronce" if builds[k] == "ronce" else "build Sève", Vector2(COLS["apres"][0] + k * bw + 60, cy + 270), 20, Art.c("texte_doux"))
	# Après, taille réelle sur le sol.
	var real_a: Image = await b.bake(Vector2i(330, 300), func(ci):
		C.draw_ground(ci, Rect2(0, 0, 330, 300), region, 11 + i)
		if hero:
			C.draw_after(ci, "heros", Vector2(110, 170), C.S1080, {"t": 0.4, "look": 0.2, "build": "ronce"})
			C.draw_after(ci, "heros", Vector2(230, 170), C.S1080, {"t": 1.1, "look": 0.2, "build": "seve"})
		else:
			C.draw_after(ci, "heros", Vector2(70, 170), C.S1080, {"t": 0.4, "look": 0.1})
			C.draw_after(ci, id, Vector2(210, 175), C.S1080, {"t": 0.4, "look": PI - 0.25}))
	_blit(real_a, COLS["apres_reel"][0], cy)
	# Silhouettes : avant et après, à ×1,5 la taille à l'écran, en noir sur papier clair.
	var sil_bg := Image.create(300, 300, false, Image.FORMAT_RGBA8)
	sil_bg.fill(Color("e8dcc0"))
	_blit(sil_bg, COLS["silhouette"][0], cy)
	var s15 := 1.5 * C.S1080 * 1.4
	var sb: Image = await b.bake(Vector2i(150, 300), func(ci): C.draw_before(ci, id, r, Vector2(75, 150), s15, {"t": 0.5}, face), 1)
	var sa: Image = await b.bake(Vector2i(150, 300), func(ci): C.draw_after(ci, id, Vector2(75, 230), s15, {"t": 0.4, "look": 0.25, "build": builds[0]}))
	_blit(_silhouette(sb), COLS["silhouette"][0], cy)
	_blit(_silhouette(sa), COLS["silhouette"][0] + 150, cy)
	# Niveaux de gris : la lecture des valeurs (avant, après), sur le sol de la région.
	var gb: Image = await b.bake(Vector2i(285, 300), func(ci):
		ci.draw_rect(Rect2(0, 0, 285, 300), gc[1])
		C.draw_before(ci, id, r, Vector2(142, 150), BIG * 0.85, {"t": 0.5}, face), 1)
	var ga: Image = await b.bake(Vector2i(285, 300), func(ci):
		ci.draw_rect(Rect2(0, 0, 285, 300), gc[1])
		C.draw_after(ci, id, Vector2(142 - (8 if hero else 0), 262), BIG * 0.85, {"t": 0.4, "look": 0.25, "build": builds[0]}))
	_blit(_gray(gb), COLS["gris"][0], cy)
	_blit(_gray(ga), COLS["gris"][0] + 285, cy)


## Silhouette noire : tout pixel assez opaque devient noir (ombres et halos, transparents, disparaissent).
static func _silhouette(img: Image) -> Image:
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for yy in img.get_height():
		for xx in img.get_width():
			var a := img.get_pixel(xx, yy).a
			if a > 0.55:
				out.set_pixel(xx, yy, Color(0.05, 0.04, 0.04, 1.0))
	return out


static func _gray(img: Image) -> Image:
	var out := img.duplicate()
	for yy in img.get_height():
		for xx in img.get_width():
			var c := img.get_pixel(xx, yy)
			var l := c.get_luminance()
			out.set_pixel(xx, yy, Color(l, l, l, c.a))
	return out
