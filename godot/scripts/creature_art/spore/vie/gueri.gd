## Formes guéries des Flétris de Spore (tâche F) : la limace aux trois champignons, la vesse double, la
## petite vesse à filaments, le cloporte lichené. Chair mauve de la région, chapeaux crème, lichen gris-vert,
## vert sève ; jamais de braise. Contrat : creature_art/vie/outils.gd.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vie/outils.gd")

const FORMES := {
	"traine_vase": {"h": 55.0, "v": 14.0, "poses": {"repos": 2, "marche": 4}},
	"scissipore": {"h": 55.0, "v": 26.0, "poses": {"repos": 2, "marche": 4}},
	"sporule": {"h": 41.0, "v": 44.0, "poses": {"repos": 2, "marche": 4}},
	"lichen": {"h": 58.0, "v": 22.0, "poses": {"repos": 2, "marche": 4}},
}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var xf := Ink.frame(feet, h, false)
	match o.get("sp", ""):
		"traine_vase": _limace(ci, xf, o)
		"scissipore": _vesse_double(ci, xf, o)
		"sporule": _vesse(ci, xf, o)
		"lichen": _cloporte(ci, xf, o)


static func _cap_pal() -> Dictionary:
	return {"clair": Art.bc("spore", "chapeau"), "ombre": Art.bc("spore", "chapeau_ombre"), "reflet": Color("fffaf0")}


static func _mushroom(ci: CanvasItem, xf: Transform2D, b: Vector2, s: float, lean: float) -> void:
	V.part(ci, xf, PackedVector2Array([b + Vector2(-2.2 * s, 0), b + Vector2(-1.8 * s + lean * 0.5, -7 * s), b + Vector2(1.8 * s + lean * 0.5, -7 * s), b + Vector2(2.2 * s, 0)]), V.cream(), 1.0, 1.0, 0.4)
	var cap := Ink.oval(b + Vector2(lean * 0.6, -8.5 * s), 6.5 * s, 4.6 * s, 18, lean * 0.02)
	for i in cap.size():
		cap[i].y = minf(cap[i].y, b.y - 7.5 * s)
	V.part(ci, xf, cap, _cap_pal(), 1.3, 1.0, 0.8)
	V.blob(ci, xf, b + Vector2(-1.5 * s + lean * 0.6, -11.0 * s), 1.1 * s, 0.9 * s, V.cream(), 0.0, 0.0, 0.0)


## Limace des marais : un corps mauve luisant qui ondule, deux cornes oculaires, trois champignons sur le dos.
static func _limace(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 30.0)
	var body := V.pal("spore")
	var belly := V.tint(V.cream(), Color("d8c0f0"), 0.4)
	# Pied de la limace (bande plus claire au sol), puis dos bombé qui ondule.
	var pts := PackedVector2Array()
	var low := PackedVector2Array()
	for i in 17:
		var u := i / 16.0
		var x := -36.0 + 78.0 * u
		var wave := sin(walk - u * 6.0) * 1.6 * mv
		var hgt := 30.0 * sin(PI * pow(u, 0.7)) * (1.0 + 0.04 * br) + 4.0 + 6.0 * smoothstep(0.78, 1.0, u)
		pts.append(Vector2(x, -hgt - wave))
		low.append(Vector2(x, -1.5 + wave * 0.4))
	low.reverse()
	pts.append_array(low)
	V.part(ci, xf, pts, body, 2.0, 1.0, 0.9)
	V.flat(ci, xf, PackedVector2Array([Vector2(-34, -2), Vector2(40, -2), Vector2(38, -7), Vector2(-30, -6)]), belly["clair"], 0.0)
	# Cornes oculaires et tête.
	for k in [0, 1]:
		var base := Vector2(34 + 4 * k, -30)
		var tip := base + Vector2(6 + 3 * k, -14 - 2 * k + 1.5 * br)
		V.stroke(ci, xf, PackedVector2Array([base, base.lerp(tip, 0.5) + Vector2(-2, 0), tip]), 2.6, body["clair"])
		V.eye(ci, xf, tip + Vector2(0, -1), 3.0, 0.0)
	# Trois champignons sur le dos.
	_mushroom(ci, xf, Vector2(-14, -24), 1.15, -2.0)
	_mushroom(ci, xf, Vector2(2, -31), 1.4, 1.0)
	_mushroom(ci, xf, Vector2(18, -29), 0.9, 2.0)
	V.sprout(ci, xf, Vector2(-26, -12), -1.9, 7.0, V.sap(), br, 1)


