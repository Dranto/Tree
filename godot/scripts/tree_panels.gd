## Outils de l'écran de l'Arbre de vie : recherche, chemin au survol, aperçu des statistiques,
## résumé du build, mode plan et annulation. La logique est dans tree_planner.gd ; ici, seulement
## l'interface (nœuds Control avec UiTheme) et ce que l'écran de l'arbre doit dessiner en plus.
##
## Branchement dans tree_ui.gd (quelques appels) :
##   panels.click(id) / panels.right_click(id)   au lieu de Game.allocate / Game.refund
##   panels.draw_overlay()                        dans _draw, avec la transformation de l'arbre
##   panels.tooltip_lines(n, st)                  lignes ajoutées à l'infobulle
##   panels.captures_keys()                       vrai pendant la saisie dans la recherche
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const TreePlanner = preload("res://scripts/tree_planner.gd")

const PATH_OK := Color("7fd36b")
const PATH_SHORT := Color("e0675e")
const PLAN := Color("f2d06b")
const MATCH := Color("8fd8ff")
const DIM := Color(0.65, 0.72, 0.68)

## Écran de l'arbre (tree_ui.gd) : on lit hover, zoom, cam, t et RADIUS, et on dessine sur lui.
var ui
var planner
var plan_mode := false
var matches: Array = []
var match_set: Dictionary = {}
var match_index := -1

var search: LineEdit
var count_label: Label
var plan_button: Button
var undo_button: Button
var summary_button: Button
var plan_bar: PanelContainer
var plan_label: Label
var commit_button: Button
var summary_panel: PanelContainer
var summary_box: VBoxContainer
var message: Label
var message_time := 0.0

