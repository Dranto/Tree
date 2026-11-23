## Journal (touche J) : les objectifs en cours et accomplis, avec leurs récompenses, rangés par région.
## Les objectifs communs (« L'aventure ») puis une section par région, dans l'ordre du monde, lue dans
## data/objectives.json (champ « region ») : une région ajoutée par ses fichiers a sa section d'elle-même.
## La section de l'objectif en cours est ouverte ; les autres se replient sur une ligne (avancement),
## et un clic sur leur titre les déplie.
## Nœuds Control avec le thème commun. Le jeu est en pause tant qu'il est ouvert (voir quest_ui.gd).
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const ControlsCard = preload("res://scripts/controls_card.gd")
const Regions = preload("res://scripts/regions.gd")
const RegionUi = preload("res://scripts/region_ui.gd")

var _panel: PanelContainer
var _scroll: ScrollContainer
var _box: VBoxContainer
var _subtitle: Label
## Sections dépliées ou repliées à la main (identifiant de région, "" : l'aventure) ; sans choix, seule
## celle de l'objectif en cours est dépliée.
var _manual: Dictionary = {}


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
		var col := UiTheme.LEAF if done else (UiTheme.GOLD if current else Color(0.553, 0.517, 0.434))
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
			var ink := Color(0.0713, 0.0667, 0.056)
			draw_polyline(PackedVector2Array([c + Vector2(-4, 0), c + Vector2(-1, 3.5), c + Vector2(5, -3.5)]), ink, 2.0)


## Petit triangle de section : pointe à droite (repliée) ou en bas (dépliée).
class Chevron extends Control:
	var open := false
	var color := Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(16, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var pts := PackedVector2Array([c + Vector2(-5, -3), c + Vector2(5, -3), c + Vector2(0, 4)]) if open \
			else PackedVector2Array([c + Vector2(-3, -5), c + Vector2(4, 0), c + Vector2(-3, 5)])
		draw_colored_polygon(pts, color)


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
	var sb := UiTheme.box(UiTheme.PANEL_BG, Color(UiTheme.GOLD, 0.3), 1, 10)
	sb.content_margin_top = 14
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	# Le contenu défile si plusieurs régions sont dépliées et dépassent l'écran (voir _fit).
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
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
	var multi := Regions.ids().size() > 1
	var purified := 0
	for id in Regions.ids():
		if bool(Game.flags.get(Regions.boss_flag(id), false)):
			purified += 1
	var sub := "%s : %d / %d objectifs principaux accomplis" % ["Aventure" if multi else "Tranche de Ronce", Objectives.main_done_count(), Objectives.main_total()]
	if multi:
		sub += "   ·   %d / %d régions purifiées" % [purified, Regions.ids().size()]
	_subtitle = _label(_box, sub, 14, Color(0.778, 0.727, 0.61))
	# La section dépliée par défaut est celle de la région que suit le joueur (Objectives.followed).
	var cur: Dictionary = Objectives.followed()
	var cur_region := RegionUi.journal_section(cur)
	# Sections : l'aventure (objectifs sans région), chaque région qui a des objectifs, puis « sous la
	# graine » (la finale : scellée tant que toutes les régions ne sont pas purifiées).
	var sections: Array = [""]
	for id in Regions.ids():
		sections.append(id)
	sections.append(RegionUi.UNDER_SEED_ID)
	for reg in sections:
		var rows: Array = Objectives.list().filter(func(o): return RegionUi.journal_section(o) == reg)
		if rows.is_empty():
			continue
		var is_open: bool = _manual.get(reg, reg == cur_region and not cur.is_empty())
		_add_section(reg, rows, is_open, cur)
	_label(_box, "COMMANDES", 12, UiTheme.SOFT)
	_box.add_child(ControlsCard.new(13))
	_label(_box, "J ou Échap : fermer   ·   M : carte", 12, Color(0.606, 0.567, 0.476))
	_fit()


## Le cadre prend la hauteur du contenu, sans dépasser l'écran (au-delà, le contenu défile).
func _fit() -> void:
	var need := _box.get_combined_minimum_size()
	_scroll.custom_minimum_size = Vector2(need.x, minf(need.y, maxf(200.0, size.y - 90.0)))
	_panel.reset_size()


## Une section : son titre (cliquable) avec l'avancement, puis, si elle est dépliée, ses objectifs
## principaux et facultatifs.
func _add_section(reg: String, rows: Array, is_open: bool, cur: Dictionary) -> void:
	var mains: Array = rows.filter(func(o): return o.get("main", false))
	var done := 0
	for o in mains:
		if Objectives.is_done(o["id"]):
			done += 1
	var under_seed: bool = reg == RegionUi.UNDER_SEED_ID
	var tint := RegionUi.UNDER_SEED_TINT if under_seed else (RegionUi.tint(reg).lightened(0.2) if reg != "" else Color(0.685, 0.64, 0.538))
	var title := "L'AVENTURE" if reg == "" else (RegionUi.UNDER_SEED_NAME.to_upper() if under_seed else RegionUi.full_name(reg).to_upper())
	var head := Button.new()
	head.flat = true
	head.focus_mode = Control.FOCUS_NONE
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 6)
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var chev := Chevron.new()
	chev.open = is_open
	chev.color = tint
	line.add_child(chev)
	var t := _label(line, title, 13, tint, true)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var state := RegionUi.finale_state() if under_seed else (RegionUi.state(reg) if reg != "" else "")
	var tail := "%d / %d" % [done, mains.size()] + ("   ·   " + state if state != "" else "")
	var r := _label(line, tail, 13, Color(0.671, 0.627, 0.526))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.custom_minimum_size = Vector2(0, 28)
	head.add_child(line)
	head.pressed.connect(func():
		_manual[reg] = not is_open
		refresh())
	_box.add_child(head)
	if not is_open:
		return
	for pass_main in [true, false]:
		var part: Array = rows.filter(func(o): return bool(o.get("main", false)) == pass_main)
		if part.is_empty():
			continue
		var sub := _label(_box, "OBJECTIFS PRINCIPAUX" if pass_main else "FACULTATIFS", 11, Color(0.571, 0.533, 0.448))
		sub.add_theme_constant_override("line_spacing", 0)
		for o in part:
			_add_row(o, not cur.is_empty() and cur["id"] == o["id"])


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
	var ink := Color(0.564, 0.527, 0.442) if done else (UiTheme.INK if is_current or not o.get("main", false) else Color(0.778, 0.727, 0.61))
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
	_label(col, o["text"], 13, Color(0.499, 0.467, 0.392) if done else UiTheme.SOFT)
	if is_current:
		var hl := UiTheme.box(Color(UiTheme.PAPER.lightened(0.08), 0.8), Color(UiTheme.GOLD, 0.6), 1, 6)
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
	_manual.clear()
	refresh()
	visible = true


func close() -> void:
	visible = false
