## Capsules de la page Steam (jalon 12 H), dans la direction « Herbier » du jeu : l'illustration
## prise en vrai jeu (vitrine.gd, 3840 x 2160, sans interface) recadrée pour chaque format, un voile
## de papier brun du côté du titre, le nom du jeu en Cormorant ivoire, un filet d'or et deux feuilles.
## Le nom vient de Loc.game_name() (project.godot) : relancer tools/steam-art.sh suffit à le changer.
##
## Lancer par tools/steam-art.sh (scène steam_art.tscn, avec les autoloads du jeu). Arguments (après « -- ») :
##   --illustration=FICHIER   illustration 3840 x 2160 ; les portraits succes_<ID>.png sont lus à côté
##   --out=DOSSIER            dossier de sortie (une capsule par fichier PNG)
##   --lang=fr|en             langue du nom du jeu
extends Node

const UiTheme = preload("res://scripts/ui_theme.gd")
const IconDrawing = preload("res://tools/gen_icon.gd").Drawing

const IVORY := Color("f3ead2")
const SHADE := Color("140f0a")

## Formats demandés par Steam (Steamworks › Illustrations de la boutique et de la bibliothèque).
##   focus : où tombe le héros de l'illustration (part de la capsule) ; zoom : agrandissement de
##   l'illustration au-delà du simple remplissage ; title : zone du titre (parts de la capsule),
##   vide pour les formats sans texte (Steam refuse le texte sur le héros de bibliothèque).
const CAPSULES := {
	"capsule_entete_920x430": {"size": Vector2i(920, 430), "focus": Vector2(0.72, 0.55), "zoom": 1.6, "title": Rect2(0.05, 0.16, 0.5, 0.68), "veil": "left"},
	"capsule_petite_462x174": {"size": Vector2i(462, 174), "focus": Vector2(0.82, 0.5), "zoom": 1.7, "title": Rect2(0.04, 0.1, 0.6, 0.8), "veil": "left"},
	"capsule_principale_1232x706": {"size": Vector2i(1232, 706), "focus": Vector2(0.68, 0.55), "zoom": 1.4, "title": Rect2(0.05, 0.2, 0.46, 0.6), "veil": "left"},
	"capsule_verticale_748x896": {"size": Vector2i(748, 896), "focus": Vector2(0.55, 0.66), "zoom": 1.5, "title": Rect2(0.13, 0.07, 0.74, 0.26), "veil": "top"},
	"bibliotheque_600x900": {"size": Vector2i(600, 900), "focus": Vector2(0.55, 0.66), "zoom": 1.6, "title": Rect2(0.13, 0.07, 0.74, 0.26), "veil": "top"},
	"bibliotheque_heros_3840x1240": {"size": Vector2i(3840, 1240), "focus": Vector2(0.62, 0.5), "zoom": 1.0, "title": Rect2(), "veil": "none"},
	"fond_page_1438x810": {"size": Vector2i(1438, 810), "focus": Vector2(0.5, 0.5), "zoom": 1.0, "title": Rect2(), "veil": "page"},
}


