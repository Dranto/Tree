## Formes guéries des Flétris de Vent (tâche F) : le faucon crécerelle, le tétras des steppes, la phalène à
## queues, la pierre levée moussue. Plumes bleu ardoise, duvet pâle, ailes ciel de la région, mousse et
## fleurs de plateau, vert sève ; jamais de braise. Contrat : creature_art/vie/outils.gd.
## La phalène a la pose « vol » : elle voltige au lieu de marcher.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")
const V = preload("res://scripts/creature_art/vie/outils.gd")

const FORMES := {
	"plongeur": {"h": 48.0, "v": 36.0, "poses": {"repos": 2, "marche": 4}},
	"souffleur": {"h": 50.0, "v": 28.0, "poses": {"repos": 2, "marche": 4}},
	"planeur": {"h": 55.0, "v": 60.0, "poses": {"vol": 4}},
	"menhir": {"h": 62.0, "v": 16.0, "poses": {"repos": 2, "marche": 4}},
}


static func draw(ci: CanvasItem, feet: Vector2, h: float, o := {}) -> void:
	var xf := Ink.frame(feet, h, false)
	match o.get("sp", ""):
		"plongeur": _faucon(ci, xf, o)
		"souffleur": _tetras(ci, xf, o)
		"planeur": _phalene(ci, xf, o)
		"menhir": _menhir(ci, xf, o)


static func _plume() -> Dictionary:
	return {"clair": Art.bc("vent", "plume"), "ombre": Art.bc("vent", "plume").darkened(0.35), "reflet": Art.bc("vent", "aile")}


static func _duvet() -> Dictionary:
	return {"clair": Art.bc("vent", "duvet"), "ombre": Art.bc("vent", "duvet").darkened(0.25), "reflet": Color.WHITE}


## Faucon crécerelle posé : dos d'ardoise, poitrail strié de pâle, moustache fine, bec crochu crème, queue en éventail.
static func _faucon(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 20.0)
	var pl := _plume()
	var hop := absf(sin(walk)) * 4.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, -hop)) * xf
	var yellow := Color("d6c27e")
	# Pattes jaunes (deux) : l'une du fond, l'autre devant.
	for i in 2:
		var f := V.foot(Vector2(2.0 + i * 8.0, 0.0), walk, i * PI, 6.0, 5.0, mv)
		V.limb(ci, xf, Vector2(2.0 + i * 7.0, -14 - hop), Vector2(3.0 + i * 7.0 + (f.x - 3) * 0.3, -7), f, 2.4, yellow)
	# Queue, corps en goutte, aile pliée, poitrail.
	V.part(ci, x2, PackedVector2Array([Vector2(-14, -22), Vector2(-34, -16), Vector2(-33, -8), Vector2(-26, -5), Vector2(-12, -14)]), V.tint(pl, Color("c9a86a"), 0.25), 1.6, 1.0, 0.5)
	V.part(ci, x2, Ink.oval(Vector2(-1, -30), 19.0, 15.0 + 0.8 * br, 24, -0.4), pl, 2.0, 1.0, 0.8)
	V.part(ci, x2, Ink.oval(Vector2(5, -27), 11.0, 11.0, 18), _duvet(), 1.4, 1.0, 0.7)
	for i in 4:
		V.stroke(ci, x2, PackedVector2Array([Vector2(1 + i * 2.4, -34 + i * 0.5), Vector2(2 + i * 2.4, -28), Vector2(1 + i * 2.4, -22)]), 0.9, pl["ombre"], false)
	V.part(ci, x2, PackedVector2Array([Vector2(-14, -34), Vector2(2, -37), Vector2(-4, -22), Vector2(-24, -12), Vector2(-20, -26)]), V.tint(pl, Color("c9a86a"), 0.2), 1.4, 1.0, 0.5)
	# Tête ronde, bec, moustache, œil jaune cerclé.
	V.part(ci, x2, Ink.oval(Vector2(11, -41), 9.0, 8.4, 18), V.tint(pl, Color("aab6c0"), 0.4), 1.6, 1.0, 0.8)
	V.part(ci, x2, PackedVector2Array([Vector2(17, -43), Vector2(25, -39), Vector2(18.5, -37.5)]), V.cream(), 1.0, 1.0, 0.3)
	V.eye(ci, x2, Vector2(14.5, -43), 2.8, 0.0)
	V.stroke(ci, x2, PackedVector2Array([Vector2(14, -39), Vector2(12, -34.5)]), 1.3, pl["ombre"], false)
	V.sprout(ci, x2, Vector2(-4, -43), -1.5, 8.0, V.sap(), br, 1)


