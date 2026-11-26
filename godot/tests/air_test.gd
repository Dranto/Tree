## Test de la lumière et de l'air du monde (ambience.gd, Art.MONDE_AIR) : chaque région a son air, le flétri est
## plus sombre que le ravivé, la lumière vient d'en haut à gauche, le temps et les particules ont un plafond,
## « Réduire les effets » garde un tiers.
## Lancer : tools/godot.sh --headless -s res://tests/air_test.gd
extends SceneTree

# ambience.gd nomme l'autoload Settings : chargé à l'exécution (un préchargement ne compile pas avec -s).
var Ambience
const RegionAudio = preload("res://scripts/region_audio.gd")
const Regions = preload("res://scripts/regions.gd")

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	Ambience = load("res://scripts/ambience.gd")
	var settings = root.get_node("Settings")
	print("Palettes d'air")
	for id in Regions.ids() + ["finale"]:
		if id in ["generique", "essai"]:
			continue
		check(Art.MONDE_AIR.has(id), "« %s » a son air" % id)
	for id in Art.MONDE_AIR:
		var f: Array = Art.air_de(id, "fletri")
		var r: Array = Art.air_de(id, "ravive")
		check((f[0] as Color).get_luminance() < (r[0] as Color).get_luminance(), "%s : la lumière ravivée est plus claire que celle du flétri" % id)
		check((f[1] as Color).get_luminance() < 0.12 and (r[1] as Color).get_luminance() < 0.2, "%s : voile sombre (la vignette ne blanchit pas les bords)" % id)
	check(Art.air_de("inconnue", "ravive") == Art.MONDE_AIR["ronce"]["ravive"], "région sans air : celui de Ronce")
	check(Art.AIR_ETAT["fletri"]["vignette"] > Art.AIR_ETAT["ravive"]["vignette"], "vignette plus marquée en terre flétrie")
	check(Art.AIR_ETAT["ravive"]["haut"] > Art.AIR_ETAT["fletri"]["haut"] and Art.AIR_ETAT["ravive"]["rayons"] > 0.0, "lumière et rayons en terre ravivée")
	for etat in Art.AIR_ETAT:
		for k in Art.AIR_ETAT[etat]:
			check(Art.AIR_ETAT[etat][k] <= 0.6, "%s › %s : jamais assez fort pour noyer le centre" % [etat, k])

	print("Lumière commune")
	check(Art.LUMIERE_DIR.x < 0.0 and Art.LUMIERE_DIR.y < 0.0, "la lumière vient d'en haut à gauche")
	check(Art.OMBRE_DIR.x > 0.0 and Art.OMBRE_DIR.y > 0.0, "l'ombre part en bas à droite")
	check(Art.ombre_decalee(Vector2.ZERO, 10.0).x > 0.0 and Art.ombre_decalee(Vector2.ZERO, 10.0).y > 0.0, "l'ombre du décor est décalée vers le bas à droite")
	var Ink = load("res://scripts/creature_art/ink.gd")
	check(Art.LUMIERE_DIR.is_equal_approx(Ink.LIGHT), "même direction que l'encre des créatures")

	print("Air selon la région et la vie")
	var amb = Ambience.new()
	amb._region = "ronce"
	amb._life = 0.0
	var t0: Array = amb._air_target()
	amb._life = 1.0
	var t1: Array = amb._air_target()
	check((t0[1] as Color).a > (t1[1] as Color).a, "la vignette s'éclaircit quand la terre revit")
	check(t1[3] > t0[3], "des rayons seulement sur la terre vivante")
	check((t1[0] as Color).get_luminance() > (t0[0] as Color).get_luminance(), "l'air ravivé est plus clair")
	amb._region = "spore"
	amb._life = 0.0
	check(amb._air_target()[0] != t0[0], "chaque région a sa teinte")
	amb._region = "mondeinconnu"
	check(amb._air_target().size() == 4, "région sans air : repli sur Ronce")

	print("Plafonds et « Réduire les effets »")
	for i in Ambience.MOTES:
		amb.motes.append({})
	for i in Ambience.BUTTERFLIES:
		amb.butterflies.append({})
	settings.reduce_effects = false
	check(amb._mote_count() == Ambience.MOTES and amb._butterfly_count() == Ambience.BUTTERFLIES, "tout est là sans réglage")
	settings.reduce_effects = true
	check(amb._mote_count() == Ambience.MOTES / 3 and amb._butterfly_count() == 1, "un tiers des particules avec « Réduire les effets » : %d" % amb._mote_count())
	settings.reduce_effects = false
	check(Ambience.RAIN_DROPS + Ambience.GUST_STREAKS + Ambience.MOTES + Ambience.BUTTERFLIES <= 100, "au plus 100 éléments d'ambiance à l'écran")
	check(Ambience.WEATHER.get("spore") == "rain" and Ambience.WEATHER.get("vent") == "gust", "pluie au Marais, rafales sur les Plateaux")

	print("Temps")
	amb._region = "spore"
	amb._life = 0.0
	for i in 40:
		amb._step_weather(0.1)
	check(amb._rain > 0.9, "la pluie monte au Marais flétri")
	amb._life = 1.0
	for i in 60:
		amb._step_weather(0.1)
	check(amb._rain > 0.3 and amb._rain < 0.8, "moins de pluie sur la terre ravivée (%.2f)" % amb._rain)
	amb._region = "ronce"
	for i in 60:
		amb._step_weather(0.1)
	check(amb._rain == 0.0 and amb._gust == 0.0, "pas de temps à Ronce")
	amb._region = "vent"
	var gusted := false
	for i in 400:
		amb._step_weather(0.1)
		if amb._gust_t >= 0.0:
			gusted = true
	check(gusted, "une rafale passe sur les Plateaux")

	print("Données d'ambiance")
	check(RegionAudio.validate().is_empty(), "réglages de son et d'ambiance valides : %s" % [RegionAudio.validate()])
	check(RegionAudio.ambience("seve").get("alive", {}).get("shape") == "drop", "gouttes en Sève")
	check(RegionAudio.ambience("racine").get("alive", {}).get("shape") == "chip", "sciure en Racine")
	check(RegionAudio.ambience("vent").get("alive", {}).get("alt") == "feather", "plumes sur les Plateaux")
	amb.free()
	print("AIR : %s" % ("OK" if failures == 0 else "%d échec(s)" % failures))
	quit(1 if failures > 0 else 0)
