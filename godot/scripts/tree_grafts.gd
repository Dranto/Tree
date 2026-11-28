## Couronne de greffes, sur l'écran de l'Arbre de vie (en bas à gauche) : indépendante des nœuds.
##
## En haut, la couronne : une vrille en anneau qui porte les emplacements. Les emplacements ouverts
## sont des médaillons (creux s'ils sont vides) ; ceux qui restent à gagner sont des bourgeons fermés
## (un de plus par région dont les Cœurs sont purifiés, par boss vaincu, et à la finale :
## Game.crown_size, data/crown.json). Un emplacement qui vient de s'ouvrir luit jusqu'à ce qu'on le voie.
## En dessous, les greffes trouvées, en grille d'icônes (celles qui sont posées sont estompées), et une
## fiche : la greffe survolée ou tenue, ses effets et l'aperçu des statistiques avant → après.
##
## Pose et retrait libres : glisser une greffe sur un emplacement (ou clic sur la greffe puis sur
## l'emplacement, ou double-clic pour la poser au premier emplacement libre) ; un clic (ou clic droit)
## sur un emplacement occupé retire sa greffe, et on peut la glisser d'un emplacement à l'autre ou
## la ramener dans la grille. Une greffe posée agit tout de suite.
##
## Le panneau n'apparaît qu'une fois une greffe trouvée. Un clic sur le titre replie la grille.
extends PanelContainer

const UiTheme = preload("res://scripts/ui_theme.gd")
const Content = preload("res://scripts/content.gd")
const Effects = preload("res://scripts/effects.gd")
const GraftPickup = preload("res://scripts/graft_pickup.gd")
const TreeArt = preload("res://scripts/tree_art.gd")

const DIM := Color(0.731, 0.683, 0.574)
const PLAN := Color("f2d06b")
const SLOT_BG := Color("3a2a1a")
## Largeur utile du panneau (la couronne, la grille et la fiche s'y tiennent).
const WIDTH := 316.0
const COLUMNS := 8
const CELL := 36.0
## Rangées de la grille visibles sans défiler.
const ROWS_VISIBLE := 4
## Hauteur fixe de la fiche (et de la consigne) : le panneau ne grandit ni ne rétrécit au survol ;
## le texte, lui, rapetisse pour s'y tenir (jamais sous MIN_FONT).
const DETAIL_H := 176.0
const MIN_FONT := 11
## Drapeau de Game.flags : nombre d'emplacements déjà vus (les suivants luisent).
const SEEN_FLAG := "couronne_vue"

var ui
## Greffe tenue : choisie d'un clic dans la grille, ou en train d'être glissée.
var held := ""
var dragging := false
## Ce que le pointeur survole : une greffe (grille ou emplacement occupé) et l'emplacement survolé (-1 sinon).
var hover_graft := ""
var hover_slot := -1
var folded := false
var t := 0.0
## Manette (tree_pad.gd) : case visée, emplacements ouverts puis greffes de la grille (-1 : aucune).
var pad_index := -1
var crown_view: Control
var _title: Button
var _count: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _detail: VBoxContainer
var _detail_frame: Control
var _hint: Label
var _seen := 0
## Jalon Éclat G : racines qui poussent de l'emplacement où l'on vient de poser une greffe
## (emplacement → temps écoulé) ; greffes de la couronne à la dernière image.
var _roots := {}
var _last_crown: Array = []


