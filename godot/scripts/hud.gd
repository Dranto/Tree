## Interface en jeu : vie, expérience, points à placer, compétences et état du monde.
## Construite en nœuds Control ancrés aux bords : elle suit la taille de la fenêtre.
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const Content = preload("res://scripts/content.gd")

## Part du monde qu'il est possible de raviver (disque de l'arbre sur la carte carrée).
const REVIVABLE := 0.67
## Emplacements de compétences : au moins MIN_SLOTS affichés, au plus MAX_SLOTS.
const MIN_SLOTS := 4
const MAX_SLOTS := 6
const MARGIN := 20

var main
var banner_text := ""
var banner_time := 0.0
var hint_time := 12.0

var _labels := {}
var _level_label: Label
var _points_label: Label
var _world_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _xp_bar: ProgressBar
var _banner: Label
var _hint_box: VBoxContainer
var _slots: Array = []


## Un emplacement de compétence : aplat de couleur, voile de recharge, touche et nom.
class Slot extends PanelContainer:
	var skill_id := ""
	var color := Color.WHITE
	var owned := false
	var ratio := 0.0
	var icon: Control
	var key_label: Label
	var name_label: Label

	func _init() -> void:
		custom_minimum_size = Vector2(100, 76)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		add_child(box)
		icon = Control.new()
		icon.custom_minimum_size = Vector2(0, 30)
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.draw.connect(_draw_icon)
		box.add_child(icon)
		key_label = Label.new()
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 16)
		box.add_child(key_label)
		name_label = Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(name_label)

	func _draw_icon() -> void:
		var r := Rect2(Vector2.ZERO, icon.size)
		if not owned:
			icon.draw_string(UiTheme.font(), Vector2(0, r.size.y - 8), "—", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Color(0.5, 0.5, 0.5))
			return
		icon.draw_rect(r, color.darkened(0.6) if ratio > 0.0 else color)
		if ratio > 0.0:
			icon.draw_rect(Rect2(0, 0, r.size.x, r.size.y * ratio), Color(0, 0, 0, 0.45))

	func refresh() -> void:
		icon.queue_redraw()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.make()
	_build_top_left()
	_build_bottom_left()
	_build_bottom_center()
	_build_banner()
	_refresh()


func banner(s: String) -> void:
	banner_text = s
	banner_time = 3.0


## Nom de la touche selon la disposition du clavier du joueur (Z sur AZERTY pour « avancer »).
func key_label(action: String) -> String:
	if _labels.has(action):
		return _labels[action]
	var label := "?"
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			var key_ev := ev as InputEventKey
			if key_ev:
				var kc := key_ev.physical_keycode
				if DisplayServer.get_name() != "headless":
					kc = DisplayServer.keyboard_get_keycode_from_physical(kc)
				label = OS.get_keycode_string(kc)
				break
	_labels[action] = label
	return label


