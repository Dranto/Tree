## Banc du dessin des silhouettes (fletri_art.gd) sans rendu : temps de calcul d'une silhouette
## dans le lot de triangles, par sorte. Lancer : tools/godot.sh --headless -s res://tests/fletri_bench.gd
extends SceneTree

const FletriArt = preload("res://scripts/fletri_art.gd")
const DrawBatch = preload("res://scripts/draw_batch.gd")
const N := 1500


func _initialize() -> void:
	var b = DrawBatch.new()
	var total := 0.0
	for kind in ["fletri", "cendreux", "colosse", "cracheur", "gardien", "boursoufle", "tireur", "chargeur", "nid", "rejeton"]:
		var t0 := Time.get_ticks_usec()
		var verts := 0
		for i in N:
			var face := Vector2.from_angle(i * 0.37)
			var o := {"walk": i * 0.2, "moving": 0.7, "state": "", "k": 0.0}
			b.draw_colored_polygon(Art.ellipse(Vector2(0, 3), 14.7, 10.5, 14), Art.c("ombre"))
			FletriArt.draw(b, kind, Vector2.ZERO, 14.0, face, i * 0.016, o)
			verts = b.points.size()
			b.clear()
		var us := (Time.get_ticks_usec() - t0) / float(N)
		total += us
		print("SILHOUETTE %-11s %6.1f µs  %4d sommets" % [kind, us, verts])
	print("SILHOUETTE moyenne %6.1f µs" % (total / 10.0))
	quit(0)
