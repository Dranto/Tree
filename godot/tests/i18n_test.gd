## Traduction (jalon 12 A) : nombres et textes des données selon la langue, pluriels, changement de
## langue à chaud, réglage Settings.locale, et surtout : en pseudo-langue (xx), aucun texte visible ne
## reste en français simple. Écrans parcourus : titre, options (quatre onglets), HUD, pause et ses
## options, carte, Arbre de vie (en-tête, libellés, infobulles de tous les nœuds), choix d'une maîtrise.
## Vérifie aussi que la police a tous les glyphes de la pseudo-langue.
## Lancer : tools/godot.sh --headless --fixed-fps 60 -s res://tests/i18n_test.gd
extends SceneTree

var failures := 0
var escapes: Dictionary = {}   # texte resté en français -> où
var Settings
var UiAudit
var letters := RegEx.create_from_string("[A-Za-zÀ-ÖØ-öø-ÿŒœ]{2,}")
var bracketed := RegEx.create_from_string("\\[[^\\[\\]]*\\]")
## Textes qui ne se traduisent pas : noms de touches de Godot, noms des langues, initiales.
const ALLOWED := ["Tab", "Ctrl", "Français", "English", "Pseudo (xx)", "Escape", "Shift", "Space", "Enter"]


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


func _run() -> void:
	Settings = root.get_node("Settings")
	UiAudit = root.get_node("UiAudit")
	_numbers_and_data()
	_settings()
	_glyphs()
	await _pseudo_screens()
	print("RÉSULTAT ", "ok" if failures == 0 else "%d échec(s)" % failures)
	quit(1 if failures > 0 else 0)


## Nombres, gabarits des données, pluriels et contexte, avec une petite traduction anglaise de test.
func _numbers_and_data() -> void:
	print("Nombres et textes des données")
	Loc.apply("fr")
	check(Loc.num(1.5, 1) == "1,5" and Loc.num(2.25, 2) == "2,25", "nombre à la française : %s" % Loc.num(1.5, 1))
	check(Loc.pct(60) == "60 %", "pourcentage à la française")
	var nums: Array = []
	check(Loc.template("Toutes les 1,5 s, ×2 (niveau 12)", nums) == "Toutes les {0} s, ×{1} (niveau {2})" and nums == ["1,5", "2", "12"],
		"gabarit des nombres : %s" % Loc.template("Toutes les 1,5 s, ×2 (niveau 12)", []))
	check(Loc.template("Résonance II, {min} s", []) == "Résonance II, {min} s", "un paramètre {min} n'est pas un nombre")
	check(Loc.data("Toutes les 1,5 s") == "Toutes les 1,5 s", "en français, un texte des données reste tel quel")
	check(Loc.tn("%d trouvée", "%d trouvées", 0) == "%d trouvée" and Loc.tn("%d trouvée", "%d trouvées", 2) == "%d trouvées", "pluriel français (0 et 1 au singulier)")
	var t := Translation.new()
	t.locale = "en"
	t.add_message("Toutes les {0} s, ×{1}", "Every {0} s, ×{1}")
	t.add_message("%d %%", "%d%%")
	t.add_message("Texte d'essai du Label", "Label test text")
	TranslationServer.add_translation(t)
	Loc.apply("en")
	Loc.clear_cache()
	check(Loc.num(1.5, 1) == "1.5", "nombre à l'anglaise : %s" % Loc.num(1.5, 1))
	check(Loc.pct(60) == "60%", "pourcentage traduit : %s" % Loc.pct(60))
	check(Loc.data("Toutes les 1,5 s, ×2") == "Every 1.5 s, ×2", "texte des données traduit, nombres remis : %s" % Loc.data("Toutes les 1,5 s, ×2"))
	check(Loc.data("Toutes les 3 s, ×0,5") == "Every 3 s, ×0.5", "même traduction quand un nombre change dans le JSON")
	check(Loc.data("Texte sans traduction 4,5") == "Texte sans traduction 4,5", "sans traduction : le texte français d'origine")
	var label := Label.new()
	label.text = "Texte d'essai du Label"
	root.add_child(label)
	check(label.atr(label.text) == "Label test text", "un Label traduit son texte lui-même")
	label.queue_free()
	TranslationServer.remove_translation(t)
	Loc.apply("fr")
	Loc.clear_cache()
	check(Loc.game_name() == str(ProjectSettings.get_setting("application/config/name")), "nom du jeu lu dans project.godot : %s" % Loc.game_name())


## Settings.locale : enregistré dans la section « general », langue du système par défaut, langue
## forcée par les tests (TREE_LANG ou --lang=) prioritaire.
func _settings() -> void:
	print("Réglage de la langue")
	var before: String = Settings.locale
	check(Loc.resolve("") in Loc.LOCALES, "langue du système résolue parmi les langues proposées (%s)" % Loc.resolve(""))
	check(Loc.resolve("en") == "en" and Loc.resolve("de") in Loc.LOCALES, "langue inconnue : repli")
	Settings.locale = "en"
	Settings.save_settings()
	var cfg := ConfigFile.new()
	cfg.load(Settings.PATH)
	check(str(cfg.get_value("general", "locale", "?")) == "en", "langue enregistrée dans settings.cfg › general/locale")
	Settings.locale = ""
	Settings.load_settings()
	check(Settings.locale == "en", "langue relue au lancement")
	if Settings.forced_locale() != "":
		check(Settings.effective_locale() == Loc.resolve(Settings.forced_locale()), "la langue forcée des tests passe avant le choix du joueur")
	Settings.locale = before
	Settings.save_settings()
	Settings.apply_locale()


