## Outils partagés des Flétris de la forêt pétrifiée (Racine), « Bestiaire d'herbier » : lecture de la
## pose, palettes (écorce devenue pierre, bois, chair de racine), patte d'insecte articulée, collier
## d'élite (racine tressée, perles d'ambre, liseré doré) et braises d'étourdissement.
##
## Famille : coléoptères, bois et pierre. Corps gris-beige de pierre veinée (Art.bc("racine", …)),
## bois sombre, lichens clairs ; la braise (yeux, fentes) est le signe commun de l'ennemi.
## Pas une sorte de enemies.json : le moteur ne cherche que creature_art/<région>/<id>.gd.
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")


## Pose commune lue une fois : t, walk, moving, k, state, strike (-1 : aucune), hit (ou flash), look,
## flip (regard vers la gauche) et la (angle du regard ramené vers la droite).
static func read(o: Dictionary) -> Dictionary:
	var look: float = o.get("look", 0.0)
	var flip := cos(look) < 0.0
	var hit: float = o.get("hit", o.get("flash", 0.0))
	return {
		"t": float(o.get("t", 0.0)), "walk": float(o.get("walk", 0.0)), "mv": float(o.get("moving", 0.0)),
		"k": float(o.get("k", 0.0)), "state": String(o.get("state", "")), "strike": float(o.get("strike", -1.0)),
		"hit": hit, "look": look, "flip": flip, "la": wrapf(PI - look if flip else look, -PI, PI),
		"elite": bool(o.get("elite", false)),
	}


## Palette à deux tons + reflet d'un nom de Art.BESTIAIRE["racine"] : « pierre » (clair/ombre/reflet de
## la région), « bois », « chair » (racine vivante de la mandragore), « cendre » (termite).
static func pal(nom := "pierre") -> Dictionary:
	match nom:
		"bois":
			return {"clair": Art.bc("racine", "bois"), "ombre": Art.bc("racine", "bois_ombre"), "reflet": Art.bc("racine", "bois").lightened(0.35)}
		"chair":
			return {"clair": Art.bc("racine", "chair"), "ombre": Art.bc("racine", "chair_ombre"), "reflet": Art.bc("racine", "chair").lightened(0.4)}
		"cendre":
			return {"clair": Art.bc("racine", "cendre"), "ombre": Art.bc("racine", "cendre_ombre"), "reflet": Art.bc("racine", "cendre").lightened(0.35)}
		"os":
			return {"clair": Art.bc("os"), "ombre": Art.bc("os").darkened(0.35), "reflet": Color.WHITE}
		"feuille":
			return {"clair": Art.bc("racine", "feuille"), "ombre": Art.bc("racine", "feuille").darkened(0.4), "reflet": Art.bc("racine", "feuille").lightened(0.35)}
	return {"clair": Art.bc("racine", "clair"), "ombre": Art.bc("racine", "ombre"), "reflet": Art.bc("racine", "reflet")}


## Patte articulée d'insecte : hanche (écran) → genou haut → pied (local), griffe et épine au tibia.
## w : épaisseur (1 : celle du scarabée).
static func leg(ci: CanvasItem, base: Transform2D, hip_w: Vector2, foot: Vector2, col: Color, w := 1.0) -> void:
	var hip := base.affine_inverse() * hip_w
	var out := -1.0 if foot.x < hip.x else 1.0
	var knee := Vector2(hip.x + (foot.x - hip.x) * 0.4 + out * 4.0 * w, minf(hip.y, foot.y) - 6.0 * w)
	var pts := PackedVector2Array([hip, knee, foot])
	Ink.brush(ci, base, pts, 5.6 * w, Ink.encre(), 1.0, 0.5)
	Ink.brush(ci, base, pts, 3.4 * w, col, 1.0, 0.4)
	Ink.brush(ci, base, PackedVector2Array([hip.lerp(knee, 0.3), knee]), 1.0 * w, col.lightened(0.4))
	ci.draw_circle(base * knee, 1.3 * w * base.get_scale().abs().x, Ink.shade(col.lightened(0.25)) if not Ink.mono else Color.BLACK)
	Ink.brush(ci, base, PackedVector2Array([foot, foot + Vector2(out * 3.5 * w, 0.5)]), 1.6 * w, Ink.encre(), 1.0, 0.0)
	Ink.brush(ci, base, PackedVector2Array([knee.lerp(foot, 0.45), knee.lerp(foot, 0.45) + Vector2(out * 4.0 * w, -2.0 * w)]), 1.6 * w, Ink.encre(), 1.0, 0.0)


