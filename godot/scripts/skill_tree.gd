## Génération procédurale (déterministe) de l'Arbre de vie.
## Six branches partent de la graine centrale sur 12 anneaux : environ 600 nœuds.
## La position d'un nœud dans l'arbre correspond à une région du monde :
## l'apprendre ravive cette région.
## Le générateur ne décide que de la forme de l'arbre. Ce que font les nœuds (statistiques,
## nœuds clés, compétences) est décrit dans res://data/ : voir res://data/README.md.
##
## Une branche peut aussi déclarer des grappes écrites à la main (« clusters ») : elles sont
## insérées après la génération, à l'anneau et à l'angle indiqués. Les petits nœuds générés qui
## les gênent sont écartés, et l'arbre est recousu pour que tout reste relié à la graine.
## L'insertion ne consomme aucun tirage du générateur : le reste de l'arbre ne bouge pas.
##
## Frontières hybrides (res://data/borders/) : des grappes à cheval sur la limite de deux branches
## voisines. Chaque nœud d'une frontière appartient au secteur où il tombe (« branch ») et porte
## l'autre branche dans « border » ; il compte pour la résonance des deux branches.
extends RefCounted

const RINGS := 12
const RING_GAP := 110.0
const SEED := 20261109

## Types de nœuds qu'une grappe peut contenir.
## « attack » : nœud qui change la forme ou le comportement de l'attaque de base (attack.gd).
const CLUSTER_TYPES := ["small", "notable", "keystone", "skill", "mutation", "mastery", "graft", "withered", "attack"]
## Nom par défaut d'un nœud de grappe sans « name ».
const DEFAULT_NAME := {"graft": "Emplacement de greffe", "withered": "Nœud flétri", "mastery": "Maîtrise", "small": "Nœud", "attack": "Attaque"}
## Distances de dégagement autour d'une grappe, en unités d'anneau : un nœud généré plus proche
## que CLEAR_NODE d'un nœud de grappe (ou que CLEAR_LINK d'un de ses liens) est écarté ; un lien
## généré qui passe à moins de CLEAR_EDGE d'un nœud de grappe est retiré.
const CLEAR_NODE := 0.62
const CLEAR_LINK := 0.36
const CLEAR_EDGE := 0.34
## Écartement des grappes (dessin seulement) : rayon de dessin de chaque type de nœud, et marge
## voulue entre deux nœuds de grappe (place des anneaux d'invitation et des halos). Une grappe trop
## serrée est agrandie autour de son point d'ancrage, sans jamais approcher un nœud généré à moins
## de CLEAR_NODE ; les liens, les identifiants et les anneaux ne changent pas.
const SPREAD_RADIUS := {
	"small": 11.0, "notable": 18.0, "keystone": 30.0, "skill": 25.0, "mutation": 25.0,
	"mastery": 19.0, "graft": 18.0, "withered": 19.0, "attack": 22.0,
}
const SPREAD_GAP := 30.0
const SPREAD_MAX := 1.5

const Content = preload("res://scripts/content.gd")
const Effects = preload("res://scripts/effects.gd")

## Branches, lues dans res://data/branches/ (une par fichier, dans l'ordre de tree.json).
static var BRANCHES: Array = Content.branches()
## Frontières hybrides entre deux branches voisines, lues dans res://data/borders/.
static var BORDERS: Array = Content.borders()
## Part de la couleur de l'autre branche dans un nœud de frontière (0 : sa branche seule).
const BORDER_MIX := 0.3

var nodes: Array = []
var edges: Array = []  # Vector2i(a, b)
## Identifiant stable (uid) -> index dans nodes. Les sauvegardes utilisent les uid,
## qui ne changent pas si l'ordre de génération des nœuds évolue.
var by_uid: Dictionary = {}
## Grappes insérées : "<branche>:<grappe>" (ou "<frontière>:<grappe>") -> {"name", "branch", "border",
## "nodes": [index], "effects": bonus de grappe complète}. « border » vaut -1 hors des frontières.
var clusters: Dictionary = {}
## Compétence -> index des nœuds qui la donnent (pour savoir si une mutation est disponible).
var skill_sources: Dictionary = {}
## Index d'un nœud -> index des nœuds qui s'excluent avec lui (relation symétrique).
var exclusions: Dictionary = {}


func branch_color(bi: int) -> Color:
	if bi < 0:
		return Color("f0e6b4")
	return Color(BRANCHES[bi]["color"])