## Vesse-de-loup double : deux boules crème soudées, un pli doux entre elles, un faisceau de filaments blancs.
static func _vesse_double(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 26.0)
	var cp := _cap_pal()
	var up := -absf(sin(walk)) * 3.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, up)) * xf
	# Filaments de mycélium : sept fils qui trottent.
	for i in 7:
		var hx := -14.0 + i * 5.0
		var f := V.foot(Vector2(hx + 1.0, 0.0), walk, i * 1.7, 5.0, 4.0, mv)
		V.stroke(ci, xf, PackedVector2Array([Vector2(hx, -14 + up), Vector2(hx + (f.x - hx) * 0.3, -8), f]), 1.6, Color("f2ead8") if i % 2 == 0 else Color("d0c4a8"))
	V.blob(ci, x2, Vector2(-12, -34), 17.0, 16.0 + 0.8 * br, V.tint(cp, Color("d8b8f0"), 0.25), 2.0, 0.0, 0.8)
	V.blob(ci, x2, Vector2(11, -32), 17.0, 15.0 + 0.6 * br, cp, 2.0, 0.0, 0.9)
	# Petites verrues de vesse et pore au sommet.
	for q in [Vector2(-18, -42), Vector2(-9, -46), Vector2(2, -42), Vector2(10, -44), Vector2(18, -38), Vector2(-4, -30), Vector2(20, -28)]:
		V.blob(ci, x2, q, 1.5, 1.3, V.cream(), 0.0, 0.0, 0.0)
	V.eye(ci, x2, Vector2(14, -34), 3.6, 0.0)
	V.eye(ci, x2, Vector2(22, -32), 3.0, 0.0)
	V.sprout(ci, x2, Vector2(-14, -49), -1.7, 9.0, V.sap(), br, 1)


## Petite vesse : une boule crème, un grand œil rond, quatre filaments qui trottent, un souffle de spores.
static func _vesse(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 17.0)
	var up := -absf(sin(walk)) * 5.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, up)) * xf
	for i in 4:
		var hx := -9.0 + i * 6.0
		var f := V.foot(Vector2(hx + 1.0, 0.0), walk, i * PI * 0.5, 5.0, 6.0, mv)
		V.stroke(ci, xf, PackedVector2Array([Vector2(hx, -24 + up), Vector2(hx + (f.x - hx) * 0.4, -12), f]), 1.7, Color("e8dfc8"))
	V.blob(ci, x2, Vector2(0, -42), 21.0, 20.0 + 1.0 * br, _cap_pal(), 2.0, 0.0, 0.9)
	V.eye(ci, x2, Vector2(8, -42), 6.0, 0.0, Vector2(0.6, 0.1))
	for q in [Vector2(-12, -54), Vector2(-4, -58), Vector2(-16, -42), Vector2(-9, -32)]:
		V.blob(ci, x2, q, 1.6, 1.4, V.cream(), 0.0, 0.0, 0.0)
	# Quelques spores qui s'envolent.
	for i in 3:
		var u := fposmod(t * 0.5 + i * 0.33, 1.0)
		x2 = Transform2D(0.0, Vector2(0, up)) * xf
		var q := x2 * Vector2(-4.0 + i * 7.0 + sin(u * 6.0) * 3.0, -64.0 - u * 14.0)
		ci.draw_circle(q, 1.5 * xf.get_scale().x, Color(Art.bc("spore", "spore"), 0.8 * (1.0 - u)))
	V.sprout(ci, x2, Vector2(2, -61), -1.6, 8.0, V.sap(), br, 1)


## Cloporte lichené : plaques bombées mauves, plaques de lichen et petit polypore, sept pattes fines, antennes.
static func _cloporte(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 36.0)
	var shell := V.pal("spore", 0.15)
	var lich := {"clair": Art.bc("spore", "lichen"), "ombre": Art.bc("spore", "lichen_ombre"), "reflet": Color("e4f0d0")}
	for i in 4:
		var hx := -22.0 + i * 14.0
		var f := V.foot(Vector2(hx + 3.0, 0.0), walk, i * 1.6 + PI, 6.0, 5.0, mv)
		V.limb(ci, xf, Vector2(hx, -12), Vector2(hx + 8, -6), f, 2.6, shell["ombre"])
	var rise := absf(sin(walk)) * 1.5 * mv
	var x2 := Transform2D(0.0, Vector2(0, -rise)) * xf
	# Carapace : sept plaques en arcs.
	var plates := 6
	for i in plates:
		var u := float(i) / (plates - 1)
		var cx := -26.0 + 46.0 * u
		var ph := 20.0 + 9.0 * sin(PI * (0.15 + 0.7 * u)) + 0.8 * br
		V.part(ci, x2, Ink.oval(Vector2(cx, -ph * 0.5 - 4.0), 10.5, ph * 0.5 + 3.0, 16), shell, 1.5, 1.0, 0.8)
	# Lichen et polypore posés sur les plaques.
	V.part(ci, x2, Ink.lumpy(Vector2(-10, -30), 10.0, 5.0, 14, 0.2, 6.0), lich, 1.2, 1.0, 0.5)
	V.part(ci, x2, Ink.lumpy(Vector2(6, -34), 8.0, 4.4, 12, 0.2, 5.0), lich, 1.2, 1.0, 0.5)
	V.blob(ci, x2, Vector2(-1, -28), 6.5, 2.8, _cap_pal(), 1.2, 0.0, 0.6)
	# Tête sous le bord, deux yeux et deux antennes.
	V.part(ci, x2, Ink.oval(Vector2(28, -14), 9.0, 8.0, 16), V.pal("spore", 0.3), 1.6, 1.0, 0.6)
	V.eye(ci, x2, Vector2(31, -16), 3.0, 0.0)
	V.stroke(ci, x2, PackedVector2Array([Vector2(33, -20), Vector2(40, -28 + 2 * br), Vector2(45, -27)]), 1.0, shell["ombre"])
	V.sprout(ci, x2, Vector2(-18, -38), -1.6, 8.0, V.sap(), br, 1)