class Capsule extends Node2D:
	var art: Texture2D
	var size_px := Vector2(920, 430)
	var spec: Dictionary = {}
	var mode := "capsule"   # capsule, logo, icone
	var numeral := ""   # médaille d'un succès de cycle : « II », « III » sur un cartouche d'or
	var _vig: ImageTexture

	func _draw() -> void:
		match mode:
			"logo":
				_title(Rect2(Vector2(size_px.x * 0.06, size_px.y * 0.18), size_px * Vector2(0.88, 0.64)), true)
			"medaille":
				_medal()
			_:
				_capsule()

	func _capsule() -> void:
		# L'illustration couvre la capsule, recadrée pour que le héros (centre de l'illustration)
		# tombe sur « focus ».
		var src := Vector2(art.get_size())
		var k := maxf(size_px.x / src.x, size_px.y / src.y) * float(spec["zoom"])
		var shown := size_px / k
		var focus: Vector2 = spec["focus"]
		var origin := src * 0.5 - shown * focus
		origin = origin.clamp(Vector2.ZERO, src - shown)
		draw_texture_rect_region(art, Rect2(Vector2.ZERO, size_px), Rect2(origin, shown))
		var w := size_px.x
		var h := size_px.y
		var clear := Color(SHADE, 0.0)
		match str(spec["veil"]):
			"left":
				# Voile de papier brun sur la terre flétrie, à gauche, qui s'efface avant le héros.
				_hgrad(0.0, w * 0.32, Color(SHADE, 0.82), Color(SHADE, 0.62))
				_hgrad(w * 0.32, w * 0.62, Color(SHADE, 0.62), clear)
			"top":
				_vgrad(0.0, h * 0.3, Color(SHADE, 0.85), Color(SHADE, 0.6))
				_vgrad(h * 0.3, h * 0.55, Color(SHADE, 0.6), clear)
			"page":
				# Fond de page : l'illustration très assombrie, pour que le texte de Steam reste lisible.
				draw_rect(Rect2(Vector2.ZERO, size_px), Color(SHADE, 0.72))
		_vignette()
		var title: Rect2 = spec["title"]
		if title.has_area():
			var f := clampf(h / 430.0, 0.45, 1.6)
			var m := 14.0 * f
			UiTheme.draw_frame(self, Rect2(Vector2(m, m), size_px - Vector2(m, m) * 2.0), f)
			_title(Rect2(title.position * size_px, title.size * size_px), false)

	## Médaille d'un succès : le portrait du boss dans un cercle, cerclé d'or, sur papier brun.
	func _medal() -> void:
		var c := size_px * 0.5
		var r := size_px.x * 0.5
		draw_rect(Rect2(Vector2.ZERO, size_px), UiTheme.PAPER)
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for k in 64:
			var d := Vector2.from_angle(TAU * k / 64.0)
			pts.append(c + d * r * 0.86)
			uvs.append(Vector2(0.5, 0.44) + d * 0.38)   # le boss remplit la médaille
		draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, art)
		draw_arc(c, r * 0.86, 0, TAU, 64, UiTheme.GOLD, r * 0.07, true)
		draw_arc(c, r * 0.96, 0, TAU, 64, Color(UiTheme.GOLD, 0.5), r * 0.025, true)
		for k in 4:
			UiTheme.draw_diamond(self, c + Vector2.from_angle(PI * 0.25 + PI * 0.5 * k) * r * 0.95, r * 0.05, UiTheme.GOLD)
		if numeral != "":
			_cycle_plate(c, r)

	## Cartouche du cycle (succès CYCLE_N) : un bandeau d'or au bas de la médaille, le chiffre romain
	## du cycle en encre (lisible à 64 px), un losange de chaque côté. Sans texte à traduire.
	func _cycle_plate(c: Vector2, r: float) -> void:
		var font := UiTheme.display(700, 0)
		var fs := int(r * 0.5)
		var sz := font.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var h := r * 0.36
		var w := maxf(sz.x + r * 0.34, r * 0.62)
		var top := c.y + r * 0.5
		var plate := Rect2(c.x - w * 0.5, top, w, h)
		# Bandeau aux bouts en pointe (comme les rubans de l'Herbier), filet sombre autour.
		var tip := h * 0.4
		var poly := PackedVector2Array([plate.position + Vector2(-tip, h * 0.5), plate.position,
			plate.position + Vector2(w, 0), plate.position + Vector2(w + tip, h * 0.5),
			plate.position + Vector2(w, h), plate.position + Vector2(0, h)])
		draw_colored_polygon(poly, UiTheme.GOLD)
		var ring := poly.duplicate()
		ring.append(poly[0])
		draw_polyline(ring, SHADE, r * 0.025, true)
		var base := Vector2(c.x - sz.x * 0.5, top + (h + font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
		draw_string(font, base, numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, SHADE)

	func _hgrad(x0: float, x1: float, a: Color, b: Color) -> void:
		var h := size_px.y
		draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, h), Vector2(x0, h)]), PackedColorArray([a, b, b, a]))

	func _vgrad(y0: float, y1: float, a: Color, b: Color) -> void:
		var w := size_px.x
		draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y1), Vector2(0, y1)]), PackedColorArray([a, a, b, b]))

	## Coins assombris (vignette ronde, comme l'écran titre), calculée dans une petite image.
	func _vignette() -> void:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				var a := smoothstep(0.55, 1.45, d) * 0.75
				img.set_pixel(x, y, Color(SHADE, a))
		# Gardée en membre : une texture libérée avant le rendu s'affiche blanche.
		_vig = ImageTexture.create_from_image(img)
		draw_texture_rect(_vig, Rect2(Vector2.ZERO, size_px), false)

	## Le nom du jeu, centré dans la zone, au plus grand qui tienne ; un filet d'or dessous, avec un
	## losange et deux feuilles. « halo » : contour sombre (logo posé par Steam sur l'illustration).
	func _title(zone: Rect2, halo: bool) -> void:
		var game := Loc.game_name()
		var font := UiTheme.display(600, 2)
		var fs := 400
		var sz := font.get_string_size(game, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var ratio := minf(zone.size.x / sz.x, zone.size.y * 0.62 / font.get_height(fs))
		fs = maxi(8, int(fs * ratio))
		sz = font.get_string_size(game, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var total := font.get_height(fs) + fs * 0.32
		var top := zone.position.y + (zone.size.y - total) * 0.5
		var x := zone.position.x + (zone.size.x - sz.x) * 0.5
		var base := top + font.get_ascent(fs)
		var line_y := top + font.get_height(fs) + fs * 0.06
		var half := sz.x * 0.36
		var cx := zone.position.x + zone.size.x * 0.5
		var lw := maxf(1.0, fs / 70.0)
		if halo:
			draw_string_outline(font, Vector2(x, base), game, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.09), Color(SHADE, 0.9))
			draw_line(Vector2(cx - half, line_y), Vector2(cx + half, line_y), Color(SHADE, 0.8), lw * 5.0, true)
		else:
			draw_string_outline(font, Vector2(x, base), game, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.05), Color(SHADE, 0.55))
		draw_string(font, Vector2(x, base), game, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, IVORY)
		# Filet d'or : deux traits, un losange au milieu, une feuille à chaque bout.
		var gold := UiTheme.GOLD
		var gap := fs * 0.1
		draw_line(Vector2(cx - half, line_y), Vector2(cx - gap, line_y), gold, lw, true)
		draw_line(Vector2(cx + gap, line_y), Vector2(cx + half, line_y), gold, lw, true)
		UiTheme.draw_diamond(self, Vector2(cx, line_y), fs * 0.045, gold)
		for d in [-1.0, 1.0]:
			var tip := Vector2(cx + d * half, line_y)
			UiTheme.draw_leaf(self, tip, (0.0 if d > 0 else PI) - d * 0.45, fs * 0.16, fs * 0.05, gold, Color(gold, 0.55), lw)
			UiTheme.draw_leaf(self, tip, (0.0 if d > 0 else PI) + d * 0.35, fs * 0.12, fs * 0.04, gold, Color(0, 0, 0, 0), lw)


