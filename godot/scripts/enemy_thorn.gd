## Épine tirée par un Tireur d'épines (ou une élite épineuse), ou boule de cendre crachée par un
## Cracheur de cendre (look = "cendre") : vole en ligne droite et blesse le Porte-Graine.
## Un buisson d'épines l'arrête. L'esquive (invulnérable) la laisse passer.
extends Node2D

var main
var vel := Vector2.ZERO
var damage := 8.0
var life := 2.4
var radius := 5.0
## Apparence : "" (épine) ou "cendre" (boule de braise).
var look := ""


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
	if look == "cendre":
		# Boule de cendre rougeoyante, avec sa traînée de fumée.
		draw_line(Vector2(-20, 0), Vector2(-4, 0), Color(0.5, 0.45, 0.42, 0.35), 6.0)
		draw_circle(Vector2.ZERO, 6.5, Color("4a3a34"))
		draw_circle(Vector2(1, 0), 4.2, Color("ff9a4a"))
		draw_circle(Vector2(2, -1), 1.8, Color("fff0b0"))
		return
	# Épine claire et effilée, avec une traînée rouge pour qu'on la voie venir.
	draw_line(Vector2(-22, 0), Vector2(-4, 0), Color(0.9, 0.3, 0.2, 0.35), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -3.5), Vector2(10, 0), Vector2(-9, 3.5)]), Color("e8d6b0"))
	draw_line(Vector2(-9, 0), Vector2(6, 0), Color("6a3a30"), 1.2)
