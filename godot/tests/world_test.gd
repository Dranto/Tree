## Test du monde à cinq régions (et plus) : avec les régions du jeu (dont Sève et Aube) et la région
## d'essai (branche Racine), les six secteurs sont
## occupés. On vérifie que chaque région tient dans le monde (lieux, Cœur, arène), que les arènes ne se
## chevauchent pas, que la vraie région d'une branche l'emporte sur sa région factice, que check_data
## refuse une région qui déborde, que les dessins de chaque région (Cœur, arène) sont les siens, et que
## le robot de partie complète reste dans sa région.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/world_test.gd
## Ne lit ni n'écrit la sauvegarde par défaut.
extends SceneTree

const Regions = preload("res://scripts/regions.gd")

const FAKE_DIR := "user://world_test_regions/"

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


func _steps(n: int) -> void:
	for i in n:
		await physics_frame


## Toutes les positions d'une région : lieux du fichier, Cœur.
func _spots(id: String) -> Array:
	var out: Array = []
	for kind in ["sanctuaries", "altars", "secrets", "landmarks"]:
		for spot in Regions.def(id).get(kind, []):
			out.append([kind + " " + str(spot.get("id", spot.get("kind", "?"))), Regions.place(id, spot)])
	return out


func _run() -> void:
	var game = root.get_node("Game")

	print("Six secteurs")
	check(Regions.ids() == ["ronce", "spore", "seve", "vent", "aube"], "sans les régions des tests : Ronce, Spore, Sève, Vent et Aube (%s)" % [Regions.ids()])
	Regions.set_extra_dirs(["res://tests/regions/"])
	var ids: Array = Regions.ids()
	check(ids == ["ronce", "spore", "seve", "vent", "aube", "essai"], "avec la région d'essai, une par branche, dans l'ordre du cercle (%s)" % [ids])
	check(Regions.validate().is_empty(), "check_data accepte les six régions %s" % [Regions.validate()])
	var angles := {}
	for id in ids:
		angles[snappedf(fposmod(Regions.angle_of(id), TAU), 0.01)] = id
	check(angles.size() == 6, "six secteurs différents")

	print("Chaque région tient dans le monde")
	for id in ids:
		var bad: Array = []
		for s in _spots(id):
			if not Regions.fits_world(s[1]) or Regions.region_at(s[1]) != id:
				bad.append(s[0])
		check(bad.is_empty(), "%s : lieux dans le monde et dans le secteur %s" % [id, bad])
		var heart := Regions.center(id)
		check(Regions.region_at(heart) == id and Regions.fits_world(heart, 240.0), "%s : le Cœur et sa zone" % id)
		var ar: Dictionary = Regions.section(id, "boss").get("arena", {})
		var ac := Regions.arena_center(id)
		var r := float(ar.get("radius", 470.0))
		check(Regions.fits_world(ac, r) and Regions.inside_distance(ac, id) >= r, "%s : l'arène (rayon %.0f) dans le monde et dans le secteur" % [id, r])
		var dir := Vector2.from_angle(Regions.angle_of(id))
		check(absf(ac.normalized().dot(dir) - 1.0) < 0.001, "%s : l'arène est dans l'axe de la région, au-delà du Cœur" % id)
	# Est et ouest : les secteurs sans coin (Spore, Aube) sont les moins profonds.
	check(is_equal_approx(Regions.reach(Regions.angle_of("spore")), Regions.WORLD_HALF) and is_equal_approx(Regions.reach(Regions.angle_of("aube")), Regions.WORLD_HALF), "Spore et Aube : le bord du monde à %.0f px dans leur axe" % Regions.WORLD_HALF)
	check(Regions.reach(Regions.angle_of("seve")) > 3300.0, "Sève : à %.0f px (secteur en coin)" % Regions.reach(Regions.angle_of("seve")))
	var overlap: Array = []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			var ra := float(Regions.section(a, "boss").get("arena", {}).get("radius", 470.0))
			var rb := float(Regions.section(b, "boss").get("arena", {}).get("radius", 470.0))
			if Regions.arena_center(a).distance_to(Regions.arena_center(b)) < ra + rb + 200.0:
				overlap.append(a + "/" + b)
	check(overlap.is_empty(), "les arènes ne se touchent pas (au moins 200 px entre deux murs) %s" % [overlap])

	print("Vérification d'une région qui déborde")
	var aube: Dictionary = Regions.def("aube")
	var arena: Dictionary = aube["boss"]["arena"]
	var offset0: float = arena["offset"]
	arena["offset"] = 1000.0
	var errs := Regions.validate()
	check(errs.size() == 1 and "sort du monde" in errs[0] and "1190" in errs[0], "Aube : une arène trop loin est refusée, avec la limite du secteur (%s)" % [errs])
	arena["offset"] = offset0
	var secret: Dictionary = aube["secrets"][0]
	var secret0 := secret.duplicate()
	secret["dist"] = 2950.0
	secret["side"] = 0.0
	errs = Regions.validate()
	check(errs.size() == 1 and "hors du monde" in errs[0], "Aube : un secret au-delà du bord est refusé (%s)" % [errs])
	secret["dist"] = secret0["dist"]
	secret["side"] = secret0["side"]
	var art0 = aube.get("art")
	aube["art"] = "inconnu"
	errs = Regions.validate()
	check(errs.size() == 1 and "dessins inconnus" in errs[0], "un « art » sans script est refusé (%s)" % [errs])
	if art0 == null:
		aube.erase("art")
	else:
		aube["art"] = art0
	check(Regions.validate().is_empty(), "tout redevient valide")

	print("La vraie région l'emporte sur la factice")
	DirAccess.make_dir_recursive_absolute(FAKE_DIR)
	var dup := FileAccess.open(FAKE_DIR + "doublon.json", FileAccess.WRITE)
	dup.store_string(JSON.stringify({"id": "ronce_bis", "branch": "ronce", "name": "Doublon"}))
	dup.close()
	var same := FileAccess.open(FAKE_DIR + "spore.json", FileAccess.WRITE)
	same.store_string(JSON.stringify({"id": "spore", "branch": "racine", "name": "Faux Spore"}))
	same.close()
	Regions.set_extra_dirs(["res://tests/regions/", FAKE_DIR])
	check(not "ronce_bis" in Regions.ids() and Regions.def("spore").get("name", "") == "Région de Spore", "une région des tests ne prend ni le secteur ni l'identifiant d'une région du jeu")
	check(Regions.validate().is_empty(), "et check_data n'y voit pas de doublon")
	DirAccess.remove_absolute(FAKE_DIR + "doublon.json")
	DirAccess.remove_absolute(FAKE_DIR + "spore.json")
	DirAccess.remove_absolute(FAKE_DIR)
	Regions.set_extra_dirs(["res://tests/regions/"])

	print("Dessins de chaque région")
	check(Regions.art("ronce").resource_path == Regions.BASE_ART, "Ronce : les dessins par défaut (la rose, le mur de ronces)")
	check(Regions.art("spore").resource_path.ends_with("region_art/spore.gd"), "Spore : ses propres dessins")
	check(Regions.art("vent").resource_path.ends_with("region_art/vent.gd"), "Vent : ses propres dessins")
	check(Regions.art("seve").resource_path.ends_with("region_art/seve.gd"), "Sève : ses propres dessins")
	check(Regions.art("aube").resource_path.ends_with("region_art/aube.gd"), "Aube : ses propres dessins (les falaises de verre)")
	for f in ["draw_heart", "draw_heart_purified", "draw_arena_floor", "draw_arena_wall"]:
		check(Regions.art("aube").get_script_method_list().any(func(m): return m["name"] == f), "Aube redessine %s" % f)
	check(Regions.art("essai").resource_path == Regions.BASE_ART, "une région sans « art » : les dessins par défaut")
	for f in ["draw_heart", "draw_heart_purified", "draw_arena_floor", "draw_arena_wall"]:
		var own := []
		for id in ["spore", "vent"]:
			for m in Regions.art(id).get_script_method_list():
				if m["name"] == f:
					own.append(id)
					break
		check(own == ["spore", "vent"], "Spore et Vent redessinent %s" % f)

	print("Le monde avec six régions")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	await _steps(3)
	check(main.hearts.size() == 6 and main.arenas.size() == 6, "un Cœur et une arène par région")
	var placed := true
	for id in ids:
		var h = main.hearts[id]
		var a = main.arenas[id]
		placed = placed and h.center == Regions.center(id) and a.center == Regions.arena_center(id) and a.heart == h
	check(placed, "chacun à sa place (Regions.center, Regions.arena_center)")
	var sanct := true
	for id in ids:
		for s in Regions.def(id).get("sanctuaries", []):
			var node = main.sanctuary(str(s["id"]))
			sanct = sanct and node != null and Regions.region_at(node.position) == id
	check(sanct, "les sanctuaires de chaque région sont posés dans son secteur")
	check(main.region_at(Regions.center("seve")) == "seve" and main.region_at(Regions.center("aube")) == "aube", "main.region_at reconnaît Sève et Aube")

	print("Robot de partie complète")
	for id in ids:
		# Chargé ici : build_bot.gd cite l'autoload Game, absent quand ce script se compile.
		var bot = load("res://scripts/build_bot.gd").new()
		bot.region = id
		var ok := true
		for lv in range(6, 26):
			game.level = lv
			var anchor: Vector2 = bot.run_anchor(main)
			# Le robot tourne à 200 px autour de son ancrage, et poursuit jusqu'à la laisse.
			ok = ok and Regions.region_at(anchor) == id and Regions.fits_world(anchor, 200.0)
		check(ok, "%s : son point d'ancrage reste dans la région et loin du bord du monde" % id)
	game.level = 1

	Regions.set_extra_dirs([])
	print("RÉSULTAT : " + ("tout est bon" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
