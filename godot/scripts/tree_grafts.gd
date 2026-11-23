## Inventaire des greffes sur l'écran de l'Arbre de vie (en bas à gauche) : les greffes trouvées
## dans le monde, posées ou non. On en glisse une sur un emplacement de greffe de l'arbre (anneau
## creux) pour l'y poser, ou on la choisit d'un clic puis on clique l'emplacement. Un clic sur un
## emplacement occupé retire la greffe, qui revient dans l'inventaire. L'infobulle de l'emplacement
## montre l'effet de la greffe tenue avant de la poser (aperçu du planificateur, statistiques avant → après).
##
## Le panneau n'apparaît qu'une fois une greffe trouvée.
extends PanelContainer

const UiTheme = preload("res://scripts/ui_theme.gd")
const Content = preload("res://scripts/content.gd")
const Effects = preload("res://scripts/effects.gd")
const GraftPickup = preload("res://scripts/graft_pickup.gd")

const DIM := Color(0.731, 0.683, 0.574)
const PLAN := Color("f2d06b")

var ui
## Greffe tenue : choisie d'un clic dans l'inventaire, ou en train d'être glissée.
var held := ""
var dragging := false
var _title: Label
var _hint: Label
var _list: VBoxContainer


## Une ligne de l'inventaire : la forme de la greffe, son nom et où elle est posée. Se glisse.
class Item extends PanelContainer:
	var panel
	var graft_id := ""
	var icon: Control
	var name_label: Label
	var place_label: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		icon = Control.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.draw.connect(_draw_icon)
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		name_label = Label.new()
		name_label.add_theme_font_size_override("font_size", 15)
		col.add_child(name_label)
		place_label = Label.new()
		place_label.add_theme_font_size_override("font_size", 14)
		place_label.add_theme_color_override("font_color", DIM)
		col.add_child(place_label)

	func _draw_icon() -> void:
		var g: Dictionary = Content.grafts().get(graft_id, {})
		var c := icon.size / 2.0
		icon.draw_circle(c, 13.0, Color("3a2a1a"))
		icon.draw_arc(c, 13.0, 0.0, TAU, 24, Color("f2d06b"), 1.5, true)
		GraftPickup.draw_shape(icon, str(g.get("shape", "feuille")), c, 8.0, Color(str(g.get("color", "#f2d06b"))))

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			panel.select(graft_id)
			accept_event()

	func _get_drag_data(_at: Vector2):
		var preview := Control.new()
		var copy := Control.new()
		copy.size = Vector2(28, 28)
		copy.position = Vector2(-14, -14)
		copy.draw.connect(func():
			var g: Dictionary = Content.grafts().get(graft_id, {})
			copy.draw_circle(Vector2(14, 14), 13.0, Color("3a2a1a"))
			copy.draw_arc(Vector2(14, 14), 13.0, 0.0, TAU, 24, Color("f2d06b"), 1.5, true)
			GraftPickup.draw_shape(copy, str(g.get("shape", "feuille")), Vector2(14, 14), 8.0, Color(str(g.get("color", "#f2d06b")))))
		preview.add_child(copy)
		set_drag_preview(preview)
		panel.begin_drag(graft_id)
		return {"graft": graft_id}


func _ready() -> void:
	theme = UiTheme.make()
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 16.0
	offset_bottom = -16.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb := UiTheme.box(Color(UiTheme.PAPER, 0.94), Color(UiTheme.GOLD, 0.3), 1, 8)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, 10)
	add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_override("font", UiTheme.font(true))
	_title.add_theme_font_size_override("font_size", 17)
	_title.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_list)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", DIM)
	box.add_child(_hint)
	Game.tree_changed.connect(refresh)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and dragging:
		dragging = false
		held = ""
		refresh()


func select(id: String) -> void:
	held = "" if held == id else id
	refresh()
	if held != "" and ui != null:
		ui.panels.say("« %s » : clique un emplacement de greffe de l'arbre (anneau creux) pour l'y poser." % Content.grafts()[held]["name"])


func begin_drag(id: String) -> void:
	held = id
	dragging = true
	refresh()