func _render(node: Node2D, size: Vector2i, transparent: bool) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = transparent
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(node)
	get_tree().root.add_child(vp)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


func _ready() -> void:
	var illus := ""
	var out := ""
	var lang := "fr"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--illustration="):
			illus = a.get_slice("=", 1)
		elif a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--lang="):
			lang = a.get_slice("=", 1)
	Loc.apply(lang)
	await get_tree().process_frame   # la racine finit d'ajouter ses enfants
	DirAccess.make_dir_recursive_absolute(out)
	var art := ImageTexture.create_from_image(Image.load_from_file(illus))
	for id in CAPSULES:
		var spec: Dictionary = CAPSULES[id]
		var c := Capsule.new()
		c.art = art
		c.spec = spec
		c.size_px = Vector2(spec["size"])
		var img := await _render(c, spec["size"], false)
		img.convert(Image.FORMAT_RGB8)
		img.save_png(out.path_join(id + ".png"))
		print("CAPSULE ", id)
	# Icônes des succès (64 x 64) : débloqué, et grisé (verrouillé), depuis les portraits des boss.
	var portraits := DirAccess.get_files_at(illus.get_base_dir())
	DirAccess.make_dir_recursive_absolute(out.path_join("succes"))
	for f in portraits:
		if not (f.begins_with("succes_") and f.ends_with(".png")):
			continue
		var id := f.trim_prefix("succes_").trim_suffix(".png")
		var m := Capsule.new()
		m.mode = "medaille"
		m.size_px = Vector2(256, 256)
		if id.begins_with("CYCLE_"):
			m.numeral = "I".repeat(int(id.trim_prefix("CYCLE_")))
		m.art = ImageTexture.create_from_image(Image.load_from_file(illus.get_base_dir().path_join(f)))
		var med := await _render(m, Vector2i(256, 256), false)
		med.convert(Image.FORMAT_RGB8)
		med.resize(64, 64, Image.INTERPOLATE_LANCZOS)
		med.save_png(out.path_join("succes/%s.png" % id))
		for y in 64:
			for x in 64:
				var px := med.get_pixel(x, y)
				var g := px.get_luminance() * 0.8
				med.set_pixel(x, y, Color(g, g * 0.96, g * 0.9))
		med.save_png(out.path_join("succes/%s_gris.png" % id))
		print("CAPSULE succès ", id)
	# Logo seul, transparent (Steam le pose sur le héros de bibliothèque).
	var logo := Capsule.new()
	logo.mode = "logo"
	logo.size_px = Vector2(1280, 720)
	(await _render(logo, Vector2i(1280, 720), true)).save_png(out.path_join("logo_1280x720.png"))
	print("CAPSULE logo")
	# Icône de la communauté : l'icône du jeu (tools/gen_icon.gd), redessinée à 184 px.
	var icon := IconDrawing.new()
	var big := await _render(icon, Vector2i(512, 512), true)
	big.resize(184, 184, Image.INTERPOLATE_LANCZOS)
	# Steam la veut opaque (JPG accepté) : posée sur le papier de l'Herbier.
	var flat := Image.create(184, 184, false, Image.FORMAT_RGBA8)
	flat.fill(UiTheme.PAPER)
	flat.blend_rect(big, Rect2i(0, 0, 184, 184), Vector2i.ZERO)
	flat.convert(Image.FORMAT_RGB8)
	big = flat
	big.save_png(out.path_join("icone_communaute_184x184.png"))
	print("CAPSULE icone")
	get_tree().quit()