## Couleur d'un nœud : celle de sa branche ; un nœud de frontière y mêle un peu de l'autre branche.
func node_color(n: Dictionary) -> Color:
	var col := branch_color(n["branch"])
	if int(n.get("border", -1)) >= 0:
		col = col.lerp(branch_color(n["border"]), BORDER_MIX)
	return col


## Vrai si le nœud compte pour la branche bi (sa branche, ou l'autre branche d'un nœud de frontière).
static func in_branch(n: Dictionary, bi: int) -> bool:
	return bi >= 0 and (n["branch"] == bi or int(n.get("border", -1)) == bi)


## Direction (vecteur unitaire, dans le sens des aiguilles d'une montre) qui va de la branche « branch »
## vers la branche « border » au point p : sert à dessiner les deux couleurs d'un nœud de frontière.
static func border_dir(n: Dictionary) -> Vector2:
	var p: Vector2 = n["pos"]
	var side := Vector2(-p.y, p.x).normalized()
	var a: int = n["branch"]
	var b: int = int(n.get("border", -1))
	if b < 0:
		return side
	var count := BRANCHES.size()
	return side if (a + 1) % count == b else -side


func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	nodes = []
	edges = []
	by_uid = {}
	clusters = {}
	skill_sources = {}
	exclusions = {}
	var edge_set := {}
	var root: Dictionary = Content.tree().get("root", {})
	nodes.append(_make(0, 0, -1, "root", Vector2.ZERO, root.get("name", ""), "", root.get("desc", ""), root.get("effects", [])))

	var sector := TAU / BRANCHES.size()
	var rows: Array = []
	for bi in BRANCHES.size():
		rows.append([[0]])
	var name_idx := {}

	for r in range(1, RINGS + 1):
		var count := int(ceil(1.2 * r))
		for bi in BRANCHES.size():
			var b: Dictionary = BRANCHES[bi]
			var bid: String = b["id"]
			var row: Array = []
			var start := bi * sector - PI / 2.0
			var mid := int((count - 1) / 2.0)
			for i in count:
				var t := (i + 0.5) / float(count)
				var ja := (rng.randf() - 0.5) * (sector / count) * 0.35
				var ang := start + t * sector + ja
				var rad := r * RING_GAP + (rng.randf() - 0.5) * RING_GAP * 0.3
				var kind := "small"
				var key := ""
				var nm := ""
				var desc := ""
				var effects: Array = []
				if i == mid and r % 4 == 0:
					kind = "keystone"
					var ks: Dictionary = b["keystones"][int(r / 4.0) - 1]
					key = ks["key"]
					nm = ks["name"]
					desc = ks.get("desc", "")
					effects = ks.get("effects", [])
				elif r % 3 == 0 and i != 0 and i != count - 1 and (i + r) % 4 == 0:
					kind = "notable"
				elif r >= 2 and rng.randf() < 0.05:
					kind = "notable"
				if kind == "notable":
					var words: Array = b["notable"]["names"]
					name_idx[bid] = int(name_idx.get(bid, 0)) + 1
					var k: int = name_idx[bid]
					nm = "%s %s" % [words[0][k % words[0].size()], words[1][int(k / float(words[0].size())) % words[1].size()]]
					effects = _effects(b, r, true, i)
				elif kind == "small":
					effects = _effects(b, r, false, i)
					nm = Content.stats()[effects[0]["stat"]]["label"]
				var id := nodes.size()
				var node := _make(id, r, bi, kind, Vector2.from_angle(ang) * rad, nm, key, desc, effects)
				node["uid"] = "key:" + key if key != "" else "%s:%d:%d" % [bid, r, i]
				nodes.append(node)
				row.append(id)
			rows[bi].append(row)

			# Liens vers l'anneau précédent : le parent le plus proche, parfois un second.
			var prev: Array = rows[bi][r - 1]
			for id in row:
				var p: Vector2 = nodes[id]["pos"]
				var sorted: Array = []
				for q in prev:
					sorted.append([p.distance_squared_to(nodes[q]["pos"]), q])
				sorted.sort_custom(func(x, y): return x[0] < y[0])
				_link(id, sorted[0][1], edge_set)
				if sorted.size() > 1 and rng.randf() < 0.22:
					_link(id, sorted[1][1], edge_set)
			# Liens latéraux dans le même anneau.
			for i in range(row.size() - 1):
				if rng.randf() < 0.2:
					_link(row[i], row[i + 1], edge_set)
		# Ponts entre branches voisines.
		if r % 4 == 2:
			for bi in BRANCHES.size():
				var a: Array = rows[bi][r]
				var c: Array = rows[(bi + 1) % BRANCHES.size()][r]
				_link(a[a.size() - 1], c[0], edge_set)
	_insert_clusters()
	for n in nodes:
		by_uid[n["uid"]] = n["id"]
	_index_rules()


