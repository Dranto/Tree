## Apparence du héros (l'Esprit masqué, scripts/creature_art/heros/) selon le build en cours :
##   voie  : part des nœuds appris dans chaque branche de l'Arbre (un nœud de frontière compte pour
##           moitié dans chacune de ses deux branches) : un build hybride mélange les tenues ;
##   evol  : palier atteint dans l'Arbre (anneaux des nœuds clés 4, 8 et 12) : la tenue se renforce ;
##   forme, mods : l'attaque de base courante (attack.gd current()) : l'arme et ses ornements.
## Lu au changement de l'Arbre (achat, oubli, bascule de build) : player.gd compare la clé et relance
## la cuisson (hero_bake.gd) quand l'apparence change. Apparence seulement : rien ici ne touche au jeu.
extends RefCounted

const SkillTree = preload("res://scripts/skill_tree.gd")
const AttackScript = preload("res://scripts/attack.gd")

## Anneaux des paliers (nœuds clés générés) et progression de la tenue à chaque palier.
const PALIERS := [4, 8, 12]
const EVOL := [0.0, 0.4, 0.72, 1.0]
## Les parts de branche sont arrondies (pas de nouvelle cuisson pour un écart invisible).
const PAS := 0.1


## Apparence de la partie en cours (Game), ou celle du départ sans Game.
static func current() -> Dictionary:
	var ml := Engine.get_main_loop()
	var game = ml.root.get_node_or_null("Game") if ml is SceneTree else null
	if game == null or game.tree == null:
		return compute([], [], AttackScript.current())
	return compute(game.tree.nodes, game.allocated.keys(), AttackScript.current())


## Apparence pour des nœuds appris (identifiants dans nodes) et un état d'attaque.
static func compute(nodes: Array, owned: Array, att: Dictionary) -> Dictionary:
	var count := {}
	var ring := 0
	var total := 0.0
	for id in owned:
		if int(id) < 0 or int(id) >= nodes.size():
			continue
		var n: Dictionary = nodes[id]
		var bi := int(n.get("branch", -1))
		if bi < 0 or bi >= SkillTree.BRANCHES.size():
			continue
		ring = maxi(ring, int(n.get("ring", 0)))
		var other := int(n.get("border", -1))
		var parts := {bi: 1.0} if other < 0 or other >= SkillTree.BRANCHES.size() else {bi: 0.5, other: 0.5}
		for b in parts:
			var id_b := str(SkillTree.BRANCHES[b].get("id", ""))
			count[id_b] = float(count.get(id_b, 0.0)) + parts[b]
			total += parts[b]
	var voie := {}
	for b in count:
		var w := snappedf(count[b] / total, PAS)
		if w > 0.0:
			voie[b] = w
	var palier := 0
	for r in PALIERS:
		if ring >= r:
			palier += 1
	var forme := str(att.get("form", AttackScript.start_form()))
	var mods := []
	var md: Dictionary = att.get("mods", {})
	for m in md:
		if float(md[m]) > 0.0 and AttackScript.applies(m, forme):
			mods.append(str(m))
	mods.sort()
	return {"voie": voie, "evol": EVOL[palier], "forme": forme, "mods": mods}


## Clé du corps (tenue seule) et de l'ensemble (tenue et arme) : deux apparences de même clé se
## dessinent pareil.
static func body_key(look: Dictionary) -> String:
	var v: Dictionary = look.get("voie", {})
	var ks := v.keys()
	ks.sort()
	var s := "%.2f" % float(look.get("evol", 0.0))
	for b in ks:
		s += "|%s:%.2f" % [b, v[b]]
	return s


static func key(look: Dictionary) -> String:
	return body_key(look) + "#" + str(look.get("forme", "")) + ":" + ",".join(look.get("mods", []))
