## Génération procédurale (déterministe) de l'Arbre de vie.
## Six branches partent de la graine centrale sur 12 anneaux : environ 600 nœuds.
## La position d'un nœud dans l'arbre correspond à une région du monde :
## l'apprendre ravive cette région.
extends RefCounted

const RINGS := 12
const RING_GAP := 110.0
const SEED := 20261109

const BRANCHES := [
	{"id": "ronce", "name": "Ronce", "color": "#e0675e", "blurb": "Dégâts bruts et épines", "stats": ["damage", "thorns"], "bonus": {"pierce": 0.5}},
	{"id": "spore", "name": "Spore", "color": "#b48ae0", "blurb": "Poison et zones", "stats": ["poison", "area"], "bonus": {"poison": 0.1}},
	{"id": "seve", "name": "Sève", "color": "#7fd36b", "blurb": "Vie, régénération, vol de vie", "stats": ["max_hp", "regen"], "bonus": {"lifesteal": 0.01}},
	{"id": "vent", "name": "Vent", "color": "#7fd0e0", "blurb": "Vitesse d'attaque et de déplacement", "stats": ["attack_speed", "move_speed"], "bonus": {"pickup": 0.2, "dash_cd": 0.05}},
	{"id": "aube", "name": "Aube", "color": "#f2d06b", "blurb": "Coups critiques", "stats": ["crit", "crit_mult"], "bonus": {"damage": 0.08}},
	{"id": "racine", "name": "Racine", "color": "#c49a6c", "blurb": "Armure et robustesse", "stats": ["armor", "max_hp"], "bonus": {"max_hp": 20.0}},
]

## Valeur d'un petit nœud au premier anneau.
const STAT_SMALL := {
	"damage": 0.05, "thorns": 3.0, "poison": 0.06, "area": 0.05,
	"max_hp": 10.0, "regen": 0.35, "attack_speed": 0.04, "move_speed": 0.025,
	"crit": 0.012, "crit_mult": 0.07, "armor": 0.015,
}

## Libellé et affichage en pourcentage ou non.
const STAT_LABEL := {
	"damage": ["Dégâts", true], "thorns": ["Épines (dégâts renvoyés)", false],
	"poison": ["Poison (dégâts du coup par seconde)", true], "area": ["Taille des zones", true],
	"max_hp": ["Vie maximale", false], "regen": ["Régénération /s", false],
	"attack_speed": ["Vitesse d'attaque", true], "move_speed": ["Vitesse de déplacement", true],
	"crit": ["Chance de critique", true], "crit_mult": ["Multiplicateur de critique", true],
	"armor": ["Armure (réduction des dégâts)", true], "pierce": ["Perforation", false],
	"lifesteal": ["Vol de vie", true], "pickup": ["Rayon de collecte", true],
	"dash_cd": ["Recharge de l'esquive", true],
}

## Nœuds clés : placés aux anneaux 4, 8 et 12 de chaque branche.
const KEYSTONES := {
	"ronce": [
		["nova", "Couronne d'épines", "Nouvelle compétence : une onde d'épines blesse et repousse les ennemis autour de toi."],
		["ecorce_vive", "Écorce vive", "Épines ×3, +15 dégâts renvoyés."],
		["sanguinaire", "Ronce sanguinaire", "Dégâts ×1,4, mais vie maximale ×0,8."],
	],
	"spore": [
		["cloud", "Nuage de spores", "Nouvelle compétence : un nuage toxique ronge les ennemis à l'endroit visé."],
		["mycose", "Mycose", "Poison ×2, +15 % de base."],
		["contagion", "Contagion", "Un ennemi empoisonné qui meurt transmet son poison autour de lui."],
	],
	"seve": [
		["bloom", "Floraison", "Nouvelle compétence : soigne 35 % de ta vie et fait renaître le sol autour de toi."],
		["racine_de_vie", "Racine de vie", "+3 % de vol de vie."],
		["immortel", "Graine immortelle", "Une fois par minute, un coup mortel te laisse à 1 point de vie."],
	],
	"vent": [
		["rafale", "Rafale", "+2 projectiles, mais dégâts ×0,85."],
		["pas_du_vent", "Pas du vent", "Chaque ennemi vaincu réduit la recharge de l'esquive de 0,3 s."],
		["tempete", "Tempête", "Vitesse d'attaque ×1,5."],
	],
	"aube": [
		["eclat", "Éclat d'aube", "Les coups critiques explosent et touchent les ennemis proches."],
		["zenith", "Zénith", "Chance de critique ×2."],
		["lumiere_lente", "Lumière lente", "Projectiles énormes, dégâts ×1,6, vitesse d'attaque ×0,8."],
	],
	"racine": [
		["enracine", "Enraciné", "Immobile depuis 0,5 s : dégâts ×1,4 et +20 % d'armure."],
		["coeur_pierre", "Cœur de pierre", "Vie maximale ×1,5, vitesse ×0,9."],
		["bastion", "Bastion", "+15 % d'armure et plafond d'armure porté à 85 %."],
	],
}

