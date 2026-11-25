## Glyphes de manette dessinés par le code (jalon 11) : boutons de face, gâchettes, boutons de
## tranche, sticks, croix directionnelle, Affichage et Menu. Deux styles, Xbox (lettres A B X Y,
## LB RB LT RT) et PlayStation (croix, rond, carré, triangle, L1 R1 L2 R2), choisis par
## Settings.pad_layout(). Même facture que les touches du tutoriel : cabochon de papier sombre,
## bord d'or, symbole à l'encre ivoire ; les boutons de face gardent une pointe de leur couleur.
##
## Codes : ceux des liaisons de Settings (JOY_BUTTON_*, PAD_LT / PAD_RT) et les pseudo-codes
## STICK_L, PAD_STICK_R et PAD_DPAD (glyphe entier des sticks et de la croix).
extends RefCounted

const UiTheme = preload("res://scripts/ui_theme.gd")
## Mêmes valeurs que Settings.PAD_LT, PAD_RT, PAD_STICK_L, PAD_STICK_R et PAD_DPAD (constantes
## locales : un motif de « match » doit être constant).
const PAD_LT := 200 + JOY_AXIS_TRIGGER_LEFT
const PAD_RT := 200 + JOY_AXIS_TRIGGER_RIGHT
const STICK_L := 300
const STICK_R := 301
const DPAD := 302

## Pointe de couleur des boutons de face (sourdes, pour rester dans la planche Herbier).
const FACE_XBOX := {JOY_BUTTON_A: Color("8fc46a"), JOY_BUTTON_B: Color("dc7a62"), JOY_BUTTON_X: Color("78a6dc"), JOY_BUTTON_Y: Color("e6c463")}
const FACE_PS := {JOY_BUTTON_A: Color("8fb0e6"), JOY_BUTTON_B: Color("e27f74"), JOY_BUTTON_X: Color("d99ac6"), JOY_BUTTON_Y: Color("7fcaa8")}


## Largeur du glyphe pour une hauteur h (pour aligner plusieurs glyphes).
static func width(code: int, h := 30.0) -> float:
	match code:
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, PAD_LT, PAD_RT:
			return h * 1.5
		JOY_BUTTON_BACK, JOY_BUTTON_START:
			return h * 1.15
		DPAD, STICK_L, STICK_R:
			return h * 1.1
	if code >= JOY_BUTTON_PADDLE1 and code <= JOY_BUTTON_PADDLE4:
		return h * 1.5
	return h