# --- Grappes écrites à la main ---

## Position de chaque nœud d'une grappe (identifiant local -> position dans l'arbre).
## Le point d'ancrage est à l'anneau « ring », à la fraction « angle » du secteur de la branche
## (0 = bord gauche, 1 = bord droit ; peut dépasser pour une grappe frontière). « at » est en unités
## d'anneau : x vers l'extérieur de l'arbre, y le long de l'anneau (sens des aiguilles d'une montre).
static func cluster_layout(bi: int, c: Dictionary) -> Dictionary:
	return _layout(bi, float(c.get("angle", 0.5)), c)


## Position des nœuds d'une grappe de frontière : « angle » est l'écart à la limite entre les
## branches a et b (fraction de secteur, négatif du côté de a), y > 0 va vers b.
static func border_layout(a: int, c: Dictionary) -> Dictionary:
	return _layout(a, 1.0 + float(c.get("angle", 0.0)), c)


static func _layout(bi: int, angle: float, c: Dictionary) -> Dictionary:
	var sector := TAU / BRANCHES.size()
	var out := Vector2.from_angle(bi * sector - PI / 2.0 + angle * sector)
	var side := Vector2(-out.y, out.x)
	var anchor := out * float(c.get("ring", 1)) * RING_GAP
	var pos := {}
	for cn in c.get("nodes", []):
		if not cn is Dictionary:
			continue
		var at = cn.get("at", [0, 0])
		var x := 0.0
		var y := 0.0
		if at is Array and at.size() == 2:
			x = float(at[0])
			y = float(at[1])
		pos[str(cn.get("id", ""))] = anchor + (out * x + side * y) * RING_GAP
	return pos


