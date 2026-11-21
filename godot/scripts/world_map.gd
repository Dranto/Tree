## Carte du monde (touche M), dessinée par le code : terre ravivée, le secteur de chaque région (Ronce, Spore,
## Vent…), sanctuaires, autels découverts, Cœur et arène de chaque région, position du joueur et objectif.
## La légende et l'avancement de chaque région sont lus dans data/regions/<id>.json et les drapeaux de la partie :
## une région ajoutée par ses fichiers apparaît d'elle-même. Le jeu est en pause tant qu'elle est ouverte
## (voir quest_ui.gd).
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const Regions = preload("res://scripts/regions.gd")
const Content = preload("res://scripts/content.gd")
const RegionUi = preload("res://scripts/region_ui.gd")

const TEX_SIZE := 160
const DEAD := Color(0.17, 0.16, 0.18)
const ALIVE := Color(0.33, 0.6, 0.27)

var main
var _view: Control
var _panel: PanelContainer
var _goal_title: Label
var _goal_text: Label
var _goal_region: Label
var _legend: VBoxContainer
var t := 0.0


## Un signe de la légende, avec la même forme que sur la carte.
class Glyph extends Control:
	var kind := ""
	var color := Color.WHITE
	var filled := true
	var painter

	func _init() -> void:
		custom_minimum_size = Vector2(22, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		painter.draw_glyph(self, kind, size / 2.0, color, filled, 1.0)


## La carte elle-même : se découpe aux bords du cadre pour que la région de Ronce, qui déborde
## du monde, ne sorte pas du dessin.
class MapView extends Control:
	var owner_map

	func _draw() -> void:
		owner_map.draw_map(self)


var _tex: ImageTexture


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_view = MapView.new()
	_view.owner_map = self
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(290, 0)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	_label(v, "OBJECTIF", 12, UiTheme.GOLD)
	_goal_region = _label(v, "", 12, Color(0.78, 0.85, 0.78))
	_goal_title = _label(v, "", 17, UiTheme.INK, true)
	_goal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_title.custom_minimum_size.x = 250.0
	_goal_text = _label(v, "", 13, Color(0.78, 0.85, 0.78))
	_goal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_text.custom_minimum_size.x = 250.0
	v.add_child(HSeparator.new())
	_label(v, "LÉGENDE", 12, Color(0.55, 0.65, 0.55))
	_legend = VBoxContainer.new()
	_legend.add_theme_constant_override("separation", 6)
	v.add_child(_legend)
	_label(v, "M ou Échap : fermer   ·   J : journal", 12, Color(0.55, 0.6, 0.55))
	resized.connect(_layout)


## La légende : un signe par région (avec son avancement), puis les signes communs. Reconstruite à chaque
## ouverture, car l'avancement change.
func _build_legend() -> void:
	for c in _legend.get_children():
		_legend.remove_child(c)
		c.queue_free()
	_legend_row(["land", Color("5c9a45"), "Terre ravivée", ""])
	for reg in Regions.ids():
		var sub := RegionUi.summary(reg)
		var st := RegionUi.state(reg)
		_legend_row(["region", RegionUi.tint(reg), RegionUi.full_name(reg), sub + ("  ·  " + st if st != "" and sub != "" else st)])
	for e in [
		["seed", UiTheme.GOLD, "La graine", ""],
		["breach", _breach_color(), RegionUi.UNDER_SEED_NAME, RegionUi.finale_summary()],
		["sanctuary", Color("9ad7ff"), "Sanctuaire", ""],
		["altar", Color("f2d06b"), "Autel découvert", ""],
		["heart", Color("c84b44"), "Cœur de flétrissure", ""],
		["arena", Color("e0675e"), "Arène du boss", ""],
		["player", Color.WHITE, "Toi", ""],
	]:
		_legend_row(e)


func _legend_row(e: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var holder := HBoxContainer.new()
	var g := Glyph.new()
	g.kind = e[0]
	g.color = e[1]
	g.painter = self
	holder.add_child(g)
	row.add_child(holder)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	_label(col, e[2], 13, Color(0.82, 0.88, 0.82))
	if str(e[3]) != "":
		var sub := _label(col, e[3], 11, Color(0.6, 0.68, 0.6))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size.x = 215.0
	_legend.add_child(row)


func _label(parent: Node, text: String, size_px: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UiTheme.font(true))
	parent.add_child(l)
	return l


## Le cadre carré de la carte : à gauche, sous le titre, et la colonne de droite pour le reste.
func _layout() -> void:
	var side := minf(size.y - 130.0, size.x - 400.0)
	_view.position = Vector2(40, 90)
	_view.size = Vector2(side, side)
	_panel.reset_size()
	_panel.position = Vector2(size.x - _panel.size.x - 40.0, 90.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.03, 0.94))
	UiAudit.draw_text(self, "carte", UiTheme.font(true), Vector2(40, 66), "Carte", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiTheme.GOLD)


func open() -> void:
	_build_legend()
	_layout()
	_rebuild_texture()
	_refresh_goal()
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func _refresh_goal() -> void:
	var o: Dictionary = Objectives.followed()
	var reg := str(o.get("region", ""))
	_goal_region.text = RegionUi.full_name(reg) if reg != "" and Regions.ids().size() > 1 else ""
	_goal_region.add_theme_color_override("font_color", RegionUi.tint(reg).lightened(0.25) if _goal_region.text != "" else Color.WHITE)
	_goal_region.visible = _goal_region.text != ""
	if not o.is_empty():
		_goal_title.text = o["title"]
		_goal_text.text = o["text"]
	elif Regions.ids().size() > 1:
		_goal_title.text = "Aventure accomplie"
		_goal_text.text = "Toutes les régions sont purifiées."
	else:
		_goal_title.text = "Tranche accomplie"
		_goal_text.text = "Le roncier est libre."
	_layout()


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	# La terre se ravive même si le jeu est en pause (vague en cours) : on redessine à un rythme calme.
	_view.queue_redraw()


## Carte de la vie du sol : une image ré-échantillonnée à l'ouverture.
func _rebuild_texture() -> void:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGB8)
	var half: float = main.world_half
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var p := Vector2((x + 0.5) / TEX_SIZE * 2.0 - 1.0, (y + 0.5) / TEX_SIZE * 2.0 - 1.0) * half
			var life: float = main.ground.life_at(p)
			var grain := 0.012 * sin(float(x) * 1.7 + float(y) * 2.3)
			img.set_pixel(x, y, DEAD.lerp(ALIVE, clampf(life * 1.15, 0.0, 1.0)) + Color(grain, grain, grain, 0.0))
	_tex = ImageTexture.create_from_image(img)