## Tétras : gros oiseau ventru, queue en éventail dressée, jabot rond crème, œil vif.
static func _tetras(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 26.0)
	var pl := V.tint(_plume(), Color("a99060"), 0.35)
	var bob := absf(sin(walk)) * 3.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, -bob)) * xf
	for i in 2:
		var f := V.foot(Vector2(i * 10.0 - 2.0, 0.0), walk, i * PI, 6.0, 4.0, mv)
		V.limb(ci, xf, Vector2(i * 10.0 - 4.0, -15 - bob), Vector2(i * 10.0 - 3.0, -8), f, 2.6, Color("b9a07a"))
	# Éventail de plumes de queue.
	for i in 7:
		var a := -2.7 + i * 0.28
		V.part(ci, x2, Ink.leaf(Vector2(-18, -28), a, 26.0, 7.0), _plume() if i % 2 == 0 else V.tint(_plume(), Color("d8e0e8"), 0.35), 1.2, 1.0, 0.5)
	V.part(ci, x2, Ink.oval(Vector2(-2, -29), 22.0, 15.0 + 0.8 * br, 26, -0.1), pl, 2.0, 1.0, 0.8)
	# Jabot crème, dos barré, aile pliée.
	V.blob(ci, x2, Vector2(10, -26), 12.0, 12.0 + 0.8 * br, _duvet(), 1.5, 0.0, 0.7)
	for i in 5:
		V.stroke(ci, x2, PackedVector2Array([Vector2(-18 + i * 6.0, -37 + 0.5 * i), Vector2(-15 + i * 6.0, -32)]), 1.1, pl["ombre"], false)
	V.part(ci, x2, Ink.oval(Vector2(-6, -28), 13.0, 7.0, 18, 0.15), V.tint(_plume(), Color("c9a86a"), 0.25), 1.3, 1.0, 0.4)
	# Cou, tête, bec, œil et crête rouge de tétras (une petite tache vive au-dessus de l'œil).
	V.part(ci, x2, Ink.oval(Vector2(17, -39), 7.0, 9.0, 16, 0.2), pl, 1.6, 1.0, 0.7)
	V.part(ci, x2, Ink.oval(Vector2(22, -44), 7.0, 6.4, 16), pl, 1.5, 1.0, 0.8)
	V.part(ci, x2, PackedVector2Array([Vector2(27, -45), Vector2(33, -42), Vector2(27, -41)]), V.cream(), 0.9, 1.0, 0.2)
	V.flat(ci, x2, Ink.oval(Vector2(22.5, -48.2), 3.4, 1.5, 10), Color("d9573e"), 0.0)
	V.eye(ci, x2, Vector2(24, -44.5), 2.3, 0.0)
	V.sprout(ci, x2, Vector2(-8, -42), -1.4, 8.0, V.sap(), br, 1)


