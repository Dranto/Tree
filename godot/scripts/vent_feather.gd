## Plume de cendre crachée par un Planeur de cendre (région de Vent) : vole en ligne droite (les
## rafales la dévient, wind.gd) et blesse le Porte-Graine. Un rocher l'arrête ; l'esquive
## (invulnérable) la laisse passer. Même contrat que enemy_thorn.gd.
extends Node2D

var main
var vel := Vector2.ZERO
var damage := 7.0
var life := 2.4
var radius := 5.0
var t := 0.0


func _ready() -> void:
	rotation = vel.angle()
	queue_redraw()


## Logique à pas fixe.
func _physics_process(delta: float) -> void:
	position += vel * delta
	rotation = vel.angle()
	life -= delta
	t += delta
	if life <= 0.0:
		queue_free()
		return
	var p = main.player
	if position.distance_squared_to(p.position) < (radius + p.radius) * (radius + p.radius):
		if p.invuln <= 0.0:
			p.take_hit(damage, null)
			queue_free()
		return
	if main.flora and main.flora.push_out(position, radius) != position:
		queue_free()


func _draw() -> void:
	# Repère local : la plume vole vers +x. Traînée rouge de danger, puis une plume grise à la
	# hampe d'os et au bout de braise (on la voit venir).
	draw_line(Vector2(-26, 0), Vector2(-8, 0), Color(Art.c("danger"), 0.35), 5.0, true)
	draw_line(Vector2(-16, 0), Vector2(-8, 0), Color(Art.c("danger"), 0.6), 2.5, true)
	var vane := Art.c("ennemi").lerp(Art.ec("vent", "sombre"), 0.4).lightened(0.1)
	var pts := PackedVector2Array([Vector2(10, 0), Vector2(4, -4.5), Vector2(-6, -4), Vector2(-10, -1.5), Vector2(-8, 0), Vector2(-10, 1.5), Vector2(-6, 4), Vector2(4, 4.5)])
	Art.volume(self, pts, vane, 0.7)
	Art.outline(self, pts, Art.c("ennemi_contour"), 1.2)
	draw_line(Vector2(-11, 0), Vector2(10, 0), Art.ec("epine", "clair").darkened(0.15), 1.5, true)
	draw_circle(Vector2(10, 0), 2.2, Art.ec("cendre"))
