## Sève perdue : l'expérience non dépensée laissée au sol là où le Porte-Graine est tombé.
##
## L'état fait foi dans Game.flags (« seve_perdue » = quantité, « seve_perdue_x » / « _y » =
## position) : il suit la sauvegarde sans en changer le format. main.gd crée ou retire ce nœud
## d'après ces drapeaux (main._sync_lost_sap) ; le toucher rend toute l'expérience (main.recover_sap).
## Mourir une seconde fois avant de la reprendre la perd : la nouvelle mort la remplace.
extends Node2D

## Distance à laquelle le joueur la ramasse (pas d'aimant : il faut aller la chercher).
const PICK := 34.0

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


## Une goutte de sève en volume qui flotte, son halo, une colonne de lumière qui se voit de loin
## et des éclats qui tournent autour (charte : la sève est le vert lumineux de la vie).
func _draw() -> void:
	var seve := Art.ec("seve")
	var clair := Art.ec("seve", "clair")
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	var bob := Vector2(0, -8.0 - 3.0 * sin(t * 2.0))
	Art.shadow(self, Vector2(0, 2), 10.0 * (1.0 - 0.1 * sin(t * 2.0)))
	# Colonne de lumière : elle s'efface vers le haut.
	for j in 5:
		var al := (0.2 + 0.08 * pulse) * (1.0 - j / 5.0)
		draw_rect(Rect2(-6.0, -24.0 - (j + 1) * 22.0, 12.0, 22.0), Color(seve, al * 0.5))
		draw_rect(Rect2(-2.0, -24.0 - (j + 1) * 22.0, 4.0, 22.0), Color(clair, al))
	Art.glow(self, bob, 36.0 + 6.0 * pulse, "seve")
	# Goutte : rond en bas, pointe en haut.
	var drop := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		var up := maxf(0.0, -sin(a))
		drop.append(bob + Vector2(cos(a) * 10.0 * (1.0 - 0.45 * up * up), sin(a) * 10.0 * (1.0 + 0.7 * up)))
	Art.volume(self, drop, seve, 1.0)
	Art.outline(self, drop, Art.ec("seve", "sombre"), Art.TRAIT)
	# Éclats qui tournent autour, devant puis derrière.
	for i in 5:
		var a := t * 1.6 + TAU * i / 5.0
		var p := bob + Vector2(cos(a) * 24.0, sin(a) * 9.0)
		draw_circle(p, 2.0 + 0.8 * sin(a), Color(clair, 0.55 + 0.4 * sin(a)))
