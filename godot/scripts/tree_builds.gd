## Builds enregistrés, sur l'écran de l'Arbre de vie (en haut à droite, à la place du résumé) :
## un panneau, pas un écran. La logique est dans game.gd (builds, switch_build, refund_cost).
##
## Une ligne par emplacement (data/respec.json, « slots ») : le nom (modifiable sur place), ce qu'il
## contient (nœuds appris, nœuds prévus, greffes posées) et ses actions :
## - « Charger » : bascule vers ce build. Gratuit dans le cercle d'un sanctuaire ravivé ; ailleurs, coûte
##   l'essence que coûterait l'oubli des nœuds qui disparaissent (le prix est écrit sur le bouton).
##   Un emplacement vide charge un build neuf : tous les points rendus, la couronne gardée.
## - « Copier ici » : enregistre le build actif, avec son plan, dans cet emplacement.
## - « Vider » : efface un emplacement qui n'est pas le build actif.
##
## Préparer un build sans dépenser : le mode plan (tree_panels.gd) trace des nœuds sans points ; le plan
## appartient au build actif et le suit d'un emplacement à l'autre. Un build qui demande plus de points
## que la partie n'en a garde ses nœuds en trop dans son plan.
extends PanelContainer

const UiTheme = preload("res://scripts/ui_theme.gd")

const DIM := Color(0.731, 0.683, 0.574)
const PLAN := Color("f2d06b")
const SHORT := Color("e0675e")
const WIDTH := 372.0

## Écran de l'arbre (tree_ui.gd) et outils (tree_panels.gd), pour les messages et le plan.
var ui
var panels
var _rows: VBoxContainer
var _rule: Label
var _names: Array = []
var _sig := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -WIDTH - 16.0
	offset_right = -16.0
	# Sous la barre d'outils, qui va jusqu'au milieu de l'écran en 1280×720.
	offset_top = 104.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var title := Label.new()
	title.text = "Builds"
	title.add_theme_font_override("font", UiTheme.font(true))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(title)
	_rule = Label.new()
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rule.custom_minimum_size = Vector2(WIDTH - 24.0, 0)
	_rule.add_theme_font_size_override("font_size", 14)
	_rule.add_theme_color_override("font_color", DIM)
	box.add_child(_rule)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	box.add_child(_rows)
	Game.tree_changed.connect(refresh)
	refresh()


func _process(_delta: float) -> void:
	# L'essence et le sanctuaire changent sans tree_changed (expérience gagnée, joueur qui bouge) :
	# le panneau se refait quand ce qu'il affiche change.
	if is_visible_in_tree() and _signature() != _sig:
		refresh()


func _signature() -> String:
	var parts := PackedStringArray([str(Game.active_build), str(Game.essence()), str(Game.at_sanctuary), str(Game.allocated.size())])
	for i in Game.build_slots():
		parts.append(str(Game.switch_cost(i)))
	return "/".join(parts)


## Texte de la règle d'oubli, selon l'endroit où se tient le joueur.
func rule_text() -> String:
	var r: Dictionary = preload("res://scripts/content.gd").respec()
	if Game.at_sanctuary and bool(r.get("free_at_sanctuary", true)):
		return "Au sanctuaire : oublier des nœuds et changer de build est gratuit.\n« Nouveau » repart de la graine, « Copier ici » enregistre le build actif."
	return "Près de la graine (anneaux 1 à %d), oublier est gratuit. Plus loin, cela coûte de l'essence, prise sur le niveau en cours (%d en réserve). Au sanctuaire, tout est gratuit.\n« Nouveau » repart de la graine, « Copier ici » enregistre le build actif." % [int(r.get("free_rings", 3)), Game.essence()]


func refresh() -> void:
	if _rows == null:
		return
	# Ne pas refaire les lignes pendant la saisie d'un nom.
	for e in _names:
		if is_instance_valid(e) and e.has_focus():
			return
	_sig = _signature()
	_rule.text = rule_text()
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	_names = []
	for i in Game.build_slots():
		_rows.add_child(_row(i))


func _row(i: int) -> Control:
	var info: Dictionary = Game.build_info(i)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	var name_edit := LineEdit.new()
	name_edit.text = info["name"]
	name_edit.max_length = 24
	name_edit.custom_minimum_size = Vector2(150, 0)
	name_edit.context_menu_enabled = false
	name_edit.add_theme_color_override("font_color", UiTheme.GOLD if info["active"] else UiTheme.INK)
	name_edit.text_submitted.connect(func(t): _rename(i, t, name_edit))
	name_edit.focus_exited.connect(func(): _rename(i, name_edit.text, null))
	_names.append(name_edit)
	head.add_child(name_edit)
	if info["active"]:
		var tag := Label.new()
		tag.text = "actif"
		tag.add_theme_color_override("font_color", UiTheme.LEAF)
		head.add_child(tag)
	else:
		var cost: int = Game.switch_cost(i)
		var load_b: Button = _button(head, "Nouveau" if info["empty"] else "Charger", func(): load_build(i))
		if cost > 0:
			load_b.text += " · %d" % cost
			load_b.tooltip_text = "Coûte %d essence hors d'un sanctuaire." % cost
		load_b.disabled = cost > Game.essence()
		_button(head, "Copier ici", func(): copy_here(i))
		if not info["empty"]:
			_button(head, "Vider", func(): clear(i))
	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", DIM)
	if info["empty"]:
		detail.text = "Vide"
	else:
		var parts := PackedStringArray(["%d nœud(s) appris" % info["nodes"]])
		if info["planned"] > 0:
			parts.append("%d prévu(s)" % info["planned"])
		parts.append("%d greffe(s)" % info["grafts"])
		detail.text = "  ·  ".join(parts)
	col.add_child(detail)
	return col


func _button(parent: Node, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _rename(i: int, text: String, edit) -> void:
	if text.strip_edges() != Game.build_name(i):
		Game.rename_build(i, text)
	if edit != null:
		edit.release_focus()
	_autosave()


## Bascule vers le build i (voir Game.switch_build). Renvoie false si l'essence ne suffit pas.
func load_build(i: int) -> bool:
	var cost: int = Game.switch_cost(i)
	if not Game.switch_build(i):
		_say("Changer de build ici coûte %d essence : il t'en manque %d. Au sanctuaire, c'est gratuit." % [cost, cost - Game.essence()])
		return false
	if panels != null:
		panels.planner.clear_undo()
	var info: Dictionary = Game.build_info(i)
	var text := "Build « %s » chargé" % info["name"]
	if cost > 0:
		text += " (%d essence)" % cost
	if info["planned"] > 0:
		text += " : %d nœud(s) attendent dans le plan" % info["planned"]
	_say(text)
	_autosave()
	return true


func copy_here(i: int) -> void:
	if Game.copy_build_to(i):
		_say("Build actif copié dans « %s »" % Game.build_name(i))
		_autosave()


func clear(i: int) -> void:
	if Game.clear_build(i):
		_say("« %s » vidé" % Game.build_name(i))
		_autosave()


func _say(text: String) -> void:
	if panels != null:
		panels.say(text)


func _autosave() -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene != null and scene.has_method("request_autosave"):
		scene.request_autosave()
