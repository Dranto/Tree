## Dessins de la branche Sève, selon la charte (élément « seve » : couleur #8af5c0, motif « lueur ») :
## perle de sève (projectile), signatures des compétences (liane buveuse, fontaine de sève, cocon de
## sève), éclaboussure des perles, gouttes de rosée, icônes. Purement visuel : la logique est dans
## scripts/skills/ et attack.gd.
##
## skill_fx.gd et attack_fx.gd confient à SeveFx les signatures qu'il connaît (draws / draw) ;
## Art._icon_body lui confie les icônes de Sève (icon). Les dessins sont statiques (instant e["t"]) :
## la galerie les fige.
class_name SeveFx
extends RefCounted

## Durée par défaut de chaque signature (secondes) ; la liane, la fontaine et le cocon donnent la leur.
const DUREE := {
	"liane": 3.0, "liane_jet": 0.5, "fontaine": 6.0, "fontaine_geyser": 0.6,
	"cocon": 4.0, "cocon_eclat": 0.5, "perle_eclat": 0.3, "rosee": 0.45,
}
## Icônes de Sève : compétences, puis formes de l'attaque.
const ICONES_COMPETENCES := ["liane", "fontaine", "cocon"]
const ICONES_ATTAQUES := ["attaque_perle"]


static func draws(id: String) -> bool:
	return DUREE.has(id)


## Joue le son « id » s'il existe (la tâche « son » peut l'ajouter), sinon « fallback ».
static func sound(id: String, fallback: String, pos := Vector2.INF) -> void:
	var loop = Engine.get_main_loop()
	var sfx = loop.root.get_node_or_null("Sfx") if loop is SceneTree else null
	if sfx != null:
		sfx.play(id if sfx.streams.has(id) else fallback, pos)


## Dessine la signature id à son instant (e["t"], e["dur"]). on_ground : partie au sol (sous les
## acteurs) ou au-dessus.
static func draw(ci: CanvasItem, e: Dictionary, on_ground: bool) -> void:
	var k: float = clampf(e["t"] / maxf(e["dur"], 0.001), 0.0, 1.0)
	match e["id"]:
		"liane":
			_liane(ci, e, k, on_ground)
		"liane_jet":
			_liane_jet(ci, e, k, on_ground)
		"fontaine":
			_fontaine(ci, e, k, on_ground)
		"fontaine_geyser":
			_geyser(ci, e, k, on_ground)
		"cocon":
			if not on_ground:
				_cocon(ci, e, k)
		"cocon_eclat":
			_cocon_eclat(ci, e, k, on_ground)
		"perle_eclat":
			if not on_ground:
				_perle_eclat(ci, e, k)
		"rosee":
			if not on_ground:
				_rosee(ci, e, k)


# --- Projectile ---

## Perle de sève : une grosse goutte claire, cerclée de vert sombre, un reflet blanc et une
## lueur douce (motif « lueur »). Elle s'étire un peu vers l'arrière, comme une goutte qui file.
static func draw_perle(ci: CanvasItem, dir: Vector2, r: float) -> void:
	var col := Art.ec("seve")
	var clair := Art.ec("seve", "clair")
	var sombre := Art.ec("seve", "sombre")
	var n := dir.orthogonal()
	ci.draw_circle(Vector2.ZERO, r * 2.0, Color(col, 0.14))
	# Queue de la goutte : un triangle arrondi vers l'arrière.
	var tail := PackedVector2Array([n * r * 0.95, -dir * r * 2.1, -n * r * 0.95])
	ci.draw_colored_polygon(tail, Color(col, 0.75))
	ci.draw_circle(Vector2.ZERO, r * 1.12, sombre)
	ci.draw_circle(Vector2.ZERO, r * 0.98, col)
	ci.draw_circle(-dir * r * 0.2 - n * r * 0.25, r * 0.55, Color(sombre, 0.35))
	ci.draw_circle(dir * r * 0.3 + n * r * 0.35, r * 0.28, clair)


# --- Compétences ---

