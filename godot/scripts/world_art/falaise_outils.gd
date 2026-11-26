## Outils de dessin des Falaises (région d'Aube, refonte du monde vague 2 P5) : prismes de cristal,
## bouquets de cristaux, blocs de calcaire en strates, fleurs d'aube, étincelles. Partagés par le décor
## (decor_falaise.gd) ; couleurs de Art.MONDE["aube"]. Dessin seul.
extends RefCounted

const O = preload("res://scripts/world_art/outils.gd")
const A = preload("res://scripts/region_art/aube.gd")


## État dessiné d'un élément : « ravive » une fois reverdi, sinon « fletri ».
static func etat_of(t) -> String:
	return "ravive" if t.alive and t.growth() > 0.5 else "fletri"


static func pal(etat: String, key: String) -> Dictionary:
	return Art.mc("aube", etat, key)


static func col(etat: String, key: String) -> Color:
	return Art.mc("aube", etat, key)


## Un prisme de cristal à l'encre : pied en foot, demi-largeur wid, hauteur hgt, penché de lean ; face
## claire à droite, arête lumineuse au milieu.
static func prism(ci: CanvasItem, foot: Vector2, wid: float, hgt: float, lean: float, p: Dictionary) -> PackedVector2Array:
	var pts := A.prism(foot, wid, hgt, lean)
	O.part(ci, pts, p, 1.2, 0.6, 0.0)
	var tip: Vector2 = pts[2]
	var base: Vector2 = pts[0].lerp(pts[4], 0.5)
	O.poly(ci, PackedVector2Array([base, tip, pts[3], pts[4]]), Color(p["clair"].lightened(0.12), 0.85))
	ci.draw_line(base, tip, Color(p["reflet"], 0.85), maxf(0.8, wid * 0.12), true)
	ci.draw_line(pts[1].lerp(tip, 0.2), pts[1].lerp(tip, 0.75), Color(p["reflet"], 0.4), 0.8, true)
	return pts


## Bouquet de n prismes plantés ensemble (les plus hauts au milieu), pied en c, largeur spread, hauteur
## hgt. Verre et nacre en alternance ; ravivé : une lueur d'or au pied et des fleurs d'aube.
static func crystal_group(ci: CanvasItem, c: Vector2, spread: float, hgt: float, n: int, r: RandomNumberGenerator, etat: String) -> void:
	var glass := pal(etat, "verre")
	var nacre := pal(etat, "nacre")
	var alive := etat == "ravive"
	O.cast_shadow(ci, c, spread * 1.1, hgt * 0.7, 0.26 if alive else 0.32)
	if alive:
		ci.draw_circle(c + Vector2(0, -hgt * 0.15), spread * 0.5, Color(col("ravive", "lueur"), 0.07))
	var items := []
	for i in n:
		var u: float = (i + 0.5) / n - 0.5
		var foot := c + Vector2(u * spread + r.randf_range(-0.08, 0.08) * spread, r.randf_range(-0.12, 0.06) * spread * 0.5)
		var h := hgt * (1.0 - absf(u) * 1.1) * r.randf_range(0.75, 1.05)
		items.append([foot, maxf(h, hgt * 0.25), u, i])
	# Les plus hauts derrière (dessinés d'abord), puis de l'arrière vers l'avant.
	items.sort_custom(func(a, b): return a[0].y < b[0].y)
	for it in items:
		var h: float = it[1]
		var wid := maxf(h * r.randf_range(0.13, 0.18), 1.6)
		prism(ci, it[0], wid, h, it[2] * h * 0.5 + r.randf_range(-0.05, 0.05) * h, nacre if int(it[3]) % 3 == 1 else glass)
	if alive:
		for i in 2 + r.randi() % 2:
			var p := c + Vector2(r.randf_range(-0.6, 0.6) * spread, r.randf_range(0.0, 0.18) * spread)
			star(ci, p, maxf(2.2, spread * 0.07), col("ravive", "fleur") if i % 2 == 0 else col("ravive", "fleur_2"), col("ravive", "fleur_coeur"))
	else:
		# Fentes de lumière éteinte : un trait sombre au pied.
		ci.draw_line(c + Vector2(-spread * 0.3, 1.0), c + Vector2(spread * 0.25, 2.0), Color(col("fletri", "matiere"), 0.5), 1.0, true)


## Fleur d'aube : étoile à six pointes (nacre ou or), cœur d'or.
static func star(ci: CanvasItem, c: Vector2, r: float, petal: Color, heart: Color) -> void:
	var pts := PackedVector2Array()
	for k in 12:
		pts.append(c + Vector2.from_angle(TAU * k / 12.0 - PI / 2.0) * r * (1.3 if k % 2 == 0 else 0.6) * Vector2(1.0, 0.8))
	O.poly(ci, pts, petal)
	ci.draw_circle(c + Vector2(-0.2, -0.2), r * 0.42, heart)


## Petite étincelle en croix (reflet qui accroche la lumière).
static func spark(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	ci.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), color, maxf(0.8, r * 0.18), true)
	ci.draw_line(c - Vector2(0, r * 1.4), c + Vector2(0, r * 1.4), color, maxf(0.8, r * 0.18), true)


## Bloc de calcaire en strates (dessus plat, flancs striés), pied en c, demi-largeur w, hauteur h.
static func block(ci: CanvasItem, c: Vector2, w: float, h: float, r: RandomNumberGenerator, etat: String) -> PackedVector2Array:
	var rock := pal(etat, "roche")
	var pts := PackedVector2Array()
	var n := 10
	var rot := r.randf_range(-0.1, 0.1)
	for i in n:
		var a := PI + TAU * i / n
		var k := r.randf_range(0.88, 1.08)
		var y := sin(a)
		# Dessus plat et un peu penché, base arrondie (vue de trois quarts).
		var py := -h * 0.92 * k + rot * cos(a) * w if y < -0.35 else h * 0.18 * y - h * 0.06
		pts.append(c + Vector2(cos(a) * w * k, py))
	O.part(ci, pts, rock, 1.5, 0.8, 0.4)
	# Strates : lignes presque horizontales sur le flanc, liseré clair dessus.
	for i in 3:
		var y := -h * (0.22 + 0.22 * i)
		var x0 := -w * (0.85 - 0.08 * i)
		var x1 := w * (0.8 - 0.12 * i)
		var line := PackedVector2Array([c + Vector2(x0, y), c + Vector2(lerpf(x0, x1, 0.5), y + h * 0.02), c + Vector2(x1, y + h * 0.05)])
		O.brush(ci, line, maxf(1.0, h * 0.025), Color(rock["ombre"].darkened(0.25), 0.8), 0.3, 0.3)
		O.brush(ci, Transform2D(0.0, Vector2(0, -1.4)) * line, maxf(0.7, h * 0.012), Color(rock["reflet"], 0.45), 0.3, 0.3)
	# Arête du dessus, éclairée.
	ci.draw_line(c + Vector2(-w * 0.75, -h * 0.9), c + Vector2(w * 0.55, -h * 0.92), Color(rock["reflet"], 0.7), maxf(1.0, h * 0.02), true)
	return pts

## Poussière de verre sur une arête (flétri).
static func ci_dust(ci: CanvasItem, c: Vector2, w: float, r: RandomNumberGenerator) -> void:
	for i in 6:
		ci.draw_circle(c + Vector2(r.randf_range(-0.8, 0.8) * w, r.randf_range(-0.05, 0.05) * w), 0.9, Color(col("fletri", "cendre"), 0.6))
