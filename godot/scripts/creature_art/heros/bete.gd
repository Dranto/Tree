## Piste B, « Bête-graine » : un petit animal-graine à grandes oreilles qui devient une bête fière,
## mi-renard mi-cerf. En grandissant : pattes longues, museau effilé, crinière de feuilles le long du cou
## et du dos, bois qui poussent et se ramifient, grande queue dont la pointe est la graine-lanterne.
## La couleur de la branche passe dans les marques des flancs, l'intérieur des oreilles et les bois.
## Pose : t, walk, moving, look, hit, build, evol (0 → 1) ou stade (1 → 3).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const K = preload("res://scripts/creature_art/heros/commun.gd")
const Sylve = preload("res://scripts/creature_art/heros/sylve.gd")

const HEIGHT := 56.0


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var look: float = o.get("look", 0.0)
	var build: String = o.get("build", "aucun")
	var p := K.progress(o)
	var flip := cos(look) < 0.0
	Ink.flash = o.get("hit", 0.0)
	var base := Ink.frame(feet, h * (0.62 + 0.38 * p), flip)
	var u := base.get_scale().y
	var acc := K.accent(build)
	var gl := K.glow(build)
	var lv := K.leaves(build)
	var dark := {"clair": lv["ombre"], "ombre": lv["ombre"].darkened(0.35), "reflet": lv["clair"]}
	var fur := {"clair": K.CREME, "ombre": K.CREME.darkened(0.2).lerp(Color("b49a7a"), 0.3), "reflet": Color.WHITE}
	var furfar := {"clair": fur["ombre"], "ombre": fur["ombre"].darkened(0.2), "reflet": fur["clair"]}
	K.aura(ci, base, t, p, acc)
	var legl := 9.0 + 17.0 * p
	var bl := 12.0 + 13.0 * p
	var bh := 10.0 + 2.0 * p
	var breath := sin(t * TAU / 2.4)
	var bob := breath * 0.8 - absf(sin(walk)) * 2.5 * mv
	var xf := base * Transform2D(0.0, Vector2(0, bob))
	var bc := Vector2(-2.0 - 3.0 * p, -legl - bh + 2.0)
	var hc := Vector2(bc.x + bl + 3.0 + 3.0 * p, bc.y - bh - 5.0 - 11.0 * p)
	var hr := 11.0 - 1.0 * p
	Ink.ground_shadow(ci, base, Vector2(bc.x, 0), bl + 8.0)
	var sw := sin(walk) * 6.0 * mv
	# Queue : épaisse, relevée, pointe en graine-lanterne.
	var lt := 14.0 + 30.0 * p
	var tb := Vector2(bc.x - bl * 0.9, bc.y - bh * 0.3)
	var tail := PackedVector2Array()
	for i in 8:
		var k := i / 7.0
		tail.append(tb + Vector2(-lt * 0.55 * sin(k * 1.6), -lt * k + sin(k * 3.0 + t * 2.2) * 3.0 * k))
	Ink.brush(ci, xf, tail, 11.0 + 6.0 * p, Ink.encre(), 0.6, 0.0)
	Ink.brush(ci, xf, tail, 8.6 + 5.0 * p, K.CREME, 0.6, 0.0)
	var tip_part := PackedVector2Array([tail[4], tail[5], tail[6], tail[7]])
	Ink.brush(ci, xf, tip_part, 7.0 + 4.0 * p, lv["clair"], 0.5, 0.0)
	K.seed(ci, xf * (tail[7] + Vector2(-1, -3)), u, p, t, gl, 4.0 + 1.4 * p)
	# Pattes du fond.
	_leg(ci, xf, Vector2(bc.x + bl * 0.55, bc.y + bh * 0.2), legl, sw, false, furfar, p)
	_leg(ci, xf, Vector2(bc.x - bl * 0.55, bc.y + bh * 0.2), legl, -sw, true, furfar, p)
	# Bois (côté du fond).
	if p > 0.25:
		Sylve._antler(ci, xf, hc + Vector2(-hr * 0.45, -hr * 0.7), -1.0, p, build, acc, gl, t, true)
	# Oreille du fond.
	_ear(ci, xf, hc + Vector2(-hr * 0.55, -hr * 0.55), -2.3, p, furfar, acc, t)
	# Corps.
	var body := Ink.oval(bc, bl, bh * (1.0 + 0.02 * breath), 36)
	Ink.part(ci, xf, body, fur, 2.2, 1.0, 0.7)
	Ink.flat(ci, xf, Ink.oval(bc + Vector2(bl * 0.1, bh * 0.45), bl * 0.7, bh * 0.4, 20), Color(Color.WHITE, 0.35))
	# Marques des flancs.
	if p > 0.3:
		var k := clampf((p - 0.3) / 0.5, 0.0, 1.0)
		for i in 3:
			var x := bc.x - bl * 0.3 + i * bl * 0.28
			Ink.flat(ci, xf, Ink.leaf(Vector2(x, bc.y - bh * 0.85), PI * 0.5 + 0.35, bh * 0.9 * k, 3.4 - i * 0.5), acc)
	# Crinière de feuilles le long du dos et du cou.
	var nm := 2 + roundi(7.0 * p)
	for i in nm:
		var k := i / maxf(nm - 1, 1)
		var q := Vector2(lerpf(bc.x - bl * 0.6, hc.x - hr * 0.5, k), lerpf(bc.y - bh * 0.95, hc.y + hr * 0.2, k * k))
		K.leaf(ci, xf, q, PI * 1.25 + 0.1 * sin(t * 2.0 + i), 7.0 + 8.0 * p, 4.4 + 1.5 * p, lv if i % 2 == 0 else dark, 0.06, 1.0)
	# Cou.
	var neck := PackedVector2Array([Vector2(bc.x + bl * 0.55, bc.y - bh * 0.6), Vector2(bc.x + bl * 0.85, bc.y - bh * 0.1), hc + Vector2(hr * 0.2, hr * 0.6), hc + Vector2(-hr * 0.6, hr * 0.1)])
	Ink.part(ci, xf, neck, fur, 2.0, 1.0, 0.4)
	# Collerette (poitrail) de feuilles claires, plus fournie à maturité.
	if p > 0.4:
		for i in 3:
			K.leaf(ci, xf, Vector2(bc.x + bl * 0.8, bc.y - bh * 0.2 + i * 3.0), PI * 0.3 + i * 0.25, 7.0 + 5.0 * p, 4.0, {"clair": K.CREME.lightened(0.3), "ombre": K.CREME.darkened(0.15)}, 0.0, 0.9)
	# Pattes de devant.
	_leg(ci, xf, Vector2(bc.x + bl * 0.6 + 3.0, bc.y + bh * 0.3), legl, -sw, false, fur, p)
	_leg(ci, xf, Vector2(bc.x - bl * 0.5 + 3.0, bc.y + bh * 0.3), legl, sw, true, fur, p)
	# Tête : crâne rond, museau qui s'allonge, truffe.
	var sn := 4.0 + 10.0 * p
	var head := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		var d := Vector2(cos(a), sin(a))
		var q := hc + d * hr
		if d.x > 0.2 and d.y > -0.4:
			q.x += sn * (d.x - 0.2) * (1.0 - absf(d.y + 0.05) * 0.9)
			q.y -= (d.y - 0.1) * sn * 0.25 * (d.x - 0.2)
		head.append(q)
	Ink.part(ci, xf, head, fur, 2.2, 1.0, 0.8)
	Ink.flat(ci, xf, Ink.oval(hc + Vector2(hr * 0.6 + sn * 0.6, hr * 0.15), hr * 0.25 + sn * 0.25, hr * 0.28, 14), Color(Color.WHITE, 0.4))
	var nose := hc + Vector2(hr * 0.75 + sn * 0.85, hr * 0.02)
	Ink.flat(ci, xf, Ink.oval(nose, 2.4, 1.8, 10), Ink.encre())
	Ink.brush(ci, xf, PackedVector2Array([nose + Vector2(-1.5, 2.5), nose + Vector2(-sn * 0.45, 4.5), nose + Vector2(-sn * 0.7 - 2.0, 3.2)]), 1.2, Ink.encre(), 0.3, 0.3)
	# Joue et marque de branche sous l'œil.
	if p > 0.2:
		Ink.flat(ci, xf, Ink.leaf(hc + Vector2(hr * 0.1, hr * 0.15), 0.35, hr * 0.7 * clampf((p - 0.2) * 2.0, 0.0, 1.0), 2.8), acc)
	# Yeux.
	var closed: bool = o.get("hit", 0.0) > 0.3 or Ink.blink(t, 0.4) > 0.0
	if closed:
		Ink.brush(ci, xf, PackedVector2Array([hc + Vector2(hr * 0.05, -hr * 0.2), hc + Vector2(hr * 0.35, -hr * 0.28), hc + Vector2(hr * 0.65, -hr * 0.2)]), 1.6, Ink.encre(), 0.3, 0.3)
	else:
		K.eye(ci, xf, hc + Vector2(hr * 0.35, -hr * 0.22), 4.4 - 0.6 * p, 3.6 - 0.4 * p, -0.15 - 0.1 * p, Art.ec("seve").lerp(gl, 0.5 * p))
	# Oreille de devant et bois de devant.
	_ear(ci, xf, hc + Vector2(-hr * 0.1, -hr * 0.75), -1.95, p, fur, acc, t)
	if p > 0.25:
		Sylve._antler(ci, xf, hc + Vector2(hr * 0.15, -hr * 0.85), 1.0, p, build, acc, gl, t, false)
	# Pousse de départ entre les oreilles, qui s'efface quand les bois arrivent.
	if p < 0.5:
		var k := 1.0 - p / 0.5
		K.leaf(ci, xf, hc + Vector2(-hr * 0.2, -hr * 0.95), -2.0, 8.0 * k, 4.6 * k, lv)
		K.leaf(ci, xf, hc + Vector2(-hr * 0.2, -hr * 0.95), -0.9, 7.0 * k, 4.0 * k, lv)


