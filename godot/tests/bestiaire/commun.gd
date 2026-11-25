## Outils communs des planches du « Bestiaire d'herbier » (vague 0) : sol d'une région, dessin « avant »
## (fletri_art.gd, hero_art.gd, tels qu'en jeu) et « après » (scripts/creature_art/) d'un personnage.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const FletriArt = preload("res://scripts/fletri_art.gd")
const Regions = preload("res://scripts/regions.gd")
const Tireur = preload("res://scripts/creature_art/ronce/tireur.gd")
const Scarabee = preload("res://scripts/creature_art/racine/scarabee.gd")
const Menhir = preload("res://scripts/creature_art/vent/menhir.gd")
const Esprit = preload("res://scripts/creature_art/heros/esprit.gd")

## Échelle du jeu en 1080p (projet en 1600×900, étiré).
const S1080 := 1080.0 / 900.0

## Personnages de la planche : sorte de enemies.json (ou héros), région, rôle, nouveau dessin.
const CAST := [
	{"id": "tireur", "nom": "Tireur d'épines", "region": "ronce", "role": "tireur", "r": 13.0},
	{"id": "scarabee", "nom": "Scarabée perce-écorce", "region": "racine", "role": "chargeur", "r": 16.0},
	{"id": "menhir", "nom": "Menhir flétri", "region": "vent", "role": "lourd", "r": 24.0},
	{"id": "heros", "nom": "Porte-Graine", "region": "ronce", "role": "héros", "r": 14.0},
]


static func art_of(id: String):
	match id:
		"tireur":
			return Tireur
		"scarabee":
			return Scarabee
		"menhir":
			return Menhir
	return Esprit


## Couleurs du sol mort d'une région (data/regions/<id>.json › ground).
static func ground_colors(region: String) -> Array:
	var g: Dictionary = Regions.def(region)["ground"]
	var named := Regions.named_colors(g)
	return [Regions.color(g["dead_dark"], named), Regions.color(g["dead_light"], named), Regions.color(g.get("dot", "sol_mort"), named)]


## Sol d'une région dans rect : fond clair, taches sombres, quelques cailloux et points (graine fixe).
static func draw_ground(ci: CanvasItem, rect: Rect2, region: String, seed := 7) -> void:
	var cols := ground_colors(region)
	ci.draw_rect(rect, cols[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := int(rect.get_area() / 900.0)
	for i in n:
		var p := rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		var rr := rng.randf_range(6.0, 26.0)
		ci.draw_colored_polygon(Art.ellipse(p, rr * 1.6, rr * 0.7, 16), Color(cols[0], 0.35))
	for i in n / 3:
		var p := rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		ci.draw_circle(p, rng.randf_range(1.0, 2.2), Color(cols[0].darkened(0.3), 0.6))
	for i in n / 6:
		var p := rect.position + Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		ci.draw_circle(p, 1.4, Color(cols[2], 0.5))


## Dessin d'avant (tel qu'en jeu), centré en pos, à l'échelle s (1 : px du jeu en 1600×900).
## o : pose de fletri_art.gd ; face : regard.
static func draw_before(ci: CanvasItem, id: String, r: float, pos: Vector2, s: float, o := {}, face := Vector2(1, 0.3).normalized()) -> void:
	if id == "heros":
		HeroArt.base = Transform2D(0.0, Vector2(s, s), 0.0, pos)
		HeroArt.draw(ci, Vector2.ZERO, r, face.angle(), o)
		HeroArt.base = Transform2D.IDENTITY
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	ci.draw_set_transform(pos, 0.0, Vector2(s, s))
	if not o.get("mono", false):
		ci.draw_colored_polygon(Art.ellipse(Vector2(0, r * Art.OMBRE_DECALAGE * 0.5), r * 1.05, r * 0.75, 14), Art.c("ombre"))
	FletriArt.draw(ci, id, Vector2.ZERO, r, face, o.get("t", 0.5), o)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Nouveau dessin, pieds en feet, à l'échelle s (1 : px du jeu). o : pose de creature_art/.
static func draw_after(ci: CanvasItem, id: String, feet: Vector2, s: float, o := {}) -> void:
	var art = art_of(id)
	art.draw(ci, feet, art.HEIGHT * s, o)
	Ink.flash = 0.0
