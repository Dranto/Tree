## Étiquette d'herbier des statistiques (jalon 14.5, lot S) : tant qu'on maintient la touche
## « Statistiques » (C par défaut, clic du stick gauche à la manette ; réassignable dans Options →
## Commandes), le jeu garde son cours et une fiche posée à gauche donne vie, dégâts, vitesses,
## critique, défense, et l'attaque de base avec ses modificateurs cumulés. Aucune pause.
## Les valeurs viennent de Game.stats, formatées comme la section Statistiques de l'arbre
## (TreePlanner.format_stat) ; l'attaque, de Attack.describe. Une valeur au-dessus de la base du
## héros est teintée de sa catégorie, sinon elle reste en encre douce.
extends PanelContainer

const UiTheme = preload("res://scripts/ui_theme.gd")
const Planner = preload("res://scripts/tree_planner.gd")
const Content = preload("res://scripts/content.gd")
const Effects = preload("res://scripts/effects.gd")

const ACTION := "show_stats"
## Lignes de la fiche : [statistique, catégorie]. Les catégories sont celles des textes colorés
## (dégâts, vie, vitesse, critique, défense, recharge).
const ROWS := [
	["max_hp", "vie"], ["regen", "vie"], ["damage", "degats"], ["fire_rate", "vitesse"],
	["move_speed", "vitesse"], ["crit", "critique"], ["crit_mult", "critique"], ["armor", "defense"],
	["dash_cd", "recharge"],
]
const COLORS := {
	"degats": Color("e0745c"), "vie": Color("7fd36b"), "vitesse": Color("6fa8e8"),
	"critique": Color("e8c25a"), "defense": Color("b88a5a"), "recharge": Color("8fa3b8"),
}
const MARGIN := 20.0
## Distance sous le coin (niveau, points) où la fiche se pose.
const TOP := 110.0
const WIDTH := 330.0
const FADE := 7.0

## Opacité de la fiche (0 : cachée) ; elle suit la touche en un instant.
var alpha := 0.0
## Vrai tant que la touche est tenue (pour les tests, qui n'ont pas de vraie entrée).
var held_override := false
var _grid: GridContainer
var _attack_box: VBoxContainer
var _signature := ""
var _base := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)
	position = Vector2(MARGIN, TOP)
	custom_minimum_size = Vector2(WIDTH, 0)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := Label.new()
	title.text = Loc.t("Statistiques")
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.add_theme_font_size_override("font_size", UiTheme.fs(20))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 2)
	box.add_child(_grid)
	_attack_box = VBoxContainer.new()
	_attack_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack_box.add_theme_constant_override("separation", 3)
	box.add_child(_attack_box)
	_base = Effects.new().compute()
	visible = false
	modulate.a = 0.0
	Settings.changed.connect(func(): _signature = "")


## La touche est tenue, la partie suit son cours (ni arbre, ni menu, ni carte ouverts).
func wanted() -> bool:
	if get_tree().paused:
		return false
	return held_override or Input.is_action_pressed(ACTION)


func _process(delta: float) -> void:
	var on := wanted()
	alpha = move_toward(alpha, 1.0 if on else 0.0, delta * FADE)
	visible = alpha > 0.01
	modulate.a = alpha
	if on:
		_refresh()


## Remplit la fiche si les statistiques ou l'attaque ont changé depuis la dernière fois.
func _refresh() -> void:
	var st: Dictionary = Game.attack()
	var sig := "%s|%s|%s" % [str(Game.stats.hash()), str(st.hash()), Loc.lang()]
	if sig == _signature:
		return
	_signature = sig
	_fill(st)
	size = Vector2(WIDTH, 0)


func _fill(st: Dictionary) -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	for c in _attack_box.get_children():
		_attack_box.remove_child(c)
		c.queue_free()
	var defs := Content.stats()
	for row in ROWS:
		var name: String = row[0]
		var now := float(Game.stats.get(name, 0.0))
		var base := float(_base.get(name, now))
		var better := not is_equal_approx(now, base)
		var l := Label.new()
		l.text = Loc.data(str(defs.get(name, {}).get("label", name)))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(190, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", UiTheme.legible(15))
		_grid.add_child(l)
		var v := Label.new()
		v.text = Planner.format_stat(name, now)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_font_size_override("font_size", UiTheme.legible(15))
		v.add_theme_color_override("font_color", COLORS[row[1]] if better else UiTheme.SOFT)
		_grid.add_child(v)
	var head := Label.new()
	head.text = Loc.t("Attaque")
	head.add_theme_color_override("font_color", UiTheme.GOLD)
	head.add_theme_font_size_override("font_size", UiTheme.legible(16))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack_box.add_child(head)
	for line in Attack.describe(st):
		var a := Label.new()
		a.text = line
		a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		a.custom_minimum_size = Vector2(WIDTH - 44.0, 0)
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		a.add_theme_font_size_override("font_size", UiTheme.legible(14))
		a.add_theme_color_override("font_color", UiTheme.SOFT)
		_attack_box.add_child(a)
