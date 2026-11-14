## Génération procédurale (déterministe) de l'Arbre de vie.
## Six branches partent de la graine centrale sur 12 anneaux : environ 600 nœuds.
## La position d'un nœud dans l'arbre correspond à une région du monde :
## l'apprendre ravive cette région.
## Le générateur ne décide que de la forme de l'arbre. Ce que font les nœuds (statistiques,
## nœuds clés, compétences) est décrit dans res://data/ : voir res://data/README.md.
extends RefCounted

const RINGS := 12
const RING_GAP := 110.0
const SEED := 20261109

const Content = preload("res://scripts/content.gd")
const Effects = preload("res://scripts/effects.gd")

## Branches, lues dans res://data/branches/ (une par fichier, dans l'ordre de tree.json).
static var BRANCHES: Array = Content.branches()

var nodes: Array = []
var edges: Array = []  # Vector2i(a, b)
## Identifiant stable (uid) -> index dans nodes. Les sauvegardes utilisent les uid,
## qui ne changent pas si l'ordre de génération des nœuds évolue.
var by_uid: Dictionary = {}


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
	for n in nodes:
		by_uid[n["uid"]] = n["id"]


## Index du nœud portant cet identifiant stable, ou -1 s'il n'existe plus.
func id_for_uid(uid: String) -> int:
	return int(by_uid.get(uid, -1))


func _make(id: int, ring: int, branch: int, kind: String, pos: Vector2, nm: String, key: String, desc: String, effects: Array) -> Dictionary:
	return {
		"id": id, "ring": ring, "branch": branch, "type": kind, "pos": pos,
		"name": nm, "key": key, "desc": desc, "effects": effects, "neighbors": [],
		"uid": "root" if id == 0 else "",
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
	if n["desc"] != "":
		out.append(n["desc"])
	return out
