## Épine tirée par un Tireur d'épines : vole en ligne droite et blesse le Porte-Graine.
## Un buisson d'épines l'arrête. L'esquive (invulnérable) la laisse passer.
extends Node2D

var main
var vel := Vector2.ZERO
var damage := 8.0
var life := 2.4
var radius := 5.0


func _ready() -> void:
	rotation = vel.angle()
	queue_redraw()


## Logique à pas fixe.
func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
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
	# Épine claire et effilée, avec une traînée rouge pour qu'on la voie venir.
	draw_line(Vector2(-22, 0), Vector2(-4, 0), Color(0.9, 0.3, 0.2, 0.35), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -3.5), Vector2(10, 0), Vector2(-9, 3.5)]), Color("e8d6b0"))
	draw_line(Vector2(-9, 0), Vector2(6, 0), Color("6a3a30"), 1.2)
