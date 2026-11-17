## Lisibilité de l'attaque automatique, dessinée au sol sous les acteurs :
##
## - Cible : trois arcs fins posés au sol sous l'ennemi visé (player.target), qui tournent
##   lentement. Au changement de cible, ils se resserrent sur la nouvelle (Anim.ease_out).
## - Portée : quand des ennemis approchent mais qu'aucun n'est à portée, un cercle pointillé
##   très discret montre jusqu'où part l'attaque ; il s'efface dès qu'une cible est prise.
##
## Couleur : Art.c("joueur_accent"), la teinte du héros (c'est son attaque), sur un trait de
## contour pour rester lisible sur l'herbe comme sur le sol mort. Rien n'est dessiné en mode
## « viser le curseur » (Settings.aim_mode), où l'attaque ne choisit pas de cible.
extends Node2D

## Durées : resserrement sur une nouvelle cible, fondu d'entrée et de sortie.
const LOCK := 0.18
const FADE := 0.2
## Le cercle de portée apparaît quand un ennemi est à moins de NEAR × la portée.
const NEAR := 1.45
## Recherche des ennemis proches pour le cercle de portée : quelques fois par seconde.
const SCAN_EVERY := 0.15
const SEGMENTS := 3
const RANGE_DASHES := 56

var main
var t := 0.0
var target = null
var since_lock := 10.0
## Opacités de la cible et du cercle de portée (0 à 1).
var target_alpha := 0.0
var range_alpha := 0.0
var _pos := Vector2.ZERO
var _r := 10.0
var _near := false
var _scan := 0.0
var _drawn := false


func _process(delta: float) -> void:
	t += delta
	since_lock += delta
	var p = main.player if main != null else null
	if p == null:
		return
	var active: bool = Settings.aim_mode != "curseur"
	var tg = p.target if active else null
	if tg != null and (not is_instance_valid(tg) or tg.dead):
		tg = null
	if tg != target:
		if tg != null:
			since_lock = 0.0
		target = tg
	if target != null:
		_pos = target.position
		_r = target.radius
		target_alpha = minf(1.0, target_alpha + delta / FADE)
	else:
		target_alpha = maxf(0.0, target_alpha - delta / FADE)
	# Cercle de portée : des ennemis tout près, mais aucun à portée.
	_scan -= delta
	if _scan <= 0.0:
		_scan = SCAN_EVERY
		_near = active and target == null and not main.enemies_near(p.position, p.attack_range() * NEAR).is_empty()
	range_alpha = clampf(range_alpha + (delta if _near else -delta) / FADE, 0.0, 1.0)
	# Redessiné tant que quelque chose est visible, et une dernière fois pour s'effacer.
	if target_alpha > 0.0 or range_alpha > 0.0 or _drawn:
		_drawn = target_alpha > 0.0 or range_alpha > 0.0
		queue_redraw()


func _draw() -> void:
	var p = main.player if main != null else null
	if p == null:
		return
	var col := Art.c("joueur_accent")
	var ink := Art.c("contour")
	if range_alpha > 0.0:
		_draw_range(p.position, p.attack_range(), col, ink, range_alpha)
	if target_alpha > 0.0:
		_draw_target(col, ink, target_alpha)


## Trois arcs sur une ellipse au sol, sous les pieds de l'ennemi (comme son ombre).
func _draw_target(col: Color, ink: Color, a: float) -> void:
	var k := Anim.ease_out(clampf(since_lock / LOCK, 0.0, 1.0))
	var rx := (_r * 1.35 + 6.0) * lerpf(1.7, 1.0, k)
	var ry := rx * Art.OMBRE_APLATI * 1.25
	var center := _pos + Vector2(0, _r * Art.OMBRE_DECALAGE)
	var spin := t * 0.9
	var gap := 0.5
	var span := TAU / SEGMENTS - gap
	var alpha := a * lerpf(0.4, 1.0, k)
	for i in SEGMENTS:
		var a0 := spin + i * TAU / SEGMENTS
		var pts := PackedVector2Array()
		for j in 9:
			var ang := a0 + span * j / 8.0
			pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
		draw_polyline(pts, Color(ink, 0.5 * alpha), Art.TRAIT + 1.5, true)
		draw_polyline(pts, Color(col, 0.85 * alpha), Art.TRAIT_FIN, true)


## Cercle pointillé de la portée, autour du héros.
func _draw_range(center: Vector2, r: float, col: Color, ink: Color, a: float) -> void:
	var step := TAU / RANGE_DASHES
	var drift := t * 0.05
	for i in RANGE_DASHES:
		var a0 := drift + i * step
		var p0 := center + Vector2.from_angle(a0) * r
		var p1 := center + Vector2.from_angle(a0 + step * 0.45) * r
		draw_line(p0, p1, Color(ink, 0.22 * a), Art.TRAIT + 1.0)
		draw_line(p0, p1, Color(col, 0.32 * a), Art.TRAIT_FIN)