## La couronne : anneau de vrille et emplacements, dessinés par le code.
class CrownView extends Control:
	var panel

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(WIDTH, 150)

	## Au New Game+, la couronne dépasse 16 emplacements (jusqu'à 20) : l'anneau s'ouvre un peu en
	## hauteur et les médaillons rapetissent pour ne pas se toucher. 1 jusqu'à 16 emplacements.
	func slot_scale() -> float:
		return clampf(16.0 / float(maxi(slot_count(), 16)), 0.78, 1.0)

	func slot_count() -> int:
		return maxi(Game.crown_max() + Game.crown_next_cycle(), 1)

	## Hauteur voulue de l'anneau selon le nombre d'emplacements (150 jusqu'à 16, puis 6 par emplacement).
	func wanted_height() -> float:
		return 150.0 + 6.0 * float(maxi(0, slot_count() - 16))

	## Centre de chaque emplacement (ouverts puis fermés), répartis à intervalles égaux le long de
	## l'ellipse (pas d'angles égaux : ils se serreraient aux deux bouts), le premier en bas.
	func slot_points() -> Array:
		var out: Array = []
		var n: int = maxi(Game.crown_max() + Game.crown_next_cycle(), 1)
		var c := size / 2.0
		var rx := size.x / 2.0 - 22.0
		var ry := size.y / 2.0 - 20.0
		const STEPS := 360
		var pts: Array = []
		var acc: Array = [0.0]
		for k in STEPS + 1:
			var a := PI / 2.0 + TAU * float(k) / STEPS
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
			if k > 0:
				acc.append(acc[k - 1] + pts[k].distance_to(pts[k - 1]))
		var total: float = acc[STEPS]
		var k := 0
		for i in n:
			var want := total * float(i) / float(n)
			while k < STEPS and acc[k + 1] < want:
				k += 1
			out.append(pts[k])
		return out

	func slot_at(p: Vector2) -> int:
		var pts := slot_points()
		var best := -1
		var best_d := 19.0 * slot_scale()
		for i in pts.size():
			var d: float = p.distance_to(pts[i])
			if d < best_d:
				best_d = d
				best = i
		return best

	func _draw() -> void:
		var pts := slot_points()
		var open: int = Game.crown_size()
		var k_s := slot_scale()
		var c := size / 2.0
		var rx := size.x / 2.0 - 22.0
		var ry := size.y / 2.0 - 20.0
		# La vrille : deux brins qui s'enroulent autour de l'anneau.
		for k in 2:
			var line := PackedVector2Array()
			for s in 97:
				var a := TAU * s / 96.0
				var wob := 3.0 * sin(a * 9.0 + k * PI)
				line.append(c + Vector2(cos(a) * (rx + wob), sin(a) * (ry + wob)))
			draw_polyline(line, Color(UiTheme.LEAF.darkened(0.35 + 0.15 * k), 0.9), 2.2 - 0.6 * k, true)
		# Petites feuilles entre les emplacements.
		for i in pts.size():
			var a := PI / 2.0 + TAU * (float(i) + 0.5) / float(pts.size())
			var q := c + Vector2(cos(a) * rx, sin(a) * ry)
			UiTheme.draw_leaf(self, q, a + PI / 2.0 + (0.5 if i % 2 == 0 else -0.5), 10.0, 3.2, Color(UiTheme.LEAF.darkened(0.2), 0.9), Color(UiTheme.LEAF.darkened(0.45), 0.8), 1.0)
		for i in pts.size():
			var p: Vector2 = pts[i]
			if i >= open:
				_draw_bud(p, k_s)
				continue
			var gid := Game.graft_of(i)
			var target: bool = panel.held != "" and panel.hover_slot == i
			var fresh: bool = i >= panel._seen
			var glow := 0.0
			if fresh:
				glow = 0.5 + 0.5 * sin(panel.t * 4.0)
				draw_circle(p, (19.0 + 3.0 * glow) * k_s, Color(PLAN, 0.12 + 0.18 * glow))
			draw_circle(p, 14.5 * k_s, SLOT_BG if gid != "" else Color(SLOT_BG, 0.75))
			var ring := PLAN if target else (UiTheme.GOLD if gid != "" else Color(UiTheme.GOLD, 0.55 + 0.4 * glow))
			draw_arc(p, 14.5 * k_s, 0.0, TAU, 28, ring, 2.5 if target else 1.6, true)
			if panel.pad_index == i:
				# Visé à la manette : un second anneau d'or, plus large.
				draw_arc(p, 19.5 * k_s, 0.0, TAU, 32, PLAN, 2.0, true)
			if gid != "":
				var g: Dictionary = Content.grafts().get(gid, {})
				GraftPickup.draw_shape(self, str(g.get("shape", "feuille")), p, 9.0 * k_s, Color(str(g.get("color", "#f2d06b"))))
			else:
				# Emplacement ouvert et vide : une petite croix d'or, comme un écusson qui attend.
				var s := 4.0 * k_s
				var col := Color(UiTheme.GOLD, 0.6)
				draw_line(p + Vector2(-s, 0), p + Vector2(s, 0), col, 1.5, true)
				draw_line(p + Vector2(0, -s), p + Vector2(0, s), col, 1.5, true)
			if panel.hover_slot == i and panel.held == "":
				draw_arc(p, 17.5 * k_s, 0.0, TAU, 28, Color(PLAN, 0.7), 1.2, true)
		# Au centre : emplacements occupés sur emplacements ouverts.
		var f := UiTheme.font(true)
		var txt := "%d / %d" % [Game.placed_grafts().size(), open]
		UiTheme.draw_text(self, f, c + Vector2(-60, 7), txt, HORIZONTAL_ALIGNMENT_CENTER, 120, 20, UiTheme.GOLD, 4)
		# Une greffe qui vient d'être posée s'enracine : des racines poussent de son emplacement.
		var rcfg: Dictionary = Content.feel().get("tree", {}).get("roots", {})
		var dur := float(rcfg.get("time", 1.1))
		var count := int(rcfg.get("count", 7))
		if Settings.reduce_effects:
			count = maxi(count / 3, 2)
		for slot in panel._roots:
			if slot < pts.size():
				TreeArt.roots(self, pts[slot], float(rcfg.get("size", 34.0)), UiTheme.LEAF, panel._roots[slot] / dur, count, slot)

	## Emplacement encore fermé : un bourgeon clos, cerclé d'un filet pointillé.
	func _draw_bud(p: Vector2, k_s := 1.0) -> void:
		draw_circle(p, 10.5 * k_s, Color(SLOT_BG, 0.85))
		for k in 10:
			var a := TAU * k / 10.0
			draw_arc(p, 10.5 * k_s, a, a + TAU / 20.0, 3, Color(DIM, 0.75), 1.2, true)
		var bud := Color("b58a5a")
		UiTheme.draw_leaf(self, p + Vector2(0, 5) * k_s, -PI / 2.0 - 0.3, 11.0 * k_s, 3.6 * k_s, bud.lightened(0.2), bud, 1.0)
		UiTheme.draw_leaf(self, p + Vector2(0, 5) * k_s, -PI / 2.0 + 0.3, 11.0 * k_s, 3.6 * k_s, bud.lightened(0.2), bud.darkened(0.15), 1.0)

	func _gui_input(event: InputEvent) -> void:
		var mm := event as InputEventMouseMotion
		if mm:
			panel.set_hover_slot(slot_at(mm.position))
		var mb := event as InputEventMouseButton
		if mb and mb.pressed and (mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT):
			var i := slot_at(mb.position)
			if i >= 0:
				panel.click_slot(i, mb.button_index == MOUSE_BUTTON_RIGHT)
				accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			panel.set_hover_slot(-1)

	func _get_drag_data(at: Vector2):
		var i := slot_at(at)
		if i < 0 or Game.graft_of(i) == "":
			return null
		var gid := Game.graft_of(i)
		set_drag_preview(panel.drag_preview(gid))
		panel.begin_drag(gid)
		return {"graft": gid, "from_slot": i}

	func _can_drop_data(at: Vector2, data) -> bool:
		if not (data is Dictionary and data.has("graft")):
			return false
		panel.set_hover_slot(slot_at(at))
		return true

	func _drop_data(at: Vector2, data) -> void:
		panel.drop_on(slot_at(at), str(data["graft"]))


