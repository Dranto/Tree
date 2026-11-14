## Thème commun des menus : aplats sombres et accents verts, tout dessiné par le code.
extends RefCounted

const INK := Color("e9e2c8")
const LEAF := Color("7fd36b")
const GOLD := Color("f2d06b")
const PANEL_BG := Color(0.06, 0.08, 0.07, 0.92)


static func box(bg: Color, border: Color, width := 1, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.52, 0.5))
	t.set_stylebox("normal", "Button", box(Color(0.1, 0.13, 0.11, 0.9), Color(0.6, 0.8, 0.6, 0.25)))
	t.set_stylebox("hover", "Button", box(Color(0.14, 0.2, 0.15, 0.95), LEAF))
	t.set_stylebox("focus", "Button", box(Color(0.14, 0.2, 0.15, 0.95), GOLD, 2))
	t.set_stylebox("pressed", "Button", box(Color(0.2, 0.3, 0.2, 1.0), LEAF))
	t.set_stylebox("disabled", "Button", box(Color(0.08, 0.09, 0.08, 0.7), Color(0.4, 0.4, 0.4, 0.2)))
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "CheckBox", INK)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		t.set_color(c, "CheckBox", Color(0.85, 0.95, 0.8))
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_focus_color", "CheckBox", GOLD)
	t.set_stylebox("focus", "CheckBox", box(Color(0, 0, 0, 0), GOLD, 2))
	t.set_icon("unchecked", "CheckBox", _box_icon(false))
	t.set_icon("checked", "CheckBox", _box_icon(true))
	# Curseur
	var track := box(Color(0.1, 0.14, 0.11), Color(0.6, 0.8, 0.6, 0.25), 1, 4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(LEAF.darkened(0.3), LEAF.darkened(0.3), 1, 4)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _dot(LEAF))
	t.set_icon("grabber_highlight", "HSlider", _dot(GOLD))
	t.set_icon("grabber_disabled", "HSlider", _dot(Color.GRAY))
	t.set_stylebox("panel", "PanelContainer", box(PANEL_BG, Color(0.6, 0.8, 0.6, 0.3), 1, 10))
	return t


static func _box_icon(on: bool) -> ImageTexture:
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var edge := x < 2 or y < 2 or x >= n - 2 or y >= n - 2
			if edge:
				img.set_pixel(x, y, Color(0.75, 0.9, 0.7))
			elif on and x > 5 and x < n - 6 and y > 5 and y < n - 6:
				img.set_pixel(x, y, LEAF)
	return ImageTexture.create_from_image(img)


static func _dot(c: Color) -> ImageTexture:
	var n := 22
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var mid := (n - 1) / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x, y).distance_to(Vector2(mid, mid))
			var a := clampf(mid + 0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return ImageTexture.create_from_image(img)


## Bouton de menu : largeur fixe, prend le focus au clavier et à la manette.
static func button(text: String, width := 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 52)
	b.focus_mode = Control.FOCUS_ALL
	return b
