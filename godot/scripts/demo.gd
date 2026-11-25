## Démo Steam (jalon 12 E) : la région de Ronce entière, ses trois Cœurs et son boss, sans limite
## de temps. Le reste du monde est là, mais fermé par une ronce épaisse (demo_wall.gd) ; l'arbre de
## vie reste entier, mais seule la branche de Ronce se lit : le reste est sous la ronce (tree_ui.gd).
## Après la Mère-Ronce, la boucle continue (region_fanfare.gd) ; la brèche au pied de la graine
## reste scellée et pulse : la suite pousse dans le jeu complet.
##
## Indicateur : `Game.is_demo()` (nom convenu au jalon 12) = fonctionnalité d'export « demo »
## (export_presets.cfg) ou argument « -- --demo » (tests). La sauvegarde a le même format que celle
## du jeu complet, qui la reprend telle quelle.
##
## Fonctions statiques sans autoload : un test lancé par « -s » peut précharger ce script.
## Réglages : res://data/demo.json.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const Content = preload("res://scripts/content.gd")

## Tests : 1 force la démo, 0 force le jeu complet, -1 suit l'export et la ligne de commande.
static var forced := -1
## Drapeau posé quand le héros s'est approché du sceau de la graine après la fin de la démo.
const SEAL_SEEN := "demo_sceau_vu"


## Vrai quand le jeu tourne en démo.
static func active() -> bool:
	if forced >= 0:
		return forced == 1
	return OS.has_feature("demo") or "--demo" in OS.get_cmdline_user_args()


static func data() -> Dictionary:
	return Content._load("demo")


static func wall_value(key: String, fallback: float) -> float:
	var w = data().get("wall", {})
	return float(w.get(key, fallback)) if w is Dictionary else fallback


## Régions ouvertes dans la démo (data/demo.json › regions, celles qui existent).
static func regions() -> Array:
	var out: Array = []
	for id in data().get("regions", ["ronce"]):
		if Regions.exists(str(id)):
			out.append(str(id))
	return out


## Vrai si la région est jouable : toujours dans le jeu complet, en démo seulement les siennes.
## "" (l'oasis de la graine) est toujours ouverte.
static func region_open(id: String) -> bool:
	return id == "" or not active() or id in regions()


## Branche de l'arbre ouverte (secteur d'une région de la démo).
static func branch_open(branch: String) -> bool:
	if not active():
		return true
	for id in regions():
		if Regions.branch_of(id) == branch:
			return true
	return false


## Vrai quand toutes les régions de la démo ont leur boss vaincu : la démo est finie (la boucle continue).
static func finished(flags: Dictionary) -> bool:
	if not active():
		return false
	var list := regions()
	if list.is_empty():
		return false
	for id in list:
		if not bool(flags.get(Regions.boss_flag(id), false)):
			return false
	return true


# --- Monde : où le héros peut aller ---

## Secteurs ouverts, regroupés en éventails contigus : chacun [angle de début, angle de fin] (radians,
## sens croissant). Le monde jouable = le disque de l'oasis (rayon Regions.INNER) et ces éventails.
static func open_spans() -> Array:
	var ids: Array = Regions.ids()
	var n := ids.size()
	if n == 0:
		return []
	var h := Regions.half_width()
	var open: Array = []
	for id in ids:
		open.append(region_open(id))
	if not false in open:
		return [[-PI, PI + 0.0001]]
	# On part d'un secteur fermé, puis on suit le tour.
	var start := open.find(false)
	var spans: Array = []
	var cur = null
	for k in range(1, n + 1):
		var i := (start + k) % n
		var a: float = Regions.angle_of(ids[i])
		if open[i]:
			if cur == null:
				cur = [a - h, a + h]
			else:
				var e := a + h
				while e <= float(cur[1]):
					e += TAU
				cur[1] = e
		elif cur != null:
			spans.append(cur)
			cur = null
	if cur != null:
		spans.append(cur)
	return spans


## Pièces de la haie : des segments {seg: [a, b], closed: normale vers le côté fermé} (bords des
## secteurs ouverts, de l'oasis au bout du monde) et des arcs {arc: [début, fin]} sur le cercle de
## l'oasis, devant les secteurs fermés (côté fermé à l'extérieur).
static func wall_pieces() -> Array:
	var spans := open_spans()
	if spans.size() == 1 and spans[0][1] - spans[0][0] >= TAU:
		return []
	var out: Array = []
	var r := Regions.INNER
	for i in spans.size():
		var s: Array = spans[i]
		# Bord de début (le secteur fermé est avant, côté des angles plus petits).
		var a0: float = s[0]
		var a1: float = s[1]
		var u0 := Vector2.from_angle(a0)
		var u1 := Vector2.from_angle(a1)
		out.append({"seg": [u0 * Regions.reach(a0) * 1.04, u0 * r], "closed": u0.orthogonal()})
		out.append({"seg": [u1 * r, u1 * Regions.reach(a1) * 1.04], "closed": -u1.orthogonal()})
		var nxt: Array = spans[(i + 1) % spans.size()]
		var b0: float = nxt[0]
		while b0 <= a1:
			b0 += TAU
		out.append({"arc": [a1, b0]})
	return out