## Liane buveuse : une liane ondule du héros jusqu'à l'ennemi, enroulée d'une vrille claire ; des
## gouttes de sève remontent le long de la liane vers le héros (la vie bue). Elle sort vite au début
## et se fane à la fin (elle pâlit et se rétracte).
static func _liane(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	if on_ground:
		return
	var from: Vector2 = e["pos"]
	var to: Vector2 = e.get("to", from)
	var t: float = e["t"]
	var dur: float = e["dur"]
	var d := to - from
	var l := d.length()
	if l < 4.0:
		return
	var dir := d / l
	var n := dir.orthogonal()
	var grow := Anim.ease_out(clampf(t / 0.18, 0.0, 1.0))
	var fade := clampf((t - (dur - 0.25)) / 0.25, 0.0, 1.0)
	var a := 1.0 - fade
	var reach := grow * (1.0 - 0.6 * fade)
	var col := Art.ec("seve")
	var clair := Art.ec("seve", "clair")
	var sombre := Art.ec("seve", "sombre")
	var seed := float(e.get("seed", 0))
	var pts := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var q := i / float(steps) * reach
		var wave := sin(q * 9.0 + t * 6.0 + seed) * 10.0 * sin(PI * q)
		pts.append(from + dir * l * q + n * wave)
	ci.draw_polyline(pts, Color(sombre, 0.9 * a), Art.TRAIT + 1.0, true)
	ci.draw_polyline(pts, Color(col, a), Art.TRAIT_FIN + 0.5, true)
	# Vrille claire enroulée autour de la liane.
	var curl := PackedVector2Array()
	for i in steps + 1:
		var q := i / float(steps) * reach
		var wave := sin(q * 9.0 + t * 6.0 + seed) * 10.0 * sin(PI * q)
		curl.append(from + dir * l * q + n * (wave + sin(q * 30.0 + seed) * 4.0))
	ci.draw_polyline(curl, Color(clair, 0.55 * a), 1.0, true)
	if grow < 1.0:
		return
	# Gouttes de sève qui remontent vers le héros.
	for i in 3:
		var q := 1.0 - fposmod(t * 1.4 + i / 3.0, 1.0)
		var wave := sin(q * 9.0 + t * 6.0 + seed) * 10.0 * sin(PI * q)
		ci.draw_circle(from + dir * l * q + n * wave, 3.2, Color(clair, a))
	# Prise : trois petites feuilles serrées sur l'ennemi.
	for i in 3:
		Art._leaf(ci, to, 5.0, dir.angle() + PI + (i - 1) * 0.9, Color(col, a))
	# Au moment où la liane saisit : un anneau se serre sur l'ennemi.
	var sk := (t - 0.18) / 0.22
	if sk > 0.0 and sk < 1.0:
		ci.draw_arc(to, lerpf(30.0, 12.0, Anim.ease_out(sk)), 0.0, TAU, 20, Color(clair, 1.0 - sk), 3.0 * (1.0 - sk) + 1.0, true)


## Départ des lianes (anticipation, windup › liane) : une bosse de terre file sous le sol du héros
## jusqu'à l'endroit visé, puis la terre s'y ouvre en cercle et des pousses de liane en jaillissent ;
## le cercle de terre retournée pâlit.
static func _liane_jet(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 200.0)
	var from: Vector2 = e.get("from", p)
	var t: float = e["t"]
	var w := SkillFx.windup("liane", 0.12)
	var u := clampf(t / maxf(w, 0.001), 0.0, 1.0)
	var ok := clampf((t - w) / maxf(float(e["dur"]) - w, 0.01), 0.0, 1.0)
	var sombre := Art.ec("seve", "sombre")
	var head := from.lerp(p, Anim.ease_in_out(u))
	if on_ground:
		if u < 1.0:
			# Sillon de terre soulevée derrière la bosse.
			ci.draw_line(from, head, Color(Art.ec("racine", "sombre"), 0.5), 4.0, true)
			ci.draw_colored_polygon(Art.ellipse(head, 12.0, 6.0, 12), Color(Art.ec("racine", "sombre"), 0.8))
			return
		var a := 1.0 - ok
		ci.draw_arc(p, r * (0.85 + 0.15 * Anim.ease_out(ok)), 0.0, TAU, 40, Color(Art.ec("seve"), 0.45 * a), Art.TRAIT_FIN, true)
		ci.draw_circle(p, r * 0.25 * (1.0 - ok), Color(sombre, 0.25 * a))
		return
	if u < 1.0:
		# Mottes qui sautent sur la bosse.
		for i in SkillFx._take(SkillFx.amount(3)):
			ci.draw_circle(head + Vector2((i - 1) * 7.0, -absf(sin(t * 40.0 + i)) * 8.0), 2.2, Color(Art.ec("racine", "sombre").lightened(0.2), 0.9))
		return
	# Pousses qui jaillissent du cercle et retombent.
	if ok < 0.8:
		var q := ok / 0.8
		for i in SkillFx._take(SkillFx.amount(6)):
			var ang := i * TAU / 6.0 + 0.4
			var base := p + Vector2(cos(ang), sin(ang) * 0.5) * r * 0.35
			var h := 36.0 * sin(PI * q)
			var tip := base + Vector2(cos(ang) * 10.0, -h)
			ci.draw_line(base, tip, Color(sombre, 1.0 - q), 4.0, true)
			ci.draw_line(base, tip, Color(Art.ec("seve"), 1.0 - q), 2.0, true)
			Art._leaf(ci, tip, 5.0, -PI / 2.0 + cos(ang) * 0.6, Color(Art.ec("seve", "clair"), 1.0 - q))


## Fontaine de sève : au sol, une flaque claire bordée de mousse, des rides qui s'élargissent ;
## au-dessus, un jet de gouttes au centre et une lueur qui respire. Elle sort en éclaboussant et
## s'assèche à la fin.
static func _fontaine(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 140.0)
	var t: float = e["t"]
	var dur: float = e["dur"]
	var col := Art.ec("seve")
	var clair := Art.ec("seve", "clair")
	var sombre := Art.ec("seve", "sombre")
	# Anticipation (windup › fontaine) : la terre bombe et se fend, des bulles de sève percent ;
	# puis la sève jaillit en colonne haute et retombe en flaque.
	var w := SkillFx.windup("fontaine", 0.28)
	var a := 1.0 - clampf((t - (dur - 0.5)) / 0.5, 0.0, 1.0)
	if t < w:
		var u := t / w
		if on_ground:
			ci.draw_colored_polygon(Art.ellipse(p, 10.0 + 26.0 * u, 5.0 + 13.0 * u, 16), Color(Art.ec("racine", "sombre"), 0.6))
			for i in 5:
				var ang := i * TAU / 5.0 + 0.3
				ci.draw_line(p, p + Vector2(cos(ang) * 40.0, sin(ang) * 20.0) * u, Color(sombre, 0.9), 2.0, true)
			return
		for i in SkillFx._take(SkillFx.amount(5)):
			var bk := fposmod(u * 2.0 + i * 0.37, 1.0)
			var q := p + Vector2(cos(i * 2.4) * 18.0 * u, sin(i * 2.4) * 8.0 * u - bk * 10.0)
			ci.draw_arc(q, 2.0 + 3.0 * bk, 0.0, TAU, 10, Color(clair, 1.0 - bk), 1.2, true)
		return
	var appear := Anim.ease_out(clampf((t - w) / 0.35, 0.0, 1.0))
	if not on_ground:
		# Colonne qui jaillit puis retombe en gerbe.
		var jk := (t - w) / 0.45
		if jk < 1.0:
			var hh := 110.0 * sin(PI * minf(jk * 1.3, 1.0))
			ci.draw_line(p, p + Vector2(0, -hh), Color(col, 0.7 * (1.0 - jk)), 14.0 * (1.0 - jk) + 2.0, true)
			ci.draw_line(p, p + Vector2(0, -hh), Color(clair, 1.0 - jk), 4.0 * (1.0 - jk) + 1.0, true)
			for i in SkillFx._take(SkillFx.amount(8)):
				var side := (i - 3.5) / 3.5
				var q := p + Vector2(side * 70.0 * jk, -hh * 0.9 + 140.0 * jk * jk * (0.6 + 0.4 * absf(side)))
				ci.draw_circle(q, 3.0, Color(clair, 1.0 - jk))
	if on_ground:
		ci.draw_colored_polygon(Art.ellipse(p, r * appear + 1.0, r * 0.62 * appear + 1.0, 32), Color(sombre, 0.3 * a))
		ci.draw_colored_polygon(Art.ellipse(p, r * 0.82 * appear + 1.0, r * 0.5 * appear + 1.0, 28), Color(col, 0.16 * a))
		# Bord de mousse : des touffes le long de l'ellipse.
		for i in 14:
			var ang := i * TAU / 14.0
			var q := p + Vector2(cos(ang) * r, sin(ang) * r * 0.62) * appear
			ci.draw_circle(q, 5.0 + 2.0 * sin(i * 2.3), Color(sombre.lightened(0.15), 0.8 * a))
		# Rides qui partent du centre.
		for i in 3:
			var q := fposmod(t * 0.6 + i / 3.0, 1.0)
			ci.draw_polyline(Art.ellipse(p, r * 0.8 * q * appear, r * 0.5 * q * appear, 24), Color(clair, 0.4 * (1.0 - q) * a), Art.TRAIT_FIN, true)
		return
	var b := 0.5 + 0.5 * sin(t * 3.0)
	ci.draw_circle(p, r * 0.18 * (1.0 + 0.15 * b) * appear, Color(col, 0.25 * a))
	# Jet : des gouttes montent puis retombent en gerbe.
	for i in 7:
		var q := fposmod(t * 1.1 + i / 7.0, 1.0)
		var side := (i - 3) / 3.0
		var h := sin(PI * q) * 46.0 * appear
		var x := side * 22.0 * q
		ci.draw_circle(p + Vector2(x, -h), 3.0 * (1.0 - 0.4 * q), Color(clair, 0.9 * a))


## Geyser (mutation de la fontaine) : une colonne de sève jaillit et retombe en anneau.
static func _geyser(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 140.0)
	var a := 1.0 - k
	if on_ground:
		ci.draw_arc(p, r * Anim.ease_out(k), 0.0, TAU, 40, Color(Art.ec("seve", "clair"), 0.8 * a), 2.0 + 5.0 * a, true)
		return
	var h := 120.0 * sin(PI * minf(k * 1.4, 1.0))
	ci.draw_line(p, p + Vector2(0, -h), Color(Art.ec("seve"), 0.7 * a), 16.0 * a + 2.0, true)
	ci.draw_line(p, p + Vector2(0, -h), Color(Art.ec("seve", "clair"), a), 5.0 * a + 1.0, true)


## Cocon de sève : une coque de feuilles translucides autour du héros, qui s'amincit avec le
## bouclier restant (e["part"]) ; la coque respire et des reflets clairs glissent dessus.
static func _cocon(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 30.0)
	var t: float = e["t"]
	var part: float = clampf(float(e.get("part", 1.0)), 0.0, 1.0)
	var col := Art.ec("seve")
	var clair := Art.ec("seve", "clair")
	var sombre := Art.ec("seve", "sombre")
	# Anticipation (windup › cocon) : des feuilles montent du sol en spirale autour du héros et se
	# referment sur lui ; la coque se scelle dans un éclat clair.
	var w := SkillFx.windup("cocon", 0.3)
	if t < w:
		var u := t / w
		var cu := Anim.ease_in_out(u)
		for i in 8:
			var ang := i * TAU / 8.0 + cu * 4.0
			var rad := r * lerpf(1.9, 1.0, cu)
			var q := p + Vector2(0, -r * 0.15) + Vector2(cos(ang) * rad, sin(ang) * rad * 0.5 + r * 0.9 * (1.0 - cu) - r * 0.4 * sin(PI * u))
			Art._leaf(ci, q, r * 0.32, ang + PI * 0.5 + (1.0 - cu) * 2.0, Color(sombre.lightened(0.25), 0.4 + 0.5 * u))
		return
	var appear := Anim.pop(clampf((t - w) / 0.2, 0.0, 1.0))
	var b := 0.5 + 0.5 * sin(t * 4.0)
	var rr := r * appear * (1.0 + 0.04 * b)
	ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, -r * 0.15), rr, rr * 1.15, 28), Color(col, 0.12 + 0.12 * part))
	# Feuilles de la coque : autant qu'il reste de bouclier (de 3 à 8).
	var leaves := 3 + int(round(5.0 * part))
	for i in leaves:
		var ang := i * TAU / 8.0 + t * 0.4
		var q := p + Vector2(0, -r * 0.15) + Vector2(cos(ang) * rr * 0.92, sin(ang) * rr * 1.05)
		Art._leaf(ci, q, rr * 0.32, ang + PI * 0.5, Color(sombre.lightened(0.25), 0.55 + 0.35 * part))
	ci.draw_polyline(Art.ellipse(p + Vector2(0, -r * 0.15), rr, rr * 1.15, 28), Color(clair, 0.5 + 0.4 * part), Art.TRAIT_FIN + part, true)
	var ga := t * 1.6
	ci.draw_arc(p + Vector2(0, -r * 0.15), rr * 0.85, ga, ga + 0.7, 8, Color(1, 1, 1, 0.45 * part), 2.0, true)
	# Sceau : un éclat clair quand la coque se ferme.
	var sk := (t - w) / 0.25
	if sk > 0.0 and sk < 1.0:
		ci.draw_polyline(Art.ellipse(p + Vector2(0, -r * 0.15), rr * (1.0 + 0.5 * sk), rr * 1.15 * (1.0 + 0.5 * sk), 28), Color(clair, 1.0 - sk), 3.0 * (1.0 - sk) + 1.0, true)
		ci.draw_circle(p + Vector2(0, -r * 1.2), 6.0 * (1.0 - sk) + 1.0, Color(Color.WHITE, 1.0 - sk))