## Passage du monde au cadre : le monde carré (± world_half) remplit le cadre.
func to_map(p: Vector2, view_size: Vector2) -> Vector2:
	var half: float = main.world_half
	return (p / half * 0.5 + Vector2(0.5, 0.5)) * view_size


func draw_map(v: Control) -> void:
	if main == null or not is_instance_valid(main) or _tex == null:
		return
	UiAudit.begin("carte")
	UiAudit.text("carte", Rect2(Vector2(40, 36), Vector2(70, 36)), "Carte", "titre")
	var s := v.size
	var font := UiTheme.font(true)
	v.draw_texture_rect(_tex, Rect2(Vector2.ZERO, s), false)
	# Chaque région : un secteur teinté, borné par ses deux bords et le cercle intérieur.
	for reg in Regions.ids():
		_draw_region(v, reg, s, font)

	# La graine.
	var seed_at := to_map(Vector2.ZERO, s)
	draw_glyph(v, "seed", seed_at, UiTheme.GOLD, true, 1.0)
	_text(v, font, seed_at + Vector2(14, 5), "Graine", Color(UiTheme.GOLD, 0.9))
	# La brèche à son pied (la finale) : un anneau qui s'allume quand toutes les régions sont purifiées.
	draw_glyph(v, "breach", seed_at, _breach_color(), true, 1.0)
	if bool(Game.flags.get("finale_ouverte", false)) and not bool(Game.flags.get("finale_vaincue", false)):
		_text(v, font, seed_at + Vector2(14, 21), "Brèche", Color(_breach_color(), 0.95))

	# Sanctuaires et autels du monde (groupes « sanctuaire » et « autel »).
	for n in main.get_tree().get_nodes_in_group("sanctuaire"):
		var lit: bool = Game.flags.get("sanctuaire_" + str(n.get("id")), false)
		draw_glyph(v, "sanctuary", to_map(n.position, s), Color("9ad7ff"), lit, 1.0)
	for n in main.get_tree().get_nodes_in_group("autel"):
		if Game.flags.get("autel_" + str(n.get("id")), false):
			draw_glyph(v, "altar", to_map(n.position, s), Color("f2d06b"), true, 1.0)

	# Le Cœur et l'arène de chaque région.
	for reg in main.hearts:
		var heart = main.hearts[reg]
		var purified := bool(Game.flags.get(heart.flag, false))
		var hc := to_map(heart.center, s)
		draw_glyph(v, "heart", hc, Color("7fd36b") if purified else Color("c84b44"), true, 1.0)
		_text(v, font, hc + Vector2(-60, 24), "Cœur", Color("e9e2c8"))
		var arena = main.arenas[reg]
		var beaten := bool(Game.flags.get(arena.flag, false))
		var ac := to_map(arena.center, s)
		draw_glyph(v, "arena", ac, Color("7fd36b") if beaten else RegionUi.tint(reg).lightened(0.15), true, 1.0)
		_text(v, font, ac + Vector2(-70, 4), "Arène", Color("e9e2c8"))

	# Objectif : un anneau qui bat autour de la cible.
	var goal = Objectives.target_pos(Objectives.followed())
	if goal != null:
		var gc := to_map(goal, s)
		# Le trajet du joueur à l'objectif, en pointillés : il passe d'une région à l'autre.
		var from := to_map(main.map_position(main.player.position), s)
		var dash := 9.0
		var span := from.distance_to(gc)
		var dir := (gc - from).normalized()
		var k := fmod(t * 24.0, dash * 2.0)
		while k < span - 14.0:
			var a := from + dir * maxf(k, 14.0)
			var b := from + dir * minf(k + dash, span - 14.0)
			if k + dash > 14.0:
				v.draw_line(a, b, Color(UiTheme.GOLD, 0.45), 2.0)
			k += dash * 2.0
		var pulse := 0.5 + 0.5 * sin(t * 4.0)
		v.draw_arc(gc, 13.0 + 4.0 * pulse, 0.0, TAU, 28, Color(UiTheme.GOLD, 0.9 - 0.4 * pulse), 2.0)

	# Le joueur, tourné vers sa visée.
	draw_glyph(v, "player", to_map(main.map_position(main.player.position), s), Color.WHITE, true, 1.0, main.player.aim.angle())
	v.draw_rect(Rect2(Vector2.ZERO, s), Color(0.6, 0.8, 0.6, 0.5), false, 2.0)
	UiAudit.scan_controls("carte", self)