static func _ear(ci: CanvasItem, xf: Transform2D, b: Vector2, a: float, p: float, pal: Dictionary, acc: Color, t: float) -> void:
	var l := 12.0 + 4.0 * p
	var w := 9.0 - 1.0 * p
	var aa := a + 0.06 * sin(t * 1.9)
	Ink.part(ci, xf, Ink.leaf(b, aa, l, w, 0.04), pal, 1.6, 1.0, 0.4)
	Ink.flat(ci, xf, Ink.leaf(b + Vector2.from_angle(aa) * 2.0, aa, l * 0.7, w * 0.45, 0.04), acc.lerp(Color("f2c8c0"), 0.5 - 0.4 * p))


## Patte : de l'épaule (ou de la hanche) au sol ; les pattes arrière ont un jarret.
static func _leg(ci: CanvasItem, xf: Transform2D, hip: Vector2, legl: float, sw: float, hind: bool, pal: Dictionary, p: float) -> void:
	var paw := Vector2(hip.x + sw, -2.0)
	var pts := PackedVector2Array([hip])
	if hind:
		pts.append(Vector2(hip.x - 4.0 - 2.0 * p, -legl * 0.55))
		pts.append(Vector2(hip.x + 1.0 + sw * 0.6, -legl * 0.22))
	else:
		pts.append(Vector2(hip.x + 1.0 + sw * 0.5, -legl * 0.5))
	pts.append(paw)
	var w := 6.0 + 1.0 * p
	Ink.brush(ci, xf, pts, w + 2.4, Ink.encre(), 1.0, 0.6)
	Ink.brush(ci, xf, pts, w, pal["clair"], 1.0, 0.6)
	Ink.part(ci, xf, Ink.oval(paw + Vector2(1.5, 0.5), 3.6 + 0.6 * p, 2.4, 12), {"clair": Color("5b4636"), "ombre": Color("3f3026")}, 1.0, 1.0, 0.0)