## Éclatement du cocon : les feuilles s'envolent en étoile, un anneau de sève s'élargit.
static func _cocon_eclat(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 140.0)
	var a := 1.0 - k
	var g := Anim.ease_out(k)
	if on_ground:
		ci.draw_circle(p, r * g, Color(Art.ec("seve"), 0.15 * a))
		return
	ci.draw_arc(p, r * g, 0.0, TAU, 40, Color(Art.ec("seve", "clair"), 0.85 * a), 2.0 + 4.0 * a, true)
	for i in 8:
		var ang := i * TAU / 8.0 + 0.3
		Art._leaf(ci, p + Vector2.from_angle(ang) * r * 0.8 * g, 7.0 * a + 2.0, ang, Color(Art.ec("seve"), a))


## Éclaboussure d'une perle : une couronne de gouttelettes autour de l'impact.
static func _perle_eclat(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 56.0)
	var a := 1.0 - k
	var g := Anim.ease_out(k)
	ci.draw_arc(p, r * g, 0.0, TAU, 24, Color(Art.ec("seve"), 0.6 * a), 1.5 + 2.0 * a, true)
	for i in 6:
		var ang := i * TAU / 6.0 + 0.4
		ci.draw_circle(p + Vector2.from_angle(ang) * r * (0.4 + 0.6 * g), 2.5 * a + 1.0, Color(Art.ec("seve", "clair"), a))