func _insert_clusters() -> void:
	var specs: Array = []
	var pts: Array = []
	var segs: Array = []
	for bi in BRANCHES.size():
		var list = BRANCHES[bi].get("clusters", [])
		if not list is Array:
			continue
		for c in list:
			if not (c is Dictionary and c.get("nodes") is Array):
				continue
			specs.append({"bi": bi, "border": -1, "file": BRANCHES[bi]["id"], "c": c, "pos": cluster_layout(bi, c)})
	for bd in BORDERS:
		var list = bd.get("clusters", [])
		if not list is Array:
			continue
		for c in list:
			if not (c is Dictionary and c.get("nodes") is Array):
				continue
			specs.append({"bi": bd["a"], "border": bd["b"], "file": str(bd["id"]), "c": c, "pos": border_layout(bd["a"], c)})
	# Points et liens des grappes ; ceux des frontières sont aussi gardés à part (voir « ghosts »).
	var border_pts: Array = []
	var border_segs: Array = []
	for s in specs:
		var pos: Dictionary = s["pos"]
		for cn in s["c"]["nodes"]:
			if not cn is Dictionary:
				continue
			var p: Vector2 = pos[str(cn.get("id", ""))]
			pts.append(p)
			if s["border"] >= 0:
				border_pts.append(p)
			for l in _list(cn.get("links")):
				if pos.has(str(l)):
					segs.append([p, pos[str(l)]])
					if s["border"] >= 0:
						border_segs.append([p, pos[str(l)]])
	if specs.is_empty():
		return

	# 1. Les petits nœuds et notables générés qui gênent sont écartés (jamais la graine ni un nœud clé).
	# Un nœud écarté par une frontière seulement reste un « fantôme » qui gêne encore l'écartement
	# des grappes de branche : poser une frontière ne déforme pas les grappes voisines.
	var remove := {}
	var ghosts: Array = []
	var branch_pts: Array = pts.filter(func(q): return not q in border_pts)
	var branch_segs: Array = segs.filter(func(sg): return not sg in border_segs)
	for n in nodes:
		if n["type"] != "small" and n["type"] != "notable":
			continue
		var p: Vector2 = n["pos"]
		if _blocks(p, pts, segs):
			remove[n["id"]] = true
			if not border_pts.is_empty() and not _blocks(p, branch_pts, branch_segs):
				ghosts.append(p)

	# 2. Renumérotation des nœuds gardés ; les liens qui traversent une grappe sont retirés.
	var old_nodes := nodes
	var old_edges := edges
	var remap := {}
	nodes = []
	for n in old_nodes:
		if remove.has(n["id"]):
			continue
		remap[n["id"]] = nodes.size()
		n["id"] = nodes.size()
		n["neighbors"] = []
		nodes.append(n)
	edges = []
	var edge_set := {}
	for e in old_edges:
		if remap.has(e.x) and remap.has(e.y):
			var a: int = remap[e.x]
			var b: int = remap[e.y]
			if not _crosses(nodes[a]["pos"], nodes[b]["pos"], pts):
				_link(a, b, edge_set)
	var generated := nodes.size()

	# 3. Nœuds et liens des grappes, puis rattachement des entrées aux nœuds générés voisins.
	var spread: Array = []
	# Nœuds de frontière sans « side » : leur branche est relue après l'écartement (secteur où ils tombent).
	var free_side := {}
	var stitched := false
	for s in specs:
		# Les grappes de branche sont recousues avant d'ajouter les frontières : une frontière ne
		# change pas les liens que l'arbre aurait sans elle (les chemins d'une branche restent les mêmes).
		if s["border"] >= 0 and not stitched:
			stitched = true
			_reconnect(edge_set, pts)
		var c: Dictionary = s["c"]
		var bi: int = s["bi"]
		var other: int = s["border"]
		var key := "%s:%s" % [s["file"], c.get("id", "")]
		var ids := {}
		for cn in c["nodes"]:
			if not cn is Dictionary or str(cn.get("id", "")) == "" or ids.has(str(cn["id"])):
				continue
			var p: Vector2 = s["pos"][str(cn["id"])]
			if other >= 0 and str(cn.get("side", "")) == "":
				free_side[nodes.size()] = [bi, other]
			var side := bi
			if other >= 0:
				side = _border_side(bi, other, cn, p)
			var node := _cluster_node(nodes.size(), side, key, cn, p)
			if other >= 0:
				node["border"] = bi if side == other else other
			nodes.append(node)
			ids[str(cn["id"])] = node["id"]
		for cn in c["nodes"]:
			if not cn is Dictionary or not ids.has(str(cn.get("id", ""))):
				continue
			for l in _list(cn.get("links")):
				if ids.has(str(l)):
					_link(ids[str(cn["id"])], ids[str(l)], edge_set)
		for entry in _list(c.get("entry")):
			if ids.has(str(entry)):
				_link_entry(ids[str(entry)], generated, edge_set)
		var complete = c.get("complete", {})
		var probe := {"ring": c.get("ring", 1), "angle": c.get("angle", 0.0 if other >= 0 else 0.5), "nodes": [{"id": "_", "at": [0, 0]}]}
		var anchor := border_layout(bi, probe) if other >= 0 else cluster_layout(bi, probe)
		spread.append([ids.values(), anchor["_"]])
		clusters[key] = {
			"name": str(c.get("name", "")), "branch": bi, "border": other, "nodes": ids.values(),
			"effects": _list(complete.get("effects")) if complete is Dictionary else [],
		}

	# 4. Tout ce qui n'est plus relié à la graine est recousu au plus proche.
	_reconnect(edge_set, pts)
	# 5. Les grappes trop serrées sont desserrées (positions seulement).
	_spread_clusters(spread, generated, ghosts)
	for id in free_side:
		var pair: Array = free_side[id]
		var side := _border_side(pair[0], pair[1], {}, nodes[id]["pos"])
		nodes[id]["branch"] = side
		nodes[id]["border"] = pair[1] if side == pair[0] else pair[0]


