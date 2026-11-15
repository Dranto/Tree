## Graine lumineuse tirée par le Porte-Graine.
extends Node2D

var main
var vel := Vector2.ZERO
var damage := 10.0
var pierce := 0
var life := 1.1
var radius := 6.0
var hit := {}
## Épine (Volée d'épines) : dessin et couleur propres, saignement posé à chaque ennemi touché.
var thorn := false
var color := Color("d8ffb0")
var bleed := 0.0
var bleed_duration := 0.0


func _ready() -> void:
	queue_redraw()


## Logique à pas fixe ; seuls les Flétris des cases voisines sont testés (grille spatiale).
func _physics_process(delta: float) -> void:
	position += vel * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for e in main.enemies_near(position, radius):
		if e.dead or hit.has(e.get_instance_id()):
			continue
		hit[e.get_instance_id()] = true
		main.player_hit_enemy(e, damage)
		if bleed > 0.0 and not e.dead:
			e.apply_status("saignement", damage * bleed, bleed_duration)
		if pierce <= 0:
			queue_free()
			return
		pierce -= 1


func _draw() -> void:
	var dir := vel.normalized()
	if thorn:
		# Épine effilée : pointe vers l'avant, base sombre.
		var side := dir.orthogonal() * radius * 0.55
		draw_colored_polygon(PackedVector2Array([dir * radius * 2.2, side - dir * radius * 1.4, -side - dir * radius * 1.4]), color)
		draw_line(-dir * radius * 3.0, -dir * radius * 1.2, Color(color, 0.35), radius * 0.6)
		return
	# Traînée : la graine file droit, donc sa queue est fixe. Segments qui s'effilent et s'effacent.
	var prev := Vector2.ZERO
	for i in 4:
		var q := -dir * radius * 2.2 * (i + 1)
		var k := 1.0 - i / 4.0
		draw_line(prev, q, Color(0.7, 1.0, 0.5, 0.5 * k), radius * 1.5 * k)
		prev = q
	draw_line(-dir * radius * 2.5, Vector2.ZERO, Color(0.7, 1.0, 0.5, 0.35), radius)
	draw_circle(Vector2.ZERO, radius * 1.6, Color(0.7, 1.0, 0.5, 0.25))
	draw_circle(Vector2.ZERO, radius, Color("d8ffb0"))
