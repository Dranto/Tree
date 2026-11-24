## Orientation et grands moments de l'aventure (jalon 11 : l'histoire se lit dans le monde) :
## veine de sève au sol et feuille au bord de l'écran vers le prochain lieu, carte (M), reverdie
## d'une région purifiée (sur place, sans pause ni texte : region_fanfare.gd) et fin de l'aventure
## jouée dans le monde (world_ending.gd). Plus de journal, de suivi écrit ni d'épilogue.
## La scène de jeu en crée une seule (voir main.gd).
extends Node

const Tracker = preload("res://scripts/objective_tracker.gd")
const SapVein = preload("res://scripts/sap_vein.gd")
const WorldEnding = preload("res://scripts/world_ending.gd")
const WorldMap = preload("res://scripts/world_map.gd")
const Fanfare = preload("res://scripts/region_fanfare.gd")

## Délai entre la mort d'un boss régional et la reverdie de sa région.
const ENDING_DELAY := 2.0
## Délai entre la mort de la Flétrissure et la fin (le creux refleurit).
const EPILOGUE_DELAY := 4.0

var main
## Feuille de sève au bord de l'écran (objective_tracker.gd).
var tracker
## Veine de sève au sol (sap_vein.gd) et fin de l'aventure dans le monde (world_ending.gd).
var vein
var world_ending
var world_map
## Reverdie « région purifiée » en cours ou passée (region_fanfare.gd) : le jeu continue dessous.
var fanfare
## "" (rien d'ouvert) ou "carte".
var current := ""
var ending_enabled := true
var _tracker_layer: CanvasLayer
var _ending_wait := 0.0
var _epilogue_wait := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_tracker_layer = CanvasLayer.new()
	_tracker_layer.layer = 6
	add_child(_tracker_layer)
	tracker = Tracker.new()
	tracker.main = main
	_tracker_layer.add_child(tracker)
	# La veine et les noms du générique sont au sol : sous les acteurs.
	vein = SapVein.new()
	vein.main = main
	world_ending = WorldEnding.new()
	world_ending.main = main
	var under = main.get("actors_layer")
	for n in [vein, world_ending]:
		main.add_child(n)
		if under != null:
			main.move_child(n, under.get_index())

	var overlays := CanvasLayer.new()
	overlays.layer = 12
	overlays.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlays)
	world_map = WorldMap.new()
	world_map.main = main
	overlays.add_child(world_map)

	var fanfare_layer := CanvasLayer.new()
	fanfare_layer.layer = 7
	fanfare_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fanfare_layer)
	fanfare = Fanfare.new()
	fanfare.main = main
	fanfare_layer.add_child(fanfare)
	Objectives.attach(main)
	# Pas de fin de partie pendant les bancs d'essai et les combats de test.
	ending_enabled = main.build_bot == null and not main.autotest_boss and not main.benchmark


func _exit_tree() -> void:
	Objectives.detach(main)


func _setup_input() -> void:
	# Touche logique M, quelle que soit la disposition du clavier.
	if not InputMap.has_action("toggle_map"):
		InputMap.add_action("toggle_map")
		var ev := InputEventKey.new()
		ev.keycode = KEY_M
		InputMap.action_add_event("toggle_map", ev)


## Nom de la touche d'une action, pour les glyphes.
func key_name(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k:
			return OS.get_keycode_string(k.keycode if k.keycode != KEY_NONE else k.physical_keycode)
	return "?"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map"):
		toggle("carte")
		get_viewport().set_input_as_handled()
	elif current != "" and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Une fenêtre modale (Arbre, pause) est déjà ouverte : la carte attend.
func _blocked() -> bool:
	return main.tree_ui.visible or main.pause_menu.visible or (get_tree().paused and current == "")


func toggle(which: String) -> void:
	if current == which:
		close()
		return
	if current == "" and _blocked():
		return
	current = "carte"
	get_tree().paused = true
	world_map.open()
	_veil()


func close() -> void:
	if current == "":
		return
	world_map.close()
	current = ""
	get_tree().paused = false
	_veil()


## Transition d'ouverture ou de fermeture : un voile sombre qui se dissipe vite.
func _veil() -> void:
	if main.get("screen_fx") != null:
		main.screen_fx.fade(Art.c("decor"), 0.45, 0.0, main.screen_fx.FADE_PANEL)


## La feuille s'efface par-dessus l'Arbre de vie (il couvre tout l'écran), pendant le combat de boss
## et pendant la reverdie d'une région ou la fin.
func tracker_shown() -> bool:
	return not main.tree_ui.visible and not main.in_boss_fight() and not fanfare.active and not world_ending.active


func _process(delta: float) -> void:
	_tracker_layer.visible = tracker_shown()
	if not ending_enabled or fanfare.active or world_ending.active:
		return
	# Fin de l'aventure : la Flétrissure vaincue, après un court délai, une seule fois.
	if Objectives.epilogue_due() and not Objectives.ending_due():
		if not get_tree().paused:
			_epilogue_wait += delta
			if _epilogue_wait >= EPILOGUE_DELAY:
				_epilogue_wait = 0.0
				start_epilogue()
		return
	_epilogue_wait = 0.0
	if Objectives.ending_due():
		if get_tree().paused:
			return
		_ending_wait += delta
		if _ending_wait >= ENDING_DELAY:
			_ending_wait = 0.0
			start_ending()
	else:
		_ending_wait = 0.0


## Lance la reverdie de la région due tout de suite (appelée après le délai, ou par les tests) :
## sans pause ni texte, le joueur continue à jouer. La carte rejouera la région qui reverdit.
func start_ending() -> void:
	var reg := Objectives.ending_region()
	if reg == "":
		return
	world_map.pending_reveal.append(reg)
	fanfare.begin(main, reg)


## Lance la fin de l'aventure tout de suite (appelée après le délai, ou par les tests et les
## robots) : le joueur remonte au pied de la graine, le monde reverdit, le générique s'écrit dans
## l'herbe. Le jeu continue.
func start_epilogue() -> void:
	if current != "":
		close()
	if main.pause_menu.visible:
		main.pause_menu.close()
	world_ending.begin(main)
