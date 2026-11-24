## Feuille de sève au bord de l'écran (jalon 11) : quand le prochain lieu de l'aventure est hors
## champ, une feuille dorée se pose au bord de l'écran, pointée vers lui. Aucun texte : le suivi
## d'objectif écrit et la distance en mètres ont disparu (l'histoire se lit dans le monde, voir
## sap_vein.gd pour la veine au sol). Dessin seulement.
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")

## Distance au bord de l'écran où se pose la feuille.
const EDGE := 56.0

var main
var t := 0.0
## Objectif suivi, relu quatre fois par seconde.
var _followed: Dictionary = {}
var _check := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Compatibilité : plus rien à remettre à jour (aucun texte).
func refresh() -> void:
	pass


func _process(delta: float) -> void:
	t += delta
	_check -= delta
	if _check <= 0.0:
		_check = 0.25
		_followed = Objectives.followed()
	queue_redraw()


## Position de la feuille à l'écran et sa direction, ou un tableau vide quand la cible se voit.
func leaf_at() -> Array:
	if main == null or not is_instance_valid(main) or main.player == null:
		return []
	var target = Objectives.target_pos(_followed)
	if target == null:
		return []
	var to_screen: Vector2 = get_viewport().get_canvas_transform() * (target as Vector2)
	var inner := Rect2(Vector2(EDGE, EDGE), size - Vector2(EDGE, EDGE) * 2.0)
	if inner.has_point(to_screen):
		return []
	var c := size / 2.0
	var d := to_screen - c
	if d.length() < 1.0:
		return []
	var k := minf(inner.size.x / 2.0 / maxf(absf(d.x), 0.001), inner.size.y / 2.0 / maxf(absf(d.y), 0.001))
	return [c + d * k, d.normalized()]


func _draw() -> void:
	var at := leaf_at()
	if at.is_empty():
		return
	var pos: Vector2 = at[0]
	var dir: Vector2 = at[1]
	var side := dir.orthogonal()
	var sway := 0.12 * sin(t * 2.2)
	dir = dir.rotated(sway)
	side = dir.orthogonal()
	var pulse := 0.75 + 0.25 * sin(t * 3.0)
	var gold := Color(UiTheme.GOLD, 0.9 * pulse)
	# Une feuille : deux arcs qui se rejoignent à la pointe (vers la cible) et à la queue.
	var tip := pos + dir * 18.0
	var tail := pos - dir * 14.0
	var pts := PackedVector2Array()
	for i in 9:
		var k := float(i) / 8.0
		pts.append(tail.lerp(tip, k) + side * sin(k * PI) * 9.0)
	for i in range(7, 0, -1):
		var k := float(i) / 8.0
		pts.append(tail.lerp(tip, k) - side * sin(k * PI) * 9.0)
	draw_colored_polygon(pts, gold)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.05, 0.05, 0.04, 0.7), 1.5, true)
	# La nervure et la queue.
	draw_line(tail - dir * 6.0, tip - dir * 3.0, Color(0.32, 0.22, 0.08, 0.8 * pulse), 1.5, true)
