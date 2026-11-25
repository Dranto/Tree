## Thème commun de l'interface, direction « Herbier » (jalon 10) : une planche botanique gravée.
## Papier brun chaud, encre ivoire, filets et vrilles d'or, une seule police (Cormorant Garamond,
## licence OFL, dans assets/fonts) pour tous les textes du jeu. Tout est dessiné par le code.
## Police agrandie de 20 % (tools/font-herbier.py) : son œil est petit.
## Les couleurs viennent de la charte graphique (art.gd, docs/charte-graphique.md).
extends RefCounted

## Couleurs de la charte (art.gd).
const INK: Color = Art.PALETTE["texte"]
## Encre secondaire : une variable (et non une constante) pour suivre le contraste renforcé.
static var SOFT: Color = Art.PALETTE["texte_doux"]
const LEAF: Color = Art.PALETTE["accent"]
const GOLD: Color = Art.PALETTE["or"]
const RED: Color = Art.PALETTE["encre_rouge"]
const PAPER: Color = Art.PALETTE["papier"]
const PAPER_DARK: Color = Art.PALETTE["papier_sombre"]
const PANEL_BG: Color = Art.PALETTE["panneau"]
## Filet d'or des cadres et des séparateurs.
static var FILET := Color(0.851, 0.71, 0.4, 0.45)
## Halo des textes posés sur le jeu (épaisseur en pixels, couleur) : voir draw_text().
const OUTLINE := 5
const HALO := Color(0.055, 0.04, 0.025, 0.88)
## Taille minimale des textes du HUD (pixels de la vue de base 1600 x 900 ; 12 px à 1280 x 720).
const MIN_HUD_SIZE := 15
const FONT_SERIF := "res://assets/fonts/CormorantGaramond-Herbier.ttf"
## Graisses : texte courant en demi-gras (plus lisible en petit), « gras » franc, titres plus fins.
const WEIGHT_REGULAR := 600
const WEIGHT_BOLD := 700

## Contraste renforcé (Settings.high_contrast) : encre secondaire presque pleine, filets marqués.
const SOFT_NORMAL: Color = Art.PALETTE["texte_doux"]
const SOFT_CONTRASTE := Color("d9cfb6")
const FILET_NORMAL := Color(0.851, 0.71, 0.4, 0.45)
const FILET_CONTRASTE := Color(0.851, 0.71, 0.4, 0.85)
static var contraste := false

static var _fonts := {}
static var _installed := false


## Police du jeu, pour tous les textes : Cormorant Garamond (variable). bold = gras.
static func font(bold := false) -> Font:
	return serif(WEIGHT_BOLD if bold else WEIGHT_REGULAR)


## Cormorant Garamond à la graisse voulue (300 à 700), espacement des lettres en pixels.
static func serif(weight := WEIGHT_REGULAR, spacing := 0) -> Font:
	var key := "%d|%d" % [weight, spacing]
	if not _fonts.has(key):
		var v := FontVariation.new()
		v.base_font = load(FONT_SERIF)
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		# Chiffres alignés (« 100 / 100 ») plutôt que les chiffres elzéviriens de Cormorant.
		v.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("lnum"): 1}
		v.spacing_glyph = spacing
		_fonts[key] = v
	return _fonts[key]


## Police de titre : plus fine et plus espacée.
static func display(weight := 500, spacing := 0) -> Font:
	return serif(weight, spacing)


## La police du jeu devient celle du moteur par défaut : tout texte sans thème (dessins des
## acteurs, de l'arbre, des effets) l'utilise aussi. Appelé au démarrage (game.gd).
static func install() -> void:
	if _installed:
		return
	_installed = true
	ThemeDB.fallback_font = font()


## Texte avec son halo sombre (draw_string_outline puis draw_string) : à utiliser pour tout
## texte dessiné sur le jeu, dont le fond change.
static func draw_text(ci: CanvasItem, f: Font, pos: Vector2, s: String, align: int, width: float, fs: int, col: Color, outline := OUTLINE) -> void:
	ci.draw_string_outline(f, pos, s, align, width, fs, outline, Color(HALO, HALO.a * col.a))
	ci.draw_string(f, pos, s, align, width, fs, col)