## Une greffe de la grille : son médaillon. Se glisse, se choisit d'un clic.
class Item extends Control:
	var panel
	var graft_id := ""

	func _init() -> void:
		custom_minimum_size = Vector2(CELL, CELL)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var g: Dictionary = Content.grafts().get(graft_id, {})
		var c := size / 2.0
		var placed: bool = Game.graft_slot(graft_id) >= 0
		var selected: bool = panel.held == graft_id
		var a := 0.45 if placed else 1.0
		if selected or panel.hover_graft == graft_id:
			draw_circle(c, 17.0, Color(PLAN, 0.22 if selected else 0.12))
		draw_circle(c, 14.0, Color(SLOT_BG, a))
		draw_arc(c, 14.0, 0.0, TAU, 24, PLAN if selected else Color(UiTheme.GOLD, 0.9 * a), 2.0 if selected else 1.4, true)
		GraftPickup.draw_shape(self, str(g.get("shape", "feuille")), c, 8.5, Color(Color(str(g.get("color", "#f2d06b"))), a))
		if panel.pad_index >= Game.crown_size() and panel.pad_index - Game.crown_size() == get_index():
			draw_arc(c, 17.0, 0.0, TAU, 28, PLAN, 2.0, true)
		if placed:
			# Posée dans la couronne : une perle d'or en bas à droite.
			draw_circle(c + Vector2(10, 10), 3.6, UiTheme.GOLD)
			draw_arc(c + Vector2(10, 10), 3.6, 0.0, TAU, 12, SLOT_BG, 1.0, true)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.double_click:
				panel.quick_place(graft_id)
			else:
				panel.select(graft_id)
			accept_event()
		elif mb and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			panel.unplace(graft_id)
			accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			panel.set_hover_graft(graft_id)
		elif what == NOTIFICATION_MOUSE_EXIT and panel.hover_graft == graft_id:
			panel.set_hover_graft("")

	func _get_drag_data(_at: Vector2):
		set_drag_preview(panel.drag_preview(graft_id))
		panel.begin_drag(graft_id)
		return {"graft": graft_id}

	## Une greffe ramenée d'un emplacement sur la grille est retirée de la couronne.
	func _can_drop_data(_at: Vector2, data) -> bool:
		return data is Dictionary and data.has("from_slot")

	func _drop_data(_at: Vector2, data) -> void:
		panel.unplace(str(data["graft"]))