## Desserre les grappes : chaque grappe trop serrée est agrandie autour de son point d'ancrage
## (au plus SPREAD_MAX), puis les nœuds de grappe encore trop proches s'écartent l'un de l'autre.
## Un nœud de grappe ne s'approche jamais d'un nœud généré à moins de CLEAR_NODE ; le point
## d'ancrage d'une grappe ne bouge pas.
func _spread_clusters(spread: Array, generated: int, ghosts: Array = []) -> void:
	# Seuls les nœuds générés proches d'une grappe peuvent la gêner.
	var near: Array = []
	for g in generated:
		for sp in spread:
			if nodes[g]["pos"].distance_to(sp[1]) < 3.5 * RING_GAP:
				near.append(g)
				break
	var fixed := {}
	var movable: Array = []
	for sp in spread:
		var ids: Array = sp[0]
		var anchor: Vector2 = sp[1]
		var need := 1.0
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var d: float = nodes[ids[i]]["pos"].distance_to(nodes[ids[j]]["pos"])
				if d > 0.001:
					need = maxf(need, _spread_want(ids[i], ids[j]) / d)
		var k := minf(need, SPREAD_MAX)
		var base := {}
		for id in ids:
			base[id] = nodes[id]["pos"]
			if base[id].distance_to(anchor) < 0.01:
				fixed[id] = true
			else:
				movable.append(id)
		while k > 1.0:
			var ok := true
			for id in ids:
				var np: Vector2 = anchor + (base[id] - anchor) * k
				if not _spread_free(np, near, [] if nodes[id]["border"] >= 0 else ghosts):
					ok = false
					break
			if ok:
				for id in ids:
					nodes[id]["pos"] = anchor + (base[id] - anchor) * k
				break
			k -= 0.05
	# Écartement deux à deux : chaque nœud trop proche d'un autre nœud de grappe s'en éloigne un peu.
	var all: Array = movable + fixed.keys()
	for it in 24:
		var moved := false
		for id in movable:
			var p: Vector2 = nodes[id]["pos"]
			var push := Vector2.ZERO
			for other in all:
				if other == id:
					continue
				var q: Vector2 = nodes[other]["pos"]
				var d := p.distance_to(q)
				var want := _spread_want(id, other)
				if d < want and d > 0.001:
					push += (p - q) / d * (want - d) * (0.5 if fixed.has(other) == false else 1.0)
			if push == Vector2.ZERO:
				continue
			var np := p + push * 0.5
			if _spread_free(np, near, [] if nodes[id]["border"] >= 0 else ghosts):
				nodes[id]["pos"] = np
				moved = true
		if not moved:
			break


## Branche d'un nœud de frontière : « side » s'il est écrit, sinon le secteur où il tombe (a du côté
## des y négatifs, b de l'autre ; un nœud posé sur la limite même va à a).
static func _border_side(a: int, b: int, cn: Dictionary, p: Vector2) -> int:
	var side := str(cn.get("side", ""))
	if side != "":
		return b if side == str(BRANCHES[b]["id"]) else a
	var sector := TAU / BRANCHES.size()
	var limit := (a + 1) * sector - PI / 2.0
	return b if wrapf(p.angle() - limit, -PI, PI) > 0.0001 else a


func _spread_want(a: int, b: int) -> float:
	return SPREAD_RADIUS.get(nodes[a]["type"], 18.0) + SPREAD_RADIUS.get(nodes[b]["type"], 18.0) + SPREAD_GAP


func _spread_free(p: Vector2, near: Array, ghosts: Array = []) -> bool:
	for g in near:
		if p.distance_to(nodes[g]["pos"]) < CLEAR_NODE * RING_GAP:
			return false
	for q in ghosts:
		if p.distance_to(q) < CLEAR_NODE * RING_GAP:
			return false
	return true


## Vrai si un nœud généré en p gêne une grappe : trop près d'un de ses nœuds ou de ses liens.
static func _blocks(p: Vector2, pts: Array, segs: Array) -> bool:
	for q in pts:
		if p.distance_to(q) < CLEAR_NODE * RING_GAP:
			return true
	for sg in segs:
		if _seg_dist(p, sg[0], sg[1]) < CLEAR_LINK * RING_GAP:
			return true
	return false


