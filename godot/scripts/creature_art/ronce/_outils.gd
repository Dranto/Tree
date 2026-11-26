## Outils communs aux Flétris de Ronce (« Bestiaire d'herbier ») : marque de l'élite (collier de ronce
## tressée + liseré doré autour de la silhouette), épines d'os, petites pattes d'insecte.
## Ce fichier ne dessine aucune sorte (son nom commence par « _ » : aucune sorte de enemies.json).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")

const BONE := 0.3


static func bone() -> Dictionary:
	return {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(BONE), "reflet": Color.WHITE}


static func pal(ton_ombre := 0.0) -> Dictionary:
	return {"clair": Art.bc("ronce", "clair").darkened(ton_ombre), "ombre": Art.bc("ronce", "ombre").darkened(ton_ombre), "reflet": Art.bc("ronce", "reflet")}


static func stem() -> Dictionary:
	var d := Art.bc("ronce", "detail")
	return {"clair": d, "ombre": d.darkened(0.4), "reflet": d.lightened(0.4)}


## Liseré doré de l'élite : un fil d'or autour de la forme principale, dessiné avant elle (il dépasse
## de l'encre). En silhouette noire, il épaissit la silhouette d'autant.
static func rim(ci: CanvasItem, xf: Transform2D, pts: PackedVector2Array, ink := 2.4) -> void:
	var k := xf.get_scale().abs().x
	var w := xf * pts
	var col := Color.BLACK if Ink.mono else Ink.shade(Art.c("or"))
	for poly in Geometry2D.offset_polygon(w, (ink * Ink.INK + 2.2) * k, Geometry2D.JOIN_ROUND):
		Art.safe_polygon(ci, poly, col)


## Collier de l'élite : une ronce tressée (deux brins qui se croisent) autour du point c, de demi-axes
## rx, ry, avec des épines d'os et trois perles d'or. front : côté visible (0 → 1) ; t anime les perles.
## region : la région où se trouve l'élite (le collier prend sa couleur, ronce par défaut).
static func collar(ci: CanvasItem, xf: Transform2D, c: Vector2, rx: float, ry: float, t := 0.0, region := "ronce") -> void:
	var reg := region if Art.BESTIAIRE.get(region, null) is Dictionary else "ronce"
	var cane := Art.bc(reg, "detail").darkened(0.15)
	for s: float in [0.0, PI]:
		var pts := PackedVector2Array()
		for i in 13:
			var a := lerpf(-0.15, PI + 0.15, i / 12.0)
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry + sin(a * 6.0 + s) * 2.2))
		Ink.brush(ci, xf, pts, 5.6, Ink.encre(), 1.0, 1.0)
		Ink.brush(ci, xf, pts, 3.2, cane.lightened(0.12 if s == 0.0 else 0.0), 1.0, 1.0)
	for i in 4:
		var a := 0.35 + i * 0.8
		var p := c + Vector2(cos(a) * rx, sin(a) * ry)
		Ink.part(ci, xf, Ink.thorn(p, a + 0.2, 6.0, 3.0), bone(), 0.9, 1.0, 0.0)
	for i in 3:
		var a := 0.8 + i * 0.75
		var p := c + Vector2(cos(a) * rx, sin(a) * ry + 2.0)
		Ink.part(ci, xf, Ink.oval(p, 2.6, 2.6, 10), {"clair": Art.c("or").lightened(0.2), "ombre": Art.c("or").darkened(0.35), "reflet": Color.WHITE}, 1.0, 1.0, 0.8 + 0.2 * sin(t * 3.0 + i))


## Patte d'insecte (hanche → genou → pied, repère local), encre puis couleur, griffe au bout.
static func leg(ci: CanvasItem, xf: Transform2D, hip: Vector2, foot: Vector2, col: Color, w := 3.4, lift := 6.0) -> void:
	var out := -1.0 if foot.x < hip.x else 1.0
	var knee := Vector2(hip.x + (foot.x - hip.x) * 0.45 + out * 3.0, minf(hip.y, foot.y) - lift)
	var pts := PackedVector2Array([hip, knee, foot])
	Ink.brush(ci, xf, pts, w + 2.2, Ink.encre(), 1.0, 0.5)
	Ink.brush(ci, xf, pts, w, col, 1.0, 0.4)
	Ink.brush(ci, xf, PackedVector2Array([hip.lerp(knee, 0.3), knee]), w * 0.3, col.lightened(0.4))
	Ink.brush(ci, xf, PackedVector2Array([foot, foot + Vector2(out * 3.5, 0.5)]), 1.6, Ink.encre(), 1.0, 0.0)
	# Petite épine au tibia (insecte de ronce).
	Ink.part(ci, xf, Ink.thorn(knee.lerp(foot, 0.4), (0.0 if out > 0 else PI) - 0.9 * out, 4.0, 2.0), bone(), 0.7, 1.0, 0.0)


## Œil de braise, plissé sous un coup ou au clignement (salt décale le clignement).
static func eye(ci: CanvasItem, xf: Transform2D, p: Vector2, a: float, l: float, w: float, glow: float, hit: float, t: float, k: float, salt: float) -> void:
	if hit > 0.4 or (k == 0.0 and Ink.blink(t, salt) > 0.0):
		Ink.brush(ci, xf, PackedVector2Array([p - Vector2.from_angle(a) * l * 0.1, p + Vector2.from_angle(a) * l * 0.9]), w * 0.55, Ink.encre())
	else:
		Ink.ember(ci, xf, Ink.leaf(p, a, l, w), glow)


## Rotation d'un repère local autour du point p (tête qui suit la cible).
static func turn(xf: Transform2D, p: Vector2, a: float) -> Transform2D:
	return xf * Transform2D(a, p) * Transform2D(0.0, -p)


## Angle de la cible dans le repère du dessin (regard vers +x), et sens du retournement.
static func aim(look: float) -> Array:
	var flip := cos(look) < 0.0
	return [flip, wrapf(PI - look if flip else look, -PI, PI)]
