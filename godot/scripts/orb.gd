## Essence de vie laissée par un Flétri purifié : donne de l'expérience.
##
## Retour du ramassage (charte, anticipation / impact / retour) :
## - apparition : l'essence jaillit en grossissant (Anim.pop) ;
## - anticipation : dès que l'aimant l'attrape, elle gonfle un instant ;
## - attraction : elle accélère vers le joueur en laissant une traînée ;
## - impact : au contact, un éclat de sève et un son dont la hauteur monte si l'on enchaîne.
extends Node2D

var main
var value := 3.0
var t := 0.0
## Âge en pas de jeu : une essence oubliée finit par rejoindre le joueur (LATE_AFTER secondes,
## dans un rayon de LATE_RANGE), pour que l'expérience suive les ennemis vaincus et que la durée
## d'un niveau reste prévisible (data/difficulty.json).
var age := 0.0
const LATE_AFTER := 5.0
const LATE_RANGE := 650.0
const LATE_SPEED := 300.0
## Secondes d'attraction à vitesse croissante (la vitesse de départ est celle d'avant la charte).
const PULL_SPEED := 520.0
const PULL_SPEED_MAX := 780.0
const PULL_RAMP := 0.35
## Durée de l'anticipation (gonflement) et de la traînée.
const SWELL := 0.12
const TRAIL := 5

## Secondes passées sous l'aimant.
var pulled := 0.0
var _trail: Array = []
## Enchaînement de ramassages : fait monter la hauteur du son, retombe après 0,45 s sans ramassage.
static var _combo := 0
static var _combo_at := -1000


## Animation seulement (pulsation, apparition).
func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Logique à pas fixe : attirée par le joueur, ramassée au contact.
func _physics_process(delta: float) -> void:
	var p = main.player
	var to: Vector2 = p.position - position
	var d := to.length()
	age += delta
	if d < Game.stats["pickup"]:
		pulled += delta
		var speed := lerpf(PULL_SPEED, PULL_SPEED_MAX, Anim.ease_in(pulled / PULL_RAMP))
		_trail.push_front(position)
		position += to / maxf(d, 1.0) * minf(d, speed * delta)
	elif age > LATE_AFTER and d < LATE_RANGE:
		_trail.push_front(position)
		position += to / maxf(d, 1.0) * minf(d, LATE_SPEED * delta)
	else:
		pulled = 0.0
		_trail.clear()
	if _trail.size() > TRAIL:
		_trail.resize(TRAIL)
	if d < 20.0:
		_collect()


func _collect() -> void:
	Game.add_xp(value)
	main.fx.pickup(position, "seve", 4)
	var now := Time.get_ticks_msec()
	_combo = _combo + 1 if now - _combo_at < 450 else 0
	_combo_at = now
	Sfx.play("ramasse", position, 1.0 + 0.045 * mini(_combo, 10))
	queue_free()


func _draw() -> void:
	var seve := Art.ec("seve")
	var clair := Art.ec("seve", "clair")
	var pop := Anim.pop(t / Anim.DUREE["apparition"])
	# Anticipation : un gonflement bref au moment où l'aimant l'attrape.
	var swell := 1.0 + 0.35 * Anim.flash(pulled / SWELL) * (1.0 if pulled > 0.0 else 0.0)
	var k := pop * swell
	var pulse := 0.5 + 0.5 * sin(t * 6.0)
	# Traînée : des points de plus en plus petits sur le chemin parcouru.
	for i in _trail.size():
		var q: Vector2 = _trail[i] - position
		var f := 1.0 - float(i + 1) / (TRAIL + 1)
		draw_circle(q, 3.6 * f * k, Color(seve, 0.4 * f))
	draw_circle(Vector2.ZERO, 9.0 * k, Color(seve, 0.12 + 0.1 * pulse))
	# Petite goutte de sève : pointe en haut, reflet clair.
	var drop := PackedVector2Array([Vector2(0, -6.2), Vector2(2.6, -1.8), Vector2(3.3, 1.2), Vector2(1.8, 3.6),
		Vector2(0, 4.2), Vector2(-1.8, 3.6), Vector2(-3.3, 1.2), Vector2(-2.6, -1.8)])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	draw_colored_polygon(drop, seve)
	draw_circle(Vector2(-1.0, 0.0), 1.2, clair)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
