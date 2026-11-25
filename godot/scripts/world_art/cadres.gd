## Cadres de la planche « Paysages d'herbier » (refonte du monde, vague 0, tâche W) : pour chaque région,
## un même endroit du vrai monde vu en 1920×1080, le héros au centre (la caméra le suit), un Cœur, un
## sanctuaire, un autel et un repère tirés de data/regions/<id>.json, et une distribution de personnages
## (positions relatives au héros, en px du jeu 1600×900).
##
## « kind » : sorte de data/enemies.json posée dans le vrai jeu (captures « avant ») ;
## « art » : nouveau dessin (scripts/creature_art/), ou "" pour garder le dessin actuel (fletri_art.gd).
## « pose » : propriétés de enemy.gd (avant) ; la pose du nouveau dessin en est déduite.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")

const CADRES := {
	"ronce": {
		"center": Vector2(1100, -990),
		"heart": 1,
		"sanctuary": "ravin",
		"altar": "ronce_2",
		"landmark": "grand_arbre",
		"cast": [
			{"kind": "tireur", "art": "tireur", "at": Vector2(330, 95), "pose": {"state": "windup", "state_t": 0.25}},
			{"kind": "tireur", "art": "tireur", "at": Vector2(-290, -150), "pose": {"walk": 1.0, "moving": 1.0}},
			{"kind": "scarabee", "art": "scarabee", "at": Vector2(-235, 40), "pose": {"state": "windup", "state_t": 0.3}},
			{"kind": "menhir", "art": "menhir", "at": Vector2(60, -235), "pose": {"walk": 2.0, "moving": 1.0}},
			{"kind": "fletri", "art": "", "at": Vector2(170, 175), "pose": {"walk": 0.6, "moving": 1.0}},
			{"kind": "fletri", "art": "", "at": Vector2(-90, -120), "pose": {"walk": 2.2, "moving": 1.0}},
			{"kind": "cendreux", "art": "", "at": Vector2(250, -40), "pose": {"walk": 1.4, "moving": 1.0}},
		],
	},
	"spore": {
		"center": Vector2(1450, -430),
		"heart": 0,
		"sanctuary": "roseliere",
		"altar": "spore_2",
		"landmark": "rocher",
		"repere_at": Vector2(-640, 60),
		"cast": [
			{"kind": "tireur", "art": "tireur", "at": Vector2(300, 150), "pose": {"state": "windup", "state_t": 0.25}},
			{"kind": "scarabee", "art": "scarabee", "at": Vector2(-260, 150), "pose": {"state": "windup", "state_t": 0.3}},
			{"kind": "menhir", "art": "menhir", "at": Vector2(40, 185), "pose": {"walk": 2.0, "moving": 1.0}},
			{"kind": "traine_vase", "art": "", "at": Vector2(170, -10), "pose": {"walk": 0.6, "moving": 1.0}},
			{"kind": "scissipore", "art": "", "at": Vector2(-120, -40), "pose": {"walk": 2.2, "moving": 1.0}},
			{"kind": "lichen", "art": "", "at": Vector2(400, -60), "pose": {"walk": 1.4, "moving": 1.0}},
			{"kind": "scissipore", "art": "", "at": Vector2(-420, -200), "pose": {"walk": 0.3, "moving": 1.0}},
		],
	},
}


## Cadre complet d'une région : positions monde du Cœur (avec son rayon de vie), du sanctuaire, de
## l'autel et du repère, ajoutées au dictionnaire de CADRES.
static func get_cadre(region: String) -> Dictionary:
	var c: Dictionary = CADRES[region].duplicate(true)
	c["region"] = region
	var spot: Dictionary = Regions.heart_spots(region)[c["heart"]]
	c["heart_pos"] = spot["pos"]
	c["heart_size"] = spot["size"]
	c["life_radius"] = spot["life_radius"]
	c["zone"] = spot["zone"]
	var d := Regions.def(region)
	for s in d.get("sanctuaries", []):
		if s["id"] == c["sanctuary"]:
			c["sanctuary_pos"] = Regions.place(region, s)
	for s in d.get("altars", []):
		if s["id"] == c["altar"]:
			c["altar_pos"] = Regions.place(region, s)
	for s in d.get("landmarks", []):
		if s["kind"] == c["landmark"]:
			c["landmark_pos"] = Regions.place(region, s)
	return c
