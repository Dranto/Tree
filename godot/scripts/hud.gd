## Interface en jeu : vie, expérience, points à placer, compétences et état du monde.
extends Control

## Part du monde qu'il est possible de raviver (disque de l'arbre sur la carte carrée).
const REVIVABLE := 0.67

var main
var font: Font
var banner_text := ""
var banner_time := 0.0
var hint_time := 12.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func banner(s: String) -> void:
	banner_text = s
	banner_time = 3.0


var _labels := {}


## Nom de la touche selon la disposition du clavier du joueur (Z sur AZERTY pour « avancer »).
func key_label(action: String) -> String:
	if _labels.has(action):
		return _labels[action]
	var label := "?"
	for ev in InputMap.action_get_events(action):
		var key_ev := ev as InputEventKey
		if key_ev:
			var kc := key_ev.physical_keycode
			if DisplayServer.get_name() != "headless":
				kc = DisplayServer.keyboard_get_keycode_from_physical(kc)
			label = OS.get_keycode_string(kc)
			break
	_labels[action] = label
	return label


func _process(delta: float) -> void:
	banner_time -= delta
	hint_time -= delta
	queue_redraw()


func _panel(r: Rect2) -> void:
	draw_rect(r, Color(0.06, 0.08, 0.07, 0.8))
	draw_rect(r, Color(0.6, 0.8, 0.6, 0.2), false, 1.0)


func _draw() -> void:
	var s: Dictionary = Game.stats
	var w := size.x
	var h := size.y
	var p = main.player

	# Vie
	var hp_ratio: float = clampf(p.hp / s["max_hp"], 0.0, 1.0)
	_panel(Rect2(20, h - 74, 340, 54))
	draw_rect(Rect2(30, h - 64, 320, 16), Color(0.25, 0.08, 0.08))
	draw_rect(Rect2(30, h - 64, 320 * hp_ratio, 16), Color("c84b44"))
	draw_string(font, Vector2(34, h - 51), "Vie %d / %d" % [roundi(p.hp), roundi(s["max_hp"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	# Expérience
	var xp_ratio := clampf(Game.xp / Game.xp_to_next(), 0.0, 1.0)
	draw_rect(Rect2(30, h - 42, 320, 10), Color(0.08, 0.15, 0.08))
	draw_rect(Rect2(30, h - 42, 320 * xp_ratio, 10), Color("7fd36b"))

	# Niveau, points, monde
	_panel(Rect2(20, 20, 300, 96))
	draw_string(font, Vector2(34, 46), "Niveau %d" % Game.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e9e2c8"))
	var pts_col := Color("f2d06b") if Game.points > 0 else Color(0.7, 0.75, 0.7)
	draw_string(font, Vector2(34, 72), "Points de l'Arbre : %d  (%s)" % [Game.points, key_label("toggle_tree")], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, pts_col)
	var revived := minf(1.0, main.ground.ratio() / REVIVABLE)
	draw_string(font, Vector2(34, 96), "Monde ravivé : %.1f %%   ·   Flétris purifiés : %d" % [revived * 100.0, Game.kills], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.85, 0.75))

	# Compétences actives
	var skills := [["nova", "skill_nova", "Épines", Color("e0675e")], ["cloud", "skill_cloud", "Spores", Color("b48ae0")], ["bloom", "skill_bloom", "Floraison", Color("7fd36b")]]
	var x := w / 2.0 - 120.0
	for sk in skills:
		var owned := Game.has_key(sk[0])
		var r := Rect2(x, h - 84, 70, 64)
		_panel(r)
		if owned:
			var cd: float = p.cds[sk[0]]
			var maxcd: float = p.skill_cd[sk[0]]
			var col: Color = sk[3]
			if cd > 0.0:
				col = col.darkened(0.6)
			draw_rect(Rect2(x + 6, h - 78, 58, 34), col)
			if cd > 0.0:
				draw_rect(Rect2(x + 6, h - 78, 58, 34 * cd / maxcd), Color(0, 0, 0, 0.45))
			draw_string(font, Vector2(x, h - 55), key_label(sk[1]), HORIZONTAL_ALIGNMENT_CENTER, 70, 18, Color.WHITE)
			draw_string(font, Vector2(x, h - 28), sk[2], HORIZONTAL_ALIGNMENT_CENTER, 70, 12, Color(0.85, 0.9, 0.85))
		else:
			draw_string(font, Vector2(x, h - 46), "—", HORIZONTAL_ALIGNMENT_CENTER, 70, 18, Color(0.5, 0.5, 0.5))
			draw_string(font, Vector2(x, h - 28), "verrouillé", HORIZONTAL_ALIGNMENT_CENTER, 70, 11, Color(0.5, 0.5, 0.5))
		x += 80.0

	# Bannière
	if banner_time > 0.0:
		var a := clampf(banner_time, 0.0, 1.0)
		draw_string(font, Vector2(0, 160), banner_text, HORIZONTAL_ALIGNMENT_CENTER, w, 24, Color(0.95, 0.92, 0.75, a))

	# Aide de départ
	if hint_time > 0.0:
		var a := clampf(hint_time / 2.0, 0.0, 1.0)
		var lines := [
			"%s %s %s %s : se déplacer   ·   Clic gauche : lancer des graines   ·   %s : esquive" % [key_label("move_up"), key_label("move_left"), key_label("move_down"), key_label("move_right"), key_label("dash")],
			"%s : ouvrir l'Arbre de vie. Chaque nœud appris ravive une région du monde." % key_label("toggle_tree"),
		]
		var y := h - 140.0
		for line in lines:
			draw_string(font, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color(0.9, 0.95, 0.85, a))
			y += 24.0