# --- Géométrie d'une pièce : « s » le long de la haie, « d » vers le côté fermé ---

static func piece_length(piece: Dictionary) -> float:
	if piece.has("seg"):
		return (piece["seg"][1] - piece["seg"][0]).length()
	return (float(piece["arc"][1]) - float(piece["arc"][0])) * Regions.INNER


static func wall_at(piece: Dictionary, s: float, d: float) -> Vector2:
	if piece.has("seg"):
		var a: Vector2 = piece["seg"][0]
		var b: Vector2 = piece["seg"][1]
		return a + (b - a).normalized() * s + piece["closed"] * d
	var ang: float = float(piece["arc"][0]) + s / Regions.INNER
	return Vector2.from_angle(ang) * (Regions.INNER + d)


## Vrai si la position (disque de rayon « radius ») est dans le monde jouable.
static func allowed(pos: Vector2, radius := 0.0) -> bool:
	return keep_inside(pos, radius) == pos


## Ramène une position dans le monde jouable de la démo (le point jouable le plus proche, à « radius »
## plus la marge de la haie). Hors démo, ou sans région fermée, la position telle quelle.
static func keep_inside(pos: Vector2, radius := 0.0) -> Vector2:
	if not active():
		return pos
	var spans := open_spans()
	if spans.is_empty() or (spans.size() == 1 and spans[0][1] - spans[0][0] >= TAU):
		return pos
	var m := radius + wall_value("margin", 14.0)
	var disc := maxf(Regions.INNER - m, 1.0)
	var l := pos.length()
	if l <= disc:
		return pos
	var best := pos.normalized() * disc if l > 0.001 else Vector2.ZERO
	var best_d := pos.distance_squared_to(best)
	for s in spans:
		var q := _into_fan(pos, float(s[0]), float(s[1]), m)
		if q == pos:
			return pos
		var d := pos.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best


## Point le plus proche de « p » dans l'éventail [a0, a1] rétréci de « m » de chaque bord (moins d'un
## demi-tour : un cône convexe dont la pointe s'écarte de la graine).
static func _into_fan(p: Vector2, a0: float, a1: float, m: float) -> Vector2:
	var u0 := Vector2.from_angle(a0)
	var u1 := Vector2.from_angle(a1)
	# Normales intérieures (comme Regions.edge_normals).
	var n0 := -u0.orthogonal()
	var n1 := u1.orthogonal()
	if a1 - a0 >= PI:
		# Éventail de plus d'un demi-tour : seuls les deux bords comptent, chacun de son côté.
		if p.dot(n0) >= m or p.dot(n1) >= m:
			return p
	elif p.dot(n0) >= m and p.dot(n1) >= m:
		return p
	# Pointe du cône rétréci : à « m » des deux bords.
	var half := (a1 - a0) * 0.5
	var apex := Vector2.from_angle(a0 + half) * (m / maxf(sin(half), 0.05))
	var best := apex
	var best_d := p.distance_squared_to(apex)
	for u in [u0, u1]:
		var t := maxf(0.0, (p - apex).dot(u))
		var q: Vector2 = apex + u * t
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	return best


# --- Arbre de vie ---

## Vrai si le nœud est hors de portée de la démo : tout nœud qui n'est pas de la branche d'une région
## ouverte (ni d'une frontière qui la touche), et les nœuds flétris que seule une région fermée libère.
## L'arbre reste entier, on voit qu'il existe, mais ces nœuds sont couverts de ronce et illisibles
## (tree_ui.gd : ni libellé, ni effet dans l'infobulle, ni résultat de recherche), et ne s'apprennent pas.
static func node_closed(n: Dictionary) -> bool:
	if not active() or str(n.get("type", "")) == "root":
		return false
	var flag := str(n.get("requires_flag", ""))
	if flag != "":
		var reg := flag.get_slice("_", 0)
		if Regions.exists(reg) and not region_open(reg):
			return true
	var names: Array = Content.tree().get("branches", [])
	var b := int(n.get("branch", -1))
	var border := int(n.get("border", -1))
	var b1 := str(names[b]) if b >= 0 and b < names.size() else ""
	var b2 := str(names[border]) if border >= 0 and border < names.size() else ""
	if b1 == "" and b2 == "":
		return false
	return not (b1 != "" and branch_open(b1)) and not (b2 != "" and branch_open(b2))