## Fond de la grille : reçoit aussi une greffe ramenée d'un emplacement.
class Grid extends GridContainer:
	var panel

	func _can_drop_data(_at: Vector2, data) -> bool:
		return data is Dictionary and data.has("from_slot")

	func _drop_data(_at: Vector2, data) -> void:
		panel.unplace(str(data["graft"]))


func _ready() -> void:
	theme = UiTheme.make()
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 16.0
	offset_bottom = -16.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_theme_stylebox_override("panel", UiTheme.cadre(false, Color(UiTheme.PAPER, 0.95), UiTheme.GOLD, 14.0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	_title = Button.new()
	_title.flat = true
	_title.focus_mode = Control.FOCUS_NONE
	_title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_override("font", UiTheme.font(true))
	_title.add_theme_font_size_override("font_size", 19)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_title.add_theme_color_override(k, UiTheme.GOLD)
	var flat := StyleBoxEmpty.new()
	for k in ["normal", "hover", "pressed", "focus"]:
		_title.add_theme_stylebox_override(k, flat)
	_title.pressed.connect(func(): set_folded(not folded))
	head.add_child(_title)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 15)
	_count.add_theme_color_override("font_color", DIM)
	head.add_child(_count)
	crown_view = CrownView.new()
	crown_view.panel = self
	box.add_child(crown_view)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_scroll)
	_grid = Grid.new()
	_grid.panel = self
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_grid)
	_detail_frame = Control.new()
	_detail_frame.custom_minimum_size = Vector2(WIDTH, DETAIL_H)
	_detail_frame.clip_contents = true
	_detail_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_detail_frame)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 1)
	_detail.position = Vector2.ZERO
	_detail.size = Vector2(WIDTH, DETAIL_H)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_frame.add_child(_detail)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", DIM)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.position = Vector2.ZERO
	_hint.size = Vector2(WIDTH, DETAIL_H)
	_hint.custom_minimum_size = Vector2(WIDTH, 0)
	_detail_frame.add_child(_hint)
	Game.tree_changed.connect(refresh)
	Settings.device_changed.connect(refresh)
	if ui != null and ui.has_signal("toggled"):
		ui.toggled.connect(_on_tree_toggled)
	_seen = _seen_slots()
	for i in Game.crown_size():
		_last_crown.append(Game.graft_of(i))
	refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	t += delta
	# Seul un emplacement neuf (qui luit) ou une racine qui pousse demande un dessin à chaque image.
	if not _roots.is_empty():
		var dur := float(Content.feel().get("tree", {}).get("roots", {}).get("time", 1.1))
		for slot in _roots.keys():
			_roots[slot] += delta
			if _roots[slot] >= dur:
				_roots.erase(slot)
		crown_view.queue_redraw()
	elif _seen < Game.crown_size():
		crown_view.queue_redraw()