## Reconstruit la liste : une ligne par greffe possédée, dans l'ordre où elles ont été trouvées.
func refresh() -> void:
	if _list == null:
		return
	visible = not Game.graft_inventory.is_empty()
	if held != "" and not Game.has_graft(held):
		held = ""
	var free: int = Game.free_grafts().size()
	_title.text = "Greffes : %d trouvée%s, %d à poser" % [Game.graft_inventory.size(), "s" if Game.graft_inventory.size() > 1 else "", free]
	_hint.text = "Glisse une greffe sur un emplacement (anneau creux)." if held == "" else "Clique un emplacement pour poser la greffe choisie."
	while _list.get_child_count() > Game.graft_inventory.size():
		var last := _list.get_child(_list.get_child_count() - 1)
		_list.remove_child(last)
		last.queue_free()
	while _list.get_child_count() < Game.graft_inventory.size():
		var it := Item.new()
		it.panel = self
		_list.add_child(it)
	for i in Game.graft_inventory.size():
		var it: Item = _list.get_child(i)
		var id: String = Game.graft_inventory[i]
		it.graft_id = id
		var g: Dictionary = Content.grafts().get(id, {})
		it.name_label.text = str(g.get("name", id))
		var slot: int = Game.graft_slot(id)
		if slot < 0:
			it.place_label.text = "à poser"
		elif Game.allocated.has(slot):
			it.place_label.text = "posée : " + str(Game.tree.nodes[slot]["name"])
		else:
			it.place_label.text = "posée (emplacement pas encore appris)"
		var selected := id == held
		var box := UiTheme.box(Color(0.16, 0.14, 0.08, 0.95) if selected else Color(UiTheme.PAPER.lightened(0.04), 0.9), UiTheme.GOLD if selected else Color(UiTheme.GOLD, 0.18), 1, 6)
		box.content_margin_left = 6
		box.content_margin_right = 10
		box.content_margin_top = 3
		box.content_margin_bottom = 3
		it.add_theme_stylebox_override("panel", box)
		it.name_label.add_theme_color_override("font_color", UiTheme.GOLD if slot < 0 else UiTheme.INK)
		it.icon.queue_redraw()
	if ui != null:
		ui._redraw_all()


## Clic sur un emplacement de greffe de l'arbre : pose la greffe tenue, sinon retire celle qui y est.
## Renvoie true si le clic a été pris en charge.
func click_slot(id: int) -> bool:
	var n: Dictionary = Game.tree.nodes[id]
	if n["type"] != "graft":
		return false
	if held != "":
		return drop_on(id, held)
	var current := Game.graft_of(id)
	if current == "":
		if Game.free_grafts().is_empty():
			ui.panels.say("Emplacement vide : les greffes se trouvent dans le monde (autels, élites, boss).")
		else:
			ui.panels.say("Emplacement vide : glisse une greffe de l'inventaire (en bas à gauche) jusqu'ici.")
		return true
	Game.set_graft(id, "")
	ui.panels.say("« %s » retirée : elle revient dans l'inventaire." % Content.grafts()[current]["name"])
	_saved()
	return true


## Pose la greffe sur le nœud visé (glisser-déposer ou clic). Hors d'un emplacement, rien ne change.
func drop_on(id: int, graft: String) -> bool:
	held = ""
	if id < 0 or Game.tree.nodes[id]["type"] != "graft":
		ui.panels.say("Dépose la greffe sur un emplacement de greffe (anneau creux).")
		refresh()
		return false
	var ok: bool = Game.place_graft(id, graft)
	if ok:
		var where: String = Game.tree.nodes[id]["name"]
		var name_of: String = Content.grafts()[graft]["name"]
		if Game.allocated.has(id):
			ui.panels.say("« %s » posée dans « %s »." % [name_of, where])
		else:
			ui.panels.say("« %s » posée : elle agira quand « %s » sera appris." % [name_of, where])
		Sfx.play("noeud")
		_saved()
	refresh()
	return ok


func _saved() -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene != null and scene.has_method("request_autosave"):
		scene.request_autosave()


## Lignes ajoutées à l'infobulle d'un emplacement de greffe quand une greffe est tenue :
## ses effets et l'aperçu des statistiques avant → après.
func tooltip_lines(n: Dictionary) -> Array:
	var lines: Array = []
	if held == "" or n["type"] != "graft":
		return lines
	var g: Dictionary = Content.grafts().get(held, {})
	lines.append(["Poser « %s » ici :" % g.get("name", held), 14, PLAN])
	for e in g.get("effects", []):
		var line := Effects.describe(e)
		if line != "":
			lines.append(["   " + line, 15, PLAN])
	var owned: bool = Game.allocated.has(n["id"])
	var changes: Array = ui.panels.planner.preview_graft(n["id"], held)
	if not changes.is_empty():
		lines.append(["Statistiques" + ("" if owned else ", une fois l'emplacement appris") + " :", 15, DIM])
		for c in changes:
			lines.append(["   " + c["text"], 14, PLAN])
	elif not owned:
		lines.append(["Elle agira quand l'emplacement sera appris.", 15, DIM])
	var current := Game.graft_of(n["id"])
	if current != "" and current != held:
		lines.append(["Remplace « %s », qui revient dans l'inventaire." % Content.grafts()[current]["name"], 15, DIM])
	return lines
