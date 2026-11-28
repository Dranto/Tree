## Fruit de la graine (jalon 14, New Game+) : une fois la fin de l'aventure jouée (générique écrit
## dans l'herbe, Objectives.ENDING_SEEN), un fruit pousse au pied de la graine. Le joueur s'y tient une
## seconde (anneau qui se remplit, comme un sanctuaire) : le cycle suivant commence (Cycles.start_next).
## Aucun écran, aucun bouton. Pas de fruit dans la démo.
## Dessiné en code, au trait de la charte : un fruit de sève sur un brin courbé, encre fine.
extends Node2D

const Demo = preload("res://scripts/demo.gd")

## Place du fruit : au nord-est de la graine, entre les pierres du sanctuaire et le bord de l'oasis
## (la brèche de la finale est au sud).
const SPOT := Vector2(118.0, -96.0)
## Rayon de contact (px du monde) et temps à tenir (s).
const RADIUS := 46.0
const HOLD := 1.0
## Retombée de l'anneau quand le joueur s'éloigne (part de HOLD par seconde).
const DECAY := 2.0
## Pousse du fruit à son apparition (s).
const GROW := 1.4

var main
## Avancée du contact, de 0 à HOLD.
var progress := 0.0
## Pousse du fruit (0 : rien, 1 : mûr).
var grown := 0.0
var t := 0.0
## Le cycle suivant est lancé (on ne relance pas pendant le rechargement).
var picked := false


func _ready() -> void:
	position = SPOT
	z_index = 0
	grown = 1.0 if ripe() else 0.0


## Le fruit est là : l'aventure est finie et sa fin jouée, hors de la démo.
func ripe() -> bool:
	if Demo.active() or picked:
		return false
	if not bool(Game.flags.get(Objectives.ENDING_SEEN, false)):
		return false
	# Pendant que la fin se joue (vagues, générique), le fruit attend le dernier nom.
	var qu = main.get("quest_ui") if main != null else null
	if qu != null and qu.get("world_ending") != null and qu.world_ending.active:
		return false
	return true


func _process(delta: float) -> void:
	t += delta
	var r := ripe()
	var before := grown
	grown = clampf(grown + (delta / GROW if r else -delta / 0.4), 0.0, 1.0)
	if grown > 0.0 or before > 0.0:
		queue_redraw()


func _physics_process(delta: float) -> void:
	if main == null or picked or grown < 1.0:
		progress = 0.0
		return
	var p = main.player
	if p == null:
		return
	var near: bool = p.position.distance_squared_to(position) < RADIUS * RADIUS
	if near:
		progress += delta
		if progress >= HOLD:
			pick()
	else:
		progress = maxf(0.0, progress - delta * DECAY * HOLD)


## Le fruit est cueilli : onde de sève, puis le cycle suivant (sauvegarde et rechargement).
func pick() -> void:
	picked = true
	progress = HOLD
	# Point d'accroche son : « cycle_fruit » (passe d'Antoine) ; d'ici là, le son des Cœurs.
	Sfx.play("coeur", position)
	if main.get("fx") != null:
		main.fx.ring(position, 10.0, RADIUS * 3.0, 0.9, Color(Art.ec("seve"), 0.9), 5.0)
	if main.get("screen_fx") != null:
		main.screen_fx.glow(Art.ec("seve"), 0.45, 1.2)
	Cycles.start_next(main)


func _draw() -> void:
	if grown <= 0.0:
		return
	var k := ease(grown, -2.0)
	var ink := Art.c("contour")
	var sway := sin(t * 1.3) * 2.0
	# Brin courbé qui sort du sol, feuille, puis le fruit qui pend.
	var base := Vector2(-10.0, 30.0)
	var top := Vector2(6.0 + sway * 0.5, -34.0 * k)
	var mid := base.lerp(top, 0.5) + Vector2(-12.0, 0.0)
	var stem := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		stem.append(base.lerp(mid, u).lerp(mid.lerp(top, u), u))
	draw_polyline(stem, ink, 2.0, true)
	# Feuille en amande, nervure au trait.
	var leaf_at := stem[4]
	var dir := Vector2.from_angle(PI + 0.5 + sin(t * 1.1) * 0.08)
	var side := dir.orthogonal()
	var leaf := PackedVector2Array()
	for i in 13:
		var u := i / 12.0
		leaf.append(leaf_at + dir * 24.0 * k * u + side * sin(u * PI) * 7.0 * k)
	for i in range(11, 0, -1):
		var u := i / 12.0
		leaf.append(leaf_at + dir * 24.0 * k * u - side * sin(u * PI) * 7.0 * k)
	Art.safe_polygon(self, leaf, Art.ec("seve").darkened(0.25))
	Art.outline(self, leaf, ink, 1.4)
	draw_line(leaf_at, leaf_at + dir * 20.0 * k, ink, 1.0, true)
	var fruit_at := top + Vector2(sway, 14.0 * k)
	var r := 15.0 * k
	if r > 1.0:
		Art.shadow(self, Vector2(fruit_at.x, 30.0), r * 0.8)
		# Lueur qui bat lentement : on peut le toucher.
		var pulse := 0.5 + 0.5 * sin(t * 2.4)
		draw_circle(fruit_at, r * (1.9 + 0.25 * pulse), Color(Art.ec("seve"), 0.10 + 0.06 * pulse))
		Art.volume_circle(self, fruit_at, r, Art.ec("seve"))
		draw_arc(fruit_at, r, 0.0, TAU, 28, ink, 1.6, true)
		# Petite couronne de sépales au sommet.
		for i in 3:
			var a := -PI / 2.0 + (i - 1) * 0.6
			draw_line(fruit_at + Vector2.from_angle(a) * r * 0.8, fruit_at + Vector2.from_angle(a) * r * 1.35, ink, 1.4, true)
	# Anneau de contact au sol, comme pour un sanctuaire.
	if progress > 0.0:
		var f := clampf(progress / HOLD, 0.0, 1.0)
		draw_arc(Vector2.ZERO, RADIUS, -PI / 2.0, -PI / 2.0 + TAU * f, 48, Color(Art.ec("seve", "clair"), 0.9), 3.0, true)
