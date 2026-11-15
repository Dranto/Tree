## Régions du monde : chaque branche de l'arbre a son secteur, dans la même direction que
## dans l'Arbre de vie, au-delà de l'oasis de départ. Seule la région de Ronce existe pour
## l'instant (jalon 3) ; les cinq autres branches s'ajouteront à REGIONS.
##
## Logique pure (aucun nœud) : utilisée par main.gd (region_at, region_center, apparitions),
## ground.gd (teinte du sol) et flora.gd (décor du roncier).
extends RefCounted

const Content = preload("res://scripts/content.gd")

## Branches qui ont déjà leur région.
const REGIONS := ["ronce"]
## Distance à la graine où commence une région (l'oasis de départ fait 260 px de rayon).
const INNER := 430.0
## Distance du centre d'une région (là où D place le Cœur de flétrissure).
const CENTER_DIST := 1650.0
## Largeur du fondu entre une région et le reste du monde (en pixels, de part et d'autre du bord).
const EDGE := 110.0


## Angle (radians) du milieu du secteur de la branche, comme dans skill_tree.gd.
static func angle_of(id: String) -> float:
	var ids: Array = Content.tree().get("branches", [])
	var bi := ids.find(id)
	if bi < 0:
		return 0.0
	var sector := TAU / ids.size()
	return bi * sector - PI / 2.0 + sector / 2.0


## Demi-ouverture d'un secteur (radians).
static func half_width() -> float:
	return PI / maxf(1.0, Content.tree().get("branches", []).size())


## Distance (en pixels, positive à l'intérieur) entre une position et le bord de la région.
static func inside_distance(pos: Vector2, id: String) -> float:
	var d := pos.length()
	var ad := absf(angle_difference(angle_of(id), pos.angle()))
	var side := (half_width() - ad) * d
	return minf(side, d - INNER)


static func region_at(pos: Vector2) -> String:
	for id in REGIONS:
		if inside_distance(pos, id) > 0.0:
			return id
	return ""


static func center(id: String) -> Vector2:
	return Vector2.from_angle(angle_of(id)) * CENTER_DIST


## Appartenance progressive (0 dehors, 1 bien à l'intérieur) : sert au fondu du décor.
static func weight(pos: Vector2, id: String) -> float:
	return smoothstep(-EDGE, EDGE, inside_distance(pos, id))