var _preview_key := ""
var _preview := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _theme()
	planner = TreePlanner.new(Game)
	planner.plan_changed.connect(_on_plan_changed)
	Game.tree_changed.connect(_on_tree_changed)

	var column := VBoxContainer.new()
	column.position = Vector2(16, 74)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar)
	search = LineEdit.new()
	search.placeholder_text = "Rechercher : nom, statistique, effet…"
	search.custom_minimum_size = Vector2(330, 0)
	search.clear_button_enabled = true
	search.context_menu_enabled = false
	search.text_changed.connect(_on_search_changed)
	search.text_submitted.connect(func(_t): next_match(-1 if Input.is_key_pressed(KEY_SHIFT) else 1))
	bar.add_child(search)
	count_label = Label.new()
	count_label.custom_minimum_size = Vector2(96, 0)
	count_label.add_theme_color_override("font_color", DIM)
	bar.add_child(count_label)
	_button(bar, "Précédent", func(): next_match(-1))
	_button(bar, "Suivant", func(): next_match(1))
	plan_button = _button(bar, "Mode plan", Callable())
	plan_button.toggle_mode = true
	plan_button.toggled.connect(set_plan_mode)
	undo_button = _button(bar, "Annuler", undo)
	summary_button = _button(bar, "Résumé", Callable())
	summary_button.toggle_mode = true
	summary_button.toggled.connect(set_summary_visible)

	plan_bar = PanelContainer.new()
	plan_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(plan_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	plan_bar.add_child(row)
	plan_label = Label.new()
	row.add_child(plan_label)
	commit_button = _button(row, "Valider le plan", commit_plan)
	_button(row, "Effacer", func(): planner.plan_clear())

	message = Label.new()
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.add_theme_color_override("font_color", UiTheme.GOLD)
	message.add_theme_font_size_override("font_size", 18)
	column.add_child(message)

	summary_panel = PanelContainer.new()
	summary_panel.visible = false
	summary_panel.anchor_left = 1.0
	summary_panel.anchor_right = 1.0
	summary_panel.anchor_bottom = 1.0
	summary_panel.offset_left = -396.0
	summary_panel.offset_right = -16.0
	summary_panel.offset_top = 74.0
	summary_panel.offset_bottom = -16.0
	add_child(summary_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summary_panel.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 16)
	scroll.add_child(margin)
	summary_box = VBoxContainer.new()
	summary_box.add_theme_constant_override("separation", 4)
	margin.add_child(summary_box)

	_refresh()


func _theme() -> Theme:
	var t: Theme = UiTheme.make()
	t.default_font_size = 15
	var normal: StyleBoxFlat = UiTheme.box(Color(0.1, 0.13, 0.11, 0.95), Color(0.6, 0.8, 0.6, 0.25))
	var focus: StyleBoxFlat = UiTheme.box(Color(0.1, 0.13, 0.11, 0.95), UiTheme.GOLD)
	for sb in [normal, focus]:
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
	t.set_stylebox("normal", "LineEdit", normal)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", UiTheme.INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.6, 0.66, 0.62, 0.8))
	t.set_color("caret_color", "LineEdit", UiTheme.GOLD)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = t.get_stylebox(state, "Button").duplicate()
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		t.set_stylebox(state, "Button", sb)
	var panel: StyleBoxFlat = UiTheme.box(Color(0.06, 0.08, 0.07, 0.96), Color(0.6, 0.8, 0.6, 0.3), 1, 8)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	t.set_stylebox("panel", "PanelContainer", panel)
	return t


func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if action.is_valid():
		b.pressed.connect(action)
	parent.add_child(b)
	return b


# --- Clavier ---

## Vrai pendant la saisie dans la recherche : l'écran de l'arbre ne doit pas se fermer sur « T ».
func captures_keys() -> bool:
	return search != null and is_visible_in_tree() and search.has_focus()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and search.has_focus() and not search.get_global_rect().has_point(mb.position):
		search.release_focus()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if search.has_focus():
		if key.keycode == KEY_ESCAPE:
			search.release_focus()
			get_viewport().set_input_as_handled()
		return
	if key.is_command_or_control_pressed() and key.keycode == KEY_F:
		search.grab_focus()
		search.select_all()
		get_viewport().set_input_as_handled()
	elif key.is_command_or_control_pressed() and key.keycode == KEY_Z:
		undo()
		get_viewport().set_input_as_handled()
	elif (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER) and not matches.is_empty():
		next_match(-1 if key.shift_pressed else 1)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		undo_button.disabled = not planner.can_undo()
	if message_time > 0.0:
		message_time -= delta
		message.modulate.a = clampf(message_time, 0.0, 1.0)
		if message_time <= 0.0:
			message.text = ""


func say(text: String) -> void:
	message.text = text
	message.modulate.a = 1.0
	message_time = 3.5


# --- Recherche ---

func set_query(text: String) -> void:
	search.text = text
	_on_search_changed(text)


func _on_search_changed(text: String) -> void:
	matches = planner.search(text)
	match_set = {}
	for id in matches:
		match_set[id] = true
	match_index = -1
	_refresh()
	ui.queue_redraw()


## Centre la caméra sur le résultat suivant (ou précédent) de la recherche.
func next_match(step := 1) -> void:
	if matches.is_empty():
		return
	match_index = posmod(match_index + step, matches.size()) if match_index >= 0 else (0 if step > 0 else matches.size() - 1)
	var n: Dictionary = Game.tree.nodes[matches[match_index]]
	ui.cam = n["pos"]
	if ui.zoom < 0.5:
		ui.zoom = 0.8
	_refresh()
	ui.queue_redraw()


# --- Clics relayés par l'écran de l'arbre ---

func click(id: int) -> void:
	if Game.allocated.has(id):
		return
	if plan_mode:
		if planner.plan_has(id):
			var removed: int = planner.plan_remove(id)
			say("%d nœud(s) retiré(s) du plan" % removed)
		else:
			var added: int = planner.plan_add(id)
			say("%d nœud(s) ajouté(s) au plan" % added)
		return
	var path: Array = planner.path_to(id)
	if path.is_empty():
		return
	if not planner.learn_path(path):
		var missing: int = path.size() - Game.points
		say("Il manque %d point(s) pour ce chemin de %d nœud(s). Le mode plan permet de le préparer." % [missing, path.size()])
	elif path.size() > 1:
		say("%d nœuds appris d'un coup" % path.size())


func right_click(id: int) -> void:
	if planner.plan_has(id):
		planner.plan_remove(id)
	elif Game.allocated.has(id):
		if not planner.forget(id) and id != 0:
			say("Ce nœud en relie d'autres à la graine : oublie d'abord ceux-là.")


func undo() -> void:
	var what: String = planner.undo_label()
	if planner.undo():
		say("Annulé : " + what)


func set_plan_mode(on: bool) -> void:
	plan_mode = on
	plan_button.set_pressed_no_signal(on)
	_preview_key = ""
	_refresh()
	ui.queue_redraw()


func commit_plan() -> void:
	var n: int = planner.plan_cost()
	if planner.plan_commit():
		say("Plan validé : %d nœuds appris" % n)
		set_plan_mode(false)


func set_summary_visible(on: bool) -> void:
	summary_panel.visible = on
	summary_button.set_pressed_no_signal(on)
	_refresh()


func _on_tree_changed() -> void:
	planner.sync()
	_preview_key = ""
	_refresh()


func _on_plan_changed() -> void:
	_preview_key = ""
	_refresh()
	if ui != null:
		ui.queue_redraw()
	# Le plan vit dans Game.flags : on demande une sauvegarde automatique à la scène de jeu.
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene != null and scene.has_method("request_autosave"):
		scene.request_autosave()


# --- Aperçu du nœud survolé ---

## Chemin et différences de statistiques pour le nœud survolé, recalculés seulement quand
## le survol, l'arbre ou le plan changent.
func _preview_for(id: int) -> Dictionary:
	var key := "%d/%d/%d/%d/%s" % [id, Game.allocated.size(), Game.points, planner.plan.size(), plan_mode]
	if key == _preview_key:
		return _preview
	_preview_key = key
	_preview = {"route": [], "path": [], "changes": []}
	if id < 0 or Game.allocated.has(id):
		return _preview
	if planner.plan_has(id):
		_preview["changes"] = planner.preview(planner.plan)
		return _preview
	var route: Array = planner.route_to(id, plan_mode)
	_preview["route"] = route
	_preview["path"] = route.slice(1)
	_preview["changes"] = planner.preview((planner.plan if plan_mode else []) + _preview["path"])
	return _preview


## Lignes [texte, taille, couleur] ajoutées à l'infobulle d'un nœud : différences de statistiques
## (avant → après), coût du chemin et ce que fait le clic.
func tooltip_lines(n: Dictionary, st: String) -> Array:
	var lines: Array = []
	var id: int = n["id"]
	if st == "owned":
		var ok: bool = Game.can_refund(id)
		lines.append(["Appris" + ("  ·  clic droit pour l'oublier" if ok else ""), 13, UiTheme.LEAF])
		return lines
	var p := _preview_for(id)
	var count: int = p["path"].size()
	var planned: bool = planner.plan_has(id)
	if not p["changes"].is_empty():
		var title := "Après ce nœud :"
		if planned:
			title = "Après tout le plan (%d nœuds) :" % planner.plan_cost()
		elif plan_mode and planner.plan_cost() > 0:
			title = "Après le plan et ce chemin (%d nœuds) :" % (planner.plan_cost() + count)
		elif count > 1:
			title = "Après ce chemin (%d nœuds) :" % count
		lines.append([title, 13, DIM])
		for c in p["changes"]:
			lines.append(["   " + c["text"], 14, PLAN])
	if planned:
		lines.append(["Dans le plan  ·  clic pour l'en retirer", 13, PLAN])
	elif plan_mode:
		lines.append(["Clic pour ajouter au plan (%d nœud(s), %d point(s))" % [count, count], 13, PLAN])
	elif count <= Game.points:
		if count == 1:
			lines.append(["Clic pour apprendre (1 point)", 13, UiTheme.GOLD])
		else:
			lines.append(["Chemin de %d nœuds, %d points  ·  clic pour tout apprendre" % [count, count], 13, UiTheme.GOLD])
	elif Game.points <= 0 and count == 1:
		lines.append(["Pas de point disponible : monte de niveau", 13, PATH_SHORT])
	else:
		lines.append(["Chemin de %d nœuds : il te manque %d point(s)" % [count, count - Game.points], 13, PATH_SHORT])
	return lines


# --- Dessin sur l'écran de l'arbre ---

## À appeler dans tree_ui._draw, transformation de l'arbre active, après les nœuds :
## dessine le plan, le chemin vers le nœud survolé et les résultats de la recherche.
func draw_overlay() -> void:
	var nodes: Array = Game.tree.nodes
	var z: float = ui.zoom
	var w := maxf(4.0, 3.0 / z)
	# Plan : tirets dorés.
	for id in planner.plan:
		_link(nodes[planner.plan_parent(id)], nodes[id], PLAN, w, true)
	for id in planner.plan:
		_ring(nodes[id], 5.0, PLAN, w)
	# Chemin vers le nœud survolé.
	var hover: int = ui.hover
	if hover >= 0:
		var p := _preview_for(hover)
		var route: Array = p["route"]
		if route.size() > 2 or (plan_mode and route.size() > 1):
			var col := PLAN if plan_mode else (PATH_OK if route.size() - 1 <= Game.points else PATH_SHORT)
			for i in range(1, route.size()):
				_link(nodes[route[i - 1]], nodes[route[i]], col, w, false)
				_ring(nodes[route[i]], 5.0, col, w)
	# Résultats de la recherche.
	for id in matches:
		_ring(nodes[id], 9.0, MATCH, w)
	if match_index >= 0 and match_index < matches.size():
		var pulse: float = 0.5 + 0.5 * sin(ui.t * 5.0)
		_ring(nodes[matches[match_index]], 16.0 + 6.0 * pulse, Color.WHITE, w)


func _radius(n: Dictionary) -> float:
	return ui.RADIUS[n["type"]]


func _ring(n: Dictionary, margin: float, col: Color, w: float) -> void:
	ui.draw_arc(n["pos"], _radius(n) + margin + w * 0.5, 0.0, TAU, 40, col, w, true)


## Trait entre deux nœuds, arrêté au bord de chacun pour ne pas les recouvrir.
func _link(a: Dictionary, b: Dictionary, col: Color, w: float, dashed: bool) -> void:
	var d: Vector2 = b["pos"] - a["pos"]
	var l := d.length()
	var ra := _radius(a) + 3.0
	var rb := _radius(b) + 3.0
	if l <= ra + rb:
		return
	var from: Vector2 = a["pos"] + d / l * ra
	var to: Vector2 = b["pos"] - d / l * rb
	if dashed:
		ui.draw_dashed_line(from, to, col, w, maxf(10.0, 8.0 / ui.zoom))
	else:
		ui.draw_line(from, to, col, w, true)


# --- Mise à jour des panneaux ---

func _refresh() -> void:
	if count_label == null:
		return
	if search.text.strip_edges() == "":
		count_label.text = ""
	elif matches.is_empty():
		count_label.text = "aucun"
	elif match_index >= 0:
		count_label.text = "%d / %d" % [match_index + 1, matches.size()]
	else:
		count_label.text = "%d trouvé(s)" % matches.size()
	undo_button.disabled = not planner.can_undo()
	var cost: int = planner.plan_cost()
	plan_bar.visible = plan_mode or cost > 0
	commit_button.disabled = cost == 0 or planner.plan_missing() > 0
	if cost == 0:
		plan_label.text = "Mode plan : clique des nœuds pour tracer un chemin sans dépenser de points."
	elif planner.plan_missing() > 0:
		plan_label.text = "Plan : %d nœuds, %d points. Il t'en manque %d." % [cost, cost, planner.plan_missing()]
	else:
		plan_label.text = "Plan : %d nœuds, %d points. Tu as de quoi le valider." % [cost, cost]
	if summary_panel.visible:
		_fill_summary()


func _fill_summary() -> void:
	for c in summary_box.get_children():
		summary_box.remove_child(c)
		c.queue_free()
	var now: Dictionary = planner.summary()
	var with_plan: bool = planner.plan_cost() > 0
	var later: Dictionary = planner.summary(planner.plan) if with_plan else now

	_text("Résumé du build", 20, UiTheme.GOLD)
	var head := "%d nœuds appris sur %d  ·  %d point(s) à placer" % [now["nodes"], now["total"], now["points"]]
	_text(head, 13, DIM)
	if with_plan:
		_text("Les valeurs après « → » tiennent compte du plan (%d nœuds)." % planner.plan_cost(), 13, PLAN)

	_section("Branches")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	summary_box.add_child(grid)
	for i in now["branches"].size():
		var b: Dictionary = now["branches"][i]
		var planned: int = later["branches"][i]["count"]
		var name := Label.new()
		name.text = b["name"]
		name.add_theme_color_override("font_color", b["color"])
		name.custom_minimum_size = Vector2(70, 0)
		grid.add_child(name)
		var gauge := ProgressBar.new()
		gauge.show_percentage = false
		gauge.max_value = maxi(1, b["total"])
		gauge.value = planned
		gauge.custom_minimum_size = Vector2(150, 10)
		gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.12, 0.15, 0.13)
		var fill := StyleBoxFlat.new()
		fill.bg_color = b["color"]
		gauge.add_theme_stylebox_override("background", bg)
		gauge.add_theme_stylebox_override("fill", fill)
		grid.add_child(gauge)
		var num := Label.new()
		num.text = "%d → %d / %d" % [b["count"], planned, b["total"]] if planned != b["count"] else "%d / %d" % [b["count"], b["total"]]
		num.add_theme_color_override("font_color", PLAN if planned != b["count"] else UiTheme.INK)
		grid.add_child(num)

	_section("Compétences")
	if later["skills"].is_empty():
		_text("Aucune pour l'instant : elles viennent des nœuds clés.", 14, DIM)
	for s in later["skills"]:
		_text(s + ("" if now["skills"].has(s) else "  (plan)"), 14, UiTheme.INK if now["skills"].has(s) else PLAN)

	_section("Nœuds clés")
	if later["keystones"].is_empty():
		_text("Aucun pour l'instant.", 14, DIM)
	for i in later["keystones"].size():
		var k: Dictionary = later["keystones"][i]
		var owned: bool = now["keystones"].any(func(o): return o["name"] == k["name"])
		_text(k["name"] + ("" if owned else "  (plan)"), 14, Game.tree.branch_color(k["branch"]))

	_section("Statistiques")
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 12)
	summary_box.add_child(stats)
	for i in now["stats"].size():
		var s: Dictionary = now["stats"][i]
		var after: String = later["stats"][i]["value"]
		var label := Label.new()
		label.text = s["label"]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(200, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", UiTheme.INK if s["changed"] or after != s["value"] else DIM)
		stats.add_child(label)
		var value := Label.new()
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", 14)
		if after != s["value"]:
			value.text = "%s → %s" % [s["value"], after]
			value.add_theme_color_override("font_color", PLAN)
		else:
			value.text = s["value"]
			value.add_theme_color_override("font_color", UiTheme.LEAF if s["changed"] else DIM)
		stats.add_child(value)


func _section(title: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	summary_box.add_child(gap)
	_text(title, 16, UiTheme.GOLD)


func _text(text: String, font_size: int, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	summary_box.add_child(l)
