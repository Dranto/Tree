## Arbre de vie à la manette (jalon 11) : enfant de tree_ui.gd, actif quand la dernière entrée vient
## d'une manette (Settings.pad_active()).
##
## Trois zones, LB et RB passent de l'une à l'autre :
## - « arbre » : le stick gauche (ou la croix) saute de nœud en nœud (le voisin le plus proche dans
##   la direction poussée, à défaut le nœud visible le plus proche dans ce cône) ; le stick droit
##   promène un curseur libre, aimanté par les nœuds, et la vue le suit au bord ; gâchettes : zoom
##   autour du curseur ; A apprend (ou ouvre le choix d'une maîtrise), X oublie, Y ouvre la
##   recherche, clic du stick droit : vue d'ensemble ; B ferme l'arbre ;
## - « outils » : la barre d'outils (recherche, précédent, suivant, mode plan, annuler, résumé, vue
##   d'ensemble, et la barre du plan quand elle est ouverte) ; la croix choisit, A presse ;
## - « couronne » : les emplacements ouverts puis les greffes trouvées ; A prend une greffe puis la
##   pose sur un emplacement, X retire ; la fiche de la greffe visée s'affiche comme au survol.
## B revient à la zone « arbre ». Les panneaux ajoutés plus tard s'inscrivent dans zones().
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")

## Délai avant la première répétition d'un saut, puis entre deux sauts (stick ou croix tenus).
const REPEAT_FIRST := 0.32
const REPEAT := 0.13
## Vitesse du curseur libre (pixels par seconde, stick à fond) et portée de l'aimant des nœuds.
const CURSOR_SPEED := 760.0
const MAGNET := 26.0
## Marge (pixels) au bord de la vue où le curseur fait glisser l'arbre.
const EDGE := 70.0
## Zoom par seconde, gâchette à fond (facteur multiplicatif).
const ZOOM_RATE := 2.2
## Ouverture du cône de recherche d'un saut (cosinus de l'angle maximal).
const CONE := 0.42

var ui
var zone := "arbre"
## Curseur, à l'écran. attached : collé au nœud survolé (il le suit quand la vue bouge).
var cursor := Vector2.ZERO
var attached := false
var _repeat := 0.0
var _last_dir := Vector2.ZERO
## Zone « outils » : contrôle visé. Zone « couronne » : index (emplacements puis greffes).
var tool_index := 0
var crown_index := 0
var t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Settings.device_changed.connect(_on_device)
	if ui != null:
		ui.toggled.connect(_on_toggled)


func active() -> bool:
	return Settings.pad_active() and ui != null and ui.visible and not ui.choice_open()


func _on_toggled(open: bool) -> void:
	set_zone("arbre")
	if open and Settings.pad_active():
		_start()


func _on_device() -> void:
	if not Settings.pad_active():
		set_zone("arbre")
		attached = false
	elif ui != null and ui.visible:
		_start()
	ui.queue_redraw_header()
	queue_redraw()


## Premier nœud visé : celui qui est survolé, sinon le plus proche du centre de la vue.
func _start() -> void:
	if ui.hover < 0:
		cursor = ui.view_center()
		var id := nearest(cursor, INF)
		if id >= 0:
			select(id, false)
	else:
		select(ui.hover, false)


## Zones actives, dans l'ordre de LB / RB.
func zones() -> Array:
	var out := ["arbre", "outils"]
	if ui.grafts_panel != null and ui.grafts_panel.visible:
		out.append("couronne")
	return out


func set_zone(z: String) -> void:
	if z == zone:
		return
	if zone == "outils":
		_tools_focus(false)
	elif zone == "couronne" and ui.grafts_panel != null:
		ui.grafts_panel.pad_index = -1
		ui.grafts_panel.set_hover_slot(-1)
		ui.grafts_panel.set_hover_graft("")
	zone = z
	if zone == "outils":
		_tools_focus(true)
	elif zone == "couronne":
		if ui.grafts_panel.folded:
			ui.grafts_panel.set_folded(false)
		crown_index = clampi(crown_index, 0, maxi(0, _crown_count() - 1))
		_crown_show()
	ui.queue_redraw_header()
	queue_redraw()


func cycle_zone(step: int) -> void:
	var zs := zones()
	var i := zs.find(zone)
	set_zone(zs[(i + step + zs.size()) % zs.size()])
	Sfx.play("survol")


# --- Entrées ---

