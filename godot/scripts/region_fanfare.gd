## Célébration « région purifiée » (jalon 10), lancée par quest_ui.gd peu après la victoire sur le
## boss d'une région. Elle remplace l'ancien écran plein (ending.gd, qui ne sert plus que de base à
## l'épilogue de la finale) : le jeu continue, sans pause ni bouton.
##
## - Sur place : la région reverdit depuis l'arène, ses Cœurs et son centre (vagues de vie, fleurs de
##   la couleur de la région), un éclat de sève sur les bords de l'écran ; aucun Flétri ne naît
##   pendant la célébration.
## - Par-dessus le jeu, au milieu de l'écran : un médaillon des régions (les six secteurs de la carte)
##   où celle-ci reverdit puis voit son sceau se briser, le sous-titre, le titre et, pour la dernière
##   région, le texte de la fin de l'aventure (Objectives.ending_texts). Tout s'efface seul.
## - Sur la carte du monde : la région est ajoutée à world_map.pending_reveal, qui rejoue sa
##   reverdie et son sceau brisé à la prochaine ouverture.
##
## Le drapeau « <région>_fin_vue » (Objectives.mark_ending_seen) est posé dès le début : la
## célébration ne revient jamais, même après une sauvegarde en plein milieu.
## Tout est dessiné par le code (_draw) ; les textes sont des Label avec le thème commun.
extends Control

## La célébration est finie (ou passée).
signal closed

const UiTheme = preload("res://scripts/ui_theme.gd")
const Regions = preload("res://scripts/regions.gd")
const RegionUi = preload("res://scripts/region_ui.gd")
const WorldMap = preload("res://scripts/world_map.gd")

## Instants (secondes) : la région reverdit dans le médaillon, le sceau se brise, les textes, la fin.
const T_GREEN := 0.4
const T_SEAL := 1.9
const T_TEXT := 1.2
const DURATION := 8.0
## Avec le texte de la fin de l'aventure (dernière région), la célébration dure plus longtemps.
const DURATION_LONG := 13.0
const FADE := 1.0

var main
var active := false
var region := ""
## Textes montrés ({sub, title, body}) ; body seulement pour la dernière région.
var texts: Dictionary = {}
var t := 0.0
var duration := DURATION
## Régions déjà purifiées au début (le médaillon les montre vertes).
var _done: Dictionary = {}

var _box: VBoxContainer
var _sub: Label
var _title: Label
var _body: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.make()
	visible = false
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	_sub = _label(16, Color(0.82, 0.9, 0.8))
	_title = _label(38, UiTheme.GOLD, true)
	_body = _label(16, Color(0.92, 0.94, 0.86))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resized.connect(_layout)