## Phalène à queues : ailes ciel pâle ourlées de bleu, ocelles claires, longues queues, antennes plumeuses.
static func _phalene(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var walk: float = o.get("walk", 0.0)
	var flap := sin(walk)
	var wing := {"clair": Art.bc("vent", "aile"), "ombre": Art.bc("vent", "plume"), "reflet": Color("eaf6ff")}
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 16.0)
	var c := Vector2(0, -52)
	var spread := 0.35 + 0.65 * (flap * 0.5 + 0.5)
	# Ailes du fond, puis corps, puis ailes de devant, queues effilées.
	for side in [-1.0, 1.0]:
		var base := c + Vector2(side * 3.0, -3)
		var tip := c + Vector2(side * 36.0 * spread, -26.0 * spread - 2.0)
		var low := c + Vector2(side * 26.0 * spread, 16.0)
		var fw := PackedVector2Array([base, base.lerp(tip, 0.5) + Vector2(0, -8), tip, tip.lerp(low, 0.5) + Vector2(side * 4, 0), low, c + Vector2(side * 2.0, 6)])
		V.part(ci, xf, fw, wing if side > 0 else V.tint(wing, Color("7a9ac0"), 0.25), 1.4, 1.0, 0.8)
		V.blob(ci, xf, c + Vector2(side * 20.0 * spread, -8.0 * spread), 4.2 * spread + 0.8, 3.6 * spread + 0.8, V.cream(), 1.0, 0.0, 0.6)
		V.stroke(ci, xf, PackedVector2Array([low, low + Vector2(side * 4, 18), low + Vector2(side * 2 - 3, 34 + 3 * flap)]), 2.6, wing["clair"])
	V.part(ci, xf, Ink.oval(c + Vector2(0, 4), 5.0, 14.0, 16), V.cream(), 1.5, 1.0, 0.6)
	V.blob(ci, xf, c + Vector2(0, -12), 5.4, 5.0, V.cream(), 1.4, 0.0, 0.5)
	V.eye(ci, xf, c + Vector2(2.4, -13), 2.0, 0.0)
	for side in [-1.0, 1.0]:
		V.stroke(ci, xf, PackedVector2Array([c + Vector2(side * 2, -16), c + Vector2(side * 7, -26), c + Vector2(side * 10, -30 + flap)]), 1.0, Color("6a4a3a"))


## Pierre levée moussue : un menhir râblé couvert de mousse et de fleurs de plateau, deux petits pieds de roche, deux yeux ensommeillés.
static func _menhir(ci: CanvasItem, xf: Transform2D, o: Dictionary) -> void:
	var t: float = o.get("t", 0.0)
	var walk: float = o.get("walk", 0.0)
	var mv: float = o.get("moving", 0.0)
	var br := V.breath(t)
	Ink.ground_shadow(ci, xf, Vector2(0, 0), 26.0)
	var st := V.stone()
	var up := -absf(sin(walk)) * 3.0 * mv
	var x2 := Transform2D(0.0, Vector2(0, up)) * xf
	for i in 2:
		var f := V.foot(Vector2(i * 14.0 - 12.0, 0.0), walk, i * PI, 5.0, 4.0, mv)
		V.part(ci, xf, Ink.oval(Vector2(f.x, f.y - 5.0), 8.5, 5.5, 14), V.stone(0.6 + 0.4 * i), 1.5, 1.0, 0.4)
	var rock := PackedVector2Array([Vector2(-20, -8), Vector2(-24, -34), Vector2(-18, -66), Vector2(-4, -80 - br), Vector2(12, -76), Vector2(24, -52), Vector2(22, -22), Vector2(14, -8)])
	V.part(ci, x2, rock, st, 2.2, 1.0, 0.7)
	for q in [PackedVector2Array([Vector2(-14, -22), Vector2(-4, -40), Vector2(-8, -56)]), PackedVector2Array([Vector2(10, -20), Vector2(16, -36)])]:
		V.stroke(ci, x2, q, 1.1, st["ombre"], false)
	# Mousse en cape sur le dessus et le flanc, fleurs de plateau.
	var mos := V.leafy()
	V.part(ci, x2, Ink.lumpy(Vector2(-4, -76), 18.0, 8.0, 20, 0.15, 6.0), mos, 1.6, 1.0, 0.7)
	V.part(ci, x2, Ink.lumpy(Vector2(-20, -50), 6.0, 14.0, 14, 0.2, 5.0), mos, 1.3, 1.0, 0.5)
	V.flower(ci, x2, Vector2(2, -86), 4.4, Color("fff0e6"))
	V.flower(ci, x2, Vector2(-12, -82), 3.6, Color("d8e8ff"))
	V.sprout(ci, x2, Vector2(8, -78), -1.2, 9.0, V.sap(), br, 1)
	# Visage : deux yeux en pierre claire, dans un creux ombré.
	V.blob(ci, x2, Vector2(8, -52), 12.0, 7.5, {"clair": st["ombre"], "ombre": st["ombre"].darkened(0.3), "reflet": st["ombre"]}, 0.0, 0.0, 0.0)
	V.eye(ci, x2, Vector2(4.5, -53), 3.2, 0.0, Vector2(0.2, 0.3))
	V.eye(ci, x2, Vector2(12.5, -52), 2.7, 0.0, Vector2(0.2, 0.3))