## Rosée : une goutte claire file de l'ennemi tombé jusqu'au héros.
static func _rosee(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var from: Vector2 = e.get("from", e["pos"])
	var to: Vector2 = e["pos"]
	var q := Anim.ease_in(k)
	var at := from.lerp(to, q) + Vector2(0, -sin(PI * q) * 30.0)
	ci.draw_circle(at, 7.0, Color(Art.ec("seve"), 0.25))
	ci.draw_circle(at, 3.5, Art.ec("seve", "clair"))


# --- Icônes ---

## Dessine l'icône de Sève id (voir Art.icon) ; faux si id n'en est pas une.
static func icon(ci: CanvasItem, id: String, p: Vector2, s: float, col: Color, clair: Color, sombre: Color, lw: float) -> bool:
	var relief := col == sombre
	var P := func(x: float, y: float) -> Vector2: return p + Vector2(x, y) * s
	match id:
		"liane":
			# Une liane en S qui finit en vrille, une goutte au départ.
			var pts := PackedVector2Array()
			for i in 13:
				var q := i / 12.0
				pts.append(P.call(-0.75 + 1.3 * q, 0.7 - 1.3 * q + 0.35 * sin(q * TAU)))
			ci.draw_polyline(pts, col, lw * 1.6, true)
			ci.draw_arc(P.call(0.55, -0.62), s * 0.22, PI * 0.8, PI * 2.6, 10, col, lw * 1.1, true)
			ci.draw_circle(P.call(-0.72, 0.72), s * 0.17, col if relief else clair)
		"fontaine":
			# Un jet en gerbe au-dessus d'une flaque.
			ci.draw_colored_polygon(Art.ellipse(P.call(0, 0.62), s * 0.85, s * 0.28, 16), col)
			ci.draw_line(P.call(0, 0.55), P.call(0, -0.55), col, lw * 1.6, true)
			for sgn: int in [-1, 1]:
				ci.draw_arc(P.call(sgn * 0.38, -0.3), s * 0.4, PI * (1.5 if sgn < 0 else 1.0), PI * (2.0 if sgn < 0 else 1.5), 8, col, lw * 1.2, true)
			ci.draw_circle(P.call(0, -0.72), s * 0.14, col if relief else clair)
		"cocon":
			# Une coque ovale de deux feuilles qui se referment, une lueur au centre.
			Art._leaf(ci, P.call(-0.2, 0.0), s * 0.55, -PI * 0.5 - 0.35, col)
			Art._leaf(ci, P.call(0.2, 0.0), s * 0.55, -PI * 0.5 + 0.35, col.darkened(0.15) if not relief else col)
			ci.draw_circle(P.call(0, 0.05), s * 0.2, sombre if relief else clair)
		"attaque_perle":
			# Deux gouttes qui filent vers le haut à droite, la grosse devant.
			for j in 2:
				var c: Vector2 = P.call(0.25 - 0.7 * j, -0.25 + 0.7 * j)
				var rr := s * (0.42 - 0.14 * j)
				var d := Vector2(1, -1).normalized()
				ci.draw_colored_polygon(PackedVector2Array([c + d.orthogonal() * rr * 0.9, c - d * rr * 2.0, c - d.orthogonal() * rr * 0.9]), col)
				ci.draw_circle(c, rr, col)
				if not relief:
					ci.draw_circle(c + Vector2(rr * 0.3, -rr * 0.3), rr * 0.3, clair)
		_:
			return false
	return true
