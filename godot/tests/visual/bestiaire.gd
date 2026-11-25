## Planche du banc de lisibilité (scénario visuel « bestiaire », capture bestiaire.png) : toutes les sortes de
## Flétris, une ligne par région, chacune sur le sol de sa région, au nouveau dessin (scripts/creature_art/) :
## en grand à gauche, à la taille réelle d'un écran 1080p à droite avec le Porte-Graine pour l'échelle. Une sorte
## sans script garde son ancien dessin (taille réelle seulement) et le dit. Dernière ligne : les élites
## (+15 % et liseré doré), une par région.
## Tout est posé (pas d'horloge) : la capture est la même à chaque lancement.
extends Node2D

const Sortes = preload("res://tests/bestiaire/sortes.gd")
const C = preload("res://tests/bestiaire/commun.gd")
const Esprit = preload("res://scripts/creature_art/heros/esprit.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")

var view := Vector2(2560, 1440)
var font: Font

const TOP := 62.0
const LEFT := 112.0
const COLS := 6
## Agrandissement de la colonne « en grand » : 1,35 × la taille à l'écran en 1080p.
const BIG := 1.35 * Sortes.S1080
## Part des élites en plus (data : élite = +15 %).
const ELITE := 1.15


func _ready() -> void:
	font = ThemeDB.fallback_font
	var kinds := Sortes.kinds()
	var rows := Sortes.REGIONS.size() + 1
	var rh := (view.y - TOP - 8.0) / rows
	var elites := []
	for r in Sortes.REGIONS.size():
		var region: String = Sortes.REGIONS[r]
		var y := TOP + r * rh
		var mine := []
		for k in kinds:
			if k["region"] == region:
				mine.append(k)
		var cw := (view.x - LEFT - 12.0) / COLS
		for i in mine.size():
			var k: Dictionary = mine[i]
			_cell(Rect2(LEFT + i * cw, y, cw - 6.0, rh - 6.0), k, 31 + r * 7 + i)
			if k["script"] != null and not _has_region(elites, region):
				elites.append(k)
	var y := TOP + Sortes.REGIONS.size() * rh
	var ew := (view.x - LEFT - 12.0) / maxf(elites.size(), 1.0)
	for i in elites.size():
		_cell(Rect2(LEFT + i * ew, y, ew - 6.0, rh - 6.0), elites[i], 91 + i, true)
	_elites = elites.size()


var _elites := 0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Art.c("papier_sombre"))
	_text(self, Vector2(24, 34), "Bestiaire d'herbier · banc de lisibilité", 28, Art.c("or"))
	_text(self, Vector2(560, 34), "à gauche : en grand (×1,35 la taille à l'écran en 1080p) · à droite : taille réelle 1080p, le Porte-Graine pour l'échelle · « ancien dessin » : pas encore redessinée", 18, Art.c("texte_doux"))
	var rows := Sortes.REGIONS.size() + 1
	var rh := (view.y - TOP - 8.0) / rows
	for r in Sortes.REGIONS.size():
		_text(self, Vector2(14, TOP + r * rh + rh * 0.5 + 6), Sortes.REGIONS[r].capitalize(), 22, Art.c("texte"))
	var y := TOP + Sortes.REGIONS.size() * rh
	_text(self, Vector2(14, y + rh * 0.5 + 6), "Élites", 22, Art.c("texte"))
	if _elites == 0:
		_text(self, Vector2(LEFT, y + rh * 0.5 + 6), "aucune sorte redessinée pour l'instant", 18, Art.c("texte_doux"))


static func _has_region(list: Array, region: String) -> bool:
	for k in list:
		if k["region"] == region:
			return true
	return false


## Une case (un Control qui coupe ce qui déborde) : sol de la région, nom, le dessin en grand et à la taille
## réelle avec le héros.
func _cell(rect: Rect2, k: Dictionary, seed: int, elite := false) -> void:
	var cell := Control.new()
	cell.position = rect.position
	cell.size = rect.size
	cell.clip_contents = true
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.draw.connect(func(): _paint_cell(cell, Rect2(Vector2.ZERO, rect.size), k, seed, elite))
	add_child(cell)


func _paint_cell(ci: CanvasItem, rect: Rect2, k: Dictionary, seed: int, elite: bool) -> void:
	C.draw_ground(ci, rect, Sortes.ground_region(k["region"]), seed)
	var label := "%s · %s%s" % [k["nom"], k["role"], " · élite" if elite else ""]
	var sw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	ci.draw_rect(Rect2(Vector2(4, 3), Vector2(sw + 10, 20)), Color(Art.c("papier_sombre"), 0.7))
	_text(ci, Vector2(9, 18), label, 15, Art.c("texte"))
	var feet_y := rect.end.y - 14.0
	var k_s := ELITE if elite else 1.0
	if k["script"] == null:
		# Ancien dessin, à la taille réelle : de quoi voir ce qui reste à faire.
		var p := Vector2(rect.size.x * 0.45, feet_y - k["r"] * Sortes.S1080 * 0.9)
		C.draw_before(ci, k["id"], k["r"], p, Sortes.S1080, {"t": 0.5}, Vector2(-1, 0.3).normalized())
		_hero(ci, Vector2(rect.size.x * 0.72, feet_y))
		_text(ci, Vector2(9, rect.size.y - 8), "ancien dessin", 15, Art.c("texte_doux"))
		return
	var script = k["script"]
	var extra := {"elite": true, "region": k["region"]} if elite else {}
	var big := Vector2(rect.size.x * 0.25, feet_y)
	if elite:
		_ring(ci, big, script, BIG * k_s)
	Sortes.paint(ci, script, big, BIG * k_s, Sortes.REPOS.merged(extra))
	var real := Vector2(rect.size.x * 0.64, feet_y)
	if elite:
		_ring(ci, real, script, Sortes.S1080 * k_s)
	Sortes.paint(ci, script, real, Sortes.S1080 * k_s, Sortes.pose("repos", 0.0, 0.4, PI - 0.25).merged(extra))
	_hero(ci, Vector2(rect.size.x * 0.86, feet_y))


## Le Porte-Graine à la taille réelle (échelle).
func _hero(ci: CanvasItem, feet: Vector2) -> void:
	C.draw_after(ci, "heros", feet, Sortes.S1080, {"t": 0.4, "look": PI - 0.1, "build": "ronce"})


## Liseré doré de l'élite : un anneau au sol (le collier de la région est dessiné par le moteur).
func _ring(ci: CanvasItem, feet: Vector2, script, s: float) -> void:
	var w: float = script.HEIGHT * s * 0.4
	ci.draw_polyline(Art.ellipse(feet + Vector2(0, 2), w, w * Art.OMBRE_APLATI * 1.3, 28), Art.c("or"), 2.0)


func _text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color) -> void:
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
