## Reverdie « région purifiée » (jalon 10, réduite au jalon 11), lancée par quest_ui.gd peu après
## la victoire sur le boss d'une région : sans pause, sans bouton et sans texte.
##
## - Sur place : la région reverdit depuis l'arène, ses Cœurs et son centre (vagues de vie, fleurs de
##   la couleur de la région), un éclat de sève sur les bords de l'écran ; aucun Flétri ne naît
##   pendant la reverdie.
## - Le bord de carte de la région reverdit (world_edge.gd, déjà branché sur le drapeau du boss).
## - Quand c'est la dernière région, la cendre reflue : des coulées grises filent de chaque région
##   vers la graine, où la brèche de la finale s'ouvre (finale_arena.gd).
## - Sur la carte du monde : la région est ajoutée à world_map.pending_reveal, qui rejoue sa
##   reverdie et son sceau brisé à la prochaine ouverture.
##
## Le drapeau « <région>_fin_vue » (Objectives.mark_ending_seen) est posé dès le début : la
## reverdie ne revient jamais, même après une sauvegarde en plein milieu.
extends Node

signal closed

const Regions = preload("res://scripts/regions.gd")

## Durée de la reverdie (s) ; plus longue quand la cendre reflue vers la graine (dernière région).
const DURATION := 6.0
const DURATION_LONG := 9.0
## Reflux de la cendre (dernière région) : durée, et flocons lancés par seconde.
const ASH_TIME := 5.0
const ASH_RATE := 24.0

var main
var active := false
var region := ""
## La dernière région vient d'être purifiée : la cendre reflue vers la graine.
var last := false
var t := 0.0
var duration := DURATION
var _ash_acc := 0.0


## Lance la reverdie de la région (le boss vient de tomber).
func begin(m, reg: String) -> void:
	main = m
	region = reg
	t = 0.0
	active = true
	Objectives.mark_ending_seen(reg)
	last = Regions.all_purified(Game.flags) and Regions.ids().size() > 1
	duration = DURATION_LONG if last else DURATION
	_revive_world()
	if last:
		_ash_reflux()
	Sfx.play("coeur")


## La cendre reflue : autour du joueur, des flocons gris dérivent vers la graine pendant ASH_TIME
## secondes (voir _process) ; une onde grise se resserre sur la graine.
func _ash_reflux() -> void:
	if main == null or not is_instance_valid(main) or main.get("fx") == null:
		return
	main.fx.ring(Vector2.ZERO, 900.0, 40.0, ASH_TIME, Color(0.3, 0.28, 0.27, 0.8), 8.0)


## La région reverdit sur place : vagues de vie depuis l'arène, chaque Cœur et le centre.
func _revive_world() -> void:
	if main == null or not is_instance_valid(main):
		return
	var tint: Color = Regions.color(Regions.section(region, "heart").get("life_color", "saignement/clair"))
	var spots: Array = [Regions.arena_center(region), Regions.center(region)]
	for sp in Regions.heart_spots(region):
		spots.append(sp["pos"])
	for p in spots:
		main.ground.paint_wave(p, 900.0, 0.35)
		main.flora.spawn_patch(p, 700.0, 26, tint, 1.6, 700.0)
	if main.get("screen_fx") != null:
		main.screen_fx.glow(Art.ec("seve"), 0.4, 2.2)
	main.spawn_paused = true


## Passe à l'instant « seconds » (tests, captures).
func set_time(seconds: float) -> void:
	t = seconds
	if t >= duration:
		finish()


## Fin de la célébration : les Flétris reviennent (sauf si un combat de boss a commencé).
func finish() -> void:
	if not active:
		return
	active = false
	if main != null and is_instance_valid(main) and not main.in_boss_fight():
		main.spawn_paused = false
	closed.emit()


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	if last and t < ASH_TIME and main != null and is_instance_valid(main) and main.player != null:
		_ash_acc += delta * ASH_RATE
		var dir: Vector2 = -main.player.position.normalized()
		while _ash_acc >= 1.0:
			_ash_acc -= 1.0
			main.fx.ash_drift(main.player.position, dir, 1)
	if t >= duration:
		finish()


