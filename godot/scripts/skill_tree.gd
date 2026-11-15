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
extends RefCounted

const RINGS := 12
const RING_GAP := 110.0
const SEED := 20261109

## Types de nœuds qu'une grappe peut contenir.
const CLUSTER_TYPES := ["small", "notable", "keystone", "skill", "mutation", "mastery", "graft", "withered"]
## Nom par défaut d'un nœud de grappe sans « name ».
const DEFAULT_NAME := {"graft": "Emplacement de greffe", "withered": "Nœud flétri", "mastery": "Maîtrise", "small": "Nœud"}
## Distances de dégagement autour d'une grappe, en unités d'anneau : un nœud généré plus proche
## que CLEAR_NODE d'un nœud de grappe (ou que CLEAR_LINK d'un de ses liens) est écarté ; un lien
## généré qui passe à moins de CLEAR_EDGE d'un nœud de grappe est retiré.
const CLEAR_NODE := 0.62
const CLEAR_LINK := 0.36
const CLEAR_EDGE := 0.34

const Content = preload("res://scripts/content.gd")
const Effects = preload("res://scripts/effects.gd")

## Branches, lues dans res://data/branches/ (une par fichier, dans l'ordre de tree.json).
static var BRANCHES: Array = Content.branches()

var nodes: Array = []
var edges: Array = []  # Vector2i(a, b)
## Identifiant stable (uid) -> index dans nodes. Les sauvegardes utilisent les uid,
## qui ne changent pas si l'ordre de génération des nœuds évolue.
var by_uid: Dictionary = {}
## Grappes insérées : "<branche>:<grappe>" -> {"name", "branch", "nodes": [index], "effects": bonus de grappe complète}.
var clusters: Dictionary = {}
## Compétence -> index des nœuds qui la donnent (pour savoir si une mutation est disponible).
var skill_sources: Dictionary = {}
## Index d'un nœud -> index des nœuds qui s'excluent avec lui (relation symétrique).
var exclusions: Dictionary = {}


func branch_color(bi: int) -> Color:
	if bi < 0:
		return Color("f0e6b4")
	return Color(BRANCHES[bi]["color"])


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
	var sector := TAU / BRANCHES.size()
	var out := Vector2.from_angle(bi * sector - PI / 2.0 + float(c.get("angle", 0.5)) * sector)
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
			var pos := cluster_layout(bi, c)
			specs.append({"bi": bi, "c": c, "pos": pos})
			for cn in c["nodes"]:
				if not cn is Dictionary:
					continue
				var p: Vector2 = pos[str(cn.get("id", ""))]
				pts.append(p)
				for l in _list(cn.get("links")):
					if pos.has(str(l)):
						segs.append([p, pos[str(l)]])
	if specs.is_empty():
		return

	# 1. Les petits nœuds et notables générés qui gênent sont écartés (jamais la graine ni un nœud clé).
	var remove := {}
	for n in nodes:
		if n["type"] != "small" and n["type"] != "notable":
			continue
		var p: Vector2 = n["pos"]
		for q in pts:
			if p.distance_to(q) < CLEAR_NODE * RING_GAP:
				remove[n["id"]] = true
				break
		if remove.has(n["id"]):
			continue
		for sg in segs:
			if _seg_dist(p, sg[0], sg[1]) < CLEAR_LINK * RING_GAP:
				remove[n["id"]] = true
				break

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
	for s in specs:
		var c: Dictionary = s["c"]
		var bi: int = s["bi"]
		var bid: String = BRANCHES[bi]["id"]
		var key := "%s:%s" % [bid, c.get("id", "")]
		var ids := {}
		for cn in c["nodes"]:
			if not cn is Dictionary or str(cn.get("id", "")) == "" or ids.has(str(cn["id"])):
				continue
			var node := _cluster_node(nodes.size(), bi, key, cn, s["pos"][str(cn["id"])])
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
		clusters[key] = {
			"name": str(c.get("name", "")), "branch": bi, "nodes": ids.values(),
			"effects": _list(complete.get("effects")) if complete is Dictionary else [],
		}

	# 4. Tout ce qui n'est plus relié à la graine est recousu au plus proche.
	_reconnect(edge_set, pts)


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
			for m in nodes[stack.pop_back()]["neighbors"]:
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
