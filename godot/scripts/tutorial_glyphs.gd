## Tutoriel discret (jalon 11) : le terrain apprend chaque geste, et un glyphe de touche apparaît au
## bon moment puis s'efface dès que le geste est réussi. Jamais de pause, jamais de phrase : des
## touches et une souris dessinées par le code, au-dessus du héros (ou sous le coin de l'Arbre).
##
## Étapes, dans l'ordre de priorité (une seule visible à la fois) :
## - « bouger » : dès le début ; s'efface après quelques pas.
## - « esquive » : au premier Flétri tout proche ou au premier coup reçu ; s'efface à la première esquive.
## - « competence » : au premier groupe de Flétris, avec une compétence en main ; s'efface au premier lancer.
## - « arbre » : un point à placer et l'Arbre jamais ouvert ; la touche pulse sous le coin, jusqu'à l'ouverture.
## - « stats » : au niveau 3, la touche des statistiques (à maintenir) sous le coin ; s'efface dès qu'on la tient.
## Chaque étape réussie pose « tuto_<étape> » dans Game.flags (sauvegarde) : elle ne revient jamais.
## Une étape montrée trop longtemps sans être réussie s'efface aussi (MAX_SHOW) : on ne harcèle pas.
## Réglage « Afficher les aides » (Settings.show_hints) : coupe tout.
## Glyphes clavier et souris, ou manette (pad_glyphs.gd) quand la dernière entrée vient d'une manette.
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const Controls = preload("res://scripts/controls_text.gd")
const PadGlyphs = preload("res://scripts/pad_glyphs.gd")

const STEPS := ["bouger", "esquive", "competence", "arbre", "stats"]
## Durée maximale d'affichage d'une étape (s) ; « arbre » attend l'ouverture de l'Arbre.
const MAX_SHOW := 14.0
## Distance de marche qui valide « bouger » (pixels du monde).
const MOVE_DONE := 90.0
## Un Flétri à moins de cette distance : il est temps d'apprendre l'esquive.
const DODGE_NEAR := 210.0
## Au moins GROUP Flétris à moins de GROUP_NEAR : il est temps d'apprendre la compétence.
const GROUP := 2
const GROUP_NEAR := 420.0
## Niveau à partir duquel la touche des statistiques est montrée.
const STATS_LEVEL := 3
## Hauteur du glyphe au-dessus du héros (pixels de l'écran).
const ABOVE := 86.0

var main
var t := 0.0
## Étape montrée ("" : aucune), son temps d'affichage et son opacité.
var step := ""
var shown := 0.0
var alpha := 0.0
var _start = null
var _check := 0.0
## Partie déjà bien avancée (sauvegarde d'avant le jalon 11) : aucun glyphe, sans toucher aux drapeaux.
var _veteran := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func flag(id: String) -> String:
	return "tuto_" + id


static func done(id: String) -> bool:
	return bool(Game.flags.get(flag(id), false))


func finish(id: String) -> void:
	Game.flags[flag(id)] = true
	if step == id:
		step = ""


## Étape visible à l'écran ("" : aucune) — pour les tests.
func visible_step() -> String:
	return step if alpha > 0.05 else ""


func _process(delta: float) -> void:
	t += delta
	if main == null or not is_instance_valid(main) or main.player == null:
		return
	var p = main.player
	if _start == null:
		_start = p.position
		_veteran = Game.level > 3 and not done("bouger")
	_validate(p)
	_check -= delta
	if _check <= 0.0:
		_check = 0.2
		if step == "" or done(step):
			step = _pick(p)
			shown = 0.0
	var show := step != "" and Settings.show_hints and _can_show()
	if show:
		shown += delta
		if step != "arbre" and shown > MAX_SHOW:
			finish(step)
			show = false
	alpha = move_toward(alpha, 1.0 if show else 0.0, delta * (3.0 if show else 4.0))
	queue_redraw()


## Les gestes réussis, qu'une étape soit montrée ou non (un joueur qui esquive tout seul n'a pas
## besoin du glyphe).
func _validate(p) -> void:
	if not done("bouger") and _start != null and p.position.distance_to(_start) > MOVE_DONE:
		finish("bouger")
	if not done("esquive") and p.dash_time > 0.0:
		finish("esquive")
	if not done("competence"):
		for cd in p.cds.values():
			if float(cd) > 0.0:
				finish("competence")
				break
	if not done("arbre") and main.tree_ui.visible:
		finish("arbre")
	if not done("stats") and Input.is_action_pressed("show_stats"):
		finish("stats")


func _pick(p) -> String:
	if _veteran:
		return ""
	if not done("bouger"):
		return "bouger"
	if not done("esquive") and (p.hurt_flash > 0.0 or not main.enemies_near(p.position, DODGE_NEAR).is_empty()):
		return "esquive"
	if not done("competence") and p.bar.size() > 0 and str(p.bar[0]) != "" and main.enemies_near(p.position, GROUP_NEAR).size() >= GROUP:
		return "competence"
	if not done("arbre") and Game.points > 0:
		return "arbre"
	if not done("stats") and Game.level >= STATS_LEVEL:
		return "stats"
	return ""


func _can_show() -> bool:
	if main.tree_ui.visible or get_tree().paused:
		return false
	var hud = main.get("hud")
	if hud != null and hud.death_screen != null and hud.death_screen.is_showing():
		return false
	return true