func _cluster_node(id: int, bi: int, cluster: String, cn: Dictionary, pos: Vector2) -> Dictionary:
	var kind := str(cn.get("type", "notable"))
	if not kind in CLUSTER_TYPES:
		kind = "notable"
	var effects: Array = _list(cn.get("effects")).duplicate()
	var skill := str(cn.get("skill", ""))
	if kind == "skill" and skill != "":
		effects.push_front({"skill": skill})
	if kind == "skill" and skill == "":
		for e in effects:
			if e is Dictionary and e.has("skill"):
				skill = str(e["skill"])
				break
	var mutates := str(cn.get("mutates", "")) if kind == "mutation" else ""
	var nm := str(cn.get("name", ""))
	if nm == "":
		if kind == "skill":
			nm = Content.skills().get(skill, {}).get("name", "Compétence")
		elif kind == "mutation":
			nm = "Mutation : " + str(Content.skills().get(mutates, {}).get("name", mutates))
		else:
			nm = DEFAULT_NAME.get(kind, "Nœud notable")
	var key := str(cn.get("key", "")) if kind == "keystone" else ""
	var ring := clampi(roundi(pos.length() / RING_GAP), 1, RINGS)
	var node := _make(id, ring, bi, kind, pos, nm, key, str(cn.get("desc", "")), effects)
	node["uid"] = "key:" + key if key != "" else "c:%s:%s" % [cluster, cn["id"]]
	node["cluster"] = cluster
	node["local"] = str(cn["id"])
	node["mutates"] = mutates
	node["requires_flag"] = str(cn.get("requires_flag", ""))
	node["requires_text"] = str(cn.get("requires_text", ""))
	node["excludes"] = _list(cn.get("excludes"))
	# Nœud d'attaque : la forme qu'il donne (vide s'il n'ajoute que des modificateurs), pour son icône
	# Art.icon("attaque_<forme>") dans l'arbre.
	node["attack_form"] = ""
	if kind == "attack":
		for e in effects:
			if e is Dictionary and e.has("attack_form"):
				node["attack_form"] = str(e["attack_form"])
	if kind == "mutation" or kind == "mastery":
		for ch in _list(cn.get("choices")):
			if ch is Dictionary:
				node["choices"].append(ch)
	return node


## Relie un nœud d'entrée de grappe aux nœuds générés voisins : le plus proche côté graine dans
## sa branche, et un second (de n'importe quelle branche) s'il y en a un autre tout près.
func _link_entry(id: int, generated: int, edge_set: Dictionary) -> void:
	var p: Vector2 = nodes[id]["pos"]
	var inner := -1
	var inner_d := INF
	var sorted: Array = []
	for i in generated:
		var q: Vector2 = nodes[i]["pos"]
		var d := p.distance_to(q)
		sorted.append([d, i])
		# Côté graine, et dans la branche de la grappe (ou la graine elle-même).
		if q.length() < p.length() and d < inner_d and (nodes[i]["branch"] == nodes[id]["branch"] or i == 0):
			inner_d = d
			inner = i
	if sorted.is_empty():
		return
	sorted.sort_custom(func(x, y): return x[0] < y[0])
	if inner < 0:
		inner = sorted[0][1]
	_link(id, inner, edge_set)
	for s in sorted:
		if s[0] > 1.3 * RING_GAP:
			break
		if s[1] != inner:
			_link(id, s[1], edge_set)
			break


## Relie à l'arbre chaque groupe de nœuds coupé de la graine, par le lien le plus court possible
## qui ne passe pas sur un nœud de grappe.
func _reconnect(edge_set: Dictionary, pts: Array) -> void:
	for attempt in nodes.size():
		var seen := {0: true}
		var stack: Array = [0]
		while stack.size() > 0:
			var u: int = stack.pop_back()
			for m in nodes[u]["neighbors"]:
				# Un nœud flétri reste fermé longtemps : on ne le traverse que vers sa propre grappe,
				# pour qu'aucun autre nœud ne dépende de lui.
				if nodes[u]["type"] == "withered" and nodes[m]["cluster"] != nodes[u]["cluster"]:
					continue
				if not seen.has(m):
					seen[m] = true
					stack.append(m)
		if seen.size() == nodes.size():
			return
		var best := INF
		var bu := -1
		var bv := -1
		var fallback := INF
		var fu := -1
		var fv := -1
		for n in nodes:
			if seen.has(n["id"]):
				continue
			var p: Vector2 = n["pos"]
			for u in seen:
				var q: Vector2 = nodes[u]["pos"]
				var d := p.distance_squared_to(q)
				if d < fallback:
					fallback = d
					fu = u
					fv = n["id"]
				if d < best and not _crosses(p, q, pts):
					best = d
					bu = u
					bv = n["id"]
		if bu < 0:
			bu = fu
			bv = fv
		_link(bu, bv, edge_set)


