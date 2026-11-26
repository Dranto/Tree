## Planche des Cœurs et des arènes (tâche C du jalon 8) : une bande par région du monde, dessinée par
## les dessins de la région (champ « art » de data/regions/<id>.json, scripts/region_art/<art>.gd ;
## region_art.gd par défaut). Une région ajoutée par ses fichiers y apparaît d'elle-même (il faut alors
## refaire les références : tools/visual-tests.sh --update).
## Chaque bande montre le Cœur flétri, assiégé (à mi-chemin) puis purifié, et un morceau de l'arène du
## boss fermée, ouverte (la brèche du côté du Cœur), pendant le combat puis une fois le boss vaincu.
## Ce sont les vrais nœuds du jeu (heart.gd, boss_arena.gd), figés à un instant précis, hors de la scène.
## Capturée par le banc visuel (scénario « regions », capture « galerie_coeurs »).
extends Node2D

const Heart = preload("res://scripts/heart.gd")
const BossArena = preload("res://scripts/boss_arena.gd")
const Regions = preload("res://scripts/regions.gd")
const RegionUi = preload("res://scripts/region_ui.gd")

var view := Vector2(1600, 900)
var _bands: Array = []
var _labels: Array = []
## Nœuds du jeu qu'on fait dessiner (jamais posés dans la scène) : libérés à la sortie.
var _owned: Array = []

const HEART_STATES := [["flétri", "fletri", 0.0], ["assiégé", "siege", 0.5], ["purifié", "purifie", 1.0]]
const ARENA_STATES := [["fermée", "fermee", 0.0], ["ouverte", "ouverte", 1.0], ["combat", "combat", 0.0], ["boss vaincu", "vaincue", 1.0]]


## Un Cœur ou une arène dessinés à un endroit de la planche, à une échelle.
class Tile extends Node2D:
	var heart
	var arena
	var art: GDScript

	func _draw() -> void:
		if heart != null:
			heart.draw_body(self)
		elif arena != null:
			art.draw_arena_floor(self, arena)
			art.draw_arena_wall(self, arena)


func _ready() -> void:
	var ids: Array = Regions.ids()
	if ids.is_empty():
		return
	var band_h := minf(280.0, (view.y - 50.0) / ids.size())
	var k := band_h / 280.0
	for i in ids.size():
		var id: String = ids[i]
		var y0 := 50.0 + i * band_h
		_bands.append({"id": id, "y": y0, "h": band_h})
		var art_name := str(Regions.def(id).get("art", ""))
		_labels.append([Vector2(24, y0 + 24), "%s · %s · dessins : %s" % [RegionUi.full_name(id), Regions.section(id, "heart").get("name", "Cœur"), art_name if art_name != "" else "roncier (défaut)"], 16])
		for j in HEART_STATES.size():
			var h = Heart.new()
			_owned.append(h)
			h.configure(id)
			h.state = HEART_STATES[j][1]
			h.progress = h.hold_time * HEART_STATES[j][2]
			h.t = 1.3
			var tile := Tile.new()
			tile.heart = h
			tile.position = Vector2(110 + j * 170, y0 + 190 * k)
			tile.scale = Vector2(k, k) * 0.85
			add_child(tile)
			_labels.append([Vector2(tile.position.x - 34, y0 + 262 * k), HEART_STATES[j][0], 12])
		for j in ARENA_STATES.size():
			_arena_tile(id, j, y0, k)


## L'arène du boss dans un état, vue en entier (son mur, son sol).
func _arena_tile(id: String, j: int, y0: float, k: float) -> void:
	var heart = Heart.new()
	var a = BossArena.new()
	_owned.append(heart)
	_owned.append(a)
	a.region = id
	a.heart = heart
	a.configure(id)
	var shape := RandomNumberGenerator.new()
	shape.seed = 97
	for i in 72:
		a._wall.append([shape.randf_range(-0.03, 0.03), shape.randf_range(0.7, 1.3), shape.randf_range(-1.0, 1.0)])
	a.state = ARENA_STATES[j][1]
	a.gap_open = ARENA_STATES[j][2]
	a.t = 1.3
	# L'arène entière, le Cœur au-dessus : la brèche s'ouvre vers le haut.
	var tile := Tile.new()
	tile.arena = a
	tile.art = Regions.art(id)
	tile.position = Vector2(660 + j * 245, y0 + 145 * k)
	tile.scale = Vector2(k, k) * 0.25
	a.center = Vector2.ZERO
	heart.center = Vector2(0, -1000)
	add_child(tile)
	_labels.append([Vector2(tile.position.x - 40, y0 + 262 * k), ARENA_STATES[j][0], 12])


func _exit_tree() -> void:
	for n in _owned:
		if is_instance_valid(n):
			n.free()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.1, 0.12, 0.1))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(24, 30), "Cœurs de flétrissure (flétri, assiégé, purifié) et murs des arènes, région par région", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	for b in _bands:
		draw_rect(Rect2(14, b["y"] + 4, view.x - 28, b["h"] - 8), Color(RegionUi.tint(b["id"]), 0.1))
	for l in _labels:
		draw_string(font, l[0], l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, l[2], Color(1, 1, 1, 0.85))
