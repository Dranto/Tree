## Interface en jeu : vie, expérience, points à placer, compétences et état du monde.
## Construite en nœuds Control ancrés aux bords : elle suit la taille de la fenêtre.
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const Content = preload("res://scripts/content.gd")
const DeathScreen = preload("res://scripts/death_screen.gd")

## Part du monde qu'il est possible de raviver (disque de l'arbre sur la carte carrée).
const REVIVABLE := 0.67
## Emplacements de compétences : toujours MAX_SLOTS affichés, dont skill_slots débloqués
## (4 au départ) ; un emplacement vide est « libre », un emplacement pas encore débloqué « verrouillé ».
const MAX_SLOTS := 6
const MARGIN := 20

var main
var banner_text := ""
var banner_time := 0.0
## Annonces en attente : une annonce ne coupe pas celle qui vient d'apparaître.
var banner_queue: Array = []
var hint_time := 12.0

var _labels := {}
var _corner
var _vital
var _banner: Label
var _hint_box: VBoxContainer
var _slots: Array = []
## Écran de mort et flèche vers la sève perdue (death_screen.gd).
var death_screen


const Widgets = preload("res://scripts/hud_widgets.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.make()
	_build_top_left()
	_build_bottom_left()
	_build_bottom_center()
	_build_banner()
	death_screen = DeathScreen.new()
	death_screen.main = main
	add_child(death_screen)
	Settings.changed.connect(func(): _labels.clear())
	Game.points_granted.connect(_on_points_granted)
	Game.graft_found.connect(_on_graft_found)
	_refresh()


## Affiche une annonce en haut de l'écran. Si une autre vient d'apparaître, celle-ci attend son tour.
func banner(s: String) -> void:
	if banner_time > 1.2 and banner_text != s:
		if not banner_queue.has(s):
			banner_queue.append(s)
		return
	banner_text = s
	banner_time = 3.0


## Écran de mort (voir death_screen.gd et main.player_died).
func show_death(info: Dictionary) -> void:
	death_screen.show_death(info)
## Points d'arbre gagnés hors niveau : la source et le nombre de points.
func _on_points_granted(n: int, source: String) -> void:
	banner("%s : +%d point%s de l'Arbre de vie (%s)" % [Game.point_source_label(source), n, "s" if n > 1 else "", key_label("toggle_tree")])


func _on_graft_found(id: String) -> void:
	var g: Dictionary = Content.grafts().get(id, {})
	banner("Greffe trouvée : %s. Pose-la dans l'Arbre de vie (%s)" % [g.get("name", id), key_label("toggle_tree")])


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


func _label(parent: Node, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _build_top_left() -> void:
	# Pas de cadre : le coin n'est qu'un médaillon et trois repères sur le jeu.
	_corner = Widgets.Corner.new()
	_corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	add_child(_corner)


func _build_bottom_left() -> void:
	_vital = Widgets.Vital.new()
	_vital.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN)
	_vital.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_vital)


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
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for i in MAX_SLOTS:
		var s := Widgets.Slot.new()
		s.index = i
		s.gui_input.connect(_on_slot_input.bind(i))
		row.add_child(s)
		_slots.append(s)


## Clic sur un emplacement débloqué : y mettre une compétence acquise restée sans place.
func _on_slot_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and main and main.player:
		main.player.cycle_slot(i)


## Touches d'un emplacement : la touche choisie dans les options et le chiffre (« A · 1 »).
func slot_keys_text(i: int) -> String:
	var digit := str(i + 1)
	var k: int = Settings.slot_keys[i]
	return digit if k == KEY_NONE else "%s · %s" % [Settings.key_name(k), digit]


func _build_banner() -> void:
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 24)
	_banner.add_theme_color_override("font_color", Color(0.95, 0.92, 0.75))
	# Le cadre épouse le texte, centré : un cadre pleine largeur passait sous le suivi des
	# objectifs (en haut à droite) et l'audit d'interface y voyait un chevauchement.
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 140
	_banner.offset_bottom = 180
	add_child(_banner)


func _process(delta: float) -> void:
	banner_time -= delta
	if banner_time <= 0.2 and not banner_queue.is_empty():
		banner_text = banner_queue.pop_front()
		banner_time = 3.0
	hint_time -= delta
	_refresh()


func _refresh() -> void:
	if main == null or main.player == null:
		return
	var s: Dictionary = Game.stats
	var p = main.player
	var hp_ratio: float = clampf(p.hp / s["max_hp"], 0.0, 1.0)
	_vital.set_value(hp_ratio, "%d / %d" % [roundi(p.hp), roundi(s["max_hp"])])
	var revived := minf(1.0, main.ground.ratio() / REVIVABLE)
	_corner.set_values(Game.level, clampf(Game.xp / Game.xp_to_next(), 0.0, 1.0), Game.points, key_label("toggle_tree"), revived, Game.kills)

	var open: int = p.unlocked_slots()
	for s2 in _slots:
		var slot := s2 as Widgets.Slot
		var i: int = slot.index
		var id: String = p.bar[i] if i < p.bar.size() else ""
		if i >= open:
			slot.name_label.text = "verrouillé"
			slot.apply(Widgets.Slot.LOCKED, "", 0.0, 0.0, "", "")
		elif id == "":
			slot.name_label.text = "libre"
			slot.apply(Widgets.Slot.FREE, "", 0.0, 0.0, slot_keys_text(i), "Emplacement libre")
		else:
			var k: Dictionary = Content.skills()[id]
			var cd: float = p.cds.get(id, 0.0)
			var maxcd: float = maxf(0.01, p.skill_cd.get(id, 1.0))
			slot.name_label.text = k.get("short", id)
			slot.apply(Widgets.Slot.SKILL, id, cd / maxcd if cd > 0.0 else 0.0, cd, slot_keys_text(i), "%s\n%s" % [k.get("name", id), k.get("desc", "")])

	if _banner.text != banner_text:
		_banner.text = banner_text
		var w := _banner.get_minimum_size().x
		_banner.offset_left = -w / 2.0
		_banner.offset_right = w / 2.0
	_banner.modulate.a = clampf(banner_time, 0.0, 1.0)

	var show_hint := hint_time > 0.0 and Settings.show_hints
	_hint_box.modulate.a = clampf(hint_time / 2.0, 0.0, 1.0) if show_hint else 0.0
	var lines := [
		"%s %s %s %s : se déplacer   ·   Clic gauche : lancer des graines   ·   %s : esquive" % [key_label("move_up"), key_label("move_left"), key_label("move_down"), key_label("move_right"), key_label("dash")],
		"%s : ouvrir l'Arbre de vie. Chaque nœud appris ravive une région du monde." % key_label("toggle_tree"),
	]
	for i in 2:
		(_hint_box.get_child(i) as Label).text = lines[i]
