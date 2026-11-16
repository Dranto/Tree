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
	# Repère local : l'épine vole vers +x (rotation = direction du vol).
	if look == "cendre":
		# Boule de braise (élément cendre) : traînée de fumée, braises qui s'en détachent.
		for i in 4:
			draw_circle(Vector2(-6.0 - i * 5.0, sin(i * 1.7) * 1.5), 5.0 - i, Color(Art.c("brume").lightened(0.1), 0.4 - i * 0.08))
		draw_circle(Vector2.ZERO, 9.0, Color(Art.ec("cendre"), 0.3))
		Art.volume_circle(self, Vector2.ZERO, 6.0, Art.ec("cendre"), 1.0)
		draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, Art.ec("cendre", "sombre"), Art.TRAIT_FIN, true)
		draw_circle(Vector2(1.5, -1.0), 2.2, Art.ec("cendre", "clair"))
		return
	# Épine d'os (élément épine), avec une traînée rouge de danger pour qu'on la voie venir.
	draw_line(Vector2(-24, 0), Vector2(-6, 0), Color(Art.c("danger"), 0.35), 5.0, true)
	draw_line(Vector2(-14, 0), Vector2(-6, 0), Color(Art.c("danger"), 0.6), 2.5, true)
	var tip := Vector2(11, 0)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -4), tip, Vector2(-9, 0)]), Art.ec("epine", "clair"))
	draw_colored_polygon(PackedVector2Array([Vector2(-9, 0), tip, Vector2(-9, 4)]), Art.ec("epine").darkened(0.2))
	Art.outline(self, PackedVector2Array([Vector2(-9, -4), tip, Vector2(-9, 4)]), Art.ec("epine", "sombre"), 1.2)