## Secteur d'une région sur la carte, et son nom (« map_name » de data/regions/<id>.json).
func _draw_region(v: Control, reg: String, s: Vector2, font: Font) -> void:
	var tint: Color = Game.tree.branch_color(Content.tree().get("branches", []).find(Regions.branch_of(reg)))
	var a := Regions.angle_of(reg)
	var h := Regions.half_width()
	var far: float = main.world_half * 2.0
	var pts := PackedVector2Array()
	for i in 13:
		pts.append(to_map(Vector2.from_angle(a - h + 2.0 * h * i / 12.0) * Regions.INNER, s))
	for i in 13:
		pts.append(to_map(Vector2.from_angle(a + h - 2.0 * h * i / 12.0) * far, s))
	v.draw_colored_polygon(pts, Color(tint, 0.13))
	var edge1 := PackedVector2Array([to_map(Vector2.from_angle(a - h) * Regions.INNER, s), to_map(Vector2.from_angle(a - h) * far, s)])
	var edge2 := PackedVector2Array([to_map(Vector2.from_angle(a + h) * Regions.INNER, s), to_map(Vector2.from_angle(a + h) * far, s)])
	v.draw_polyline(edge1, Color(tint, 0.55), 1.5)
	v.draw_polyline(edge2, Color(tint, 0.55), 1.5)
	var arc := PackedVector2Array()
	for i in 25:
		arc.append(to_map(Vector2.from_angle(a - h + 2.0 * h * i / 24.0) * Regions.INNER, s))
	v.draw_polyline(arc, Color(tint, 0.55), 1.5)
	# Nom de la région, vers le milieu du secteur.
	var label := str(Regions.def(reg).get("map_name", reg.capitalize()))
	var name_at := to_map(Vector2.from_angle(a) * 1000.0, s)
	var name_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 15).x
	UiAudit.draw_text(v, "carte", font, name_at + Vector2(-name_w / 2.0, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(tint.lightened(0.25), 0.95), v.get_global_transform())


## Texte posé sur la carte, avec un liseré sombre pour rester lisible sur toutes les teintes.
func _text(v: Control, font: Font, pos: Vector2, s: String, color: Color) -> void:
	v.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.8))
	UiAudit.draw_text(v, "carte", font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color, v.get_global_transform())