const NOTABLE_WORDS := {
	"ronce": [["Épine", "Ronceraie", "Dard", "Aiguillon", "Haie", "Griffe"], ["vorace", "rouge", "acérée", "sauvage", "cruelle", "noueuse"]],
	"spore": [["Hyphe", "Spore", "Moisissure", "Filament", "Sporée", "Trame"], ["sombre", "tissée", "fertile", "muette", "rampante", "violette"]],
	"seve": [["Source", "Bourgeon", "Pousse", "Sève", "Rosée", "Floraison"], ["tendre", "vive", "pure", "claire", "fraîche", "vernale"]],
	"vent": [["Souffle", "Bourrasque", "Pollen", "Brise", "Plume", "Envol"], ["léger", "vif", "errant", "frais", "agile", "libre"]],
	"aube": [["Rayon", "Éclat", "Aurore", "Lueur", "Zénith", "Prisme"], ["doré", "aveuglant", "pâle", "ardent", "premier", "nacré"]],
	"racine": [["Souche", "Pivot", "Rhizome", "Écorce", "Cerne", "Tronc"], ["ancien", "tenace", "profond", "patient", "massif", "scellé"]],
}

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
	nodes.append(_make(0, 0, -1, "root", Vector2.ZERO, "Graine de l'Arbre-Monde", "", "Le cœur de l'arbre. Tout part d'ici.", {}))

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
				var effects := {}
				if i == mid and r % 4 == 0:
					kind = "keystone"
					var ks: Array = KEYSTONES[bid][int(r / 4.0) - 1]
					key = ks[0]
					nm = ks[1]
					desc = ks[2]
				elif r % 3 == 0 and i != 0 and i != count - 1 and (i + r) % 4 == 0:
					kind = "notable"
				elif r >= 2 and rng.randf() < 0.05:
					kind = "notable"
				if kind == "notable":
					var words: Array = NOTABLE_WORDS[bid]
					name_idx[bid] = int(name_idx.get(bid, 0)) + 1
					var k: int = name_idx[bid]
					nm = "%s %s" % [words[0][k % words[0].size()], words[1][int(k / float(words[0].size())) % words[1].size()]]
					effects = _effects(b, r, true, i)
				elif kind == "small":
					effects = _effects(b, r, false, i)
					var st: String = effects.keys()[0]
					nm = STAT_LABEL[st][0]
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


func _make(id: int, ring: int, branch: int, kind: String, pos: Vector2, nm: String, key: String, desc: String, effects: Dictionary) -> Dictionary:
	return {
		"id": id, "ring": ring, "branch": branch, "type": kind, "pos": pos,
		"name": nm, "key": key, "desc": desc, "effects": effects, "neighbors": [],
		"uid": "root" if id == 0 else "",
	}


func _effects(b: Dictionary, r: int, notable: bool, i: int) -> Dictionary:
	var e := {}
	var scale := 1.0 + 0.06 * r
	var stats: Array = b["stats"]
	if notable:
		for st in stats:
			e[st] = STAT_SMALL[st] * 2.5 * scale
		var bonus: Dictionary = b["bonus"]
		for k in bonus:
			e[k] = float(e.get(k, 0.0)) + bonus[k]
	else:
		var st: String = stats[(i + r) % 2]
		e[st] = STAT_SMALL[st] * scale
	return e


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
	var effects: Dictionary = n["effects"]
	for k in effects:
		var info: Array = STAT_LABEL[k]
		var v: float = effects[k]
		if k == "pierce":
			out.append("+%s %s" % [str(snappedf(v, 0.1)), info[0]])
		elif k == "dash_cd":
			out.append("-%d %% %s" % [roundi(v * 100.0), info[0]])
		elif info[1]:
			out.append("+%s %% %s" % [str(snappedf(v * 100.0, 0.1)), info[0]])
		else:
			out.append("+%s %s" % [str(snappedf(v, 0.1)), info[0]])
	if n["desc"] != "":
		out.append(n["desc"])
	return out
