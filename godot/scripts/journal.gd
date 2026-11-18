## Journal (touche J) : les objectifs en cours et accomplis, avec leurs récompenses.
## Nœuds Control avec le thème commun. Le jeu est en pause tant qu'il est ouvert (voir quest_ui.gd).
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const ControlsCard = preload("res://scripts/controls_card.gd")
const Regions = preload("res://scripts/regions.gd")

var _panel: PanelContainer
var _box: VBoxContainer
var _subtitle: Label


## Pastille d'un objectif : cercle vide (à faire), anneau doré (en cours), disque vert coché
## (accompli) ; un losange pour les facultatifs.
class Dot extends Control:
	var done := false
	var current := false
	var optional := false

	func _init() -> void:
		custom_minimum_size = Vector2(22, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var col := UiTheme.LEAF if done else (UiTheme.GOLD if current else Color(0.5, 0.55, 0.5))
		if optional:
			var pts := PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 0), c + Vector2(0, 9), c + Vector2(-9, 0)])
			if done:
				draw_colored_polygon(pts, col)
			else:
				var line := pts.duplicate()
				line.append(pts[0])
				draw_polyline(line, col, 2.0)
		elif done:
			draw_circle(c, 9.0, col)
		else:
			draw_arc(c, 8.0, 0.0, TAU, 24, col, 2.0)
			if current:
				draw_circle(c, 3.5, col)
		if done:
			var ink := Color(0.05, 0.1, 0.05)
			draw_polyline(PackedVector2Array([c + Vector2(-4, 0), c + Vector2(-1, 3.5), c + Vector2(5, -3.5)]), ink, 2.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(780, 0)
	var sb := UiTheme.box(UiTheme.PANEL_BG, Color(0.6, 0.8, 0.6, 0.3), 1, 10)
	sb.content_margin_top = 14
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_panel.add_child(_box)
	Objectives.changed.connect(func(): if visible: refresh())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.88))


func _label(parent: Node, text: String, size_px: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UiTheme.font(true))
	parent.add_child(l)
	return l


## Reconstruit la liste (à chaque ouverture et à chaque changement d'objectif).
func refresh() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_label(_box, "Journal", 30, UiTheme.GOLD, true)
	var cur: Dictionary = Objectives.current()
	# Une région à la fois (celle de l'objectif en cours), plus les objectifs communs : avec
	# plusieurs régions, la liste entière déborderait de l'écran.
	var reg := str(cur.get("region", ""))
	var mains: Array = Objectives.list().filter(func(o): return o.get("main", false) and (reg == "" or str(o.get("region", "")) in ["", reg]))
	var n_done := mains.filter(func(o): return Objectives.is_done(o["id"])).size()
	var place := str(Regions.def(reg).get("name", reg)) if reg != "" else "L'aventure"
	_subtitle = _label(_box, "%s : %d / %d objectifs principaux accomplis" % [place, n_done, mains.size()], 14, Color(0.7, 0.78, 0.7))
	for pass_main in [true, false]:
		var rows: Array = Objectives.list().filter(func(o): return bool(o.get("main", false)) == pass_main \
			and (reg == "" or str(o.get("region", "")) in ["", reg]))
		if rows.is_empty():
			continue
		var head := _label(_box, "OBJECTIFS PRINCIPAUX" if pass_main else "FACULTATIFS", 12, Color(0.55, 0.65, 0.55))
		head.add_theme_constant_override("line_spacing", 0)
		for o in rows:
			_add_row(o, not cur.is_empty() and cur["id"] == o["id"])
	_label(_box, "COMMANDES", 12, Color(0.55, 0.65, 0.55))
	_box.add_child(ControlsCard.new(13))
	_label(_box, "J ou Échap : fermer   ·   M : carte", 12, Color(0.55, 0.6, 0.55))
	_panel.reset_size()


func _add_row(o: Dictionary, is_current: bool) -> void:
	var done: bool = Objectives.is_done(o["id"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var dot := Dot.new()
	dot.done = done
	dot.current = is_current
	dot.optional = not o.get("main", false)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(22, 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(dot)
	dot.position = Vector2(0, 3)
	row.add_child(holder)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var ink := Color(0.5, 0.58, 0.5) if done else (UiTheme.INK if is_current or not o.get("main", false) else Color(0.72, 0.76, 0.7))
	var title: String = o["title"]
	var pr: Array = Objectives.progress(o)
	if not pr.is_empty():
		title += "   (%d / %d)" % [pr[0], pr[1]]
	if Objectives.skipped(o):
		# Étape dépassée par la suite de l'aventure : elle reste à faire, sans bloquer.
		title += "   (étape passée)"
	var t := _label(head, title, 17, ink, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reward: String = o.get("reward", {}).get("text", "")
	if reward != "":
		var r := _label(head, reward, 13, UiTheme.GOLD if not done else Color(0.6, 0.55, 0.35))
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(col, o["text"], 13, Color(0.45, 0.5, 0.45) if done else Color(0.75, 0.82, 0.75))
	if is_current:
		var hl := UiTheme.box(Color(0.12, 0.16, 0.1, 0.8), Color(UiTheme.GOLD, 0.6), 1, 6)
		hl.content_margin_top = 4
		hl.content_margin_bottom = 4
		hl.content_margin_left = 8
		hl.content_margin_right = 8
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", hl)
		pc.add_child(row)
		_box.add_child(pc)
	else:
		_box.add_child(row)


func open() -> void:
	refresh()
	visible = true


func close() -> void:
	visible = false
