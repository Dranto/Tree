## Test de la charte graphique (art.gd, anim.gd) : fonctions pures, sans écran.
## Lancer : tools/godot.sh --headless -s res://tests/art_test.gd
extends SceneTree

## Écart minimal (ΔE 1976) entre deux éléments, en vision normale et pour chaque daltonisme.
const MIN_DELTA_E := 20.0

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	print("Palette")
	for g in Art.GROUPES:
		for role in g[1]:
			check(Art.PALETTE.has(role), "rôle « %s » défini" % role)
	var listed := []
	for g in Art.GROUPES:
		listed.append_array(g[1])
	for role in Art.PALETTE:
		check(role in listed, "rôle « %s » présent sur la planche" % role)
	# Hiérarchie de lecture : le fond est plus sombre et moins saturé que ce qui compte.
	for role in ["sol_mort", "sol_vivant", "decor"]:
		var bg: Color = Art.c(role)
		check(bg.v < 0.45 and bg.s < 0.5, "fond « %s » sourd (v %.2f, s %.2f)" % [role, bg.v, bg.s])
	for role in ["joueur", "interactif", "butin"]:
		check(Art.c(role).v > 0.85, "« %s » clair" % role)
	check(Art.c("danger").s > 0.7 and Art.c("danger").v > 0.9, "danger saturé et vif")
	check(Art.delta_e(Art.c("ennemi_contour"), Art.c("sol_mort")) > 40.0, "contour des Flétris contrasté sur le sol mort")

	print("Interface alignée sur la palette")
	var ui = load("res://scripts/ui_theme.gd")
	check(ui.INK == Art.c("texte") and ui.LEAF == Art.c("accent") and ui.GOLD == Art.c("or") and ui.PANEL_BG == Art.c("panneau"), "ui_theme.gd lit ses couleurs dans Art")

	print("Éléments")
	check(Art.ELEMENT_IDS.size() == 6, "six éléments")
	var motifs := {}
	for id in Art.ELEMENT_IDS:
		var e: Dictionary = Art.ELEMENTS[id]
		for k in ["nom", "sens", "couleur", "clair", "sombre", "motif"]:
			check(e.has(k), "%s : « %s »" % [id, k])
		motifs[e["motif"]] = true
		check(id in Art.ICONES["elements"], "%s a une icône" % id)
	check(motifs.size() == 6, "un motif différent par élément")
	for kind in [""] + Art.DALTONISMES.keys():
		var worst := 1000.0
		var pair := ""
		for i in Art.ELEMENT_IDS.size():
			for j in range(i + 1, Art.ELEMENT_IDS.size()):
				var a := Art.ec(Art.ELEMENT_IDS[i])
				var b := Art.ec(Art.ELEMENT_IDS[j])
				if kind != "":
					a = Art.simulate(a, kind)
					b = Art.simulate(b, kind)
				var d := Art.delta_e(a, b)
				if d < worst:
					worst = d
					pair = "%s / %s" % [Art.ELEMENT_IDS[i], Art.ELEMENT_IDS[j]]
		check(worst >= MIN_DELTA_E, "éléments distincts %s (pire paire %s : ΔE %.1f)" % [kind if kind != "" else "en vision normale", pair, worst])
	check(Art.simulate(Color.WHITE, "deuteranopie").is_equal_approx(Color.WHITE), "le blanc reste blanc")
	check(absf(Art.lab(Color.WHITE).x - 100.0) < 0.5 and absf(Art.lab(Color.BLACK).x) < 0.5, "CIELAB : blanc à 100, noir à 0")

	print("Icônes")
	var skills: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
	for sk in skills:
		if sk.begins_with("_"):
			continue
		check(sk in Art.ICONES["competences"], "compétence « %s » a une icône" % sk)
		check(Art.ELEMENT_DE_COMPETENCE.has(sk), "compétence « %s » a un élément" % sk)
	for id in Art.icon_ids():
		check(Art.NOM_ICONE.has(id) or Art.ELEMENTS.has(id), "icône « %s » nommée" % id)
		check(Art.icon_color(id) != Color.MAGENTA, "icône « %s » a une couleur" % id)
	var seen := {}
	for id in Art.icon_ids():
		check(not seen.has(id), "icône « %s » listée une seule fois" % id)
		seen[id] = true

	print("Annonces de danger")
	var formes := [
		{"type": "cercle", "centre": Vector2(10, 10), "rayon": 50.0},
		{"type": "cone", "centre": Vector2.ZERO, "direction": 0.0, "ouverture": 1.0, "rayon": 80.0},
		{"type": "ligne", "de": Vector2.ZERO, "a": Vector2(100, 0), "largeur": 20.0},
	]
	for f in formes:
		var full := Art.telegraph_polygon(f, 1.0)
		var half := Art.telegraph_polygon(f, 0.5)
		check(full.size() >= 4 and half.size() == full.size(), "%s : polygone complet" % f["type"])
		check(_extent(half) < _extent(full), "%s : se remplit depuis l'origine" % f["type"])
	var line := Art.telegraph_polygon(formes[2], 0.5)
	check(absf(line[1].x - 50.0) < 0.01, "ligne à moitié remplie s'arrête à mi-chemin")

	print("Animations")
	var curves := {"ease_in": Anim.ease_in, "ease_out": Anim.ease_out, "ease_in_out": Anim.ease_in_out, "pop": Anim.pop}
	for f in curves:
		check(is_equal_approx(curves[f].call(0.0), 0.0) and is_equal_approx(curves[f].call(1.0), 1.0), "%s : 0 → 1" % f)
	check(Anim.ease_out(0.5) > 0.5 and Anim.ease_in(0.5) < 0.5, "ease_out rapide au début, ease_in lent")
	var peak := 0.0
	for i in 21:
		peak = maxf(peak, Anim.pop(i / 20.0))
	check(peak > 1.05 and peak < 1.2 and is_equal_approx(Anim.pop(1.0), 1.0), "pop dépasse un peu puis se pose (pic %.2f)" % peak)
	check(Anim.squash(0.0).is_equal_approx(Vector2.ONE), "squash : repos au départ")
	check(Anim.squash(Anim.SQUASH_ANTICIPATION).x > 1.1, "squash : écrasé à l'anticipation")
	check(Anim.squash(Anim.SQUASH_IMPACT).y > 1.15, "squash : étiré à l'impact")
	check(Anim.squash(1.0).is_equal_approx(Vector2.ONE), "squash : retour au repos")
	for i in 11:
		var sq := Anim.squash(i / 10.0)
		check(absf(sq.x * sq.y - 1.0) < 0.06, "squash garde l'aire à t = %.1f (%.3f)" % [i / 10.0, sq.x * sq.y])
	check(is_equal_approx(Anim.flash(0.0), 1.0) and is_equal_approx(Anim.flash(1.0), 0.0), "flash : 1 → 0")
	check(Anim.phase(0.05)["phase"] == "anticipation", "phase : anticipation")
	check(Anim.phase(Anim.DUREE["anticipation"] + 0.01)["phase"] == "impact", "phase : impact")
	check(Anim.phase(1.0)["phase"] == "fin", "phase : fin")
	check(Anim.DUREE["annonce_min"] >= 0.5, "une annonce dure au moins une demi-seconde")

	print("")
	print("ÉCHEC : %d test(s)" % failures if failures > 0 else "OK : charte graphique")
	quit(1 if failures > 0 else 0)


func _extent(pts: PackedVector2Array) -> float:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r.size.length()
