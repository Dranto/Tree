## Ce qui reste d'un Flétri purifié : sa silhouette s'éteint et tombe en cendre, puis une pousse
## de vie sort du sol à sa place et se fond dans la terre. Apparence seulement (aucun effet de jeu).
extends Node2D

const FletriArt = preload("res://scripts/fletri_art.gd")
## La silhouette s'éteint et s'effondre pendant ASH ; la pousse vit de SPROUT_FROM à DURATION.
const ASH := 0.5
const SPROUT_FROM := 0.32
const DURATION := 1.25

var kind_id := "fletri"
var radius := 14.0
var face := Vector2.RIGHT
var elite := false
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	if t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_at(self, Vector2.ZERO, t)


## Dessine l'état des restes au temps time (sert aussi à la galerie).
func draw_at(ci: CanvasItem, pos: Vector2, time: float) -> void:
	var r := radius
	if time < ASH:
		var k := time / ASH
		var e := Anim.ease_in(k)
		# La silhouette se tasse et s'éteint, puis s'effrite par le haut.
		ci.draw_set_transform(pos + Vector2(0, r * 0.35 * e), 0.0, Vector2(1.0 + 0.15 * e, 1.0 - 0.55 * e))
		var o := {"ash": minf(1.0, k * 1.6)}
		FletriArt.draw(ci, kind_id, Vector2.ZERO, r, face, 0.0, o)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if e > 0.6:
			# Un voile de cendre recouvre la fin de l'effondrement.
			ci.draw_colored_polygon(Art.ellipse(pos + Vector2(0, r * 0.3), r * 1.1, r * 0.55), Color(FletriArt.ash_color(), (e - 0.6) * 1.5))
	# Flocons qui s'envolent et un petit tas de cendre au sol.
	var heap := clampf((time - ASH * 0.6) / 0.3, 0.0, 1.0) * (1.0 - clampf((time - 0.8) / (DURATION - 0.8), 0.0, 1.0))
	if heap > 0.0:
		ci.draw_colored_polygon(Art.ellipse(pos + Vector2(0, r * 0.45), r * 0.9, r * 0.3), Color(FletriArt.ash_color().darkened(0.25), 0.7 * heap))
	var n := 6 if r < 15.0 else 9
	for i in n:
		var u := clampf((time - 0.12 - i * 0.025) / 0.8, 0.0, 1.0)
		if u <= 0.0 or u >= 1.0:
			continue
		var a := -PI / 2.0 + (i - (n - 1) / 2.0) * 0.38
		var q := pos + Vector2.from_angle(a) * r * (0.4 + 1.4 * Anim.ease_out(u)) + Vector2(sin(u * 6.0 + i) * 4.0, -r * 0.8 * u)
		var col := Art.ec("cendre", "clair") if i % 4 == 0 else FletriArt.ash_color().lightened(0.2)
		FletriArt._flake(ci, q, maxf(1.4, r * 0.08) * (1.0 - u * 0.6), Color(col, 1.0 - u))
	# La vie reprend : une pousse de sève sort du sol, ouvre deux feuilles, puis se fond.
	if time > SPROUT_FROM:
		var u := (time - SPROUT_FROM) / (DURATION - SPROUT_FROM)
		var grow := Anim.pop(clampf(u / 0.45, 0.0, 1.0))
		var fade := 1.0 - Anim.ease_in(clampf((u - 0.6) / 0.4, 0.0, 1.0))
		var s := maxf(8.0, r * 0.75) * (1.3 if elite else 1.0)
		var base := pos + Vector2(0, r * 0.35)
		Art.glow(ci, base + Vector2(0, -s * 0.4), s * 1.6 * grow, "seve")
		var top := base + Vector2(0, -s * 1.1 * grow)
		ci.draw_line(base, top, Color(Art.ec("seve", "sombre"), fade), maxf(1.5, s * 0.14), true)
		for sgn in [-1.0, 1.0]:
			var leaf := top + Vector2(sgn * s * 0.38 * grow, s * 0.05)
			Art._leaf(ci, leaf, s * 0.42 * grow, PI / 2.0 + sgn * 1.15, Color(Art.ec("seve"), fade))
		ci.draw_circle(top, maxf(1.2, s * 0.1) * grow, Color(Art.ec("seve", "clair"), fade))
