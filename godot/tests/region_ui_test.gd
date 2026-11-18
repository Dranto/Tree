## Test de la carte, du journal, du suivi d'objectif, de l'ambiance et du son de plusieurs régions : la région
## factice des tests (tests/regions/essai.json, avec sa section « audio ») s'ajoute à Ronce, et tout se lit dans
## les fichiers de régions, sans rien écrire de propre à une région.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/region_ui_test.gd
## Ne lit ni n'écrit la sauvegarde par défaut.
extends SceneTree

const Regions = preload("res://scripts/regions.gd")
const RegionAudio = preload("res://scripts/region_audio.gd")
const Synth = preload("res://scripts/synth.gd")

# region_ui.gd lit l'autoload Game : chargé à l'exécution, pas à la compilation du test.
var RegionUi
var failures := 0
var main


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Textes de tous les Label d'un nœud.
func _texts(n: Node, out: Array) -> Array:
	if n is Label:
		out.append(n.text)
	for c in n.get_children():
		_texts(c, out)
	return out


func _run() -> void:
	var game = root.get_node("Game")
	var obj = root.get_node("Objectives")
	RegionUi = load("res://scripts/region_ui.gd")
	Regions.set_extra_dirs(["res://tests/regions/"])
	game.reset()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	await _frames(3)
	main.spawn_timer = 1.0e9
	main.set_physics_process(false)
	main.player.set_physics_process(false)

	print("Régions")
	check(Regions.ids().size() == 2 and "essai" in Regions.ids(), "Ronce et la région d'essai")
	check(RegionUi.full_name("essai") == "Région d'essai" and RegionUi.short_name("essai") == "Essai", "noms lus dans le fichier de la région")
	var p: Dictionary = RegionUi.progress("essai", {})
	check(p["sanctuaires"] == [0, 1] and not p["coeur"] and not p["boss"], "avancement de départ : rien de fait")
	var flags := {"sanctuaire_essai_halte": true, "essai_coeur_purifie": true}
	check(RegionUi.progress("essai", flags)["sanctuaires"] == [1, 1] and RegionUi.state("essai", flags) == "Cœur purifié", "sanctuaire ravivé, Cœur purifié")
	check(RegionUi.state("essai", {"essai_boss_vaincu": true}) == "région purifiée", "boss vaincu : région purifiée")
	check(RegionUi.summary("ronce", {}) == "0 / 4 sanctuaires · 0 / 4 autels", "ligne d'avancement de Ronce : %s" % RegionUi.summary("ronce", {}))

	print("Son et ambiance de la région")
	check(RegionAudio.of("essai").has("music"), "la section « audio » du fichier de la région prime")
	check(RegionAudio.music_regions() == ["essai"], "une seule région a sa musique ici : %s" % [RegionAudio.music_regions()])
	check(RegionAudio.boss_sound("essai", "eveil") == "vent_boss_eveil" and RegionAudio.boss_sound("essai", "phase") == "", "sons du boss : ceux qui sont réglés")
	check(RegionAudio.boss_sound("ronce", "mort") == "", "Ronce : aucun son de boss ajouté")
	check(RegionAudio.validate().is_empty(), "réglages valides : %s" % [RegionAudio.validate()])
	check(Synth.music_dark(RegionAudio.music_style("essai")) != Synth.music_dark(), "la musique d'essai n'est pas celle de Ronce")

	var ambience = null
	for c in main.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("ambience.gd"):
			ambience = c
	check(ambience != null, "l'ambiance est dans la scène")
	if ambience != null:
		var spot: Vector2 = Regions.place("essai", {"dist": 1500.0, "side": 0.0})
		main.player.position = spot
		var styled := 0
		var plain := 0
		for i in 60:
			var m: Dictionary = ambience._new_mote(Rect2(spot - Vector2(300, 300), Vector2(600, 600)), true)
			if m.has("shape"):
				styled += 1
			else:
				plain += 1
		check(styled == 60 and plain == 0, "les particules nées dans la région prennent son style")
		var home: Vector2 = Regions.place("ronce", {"dist": 1500.0, "side": 0.0})
		var rp := 0
		for i in 20:
			if ambience._new_mote(Rect2(home - Vector2(300, 300), Vector2(600, 600)), true).has("shape"):
				rp += 1
		check(rp == 0, "dans Ronce : les cendres et le pollen de toujours")

	print("Carte")
	var q = main.quest_ui
	game.flags["sanctuaire_essai_halte"] = true
	q.toggle("carte")
	await _frames(2)
	var texts := _texts(q.world_map._legend, [])
	check("Région d'essai" in texts and "Région de Ronce" in texts, "la légende nomme chaque région")
	check("1 / 1 sanctuaires" in texts, "la légende donne l'avancement de la région d'essai : %s" % [texts])
	check(not "Arène de la Mère-Ronce" in texts, "plus de nom de boss écrit en dur")
	q.close()

	print("Journal")
	q.toggle("journal")
	await _frames(2)
	var jt := _texts(q.journal._box, [])
	check("L'AVENTURE" in jt and "RÉGION DE RONCE" in jt, "sections : l'aventure et Ronce")
	check(not "RÉGION D'ESSAI" in jt, "pas de section pour une région sans objectifs")
	check(jt.any(func(t): return t.begins_with("Aventure :") and "régions purifiées" in t), "sous-titre de l'aventure : %s" % [jt.slice(0, 3)])
	q.close()

	print("Suivi")
	var tracker = q.tracker
	obj.complete("premier_noeud", true)
	tracker.refresh()
	check(tracker._head.text.contains("Roncier") or obj.current().get("region", "") == "", "le suivi dit la région de l'objectif quand il y en a plusieurs : %s" % tracker._head.text)

	root.remove_child(main)
	main.queue_free()
	Regions.set_extra_dirs([])
	print("ÉCHECS : %d" % failures if failures > 0 else "Tout est bon.")
	quit(1 if failures > 0 else 0)