## Boîte simple (boutons, cases) : coins presque droits, filet fin.
static func box(bg: Color, border: Color, width := 1, radius := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(mini(radius, 3))
	sb.anti_aliasing = true
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


## Cadre d'herbier : papier, double filet d'or et ornements aux coins (losanges, ou vrilles et
## feuilles si ornate). Sert aux panneaux de tout le jeu (thème « PanelContainer »).
static func cadre(ornate := false, bg := PANEL_BG, line := GOLD, margin := 22.0) -> StyleBox:
	var c := Cadre.new()
	c.bg = bg
	c.line = line
	c.ornate = ornate
	c.content_margin_left = margin
	c.content_margin_right = margin
	c.content_margin_top = margin * 0.8
	c.content_margin_bottom = margin * 0.8
	return c


class Cadre extends StyleBox:
	var bg := Color(0, 0, 0, 0.9)
	var line := Color.WHITE
	var ornate := false

	func _draw(ci: RID, r: Rect2) -> void:
		var rs := RenderingServer
		# Ombre portée douce.
		for k in 4:
			rs.canvas_item_add_rect(ci, r.grow(3.0 + k * 4.0), Color(0, 0, 0, 0.07))
		rs.canvas_item_add_rect(ci, r, bg)
		_rect(ci, r.grow(-1.5), Color(line, 0.55), 1.0)
		_rect(ci, r.grow(-6.0), Color(line, 0.28), 1.0)
		var s := 1.0 if ornate else 0.0
		for corner in [[r.position, 1.0, 1.0], [Vector2(r.end.x, r.position.y), -1.0, 1.0], [Vector2(r.position.x, r.end.y), 1.0, -1.0], [r.end, -1.0, -1.0]]:
			var p: Vector2 = corner[0]
			var sx: float = corner[1]
			var sy: float = corner[2]
			if ornate and minf(r.size.x, r.size.y) > 160.0:
				var sc := clampf(minf(r.size.x, r.size.y) / 700.0, 0.45, 0.75)
				for part in load("res://scripts/ui_theme.gd").flourish_parts(p + Vector2(4.0 * sx, 4.0 * sy), sx, sy, sc):
					_part(ci, part, line)
			else:
				var d := p + Vector2(6.0 * sx, 6.0 * sy)
				rs.canvas_item_add_polygon(ci, load("res://scripts/ui_theme.gd").diamond_points(d, 3.0), PackedColorArray([Color(line, 0.85)]))
		var _u := s

	func _rect(ci: RID, r: Rect2, col: Color, w: float) -> void:
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
		RenderingServer.canvas_item_add_polyline(ci, pts, PackedColorArray([col]), w, true)

	func _part(ci: RID, part: Array, col: Color) -> void:
		var pts: PackedVector2Array = part[0]
		if part[1] > 0.0:
			RenderingServer.canvas_item_add_polygon(ci, pts, PackedColorArray([Color(col, part[1])]))
		var closed := pts.duplicate()
		if part[2]:
			closed.append(pts[0])
		RenderingServer.canvas_item_add_polyline(ci, closed, PackedColorArray([Color(col, 0.75)]), 1.1, true)


# ---------------------------------------------------------------------------------------------
# Géométrie de l'herbier (partagée par les cadres, les menus et l'écran de mort).
# ---------------------------------------------------------------------------------------------

## Contour d'une feuille en amande : base c, direction ang, longueur et demi-largeur.
static func leaf_points(c: Vector2, ang: float, length: float, width: float) -> PackedVector2Array:
	var d := Vector2.from_angle(ang)
	var n := d.orthogonal()
	var pts := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		pts.append(c + d * length * t + n * sin(t * PI) * width * (1.0 - 0.3 * t))
	for i in range(11, 0, -1):
		var t := float(i) / 12.0
		pts.append(c + d * length * t - n * sin(t * PI) * width * (1.0 - 0.3 * t))
	return pts


static func diamond_points(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])


