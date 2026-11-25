## Fin de l'aventure jouée dans le monde (jalon 11), à la place de l'épilogue écrit et de l'écran de
## générique : la Flétrissure vaincue, le joueur remonte au pied de la graine, des vagues de vie
## partent de la graine vers tout le monde, et le générique s'écrit dans l'herbe autour de la graine,
## un groupe de noms après l'autre, pendant que le joueur se promène. Aucun écran, aucune pause,
## aucun bouton : le menu pause garde « Retour au titre ».
##
## Le générique vient de data/finale.json › credits ; « auto » liste les régions et les gardiens du
## monde tel qu'il est. Une fois la fin vue (Objectives.ENDING_SEEN, dans la sauvegarde), les noms
## restent écrits dans l'herbe : on peut revenir les lire.
## Dessiné sous les acteurs (main.gd), comme la veine de sève.
extends Node2D

const Regions = preload("res://scripts/regions.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const Content = preload("res://scripts/content.gd")

## Demi-axes (pixels du monde) de l'anneau de noms, centré là où le joueur remonte (pied de la graine).
const RING := 660.0
const RING_Y := 250.0
## Écart (s) entre deux groupes de noms, et durée d'apparition d'un groupe.
const STEP := 3.2
const GROW := 1.6
## Nombre de vagues de vie qui partent de la graine, et leur écart (s).
const WAVES := 4
const WAVE_GAP := 1.4

var main
## La fin est en cours (vagues et noms qui apparaissent) ; t compte depuis son début.
var active := false
var t := -1.0
## Groupes du générique : [{title: bool, lines: [texte…]}], chacun posé à un angle de l'anneau.
var groups: Array = []
var _waves_sent := 0
## La vie part de la brèche (juste au-dessus de là où la Flétrissure est morte) ; chaque région
## reverdit quand le front l'atteint (sol des régions, ground.set_purified, par paliers).
var _from := Vector2.ZERO
var _purified := {}
## Vitesse du front de vie (px/s) : il atteint le bord du monde avec la dernière vague.
const FRONT_SPEED := 1400.0
## Centre de l'anneau de noms : là où le joueur remonte de la finale (sinon la graine).
var center := Vector2.ZERO


func _ready() -> void:
	groups = credit_groups()
	center = _center_of(main)
	if bool(Game.flags.get(Objectives.ENDING_SEEN, false)):
		# Partie reprise après la fin : les noms sont déjà écrits.
		t = INF


static func _center_of(m) -> Vector2:
	if m != null and is_instance_valid(m) and m.get("finale") != null:
		return m.finale.entrance()
	return Vector2.ZERO


## Groupes du générique (data/finale.json › credits).
static func credit_groups() -> Array:
	var out: Array = []
	for entry in Content._load("finale").get("credits", []):
		if not entry is Dictionary:
			continue
		if str(entry.get("title", "")) != "":
			var title := str(entry["title"])
			# Le titre qui porte le nom du jeu suit project.godot (Loc.game_name).
			out.append({"title": true, "lines": [Loc.game_name() if title == str(ProjectSettings.get_setting("application/config/name")) else Loc.data(title)]})
			continue
		var lines: Array = []
		for l in entry.get("lines", []):
			lines.append(Loc.data(str(l)))
		match str(entry.get("auto", "")):
			"regions":
				for id in Regions.ids():
					lines.append(Loc.data(str(Regions.def(id).get("map_name", id))))
			"bosses":
				for id in Regions.ids():
					lines.append(Loc.data(str(Regions.section(id, "boss").get("name", id))))
				lines.append(Loc.data(str(Content._load("finale").get("boss", {}).get("name", Loc.key("La Flétrissure")))))
		out.append({"title": false, "head": Loc.data(str(entry.get("head", ""))), "lines": lines})
	return out


## Lance la fin : drapeau posé (elle ne reviendra pas), le joueur au pied de la graine, sauvegarde.
func begin(m) -> void:
	main = m
	Game.flags[Objectives.ENDING_SEEN] = true
	active = true
	t = 0.0
	_waves_sent = 0
	if main.get("finale") != null:
		main.finale.bring_up()
	center = _center_of(main)
	main.spawn_paused = true
	_prng.seed = 4242
	_from = main.finale.descent_point() if main.get("finale") != null else Vector2.ZERO
	_purified = {}
	main.screen_fx.glow(Art.ec("seve"), 0.5, 3.0)
	Sfx.play("coeur")
	main.save_game()


## Instant de la fin (tests, captures) : les vagues dues partent, les noms apparaissent.
func set_time(seconds: float) -> void:
	t = seconds
	_step()
	queue_redraw()


## Durée de la fin : quand le dernier groupe est écrit, les Flétris reviennent.
func duration() -> float:
	return STEP * groups.size() + GROW


func _process(delta: float) -> void:
	if not active:
		if t == INF:
			queue_redraw()
		return
	# La fin attend que le héros soit sorti de la brèche (finale_arena.gd › bring_up).
	if main != null and is_instance_valid(main) and main.get("finale") != null and main.finale.ascent_waiting():
		return
	t += delta
	_step()
	queue_redraw()


func _step() -> void:
	if main == null or not is_instance_valid(main):
		return
	while _waves_sent < WAVES and t >= _waves_sent * WAVE_GAP:
		var r := Regions.WORLD_HALF * (0.35 + 0.65 * float(_waves_sent + 1) / WAVES) * 1.5
		main.ground.paint_wave(_from, r, 2.0)
		# Chaque vague part de la brèche dans une gerbe de pétales et de lueurs.
		if not Settings.reduce_effects and main.get("fx") != null:
			for i in 40:
				var dir := Vector2.from_angle(TAU * i / 40.0 + _prng.randf_range(-0.08, 0.08))
				if i % 2 == 0:
					main.fx.petal(_from, dir * _prng.randf_range(250.0, 600.0), _prng.randf_range(1.6, 2.6), _prng.randf_range(6.0, 10.0), Color(Art.ec(["seve", "lumiere", "vent", "poison"][i % 4], "clair"), 0.95))
				else:
					main.fx.mote(_from, dir * _prng.randf_range(500.0, 1000.0), _prng.randf_range(0.4, 0.8), 3.0, Color(Art.ec("seve", "clair"), 0.95))
		if _waves_sent == 0:
			main.flora.spawn_patch(_from, 620.0, 40, Art.ec("seve", "clair"), 2.0, 620.0)
		else:
			# Chaque vague suivante fait fleurir une partie des régions, à leurs couleurs.
			for rid in Regions.ids():
				if Regions.ids().find(rid) % (WAVES - 1) == (_waves_sent - 1):
					var tint := Regions.color(Regions.def(rid).get("color", "#7fd36b"))
					main.flora.spawn_patch(Regions.center(rid), 900.0, 40, tint, 2.0, 900.0)
		_waves_sent += 1
	# Les régions reverdissent quand le front de vie les atteint, par paliers d'un dixième.
	for id in Regions.ids():
		var d := _from.distance_to(Regions.center(id))
		var k := snappedf(clampf((t * FRONT_SPEED - d + 900.0) / 1800.0, 0.0, 1.0), 0.1)
		if k > float(_purified.get(id, -1.0)):
			_purified[id] = k
			main.ground.set_purified(id, maxf(k, main.ground.purified_of(id)))
	_particles()
	if active and t >= duration():
		for id in Regions.ids():
			main.ground.set_purified(id, 1.0)
		active = false
		t = INF
		if not main.in_boss_fight():
			main.spawn_paused = false


var _prng := RandomNumberGenerator.new()


## Pendant la fin : des pétales aux couleurs des régions volent autour du héros, portés par le vent,
## et des lueurs de sève montent de l'herbe et le rejoignent ; plus nombreux au début.
func _particles() -> void:
	if not active or Settings.reduce_effects or main.get("fx") == null or main.player == null:
		return
	var fx = main.fx
	var p: Vector2 = main.player.position
	var k := clampf(1.0 - t / maxf(duration(), 1.0), 0.25, 1.0)
	var ids := Regions.ids()
	if _prng.randf() < 0.9 * k and not ids.is_empty():
		var rid: String = ids[_prng.randi() % ids.size()]
		var tint := Regions.color(Regions.def(rid).get("color", "#7fd36b")).lightened(0.25)
		fx.petal(p + Vector2(_prng.randf_range(-900.0, 300.0), _prng.randf_range(-520.0, 420.0)), Vector2(_prng.randf_range(120.0, 220.0), _prng.randf_range(-30.0, 10.0)), _prng.randf_range(3.0, 5.0), _prng.randf_range(6.0, 10.0), Color(tint, 0.9))
	if _prng.randf() < 0.6 * k:
		var a := _prng.randf() * TAU
		fx.glow_mote(p + Vector2.from_angle(a) * _prng.randf_range(250.0, 600.0), Vector2(0.0, -40.0), 2.4, 3.0, Color(Art.ec("seve", "clair"), 0.9), true)


## Apparition (0 à 1) du groupe i.
func group_k(i: int) -> float:
	if t == INF:
		return 1.0
	if t < 0.0:
		return 0.0
	return clampf((t - 1.0 - i * STEP) / GROW, 0.0, 1.0)


## Position du groupe i sur l'anneau, dans le sens des aiguilles d'une montre depuis le haut.
func group_pos(i: int) -> Vector2:
	var n := maxi(groups.size(), 1)
	# Décalé d'un demi-pas : rien tout en haut (le sanctuaire de la Graine) ni tout en bas (le HUD).
	var ang := -PI / 2.0 + TAU * (float(i) + 0.5) / n
	return center + Vector2(cos(ang) * RING, sin(ang) * RING_Y)


func _draw() -> void:
	if t < 0.0 or groups.is_empty():
		return
	if main != null and is_instance_valid(main) and main.player != null:
		# Loin de la graine, rien à dessiner.
		if main.player.position.distance_to(center) > RING + 1400.0:
			return
	var font := UiTheme.font()
	var bold := UiTheme.font(true)
	# Encre sombre gravée dans l'herbe claire, titres d'or bruni (style Herbier).
	var ink := Color(0.1, 0.14, 0.07)
	var head_col := Color(0.42, 0.3, 0.06)
	for i in groups.size():
		var k := group_k(i)
		if k <= 0.0:
			continue
		var g: Dictionary = groups[i]
		var at := group_pos(i)
		var lines: Array = g["lines"]
		var y := at.y - (lines.size() * 28.0) / 2.0
		# Les lettres poussent : elles montent du sol et prennent leur couleur.
		var rise := (1.0 - Anim.ease_out(k)) * 10.0
		if g["title"]:
			_text(bold, at + Vector2(0, rise), str(lines[0]), 48, Color(head_col, k))
			continue
		if str(g.get("head", "")) != "":
			_text(bold, Vector2(at.x, y - 8.0 + rise), str(g["head"]).to_upper(), 16, Color(head_col, k))
			y += 20.0
		for l in lines:
			y += 28.0
			_text(font, Vector2(at.x, y + rise), str(l), 24, Color(ink, k))


## Texte centré sur « at », avec une ombre de terre pour se lire sur l'herbe.
func _text(font: Font, at: Vector2, s: String, size_px: int, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var o := Vector2(at.x - w / 2.0, at.y)
	draw_string_outline(font, o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 7, Color(0.93, 0.95, 0.82, 0.55 * col.a))
	draw_string(font, o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
