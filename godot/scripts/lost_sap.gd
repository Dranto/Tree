## Sève perdue : l'expérience non dépensée laissée au sol là où le Porte-Graine est tombé.
##
## L'état fait foi dans Game.flags (« seve_perdue » = quantité, « seve_perdue_x » / « _y » =
## position) : il suit la sauvegarde sans en changer le format. main.gd crée ou retire ce nœud
## d'après ces drapeaux (main._sync_lost_sap) ; le toucher rend toute l'expérience (main.recover_sap).
## Mourir une seconde fois avant de la reprendre la perd : la nouvelle mort la remplace.
extends Node2D

## Distance à laquelle le joueur la ramasse (pas d'aimant : il faut aller la chercher).
const PICK := 34.0
const COLOR := Color("e8d36b")   ## or doux : la sève perdue est rare et précieuse (Art.c("or"), un ton plus clair)
const CORE := Color("b6f28a")

var main
var amount := 0.0
var t := 0.0


## Animation seulement.
func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if main.player.position.distance_squared_to(position) < PICK * PICK:
		main.recover_sap()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	# Halo et colonne de lumière qui se voit de loin.
	draw_circle(Vector2.ZERO, 40.0 + 6.0 * pulse, Color(COLOR, 0.10))
	draw_circle(Vector2.ZERO, 24.0, Color(COLOR, 0.16 + 0.08 * pulse))
	draw_rect(Rect2(-3, -70, 6, 70), Color(COLOR, 0.18 + 0.1 * pulse))
	draw_rect(Rect2(-1.5, -110, 3, 110), Color(COLOR, 0.12))
	# Goutte de sève.
	var drop := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		var r := 10.0 * (1.0 + 0.55 * maxf(0.0, -sin(a)))
		drop.append(Vector2(cos(a) * 10.0 * (1.0 - 0.35 * maxf(0.0, -sin(a))), sin(a) * r) + Vector2(0, -6 - 2.0 * pulse))
	draw_colored_polygon(drop, COLOR)
	draw_circle(Vector2(-3, -8 - 2.0 * pulse), 3.0, Color(1, 1, 0.9, 0.8))
	# Éclats qui tournent autour.
	for i in 5:
		var a := t * 1.6 + TAU * i / 5.0
		var p := Vector2(cos(a) * 26.0, sin(a) * 10.0 - 6.0)
		draw_circle(p, 2.5, Color(CORE, 0.8))
