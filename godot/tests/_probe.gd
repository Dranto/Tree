extends SceneTree
func _initialize():
	var g = root.get_node("Game")
	var by := {}
	for n in g.tree.nodes:
		by[n["ring"]] = int(by.get(n["ring"],0))+1
	print(by)
	for l in [1,5,10,20,30]:
		print(l, " ", g.xp_to_next() if l==1 else 0)
	var D = load("res://scripts/difficulty.gd")
	for l in [1,5,10,20,30,40]:
		print("lvl ", l, " xp ", D.xp_to_next(l))
	quit()