## Ouverture de l'arbre : les emplacements gagnés depuis la dernière visite luisent ;
## à la fermeture, ils sont notés comme vus.
func _on_tree_toggled(open: bool) -> void:
	if open:
		_seen = _seen_slots()
		refresh()
	else:
		Game.flags[SEEN_FLAG] = Game.crown_size()
		_seen = Game.crown_size()
		held = ""
		hover_slot = -1
		hover_graft = ""


## Emplacements déjà vus : ceux du départ tant que l'arbre n'a jamais été refermé.
func _seen_slots() -> int:
	return int(Game.flags.get(SEEN_FLAG, int(Content.crown().get("start", 2))))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and dragging:
		dragging = false
		held = ""
		refresh()


## Manette : fait défiler la grille jusqu'à la case visée (index des greffes après les emplacements).
func ensure_visible(index: int) -> void:
	var gi := index - Game.crown_size()
	for it in _grid.get_children():
		it.queue_redraw()
	if gi >= 0 and gi < _grid.get_child_count():
		_scroll.ensure_control_visible(_grid.get_child(gi))


func set_folded(on: bool) -> void:
	folded = on
	refresh()


func set_hover_slot(i: int) -> void:
	if i == hover_slot:
		return
	hover_slot = i
	_refresh_detail()
	crown_view.queue_redraw()


func set_hover_graft(id: String) -> void:
	if id == hover_graft:
		return
	hover_graft = id
	_refresh_detail()
	for it in _grid.get_children():
		it.queue_redraw()


func select(id: String) -> void:
	held = "" if held == id else id
	refresh()


func begin_drag(id: String) -> void:
	held = id
	dragging = true
	refresh()


## Aperçu glissé : le médaillon de la greffe.
func drag_preview(id: String) -> Control:
	var preview := Control.new()
	var copy := Control.new()
	copy.size = Vector2(32, 32)
	copy.position = Vector2(-16, -16)
	copy.draw.connect(func():
		var g: Dictionary = Content.grafts().get(id, {})
		copy.draw_circle(Vector2(16, 16), 15.0, SLOT_BG)
		copy.draw_arc(Vector2(16, 16), 15.0, 0.0, TAU, 24, PLAN, 2.0, true)
		GraftPickup.draw_shape(copy, str(g.get("shape", "feuille")), Vector2(16, 16), 9.0, Color(str(g.get("color", "#f2d06b")))))
	preview.add_child(copy)
	return preview