## Collier d'élite de la forêt pétrifiée : une racine tressée posée en travers (de a à b, bombée de
## sag), perles d'ambre, et le liseré doré le long du bord éclairé (edge, repère local).
static func elite(ci: CanvasItem, xf: Transform2D, a: Vector2, b: Vector2, sag: float, edge: PackedVector2Array, t: float, w := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		pts.append(a.lerp(b, u) + Vector2(0, sag * sin(PI * u)))
	# Liseré doré : un trait fin au bord éclairé de la forme principale.
	if not edge.is_empty():
		Ink.brush(ci, xf, edge, 1.9 * w, Ink.encre(), 1.0, 1.0)
		Ink.brush(ci, xf, edge, 1.1 * w, Art.c("or"), 1.0, 1.0)
	# Tresse : deux brins qui s'enroulent.
	Ink.brush(ci, xf, pts, 6.2 * w, Ink.encre(), 1.0, 1.0)
	Ink.brush(ci, xf, pts, 4.0 * w, Art.bc("racine", "bois"), 1.0, 1.0)
	for i in 8:
		var q := pts[i].lerp(pts[i + 1], 0.5)
		var d := (pts[i + 1] - pts[i]).normalized()
		Ink.brush(ci, xf, PackedVector2Array([q - d * 2.2 * w + d.orthogonal() * 1.6 * w, q + d * 2.2 * w - d.orthogonal() * 1.6 * w]), 1.0 * w, Art.bc("racine", "bois_ombre"))
	Ink.brush(ci, xf, pts, 0.9 * w, Art.c("or"), 0.6, 0.6)
	# Perles d'ambre (celle du milieu plus grosse), qui luisent doucement.
	for j in 3:
		var q := pts[2 + j * 2] + Vector2(0, 3.2 * w)
		var r := (2.6 if j == 1 else 1.9) * w
		Ink.part(ci, xf, Ink.oval(q, r, r * 1.15, 12), {"clair": Art.c("or").lightened(0.15), "ombre": Art.bc("racine", "detail").darkened(0.2), "reflet": Color.WHITE}, 1.0, 1.0, 1.0)
	if not Ink.mono:
		Ink.halo(ci, xf * (pts[4] + Vector2(0, 3.2 * w)), 4.0 * w * xf.get_scale().abs().x, Art.c("or"), 0.6 + 0.3 * sin(t * 2.0))


## Sonné (récupération après un coup manqué) : trois braises tournent au-dessus de p (repère local).
static func dazed(ci: CanvasItem, xf: Transform2D, p: Vector2, t: float, rx: float, k := 1.0) -> void:
	if Ink.mono or k <= 0.0:
		return
	for i in 3:
		var a := t * 5.0 + i * TAU / 3.0
		var q := p + Vector2(cos(a) * rx, sin(a) * rx * 0.3)
		var s := 2.0 * xf.get_scale().abs().x * (0.8 + 0.3 * sin(a))
		ci.draw_circle(xf * q, s * 1.8, Color(Art.bc("braise"), 0.25 * k))
		ci.draw_circle(xf * q, s, Color(Art.bc("braise_coeur"), k))


## Poussière soulevée au sol (repère local, autour de p) : n bouffées qui s'éloignent selon dir.
static func dust(ci: CanvasItem, xf: Transform2D, p: Vector2, dir: Vector2, n: int, t: float, size: float, k: float) -> void:
	if Ink.mono or k <= 0.0:
		return
	var col := Art.bc("racine", "reflet")
	for i in n:
		var u := fposmod(t * 2.2 + float(i) / n, 1.0)
		var q := p + dir * u * 26.0 + Vector2(sin(i * 2.3) * 6.0, -u * 9.0 - i * 1.5)
		ci.draw_circle(xf * q, (size + size * 1.2 * u) * xf.get_scale().abs().x, Color(col, 0.38 * (1.0 - u) * k))
