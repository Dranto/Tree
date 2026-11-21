## Empreinte de l'Arbre de vie : nombre de nœuds par branche, md5 des nœuds, des liens et des grappes,
## temps de construction. Sert à vérifier qu'une optimisation de skill_tree.gd ne change rien.
## Lancer : tools/godot.sh --headless -s res://tests/tree_fingerprint.gd
extends SceneTree


func _initialize() -> void:
	var SkillTree = load("res://scripts/skill_tree.gd")
	var t = SkillTree.new()
	var best := INF
	for i in 3:
		var t0 := Time.get_ticks_usec()
		t.build()
		best = minf(best, (Time.get_ticks_usec() - t0) / 1000.0)
	var ns := PackedStringArray()
	var per := {}
	for n in t.nodes:
		ns.append("%s|%s|%d|%d|%.2f,%.2f|%s" % [n["uid"], n["type"], n["branch"], n["border"], n["pos"].x, n["pos"].y, n["name"]])
		var k: String = "frontières" if n["border"] >= 0 else ("graine" if n["branch"] < 0 else SkillTree.BRANCHES[n["branch"]]["id"])
		per[k] = int(per.get(k, 0)) + 1
	var es := PackedStringArray()
	for e in t.edges:
		es.append("%s-%s" % [t.nodes[e.x]["uid"], t.nodes[e.y]["uid"]])
	var cs := PackedStringArray()
	var keys: Array = t.clusters.keys()
	keys.sort()
	for k in keys:
		cs.append("%s:%s" % [k, t.clusters[k]["nodes"]])
	print("EMPREINTE nœuds %d liens %d grappes %d" % [t.nodes.size(), t.edges.size(), t.clusters.size()])
	print("EMPREINTE par branche %s" % [per])
	print("EMPREINTE md5 nœuds %s liens %s grappes %s" % ["\n".join(ns).md5_text(), "\n".join(es).md5_text(), "\n".join(cs).md5_text()])
	var dump := OS.get_environment("TREE_DUMP")
	if dump != "":
		var f := FileAccess.open(dump, FileAccess.WRITE)
		f.store_string("\n".join(ns) + "\n")
		for e in es:
			f.store_line("E " + e)
	print("EMPREINTE construction %.0f ms" % best)
	quit(0)