static func bez(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var u := 1.0 - t
		pts.append(u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3)
	return pts


## Vrille d'angle : une spirale, deux traits et deux feuilles. Chaque partie : [points, opacité
## du remplissage (0 = aucun), fermée].
static func flourish_parts(corner: Vector2, sx: float, sy: float, scale := 1.0) -> Array:
	var parts := []
	var spiral := PackedVector2Array()
	for i in 60:
		var t := float(i) / 59.0
		var ang := t * 4.2 + PI
		var r := (1.0 - t) * 26.0 * scale + 3.0
		var p := Vector2(46, 46) * scale + Vector2(cos(ang), sin(ang)) * r
		spiral.append(corner + Vector2(p.x * sx, p.y * sy))
	parts.append([spiral, 0.0, false])
	parts.append([PackedVector2Array([corner + Vector2(6 * sx, 46 * scale * sy), corner + Vector2(20 * scale * sx, 46 * scale * sy)]), 0.0, false])
	parts.append([PackedVector2Array([corner + Vector2(46 * scale * sx, 6 * sy), corner + Vector2(46 * scale * sx, 20 * scale * sy)]), 0.0, false])
	parts.append([leaf_points(corner + Vector2(70 * scale * sx, 20 * scale * sy), atan2(-0.4 * sy, sx), 16 * scale, 5 * scale), 0.18, true])
	parts.append([leaf_points(corner + Vector2(20 * scale * sx, 70 * scale * sy), atan2(sy, -0.4 * sx), 16 * scale, 5 * scale), 0.18, true])
	return parts


## Feuille dessinée au trait (avec sa nervure), éventuellement remplie.
static func draw_leaf(ci: CanvasItem, c: Vector2, ang: float, length: float, width: float, outline: Color, fill := Color(0, 0, 0, 0), lw := 1.0) -> void:
	var pts := leaf_points(c, ang, length, width)
	if fill.a > 0.0:
		ci.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	ci.draw_polyline(pts, outline, lw, true)
	ci.draw_line(c, c + Vector2.from_angle(ang) * length * 0.85, outline, lw * 0.7, true)


static func draw_diamond(ci: CanvasItem, c: Vector2, r: float, col: Color, filled := true, lw := 1.0) -> void:
	var pts := diamond_points(c, r)
	if filled:
		ci.draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, col, lw, true)


## Séparateur : deux filets, un losange au centre et aux extrémités.
static func draw_divider(ci: CanvasItem, cx: float, y: float, half: float, col := GOLD) -> void:
	ci.draw_line(Vector2(cx - half, y), Vector2(cx - 14, y), Color(col, 0.6), 1.0, true)
	ci.draw_line(Vector2(cx + 14, y), Vector2(cx + half, y), Color(col, 0.6), 1.0, true)
	draw_diamond(ci, Vector2(cx, y), 4, col, false, 1.0)
	draw_diamond(ci, Vector2(cx - half, y), 2, col)
	draw_diamond(ci, Vector2(cx + half, y), 2, col)


## Double filet d'or avec une vrille à chaque coin (cadre de l'écran titre).
static func draw_frame(ci: CanvasItem, r: Rect2, scale := 1.0, col := GOLD) -> void:
	ci.draw_rect(r, Color(col, 0.55), false, 1.0)
	ci.draw_rect(r.grow(-5), Color(col, 0.3), false, 1.0)
	for corner in [[r.position + Vector2(-4, -4), 1, 1], [Vector2(r.end.x + 4, r.position.y - 4), -1, 1], [Vector2(r.position.x - 4, r.end.y + 4), 1, -1], [r.end + Vector2(4, 4), -1, -1]]:
		for part in flourish_parts(corner[0], corner[1], corner[2], scale):
			var pts: PackedVector2Array = part[0]
			if part[1] > 0.0:
				ci.draw_colored_polygon(pts, Color(col, part[1]))
			var line := pts.duplicate()
			if part[2]:
				line.append(pts[0])
			ci.draw_polyline(line, Color(col, 0.75), 1.2, true)


