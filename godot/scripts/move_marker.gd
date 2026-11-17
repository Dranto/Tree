## Repère au sol de la destination du mode « moba » (clic droit) : dessiné sous les acteurs.
##
## - Au clic, un anneau se resserre sur le point (anticipation → impact), quatre chevrons
##   pointent vers le centre.
## - Pendant la marche, un petit anneau respire sur la destination.
## - À l'arrivée (ou quand la destination est abandonnée), le repère s'efface en un instant.
## Couleur : Art.c("accent"), la teinte de la sève vivante (le chemin choisi par le joueur).
extends Node2D

## Durée du resserrement au clic, et du fondu de sortie.
const PING := 0.22
const FADE := 0.18
const R := 13.0

var main
var t := 0.0
## Temps depuis le dernier clic, et opacité du repère (1 tant qu'une destination est posée).
var since_click := 10.0
var alpha := 0.0
var pos := Vector2.ZERO
var _clicks := 0
var _drawn := false


func _process(delta: float) -> void:
	t += delta
	since_click += delta
	var p = main.player if main != null else null
	if p == null:
		return
	if p.dest_clicks != _clicks:
		_clicks = p.dest_clicks
		since_click = 0.0
	if p.has_dest:
		pos = p.dest
		alpha = 1.0
	else:
		alpha = maxf(0.0, alpha - delta / FADE)
	# Redessiné tant qu'il est visible, et une dernière fois pour s'effacer.
	if alpha > 0.0 or _drawn:
		_drawn = alpha > 0.0
		queue_redraw()


func _draw() -> void:
	if alpha <= 0.0:
		return
	var col := Art.c("accent")
	var ink := Art.c("contour")
	var ping := clampf(since_click / PING, 0.0, 1.0)
	# Resserrement : l'anneau part large et se pose (ease out), puis respire doucement.
	var k := 1.0 - (1.0 - ping) * (1.0 - ping)
	var breathe := 0.5 + 0.5 * sin(t * 4.0)
	var r := lerpf(R * 2.6, R, k) * (1.0 + 0.06 * breathe * k)
	var a := alpha * lerpf(0.5, 1.0, k)
	draw_set_transform(pos)
	draw_circle(Vector2.ZERO, r, Color(col, 0.10 * a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(ink, 0.55 * a), Art.TRAIT + 2.0, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(col, 0.9 * a), Art.TRAIT, true)
	# Chevrons vers le centre : ils arrivent avec l'anneau puis restent posés.
	var gap := r + 7.0 + 6.0 * (1.0 - k)
	for i in 4:
		var d := Vector2.from_angle(PI / 4.0 + i * PI / 2.0)
		var n := d.orthogonal()
		var tip := d * gap
		var chev := PackedVector2Array([tip + d * 6.0 + n * 5.0, tip, tip + d * 6.0 - n * 5.0])
		draw_polyline(chev, Color(ink, 0.6 * a), Art.TRAIT + 1.5, true)
		draw_polyline(chev, Color(col, a), Art.TRAIT_FIN + 0.5, true)
	# Point central : l'endroit exact.
	draw_circle(Vector2.ZERO, 2.5, Color(col, a))
	# Éclat du clic : une onde fine qui s'ouvre et s'efface.
	if ping < 1.0:
		draw_arc(Vector2.ZERO, R * (1.0 + 1.6 * ping), 0.0, TAU, 40, Color(col, 0.6 * (1.0 - ping)), Art.TRAIT_FIN, true)
	draw_set_transform(Vector2.ZERO)
