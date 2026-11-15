## Poche de spores laissée par un Boursouflé à sa mort : un cercle s'annonce au sol, puis elle
## éclate. Elle blesse le Porte-Graine s'il est encore dedans (l'esquive la traverse) et aussi
## les autres Flétris : attirer les Boursouflés au milieu d'un groupe est une réponse.
extends Node2D

var main
var radius := 90.0
var delay := 0.9
var damage := 20.0
var enemy_damage := 50.0
var color := Color("7a6052")
var t := 0.0
var done := false


## Logique à pas fixe : compte à rebours puis éclatement.
func _physics_process(delta: float) -> void:
	t += delta
	if done:
		if t > delay + 0.25:
			queue_free()
		return
	if t < delay:
		return
	done = true
	var p = main.player
	if p.position.distance_to(position) < radius + p.radius:
		p.take_hit(damage, null)
	for e in main.enemies_near(position, radius):
		if not e.dead and e.has_method("take_damage"):
			e.take_damage(enemy_damage, false)
	main.fx.ring(position, radius * 0.3, radius * 1.1, 0.35, Color(0.85, 0.95, 0.45, 0.9), 5.0)
	main.fx.shake(4.0)
	# Par le chemin de l'autoload : ce script est aussi chargé par check_data.gd, sans autoloads.
	var sfx = get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play("nuage", position)


## Animation seulement.
func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var k := clampf(t / maxf(delay, 0.01), 0.0, 1.0)
	if done:
		var f := clampf((t - delay) / 0.25, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius * (0.6 + 0.5 * f), Color(0.8, 0.9, 0.4, 0.35 * (1.0 - f)))
		return
	# Annonce : la zone au sol se remplit depuis le centre, le bord clignote de plus en plus vite.
	var blink := 0.5 + 0.5 * sin(t * (10.0 + 30.0 * k))
	draw_circle(Vector2.ZERO, radius, Color(0.75, 0.85, 0.3, 0.08 + 0.06 * k))
	draw_circle(Vector2.ZERO, radius * k, Color(0.85, 0.9, 0.35, 0.12 + 0.14 * k))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.95, 1.0, 0.5, 0.35 + 0.45 * blink), 2.5)
	# La poche de spores elle-même, qui enfle.
	draw_circle(Vector2.ZERO, 10.0 + 8.0 * k, color.darkened(0.2))
	draw_circle(Vector2.ZERO, 6.0 + 6.0 * k, Color("c8d86a").lerp(Color("f4ffb0"), k))