func _panel(anchor: Control.LayoutPreset, grow_h: Control.GrowDirection, grow_v: Control.GrowDirection) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_and_offsets_preset(anchor, Control.PRESET_MODE_MINSIZE, MARGIN)
	p.grow_horizontal = grow_h
	p.grow_vertical = grow_v
	var sb := UiTheme.box(Color(0.06, 0.08, 0.07, 0.8), Color(0.6, 0.8, 0.6, 0.2), 1, 4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	return p


func _label(parent: Node, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _bar(fill: Color, back: Color, height: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.step = 0.0
	b.custom_minimum_size = Vector2(320, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = back
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


func _build_top_left() -> void:
	var p := _panel(Control.PRESET_TOP_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	_level_label = _label(v, 20, UiTheme.INK)
	_points_label = _label(v, 15, UiTheme.GOLD)
	_world_label = _label(v, 13, Color(0.75, 0.85, 0.75))


func _build_bottom_left() -> void:
	var p := _panel(Control.PRESET_BOTTOM_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	_hp_bar = _bar(Color("c84b44"), Color(0.25, 0.08, 0.08), 20)
	v.add_child(_hp_bar)
	_hp_label = _label(_hp_bar, 13, Color.WHITE)
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_label.offset_left = 6
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_bar = _bar(Color("7fd36b"), Color(0.08, 0.15, 0.08), 10)
	v.add_child(_xp_bar)


func _build_bottom_center() -> void:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_END
	v.add_theme_constant_override("separation", 10)
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, MARGIN)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(v)
	_hint_box = VBoxContainer.new()
	_hint_box.add_theme_constant_override("separation", 4)
	v.add_child(_hint_box)
	for i in 2:
		var l := _label(_hint_box, 16, Color(0.9, 0.95, 0.85))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var ids: Array = Content.skills().keys().slice(0, MAX_SLOTS)
	for i in maxi(MIN_SLOTS, ids.size()):
		var s := Slot.new()
		if i < ids.size():
			s.skill_id = ids[i]
			s.color = Color(Content.skills()[ids[i]].get("color", "#ffffff"))
			s.name_label.text = Content.skills()[ids[i]].get("short", ids[i])
		row.add_child(s)
		_slots.append(s)


func _build_banner() -> void:
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 24)
	_banner.add_theme_color_override("font_color", Color(0.95, 0.92, 0.75))
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 140
	_banner.offset_bottom = 180
	add_child(_banner)


func _process(delta: float) -> void:
	banner_time -= delta
	hint_time -= delta
	_refresh()


func _refresh() -> void:
	if main == null or main.player == null:
		return
	var s: Dictionary = Game.stats
	var p = main.player
	var hp_ratio: float = clampf(p.hp / s["max_hp"], 0.0, 1.0)
	_hp_bar.value = hp_ratio
	_hp_label.text = "Vie %d / %d" % [roundi(p.hp), roundi(s["max_hp"])]
	_xp_bar.value = clampf(Game.xp / Game.xp_to_next(), 0.0, 1.0)

	_level_label.text = "Niveau %d" % Game.level
	_points_label.text = "Points de l'Arbre : %d  (%s)" % [Game.points, key_label("toggle_tree")]
	_points_label.add_theme_color_override("font_color", UiTheme.GOLD if Game.points > 0 else Color(0.7, 0.75, 0.7))
	var revived := minf(1.0, main.ground.ratio() / REVIVABLE)
	_world_label.text = "Monde ravivé : %.1f %%   ·   Flétris purifiés : %d" % [revived * 100.0, Game.kills]

	for s2 in _slots:
		var slot := s2 as Slot
		if slot.skill_id == "":
			slot.owned = false
			slot.key_label.text = ""
		else:
			slot.owned = Game.has_key(slot.skill_id)
			var cd: float = p.cds.get(slot.skill_id, 0.0)
			var maxcd: float = p.skill_cd.get(slot.skill_id, 1.0)
			slot.ratio = cd / maxcd if slot.owned and cd > 0.0 else 0.0
			slot.key_label.text = key_label("skill_" + slot.skill_id) if slot.owned else ""
			slot.name_label.text = Content.skills()[slot.skill_id].get("short", slot.skill_id) if slot.owned else "verrouillé"
		slot.name_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85) if slot.owned else Color(0.5, 0.5, 0.5))
		slot.refresh()

	_banner.text = banner_text
	_banner.modulate.a = clampf(banner_time, 0.0, 1.0)

	var show_hint := hint_time > 0.0 and Settings.show_hints
	_hint_box.modulate.a = clampf(hint_time / 2.0, 0.0, 1.0) if show_hint else 0.0
	var lines := [
		"%s %s %s %s : se déplacer   ·   Clic gauche : lancer des graines   ·   %s : esquive" % [key_label("move_up"), key_label("move_left"), key_label("move_down"), key_label("move_right"), key_label("dash")],
		"%s : ouvrir l'Arbre de vie. Chaque nœud appris ravive une région du monde." % key_label("toggle_tree"),
	]
	for i in 2:
		(_hint_box.get_child(i) as Label).text = lines[i]
