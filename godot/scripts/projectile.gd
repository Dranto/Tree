## Graine lumineuse tirée par le Porte-Graine.
extends Node2D

var main
var vel := Vector2.ZERO
var damage := 10.0
var pierce := 0
var life := 1.1
var radius := 6.0
var hit := {}


func _process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for e in main.enemies:
		if not is_instance_valid(e) or e.dead or hit.has(e.get_instance_id()):
			continue
		var r: float = radius + e.radius
		if position.distance_squared_to(e.position) < r * r:
			hit[e.get_instance_id()] = true
			main.player_hit_enemy(e, damage)
			if pierce <= 0:
				queue_free()
				return
			pierce -= 1
	queue_redraw()


func _draw() -> void:
	var dir := vel.normalized()
	draw_line(-dir * radius * 2.5, Vector2.ZERO, Color(0.7, 1.0, 0.5, 0.35), radius)
	draw_circle(Vector2.ZERO, radius * 1.6, Color(0.7, 1.0, 0.5, 0.25))
	draw_circle(Vector2.ZERO, radius, Color("d8ffb0"))