## Reconstruit la grille (une case par greffe possédée, dans l'ordre où elles ont été trouvées),
## la couronne et la fiche.
func refresh() -> void:
	if _grid == null:
		return
	visible = not Game.graft_inventory.is_empty()
	if held != "" and not Game.has_graft(held):
		held = ""
	var open: int = Game.crown_size()
	crown_view.custom_minimum_size.y = crown_view.wanted_height()
	_title.text = ("▸ " if folded else "▾ ") + Loc.t("Couronne de greffes")
	var free: int = Game.free_grafts().size()
	_count.text = Loc.tn("%d trouvée", "%d trouvées", Game.graft_inventory.size()) % Game.graft_inventory.size()
	var count: int = Game.graft_inventory.size()
	while _grid.get_child_count() > count:
		var last := _grid.get_child(_grid.get_child_count() - 1)
		_grid.remove_child(last)
		last.queue_free()
	while _grid.get_child_count() < count:
		var it := Item.new()
		it.panel = self
		_grid.add_child(it)
	for i in count:
		var it: Item = _grid.get_child(i)
		it.graft_id = Game.graft_inventory[i]
		it.queue_redraw()
	var rows := ceili(float(count) / COLUMNS)
	_scroll.custom_minimum_size = Vector2(COLUMNS * (CELL + 2.0), minf(rows, ROWS_VISIBLE) * (CELL + 2.0))
	_scroll.visible = not folded
	_detail_frame.visible = not folded
	var pad := Settings.pad_active()
	var a_name := Settings.pad_name_of(JOY_BUTTON_A)
	if held != "":
		_hint.text = (Loc.t("%s sur un emplacement de la couronne : y poser la greffe.") % a_name) if pad else Loc.t("Clique un emplacement de la couronne pour y poser la greffe.")
	elif Game.placed_grafts().size() < open and free > 0:
		_hint.text = (Loc.t("%s sur une greffe pour la prendre, puis sur un emplacement libre.") % a_name) if pad else Loc.t("Glisse une greffe dans un emplacement libre de la couronne.")
	else:
		_hint.text = (Loc.t("%s sur un emplacement : retire sa greffe.") % Settings.pad_name_of(JOY_BUTTON_X)) if pad else Loc.t("Clic sur un emplacement : retire sa greffe.")
	# Une greffe posée dans un emplacement (et pas déjà là à la dernière image) s'y enracine.
	var now: Array = []
	for i in open:
		now.append(Game.graft_of(i))
	if is_visible_in_tree():
		for i in now.size():
			if now[i] != "" and (i >= _last_crown.size() or _last_crown[i] != now[i]):
				_roots[i] = 0.0
	_last_crown = now
	crown_view.queue_redraw()
	_refresh_detail()


## Fiche du bas : la greffe tenue, survolée ou posée dans l'emplacement survolé, ses effets, et
## l'aperçu des statistiques si on la posait (ou la retirait).
func _refresh_detail() -> void:
	if _detail == null:
		return
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	_hint.visible = false
	if folded:
		return
	# La consigne n'apparaît que quand la fiche est vide (rien de survolé ni de tenu).
	_hint.visible = true
	var open: int = Game.crown_size()
	if hover_slot >= open:
		_hint.visible = false
		_line(Loc.t("Emplacement fermé"), 16, DIM, true)
		if hover_slot >= Game.crown_max():
			_line(Loc.t("Il s'ouvre au cycle suivant, en touchant le fruit de la graine."), 15, DIM)
		else:
			_line(Loc.t("Il s'ouvre en purifiant les Cœurs d'une région, ou en vainquant son gardien."), 15, DIM)
		return
	var id := held if held != "" else hover_graft
	if id == "" and hover_slot >= 0:
		id = Game.graft_of(hover_slot)
	var g: Dictionary = Content.grafts().get(id, {})
	if g.is_empty():
		return
	if held == "":
		_hint.visible = false
	_line(Loc.data(str(g.get("name", id))), 17, UiTheme.GOLD, true)
	if Game.graft_min_cycle(id) >= 2:
		# Greffe de cycle (New Game+) : on dit d'où elle vient.
		_line(Loc.t("Greffe de cycle : on la trouve à partir du cycle %d.") % Game.graft_min_cycle(id), 14, DIM)
	for e in g.get("effects", []):
		var text := Effects.describe(e)
		if text != "":
			_line("• " + text, 15, UiTheme.INK, false, true)
	var planner = ui.panels.planner if ui != null and ui.panels != null else null
	if planner == null:
		return
	var slot := Game.graft_slot(id)
	var changes: Array = []
	var title := ""
	if held != "" and hover_slot >= 0 and hover_slot < open and hover_slot != slot:
		changes = planner.preview_graft(hover_slot, id)
		title = Loc.t("Posée ici :")
		var current := Game.graft_of(hover_slot)
		if current != "":
			_line(Loc.t("Remplace « %s ».") % Loc.data(Content.grafts()[current]["name"]), 15, DIM)
	elif slot < 0 and Game.first_free_slot() >= 0:
		changes = planner.preview_graft(Game.first_free_slot(), id)
		title = Loc.t("Posée :")
	elif slot >= 0 and held == "":
		changes = planner.preview_graft(-1, id)
		title = Loc.t("Retirée :")
	if not changes.is_empty():
		_line(title, 15, DIM)
		for c in changes.slice(0, 4):
			_line("   " + str(c["text"]), 15, PLAN, false, true)
	_fit_detail.call_deferred()


