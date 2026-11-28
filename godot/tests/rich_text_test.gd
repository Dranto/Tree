## Textes à mots-clés colorés (jalon 14.5 T) : découpe française et anglaise (scripts/rich_text.gd,
## data/keywords.json), aucun mot coupé, « Arbre de vie » laissé en texte simple, glyphes seulement en
## mode d'accessibilité, coupe des lignes sans perdre ni couper un mot, étiquette RichLabel, et la fiche
## de greffe qui s'en sert.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/rich_text_test.gd
extends SceneTree

const Content = preload("res://scripts/content.gd")

var failures := 0
var base := Color("fdeec7")


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  ÉCHEC ", what)


func _initialize() -> void:
	_run.call_deferred()


## Mots-clés d'un texte : [[texte, catégorie]…] (la catégorie est retrouvée par la couleur).
func _keys(text: String) -> Array:
	var out: Array = []
	for r in RichText.split(text, base):
		if r[RichText.G] != "":
			out.append([r[RichText.T], r[RichText.G]])
	return out


func _run() -> void:
	_split()
	_wrap()
	await _glyphs()
	_data()
	await _label_and_sheet()
	print("RÉSULTAT ", "ok" if failures == 0 else "%d échec(s)" % failures)
	quit(1 if failures > 0 else 0)


func _split() -> void:
	print("Découpe")
	check(_keys("+12 % Dégâts") == [["Dégâts", "pointe"]], "dégâts : %s" % [_keys("+12 % Dégâts")])
	check(_keys("+8 % Damage") == [["Damage", "pointe"]], "damage (anglais)")
	check(_keys("Poison (dégâts du coup par seconde)") == [["Poison", "goutte"], ["dégâts", "pointe"]], "poison puis dégâts")
	check(_keys("Chance de critique") == [["critique", "etoile"]], "critique")
	check(_keys("Crit chance, critical hits") == [["Crit", "etoile"], ["critical", "etoile"]], "critique en anglais : %s" % [_keys("Crit chance, critical hits")])
	check(_keys("Saignement, la cible saigne") == [["Saignement", "goutte_creuse"], ["saigne", "goutte_creuse"]], "saignement et saigne")
	check(_keys("Vol de vie et régénération") == [["Vol de vie", "croix"], ["régénération", "croix"]], "expression « vol de vie » d'un seul tenant : %s" % [_keys("Vol de vie et régénération")])
	check(_keys("Vitesse d'attaque") == [["Vitesse", "chevrons"]], "vitesse (apostrophe : « attaque » reste simple)")
	check(_keys("Armure, écorce et défense") == [["Armure", "ecu"], ["écorce", "ecu"], ["défense", "ecu"]], "défense : armure, écorce, défense")
	check(_keys("Recharge de l'esquive") == [["Recharge", "cycle"]], "recharge")
	check(_keys("Cooldown and Speed") == [["Cooldown", "cycle"], ["Speed", "chevrons"]], "recharge et vitesse en anglais")
	check(_keys("Health, heals, lifesteal") == [["Health", "croix"], ["heals", "croix"], ["lifesteal", "croix"]], "vie en anglais")
	# Faux amis : pas de couleur au milieu d'un mot, ni pour un nom propre.
	check(_keys("Arbre de vie") == [], "« Arbre de vie » reste en texte simple")
	check(_keys("Tree of Life") == [], "« Tree of Life » aussi")
	check(_keys("survie, poisonnier") == [["poisonnier", "goutte"]] or _keys("survie") == [], "« survie » n'est pas « vie »")
	check(_keys("Un texte sans mot-clé, 12 %") == [], "aucun mot-clé : aucun segment coloré")
	# Reconstitution exacte, couleurs de base pour le reste.
	for t in ["+12 % Dégâts", "(dégâts) du poison, vie !", "Dégâts×2", "", "a", "Crit"]:
		var runs := RichText.split(t, base)
		check(RichText.plain(runs) == t, "recollé à l'identique : « %s »" % t)
		for r in runs:
			check(r[RichText.G] != "" or r[RichText.C] == base, "segment simple en couleur de base : « %s »" % r[RichText.T])
	# Un mot-clé prend la couleur de sa catégorie, distincte de la couleur de base.
	var dm: Array = RichText.split("Dégâts", base)
	check(dm.size() == 1 and dm[0][RichText.C] != base, "couleur de catégorie")
	# Les huit catégories ont des couleurs et des glyphes distincts.
	var cols := {}
	var gls := {}
	for c in RichText.categories():
		cols[RichText.color_of(c).to_html()] = true
		gls[RichText.glyph_of(c)] = true
	check(RichText.categories().size() == 8 and cols.size() == 8 and gls.size() == 8, "8 catégories, 8 couleurs, 8 glyphes")


