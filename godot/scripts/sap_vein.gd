## Veine de sève (jalon 11) : l'orientation sans texte. Un filet de gouttes de sève court sur le sol,
## du joueur vers le prochain lieu de l'aventure (Objectives.followed › target_pos : sanctuaire, Cœur,
## arène, région suivante, brèche de la finale). Les gouttes avancent vers la cible : on suit le
## courant. Dessinée sous les acteurs (main.gd), comme le repère de déplacement.
##
## - En combat (ennemi proche, siège d'un Cœur, boss), sous terre et pendant la fin, elle s'efface ;
##   elle se rallume doucement quand le calme revient.
## - Près de la cible, elle se raccourcit puis disparaît : on voit le lieu.
## Couleur : Art.ec("seve", "clair"), la sève vivante.
extends Node2D

## Longueur maximale du filet (pixels du monde) et écart entre deux gouttes.
const LENGTH := 520.0
const STEP := 26.0
## Le filet part à cette distance du joueur (il ne cache pas le héros).
const START := 46.0
## En deçà de cette distance de la cible, la veine s'efface : le lieu est à l'écran.
const NEAR := 260.0
## Vitesse du courant (pixels par seconde) et ampleur de l'ondulation.
const FLOW := 70.0
const WAVE := 9.0
## Un ennemi à moins de cette distance du joueur : combat, la veine s'efface.
const FIGHT_NEAR := 380.0

var main
var t := 0.0
## Opacité actuelle (0 à 1) : monte et descend doucement.
var alpha := 0.0
var _target = null
var _check := 0.0
var _calm := true


func _ready() -> void:
	z_index = 0


## Faut-il montrer la veine maintenant ? (cible connue, pas de combat, pas trop près.)
func wanted() -> bool:
	if main == null or not is_instance_valid(main) or main.player == null:
		return false
	if _target == null or not _calm:
		return false
	return (_target as Vector2).distance_to(main.player.position) > NEAR


func _process(delta: float) -> void:
	t += delta
	_check -= delta
	if main == null or not is_instance_valid(main) or main.player == null:
		return
	# La cible et le calme sont relus quatre fois par seconde (assez pour un filet qui suit).
	if _check <= 0.0:
		_check = 0.25
		_target = Objectives.target_pos(Objectives.followed())
		_calm = _is_calm()
	var goal := 1.0 if wanted() else 0.0
	alpha = move_toward(alpha, goal, delta * (0.8 if goal > alpha else 2.5))
	if alpha > 0.0 or visible:
		queue_redraw()


func _is_calm() -> bool:
	if main.in_boss_fight() or main.siege_heart() != null:
		return false
	if main.has_method("underground") and main.underground():
		return false
	if bool(Game.flags.get(Objectives.ENDING_SEEN, false)):
		return false
	for e in main.enemies_near(main.player.position, FIGHT_NEAR):
		return false
	return true


func _draw() -> void:
	if alpha <= 0.01 or _target == null or main == null or main.player == null:
		return
	var from: Vector2 = main.player.position
	var to: Vector2 = _target
	var d := to - from
	var dist := d.length()
	if dist < 1.0:
		return
	var dir := d / dist
	var side := dir.orthogonal()
	var reach := minf(LENGTH, dist - NEAR * 0.6)
	if reach <= START:
		return
	var col := Art.ec("seve", "clair")
	var deep := Art.ec("seve")
	# Gouttes qui avancent : chacune glisse de STEP par cycle, apparaît au départ et s'éteint au bout.
	var shift := fmod(t * FLOW, STEP)
	var s := START + shift
	while s < reach:
		var k := (s - START) / (reach - START)
		# Fondu à l'entrée et à la sortie du filet.
		var fade := clampf(k * 4.0, 0.0, 1.0) * clampf((1.0 - k) * 3.0, 0.0, 1.0)
		var wave := sin(s * 0.022 - t * 1.6) * WAVE * (0.4 + k)
		var p := from + dir * s + side * wave
		var pulse := 0.8 + 0.2 * sin(t * 5.0 - s * 0.05)
		var a := alpha * fade * pulse
		draw_circle(p, 6.0, Color(deep, 0.16 * a))
		draw_circle(p, 3.0, Color(col, 0.75 * a))
		s += STEP