## Tous les textes du catalogue, en pseudo-langue, s'écrivent avec la police du jeu.
func _glyphs() -> void:
	print("Glyphes de la pseudo-langue")
	Loc.setup()
	var font: Font = load("res://scripts/ui_theme.gd").font()
	var missing := {}
	for msgid in Loc._known:
		for ch in Loc.pseudo(String(msgid)):
			if ch.unicode_at(0) >= 32 and not font.has_char(ch.unicode_at(0)):
				missing["%s (U+%04X)" % [ch, ch.unicode_at(0)]] = true
	check(missing.is_empty(), "la police couvre la pseudo-langue (%d textes)%s" % [Loc._known.size(), "" if missing.is_empty() else " ; manque : " + ", ".join(missing.keys())])
	check(Loc._known.size() > 1000, "catalogue chargé (%d textes)" % Loc._known.size())


## Texte affiché par un Control (ce qu'il dessine, après sa propre traduction).
func _shown(c: Control, s: String) -> String:
	return c.atr(s) if c.can_auto_translate() else s


## Un texte visible : resté en français simple s'il garde des lettres hors des morceaux en pseudo-langue.
func _scan_text(s: String, where: String) -> void:
	if s.strip_edges() == "" or s.strip_edges() in ALLOWED:
		return
	var rest := s
	var prev := ""
	while prev != rest:   # morceaux imbriqués : « [Attaque : [fouet]] »
		prev = rest
		rest = bracketed.sub(rest, " ", true)
	var bad := false
	for m in letters.search_all(rest):
		var w := m.get_string()
		# Noms de boutons et de touches (RT, LB, Tab) : jamais traduits.
		if not w in ALLOWED and not (w == w.to_upper() and w.length() <= 3):
			bad = true
	if bad:
		if not escapes.has(s):
			escapes[s] = where


func _scan(node: Node, where: String) -> void:
	for c in node.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		if ctl is LineEdit:
			_scan_text(_shown(ctl, (ctl as LineEdit).placeholder_text), where)
		elif ctl is OptionButton:
			var ob := ctl as OptionButton
			for i in ob.item_count:
				if ob.get_item_auto_translate_mode(i) != Node.AUTO_TRANSLATE_MODE_DISABLED:
					_scan_text(_shown(ctl, ob.get_item_text(i)), where + " (liste)")
		elif ctl is Button:
			_scan_text(_shown(ctl, (ctl as Button).text), where)
			_scan_text(_shown(ctl, ctl.tooltip_text), where + " (infobulle)")
			var note = ctl.get("note")
			if note is String:
				_scan_text(note, where + " (note)")
		elif ctl is Label:
			_scan_text(_shown(ctl, (ctl as Label).text), where)
		elif ctl is RichTextLabel:
			_scan_text((ctl as RichTextLabel).get_parsed_text(), where)


func _scan_audit(screen: String) -> void:
	for it in UiAudit.screens.get(screen, []):
		_scan_text(str(it["label"]), screen + " (dessiné)")


func _pseudo_screens() -> void:
	print("Pseudo-langue : textes visibles")
	Loc.apply(Loc.PSEUDO)
	UiAudit.enabled = true
	# Titre et options (les quatre onglets).
	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await _frames(4)
	_scan(title, "titre")
	title.options.open()
	await _frames(2)
	for i in title.options.pages.size():
		title.options.show_tab(i)
		await _frames(1)
		_scan(title.options, "options, onglet %d" % i)
	check(Loc.is_pseudo(title.options.move_hint.text), "les aides des options sont refaites au changement de langue")
	title.queue_free()
	await _frames(2)
	# Partie : HUD, pause, carte, arbre.
	var main = load("res://scenes/main.tscn").instantiate()
	main.autotest = true
	main.autotest_shots = []
	main.autotest_done = true
	root.add_child(main)
	await _frames(6)
	var game = root.get_node("Game")
	game.add_xp(300.0)
	await _frames(3)
	_scan(main.hud, "HUD")
	main.pause_menu.open()
	await _frames(2)
	_scan(main.pause_menu, "pause")
	main.pause_menu.close()
	await _frames(1)
	var map = main.quest_ui.world_map
	map.open()
	await _frames(3)
	_scan(map, "carte")
	_scan_audit("carte")
	map.close()
	await _frames(1)
	var ui = main.tree_ui
	ui.toggle()
	await _frames(4)
	_scan(ui, "arbre")
	_scan_audit("arbre")
	# Infobulle de chaque nœud (texte avant la coupe en lignes) et noms dessinés sur l'arbre.
	var SkillTree = load("res://scripts/skill_tree.gd")
	for n in game.tree.nodes:
		_scan_text(SkillTree.node_name(n), "nom de nœud")
		for line in SkillTree.describe(n):
			_scan_text(line, "infobulle du nœud « %s »" % n["name"])
		for l in ui.panels.tooltip_lines(n, "available"):
			_scan_text(str(l[0]), "infobulle (chemin) du nœud « %s »" % n["name"])
	ui.panels.set_summary_visible(true)
	await _frames(2)
	_scan(ui, "arbre, résumé du build")
	ui.toggle()
	await _frames(2)
	UiAudit.enabled = false
	var list := escapes.keys()
	for s in list.slice(0, 40):
		print("    en français : « %s » (%s)" % [s, escapes[s]])
	check(escapes.is_empty(), "aucun texte visible n'échappe à la traduction (%d trouvés)" % escapes.size())
	main.queue_free()
	await _frames(2)
	Loc.apply("fr")