## Fond de papier : dégradé brun et grain fin (fixe, graine donnée).
static func draw_paper(ci: CanvasItem, r: Rect2, grain := 2600) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([PAPER, PAPER, PAPER_DARK, PAPER_DARK]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := int(grain * r.get_area() / (1600.0 * 900.0))
	for i in n:
		var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		ci.draw_rect(Rect2(p, Vector2(1, 1)), Color(1, 0.95, 0.8, rng.randf() * 0.05))


# ---------------------------------------------------------------------------------------------
# Thème Godot.
# ---------------------------------------------------------------------------------------------

## Applique le contraste renforcé (appelé par Settings). Vaut pour les écrans construits ensuite.
static func refresh_access(on: bool) -> void:
	contraste = on
	SOFT = SOFT_CONTRASTE if on else SOFT_NORMAL
	FILET = FILET_CONTRASTE if on else FILET_NORMAL


## Taille de texte mise à l'échelle choisie dans les options (Settings.text_scale).
static func fs(size: int) -> int:
	var k := 1.0
	var settings = Engine.get_main_loop().root.get_node_or_null("Settings") if Engine.get_main_loop() is SceneTree else null
	if settings != null:
		k = settings.text_scale
	return roundi(size * k)


static func make() -> Theme:
	install()
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = fs(22)
	# Boutons ordinaires (panneaux de l'arbre, commandes) : papier et filet, or au survol.
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", Color("f4dc9a"))
	t.set_color("font_hover_pressed_color", "Button", Color("f4dc9a"))
	t.set_color("font_disabled_color", "Button", Color(SOFT, 0.5))
	t.set_stylebox("normal", "Button", box(Color(PAPER, 0.92), Color(GOLD, 0.28)))
	t.set_stylebox("hover", "Button", box(Color(PAPER.lightened(0.06), 0.96), Color(GOLD, 0.75)))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 1))
	t.set_stylebox("pressed", "Button", box(Color(PAPER.lightened(0.1), 1.0), GOLD))
	t.set_stylebox("hover_pressed", "Button", box(Color(PAPER.lightened(0.1), 1.0), GOLD))
	t.set_stylebox("disabled", "Button", box(Color(PAPER_DARK, 0.7), Color(SOFT, 0.15)))
	t.set_color("font_color", "Label", INK)
	# Halo sombre autour de chaque libellé : invisible sur un panneau, il garde le texte lisible
	# quand il est posé sur le monde (sol clair d'Aube ou de Vent, voile rouge d'un coup reçu).
	t.set_constant("outline_size", "Label", OUTLINE)
	t.set_color("font_outline_color", "Label", HALO)
	# Cases à cocher : losange vide ou plein.
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", GOLD)
	t.set_color("font_focus_color", "CheckBox", GOLD)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_hover_pressed_color", "CheckBox", GOLD)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		t.set_color(c, "CheckBox", Color.WHITE)
	t.set_stylebox("focus", "CheckBox", box(Color(0, 0, 0, 0), Color(GOLD, 0.7), 1))
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		t.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	t.set_icon("unchecked", "CheckBox", _diamond_icon(false))
	t.set_icon("checked", "CheckBox", _diamond_icon(true))
	t.set_constant("h_separation", "CheckBox", 12)
	# Curseur : filet, partie remplie en or, losange.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(SOFT, 0.3)
	track.content_margin_top = 1
	track.content_margin_bottom = 1
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.content_margin_top = 1.5
	fill.content_margin_bottom = 1.5
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _grabber(GOLD))
	t.set_icon("grabber_highlight", "HSlider", _grabber(Color("f4dc9a")))
	t.set_icon("grabber_disabled", "HSlider", _grabber(SOFT))
	# Focus visible (clavier et manette) : un filet d'or autour du curseur et des listes.
	var slider_focus := box(Color(0, 0, 0, 0), Color(GOLD, 0.8), 1)
	slider_focus.expand_margin_left = 6
	slider_focus.expand_margin_right = 6
	slider_focus.expand_margin_top = 8
	slider_focus.expand_margin_bottom = 8
	t.set_stylebox("focus", "HSlider", slider_focus)
	t.set_stylebox("focus", "OptionButton", box(Color(0, 0, 0, 0), GOLD, 1))
	# Panneaux, menus déroulants, infobulles, barres de défilement.
	t.set_stylebox("panel", "PanelContainer", cadre())
	t.set_stylebox("panel", "PopupMenu", box(Color(PAPER, 0.98), Color(GOLD, 0.5)))
	t.set_stylebox("hover", "PopupMenu", box(Color(GOLD, 0.16), Color(0, 0, 0, 0), 0))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	t.set_stylebox("panel", "TooltipPanel", box(Color(PAPER, 0.97), Color(GOLD, 0.5)))
	t.set_color("font_color", "TooltipLabel", INK)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(SOFT, 0.12)
	bar_bg.content_margin_left = 3
	bar_bg.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", bar_bg)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(GOLD, 0.45)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", grab)
	var grab_hi := grab.duplicate()
	grab_hi.bg_color = GOLD
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)
	return t


static func _diamond_icon(on: bool) -> ImageTexture:
	var n := 22
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var mid := (n - 1) / 2.0
	for y in n:
		for x in n:
			var d := absf(x - mid) + absf(y - mid)
			# Contour : anneau d'environ 1,4 px autour de d = 8 ; centre plein si coché (d <= 4).
			var ring := clampf(1.0 - absf(d - 8.0) / 1.4, 0.0, 1.0)
			var core := clampf(4.5 - d, 0.0, 1.0) if on else 0.0
			var a := maxf(ring, core)
			img.set_pixel(x, y, Color(GOLD, a))
	return ImageTexture.create_from_image(img)


