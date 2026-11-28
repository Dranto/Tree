## Test du confort et de l'accessibilité (jalon 11, tâche K) : réglages d'effets (secousse, éclats,
## micro-pauses) et reprise de l'ancienne clé, modes daltoniens (couleurs distinctes en simulation,
## hachures des zones annoncées), contraste renforcé, taille du texte, toutes les commandes
## réassignables, pause quand la fenêtre perd le focus, panneau d'options.
## Lancer : tools/godot.sh --headless -s res://tests/access_test.gd
extends SceneTree

## Chargés à l'exécution : ces scripts nomment des autoloads, absents à la compilation d'un -s.
var UiTheme
var OptionsPanel

var failures := 0
var settings


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
		await process_frame


# --- Simulation du daltonisme (Machado, Oliveira et Fernandes, 2009, sévérité 1) ---
const MACHADO := {
	"protanopie": [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
	"deuteranopie": [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
	"tritanopie": [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]],
}


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func simulate(col: Color, mode: String) -> Color:
	if not MACHADO.has(mode):
		return col
	var m: Array = MACHADO[mode]
	var l := [_lin(col.r), _lin(col.g), _lin(col.b)]
	var out := []
	for row in m:
		out.append(clampf(row[0] * l[0] + row[1] * l[1] + row[2] * l[2], 0.0, 1.0))
	return Color(out[0], out[1], out[2]).linear_to_srgb()


## Distance perceptive approchée (CIE76 sur Lab).
static func lab(col: Color) -> Vector3:
	var r := _lin(col.r)
	var g := _lin(col.g)
	var b := _lin(col.b)
	var x := (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
	var y := 0.2126 * r + 0.7152 * g + 0.0722 * b
	var z := (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
	var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	return Vector3(116.0 * f.call(y) - 16.0, 500.0 * (f.call(x) - f.call(y)), 200.0 * (f.call(y) - f.call(z)))


static func delta_e(a: Color, b: Color) -> float:
	return lab(a).distance_to(lab(b))


func _run() -> void:
	settings = root.get_node("Settings")
	UiTheme = load("res://scripts/ui_theme.gd")
	OptionsPanel = load("res://scripts/options_panel.gd")
	var cfg_path: String = settings.PATH
	var had_cfg := FileAccess.file_exists(cfg_path)
	var backup := FileAccess.get_file_as_string(cfg_path) if had_cfg else ""

	print("Fenêtre : une option (le volume…) ne redimensionne pas une fenêtre agrandie")
	var DS := DisplayServer
	check(settings.window_mode_for(false, DS.WINDOW_MODE_MAXIMIZED) == DS.WINDOW_MODE_MAXIMIZED, "hors plein écran, une fenêtre agrandie le reste")
	check(settings.window_mode_for(false, DS.WINDOW_MODE_WINDOWED) == DS.WINDOW_MODE_WINDOWED, "hors plein écran, une fenêtre normale le reste")
	check(settings.window_mode_for(false, DS.WINDOW_MODE_FULLSCREEN) == DS.WINDOW_MODE_WINDOWED, "décocher le plein écran revient en fenêtre")
	check(settings.window_mode_for(true, DS.WINDOW_MODE_MAXIMIZED) == DS.WINDOW_MODE_FULLSCREEN, "cocher le plein écran passe en plein écran")
	check(settings.window_mode_for(true, DS.WINDOW_MODE_EXCLUSIVE_FULLSCREEN) == DS.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, "un plein écran exclusif est gardé")
	print("Effets : secousse, éclats, micro-pauses")
	var cfg := ConfigFile.new()
	cfg.set_value("gameplay", "shake", 0.3)
	cfg.save(cfg_path)
	settings.load_settings()
	check(is_equal_approx(settings.shake_scale, 0.3), "l'ancienne clé « gameplay/shake » est reprise dans shake_scale")
	settings.reduce_effects = false
	settings.flash_scale = 0.4
	settings.hitstop_scale = 0.5
	check(is_equal_approx(settings.shake_strength(), 0.3) and is_equal_approx(settings.flash_strength(), 0.4) and is_equal_approx(settings.hitstop_strength(), 0.5), "les forces suivent les échelles")
	settings.reduce_effects = true
	check(settings.shake_strength() == 0.0 and settings.flash_strength() == 0.0 and settings.hitstop_strength() == 0.0, "« réduire les effets » coupe secousse, éclats et micro-pauses")
	settings.reduce_effects = false
	settings.save_settings()
	settings.shake_scale = 1.0
	settings.load_settings()
	check(is_equal_approx(settings.shake_scale, 0.3) and is_equal_approx(settings.flash_scale, 0.4) and is_equal_approx(settings.hitstop_scale, 0.5), "échelles enregistrées et relues")

	print("Modes daltoniens")
	var base_danger := Art.c("danger")
	check(settings.danger_color() == base_danger, "sans mode, la couleur de danger est celle de la charte")
	# Paires qui doivent rester distinctes pour chaque forme de daltonisme (signal contre sol,
	# héros, ou autre signal). Seuil : ΔE 20 après simulation.
	var pairs := [["danger", "sol_vivant"], ["danger", "sol_mort"], ["danger", "elite"], ["danger", "butin"],
		["danger", "accent"], ["danger", "joueur_accent"], ["elite", "butin"], ["elite", "sol_vivant"], ["butin", "sol_vivant"]]
	for mode in ["protanopie", "deuteranopie", "tritanopie"]:
		settings.set_colorblind_mode(mode)
		check(settings.danger_color() != base_danger or mode == "tritanopie", "%s : la couleur de danger change" % mode)
		var worst := INF
		var worst_pair := ""
		for pr in pairs:
			var d := delta_e(simulate(Art.c(pr[0]), mode), simulate(Art.c(pr[1]), mode))
			if d < worst:
				worst = d
				worst_pair = "%s / %s" % pr
		check(worst >= 20.0, "%s : signaux distincts après simulation (pire paire %s, ΔE %.1f)" % [mode, worst_pair, worst])
		check(Art.motifs, "%s : les zones annoncées sont hachurées" % mode)
	# Sans mode, la palette normale est plus confuse pour un protanope : c'est ce que le mode corrige.
	settings.set_colorblind_mode("aucun")
	var d0 := delta_e(simulate(Art.c("danger"), "deuteranopie"), simulate(Art.c("sol_vivant"), "deuteranopie"))
	settings.set_colorblind_mode("deuteranopie")
	var d1 := delta_e(simulate(Art.c("danger"), "deuteranopie"), simulate(Art.c("sol_vivant"), "deuteranopie"))
	check(d1 > d0, "deutéranopie : le danger se détache mieux du sol vivant avec le mode (ΔE %.1f → %.1f)" % [d0, d1])
	settings.set_colorblind_mode("aucun")
	check(not Art.motifs and Art.c("danger") == base_danger, "retour au mode normal : palette et formes d'origine")
	settings.set_colorblind_mode("n'importe quoi")
	check(settings.colorblind_mode == "aucun", "un mode inconnu revient à « aucun »")

	print("Hachures des annonces")
	var n := Art.hatch_segments(Art.telegraph_polygon({"type": "cercle", "centre": Vector2.ZERO, "rayon": 80.0}, 1.0)).size() / 2
	check(n >= 8 and n <= 20, "un cercle de 80 px reçoit des hachures (%d traits)" % n)

	print("Contraste renforcé")
	var soft: Color = UiTheme.SOFT
	settings.set_high_contrast(true)
	var paper := Art.c("papier")
	check(UiTheme.SOFT.get_luminance() > soft.get_luminance(), "l'encre secondaire s'éclaircit")
	var ratio := (_rel_lum(UiTheme.SOFT) + 0.05) / (_rel_lum(paper) + 0.05)
	check(ratio >= 7.0, "encre secondaire sur papier : contraste %.1f:1 (≥ 7:1)" % ratio)
	check(Art.c("danger_annonce").a > Art.PALETTE["danger_annonce"].a and Art.motifs, "zones de danger plus opaques et hachurées")
	settings.set_high_contrast(false)
	check(UiTheme.SOFT == soft and not Art.motifs, "contraste normal rétabli")

	print("Taille du texte")
	settings.set_text_scale(1.3)
	check(UiTheme.fs(20) == 26 and UiTheme.make().default_font_size == 29, "texte agrandi de 30 % (thème et tailles imposées)")
	settings.set_text_scale(1.2)
	check(settings.text_scale == 1.15, "une échelle hors liste revient à la plus proche")
	settings.set_text_scale(1.0)
	check(UiTheme.fs(20) == 20, "taille normale")

	print("Commandes")
	settings.reset_bindings()
	for a in settings.GAME_ACTIONS:
		check(InputMap.has_action(a) and not InputMap.action_get_events(a).is_empty(), "action « %s » créée" % a)
	check(settings.set_action_key("move_up", KEY_I) == "", "avancer réassigné sur I")
	check(_has_key("move_up", KEY_I) and not _has_key("move_up", KEY_W) and _has_key("move_up", KEY_UP), "I avance, W plus, la flèche toujours")
	check(settings.set_action_key("dash", KEY_I) != "", "une touche déjà prise est refusée")
	check(settings.set_action_key("dash", KEY_Q) != "", "une touche de la barre de compétences est refusée")
	check(settings.set_action_key("toggle_tree", KEY_ESCAPE) != "", "Échap reste au menu")
	check(settings.set_action_key("dash", KEY_V) == "" and _has_key("dash", KEY_V) and _has_key("dash", KEY_SHIFT), "esquive sur V (Maj garde l'esquive hors mode MOBA)")
	check(settings.set_action_key("toggle_map", KEY_K) == "" and _has_key("toggle_map", KEY_K), "carte réassignée")
	settings.save_settings()
	settings.reset_bindings()
	check(_has_key("move_up", KEY_W) and settings.action_keys["dash"] == KEY_SPACE, "commandes par défaut rétablies")
	settings.load_settings()
	check(settings.action_keys["move_up"] == KEY_I and settings.action_keys["toggle_map"] == KEY_K, "commandes enregistrées et relues")
	settings.reset_bindings()
	var map_ev := InputMap.action_get_events("toggle_map")[0] as InputEventKey
	check(map_ev != null and map_ev.keycode == KEY_M and map_ev.physical_keycode == KEY_NONE, "carte : M logique par défaut (quelle que soit la disposition)")

	print("Panneau d'options")
	var panel = OptionsPanel.new()
	root.add_child(panel)
	await _steps(2)
	panel.open()
	await _steps(2)
	check(panel.action_buttons.size() == settings.GAME_ACTIONS.size(), "une ligne par commande du jeu")
	panel._listen(panel.ACTION_ROW0 + settings.GAME_ACTIONS.find("toggle_tree"))
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_G
	ev.pressed = true
	panel._input(ev)
	check(settings.action_keys["toggle_tree"] == KEY_G and panel.listening == -1, "réassignation depuis le panneau")
	panel.colorblind_select.select(2)
	panel.colorblind_select.item_selected.emit(2)
	check(settings.colorblind_mode == "deuteranopie" and panel.access_hint.text != "", "mode daltonien choisi dans l'onglet Affichage")
	panel.queue_free()
	settings.set_colorblind_mode("aucun")
	settings.reset_bindings()

	print("Pause quand la fenêtre perd le focus")
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.autosave_enabled = false
	main.spawn_paused = true
	await _steps(3)
	settings.pause_on_focus_loss = true
	check(main._pause_on_focus_loss() and paused and main.pause_menu.visible, "le menu pause s'ouvre")
	check(not main._pause_on_focus_loss(), "déjà en pause : rien de plus")
	main.pause_menu.close()
	settings.pause_on_focus_loss = false
	check(not main._pause_on_focus_loss() and not paused, "réglage coupé : le jeu continue")
	settings.pause_on_focus_loss = true
	main.queue_free()
	await _steps(2)

	# Remet les options du poste comme avant le test.
	if had_cfg:
		var f := FileAccess.open(cfg_path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))
	settings.load_settings()
	settings.apply_bindings()
	if failures == 0:
		print("ACCESSIBILITÉ : tout est bon")
	else:
		print("ACCESSIBILITÉ : %d échec(s)" % failures)
	quit(1 if failures > 0 else 0)


func _has_key(action: String, code: int) -> bool:
	for e in InputMap.action_get_events(action):
		var k := e as InputEventKey
		if k and k.physical_keycode == code:
			return true
	return false



## Luminance relative (WCAG).
static func _rel_lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)
