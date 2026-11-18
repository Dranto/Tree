## Signatures visuelles des attaques du Porte-Graine : la graine (départ, impact), les sept compétences,
## et la chute du héros. Purement visuel : rien ici ne touche au jeu (dégâts et effets restent dans
## player.gd, fx.gd et main.gd). Chaque compétence suit la charte : la couleur et le motif de son
## élément, et les trois temps d'une action (anticipation, coup, fin).
##
## Deux nœuds partagent la même liste d'effets : l'un sous les acteurs (sol : fissures, taches,
## lueurs au sol), l'autre au-dessus des projectiles (racines, épines, fouet, pétales).
## Les dessins sont statiques (draw_effect) : la galerie les fige à un instant précis.
class_name SkillFx
extends Node2D

## Au plus autant d'effets à la fois (les plus anciens partent d'abord).
const MAX_EFFECTS := 48

## Durée de chaque signature (secondes). Les racines et le nuage durent ce que dure leur effet.
const DUREE := {
	"graine_depart": 0.12, "graine_impact": 0.3, "epine_impact": 0.3,
	"nova": 0.6, "fouet": 0.34, "racines": 0.6, "volee": 0.24, "saignee": 0.7,
	"cloud": 5.0, "bloom": 1.0, "chute": 1.1,
	"vesse": 9.0, "essaim": 0.3, "eclosion": 0.7,
}

## Vrai pour le nœud du sol, faux pour celui du dessus.
var sol := false
## Liste partagée entre les deux nœuds (seul le nœud du dessus fait avancer le temps).
var effects: Array = []
var twin: SkillFx
var _dirty := false


## Crée le nœud du dessus et son jumeau du sol (à ajouter sous les acteurs).
static func make_pair() -> Array:
	var top := SkillFx.new()
	var low := SkillFx.new()
	low.sol = true
	low.effects = top.effects
	top.twin = low
	low.twin = top
	return [low, top]


## Ajoute une signature. data : position "pos", direction "dir", rayon "r", nœud à suivre "follow"…
func play(id: String, data := {}) -> Dictionary:
	var e := data.duplicate()
	e["id"] = id
	e["t"] = 0.0
	if not e.has("dur"):
		e["dur"] = DUREE.get(id, VentFx.DUREE.get(id, 0.4))
	if Settings.reduce_effects and id in ["graine_depart", "graine_impact"]:
		return e
	while effects.size() >= MAX_EFFECTS:
		effects.pop_front()
	effects.append(e)
	return e


func _process(delta: float) -> void:
	if sol:
		if not effects.is_empty() or _dirty:
			queue_redraw()
		_dirty = not effects.is_empty()
		return
	var i := 0
	while i < effects.size():
		var e: Dictionary = effects[i]
		e["t"] += delta
		var f = e.get("follow")
		if f != null:
			if is_instance_valid(f):
				e["pos"] = f.position
			else:
				e.erase("follow")
		if e["t"] >= e["dur"]:
			effects.remove_at(i)
		else:
			i += 1
	if not effects.is_empty() or _dirty:
		queue_redraw()
	_dirty = not effects.is_empty()


func _draw() -> void:
	for e in effects:
		draw_effect(self, e, sol)


## Dessine un effet à son instant e["t"]. sol : la partie au sol (vrai) ou celle du dessus (faux).
static func draw_effect(ci: CanvasItem, e: Dictionary, on_ground: bool) -> void:
	var k: float = clampf(e["t"] / maxf(e["dur"], 0.001), 0.0, 1.0)
	if VentFx.draws(e["id"]):
		VentFx.draw(ci, e, on_ground)
		return
	match e["id"]:
		"graine_depart":
			if not on_ground:
				_graine_depart(ci, e, k)
		"graine_impact":
			if not on_ground:
				_graine_impact(ci, e, k)
		"epine_impact":
			if not on_ground:
				_epine_impact(ci, e, k)
		"nova":
			_nova(ci, e, k, on_ground)
		"fouet":
			_fouet(ci, e, k, on_ground)
		"racines":
			_racines(ci, e, k, on_ground)
		"volee":
			if not on_ground:
				_volee(ci, e, k)
		"saignee":
			_saignee(ci, e, k, on_ground)
		"cloud":
			_cloud(ci, e, k, on_ground)
		"bloom":
			_bloom(ci, e, k, on_ground)
		"chute":
			if not on_ground:
				_chute(ci, e, k)
		"vesse":
			_vesse(ci, e, on_ground)
		"essaim":
			if not on_ground:
				_essaim(ci, e, k)
		"eclosion":
			_eclosion(ci, e, k, on_ground)


# --- Graines ---