## Ce qu'il faut dessiner pour une étape : [« keys », [touches…]] ou [« mouse », bouton] où bouton vaut
## « left », « right » ou « move » (la souris seule, qui guide).
## À la manette : [« pad », [codes…]] (voir pad_glyphs.gd).
static func glyph_for(id: String) -> Array:
	if Settings.pad_active():
		match id:
			"bouger":
				return ["pad", [Settings.PAD_STICK_L]]
			"esquive":
				return ["pad", [Settings.pad_code("dash")]]
			"competence":
				return ["pad", [Settings.pad_code("skill_main_1")]]
			"arbre":
				return ["pad", [Settings.pad_code("toggle_tree")]]
			"stats":
				return ["pad", [Settings.pad_code("show_stats")]]
		return []
	match id:
		"bouger":
			match Settings.move_mode:
				"curseur":
					return ["mouse", "move"]
				"moba":
					return ["mouse", "right"]
			return ["cross", Controls.move_keys().split(" ")]
		"esquive":
			return ["keys", [Controls.action_label("dash")]]
		"competence":
			if Settings.binding_is_mouse(0):
				return ["mouse", "left"]
			return ["keys", [Settings.binding_name(0)]]
		"arbre":
			return ["keys", [Controls.action_label("toggle_tree", true)]]
		"stats":
			return ["keys", [Controls.action_label("show_stats", true)]]
	return []


func _draw() -> void:
	if alpha <= 0.01 or step == "" or main == null or main.player == null:
		return
	var g := glyph_for(step)
	if g.is_empty():
		return
	var at: Vector2
	if step == "arbre" or step == "stats":
		# Sous le coin (niveau, points, touche de l'Arbre).
		at = Vector2(20.0 + 105.0, 20.0 + 66.0 + 34.0)
	else:
		at = get_viewport().get_canvas_transform() * main.player.position + Vector2(0, -ABOVE)
	var bob := 3.0 * sin(t * 3.2)
	at.y += bob
	var a := alpha * (0.8 + 0.2 * sin(t * 4.0))
	match str(g[0]):
		"keys":
			var keys: Array = g[1]
			var total := 0.0
			for k in keys:
				total += _key_width(str(k)) + 6.0
			var x := at.x - total / 2.0
			for k in keys:
				var w := _key_width(str(k))
				_key(Vector2(x + w / 2.0, at.y), str(k), a)
				x += w + 6.0
		"cross":
			var keys: Array = g[1]
			if keys.size() == 4:
				_key(at + Vector2(0, -18), str(keys[0]), a)
				_key(at + Vector2(-34, 18), str(keys[1]), a)
				_key(at + Vector2(0, 18), str(keys[2]), a)
				_key(at + Vector2(34, 18), str(keys[3]), a)
		"mouse":
			_mouse(at, str(g[1]), a)
		"pad":
			PadGlyphs.draw_row(self, at, g[1], a, 32.0)


func _key_width(label: String) -> float:
	var font := UiTheme.font(true)
	return maxf(30.0, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 16.0)


## Une touche : un cabochon de papier sombre, bord doré, la lettre au milieu.
func _key(c: Vector2, label: String, a: float) -> void:
	var font := UiTheme.font(true)
	var w := _key_width(label)
	var r := Rect2(c - Vector2(w / 2.0, 15.0), Vector2(w, 30.0))
	draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.35 * a))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTheme.PAPER_DARK, 0.92 * a)
	sb.border_color = Color(UiTheme.GOLD, 0.95 * a)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	draw_style_box(sb, r)
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, Vector2(c.x - tw / 2.0, c.y + 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UiTheme.INK, a))


## Une souris : le corps arrondi, le bouton à presser allumé (ou deux flèches si elle guide seule).
func _mouse(c: Vector2, button: String, a: float) -> void:
	var w := 26.0
	var h := 38.0
	var body := Rect2(c - Vector2(w, h) / 2.0, Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTheme.PAPER_DARK, 0.92 * a)
	sb.border_color = Color(UiTheme.GOLD, 0.95 * a)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	draw_rect(Rect2(body.position + Vector2(0, 3), body.size), Color(0, 0, 0, 0.3 * a))
	draw_style_box(sb, body)
	var top := body.position.y + h * 0.42
	draw_line(Vector2(body.position.x + 2, top), Vector2(body.end.x - 2, top), Color(UiTheme.GOLD, 0.7 * a), 1.5)
	draw_line(Vector2(c.x, body.position.y + 2), Vector2(c.x, top), Color(UiTheme.GOLD, 0.7 * a), 1.5)
	var lit := Color(Art.ec("seve", "clair"), a)
	if button == "left" or button == "right":
		var x0 := body.position.x + 3.0 if button == "left" else c.x + 1.0
		draw_rect(Rect2(Vector2(x0, body.position.y + 4.0), Vector2(w / 2.0 - 4.0, h * 0.42 - 6.0)), lit)
	else:
		# La souris guide : quatre petites flèches autour.
		for i in 4:
			var d := Vector2.from_angle(i * PI / 2.0)
			var tip := c + d * 34.0
			var side := d.orthogonal() * 5.0
			draw_colored_polygon(PackedVector2Array([tip, tip - d * 8.0 + side, tip - d * 8.0 - side]), Color(UiTheme.GOLD, a))
