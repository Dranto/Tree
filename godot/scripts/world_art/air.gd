## Lumière et air des « Paysages d'herbier » : la lumière vient d'en haut à gauche (comme l'encre des
## créatures), une teinte d'air et des particules propres à la région et à son état.
##   - flétri : sombre et brumeux (nappes de brume basses, voile froid, cendre qui tombe, rares braises) ;
##   - ravivé : nettement plus clair (lumière chaude, rayons obliques, pétales et graines du Roncier,
##     spores lumineuses du Marais).
## Le centre du cadre reste presque intact : la lumière n'enlève jamais de contraste aux personnages.
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")


## Sous le décor : nappes de brume au ras du sol (flétri) ou flaque de lumière sur la clairière (ravivé).
static func under(ci: CanvasItem, m, rect: Rect2) -> void:
	var reg: String = m.region
	if m.etat == "fletri":
		var air: Color = Art.mc(reg, "fletri", "air")
		for cell in _grid(rect, 420.0):
			var r := O.rng_at(cell, 91)
			var c := (Vector2(cell) + Vector2(r.randf(), r.randf())) * 420.0 + Vector2(sin(m.t * 0.3 + cell.x) * 12.0, 0)
			var rx := r.randf_range(160.0, 300.0)
			O.poly(ci, O.blob(c, rx, rx * 0.28, r.randf() * 9.0, 0.2, 36), Color(air, 0.16))
			O.poly(ci, O.blob(c + Vector2(20, -6), rx * 0.6, rx * 0.16, r.randf() * 9.0, 0.2, 30), Color(air, 0.12))
	else:
		var light: Color = Art.mc(reg, "ravive", "air")
		for cl in m.clearings():
			O.poly(ci, O.blob(cl[0] + Vector2(-40, -20), cl[1].x * 0.8, cl[1].y * 0.7, 5.0, 0.1, 40), Color(light, 0.07))


## Par-dessus tout : rayons, dégradé de lumière, bords plus sombres, particules.
static func over(ci: CanvasItem, m, rect: Rect2) -> void:
	var reg: String = m.region
	var rav: bool = m.etat == "ravive"
	var light: Color = Art.mc(reg, "ravive" if rav else "fletri", "air")
	var voile: Color = Art.mc(reg, "ravive" if rav else "fletri", "voile")
	if rav:
		# Rayons obliques depuis le haut à gauche.
		for i in 4:
			var x := rect.position.x + rect.size.x * (0.05 + 0.22 * i)
			var a := Vector2(x, rect.position.y - 20)
			var d := Vector2(0.55, 0.83) * rect.size.y * 1.3
			var w := 40.0 + 30.0 * (i % 2)
			O.poly(ci, PackedVector2Array([a, a + Vector2(w, 0), a + d + Vector2(w * 2.2, 0), a + d]), Color(light, 0.045))
	# Dégradé : clair en haut à gauche, voilé en bas à droite.
	var tl := rect.position
	var br := rect.end
	ci.draw_polygon(PackedVector2Array([tl, Vector2(br.x, tl.y), br, Vector2(tl.x, br.y)]),
		PackedColorArray([Color(light, 0.10 if rav else 0.05), Color(voile, 0.0), Color(voile, 0.22 if rav else 0.3), Color(voile, 0.0)]))
	# Bords plus sombres (vignette), plus marqués quand le monde est flétri.
	_vignette(ci, rect, voile, 0.42 if rav else 0.62)
	_particles(ci, m, rect, rav)


static func _vignette(ci: CanvasItem, rect: Rect2, col: Color, a: float) -> void:
	var inner := rect.grow_individual(-rect.size.x * 0.2, -rect.size.y * 0.18, -rect.size.x * 0.2, -rect.size.y * 0.18)
	var o := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var i := [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
	for k in 4:
		var k2 := (k + 1) % 4
		ci.draw_polygon(PackedVector2Array([o[k], o[k2], i[k2], i[k]]), PackedColorArray([Color(col, a), Color(col, a), Color(col, 0.0), Color(col, 0.0)]))


static func _particles(ci: CanvasItem, m, rect: Rect2, rav: bool) -> void:
	var reg: String = m.region
	var t: float = m.t
	var col: Color = Art.mc(reg, "ravive" if rav else "fletri", "particule")
	var r := RandomNumberGenerator.new()
	r.seed = 404
	var n := 70 if rav else 55
	for i in n:
		var speed := Vector2(r.randf_range(10.0, 26.0), r.randf_range(8.0, 22.0))
		if reg == "spore":
			speed = Vector2(r.randf_range(-6.0, 6.0), -r.randf_range(6.0, 14.0))
		var p := Vector2(r.randf(), r.randf()) * rect.size + speed * t
		p = rect.position + Vector2(fposmod(p.x, rect.size.x), fposmod(p.y, rect.size.y))
		var ph := r.randf() * TAU
		if rav and reg == "ronce":
			if i % 3 == 0:
				# Graine à aigrette.
				ci.draw_circle(p, 3.2, Color(1, 1, 1, 0.16))
				ci.draw_circle(p, 1.0, Color(1, 1, 1, 0.75))
			else:
				var a := ph + t * 1.5
				O.poly(ci, O.Ink.oval(p, 3.0, 1.6, 10, a), Color(col, 0.8))
		elif rav:
			var s := 1.2 + 1.2 * (0.5 + 0.5 * sin(t * 2.0 + ph))
			ci.draw_circle(p, s * 3.2, Color(col, 0.12))
			ci.draw_circle(p, s, Color(col, 0.85))
		else:
			if i % 11 == 0:
				ci.draw_circle(p, 3.0, Color(Art.bc("braise"), 0.14))
				ci.draw_circle(p, 1.0, Art.bc("braise"))
			else:
				var a := ph + t
				O.poly(ci, O.Ink.oval(p, 1.8, 1.1, 8, a), Color(col, 0.45))


static func _grid(rect: Rect2, size: float) -> Array:
	var out := []
	for y in range(floori(rect.position.y / size) - 1, ceili(rect.end.y / size) + 1):
		for x in range(floori(rect.position.x / size) - 1, ceili(rect.end.x / size) + 1):
			out.append(Vector2i(x, y))
	return out