## Fait tenir la fiche dans DETAIL_H : si elle déborde, tous ses textes rapetissent d'un cran à la fois.
func _fit_detail() -> void:
	if _detail == null or not is_inside_tree():
		return
	for _step in 8:
		var h := 0.0
		for l in _detail.get_children():
			h += (l as Control).get_combined_minimum_size().y + 1.0
		if h <= DETAIL_H:
			return
		var shrunk := false
		for l in _detail.get_children():
			var fs: int = (l as Control).get_theme_font_size("font_size")
			if fs > MIN_FONT:
				(l as Control).add_theme_font_size_override("font_size", fs - 1)
				shrunk = true
		if not shrunk:
			return
		_detail.reset_size()
		_detail.size = Vector2(WIDTH, DETAIL_H)


## Une ligne de la fiche. rich : mots-clés colorés (RichText), pour les effets et les statistiques.
func _line(text: String, fs: int, col: Color, bold := false, rich := false) -> void:
	if rich:
		var r := RichLabel.new()
		r.text = text
		r.color = col
		r.bold = bold
		r.wrap_width = WIDTH
		r.add_theme_font_size_override("font_size", fs)
		_detail.add_child(r)
		return
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH, 0)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", UiTheme.font(true))
	_detail.add_child(l)


## Clic sur un emplacement de la couronne : pose la greffe tenue ; sinon (ou clic droit) retire
## celle qui y est. Renvoie true si le clic a été pris en charge.
func click_slot(i: int, remove := false) -> bool:
	if i < 0 or i >= Game.crown_size():
		return false
	if held != "" and not remove:
		return drop_on(i, held)
	var current := Game.graft_of(i)
	if current == "":
		return true
	Game.set_graft(i, "")
	_changed()
	return true


## Pose la greffe dans l'emplacement visé (glisser-déposer ou clic). Hors d'un emplacement ouvert,
## rien ne change.
func drop_on(i: int, graft: String) -> bool:
	held = ""
	if i < 0 or i >= Game.crown_size():
		refresh()
		return false
	var ok: bool = Game.place_graft(i, graft)
	if ok:
		Sfx.play("noeud")
		_changed()
	refresh()
	return ok


## Double-clic sur une greffe : posée au premier emplacement libre (rien s'il n'y en a pas).
func quick_place(graft: String) -> bool:
	held = ""
	if Game.graft_slot(graft) >= 0:
		refresh()
		return false
	var i := Game.first_free_slot()
	if i < 0:
		refresh()
		return false
	return drop_on(i, graft)


## Retire une greffe de la couronne (clic droit sur la grille, ou ramenée d'un emplacement).
func unplace(graft: String) -> bool:
	held = ""
	var ok: bool = Game.unplace_graft(graft)
	if ok:
		_changed()
	refresh()
	return ok


func _changed() -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene != null and scene.has_method("request_autosave"):
		scene.request_autosave()