## Couleur de la brèche sous la graine : éteinte tant qu'elle est scellée, rouge braise ouverte, verte vaincue.
func _breach_color() -> Color:
	if bool(Game.flags.get("finale_vaincue", false)):
		return Color("7fd36b")
	if bool(Game.flags.get("finale_ouverte", false)):
		return Color("e0675e")
	return Color(0.55, 0.58, 0.55)


## Un signe de la carte (ou de la légende), centré sur « c ».
func draw_glyph(ci: CanvasItem, kind: String, c: Vector2, color: Color, filled: bool, k: float, angle := 0.0) -> void:
	var dark := Color(0.04, 0.05, 0.04, 0.9)
	match kind:
		"land":
			ci.draw_rect(Rect2(c - Vector2(9, 7), Vector2(18, 14)), color)
		"region":
			ci.draw_rect(Rect2(c - Vector2(9, 7), Vector2(18, 14)), Color(color, 0.3))
			ci.draw_rect(Rect2(c - Vector2(9, 7), Vector2(18, 14)), Color(color, 0.8), false, 1.5)
		"seed":
			ci.draw_circle(c, 6.0 * k, dark)
			ci.draw_circle(c, 4.0 * k, color)
			ci.draw_line(c + Vector2(0, 4), c + Vector2(0, 9), color, 2.0)
		"breach":
			# Un anneau brisé autour de la graine : la brèche par où l'on descend affronter la Flétrissure.
			for i in 3:
				var a0 := TAU * i / 3.0 + 0.25
				ci.draw_arc(c, 12.0 * k, a0, a0 + 1.4, 10, dark, 4.5)
				ci.draw_arc(c, 12.0 * k, a0, a0 + 1.4, 10, color, 2.5)
		"sanctuary":
			var pts := PackedVector2Array([c + Vector2(0, -9), c + Vector2(7, 0), c + Vector2(0, 9), c + Vector2(-7, 0)])
			if filled:
				ci.draw_colored_polygon(pts, color)
			var line := pts.duplicate()
			line.append(pts[0])
			ci.draw_polyline(line, color if not filled else dark, 1.5)
		"altar":
			var pts := PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 6), c + Vector2(-8, 6)])
			ci.draw_colored_polygon(pts, color)
			var line := pts.duplicate()
			line.append(pts[0])
			ci.draw_polyline(line, dark, 1.5)
		"heart":
			ci.draw_circle(c, 9.0, dark)
			ci.draw_circle(c, 6.5, color)
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0)
				ci.draw_line(c + d * 8.0, c + d * 13.0, color, 2.0)
		"arena":
			ci.draw_arc(c, 11.0, 0.0, TAU, 28, dark, 5.0)
			ci.draw_arc(c, 11.0, 0.0, TAU, 28, color, 3.0)
			ci.draw_circle(c, 3.5, color)
		"player":
			var f := Vector2.from_angle(angle)
			var o := f.orthogonal()
			var pts := PackedVector2Array([c + f * 10.0, c - f * 7.0 + o * 7.0, c - f * 3.0, c - f * 7.0 - o * 7.0])
			ci.draw_colored_polygon(pts, color)
			var line := pts.duplicate()
			line.append(pts[0])
			ci.draw_polyline(line, dark, 1.5)
