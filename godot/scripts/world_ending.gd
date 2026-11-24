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

## Rayon (pixels du monde) de l'anneau de noms autour de la graine.
const RING := 470.0
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


func _ready() -> void:
	groups = credit_groups()
	if bool(Game.flags.get(Objectives.ENDING_SEEN, false)):
		# Partie reprise après la fin : les noms sont déjà écrits.
		t = INF


## Groupes du générique (data/finale.json › credits).
static func credit_groups() -> Array:
	var out: Array = []
	for entry in Content._load("finale").get("credits", []):
		if not entry is Dictionary:
			continue
		if str(entry.get("title", "")) != "":
			out.append({"title": true, "lines": [str(entry["title"])]})
			continue
		var lines: Array = []
		for l in entry.get("lines", []):
			lines.append(str(l))
		match str(entry.get("auto", "")):
			"regions":
				for id in Regions.ids():
					lines.append(str(Regions.def(id).get("map_name", id)))
			"bosses":
				for id in Regions.ids():
					lines.append(str(Regions.section(id, "boss").get("name", id)))
				lines.append(str(Content._load("finale").get("boss", {}).get("name", "La Flétrissure")))
		out.append({"title": false, "head": str(entry.get("head", "")), "lines": lines})
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
	main.spawn_paused = true
	for id in Regions.ids():
		main.ground.set_purified(id, 1.0)
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
	t += delta
	_step()
	queue_redraw()


func _step() -> void:
	if main == null or not is_instance_valid(main):
		return
	while _waves_sent < WAVES and t >= _waves_sent * WAVE_GAP:
		var r := Regions.WORLD_HALF * (0.35 + 0.65 * float(_waves_sent + 1) / WAVES) * 1.5
		main.ground.paint_wave(Vector2.ZERO, r, 2.0)
		if _waves_sent == 0:
			main.flora.spawn_patch(Vector2.ZERO, 620.0, 40, Art.ec("seve", "clair"), 2.0, 620.0)
		else:
			# Chaque vague suivante fait fleurir une partie des régions, à leurs couleurs.
			for rid in Regions.ids():
				if Regions.ids().find(rid) % (WAVES - 1) == (_waves_sent - 1):
					var tint := Regions.color(Regions.def(rid).get("color", "#7fd36b"))
					main.flora.spawn_patch(Regions.center(rid), 900.0, 40, tint, 2.0, 900.0)
		_waves_sent += 1
	if active and t >= duration():
		active = false
		t = INF
		if not main.in_boss_fight():
			main.spawn_paused = false


## Apparition (0 à 1) du groupe i.
func group_k(i: int) -> float:
	if t == INF:
		return 1.0
	if t < 0.0:
		return 0.0
	return clampf((t - 1.0 - i * STEP) / GROW, 0.0, 1.0)


## Position du groupe i sur l'anneau : le titre en haut, puis dans le sens des aiguilles d'une montre.
func group_pos(i: int) -> Vector2:
	var n := maxi(groups.size(), 1)
	var ang := -PI / 2.0 + TAU * float(i) / n
	return Vector2.from_angle(ang) * RING * Vector2(1.0, 0.8)


func _draw() -> void:
	if t < 0.0 or groups.is_empty():
		return
	if main != null and is_instance_valid(main) and main.player != null:
		# Loin de la graine, rien à dessiner.
		if main.player.position.length() > RING + 1400.0:
			return
	var font := UiTheme.font()
	var bold := UiTheme.font(true)
	var ink := Art.ec("seve", "clair")
	var head_col := UiTheme.GOLD
	for i in groups.size():
		var k := group_k(i)
		if k <= 0.0:
			continue
		var g: Dictionary = groups[i]
		var at := group_pos(i)
		var lines: Array = g["lines"]
		var y := at.y - (lines.size() * 24.0) / 2.0
		# Les lettres poussent : elles montent du sol et prennent leur couleur.
		var rise := (1.0 - Anim.ease_out(k)) * 10.0
		if g["title"]:
			_text(bold, at + Vector2(0, rise), str(lines[0]), 40, Color(head_col, k))
			continue
		if str(g.get("head", "")) != "":
			_text(font, Vector2(at.x, y - 8.0 + rise), str(g["head"]).to_upper(), 15, Color(head_col, 0.85 * k))
			y += 18.0
		for l in lines:
			y += 24.0
			_text(font, Vector2(at.x, y + rise), str(l), 21, Color(ink, k))


## Texte centré sur « at », avec une ombre de terre pour se lire sur l'herbe.
func _text(font: Font, at: Vector2, s: String, size_px: int, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var o := Vector2(at.x - w / 2.0, at.y)
	draw_string_outline(font, o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 6, Color(0.05, 0.08, 0.04, 0.7 * col.a))
	draw_string(font, o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