## Dessine le glyphe du code, centré en c, de hauteur h, opacité a. style : « xbox »,
## « playstation » ou vide (Settings.pad_layout()).
static func draw(ci: CanvasItem, c: Vector2, code: int, a := 1.0, h := 30.0, style := "") -> void:
	if style == "":
		style = Settings.pad_layout()
	var ps := style == "playstation"
	var ink := Color(UiTheme.INK, a)
	var gold := Color(UiTheme.GOLD, 0.95 * a)
	var bg := Color(UiTheme.PAPER_DARK, 0.92 * a)
	var lw := maxf(1.5, h / 15.0)
	match code:
		JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y:
			var r := h / 2.0
			ci.draw_circle(c + Vector2(0, h * 0.08), r, Color(0, 0, 0, 0.35 * a))
			ci.draw_circle(c, r, bg)
			var tint: Color = (FACE_PS if ps else FACE_XBOX)[code]
			ci.draw_circle(c, r - lw * 1.3, Color(tint, 0.16 * a))
			ci.draw_arc(c, r, 0.0, TAU, 32, gold, lw, true)
			if ps:
				_ps_symbol(ci, c, code, r * 0.48, Color(tint.lerp(UiTheme.INK, 0.35), a), lw * 1.1)
			else:
				_text(ci, c, ["A", "B", "X", "Y"][code], h * 0.6, Color(tint.lerp(UiTheme.INK, 0.45), a))
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
			var rect := Rect2(c - Vector2(h * 0.75, h * 0.36), Vector2(h * 1.5, h * 0.72))
			_cab(ci, rect, h * 0.18, bg, gold, lw, a)
			var left := code == JOY_BUTTON_LEFT_SHOULDER
			_text(ci, c, ("L1" if left else "R1") if ps else ("LB" if left else "RB"), h * 0.56, ink)
		PAD_LT, PAD_RT:
			# Gâchette : une plaque arrondie en haut, plus haute que les boutons de tranche.
			var rect := Rect2(c - Vector2(h * 0.6, h * 0.5), Vector2(h * 1.2, h))
			var sb := StyleBoxFlat.new()
			sb.bg_color = bg
			sb.border_color = gold
			sb.set_border_width_all(int(lw))
			sb.corner_radius_top_left = int(h * 0.5)
			sb.corner_radius_top_right = int(h * 0.5)
			sb.corner_radius_bottom_left = int(h * 0.12)
			sb.corner_radius_bottom_right = int(h * 0.12)
			ci.draw_rect(Rect2(rect.position + Vector2(0, h * 0.08), rect.size), Color(0, 0, 0, 0.3 * a))
			ci.draw_style_box(sb, rect)
			var left := code == PAD_LT
			_text(ci, c + Vector2(0, h * 0.06), ("L2" if left else "R2") if ps else ("LT" if left else "RT"), h * 0.56, ink)
		JOY_BUTTON_BACK, JOY_BUTTON_START:
			var rect := Rect2(c - Vector2(h * 0.575, h * 0.4), Vector2(h * 1.15, h * 0.8))
			_cab(ci, rect, h * 0.4, bg, gold, lw, a)
			if code == JOY_BUTTON_START:
				# Menu (ou Options) : trois traits.
				for k in 3:
					var y := c.y + (k - 1) * h * 0.15
					ci.draw_line(Vector2(c.x - h * 0.22, y), Vector2(c.x + h * 0.22, y), ink, lw * 0.9, true)
			elif ps:
				# Partage : trois petits rais qui montent.
				for k in 3:
					var x := c.x + (k - 1) * h * 0.16
					ci.draw_line(Vector2(x, c.y + h * 0.18), Vector2(x + (k - 1) * h * 0.05, c.y - h * 0.18), ink, lw * 0.9, true)
			else:
				# Affichage : deux fenêtres qui se chevauchent.
				var s := h * 0.26
				ci.draw_rect(Rect2(c + Vector2(-s * 0.9, -s * 0.75), Vector2(s * 1.2, s)), ink, false, lw * 0.8)
				ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.25), Vector2(s * 1.2, s)), bg, true)
				ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.25), Vector2(s * 1.2, s)), ink, false, lw * 0.8)
		JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK, STICK_L, STICK_R:
			var r := h / 2.0
			var left := code == JOY_BUTTON_LEFT_STICK or code == STICK_L
			ci.draw_circle(c + Vector2(0, h * 0.08), r, Color(0, 0, 0, 0.35 * a))
			ci.draw_circle(c, r, bg)
			ci.draw_arc(c, r, 0.0, TAU, 32, gold, lw, true)
			ci.draw_arc(c, r * 0.62, 0.0, TAU, 28, Color(UiTheme.GOLD, 0.45 * a), lw * 0.8, true)
			var label := ("L" if left else "R")
			if code == JOY_BUTTON_LEFT_STICK or code == JOY_BUTTON_RIGHT_STICK:
				label = (label + "3") if ps else label
				# Clic du stick : un point plein sous la lettre.
				ci.draw_circle(c + Vector2(0, r * 0.62), lw, gold)
			_text(ci, c, label, h * 0.48, ink)
			if code == STICK_L or code == STICK_R:
				# Le stick se pousse : quatre petites flèches autour.
				for i in 4:
					var d := Vector2.from_angle(i * PI / 2.0)
					var tip := c + d * (r + h * 0.24)
					var side := d.orthogonal() * h * 0.11
					ci.draw_colored_polygon(PackedVector2Array([tip, tip - d * h * 0.18 + side, tip - d * h * 0.18 - side]), gold)
		DPAD, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			_dpad(ci, c, code, h, bg, gold, lw, a)
		_:
			if code >= JOY_BUTTON_PADDLE1 and code <= JOY_BUTTON_PADDLE4:
				var rect := Rect2(c - Vector2(h * 0.75, h * 0.36), Vector2(h * 1.5, h * 0.72))
				_cab(ci, rect, h * 0.3, bg, gold, lw, a)
				_text(ci, c, "P%d" % (code - JOY_BUTTON_PADDLE1 + 1), h * 0.48, ink)
			else:
				var r := h / 2.0
				ci.draw_circle(c, r, bg)
				ci.draw_arc(c, r, 0.0, TAU, 32, gold, lw, true)
				_text(ci, c, str(code), h * 0.45, ink)


