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
	main.fx.ring(position, radius * 0.3, radius * 1.1, 0.35, Art.ec("poison", "clair"), 5.0)
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
	var forme := {"type": "cercle", "centre": Vector2.ZERO, "rayon": radius}
	if done:
		# Frappe : éclair de la charte, puis un nuage de spores qui se dissipe.
		var f := clampf((t - delay) / 0.25, 0.0, 1.0)
		Art.telegraph(self, forme, 1.0, f, t)
		for i in 8:
			var a := TAU * i / 8.0 + 0.3
			var q := Vector2.from_angle(a) * radius * (0.3 + 0.6 * Anim.ease_out(f))
			draw_arc(q, radius * (0.08 + 0.1 * f), 0.0, TAU, 12, Color(Art.ec("poison", "clair"), 1.0 - f), Art.TRAIT_FIN, true)
		return
	# Annonce : la grammaire de la charte (contour, voile qui se remplit, clignotement final).
	Art.telegraph(self, forme, k, -1.0, t)
	# La poche de spores elle-même, qui enfle et palpite de plus en plus vite.
	var beat := 0.5 + 0.5 * sin(t * (8.0 + 24.0 * k))
	var r := 9.0 + 8.0 * k + 1.5 * beat
	Art.volume_circle(self, Vector2.ZERO, r, Art.ec("poison").darkened(0.2), 0.9)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Art.ec("poison", "sombre"), Art.TRAIT_FIN, true)
	draw_circle(Vector2.ZERO, r * 0.45, Art.ec("poison", "clair").lerp(Art.c("danger_eclair"), k))
	for i in 3:
		var u := fposmod(t * 1.2 + i / 3.0, 1.0)
		var q := Vector2(sin(i * 2.0 + t * 3.0) * r * 0.8, -r * (0.8 + 1.6 * u))
		draw_arc(q, 2.0 + 2.5 * u, 0.0, TAU, 10, Color(Art.ec("poison", "clair"), 1.0 - u), Art.TRAIT_FIN, true)
