## Suivi de l'objectif en cours (en haut à droite de l'écran) et flèche discrète qui indique
## où aller. Nœuds Control avec le thème commun ; la flèche est dessinée par le code.
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const Regions = preload("res://scripts/regions.gd")
const RegionUi = preload("res://scripts/region_ui.gd")

const MARGIN := 20
const WIDTH := 330.0
## Distance au bord de l'écran où se pose la flèche.
const EDGE := 56.0
## Une cible à moins de cette distance (en pixels du monde) n'a plus de flèche : on la voit.
const NEAR := 300.0

var main
var key_hint := "J : journal   ·   M : carte"

var _panel: PanelContainer
var _head: Label
var _title: Label
var _text: Label
var _progress: Label
var _keys: Label
var t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.make()
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, MARGIN)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	var sb := UiTheme.box(Color(UiTheme.PAPER, 0.93), Color(UiTheme.GOLD, 0.3), 1, 2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 3)
	_panel.add_child(v)
	_head = _label(v, 14, UiTheme.GOLD)
	_title = _label(v, 19, UiTheme.INK)
	_title.add_theme_font_override("font", UiTheme.font(true))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = WIDTH - 26.0
	_text = _label(v, UiTheme.MIN_HUD_SIZE, Color(0.86, 0.803, 0.675))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = WIDTH - 26.0
	_progress = _label(v, UiTheme.MIN_HUD_SIZE, UiTheme.LEAF)
	_keys = _label(v, 14, UiTheme.SOFT)
	Objectives.changed.connect(refresh)
	refresh()


func _label(parent: Node, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Remet les textes à jour (changement d'objectif, d'avancement ou de touches).
func refresh() -> void:
	var o: Dictionary = Objectives.followed()
	var reg: String = Objectives.followed_region()
	var total: int = Objectives.main_total(reg)
	if o.is_empty():
		_title.text = "Tous les objectifs sont accomplis"
		if Regions.ids().size() > 1:
			_head.text = "FIN DE L'AVENTURE"
			_text.text = "Toutes les régions sont purifiées. L'Arbre de vie est en fleurs."
		else:
			_head.text = "TRANCHE DE RONCE"
			_text.text = "Le roncier est libre. Les autres branches de l'Arbre t'attendent."
		_progress.text = ""
	else:
		# Rang dans la suite (pas le nombre d'objectifs faits : une étape sautée ne décale rien).
		_head.text = "OBJECTIF  ·  %d / %d" % [Objectives.current_rank(reg), total]
		# Avec plusieurs régions, on dit laquelle : la flèche peut mener d'une région à l'autre.
		if str(o.get("region", "")) != "" and Regions.ids().size() > 1:
			_head.text += "  ·  " + RegionUi.short_name(str(o["region"]))
		_title.text = o["title"]
		_text.text = o["text"]
		var pr: Array = Objectives.progress(o)
		_progress.text = "%d / %d" % [pr[0], pr[1]] if not pr.is_empty() else ""
	_progress.visible = _progress.text != ""
	_keys.text = key_hint
	_panel.reset_size()


## Objectif suivi lu à la dernière image (_process), pour la flèche.
var _followed: Dictionary = {}


func _process(delta: float) -> void:
	t += delta
	# Une étiquette qui se replie peut annoncer une hauteur trop grande avant son premier
	# affichage : le cadre se recale sur son contenu dès qu'il est trop haut.
	if _panel.size.y > _panel.get_combined_minimum_size().y + 1.0:
		_panel.reset_size()
	# Le texte du compteur suit les drapeaux sans attendre un changement de liste.
	var o: Dictionary = Objectives.followed()
	_followed = o
	if not o.is_empty():
		var pr: Array = Objectives.progress(o)
		var s := "%d / %d" % [pr[0], pr[1]] if not pr.is_empty() else ""
		if s != _progress.text:
			refresh()
	queue_redraw()


func _draw() -> void:
	UiAudit.begin("fleche")
	if main == null or not is_instance_valid(main) or main.player == null:
		return
	# L'objectif suivi vient d'être lu par _process (même image) : on ne le recalcule pas.
	var o: Dictionary = _followed
	var target = Objectives.target_pos(o)
	if target == null:
		return
	var to_screen: Vector2 = get_viewport().get_canvas_transform() * (target as Vector2)
	var c := size / 2.0
	var world_d: float = (target as Vector2).distance_to(main.player.position)
	var pulse := 0.75 + 0.25 * sin(t * 3.0)
	var gold := Color(UiTheme.GOLD, 0.9 * pulse)
	var inner := Rect2(Vector2(EDGE, EDGE), size - Vector2(EDGE, EDGE) * 2.0)
	if inner.has_point(to_screen):
		if world_d > NEAR:
			# Visible à l'écran : un losange au-dessus de la cible.
			var m := to_screen + Vector2(0, -34 + 4.0 * sin(t * 3.0))
			draw_colored_polygon(PackedVector2Array([m + Vector2(0, 9), m + Vector2(-7, 0), m + Vector2(0, -9), m + Vector2(7, 0)]), gold)
		return
	var d := to_screen - c
	if d.length() < 1.0:
		return
	var k := minf(inner.size.x / 2.0 / maxf(absf(d.x), 0.001), inner.size.y / 2.0 / maxf(absf(d.y), 0.001))
	var pos := c + d * k
	var dir := d.normalized()
	var side := dir.orthogonal()
	var pts := PackedVector2Array([pos + dir * 16.0, pos - dir * 9.0 + side * 12.0, pos - dir * 3.0, pos - dir * 9.0 - side * 12.0])
	draw_colored_polygon(pts, gold)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.05, 0.05, 0.04, 0.7), 1.5)
	var font := UiTheme.font()
	var label := "%d m" % int(world_d / 12.0)
	var at := pos - dir * 40.0
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.MIN_HUD_SIZE).x
	var origin := Vector2(clampf(at.x - w / 2.0, 4.0, size.x - w - 4.0), clampf(at.y + 5.0, 18.0, size.y - 6.0))
	UiAudit.draw_text(self, "fleche", font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.MIN_HUD_SIZE, UiTheme.GOLD)
