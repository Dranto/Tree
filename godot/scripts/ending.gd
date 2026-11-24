## Écran plein de fin (le monde reverdit, un texte, les statistiques, puis « Continuer à jouer » ou
## « Retour au titre »). Depuis le jalon 10, il ne sert plus que de base à l'épilogue de la finale
## (epilogue.gd) : un boss régional vaincu lance une célébration sur place, sans pause
## (region_fanfare.gd). Ci-dessous, la description d'origine de la séquence.
## Les textes viennent de la région (« ending » de data/regions/<id>.json) ; quand toutes les
## régions sont purifiées, c'est la fin de l'aventure (Objectives.ending_texts). Tout est dessiné
## par le code (voir _draw) ; les textes et les boutons sont des nœuds Control avec le thème commun.
## Se déclenche une seule fois par région : Game.flags["<région>_fin_vue"] est posé dès le début de
## la séquence (Objectives.mark_ending_seen).
extends Control

## La séquence est refermée (« Continuer à jouer »).
signal closed

const UiTheme = preload("res://scripts/ui_theme.gd")
const Regions = preload("res://scripts/regions.gd")

## Instants (secondes) où chaque élément apparaît.
const T_TITLE := 3.5
const T_BODY := 5.0
const T_STATS := 7.5
const T_END := 9.0

var main
var t := 0.0
var active := false
var stats: Array = []
## Région purifiée et textes montrés ({sub, title, body}).
var region := ""
var texts: Dictionary = {}

var _left: VBoxContainer
var _title: Label
var _sub: Label
var _body: Label
var _right: PanelContainer
var _continue: Button
var _focused := false
var _motes: Array = []
## Toutes les branches de l'arbre en fleurs (l'épilogue, epilogue.gd), pas seulement la première.
var all_lush := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.make()
	visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 46:
		_motes.append({"x": rng.randf(), "y": rng.randf(), "s": rng.randf_range(0.015, 0.05), "r": rng.randf_range(1.5, 3.5), "p": rng.randf() * TAU})
	_build()


## Construit les textes et les boutons (avec les statistiques lues au début de la séquence).
func _build() -> void:
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 10)
	_left.anchor_left = 0.05
	_left.anchor_right = 0.30
	_left.anchor_top = 0.14
	_left.grow_vertical = Control.GROW_DIRECTION_END
	add_child(_left)
	_sub = _label(_left, str(texts.get("sub", "Région purifiée")), 16, Color(0.8, 0.88, 0.8))
	_title = _label(_left, str(texts.get("title", "La région reverdit")), 36, UiTheme.GOLD, true)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = 300.0
	_body = _label(_left, str(texts.get("body", "")), 16, Color(0.9, 0.93, 0.85))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 300.0

	_right = PanelContainer.new()
	_right.anchor_left = 0.70
	_right.anchor_right = 0.95
	_right.anchor_top = 0.14
	_right.grow_vertical = Control.GROW_DIRECTION_END
	add_child(_right)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_right.add_child(v)
	_label(v, "TA PARTIE", 14, UiTheme.SOFT)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for pair in stats:
		var a := _label(grid, pair[0], 15, UiTheme.SOFT)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := _label(grid, pair[1], 15, UiTheme.INK, true)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(Control.new())
	_continue = UiTheme.button("Continuer à jouer", 240.0)
	_continue.pressed.connect(_on_continue)
	v.add_child(_continue)
	var to_title := UiTheme.button("Retour au titre", 240.0)
	to_title.pressed.connect(Flow.go_title)
	v.add_child(to_title)
	_apply()


func _label(parent: Node, text: String, size_px: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiTheme.fs(size_px))
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UiTheme.font(true))
	parent.add_child(l)
	return l