func _input(event: InputEvent) -> void:
	if not active():
		return
	var jb := event as InputEventJoypadButton
	var jm := event as InputEventJoypadMotion
	if jb == null and jm == null:
		return
	# La manette est lue ici (et dans _process pour les sticks) : rien n'arrive à la navigation des
	# contrôles, qui sauterait d'un bouton de l'arbre à l'autre.
	if jm != null:
		get_viewport().set_input_as_handled()
		return
	if not jb.pressed:
		if jb.button_index >= JOY_BUTTON_DPAD_UP and jb.button_index <= JOY_BUTTON_DPAD_RIGHT:
			get_viewport().set_input_as_handled()
		return
	match jb.button_index:
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
			cycle_zone(1 if jb.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1)
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			var d: Vector2 = {JOY_BUTTON_DPAD_UP: Vector2.UP, JOY_BUTTON_DPAD_DOWN: Vector2.DOWN,
				JOY_BUTTON_DPAD_LEFT: Vector2.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2.RIGHT}[jb.button_index]
			step(d)
			_last_dir = d
			_repeat = REPEAT_FIRST
		JOY_BUTTON_A:
			press_a()
		JOY_BUTTON_X:
			press_x()
		JOY_BUTTON_Y:
			if zone == "arbre":
				open_search()
			else:
				return
		JOY_BUTTON_B:
			if zone == "arbre":
				return   # l'arbre se ferme (ui_cancel, tree_ui.gd)
			if zone == "outils" and ui.panels.search.has_focus():
				ui.panels.search.release_focus()
			set_zone("arbre")
		JOY_BUTTON_RIGHT_STICK:
			ui.glide_fit()
		_:
			return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	t += delta
	if not active():
		return
	var mv: Vector2 = Settings.stick("move")
	var dir := Vector2.ZERO
	if mv.length() > 0.5:
		dir = _snap_dir(mv) if zone != "arbre" else mv.normalized()
	if dir == Vector2.ZERO:
		_last_dir = Vector2.ZERO
		_repeat = 0.0
	elif _last_dir == Vector2.ZERO or dir.dot(_last_dir) < 0.7:
		step(dir)
		_last_dir = dir
		_repeat = REPEAT_FIRST
	else:
		_repeat -= delta
		if _repeat <= 0.0:
			step(dir)
			_repeat = REPEAT
	if zone == "arbre":
		var r: Vector2 = Settings.stick("aim")
		if r != Vector2.ZERO:
			move_cursor(r * CURSOR_SPEED * delta)
		var zin := Input.get_action_strength("pad_zoom_in") if InputMap.has_action("pad_zoom_in") else 0.0
		var zout := Input.get_action_strength("pad_zoom_out") if InputMap.has_action("pad_zoom_out") else 0.0
		if absf(zin - zout) > 0.05:
			ui.zoom_at(cursor, exp((zin - zout) * log(ZOOM_RATE) * delta))
			if attached and ui.hover >= 0:
				cursor = ui.to_screen(Game.tree.nodes[ui.hover]["pos"])
		if attached and ui.hover >= 0:
			var p: Vector2 = ui.to_screen(Game.tree.nodes[ui.hover]["pos"])
			if p.distance_squared_to(cursor) > 0.25:
				cursor = p
				ui.mouse = cursor
	queue_redraw()


## Direction d'un stick ramenée à l'une des quatre directions (zones outils et couronne).
static func _snap_dir(v: Vector2) -> Vector2:
	if absf(v.x) >= absf(v.y):
		return Vector2.RIGHT if v.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if v.y > 0.0 else Vector2.UP


## Un pas dans la direction d (stick ou croix), selon la zone.
func step(d: Vector2) -> void:
	match zone:
		"arbre":
			hop(d)
		"outils":
			_tools_step(d)
		"couronne":
			_crown_step(d)


# --- Zone « arbre » ---

## Saute vers le nœud suivant dans la direction d : un voisin du nœud visé d'abord, sinon le nœud
## visible le plus proche dans le cône.
func hop(d: Vector2) -> int:
	var cur: int = ui.hover
	if cur < 0:
		cur = nearest(cursor, INF)
		if cur >= 0:
			select(cur)
		return cur
	var nodes: Array = Game.tree.nodes
	var p: Vector2 = nodes[cur]["pos"]
	var best := -1
	var best_score := INF
	for m in nodes[cur]["neighbors"]:
		var s := _score(p, nodes[m]["pos"], d)
		if s < best_score:
			best_score = s
			best = m
	if best < 0:
		var level: int = ui.lod()
		for n in nodes:
			if n["id"] == cur or not ui._shown(n, level):
				continue
			var s := _score(p, n["pos"], d)
			if s < best_score:
				best_score = s
				best = n["id"]
	if best >= 0:
		select(best)
		Sfx.play("survol")
	return best


