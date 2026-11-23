## Interface des objectifs : suivi à l'écran et flèche, journal (J), carte (M), célébration d'une
## région purifiée (sur place, sans pause : region_fanfare.gd) et épilogue de la finale.
## La scène de jeu en crée une seule (voir main.gd). Chaque écran vit dans son propre calque pour ne
## pas toucher au HUD : suivi sous l'Arbre de vie, journal et carte au-dessus, fin au-dessus de tout.
extends Node

const Tracker = preload("res://scripts/objective_tracker.gd")
const Journal = preload("res://scripts/journal.gd")
const WorldMap = preload("res://scripts/world_map.gd")
const Fanfare = preload("res://scripts/region_fanfare.gd")
const Epilogue = preload("res://scripts/epilogue.gd")

## Délai entre la mort d'un boss régional et sa célébration (l'annonce de la victoire passe).
const ENDING_DELAY := 3.5
## Délai entre la mort de la Flétrissure et l'épilogue (le creux refleurit).
const EPILOGUE_DELAY := 4.0

var main
var tracker
var journal
var world_map
## Célébration « région purifiée » en cours ou passée (region_fanfare.gd) : le jeu continue dessous.
var fanfare
## Épilogue et générique de l'aventure, après la finale (epilogue.gd).
var epilogue
## "" (rien d'ouvert), "journal" ou "carte".
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
	# La célébration d'une région : sous le journal et la carte, au-dessus du suivi d'objectif.
	var fanfare_layer := CanvasLayer.new()
	fanfare_layer.layer = 7
	fanfare_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fanfare_layer)
	fanfare = Fanfare.new()
	fanfare.main = main
	fanfare_layer.add_child(fanfare)
	epilogue = Epilogue.new()
	end_layer.add_child(epilogue)
	epilogue.closed.connect(_on_ending_closed)
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
	if epilogue.active and epilogue.visible:
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
	return main.tree_ui.visible or main.pause_menu.visible or epilogue.active or (get_tree().paused and current == "")


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
	_veil()


func close() -> void:
	if current == "":
		return
	(journal if current == "journal" else world_map).close()
	current = ""
	get_tree().paused = false
	_veil()


## Transition d'ouverture ou de fermeture : un voile sombre qui se dissipe vite.
func _veil() -> void:
	if main.get("screen_fx") != null:
		main.screen_fx.fade(Art.c("decor"), 0.45, 0.0, main.screen_fx.FADE_PANEL)


## Le suivi s'efface par-dessus l'Arbre de vie (il couvre tout l'écran), pendant l'épilogue, pendant
## le combat de boss (seules les informations du combat restent) et pendant la célébration d'une région.
func tracker_shown() -> bool:
	return not main.tree_ui.visible and not epilogue.active and not main.in_boss_fight() and not fanfare.active


func _on_ending_closed() -> void:
	main.hud.get_parent().visible = not main.tree_ui.visible
	_tracker_layer.visible = tracker_shown()


func _process(delta: float) -> void:
	_tracker_layer.visible = tracker_shown()
	# Célébration d'une région : une fois son boss vaincu, après un court délai, une seule fois.
	if not ending_enabled or fanfare.active or epilogue.active:
		return
	# Épilogue : la Flétrissure vaincue, après un court délai, une seule fois.
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


## Lance la célébration de la région due tout de suite (appelée après le délai, ou par les tests) :
## sans pause ni écran plein, le joueur continue à jouer. La carte rejouera la région qui reverdit.
func start_ending() -> void:
	var reg := Objectives.ending_region()
	if reg == "":
		return
	world_map.pending_reveal.append(reg)
	_tracker_layer.visible = false
	fanfare.begin(main, reg)


## Lance l'épilogue tout de suite (appelée après le délai, ou par les tests et les robots) : le
## joueur remonte au pied de la graine, et le monde entier reverdit derrière l'épilogue.
func start_epilogue() -> void:
	if current != "":
		close()
	if main.pause_menu.visible:
		main.pause_menu.close()
	_tracker_layer.visible = false
	main.hud.get_parent().visible = false
	if main.get("finale") != null:
		main.finale.bring_up()
	epilogue.begin(main)
