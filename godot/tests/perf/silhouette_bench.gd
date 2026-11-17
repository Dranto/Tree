## Micro-banc des silhouettes : temps de calcul d'une silhouette par sorte (sans rendu).
##   tools/godot.sh --headless -s res://tests/perf/silhouette_bench.gd
extends SceneTree

const DrawBatch = preload("res://scripts/draw_batch.gd")
const FletriArt = preload("res://scripts/fletri_art.gd")


func _init() -> void:
	var kinds := ["fletri", "cendreux", "colosse", "cracheur", "gardien", "boursoufle", "tireur", "chargeur", "nid", "rejeton"]
	var radii := {"fletri": 14, "cendreux": 10, "colosse": 25, "cracheur": 17, "gardien": 19, "boursoufle": 18, "tireur": 13, "chargeur": 12, "nid": 26, "rejeton": 8}
	var b = DrawBatch.new()
	var total := 0.0
	for k in kinds:
		var n := 400
		var t0 := Time.get_ticks_usec()
		var verts := 0
		for i in n:
			var o := {"walk": i * 0.3, "moving": 1.0, "state": "", "k": 0.0}
			FletriArt.draw(b, k, Vector2.ZERO, radii[k], Vector2.from_angle(i * 0.1), i * 0.05, o)
			verts = b.points.size()
			b.clear()
		var us := (Time.get_ticks_usec() - t0) / float(n)
		total += us
		print("SIL %-10s %6.1f us  %4d sommets" % [k, us, verts])
	print("SIL moyenne %.1f us" % (total / kinds.size()))
	quit()