## Départ d'une graine : une collerette de deux feuilles et un éclat de sève au bout de la lanterne.
static func _graine_depart(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var d: Vector2 = e["dir"]
	var a := 1.0 - k
	ci.draw_circle(p, 10.0 * Anim.ease_out(k) + 3.0, Color(Art.ec("seve"), 0.35 * a))
	for sgn: int in [-1, 1]:
		var la := d.angle() + sgn * (0.7 + 0.5 * k)
		ci.draw_colored_polygon(HeroArt.leaf_pts(p + Vector2.from_angle(la) * 7.0 * (0.5 + k), 4.0, la), Color(Art.ec("seve", "clair"), a))


## Impact d'une graine : elle éclate en une corolle de sève et quatre petites feuilles.
static func _graine_impact(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 6.0)
	var a := 1.0 - k
	var g := Anim.ease_out(k)
	ci.draw_circle(p, r * (1.0 + 1.2 * g), Color(Art.ec("seve", "clair"), 0.5 * Anim.flash(k * 2.0)))
	ci.draw_arc(p, r * (1.0 + 2.6 * g), 0, TAU, 20, Color(Art.ec("seve"), 0.85 * a), maxf(2.5 * a, 1.0), true)
	var d: Vector2 = e.get("dir", Vector2.RIGHT)
	for i in 4:
		var la := d.angle() + PI + (i - 1.5) * 0.7
		var q := p + Vector2.from_angle(la) * r * (0.8 + 3.0 * g) + Vector2(0, 6.0 * k * k)
		ci.draw_colored_polygon(HeroArt.leaf_pts(q, r * 0.45, la + k * 4.0), Color(Art.ec("seve"), a))


## Impact d'une épine (volée) : un éclat d'os et deux gouttes de sang.
static func _epine_impact(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var d: Vector2 = e.get("dir", Vector2.RIGHT)
	var a := 1.0 - k
	var g := Anim.ease_out(k)
	for i in 5:
		var la := d.angle() + PI + (i - 2) * 0.55
		var q := p + Vector2.from_angle(la) * (4.0 + 18.0 * g)
		Art._thorn(ci, q, Vector2.from_angle(la), 7.0 * a, Color(Art.ec("epine", "clair"), a))
	for i in 2:
		var q := p + Vector2((i - 0.5) * 10.0, -4.0 + 16.0 * k * k)
		Art._drop(ci, q, 2.6 * a, Color(Art.ec("saignement", "clair"), a))


# --- Compétences ---

## Couronne d'épines : une couronne d'épines d'os jaillit autour du héros, file jusqu'au bord de la
## zone en repoussant tout, puis les épines se plantent dans le sol et s'y enfoncent.
static func _nova(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e["r"]
	var col := Art.ec("epine")
	var clair := Art.ec("epine", "clair")
	var sombre := Art.ec("epine", "sombre")
	var grow := 0.12   # anticipation : la couronne se forme
	var hit := 0.45    # fin du coup : les épines sont au bord
	var n := 18
	if on_ground:
		# Disque balayé et fissures qui rayonnent jusqu'au bord.
		var g := Anim.ease_out(clampf((k - grow) / (hit - grow), 0.0, 1.0))
		var rad := lerpf(18.0, r, g)
		var a := 1.0 - clampf((k - hit) / (1.0 - hit), 0.0, 1.0)
		ci.draw_circle(p, rad, Color(col, 0.10 * a))
		ci.draw_arc(p, r, 0, TAU, 56, Color(col, 0.25 * a * g), Art.TRAIT_FIN, true)
		for i in n:
			var d := Vector2.from_angle(i * TAU / n + 0.17)
			var mid := p + d * rad * 0.55 + d.orthogonal() * 6.0 * sin(i * 2.7)
			ci.draw_polyline(PackedVector2Array([p + d * 16.0, mid, p + d * rad * 0.95]), Color(sombre, 0.55 * a), Art.TRAIT_FIN, true)
		return
	if k < grow:
		# Les épines sortent de la capuche et se dressent en couronne.
		var g := Anim.ease_out_back(k / grow)
		for i in n:
			var d := Vector2.from_angle(i * TAU / n)
			Art._thorn(ci, p + d * 16.0, d, 14.0 * g, clair)
		return
	var g := Anim.ease_out(clampf((k - grow) / (hit - grow), 0.0, 1.0))
	var rad := lerpf(18.0, r, g)
	var fade := clampf((k - hit) / (1.0 - hit), 0.0, 1.0)
	# Onde de choc pâle, épaisse au moment du coup.
	if k < hit + 0.1:
		var w := Anim.flash((k - grow) / (hit - grow + 0.1))
		ci.draw_arc(p, rad, 0, TAU, 56, Color(Art.c("danger_eclair"), 0.75 * w), 3.0 + 7.0 * w, true)
	for i in n:
		var d := Vector2.from_angle(i * TAU / n + 0.08 * g)
		var len := 22.0 * (1.0 - 0.9 * Anim.ease_in(fade))
		var base := p + d * (rad - len * 0.25 * fade)
		# Épine en volume : une moitié claire, une moitié dans l'ombre, liseré sombre.
		var nn := d.orthogonal()
		var tip := base + d * len
		ci.draw_colored_polygon(PackedVector2Array([base + nn * len * 0.28, tip, base]), Color(clair, 1.0 - fade * 0.6))
		ci.draw_colored_polygon(PackedVector2Array([base, tip, base - nn * len * 0.28]), Color(col.darkened(0.15), 1.0 - fade * 0.6))
		ci.draw_polyline(PackedVector2Array([base + nn * len * 0.28, tip, base - nn * len * 0.28]), Color(sombre, 1.0 - fade), 1.0, true)
		# Traînée de vitesse derrière chaque épine pendant le vol.
		if fade == 0.0 and g < 0.98:
			ci.draw_line(base - d * 26.0 * (1.0 - g), base, Color(clair, 0.45), 2.0, true)
	# Poussière soulevée au bord quand elles se plantent.
	if fade > 0.0:
		for i in 9:
			var d := Vector2.from_angle(i * TAU / 9.0 + 0.3)
			var q := p + d * (r + 10.0 * fade) + Vector2(0, -14.0 * fade)
			ci.draw_circle(q, 5.0 * (1.0 - fade), Color(Art.c("brume").lightened(0.3), 0.6 * (1.0 - fade)))


## Fouet de ronce : la liane recule (anticipation), claque en arc devant le héros (coup), puis se
## rétracte en traînant des gouttes de sang (fin). Le secteur balayé reste visible un instant.
static func _fouet(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var reach: float = e["r"]
	var arc: float = e["arc"]
	var d: Vector2 = e["dir"]
	var a0 := d.angle() - arc / 2.0
	var wind := 0.14   # anticipation
	var sweep := 0.5   # fin du balayage
	var col := Art.ec("epine")
	var clair := Art.ec("epine", "clair")
	var vine := Art.ec("racine").darkened(0.1)
	var s := clampf((k - wind) / (sweep - wind), 0.0, 1.0)
	var se := Anim.ease_in_out(s)
	var cur := a0 + arc * se
	if on_ground:
		# Secteur balayé : voile clair de l'arc parcouru, il s'efface après le coup.
		if k > wind:
			var fade := 1.0 - clampf((k - sweep) / (1.0 - sweep), 0.0, 1.0)
			var pts := PackedVector2Array([p])
			for i in 17:
				pts.append(p + Vector2.from_angle(a0 + (cur - a0) * i / 16.0) * reach)
			ci.draw_colored_polygon(pts, Color(col, 0.13 * fade))
			ci.draw_arc(p, reach, a0, cur, 24, Color(clair, 0.5 * fade), 2.0, true)
		return
	# Angle de la pointe et longueur de la liane selon le temps.
	var tip_a: float
	var len: float
	if k < wind:
		var w := Anim.ease_out(k / wind)
		tip_a = a0 - 0.6 * w
		len = reach * (0.45 - 0.1 * w)
	elif k < sweep:
		tip_a = cur
		len = reach * lerpf(0.35, 1.0, Anim.ease_out(minf(s * 1.6, 1.0)))
	else:
		var u := (k - sweep) / (1.0 - sweep)
		tip_a = a0 + arc + 0.15 * sin(u * PI)
		len = reach * lerpf(1.0, 0.25, Anim.ease_in(u))
	# La liane : une courbe qui traîne derrière sa pointe (le milieu est en retard sur le bout).
	var lag := 0.55 if k < sweep else 0.2
	var hand := p + Vector2.from_angle(tip_a - lag * 0.5) * 16.0
	var pts := PackedVector2Array()
	for i in 15:
		var u := i / 14.0
		var a := tip_a - lag * (1.0 - u) * u * 2.0
		pts.append(p + Vector2.from_angle(a) * lerpf(16.0, len, u))
	pts[0] = hand
	var alpha := 1.0 if k < sweep else 1.0 - Anim.ease_in((k - sweep) / (1.0 - sweep))
	# Traînées de mouvement derrière la liane pendant le claquement.
	if k >= wind and k < sweep + 0.1:
		for j in 3:
			var back := (j + 1) * 0.12
			var tr := PackedVector2Array()
			for i in 8:
				var u := 0.3 + 0.7 * i / 7.0
				tr.append(p + Vector2.from_angle(maxf(a0, tip_a - back * u)) * lerpf(16.0, len, u))
			ci.draw_polyline(tr, Color(clair, (0.35 - j * 0.1) * alpha), 3.0 - j * 0.6, true)
	ci.draw_polyline(pts, Color(Art.c("contour"), alpha), 7.0, true)
	ci.draw_polyline(pts, Color(vine, alpha), 4.5, true)
	ci.draw_polyline(pts, Color(vine.lightened(0.35), alpha * 0.8), 1.5, true)
	# Épines le long de la liane, alternées de part et d'autre.
	for i in range(2, 14, 2):
		var dir := (pts[i + 1] - pts[i]).normalized()
		var nn := dir.orthogonal() * (1.0 if i % 4 == 0 else -1.0)
		Art._thorn(ci, pts[i], (nn + dir * 0.6).normalized(), 7.0, Color(clair, alpha))
	# Bout de la liane : une pointe d'os, et un claquement (éclair) au milieu du balayage.
	var tip := pts[14]
	var tdir := (pts[14] - pts[13]).normalized()
	Art._thorn(ci, tip, tdir, 12.0, Color(clair, alpha))
	if k >= wind and k < sweep:
		var crack := Anim.flash(absf(s - 0.55) * 4.0)
		if crack > 0.0:
			ci.draw_circle(tip, 10.0 * crack, Color(Art.c("danger_eclair"), 0.8 * crack))
			for i in 4:
				var la := tdir.angle() + i * PI / 2.0 + 0.4
				ci.draw_line(tip + Vector2.from_angle(la) * 6.0, tip + Vector2.from_angle(la) * (12.0 + 10.0 * crack), Color(Art.c("danger_eclair"), crack), 2.0, true)
	# Gouttes de sang projetées du bout, qui retombent (saignement posé par le fouet).
	if k > sweep * 0.8:
		var u := (k - sweep * 0.8) / (1.0 - sweep * 0.8)
		var blood := Art.ec("saignement", "clair")
		for i in 4:
			var la := a0 + arc * (0.35 + 0.2 * i)
			var q := p + Vector2.from_angle(la) * reach * (0.95 + 0.15 * u) + Vector2(0, 26.0 * u * u)
			Art._drop(ci, q, 3.2 * (1.0 - 0.5 * u), Color(blood, 1.0 - u))


## Racines voraces : le sol se fend en cercle (anticipation), des racines noueuses jaillissent
## et se referment sur la zone (coup), tiennent en ondulant, puis se rétractent sous terre (fin).
static func _racines(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e["r"]
	var dur: float = e["dur"]
	var t: float = e["t"]
	var crack := 0.1    # s : la terre se fend
	var rise := 0.28    # s : les racines sont dressées
	var out := 0.35     # s : retrait final
	var col := Art.ec("racine")
	var clair := Art.ec("racine", "clair")
	var sombre := Art.ec("racine", "sombre")
	var end_k := clampf((t - (dur - out)) / out, 0.0, 1.0)
	if on_ground:
		var c := Anim.ease_out(clampf(t / crack, 0.0, 1.0))
		var a := 1.0 - end_k
		ci.draw_colored_polygon(Art.ellipse(p, r * c, r * c * 0.92, 28), Color(sombre, 0.35 * a))
		ci.draw_arc(p, r * c, 0, TAU, 40, Color(col, 0.7 * a), Art.TRAIT, true)
		# Fissures noueuses du centre vers le bord.
		for i in 7:
			var d := Vector2.from_angle(i * TAU / 7.0 + 0.4)
			var q1 := p + d * r * 0.35 * c + d.orthogonal() * 8.0
			var q2 := p + d * r * 0.7 * c - d.orthogonal() * 6.0
			ci.draw_polyline(PackedVector2Array([p + d * 10.0, q1, q2, p + d * r * c]), Color(sombre.darkened(0.3), 0.8 * a), Art.TRAIT_FIN + 0.5, true)
		return
	if t < crack:
		return
	# Racines : graine fixe par effet (même tirage d'une image à l'autre).
	var n := clampi(int(r / 14.0), 6, 12)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(e.get("seed", 1))
	var hold_k := clampf((t - rise) / maxf(dur - out - rise, 0.01), 0.0, 1.0)
	for i in n:
		var a := i * TAU / n + rng.randf_range(-0.25, 0.25)
		var dist := r * rng.randf_range(0.25, 0.92)
		var base := p + Vector2.from_angle(a) * dist
		var delay := rng.randf_range(0.0, 0.08)
		var g := Anim.ease_out_back(clampf((t - crack - delay) / (rise - crack), 0.0, 1.0), 2.2)
		g *= 1.0 - Anim.ease_in(end_k)
		if g <= 0.01:
			continue
		var h := rng.randf_range(36.0, 58.0) * g
		# Chaque racine se courbe vers le centre (elle enserre), et ondule pendant qu'elle tient.
		var lean := (p - base).normalized() * h * 0.45 + Vector2(sin(t * 3.0 + i) * 3.0 * hold_k, 0)
		var tip := base + Vector2(0, -h) + lean
		var mid := base + Vector2(0, -h * 0.55) + lean * 0.3 + Vector2(rng.randf_range(-6, 6), 0)
		var w := rng.randf_range(7.0, 10.0) * minf(g, 1.0)
		var side := (tip - base).normalized().orthogonal()
		var poly := PackedVector2Array([base + side * w, mid + side * w * 0.6, tip, mid - side * w * 0.6, base - side * w])
		ci.draw_colored_polygon(poly, col)
		ci.draw_colored_polygon(PackedVector2Array([base + side * w * 0.2, mid + side * w * 0.5, tip, mid + side * w * 0.05]), col.lightened(0.18))
		Art.outline(ci, poly, Art.c("contour"), Art.TRAIT_FIN)
		# Nœuds et mousse au bout.
		ci.draw_circle(mid, w * 0.38, sombre)
		ci.draw_circle(mid + Vector2(-w * 0.12, -w * 0.12), w * 0.15, col.lightened(0.3))
		ci.draw_circle(tip, maxf(w * 0.3, 1.5), clair)
		# Mottes de terre projetées à la sortie.
		var burst := clampf((t - crack - delay) / 0.2, 0.0, 1.0)
		if burst < 1.0:
			for j in 3:
				var la := -PI / 2.0 + (j - 1) * 0.9
				var q := base + Vector2.from_angle(la) * 14.0 * burst + Vector2(0, 30.0 * burst * burst)
				ci.draw_circle(q, 2.5 * (1.0 - burst), sombre.lightened(0.15))


## Volée d'épines : un éventail d'os s'ouvre devant le héros au moment du tir (les épines elles-mêmes
## sont les projectiles). Cinq traits de visée pâles montrent l'ouverture de la volée.
static func _volee(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var d: Vector2 = e["dir"]
	var spread: float = e.get("spread", 0.5)
	var count: int = e.get("count", 5)
	var a := 1.0 - k
	var g := Anim.ease_out(k)
	var clair := Art.ec("epine", "clair")
	for i in count:
		var la := d.angle() + ((i / float(maxi(count - 1, 1))) - 0.5) * spread
		var u := Vector2.from_angle(la)
		ci.draw_line(p + u * (18.0 + 30.0 * g), p + u * (40.0 + 110.0 * g), Color(clair, 0.45 * a), 2.0, true)
	# Collerette d'épines qui s'ouvre comme un éventail.
	for i in 7:
		var la := d.angle() + (i / 6.0 - 0.5) * (spread + 0.8) * (0.5 + 0.5 * g)
		Art._thorn(ci, p + Vector2.from_angle(la) * 16.0, Vector2.from_angle(la), 13.0 * a, Color(clair, a))
	ci.draw_circle(p + d * 20.0, 8.0 * Anim.flash(k * 1.5), Color(Art.c("danger_eclair"), 0.8 * a))


## Saignée : un anneau rouge sombre se resserre sur le héros (anticipation), les saignements des
## Flétris touchés éclatent en couronne de gouttes (coup), et le sang revient vers lui en filets (fin).
static func _saignee(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e["r"]
	var col := Art.ec("saignement")
	var clair := Art.ec("saignement", "clair")
	var sombre := Art.ec("saignement", "sombre")
	var close := 0.25
	var targets: Array = e.get("targets", [])
	if on_ground:
		var c := Anim.ease_in(clampf(k / close, 0.0, 1.0))
		var a := 1.0 - clampf((k - close) / 0.3, 0.0, 1.0)
		ci.draw_circle(p, r, Color(sombre, 0.18 * a))
		ci.draw_arc(p, lerpf(r, 24.0, c), 0, TAU, 56, Color(col, 0.75 * a), 5.0, true)
		ci.draw_arc(p, r, 0, TAU, 56, Color(clair, 0.35 * a), Art.TRAIT_FIN, true)
		return
	# Gouttes entraînées par l'anneau qui se resserre.
	if k < close:
		var c := Anim.ease_in(k / close)
		for i in 16:
			var la := i * TAU / 16.0 + c * 0.8
			Art._drop(ci, p + Vector2.from_angle(la) * lerpf(r, 24.0, c), 3.2, Color(clair, 0.9))
	# Éclatement sur chaque Flétri saignant, puis filets de sang vers le héros.
	for q: Vector2 in targets:
		var bk := clampf((k - close * 0.6) / 0.3, 0.0, 1.0)
		if bk > 0.0 and bk < 1.0:
			var b := Anim.ease_out(bk)
			ci.draw_circle(q, 16.0 * b, Color(clair, 0.5 * (1.0 - bk)))
			for i in 7:
				var la := i * TAU / 7.0 - PI / 2.0
				var dq: Vector2 = q + Vector2.from_angle(la) * 24.0 * b + Vector2(0, 14.0 * bk * bk)
				Art._drop(ci, dq, 3.5 * (1.0 - 0.5 * bk), Color(col.lightened(0.2), 1.0 - bk))
		var fk := clampf((k - close) / (1.0 - close), 0.0, 1.0)
		if fk > 0.0 and fk < 1.0:
			var from: Vector2 = q
			var ctrl: Vector2 = from.lerp(p, 0.5) + (p - from).orthogonal().normalized() * 30.0
			for j in 4:
				var u := clampf(fk * 1.4 - j * 0.12, 0.0, 1.0)
				if u <= 0.0 or u >= 1.0:
					continue
				var pos := from.lerp(ctrl, u).lerp(ctrl.lerp(p, u), u)
				Art._drop(ci, pos, 3.0, Color(clair, 1.0 - u * 0.5))
	# Le héros boit : un battement rouge clair à la fin.
	if k > 0.6:
		var hk := (k - 0.6) / 0.4
		ci.draw_arc(p, 18.0 + 16.0 * Anim.ease_out(hk), 0, TAU, 32, Color(clair, 0.8 * (1.0 - hk)), 3.0, true)


## Nuage de spores : des volutes violettes gonflent (apparition), tournent lentement en crachant
## des bulles pendant toute la durée, puis se dissipent en s'élargissant (fin).
static func _cloud(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e["r"]
	var t: float = e["t"]
	var dur: float = e["dur"]
	var col := Art.ec("poison")
	var clair := Art.ec("poison", "clair")
	var sombre := Art.ec("poison", "sombre")
	var appear := Anim.pop(clampf(t / 0.35, 0.0, 1.0))
	var end_k := clampf((t - (dur - 0.6)) / 0.6, 0.0, 1.0)
	var a := 1.0 - end_k
	if on_ground:
		# Tache de sol rongé et bord en pointillés (la zone qui fait mal).
		ci.draw_colored_polygon(Art.ellipse(p, r * appear, r * appear * 0.94, 32), Color(sombre, 0.3 * a))
		var segs := 20
		for i in segs:
			var a0 := i * TAU / segs + t * 0.25
			ci.draw_arc(p, r * appear, a0, a0 + TAU / segs * 0.55, 4, Color(clair, 0.55 * a), Art.TRAIT_FIN + 0.5, true)
		return
	# Volutes : des disques qui tournent autour du centre et respirent.
	var puffs := 9
	for i in puffs:
		var ang := i * TAU / puffs + t * 0.35 * (1.0 if i % 2 == 0 else -0.7)
		var dist := r * (0.45 + 0.12 * sin(t * 1.3 + i))
		var q := p + Vector2.from_angle(ang) * dist * (1.0 + 0.3 * end_k)
		var pr := r * (0.38 + 0.05 * sin(t * 2.0 + i * 1.7)) * appear * (1.0 + 0.4 * end_k)
		ci.draw_circle(q, pr, Color(col, 0.14 * a))
		ci.draw_circle(q + Vector2(-pr * 0.2, -pr * 0.25), pr * 0.55, Color(clair, 0.08 * a))
	ci.draw_circle(p, r * 0.4 * appear, Color(col, 0.16 * a))
	# Bulles qui montent et éclatent (le motif du poison).
	for i in 10:
		var bk := fposmod(t * 0.55 + i * 0.137, 1.0)
		var ang := i * 2.39996
		var q := p + Vector2.from_angle(ang) * r * 0.75 * fposmod(i * 0.618, 1.0) + Vector2(0, -bk * r * 0.5)
		var br := (2.5 + 3.5 * bk) * appear
		if bk < 0.85:
			ci.draw_arc(q, br, 0, TAU, 12, Color(clair, 0.75 * a * (1.0 - bk)), Art.TRAIT_FIN, true)
		else:
			# Éclatement : quatre petits points.
			for j in 4:
				ci.draw_circle(q + Vector2.from_angle(j * PI / 2.0) * br * 1.4, 1.2, Color(clair, 0.7 * a))


## Floraison : une grande fleur de sève s'ouvre autour du héros (anticipation), l'onde de vie
## repousse les Flétris (coup), puis les pétales se détachent et s'envolent en tournoyant (fin).
static func _bloom(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e["r"]
	var seve := Art.ec("seve")
	var clair := Art.ec("seve", "clair")
	var open := 0.22
	var wave := 0.5
	if on_ground:
		var g := Anim.ease_out(clampf((k - open * 0.5) / (wave - open * 0.5), 0.0, 1.0))
		var a := 1.0 - clampf((k - wave) / (1.0 - wave), 0.0, 1.0)
		ci.draw_circle(p, r * g, Color(seve, 0.12 * a))
		ci.draw_arc(p, r * g, 0, TAU, 56, Color(clair, 0.7 * a), 4.0, true)
		# Brins d'herbe qui poussent au passage de l'onde.
		for i in 16:
			var d := Vector2.from_angle(i * TAU / 16.0 + 0.2)
			var q := p + d * r * g * (0.6 + 0.3 * fposmod(i * 0.618, 1.0))
			var h := 5.0 * g
			var gc := Color(Art.c("decor_vivant").lightened(0.35), a)
			ci.draw_line(q, q + Vector2(0, -h * 1.4), gc, 1.5, true)
			for sgn: int in [-1, 1]:
				ci.draw_colored_polygon(HeroArt.leaf_pts(q + Vector2(sgn * h * 0.6, -h), h * 0.6, -PI / 2.0 + sgn * 0.9), gc)
		return
	# La fleur : huit pétales qui s'ouvrent, puis se détachent et s'envolent.
	var petals := 8
	var o := Anim.ease_out_back(clampf(k / open, 0.0, 1.0))
	var fly := clampf((k - wave * 0.8) / (1.0 - wave * 0.8), 0.0, 1.0)
	Art.glow(ci, p, 30.0 + 40.0 * o * (1.0 - fly), "seve")
	for i in petals:
		var la := i * TAU / petals - PI / 2.0 + fly * 1.2
		var dist := 22.0 * o + r * 0.85 * Anim.ease_out(fly)
		var q := p + Vector2.from_angle(la) * dist + Vector2(0, 30.0 * fly * fly)
		var pl := HeroArt.leaf_pts(q, 13.0 * o * (1.0 - 0.4 * fly), la + fly * 5.0 * (1.0 if i % 2 == 0 else -1.0))
		var pc := seve.lerp(clair, 0.35 if i % 2 == 0 else 0.0)
		ci.draw_colored_polygon(pl, Color(pc, 1.0 - fly))
		Art.outline(ci, pl, Color(Art.ec("seve", "sombre"), 1.0 - fly), 1.0)
	# Pollen qui s'envole.
	if k > open:
		var u := (k - open) / (1.0 - open)
		for i in 10:
			var la := i * 2.39996
			var q := p + Vector2.from_angle(la) * (20.0 + r * 0.6 * u * fposmod(i * 0.618, 1.0) + 20.0 * u) + Vector2(0, -24.0 * u)
			ci.draw_circle(q, 2.0, Color(Art.c("butin").lerp(clair, 0.5), 1.0 - u))


## Chute du héros : il se fane sur place (le corps se ternit, la cape tombe), puis s'efface en
## feuilles mortes emportées par le vent. Il renaît au sanctuaire (voir HeroArt, appear).
static func _chute(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var facing: float = e.get("facing", 0.0)
	var fall := 0.45
	if k < fall:
		HeroArt.draw(ci, p, 14.0, facing, {"t": e["t"], "wither": Anim.ease_out(k / fall)})
		return
	var u := (k - fall) / (1.0 - fall)
	# Silhouette qui s'efface.
	ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, 4), 16.0 * (1.0 - u), 9.0 * (1.0 - u), 16), Color(Art.c("decor"), 0.7 * (1.0 - u)))
	for i in 10:
		var la := -PI / 2.0 + (i - 4.5) * 0.35
		var q := p + Vector2.from_angle(la) * (6.0 + 40.0 * Anim.ease_out(u)) + Vector2(30.0 * u * u + sin(u * 6.0 + i) * 6.0, 10.0 * u)
		var lc := Art.c("joueur_accent").darkened(0.3).lerp(Art.c("decor").lightened(0.3), u)
		ci.draw_colored_polygon(HeroArt.leaf_pts(q, 5.0, u * 6.0 + i), Color(lc, 1.0 - u))


# --- Spore ---

## Vesse-de-loup : le champignon sort de terre (anticipation), respire en lâchant une spore de temps
## en temps tant qu'il guette (armé : un anneau de pointillés au sol marque sa portée), puis éclate
## en collerette de poussière violette (coup) qui retombe (fin). « burst » : instant de l'éclatement.
static func _vesse(ci: CanvasItem, e: Dictionary, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e.get("r", 90.0)
	var t: float = e["t"]
	var col := Art.ec("poison")
	var clair := Art.ec("poison", "clair")
	var sombre := Art.ec("poison", "sombre")
	if e.has("burst"):
		var bk := clampf((t - float(e["burst"])) / 0.45, 0.0, 1.0)
		var g := Anim.ease_out(bk)
		var a := 1.0 - bk
		if on_ground:
			ci.draw_circle(p, r * (0.4 + 0.6 * g), Color(sombre, 0.3 * a))
			return
		ci.draw_arc(p, r * (0.3 + 0.75 * g), 0.0, TAU, 40, Color(clair, 0.9 * a), 4.0 * a + 0.5, true)
		for i in 10:
			var d := Vector2.from_angle(i * TAU / 10.0 + 0.2)
			ci.draw_circle(p + d * r * (0.15 + 0.8 * g) + Vector2(0, -12.0 * sin(bk * PI)), (5.0 - 3.0 * bk), Color(col, a))
		ci.draw_circle(p, 10.0 * (1.0 - g), Color(clair, a))
		return
	var grow := Anim.pop(clampf(t / 0.3, 0.0, 1.0))
	var armed: bool = t >= float(e.get("arm", 0.5))
	var breathe := 1.0 + 0.06 * sin(t * 4.0)
	if on_ground:
		ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, 4), 15.0 * grow, 6.0 * grow, 14), Color(Art.c("ombre"), 0.5))
		if armed:
			var segs := 14
			for i in segs:
				var a0 := i * TAU / segs + t * 0.3
				ci.draw_arc(p, r * 0.75, a0, a0 + TAU / segs * 0.4, 3, Color(clair, 0.3), Art.TRAIT_FIN, true)
		return
	# Pied clair, chapeau rond violet tacheté, contour de la charte.
	var s := 13.0 * grow
	ci.draw_rect(Rect2(p + Vector2(-s * 0.28, -s * 0.5), Vector2(s * 0.56, s * 0.9)), Art.ec("poison", "clair").lightened(0.3))
	var cap := Art.ellipse(p + Vector2(0, -s * 0.6), s * breathe, s * 0.75 * breathe, 18)
	var edge := cap.duplicate()
	edge.append(cap[0])
	ci.draw_colored_polygon(cap, col)
	ci.draw_polyline(edge, Art.c("contour"), Art.TRAIT, true)
	ci.draw_circle(p + Vector2(-s * 0.35, -s * 0.85), s * 0.18, clair)
	ci.draw_circle(p + Vector2(s * 0.3, -s * 0.6), s * 0.14, clair)
	ci.draw_circle(p + Vector2(s * 0.0, -s * 1.05), s * 0.1, clair)
	if armed:
		# Une spore monte du chapeau toutes les 0,8 s.
		var bk := fposmod(t, 0.8) / 0.8
		ci.draw_circle(p + Vector2(sin(t * 3.0) * 4.0, -s * 1.4 - bk * 22.0), 2.5 * (1.0 - bk) + 0.5, Color(clair, 1.0 - bk))


## Essaim : un filament de spores file d'un ennemi à l'autre, une boule de spores à sa tête,
## et un éclat au point touché.
static func _essaim(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var to: Vector2 = e.get("to", p)
	var col := Art.ec("poison")
	var clair := Art.ec("poison", "clair")
	var head := Anim.ease_out(clampf(k / 0.5, 0.0, 1.0))
	var a := 1.0 - clampf((k - 0.5) / 0.5, 0.0, 1.0)
	var d := to - p
	var n := d.orthogonal().normalized() * minf(18.0, d.length() * 0.15)
	var pts := PackedVector2Array()
	for i in 9:
		var u := i / 8.0 * head
		pts.append(p + d * u + n * sin(u * TAU) * (1.0 - u))
	ci.draw_polyline(pts, Color(col, 0.8 * a), 3.0, true)
	ci.draw_polyline(pts, Color(clair, 0.5 * a), 1.2, true)
	var q: Vector2 = pts[pts.size() - 1]
	for i in 4:
		ci.draw_circle(q + Vector2.from_angle(i * TAU / 4.0 + k * 8.0) * 4.0, 3.0, Color(col, a))
	ci.draw_circle(q, 3.5, Color(clair, a))
	if k > 0.45:
		var bk := (k - 0.45) / 0.55
		ci.draw_arc(to, 6.0 + 14.0 * Anim.ease_out(bk), 0.0, TAU, 16, Color(clair, 0.8 * (1.0 - bk)), 2.0, true)


## Éclosion : un anneau violet se resserre sur le héros (anticipation), le poison de chaque Flétri
## touché éclot en fleur de spores (coup), et la poussière retombe en s'élargissant (fin).
static func _eclosion(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e["r"]
	var col := Art.ec("poison")
	var clair := Art.ec("poison", "clair")
	var sombre := Art.ec("poison", "sombre")
	var close := 0.25
	var targets: Array = e.get("targets", [])
	if on_ground:
		var c := Anim.ease_in(clampf(k / close, 0.0, 1.0))
		var a := 1.0 - clampf((k - close) / 0.3, 0.0, 1.0)
		ci.draw_circle(p, r, Color(sombre, 0.16 * a))
		ci.draw_arc(p, lerpf(r, 28.0, c), 0, TAU, 56, Color(col, 0.7 * a), 4.0, true)
		for q: Vector2 in targets:
			var bk := clampf((k - close * 0.6) / 0.5, 0.0, 1.0)
			ci.draw_circle(q, 30.0 * Anim.ease_out(bk), Color(sombre, 0.25 * (1.0 - bk)))
		return
	for q: Vector2 in targets:
		var bk := clampf((k - close * 0.6) / 0.6, 0.0, 1.0)
		if bk <= 0.0 or bk >= 1.0:
			continue
		var b := Anim.ease_out(bk)
		var a := 1.0 - bk
		# Fleur de spores : cinq pétales ronds qui s'ouvrent, cœur clair, poussière qui monte.
		for i in 5:
			var d := Vector2.from_angle(i * TAU / 5.0 - PI / 2.0)
			ci.draw_circle(q + d * 14.0 * b, 7.0 * (1.0 - 0.4 * bk), Color(col, 0.8 * a))
		ci.draw_circle(q, 5.0 * (1.0 - bk) + 1.0, Color(clair, a))
		for i in 6:
			var d := Vector2.from_angle(i * TAU / 6.0 + 0.4)
			ci.draw_circle(q + d * 26.0 * b + Vector2(0, -16.0 * bk), 2.0, Color(clair, 0.8 * a))
	if k > 0.6:
		var hk := (k - 0.6) / 0.4
		ci.draw_arc(p, 18.0 + 16.0 * Anim.ease_out(hk), 0, TAU, 32, Color(clair, 0.7 * (1.0 - hk)), 3.0, true)
