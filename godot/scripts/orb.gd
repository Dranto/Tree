## Essence de vie laissée par un Flétri purifié : donne de l'expérience.
extends Node2D

var main
var value := 3.0
var t := 0.0


## Animation seulement (pulsation).
func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Logique à pas fixe : attirée par le joueur, ramassée au contact.
func _physics_process(delta: float) -> void:
	var p = main.player
	var to: Vector2 = p.position - position
	var d := to.length()
	if d < Game.stats["pickup"]:
		position += to / maxf(d, 1.0) * minf(d, 520.0 * delta)
	if d < 20.0:
		Game.add_xp(value)
		queue_free()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(t * 6.0)
	draw_circle(Vector2.ZERO, 9.0, Color(0.6, 1.0, 0.6, 0.15 + 0.1 * pulse))
	draw_circle(Vector2.ZERO, 4.0, Color("aef5a0"))