## Coût d'un saut de p vers q dans la direction d : la distance, alourdie quand on s'écarte de la
## direction ; INF hors du cône.
static func _score(p: Vector2, q: Vector2, d: Vector2) -> float:
	var off := q - p
	var dist := off.length()
	if dist < 0.001:
		return INF
	var c := off.dot(d) / dist
	if c < CONE:
		return INF
	return dist * (1.0 + 2.5 * (1.0 - c))


## Nœud visible le plus proche d'un point de l'écran, à moins de « reach » pixels (-1 sinon).
func nearest(screen: Vector2, reach: float) -> int:
	var tp: Vector2 = ui.to_tree(screen)
	var level: int = ui.lod()
	var best := -1
	var bd := INF
	for n in Game.tree.nodes:
		if not ui._shown(n, level):
			continue
		var d: float = tp.distance_squared_to(n["pos"])
		if d < bd:
			bd = d
			best = n["id"]
	if best >= 0 and sqrt(bd) * ui.zoom > reach:
		return -1
	return best


## Vise un nœud : infobulle, curseur collé, et la vue glisse pour le garder à l'écran (le zoom
## s'approche si le nœud est caché en vue d'ensemble).
func select(id: int, follow := true) -> void:
	ui.hover = id
	attached = true
	var n: Dictionary = Game.tree.nodes[id]
	cursor = ui.to_screen(n["pos"])
	ui.mouse = cursor
	if not follow:
		return
	var z: float = ui.zoom
	if not ui._shown(n, ui.lod()):
		z = maxf(z, ui.LOD_ALL * 1.05)
	var area: Rect2 = ui._view_area().grow(-EDGE)
	if z != ui.zoom or not area.has_point(cursor):
		ui.glide_to(n["pos"], z)


## Curseur libre : il avance de « by » pixels ; au bord, la vue glisse. L'aimant colle le curseur au
## nœud tout proche.
func move_cursor(by: Vector2) -> void:
	attached = false
	cursor += by
	var area: Rect2 = ui._view_area()
	var inner := area.grow(-EDGE)
	var push := Vector2.ZERO
	if cursor.x < inner.position.x:
		push.x = cursor.x - inner.position.x
	elif cursor.x > inner.end.x:
		push.x = cursor.x - inner.end.x
	if cursor.y < inner.position.y:
		push.y = cursor.y - inner.position.y
	elif cursor.y > inner.end.y:
		push.y = cursor.y - inner.end.y
	if push != Vector2.ZERO:
		ui.cam += push / ui.zoom * 0.25
	cursor = cursor.clamp(area.position, area.end)
	ui.mouse = cursor
	ui.hover = nearest(cursor, MAGNET)


func press_a() -> void:
	match zone:
		"arbre":
			if ui.hover >= 0:
				ui.click(ui.hover)
		"outils":
			var c = _tool_controls()[tool_index] if tool_index < _tool_controls().size() else null
			if c is LineEdit:
				open_search()
			elif c is Button and not c.disabled:
				if c.toggle_mode:
					c.button_pressed = not c.button_pressed
				else:
					c.pressed.emit()
				Sfx.play("clic")
		"couronne":
			_crown_press(false)


func press_x() -> void:
	match zone:
		"arbre":
			if ui.hover >= 0:
				ui.panels.right_click(ui.hover)
		"couronne":
			_crown_press(true)


## Recherche : la zone des outils, le champ de recherche pris (clavier virtuel s'il y en a un).
func open_search() -> void:
	set_zone("outils")
	tool_index = 0
	var s: LineEdit = ui.panels.search
	s.grab_focus()
	s.select_all()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(s.text)


# --- Zone « outils » ---

func _tool_controls() -> Array:
	return ui.panels.pad_controls()


## Les boutons des outils prennent le focus le temps de la zone (focus visible), puis le rendent.
func _tools_focus(on: bool) -> void:
	var cs := _tool_controls()
	for c in cs:
		if c is Button:
			c.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	if on:
		tool_index = clampi(tool_index, 0, maxi(0, cs.size() - 1))
		if not cs.is_empty():
			cs[tool_index].grab_focus()
	else:
		for c in cs:
			if c.has_focus():
				c.release_focus()


func _tools_step(d: Vector2) -> void:
	var cs := _tool_controls()
	if cs.is_empty():
		return
	var cur: Control = cs[clampi(tool_index, 0, cs.size() - 1)]
	var here := cur.get_global_rect().get_center()
	var best := -1
	var best_score := INF
	for i in cs.size():
		var c: Control = cs[i]
		if c == cur or not c.is_visible_in_tree():
			continue
		var s := _score(here, c.get_global_rect().get_center(), d)
		if s < best_score:
			best_score = s
			best = i
	if best >= 0:
		tool_index = best
		cs[best].grab_focus()
		Sfx.play("survol")