## Les statistiques de la partie, lues au moment où la séquence commence.
static func collect_stats(m) -> Array:
	var secs := int(m.elapsed)
	var time_text := ("%d h %02d min" % [secs / 3600, (secs % 3600) / 60]) if secs >= 3600 else ("%d min %02d s" % [secs / 60, secs % 60])
	return [
		["Temps de jeu", time_text],
		["Morts", str(Objectives.deaths_total())],
		["Niveau atteint", str(Game.level)],
		["Nœuds appris", str(Game.allocated.size() - 1)],
		["Greffes posées", str(Game.placed_grafts().size())],
		["Flétris purifiés", str(Game.kills)],
		["Monde ravivé", "%d %%" % roundi(minf(1.0, m.ground.ratio() / 0.67) * 100.0)],
	]


## Lance la séquence de la région (par défaut, celle qui est due) : drapeau posé (elle ne reviendra
## pas), sauvegarde, jeu en pause.
func begin(m, reg := "") -> void:
	main = m
	region = reg if reg != "" else Objectives.ending_region()
	if region == "":
		region = Regions.ids()[0] if not Regions.ids().is_empty() else ""
	texts = Objectives.ending_texts(region)
	stats = collect_stats(m)
	Objectives.mark_ending_seen(region)
	m.save_game()
	for c in get_children():
		remove_child(c)
		c.free()
	_build()
	active = true
	visible = true
	t = 0.0
	_focused = false
	get_tree().paused = true
	Sfx.play("coeur")
	_apply()


func _on_continue() -> void:
	active = false
	visible = false
	get_tree().paused = false
	closed.emit()


## Avance la séquence à un instant donné (tests visuels).
func set_time(seconds: float) -> void:
	t = seconds
	_apply()


func _input(event: InputEvent) -> void:
	if not visible or not active:
		return
	var press: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)
	if press and t < T_END:
		# Un appui passe la séquence : les textes et les boutons apparaissent aussitôt.
		t = T_END
		_apply()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	_apply()
	if t >= T_END and not _focused and is_instance_valid(_continue):
		_focused = true
		_continue.grab_focus()
	queue_redraw()


func _fade(from: float, to := 1.0) -> float:
	return clampf((t - from) / 1.4, 0.0, 1.0) * to


func _apply() -> void:
	if _title == null:
		return
	_sub.modulate.a = _fade(T_TITLE)
	_title.modulate.a = _fade(T_TITLE)
	_body.modulate.a = _fade(T_BODY)
	_right.modulate.a = _fade(T_STATS)
	_right.mouse_filter = Control.MOUSE_FILTER_STOP if t >= T_END else Control.MOUSE_FILTER_IGNORE
	for b in _right.find_children("*", "Button", true, false):
		(b as Button).disabled = t < T_END
	queue_redraw()
	UiAudit.begin("fin")
	UiAudit.scan_controls("fin", self)


# --- Dessin : le monde reverdit ---