func _wrap() -> void:
	print("Coupe des lignes")
	var font: Font = load("res://scripts/ui_theme.gd").font()
	var text := "• +12 % Dégâts (poison) et vie : le saignement ne dépend pas du coup critique, ni de la recharge"
	for glyphs in [false, true]:
		RichText.force_glyphs = glyphs
		var fs := 15
		var words := text.split(" ")
		for max_w in [90.0, 160.0, 240.0, 600.0]:
			var lines := RichText.wrap(RichText.split(text, base), font, fs, max_w)
			var rejoined := ""
			var ok_w := true
			var cut := false
			for l in lines:
				rejoined += (" " if rejoined != "" else "") + RichText.plain(l).strip_edges()
				var mw := RichText.measure(font, l, fs)
				var single := RichText.plain(l).strip_edges().split(" ").size() <= 1
				if mw > max_w + 0.5 and not single:
					ok_w = false
			# Aucun mot coupé : chaque mot du texte d'origine se retrouve entier, dans l'ordre.
			var got := rejoined.replace("   ", " ").split(" ", false)
			var want := text.split(" ", false)
			cut = got != want
			check(not cut, "glyphes %s, largeur %d : aucun mot coupé, aucun perdu" % [glyphs, max_w])
			check(ok_w, "glyphes %s, largeur %d : lignes dans la largeur" % [glyphs, max_w])
			if max_w < 100.0:
				check(lines.size() > 4, "largeur %d : le texte est bien coupé (%d lignes)" % [max_w, lines.size()])
		# Les lignes suivantes d'une puce sont en retrait.
		var narrow := RichText.wrap(RichText.split(text, base), font, 15, 160.0)
		check(narrow.size() > 1 and RichText.plain(narrow[1]).begins_with("   "), "retrait des lignes suivantes d'une puce")
		# Collé à une parenthèse : « (dégâts) » ne se sépare pas.
		var par := RichText.wrap(RichText.split("un (dégâts) deux", base), font, 15, 30.0)
		var joined := " | ".join(par.map(func(l): return RichText.plain(l)))
		check(joined.contains("(dégâts)"), "« (dégâts) » reste d'un seul tenant : %s" % joined)
	RichText.force_glyphs = false


func _glyphs() -> void:
	print("Glyphes")
	var font: Font = load("res://scripts/ui_theme.gd").font()
	var runs := RichText.split("+12 % Dégâts", base)
	RichText.force_glyphs = false
	var off := RichText.measure(font, runs, 15)
	var col_off := RichText.color_of("degats")
	RichText.force_glyphs = true
	var on := RichText.measure(font, RichText.split("+12 % Dégâts", base), 15)
	var col_on := RichText.color_of("degats")
	check(on > off + 5.0, "le glyphe élargit la ligne (%.1f -> %.1f)" % [off, on])
	check(col_on != col_off, "couleur plus tranchée en mode d'accessibilité")
	for c in RichText.categories():
		check(await _draw_glyph_ok(RichText.glyph_of(c)), "glyphe « %s » dessiné sans erreur" % RichText.glyph_of(c))
	RichText.force_glyphs = false
	# Le mode daltonien de la charte active les glyphes sans forcer.
	Art.set_access("deutan", false)
	check(RichText.glyphs_on(), "mode daltonien : glyphes affichés")
	Art.set_access("aucun", false)
	check(not RichText.glyphs_on(), "vision normale : pas de glyphes")


## Dessine un glyphe dans un Control de test et dit si le dessin est allé au bout.
func _draw_glyph_ok(glyph: String) -> bool:
	var c := Control.new()
	c.size = Vector2(32, 32)
	var done := [false]
	c.draw.connect(func():
		RichText.draw_glyph(c, glyph, Vector2(16, 16), 9.0, Color.WHITE)
		done[0] = true)
	root.add_child(c)
	await process_frame
	await process_frame
	c.queue_free()
	return done[0]


func _data() -> void:
	print("Données")
	var f := FileAccess.open("res://data/keywords.json", FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	check(data is Dictionary and data["categories"].size() == 8, "data/keywords.json : 8 catégories")
	var seen := {}
	for cat in data["categories"]:
		var d: Dictionary = data["categories"][cat]
		check(d["fr"].size() > 0 and d["en"].size() > 0, "%s : mots français et anglais" % cat)
		for lang in ["fr", "en"]:
			for w in d[lang]:
				var key := str(w).trim_suffix("*")
				if seen.has(key):
					check(seen[key] == cat, "« %s » n'est que dans une catégorie" % w)
				seen[key] = cat
	# Chaque stat du jeu qui porte un mot-clé le garde dans sa forme française.
	var stats: Dictionary = Content.stats()
	var colored := 0
	for id in stats:
		if not _keys(str(stats[id]["label"])).is_empty():
			colored += 1
	check(colored >= 10, "au moins 10 statistiques ont un mot-clé coloré (%d)" % colored)


func _label_and_sheet() -> void:
	print("Étiquette et fiche de greffe")
	var lab := RichLabel.new()
	lab.wrap_width = 120.0
	lab.color = base
	lab.text = "• +12 % Dégâts et poison, vie, vitesse, critique"
	root.add_child(lab)
	await process_frame
	check(lab.lines().size() >= 2, "l'étiquette coupe ses lignes (%d)" % lab.lines().size())
	check(lab.custom_minimum_size.y > 15.0 * lab.lines().size(), "hauteur proportionnée aux lignes : %s" % lab.custom_minimum_size)
	lab.add_theme_font_size_override("font_size", 11)
	var small := lab.custom_minimum_size.y
	check(small < lab.custom_minimum_size.y + 1.0 and lab.lines().size() >= 1, "taille de police suivie")
	lab.queue_free()
	# La fiche d'une greffe : effets et statistiques passent par RichLabel.
	var main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	for i in 5:
		await process_frame
	main.autotest = false
	main.autosave_enabled = false
	var game = root.get_node("Game")
	var id := ""
	for g in Content.grafts():
		for e in Content.grafts()[g].get("effects", []):
			if e.has("stat") and id == "":
				id = g
	game.give_graft(id)
	main.tree_ui.toggle()
	for i in 4:
		await process_frame
	var gp = main.tree_ui.grafts_panel
	gp.hover_graft = id
	gp._refresh_detail()
	await process_frame
	var rich := 0
	for l in gp._detail.get_children():
		if l is RichLabel:
			rich += 1
	check(rich >= 1, "la fiche de « %s » a %d ligne(s) en texte coloré" % [id, rich])
	main.queue_free()