# --- Zone « couronne » ---

## Cases de la couronne au pad : les emplacements ouverts, puis les greffes trouvées.
func _crown_count() -> int:
	return Game.crown_size() + Game.graft_inventory.size()


func _crown_show() -> void:
	var gp = ui.grafts_panel
	gp.pad_index = crown_index
	var open: int = Game.crown_size()
	if crown_index < open:
		gp.set_hover_graft("")
		gp.set_hover_slot(crown_index)
	else:
		gp.set_hover_slot(-1)
		gp.set_hover_graft(Game.graft_inventory[crown_index - open])
	gp.crown_view.queue_redraw()
	gp.ensure_visible(crown_index)


func _crown_step(d: Vector2) -> void:
	var n := _crown_count()
	if n == 0:
		return
	var open: int = Game.crown_size()
	var cols: int = ui.grafts_panel.COLUMNS
	var i := crown_index
	if d.x != 0.0:
		i += int(d.x)
	elif i < open:
		# Couronne : bas descend dans la grille, haut ne fait rien.
		if d.y > 0.0:
			i = open
	else:
		var gi := i - open + int(d.y) * cols
		i = open + gi if gi >= 0 else open - 1
	crown_index = clampi(i, 0, n - 1)
	_crown_show()
	Sfx.play("survol")


func _crown_press(remove: bool) -> void:
	var gp = ui.grafts_panel
	var open: int = Game.crown_size()
	if crown_index < open:
		gp.click_slot(crown_index, remove)
	else:
		var g: String = Game.graft_inventory[crown_index - open]
		if remove:
			gp.unplace(g)
		else:
			gp.select(g)
			if gp.held != "":
				# Greffe prise : le curseur va au premier emplacement libre (sinon au premier).
				crown_index = maxi(0, Game.first_free_slot())
	_crown_show()


# --- Dessin ---

func _draw() -> void:
	if not active() or zone != "arbre":
		return
	var gold := Color(UiTheme.GOLD, 0.9)
	var c := cursor
	if attached and ui.hover >= 0:
		var n: Dictionary = Game.tree.nodes[ui.hover]
		var r: float = ui._radius(n, ui.zoom) * ui.zoom + 7.0
		var pulse := 0.5 + 0.5 * sin(t * 5.0)
		draw_arc(c, r + 2.0 * pulse, 0.0, TAU, 40, gold, 2.0, true)
		for i in 4:
			var d := Vector2.from_angle(i * PI / 2.0 + PI / 4.0)
			draw_line(c + d * (r + 4.0), c + d * (r + 10.0), gold, 2.0, true)
	else:
		draw_arc(c, 9.0, 0.0, TAU, 24, gold, 1.6, true)
		for i in 4:
			var d := Vector2.from_angle(i * PI / 2.0)
			draw_line(c + d * 12.0, c + d * 18.0, gold, 1.6, true)


## Aide de l'en-tête à la manette (noms des boutons selon le style des glyphes).
func help_text() -> String:
	var n := func(code): return Settings.pad_name_of(code)
	match zone:
		"outils":
			return "Croix : choisir   ·   %s : valider   ·   %s / %s : panneaux   ·   %s : revenir à l'arbre" % [n.call(JOY_BUTTON_A), n.call(JOY_BUTTON_LEFT_SHOULDER), n.call(JOY_BUTTON_RIGHT_SHOULDER), n.call(JOY_BUTTON_B)]
		"couronne":
			return "Croix : choisir   ·   %s : prendre, poser   ·   %s : retirer   ·   %s / %s : panneaux   ·   %s : revenir à l'arbre" % [n.call(JOY_BUTTON_A), n.call(JOY_BUTTON_X), n.call(JOY_BUTTON_LEFT_SHOULDER), n.call(JOY_BUTTON_RIGHT_SHOULDER), n.call(JOY_BUTTON_B)]
	return "%s : apprendre   ·   %s : oublier   ·   Stick G : de nœud en nœud   ·   Stick D : curseur   ·   %s / %s : zoom   ·   %s : rechercher   ·   %s / %s : panneaux   ·   %s : fermer" % [
		n.call(JOY_BUTTON_A), n.call(JOY_BUTTON_X), n.call(Settings.PAD_LT), n.call(Settings.PAD_RT), n.call(JOY_BUTTON_Y),
		n.call(JOY_BUTTON_LEFT_SHOULDER), n.call(JOY_BUTTON_RIGHT_SHOULDER), n.call(JOY_BUTTON_B)]