func _draw() -> void:
	var s := size
	var fade := clampf(t / 1.6, 0.0, 1.0)
	var dawn := smoothstep(1.5, 9.0, t)
	var u := s.y / 720.0
	# Ciel : de la nuit cendreuse à l'aube.
	var top := Color(0.03, 0.05, 0.08).lerp(Color(0.1, 0.24, 0.32), dawn)
	var low := Color(0.07, 0.09, 0.1).lerp(Color(0.95, 0.8, 0.5), dawn * 0.9)
	var horizon := s.y * 0.8
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, horizon), Vector2(0, horizon)]),
		PackedColorArray([Color(top, fade), Color(top, fade), Color(low, fade), Color(low, fade)]))
	# Soleil bas : quelques disques empilés pour la lueur.
	var sun := Vector2(s.x * 0.5, horizon - 36.0 * u)
	for i in 6:
		draw_circle(sun, (230.0 - 30.0 * i) * u * (0.4 + 0.6 * dawn), Color(1.0, 0.9, 0.6, 0.05 * dawn * fade))
	# Collines : trois plans, de la cendre au vert.
	var greens := [Color(0.3, 0.55, 0.3), Color(0.24, 0.46, 0.25), Color(0.17, 0.36, 0.2)]
	for layer in 3:
		var base := horizon - (26.0 - layer * 14.0) * u
		var ash := Color(0.13, 0.12, 0.14).lerp(Color(0.08, 0.08, 0.09), layer / 2.0)
		var col := ash.lerp(greens[layer], dawn)
		var pts := PackedVector2Array()
		for i in 41:
			var x := s.x * i / 40.0
			pts.append(Vector2(x, base + 16.0 * u * sin(x / (130.0 * u) + layer * 1.7) + 8.0 * u * sin(x / (47.0 * u) + layer)))
		pts.append(Vector2(s.x, s.y))
		pts.append(Vector2(0, s.y))
		draw_colored_polygon(pts, Color(col, fade))
	# L'Arbre de vie : il pousse, puis ses six branches fleurissent (Ronce la première).
	var g := smoothstep(1.5, 8.5, t)
	var base_pos := Vector2(s.x * 0.5, horizon + 6.0 * u)
	var trunk_len := s.y * 0.17
	_draw_tree(base_pos, trunk_len, g, u, fade)
	# Lucioles.
	var glow := smoothstep(4.0, 9.0, t) * fade
	for m in _motes:
		var p := Vector2(m["x"] * s.x, fmod(m["y"] + 1.0 - m["s"] * t * 0.3, 1.0) * s.y * 0.85)
		draw_circle(p, m["r"] * u, Color(1.0, 0.95, 0.6, 0.55 * glow * (0.5 + 0.5 * sin(t * 2.0 + m["p"]))))


func _draw_tree(base: Vector2, trunk_len: float, g: float, u: float, fade: float) -> void:
	var branch_count: int = Game.tree.BRANCHES.size()
	var max_depth := 5
	var trunk_top := base + Vector2(0, -trunk_len * clampf(g * 4.0, 0.0, 1.0))
	var bark := Color(0.34, 0.24, 0.17, fade)
	draw_line(base, trunk_top, bark, 14.0 * u, true)
	if g < 0.25:
		return
	var leaf_t := smoothstep(5.5, 9.5, t)
	for bi in branch_count:
		# Les six branches en éventail, dans l'ordre de l'arbre ; la plus proche de la verticale pousse en haut.
		var frac := (bi + 0.5) / branch_count - 0.5
		var ang := -PI / 2.0 + frac * 2.1
		var lush := bi == 0 or all_lush
		var col: Color = Game.tree.branch_color(bi)
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + bi
		_grow(trunk_top, ang, trunk_len * 0.78, 9.0 * u, 0, max_depth, g, u, fade, col, lush, leaf_t, rng, bark)


func _grow(from: Vector2, ang: float, length: float, width: float, depth: int, max_depth: int, g: float, u: float, fade: float, col: Color, lush: bool, leaf_t: float, rng: RandomNumberGenerator, bark: Color) -> void:
	var frac := clampf(g * float(max_depth + 2) - float(depth) - 1.0, 0.0, 1.0)
	if frac <= 0.0:
		return
	var to := from + Vector2.from_angle(ang) * length * frac
	draw_line(from, to, bark.lerp(col.darkened(0.3), float(depth) / max_depth * 0.6), maxf(1.5, width), true)
	if frac < 1.0:
		return
	if depth >= max_depth - 1:
		var r := (7.0 if lush else 4.0) * u * leaf_t
		draw_circle(to, r * 1.15, Color(col.lightened(0.15), (0.9 if lush else 0.4) * leaf_t * fade))
		return
	for k in 2:
		var turn := rng.randf_range(0.3, 0.6) * (1.0 if k == 0 else -1.0)
		_grow(to, ang + turn, length * rng.randf_range(0.68, 0.8), width * 0.68, depth + 1, max_depth, g, u, fade, col, lush, leaf_t, rng, bark)