static func _grabber(c: Color) -> ImageTexture:
	var n := 20
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var mid := (n - 1) / 2.0
	for y in n:
		for x in n:
			var d := absf(x - mid) + absf(y - mid)
			var outer := clampf(8.5 - d, 0.0, 1.0)
			var ring := clampf(1.0 - absf(d - 7.5) / 1.2, 0.0, 1.0)
			var core := clampf(3.8 - d, 0.0, 1.0)
			var col := PAPER.lerp(c, maxf(ring, core))
			img.set_pixel(x, y, Color(col, outer))
	return ImageTexture.create_from_image(img)


## Bouton ordinaire : largeur fixe, prend le focus au clavier et à la manette.
static func button(text: String, width := 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 50)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func(): Sfx.play("clic"))
	b.mouse_entered.connect(func(): Sfx.play("survol"))
	return b


## Entrée de menu d'herbier : texte seul, sans boîte ; l'entrée choisie passe en or, avec une
## feuille devant et un filet dessous (align : HORIZONTAL_ALIGNMENT_LEFT ou _CENTER, avec une
## feuille de chaque côté). Le survol de la souris lui donne le focus : une seule entrée brille.
static func menu_item(text: String, size := 36, align := HORIZONTAL_ALIGNMENT_LEFT, width := 0.0) -> Button:
	var b := MenuItem.new()
	b.text = text
	b.item_size = size
	b.alignment = align
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", serif(500))
	b.add_theme_font_size_override("font_size", size)
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = 44 if align == HORIZONTAL_ALIGNMENT_LEFT else 40
	pad.content_margin_right = 40
	pad.content_margin_top = 2
	pad.content_margin_bottom = 8
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, pad)
	var rest := SOFT.lerp(INK, 0.4)
	b.add_theme_color_override("font_color", rest)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_pressed_color", Color("f4dc9a"))
	b.add_theme_color_override("font_hover_pressed_color", Color("f4dc9a"))
	b.add_theme_color_override("font_disabled_color", Color(SOFT, 0.4))
	if width > 0.0:
		b.custom_minimum_size.x = width
	b.pressed.connect(func(): Sfx.play("clic"))
	b.mouse_entered.connect(func():
		if not b.disabled:
			b.grab_focus()
			Sfx.play("survol"))
	b.focus_entered.connect(b.queue_redraw)
	b.focus_exited.connect(b.queue_redraw)
	return b


class MenuItem extends Button:
	var item_size := 36
	## Texte discret ajouté à droite de l'entrée (ex. « niveau 12 »), en petit.
	var note := ""

	func _draw() -> void:
		var f: Font = get_theme_font("font")
		var tw := f.get_string_size(atr(text), HORIZONTAL_ALIGNMENT_LEFT, -1, item_size).x
		var sb := get_theme_stylebox("normal")
		var left := sb.get_margin(SIDE_LEFT)
		var x0 := left
		if alignment == HORIZONTAL_ALIGNMENT_CENTER:
			x0 = left + (size.x - left - sb.get_margin(SIDE_RIGHT) - tw) / 2.0
		var mid_y := size.y / 2.0 - 3.0
		var base_y := size.y - sb.get_margin(SIDE_BOTTOM) + 3.0
		if note != "":
			var nf: Font = load("res://scripts/ui_theme.gd").font(true)
			draw_string(nf, Vector2(x0 + tw + 56, mid_y + 6), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(GOLD, 0.7 if has_focus() else 0.45))
		if not has_focus() or disabled:
			return
		var ut = load("res://scripts/ui_theme.gd")
		var ls := item_size / 36.0
		if alignment == HORIZONTAL_ALIGNMENT_CENTER:
			ut.draw_leaf(self, Vector2(x0 - 34 * ls, mid_y), 0.0, 20 * ls, 5.5 * ls, GOLD, Color(GOLD, 0.45), 1.1)
			ut.draw_leaf(self, Vector2(x0 + tw + 34 * ls, mid_y), PI, 20 * ls, 5.5 * ls, GOLD, Color(GOLD, 0.45), 1.1)
		else:
			ut.draw_leaf(self, Vector2(x0 - 38 * ls, mid_y), -0.25, 22 * ls, 6 * ls, GOLD, Color(GOLD, 0.45), 1.1)
			draw_line(Vector2(x0, base_y), Vector2(x0 + tw + 44, base_y), Color(GOLD, 0.7), 1.0, true)
			ut.draw_diamond(self, Vector2(x0 + tw + 48, base_y), 3, GOLD)