## Vrai si le segment a-b passe trop près d'un nœud de grappe qui n'est pas une de ses extrémités.
static func _crosses(a: Vector2, b: Vector2, pts: Array) -> bool:
	for q in pts:
		if q.is_equal_approx(a) or q.is_equal_approx(b):
			continue
		if _seg_dist(q, a, b) < CLEAR_EDGE * RING_GAP:
			return true
	return false


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


static func _list(v) -> Array:
	return v if v is Array else []


## Prépare ce que les règles d'apprentissage consultent : qui donne quelle compétence, qui exclut qui.
func _index_rules() -> void:
	var keys := {}
	var locals := {}
	for n in nodes:
		if n["cluster"] != "":
			locals["%s|%s" % [n["cluster"], n["local"]]] = n["id"]
		if n["key"] != "":
			keys[n["key"]] = n["id"]
		for e in n["effects"]:
			if e is Dictionary and e.has("skill"):
				if not skill_sources.has(e["skill"]):
					skill_sources[e["skill"]] = []
				skill_sources[e["skill"]].append(n["id"])
	for n in nodes:
		for x in n["excludes"]:
			var other := -1
			var local := "%s|%s" % [n["cluster"], x]
			if locals.has(local):
				other = locals[local]
			elif by_uid.has(str(x)):
				other = by_uid[str(x)]
			elif keys.has(str(x)):
				other = keys[str(x)]
			if other < 0 or other == n["id"]:
				continue
			for pair in [[n["id"], other], [other, n["id"]]]:
				if not exclusions.has(pair[0]):
					exclusions[pair[0]] = []
				if not pair[1] in exclusions[pair[0]]:
					exclusions[pair[0]].append(pair[1])


## Index du nœud portant cet identifiant stable, ou -1 s'il n'existe plus.
func id_for_uid(uid: String) -> int:
	return int(by_uid.get(uid, -1))


func _make(id: int, ring: int, branch: int, kind: String, pos: Vector2, nm: String, key: String, desc: String, effects: Array) -> Dictionary:
	return {
		"id": id, "ring": ring, "branch": branch, "type": kind, "pos": pos,
		"name": nm, "key": key, "desc": desc, "effects": effects, "neighbors": [],
		"uid": "root" if id == 0 else "",
		# Champs des nœuds de grappe (vides pour un nœud généré).
		"cluster": "", "local": "", "choices": [], "mutates": "", "requires_flag": "", "requires_text": "", "excludes": [],
		"attack_form": "",
		# Frontière hybride : l'autre branche du nœud (-1 hors des frontières).
		"border": -1,
	}


## Effets d'un nœud généré : un petit nœud porte une des statistiques de sa branche,
## un nœud notable les porte toutes (renforcées) plus le bonus propre à la branche.
func _effects(b: Dictionary, r: int, notable: bool, i: int) -> Array:
	var cfg := Content.tree()
	var scale: float = 1.0 + cfg.get("ring_scale", 0.0) * r
	var small: Array = b["small"]
	if not notable:
		return [Effects.scaled(small[(i + r) % small.size()], scale)]
	var e: Array = []
	for s in small:
		e.append(Effects.scaled(s, cfg.get("notable_factor", 1.0) * scale))
	e.append_array(b["notable"].get("effects", []))
	return Effects.merged(e)


func _link(a: int, b: int, edge_set: Dictionary) -> void:
	if a == b:
		return
	var k := Vector2i(mini(a, b), maxi(a, b))
	if edge_set.has(k):
		return
	edge_set[k] = true
	edges.append(k)
	nodes[a]["neighbors"].append(b)
	nodes[b]["neighbors"].append(a)


## Texte lisible des effets d'un nœud.
static func describe(n: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for e in n["effects"]:
		var line := Effects.describe(e)
		if line != "":
			out.append(line)
	for ch in n.get("choices", []):
		out.append("%s : %s" % [ch.get("name", ""), describe_effects(ch.get("effects", []))])
	if n["desc"] != "":
		out.append(n["desc"])
	if out.is_empty() and n["type"] == "graft":
		out.append("Reçoit une greffe trouvée dans le monde.")
	return out


## Les effets d'une liste sur une seule ligne, séparés par des points-virgules.
static func describe_effects(effects: Array) -> String:
	var parts := PackedStringArray()
	for e in effects:
		var line := Effects.describe(e)
		if line != "":
			parts.append(line)
	return " ; ".join(parts)
