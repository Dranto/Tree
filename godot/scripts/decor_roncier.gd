## Décor du roncier (région de Ronce, « decor » : {"kind": "roncier"} dans data/regions/ronce.json) :
## les arbres du monde y sont remplacés par des ronces mortes et grises qui verdissent et
## fleurissent quand la vie revient, et des buissons d'épines font obstacle.
##
## Une sorte de décor de région est une classe comme celle-ci, rangée dans flora.gd › DECOR (ou
## trouvée par son nom, scripts/decor_<sorte>.gd) :
##   - make_tree(p) : l'arbre qui remplace celui du reste du monde en p (null : l'arbre ordinaire).
##     Ne tire aucun nombre au hasard : le placement des arbres du monde ne change pas ;
##   - spawn() : le décor propre à la région, avec son propre tirage (graine « seed » de la région).
## Budget de dessin (docs/performances.md) : chaque élément est un DecorTree, dessiné en un appel
## par le lot fidèle et redessiné seulement quand il reverdit.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")

var flora
## Identifiant de la région et réglages de son décor (« decor » du fichier de la région).
var region := ""
var cfg: Dictionary = {}


func make_tree(_p: Vector2) -> Node2D:
	return flora.get_script().DecorBramble.new()


## Ronces et buissons d'épines : tirage à part (graine fixe), pour ne pas déplacer les arbres du
## reste du monde. Le centre de la région (Cœur, arène) et l'oasis restent libres d'obstacles.
func spawn() -> void:
	var F = flora.get_script()
	var r := RandomNumberGenerator.new()
	r.seed = int(cfg.get("seed", 8))
	var mid: float = Regions.angle_of(region)
	var half: float = Regions.half_width()
	var h := 2850.0
	var brambles := int(cfg.get("brambles", 130))
	var clear_center := float(cfg.get("clear_center", 340.0))
	var clear_seed := float(cfg.get("clear_seed", 560.0))
	for i in brambles + int(cfg.get("bushes", 46)):
		var bush := i >= brambles
		var a := mid + r.randf_range(-half, half) * 0.97
		var d := sqrt(r.randf_range(pow(Regions.INNER + 30.0, 2), pow(4000.0, 2)))
		var p := Vector2.from_angle(a) * d
		var sz := r.randf_range(0.8, 1.4)
		var sd := r.randi()
		if absf(p.x) > h or absf(p.y) > h or Regions.weight(p, region) < 0.6:
			continue
		if bush and (Regions.near_heart(region, p, clear_center) or p.length() < clear_seed):
			continue
		var t = F.DecorBush.new() if bush else F.DecorBramble.new()
		t.position = p
		t.size = sz
		t.tree_seed = sd
		t.alive = flora.ground.life_at(p) > flora.ALIVE
		if bush:
			t.radius = 20.0 + 12.0 * (sz - 0.8) / 0.6
			flora.add_obstacle(t)
		flora.trees_parent.add_child(t)
		flora._add_tree(t)