func _label(size_px: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", UiTheme.fs(size_px))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	if bold:
		l.add_theme_font_override("font", UiTheme.font(true))
	_box.add_child(l)
	return l


## Échelle des textes et du médaillon : 1 pour un écran de 720 px de haut.
func _scale() -> float:
	return clampf(size.y / 720.0, 0.8, 2.0)


## Les textes sous le médaillon, centrés ; le texte long ne dépasse pas 46 % de la largeur.
func _layout() -> void:
	var s := _scale()
	_sub.add_theme_font_size_override("font_size", UiTheme.fs(int(16 * s)))
	_title.add_theme_font_size_override("font_size", UiTheme.fs(int(38 * s)))
	_body.add_theme_font_size_override("font_size", UiTheme.fs(int(16 * s)))
	var w := minf(size.x * 0.46, 760.0 * s)
	_body.custom_minimum_size.x = w
	_box.size = Vector2(w, 0)
	_box.reset_size()
	_box.position = Vector2((size.x - _box.size.x) / 2.0, _medal_center().y + 66.0 * s)


## Centre du médaillon : sous les annonces (hud.gd, 140 à 180 px du haut).
func _medal_center() -> Vector2:
	return Vector2(size.x / 2.0, 215.0 + 70.0 * _scale())


## Lance la célébration de la région (le boss vient de tomber).
func begin(m, reg: String) -> void:
	main = m
	region = reg
	t = 0.0
	active = true
	Objectives.mark_ending_seen(reg)
	texts = Objectives.ending_texts(reg)
	var last := Regions.all_purified(Game.flags)
	duration = DURATION_LONG if last and str(texts.get("body", "")) != "" else DURATION
	_done = {}
	for id in Regions.ids():
		if id != reg and Game.flags.get(Regions.boss_flag(id), false):
			_done[id] = true
	_sub.text = str(texts.get("sub", "Région purifiée"))
	_title.text = str(texts.get("title", "La région reverdit"))
	_body.text = str(texts.get("body", "")) if last else ""
	_body.visible = _body.text != ""
	visible = true
	_layout()
	_apply()
	_revive_world()
	Sfx.play("coeur")


## La région reverdit sur place : vagues de vie depuis l'arène, chaque Cœur et le centre.
func _revive_world() -> void:
	if main == null or not is_instance_valid(main):
		return
	var tint: Color = Regions.color(Regions.section(region, "heart").get("life_color", "saignement/clair"))
	var spots: Array = [Regions.arena_center(region), Regions.center(region)]
	for sp in Regions.heart_spots(region):
		spots.append(sp["pos"])
	for p in spots:
		main.ground.paint_wave(p, 900.0, 0.35)
		main.flora.spawn_patch(p, 700.0, 26, tint, 1.6, 700.0)
	if main.get("screen_fx") != null:
		main.screen_fx.glow(Art.ec("seve"), 0.4, 2.2)
	main.spawn_paused = true


## Passe à l'instant « seconds » (tests, captures).
func set_time(seconds: float) -> void:
	t = seconds
	_apply()
	queue_redraw()
	if t >= duration:
		finish()


## Fin de la célébration : les Flétris reviennent (sauf si un combat de boss a commencé).
func finish() -> void:
	if not active:
		return
	active = false
	visible = false
	if main != null and is_instance_valid(main) and not main.in_boss_fight():
		main.spawn_paused = false
	closed.emit()


func _process(delta: float) -> void:
	if not active:
		return
	# Par-dessus l'Arbre de vie (plein écran), rien ne se montre ; le temps continue avec le jeu.
	visible = main == null or not is_instance_valid(main) or not main.tree_ui.visible
	t += delta
	_apply()
	queue_redraw()
	if t >= duration:
		finish()


## Fondu d'entrée et de sortie de tout l'ensemble.
func _alpha() -> float:
	return clampf(t / FADE, 0.0, 1.0) * clampf((duration - t) / FADE, 0.0, 1.0)


func _apply() -> void:
	var a := _alpha()
	var ta := clampf((t - T_TEXT) / 0.8, 0.0, 1.0) * a
	_box.modulate = Color(1, 1, 1, ta)


func _draw() -> void:
	if not active:
		return
	var a := _alpha()
	if a <= 0.0:
		return
	var s := _scale()
	var c := _medal_center()
	# Un voile sombre et doux derrière le médaillon et les textes, pour les lire sur n'importe quel sol.
	var band_top := c.y - 70.0 * s
	var band_h := (_box.position.y + _box.size.y + 24.0 * s) - band_top
	for i in 8:
		var k := float(i) / 8.0
		var inset := size.x * (0.18 + 0.03 * i)
		draw_rect(Rect2(Vector2(inset, band_top + band_h * 0.04 * i), Vector2(size.x - 2.0 * inset, band_h * (1.0 - 0.08 * i))), Color(0.02, 0.04, 0.03, 0.07 * a * (1.0 - k * 0.5)))
	_draw_medal(c, 48.0 * s, a)


## Médaillon des régions : les secteurs de la carte, ceux déjà purifiés en vert ; celui de la région
## reverdit de la graine vers le bord, puis son sceau se brise et ses éclats s'envolent.
func _draw_medal(c: Vector2, r: float, a: float) -> void:
	var ids: Array = Regions.ids()
	var h := Regions.half_width()
	var inner := r * 0.26
	draw_circle(c, r + 6.0, Color(0.03, 0.05, 0.04, 0.85 * a))
	var green := Color("7fd36b")
	var grow := Anim.ease_out(clampf((t - T_GREEN) / 1.4, 0.0, 1.0))
	for id in ids:
		var ang := Regions.angle_of(id)
		var tint := RegionUi.tint(id)
		var col := Color(tint.darkened(0.35), 0.9 * a)
		if _done.has(id):
			col = Color(green.darkened(0.15), 0.9 * a)
		_sector(c, ang, h, inner, r, col)
		if id == region and grow > 0.0:
			_sector(c, ang, h, inner, lerpf(inner, r, grow), Color(green, 0.95 * a))
		draw_arc(c, r, ang - h, ang + h, 10, Color(tint.lightened(0.2), 0.8 * a), 2.0, true)
	for id in ids:
		var ang := Regions.angle_of(id)
		draw_line(c + Vector2.from_angle(ang - h) * inner, c + Vector2.from_angle(ang - h) * r, Color(0.02, 0.03, 0.02, 0.9 * a), 2.0, true)
	# La graine au centre.
	draw_circle(c, inner * 0.8, Color(UiTheme.GOLD, a))
	draw_circle(c, inner * 0.45, Color(UiTheme.GOLD.lightened(0.4), a))
	# Le sceau de la région, au bord de son secteur : il se brise après la reverdie.
	var seal_k := clampf((t - T_SEAL) / 1.1, 0.0, 1.0)
	var at := c + Vector2.from_angle(Regions.angle_of(region)) * (r + 4.0)
	var seal_col := RegionUi.tint(region).lightened(0.2).lerp(green, seal_k)
	var ci := self
	draw_set_transform(at, 0.0, Vector2.ONE * (1.3 * r / 48.0))
	WorldMap.draw_seal(ci, Vector2.ZERO, Color(seal_col, a), seal_k)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# L'éclat de la brisure : un anneau de sève qui s'élargit.
	if seal_k > 0.0 and seal_k < 1.0:
		draw_arc(at, 8.0 + 40.0 * seal_k * (r / 48.0), 0.0, TAU, 32, Color(Color("d8ffc0"), (1.0 - seal_k) * a), 2.5, true)


func _sector(c: Vector2, ang: float, h: float, r0: float, r1: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(c + Vector2.from_angle(ang - h + 2.0 * h * i / 8.0) * r0)
	for i in 9:
		pts.append(c + Vector2.from_angle(ang + h - 2.0 * h * i / 8.0) * r1)
	draw_colored_polygon(pts, col)
