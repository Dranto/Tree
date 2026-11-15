## Interface des objectifs : suivi à l'écran et flèche, journal (J), carte (M) et fin de la tranche.
## La scène de jeu en crée une seule (voir main.gd). Chaque écran vit dans son propre calque pour ne
## pas toucher au HUD : suivi sous l'Arbre de vie, journal et carte au-dessus, fin au-dessus de tout.
extends Node

const Tracker = preload("res://scripts/objective_tracker.gd")
const Journal = preload("res://scripts/journal.gd")
const WorldMap = preload("res://scripts/world_map.gd")
const Ending = preload("res://scripts/ending.gd")

## Délai entre la mort de la Mère-Ronce et le début de la séquence de fin (la vague de vie passe).
const ENDING_DELAY := 5.0

var main
var tracker
var journal
var world_map
var ending
## "" (rien d'ouvert), "journal" ou "carte".
var current := ""
var ending_enabled := true
var _tracker_layer: CanvasLayer
var _ending_wait := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_tracker_layer = CanvasLayer.new()
	_tracker_layer.layer = 6
	add_child(_tracker_layer)
	tracker = Tracker.new()
	tracker.main = main
	tracker.key_hint = "%s : journal   ·   %s : carte" % [key_name("toggle_journal"), key_name("toggle_map")]
	_tracker_layer.add_child(tracker)

	var overlays := CanvasLayer.new()
	overlays.layer = 12
	overlays.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlays)
	journal = Journal.new()
	overlays.add_child(journal)
	world_map = WorldMap.new()
	world_map.main = main
	overlays.add_child(world_map)

	var end_layer := CanvasLayer.new()
	end_layer.layer = 30
	end_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(end_layer)
	ending = Ending.new()
	end_layer.add_child(ending)
	ending.closed.connect(func(): _tracker_layer.visible = not main.tree_ui.visible)

	# Pas de suivi par-dessus l'Arbre de vie (il couvre tout l'écran).
	main.tree_ui.toggled.connect(func(open: bool): _tracker_layer.visible = not open)
	Objectives.attach(main)
	# Pas de fin de partie pendant les bancs d'essai et les combats de test.
	ending_enabled = main.build_bot == null and not main.autotest_boss and not main.benchmark


func _exit_tree() -> void:
	Objectives.detach(main)


func _setup_input() -> void:
	# Touches logiques (J et M, quelle que soit la disposition du clavier).
	for pair in [["toggle_journal", KEY_J], ["toggle_map", KEY_M]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var ev := InputEventKey.new()
			ev.keycode = pair[1]
			InputMap.action_add_event(pair[0], ev)


## Nom de la touche d'une action, pour les textes d'aide.
func key_name(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		var k := ev as InputEventKey
		if k:
			return OS.get_keycode_string(k.keycode if k.keycode != KEY_NONE else k.physical_keycode)
	return "?"


func _input(event: InputEvent) -> void:
	if ending.active and ending.visible:
		return
	if event.is_action_pressed("toggle_journal"):
		toggle("journal")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_map"):
		toggle("carte")
		get_viewport().set_input_as_handled()
	elif current != "" and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Une fenêtre modale (Arbre, pause, fin) est déjà ouverte : le journal et la carte attendent.
func _blocked() -> bool:
	return main.tree_ui.visible or main.pause_menu.visible or ending.active or (get_tree().paused and current == "")


func toggle(which: String) -> void:
	if current == which:
		close()
		return
	if current == "" and _blocked():
		return
	if current != "":
		(journal if current == "journal" else world_map).close()
	current = which
	get_tree().paused = true
	if which == "journal":
		journal.open()
	else:
		world_map.open()


func close() -> void:
	if current == "":
		return
	(journal if current == "journal" else world_map).close()
	current = ""
	get_tree().paused = false


func _process(delta: float) -> void:
	# Fin de la tranche : une fois le boss vaincu, après un court délai, une seule fois.
	if not ending_enabled or ending.active:
		return
	if Objectives.ending_due():
		if get_tree().paused:
			return
		_ending_wait += delta
		if _ending_wait >= ENDING_DELAY:
			_ending_wait = 0.0
			start_ending()
	else:
		_ending_wait = 0.0


## Lance la séquence de fin tout de suite (appelée après le délai, ou par les tests).
func start_ending() -> void:
	if current != "":
		close()
	if main.pause_menu.visible:
		main.pause_menu.close()
	_tracker_layer.visible = false
	ending.begin(main)