## Une rangée de glyphes centrée en c (espacés de gap), pour le tutoriel et l'arbre.
static func draw_row(ci: CanvasItem, c: Vector2, codes: Array, a := 1.0, h := 30.0, gap := 6.0) -> void:
	var total := -gap
	for k in codes:
		total += width(int(k), h) + gap
	var x := c.x - total / 2.0
	for k in codes:
		var w := width(int(k), h)
		draw(ci, Vector2(x + w / 2.0, c.y), int(k), a, h)
		x += w + gap


static func _cab(ci: CanvasItem, rect: Rect2, radius: float, bg: Color, border: Color, lw: float, a: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(maxi(1, int(lw)))
	sb.set_corner_radius_all(int(radius))
	ci.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * 0.1), rect.size), Color(0, 0, 0, 0.3 * a))
	ci.draw_style_box(sb, rect)


static func _text(ci: CanvasItem, c: Vector2, s: String, fs: float, col: Color) -> void:
	var font := UiTheme.font(true)
	var size := maxi(8, roundi(fs))
	var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, Vector2(c.x - tw / 2.0, c.y + size * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Symboles PlayStation : croix, rond, carré, triangle.
static func _ps_symbol(ci: CanvasItem, c: Vector2, code: int, s: float, col: Color, lw: float) -> void:
	match code:
		JOY_BUTTON_A:
			ci.draw_line(c + Vector2(-s, -s), c + Vector2(s, s), col, lw, true)
			ci.draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, lw, true)
		JOY_BUTTON_B:
			ci.draw_arc(c, s, 0.0, TAU, 24, col, lw, true)
		JOY_BUTTON_X:
			ci.draw_rect(Rect2(c - Vector2(s, s) * 0.9, Vector2(s, s) * 1.8), col, false, lw)
		JOY_BUTTON_Y:
			var pts := PackedVector2Array([c + Vector2(0, -s * 1.05), c + Vector2(s * 1.05, s * 0.75), c + Vector2(-s * 1.05, s * 0.75), c + Vector2(0, -s * 1.05)])
			ci.draw_polyline(pts, col, lw, true)


## Croix directionnelle : une croix de papier, la branche pressée (ou aucune : croix entière) en or.
static func _dpad(ci: CanvasItem, c: Vector2, code: int, h: float, bg: Color, gold: Color, lw: float, a: float) -> void:
	var arm := h * 0.36
	var half := h * 0.55
	var pts := PackedVector2Array()
	for p in [Vector2(-arm / 2, -half), Vector2(arm / 2, -half), Vector2(arm / 2, -arm / 2), Vector2(half, -arm / 2),
			Vector2(half, arm / 2), Vector2(arm / 2, arm / 2), Vector2(arm / 2, half), Vector2(-arm / 2, half),
			Vector2(-arm / 2, arm / 2), Vector2(-half, arm / 2), Vector2(-half, -arm / 2), Vector2(-arm / 2, -arm / 2)]:
		pts.append(c + p)
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, h * 0.08))
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.3 * a))
	ci.draw_colored_polygon(pts, bg)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, gold, lw, true)
	var dirs := {JOY_BUTTON_DPAD_UP: Vector2.UP, JOY_BUTTON_DPAD_DOWN: Vector2.DOWN, JOY_BUTTON_DPAD_LEFT: Vector2.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2.RIGHT}
	for k in dirs:
		var d: Vector2 = dirs[k]
		var tip := c + d * half * 0.78
		var side := d.orthogonal() * arm * 0.3
		var on: bool = code == k
		ci.draw_colored_polygon(PackedVector2Array([tip, tip - d * arm * 0.42 + side, tip - d * arm * 0.42 - side]),
			gold if on or code == DPAD else Color(UiTheme.GOLD, 0.35 * a))
