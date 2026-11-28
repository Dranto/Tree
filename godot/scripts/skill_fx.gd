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

const Content = preload("res://scripts/content.gd")

## Au plus autant d'effets à la fois (les plus anciens partent d'abord).
const MAX_EFFECTS := 48

## Durée de chaque signature (secondes). Les racines et le nuage durent ce que dure leur effet.
const DUREE := {
	"graine_depart": 0.12, "graine_impact": 0.3, "epine_impact": 0.3,
	"nova": 0.6, "fouet": 0.34, "racines": 0.6, "volee": 0.24, "saignee": 0.7,
	"cloud": 5.0, "bloom": 1.1, "chute": 1.1,
	"vesse": 9.0, "essaim": 0.36, "eclosion": 0.75,
	"relache": 0.24, "pret": 0.5,
}
## Esquive : la traînée et les images rémanentes vivent la durée de l'élan plus ESQUIVE_TRAINE,
## les feuilles soulevées ESQUIVE_FEUILLES.
const ESQUIVE_FEUILLES := 0.75

## Vrai pour le nœud du sol, faux pour celui du dessus.
var sol := false
## Liste partagée entre les deux nœuds (seul le nœud du dessus fait avancer le temps).
var effects: Array = []
var twin: SkillFx
var _dirty := false
## Recharges vues au pas précédent (id -> secondes) : un lancer (la recharge remonte) pose la
## relâche, une recharge qui s'achève pose l'éclat « prête ».
var _seen_cds := {}
var _last_ready := -10.0
var _clock := 0.0
## Budget d'éclats de l'image en cours (data/feel.json › skills › max_particles).
static var _parts := 0


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
		var tuned = feel_section().get("durations", {}).get(id)
		e["dur"] = float(tuned) if tuned != null else DUREE.get(id, VentFx.DUREE.get(id, AubeFx.DUREE.get(id, SeveFx.DUREE.get(id, RacineFx.DUREE.get(id, 0.4)))))
	if id == "relache":
		e["dur"] = feel("release_time", 0.24)
	elif id == "pret":
		e["dur"] = feel("ready_time", 0.5)
	elif id == "esquive":
		e["dur"] = float(e.get("dash", 0.16)) + maxf(feel("dash_ghost_life", 0.3), ESQUIVE_FEUILLES)
		e["ghosts"] = []
		e["from"] = e["pos"]
	if reduced() and id in ["graine_depart", "graine_impact"]:
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
	_clock += delta
	_watch_player()
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
		if e["id"] == "esquive":
			_dash_step(e)
		if e["t"] >= e["dur"]:
			effects.remove_at(i)
		else:
			i += 1
	if not effects.is_empty() or _dirty:
		queue_redraw()
	_dirty = not effects.is_empty()


func _draw() -> void:
	_parts = 0
	for e in effects:
		draw_effect(self, e, sol)


## Réglage de data/feel.json › skills (valeur par défaut si absent).
static func feel(key: String, default := 0.0) -> float:
	return float(feel_section().get(key, default))


static func feel_section() -> Dictionary:
	return Content.feel().get("skills", {})


## Anticipation propre à une compétence, en secondes (data/feel.json › skills › windup › id, sinon
## « default »), multipliée par le réglage commun « anticipation ». Purement visuel : l'effet en
## jeu, lui, a lieu quand il a toujours eu lieu.
static func windup(id: String, default := 0.2) -> float:
	var w = feel_section().get("windup", {}).get(id)
	return (float(w) if w != null else default) * feel("anticipation", 1.0)


## « Réduire les effets » (Settings.reduce_effects), lu à l'exécution : les dessins des branches
## (VentFx, AubeFx…) appellent SkillFx et sont chargés par Art, y compris dans les tests lancés sans
## les autoloads.
static func reduced() -> bool:
	var loop = Engine.get_main_loop()
	var st = loop.root.get_node_or_null("Settings") if loop is SceneTree else null
	return st != null and bool(st.reduce_effects)


## Quantité d'éclats d'un effet : divisée par trois avec « réduire les effets » (au moins un).
static func amount(n: int) -> int:
	return maxi(1, n / 3) if reduced() else n


## Images rémanentes d'une esquive, et feuilles qu'elle soulève (reduce : « réduire les effets »).
static func ghost_count(reduce = null) -> int:
	if reduce == null:
		reduce = reduced()
	var n := int(feel("dash_ghosts", 3))
	return maxi(1, n / 3) if reduce else n


static func leaf_count(reduce = null) -> int:
	if reduce == null:
		reduce = reduced()
	var n := int(feel("dash_leaves", 8))
	return maxi(1, n / 3) if reduce else n


## Prend jusqu'à n éclats dans le budget de l'image (plafond global, voir max_particles).
static func _take(n: int) -> int:
	var left := int(feel("max_particles", 140)) - _parts
	var got := clampi(n, 0, maxi(left, 0))
	_parts += got
	return got


## Surveille les recharges du Porte-Graine (le nœud parent est la scène de jeu) : chaque lancer
## pose une relâche dans la couleur de l'élément, chaque longue recharge qui s'achève un éclat
## « prête » sur le héros. Rien n'est écrit dans le jeu.
func _watch_player() -> void:
	var m = get_parent()
	if m == null or not ("player" in m) or m.player == null or not is_instance_valid(m.player):
		return
	var p = m.player
	var min_cd := feel("ready_min_cooldown", 2.5)
	for id in p.cds:
		var now: float = p.cds[id]
		var was: float = _seen_cds.get(id, now)
		_seen_cds[id] = now
		# Un lancer remet la recharge à plein (player.cast) ; une recharge retouchée par un effet ne compte pas.
		if now > was + 0.04 and now >= float(p.skill_cd.get(id, 0.0)) * 0.95:
			play("relache", {"pos": p.position, "dir": p.aim, "follow": p, "skill": id,
				"col": Art.ec(Art.ELEMENT_DE_COMPETENCE.get(id, "seve"))})
		elif was > 0.0 and now <= 0.0 and id in p.bar and float(p.skill_cd.get(id, 0.0)) >= min_cd \
				and _clock - _last_ready >= feel("ready_gap", 0.2) and p.hp > 0.0:
			# Plusieurs compétences prêtes ensemble : un seul éclat.
			_last_ready = _clock
			play("pret", {"pos": p.position, "follow": p, "skill": id,
				"col": Art.ec(Art.ELEMENT_DE_COMPETENCE.get(id, "seve"))})


## Esquive : pendant l'élan, une image rémanente à intervalles réguliers (ghost_count en tout).
func _dash_step(e: Dictionary) -> void:
	var dash: float = e.get("dash", 0.16)
	var ghosts: Array = e["ghosts"]
	var n := ghost_count()
	if ghosts.size() < n and e["t"] >= dash * (ghosts.size() + 0.5) / n and e["t"] <= dash + 0.02:
		ghosts.append({"pos": e["pos"], "t": e["t"]})
	if e["t"] <= dash:
		e["to"] = e["pos"]


## Dessine un effet à son instant e["t"]. sol : la partie au sol (vrai) ou celle du dessus (faux).
static func draw_effect(ci: CanvasItem, e: Dictionary, on_ground: bool) -> void:
	var k: float = clampf(e["t"] / maxf(e["dur"], 0.001), 0.0, 1.0)
	if VentFx.draws(e["id"]):
		VentFx.draw(ci, e, on_ground)
		return
	if AubeFx.draws(e["id"]):
		AubeFx.draw(ci, e, on_ground)
		return
	if SeveFx.draws(e["id"]):
		SeveFx.draw(ci, e, on_ground)
		return
	if RacineFx.draws(e["id"]):
		RacineFx.draw(ci, e, on_ground)
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
		"esquive":
			_esquive(ci, e, on_ground)
		"relache":
			if not on_ground:
				_relache(ci, e, k)
		"pret":
			_pret(ci, e, k, on_ground)


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
	var grow := 0.18 * feel("anticipation", 1.0)   # anticipation : la couronne se serre puis se forme
	var hit := grow + 0.3    # fin du coup : les épines sont au bord
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
		# Les épines sortent de la capuche, se serrent contre le héros qui tremble (la tension
		# monte), puis se dressent en couronne juste avant de partir.
		var u := k / grow
		var g := Anim.ease_out_back(u)
		var squeeze := sin(u * PI) * 5.0
		var shake := Vector2(sin(k * 140.0) * 1.5 * u, 0)
		for i in n:
			var d := Vector2.from_angle(i * TAU / n)
			Art._thorn(ci, p + shake + d * (16.0 - squeeze), d, 14.0 * g + 4.0 * u, clair)
		ci.draw_arc(p, 30.0 - 10.0 * u, 0, TAU, 32, Color(Art.c("danger_eclair"), 0.45 * u), 2.0, true)
		return
	var g := Anim.ease_out(clampf((k - grow) / (hit - grow), 0.0, 1.0))
	var rad := lerpf(18.0, r, g)
	var fade := clampf((k - hit) / (1.0 - hit), 0.0, 1.0)
	# Onde de choc pâle, épaisse au moment du coup.
	if k < hit + 0.1:
		var w := Anim.flash((k - grow) / (hit - grow + 0.1))
		ci.draw_arc(p, rad, 0, TAU, 56, Color(Art.c("danger_eclair"), 0.8 * w), 3.0 + 9.0 * w, true)
		# Seconde onde, en retard, plus fine : l'onde a de l'épaisseur.
		ci.draw_arc(p, rad * 0.78, 0, TAU, 48, Color(clair, 0.5 * w), 2.0 + 3.0 * w, true)
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
	var wind := 0.2 * feel("anticipation", 1.0)   # anticipation : la liane s'enroule
	var sweep := 0.52  # fin du balayage
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
			# Au tout début du balayage (cur == a0) tous les points sont alignés : rien à dessiner.
			Art.safe_polygon(ci, pts, Color(col, 0.13 * fade))
			ci.draw_arc(p, reach, a0, cur, 24, Color(clair, 0.5 * fade), 2.0, true)
		return
	if k < wind:
		_fouet_coil(ci, p, a0, Anim.ease_out(k / wind))
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
		# Le bout dépasse la fin de l'arc puis revient (relâche), avant que la liane se rétracte.
		tip_a = a0 + arc + 0.32 * sin(u * PI) * (1.0 - u)
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
			ci.draw_circle(tip, 13.0 * crack, Color(Art.c("danger_eclair"), 0.85 * crack))
			for i in 6:
				var la := tdir.angle() + i * PI / 3.0 + 0.4
				var l1 := 14.0 + (18.0 if i % 2 == 0 else 9.0) * crack
				ci.draw_line(tip + Vector2.from_angle(la) * 6.0, tip + Vector2.from_angle(la) * l1, Color(Art.c("danger_eclair"), crack), 2.5, true)
	# Claquement : une onde part du bout au moment du coup et s'élargit après.
	var snap := clampf((k - (wind + (sweep - wind) * 0.5)) / 0.3, 0.0, 1.0)
	if snap > 0.0 and snap < 1.0:
		var sp := p + Vector2.from_angle(a0 + arc * 0.62) * reach
		ci.draw_arc(sp, 8.0 + 30.0 * Anim.ease_out(snap), 0.0, TAU, 28, Color(clair, 0.8 * (1.0 - snap)), 3.0 * (1.0 - snap) + 0.5, true)
	# Gouttes de sang projetées du bout, qui retombent (saignement posé par le fouet).
	if k > sweep * 0.8:
		var u := (k - sweep * 0.8) / (1.0 - sweep * 0.8)
		var blood := Art.ec("saignement", "clair")
		for i in 4:
			var la := a0 + arc * (0.35 + 0.2 * i)
			var q := p + Vector2.from_angle(la) * reach * (0.95 + 0.15 * u) + Vector2(0, 26.0 * u * u)
			Art._drop(ci, q, 3.2 * (1.0 - 0.5 * u), Color(blood, 1.0 - u))


## Anticipation du fouet : la liane s'enroule en spirale derrière la main (w : 0 → 1, enroulée),
## épines rentrées, avant de se détendre d'un coup dans l'arc.
static func _fouet_coil(ci: CanvasItem, p: Vector2, a0: float, w: float) -> void:
	var vine := Art.ec("racine").darkened(0.1)
	var clair := Art.ec("epine", "clair")
	var back := a0 - 0.9
	var hand := p + Vector2.from_angle(a0 - 0.3) * 16.0
	var c := p + Vector2.from_angle(back) * 26.0
	var pts := PackedVector2Array([hand])
	for i in range(1, 16):
		var u := i / 15.0
		var ang := back + PI * 0.4 + u * TAU * (0.5 + 1.1 * w)
		pts.append(c + Vector2.from_angle(ang) * (13.0 - 8.0 * u * w) + (hand - c) * (1.0 - u) * (1.0 - w))
	ci.draw_polyline(pts, Art.c("contour"), 7.0, true)
	ci.draw_polyline(pts, vine, 4.5, true)
	ci.draw_polyline(pts, vine.lightened(0.35), 1.5, true)
	for i in range(3, 15, 3):
		var dir := (pts[i + 1] - pts[i]).normalized()
		Art._thorn(ci, pts[i], dir.orthogonal(), 4.0 + 3.0 * (1.0 - w), clair)
	# La tension monte : un point de lumière au cœur de la spirale.
	ci.draw_circle(c, 3.0 + 4.0 * w, Color(Art.c("danger_eclair"), 0.5 * w))


## Racines voraces : le sol se fend en cercle (anticipation), des racines noueuses jaillissent
## et se referment sur la zone (coup), tiennent en ondulant, puis se rétractent sous terre (fin).
static func _racines(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var r: float = e["r"]
	var dur: float = e["dur"]
	var t: float = e["t"]
	var crack := 0.14 * feel("anticipation", 1.0)   # s : la terre se soulève et se fend
	var rise := crack + 0.18    # s : les racines sont dressées
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
	# Racines : graine fixe par effet (même tirage d'une image à l'autre).
	var n := clampi(int(r / 14.0), 6, 12)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(e.get("seed", 1))
	if t < crack:
		# Anticipation : la terre se soulève en mottes là où chaque racine va sortir, et la pointe
		# perce. Même tirage que les racines (six nombres par racine, dans le même ordre).
		var pk := Anim.ease_in(t / crack)
		for i in n:
			var a := i * TAU / n + rng.randf_range(-0.25, 0.25)
			var dist := r * rng.randf_range(0.25, 0.92)
			for j in 4:
				rng.randf()
			var base := p + Vector2.from_angle(a) * dist
			var shake := Vector2(sin(t * 80.0 + i) * 1.5 * pk, 0)
			ci.draw_colored_polygon(Art.ellipse(base + shake + Vector2(0, -3.0 * pk), 9.0 * pk + 1.0, 5.0 * pk + 0.5, 10), sombre.lightened(0.1))
			if pk > 0.5:
				Art._thorn(ci, base + shake + Vector2(0, -4.0), Vector2.UP, 10.0 * (pk - 0.5), clair)
		return
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
		# Quand la racine s'efface (g petit), le décalage fixe de « mid » fait se croiser le polygone.
		Art.fill_safe(ci, poly, col)
		Art.fill_safe(ci, PackedVector2Array([base + side * w * 0.2, mid + side * w * 0.5, tip, mid + side * w * 0.05]), col.lightened(0.18))
		Art.outline(ci, poly, Art.c("contour"), Art.TRAIT_FIN)
		# Nœuds et mousse au bout.
		ci.draw_circle(mid, w * 0.38, sombre)
		ci.draw_circle(mid + Vector2(-w * 0.12, -w * 0.12), w * 0.15, col.lightened(0.3))
		ci.draw_circle(tip, maxf(w * 0.3, 1.5), clair)
		# Mottes de terre projetées à la sortie.
		var burst := clampf((t - crack - delay) / 0.2, 0.0, 1.0)
		if burst < 1.0:
			for j in amount(5):
				var la := -PI / 2.0 + (j - 2) * 0.6
				var q := base + Vector2.from_angle(la) * 24.0 * burst + Vector2(0, 34.0 * burst * burst)
				ci.draw_circle(q, 3.2 * (1.0 - burst), sombre.lightened(0.15))
	# Prise : au moment où les racines se referment, un anneau se serre sur la zone.
	var grab := clampf((t - rise + 0.04) / 0.22, 0.0, 1.0)
	if grab > 0.0 and grab < 1.0:
		ci.draw_arc(p, r * lerpf(0.95, 0.45, Anim.ease_out(grab)), 0.0, TAU, 40, Color(clair, 0.85 * (1.0 - grab)), 4.0 * (1.0 - grab) + 1.0, true)


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
	var sombre := Art.ec("epine", "sombre")
	var lantern := p + d * 20.0
	# Départ : une bouffée claire et un anneau de recul derrière le héros.
	var burst := clampf(k / 0.35, 0.0, 1.0)
	if burst < 1.0:
		ci.draw_circle(lantern, 14.0 * Anim.flash(burst), Color(Art.c("danger_eclair"), 0.85 * (1.0 - burst)))
		ci.draw_arc(p - d * 6.0, 14.0 + 26.0 * Anim.ease_out(burst), d.angle() + PI - 1.1, d.angle() + PI + 1.1, 16, Color(clair, 0.7 * (1.0 - burst)), 3.0, true)
	for i in count:
		var la := d.angle() + ((i / float(maxi(count - 1, 1))) - 0.5) * spread
		var u := Vector2.from_angle(la)
		ci.draw_line(p + u * (18.0 + 50.0 * g), p + u * (46.0 + 150.0 * g), Color(clair, 0.55 * a), 2.5 * a + 0.5, true)
	# Collerette d'épines qui s'ouvre comme un éventail en tirant, puis se recharge : de nouvelles
	# épines repoussent une à une autour de la lanterne.
	for i in 7:
		var la := d.angle() + (i / 6.0 - 0.5) * (spread + 0.8) * (0.5 + 0.5 * g)
		Art._thorn(ci, p + Vector2.from_angle(la) * (16.0 + 10.0 * g), Vector2.from_angle(la), 15.0 * (1.0 - burst), Color(clair, 1.0 - burst))
	if k > 0.3:
		var rk := (k - 0.3) / 0.7
		for i in 5:
			var gi := clampf(rk * 1.6 - i * 0.15, 0.0, 1.0)
			if gi <= 0.0:
				continue
			var la := d.angle() + (i / 4.0 - 0.5) * 1.4
			Art._thorn(ci, lantern + Vector2.from_angle(la) * 4.0, Vector2.from_angle(la), 7.0 * Anim.ease_out_back(gi) * (1.0 - Anim.ease_in(clampf((rk - 0.75) * 4.0, 0.0, 1.0))), sombre.lerp(clair, gi))


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
		ci.draw_circle(p, lerpf(r, 24.0, c), Color(sombre, 0.16 * a * c))
		ci.draw_arc(p, lerpf(r, 24.0, c), 0, TAU, 56, Color(col, 0.85 * a), 5.0 + 4.0 * c, true)
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
			ci.draw_circle(q, 22.0 * b, Color(clair, 0.55 * (1.0 - bk)))
			# Étoile de sang : six pointes qui jaillissent du Flétri.
			for i in 6:
				var sd := Vector2.from_angle(i * TAU / 6.0 + 0.3)
				var sn := sd.orthogonal() * 4.0 * (1.0 - bk)
				# Triangle dégénéré (début ou fin de l'éclatement) : Godot refuse de le trianguler.
				if sn.length() > 0.3 and b > 0.02:
					ci.draw_colored_polygon(PackedVector2Array([q + sn, q + sd * 30.0 * b, q - sn]), Color(col, 0.9 * (1.0 - bk)))
			for i in 7:
				var la := i * TAU / 7.0 - PI / 2.0
				var dq: Vector2 = q + Vector2.from_angle(la) * 24.0 * b + Vector2(0, 14.0 * bk * bk)
				Art._drop(ci, dq, 3.5 * (1.0 - 0.5 * bk), Color(col.lightened(0.2), 1.0 - bk))
		var fk := clampf((k - close) / (1.0 - close), 0.0, 1.0)
		if fk > 0.0 and fk < 1.0:
			var from: Vector2 = q
			var ctrl: Vector2 = from.lerp(p, 0.5) + (p - from).orthogonal().normalized() * 30.0
			# Le filet lui-même : un trait sombre le long de la courbe, derrière les gouttes.
			var head := clampf(fk * 1.4, 0.0, 1.0)
			var line := PackedVector2Array()
			for j in 9:
				var u := lerpf(maxf(head - 0.45, 0.0), head, j / 8.0)
				line.append(from.lerp(ctrl, u).lerp(ctrl.lerp(p, u), u))
			ci.draw_polyline(line, Color(sombre, 0.7 * (1.0 - fk)), 2.5, true)
			for j in 4:
				var u := clampf(fk * 1.4 - j * 0.12, 0.0, 1.0)
				if u <= 0.0 or u >= 1.0:
					continue
				var pos := from.lerp(ctrl, u).lerp(ctrl.lerp(p, u), u)
				Art._drop(ci, pos, 3.0, Color(clair, 1.0 - u * 0.5))
	# Le héros boit : deux battements rouge clair à la fin, et le corps s'empourpre.
	if k > 0.6:
		var hk := (k - 0.6) / 0.4
		ci.draw_circle(p, 15.0, Color(clair, 0.35 * Anim.flash(hk * 1.5)))
		ci.draw_arc(p, 18.0 + 18.0 * Anim.ease_out(hk), 0, TAU, 32, Color(clair, 0.85 * (1.0 - hk)), 3.5, true)
		if hk > 0.25:
			var h2 := (hk - 0.25) / 0.75
			ci.draw_arc(p, 18.0 + 12.0 * Anim.ease_out(h2), 0, TAU, 32, Color(col, 0.7 * (1.0 - h2)), 2.5, true)


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
	# Anticipation (windup › cloud) : une poche de spores gonfle et tremble au point visé, puis crève
	# en lâchant le nuage (anneau clair qui file jusqu'au bord).
	var w := windup("cloud", 0.25)
	if t < w:
		var u := t / w
		var jit := Vector2(sin(t * 90.0) * 2.0 * u, 0)
		if on_ground:
			ci.draw_colored_polygon(Art.ellipse(p, 10.0 + r * 0.3 * u, (10.0 + r * 0.3 * u) * 0.5, 18), Color(sombre, 0.35))
			return
		var pr := 6.0 + r * 0.22 * Anim.ease_in(u)
		ci.draw_circle(p + jit, pr, Color(col, 0.75))
		ci.draw_circle(p + jit + Vector2(-pr * 0.3, -pr * 0.3), pr * 0.35, Color(clair, 0.6))
		ci.draw_arc(p + jit, pr, 0.0, TAU, 20, Color(sombre, 0.9), 1.5, true)
		for i in 3:
			ci.draw_circle(p + jit + Vector2.from_angle(i * 2.1 + 0.5) * pr * 0.55, pr * 0.12, Color(sombre, 0.8))
		return
	var appear := Anim.pop(clampf((t - w) / 0.35, 0.0, 1.0))
	var end_k := clampf((t - (dur - 0.6)) / 0.6, 0.0, 1.0)
	var a := 1.0 - end_k
	var pop_k := (t - w) / 0.35
	if pop_k < 1.0 and not on_ground:
		ci.draw_arc(p, r * (0.2 + 0.9 * Anim.ease_out(pop_k)), 0.0, TAU, 40, Color(clair, 0.9 * (1.0 - pop_k)), 4.0 * (1.0 - pop_k) + 1.0, true)
	if on_ground:
		# Tache de sol rongé et bord en pointillés (la zone qui fait mal).
		ci.draw_colored_polygon(Art.ellipse(p, r * appear + 1.0, r * appear * 0.94 + 1.0, 32), Color(sombre, 0.3 * a))
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
		var bud0 := windup("bloom", 0.16) / maxf(float(e["dur"]), 0.001)
		k = clampf((k - bud0) / maxf(1.0 - bud0, 0.001), 0.0, 1.0)
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
			if h < 0.5:
				continue   # onde pas encore partie : une feuille de taille nulle ne se triangule pas
			ci.draw_line(q, q + Vector2(0, -h * 1.4), gc, 1.5, true)
			for sgn: int in [-1, 1]:
				Art.safe_polygon(ci, HeroArt.leaf_pts(q + Vector2(sgn * h * 0.6, -h), h * 0.6, -PI / 2.0 + sgn * 0.9), gc)
		return
	# Anticipation (windup › bloom) : un bouton fermé gonfle sur le héros pendant que la sève monte
	# du sol vers lui ; puis il éclate en fleur.
	var bud := windup("bloom", 0.16) / maxf(float(e["dur"]), 0.001)
	if k < bud:
		var u := k / bud
		for i in amount(8):
			var d := Vector2.from_angle(i * TAU / 8.0 + 0.2)
			var q := p + d * lerpf(r * 0.55, 10.0, Anim.ease_in(u)) + Vector2(0, -6.0 * u)
			ci.draw_circle(q, 3.0, Color(clair, 0.5 + 0.5 * u))
		Art.glow(ci, p, 18.0 + 14.0 * u, "seve")
		for i in 4:
			var la := -PI / 2.0 + (i - 1.5) * 0.35 * (1.0 + 0.4 * u)
			var pl := HeroArt.leaf_pts(p + Vector2(0, -6.0) + Vector2.from_angle(la) * 6.0, 10.0 + 5.0 * u, la)
			ci.draw_colored_polygon(pl, seve.lerp(clair, 0.3 * u))
			Art.outline(ci, pl, Art.ec("seve", "sombre"), 1.0)
		return
	k = (k - bud) / maxf(1.0 - bud, 0.001)
	# La fleur : huit pétales qui s'ouvrent, puis se détachent et s'envolent.
	var petals := 8
	var o := Anim.ease_out_back(clampf(k / open, 0.0, 1.0))
	if k < 0.2:
		# Éclatement du bouton : un anneau clair.
		ci.draw_arc(p, 20.0 + 60.0 * Anim.ease_out(k / 0.2), 0.0, TAU, 32, Color(clair, 1.0 - k / 0.2), 4.0, true)
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
	# Elle finit en point : rien à dessiner une fois réduite à rien (triangulation impossible).
	if u < 0.98:
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
		# Le chapeau gonfle et tremble un instant (windup › vesse), puis éclate.
		var inf := windup("vesse", 0.08)
		var it := t - float(e["burst"])
		if it < inf:
			if not on_ground:
				var u := it / maxf(inf, 0.001)
				var s0 := 13.0 * (1.0 + 0.6 * Anim.ease_in(u))
				var jit := Vector2(sin(t * 120.0) * 2.0, 0)
				ci.draw_colored_polygon(Art.ellipse(p + jit + Vector2(0, -13.0 * 0.6), s0, s0 * 0.8, 18), col.lerp(clair, 0.4 * u))
				ci.draw_arc(p + jit + Vector2(0, -13.0 * 0.6), s0, 0.0, TAU, 18, Art.c("contour"), Art.TRAIT, true)
			return
		var bk := clampf((it - inf) / 0.45, 0.0, 1.0)
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
	var emerge := clampf(t / 0.4, 0.0, 1.0)
	if on_ground:
		ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, 4), 15.0 * grow + 1.0, 6.0 * grow + 1.0, 14), Color(Art.c("ombre"), 0.5))
		if emerge < 1.0:
			# La terre se fend là où le champignon perce.
			for i in 4:
				var ang := i * TAU / 4.0 + 0.4
				ci.draw_line(p + Vector2(0, 4), p + Vector2(0, 4) + Vector2(cos(ang) * 24.0, sin(ang) * 10.0) * minf(emerge * 3.0, 1.0), Color(Art.ec("racine", "sombre"), 0.9 * (1.0 - emerge)), 2.0, true)
		if armed:
			var segs := 14
			for i in segs:
				var a0 := i * TAU / segs + t * 0.3
				ci.draw_arc(p, r * 0.75, a0, a0 + TAU / segs * 0.4, 3, Color(clair, 0.3), Art.TRAIT_FIN, true)
		return
	if emerge < 1.0:
		# Mottes de terre qui tombent du chapeau en sortant.
		for i in _take(amount(4)):
			var q := p + Vector2((i - 1.5) * 8.0, -16.0 * grow + 30.0 * emerge * emerge)
			ci.draw_circle(q, 2.5 * (1.0 - emerge) + 0.5, Color(Art.ec("racine", "sombre").lightened(0.15), 1.0 - emerge))
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
	# Premier bond (au lancer) : les spores tourbillonnent autour de la lanterne avant de partir.
	var sw := 0.0
	if e.get("first", false):
		sw = clampf(windup("essaim", 0.1) / maxf(float(e["dur"]), 0.001), 0.0, 0.6)
		if k < sw:
			var u := k / sw
			for i in _take(amount(6)):
				var q := p + Vector2.from_angle(i * TAU / 6.0 + u * 7.0) * lerpf(26.0, 6.0, Anim.ease_in(u))
				ci.draw_circle(q, 2.5, Color(clair if i % 2 == 0 else col, 0.9))
			return
		k = (k - sw) / (1.0 - sw)
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
		# La boule crève sur sa cible : une gerbe de spores.
		for i in _take(amount(5)):
			var sd := Vector2.from_angle(i * TAU / 5.0 + 0.3)
			ci.draw_circle(to + sd * 18.0 * Anim.ease_out(bk) + Vector2(0, -6.0 * bk), 2.5 * (1.0 - bk) + 0.5, Color(col, 1.0 - bk))


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
	if k < close * 0.6:
		# Anticipation : le poison de chaque Flétri gonfle en bulle qui tremble.
		var u := k / (close * 0.6)
		for q: Vector2 in targets:
			var jit := Vector2(sin(k * 300.0 + q.x) * 1.5 * u, 0)
			ci.draw_circle(q + jit + Vector2(0, -6), 5.0 + 11.0 * Anim.ease_in(u), Color(col, 0.35 + 0.3 * u))
			ci.draw_arc(q + jit + Vector2(0, -6), 5.0 + 11.0 * Anim.ease_in(u), 0.0, TAU, 14, Color(clair, 0.8), 1.2, true)
		ci.draw_circle(p, 14.0 + 4.0 * sin(u * PI * 3.0), Color(col, 0.25 * u))
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


# --- Esquive, relâche, compétence prête (jalon Éclat) ---

## Esquive : au sol, une traînée de sève du point de départ jusqu'au héros (elle se resserre et
## pâlit derrière lui) et 2 ou 3 images rémanentes de sa silhouette qui s'effacent ; au-dessus,
## des feuilles soulevées au départ qui tournoient puis retombent.
static func _esquive(ci: CanvasItem, e: Dictionary, on_ground: bool) -> void:
	var t: float = e["t"]
	var dash: float = e.get("dash", 0.16)
	var from: Vector2 = e.get("from", e["pos"])
	var to: Vector2 = e.get("to", e["pos"])
	var d: Vector2 = e.get("dir", Vector2.RIGHT)
	var seve := Art.ec("seve")
	var clair := Art.ec("seve", "clair")
	var trail_k := feel("dash_trail", 1.0)
	var life := feel("dash_ghost_life", 0.3)
	if on_ground:
		# Traînée : un fuseau qui part du départ et s'arrête au héros ; il se retire vers lui.
		var fade := clampf((t - dash) / 0.22, 0.0, 1.0)
		var span := to - from
		if trail_k > 0.0 and fade < 1.0 and span.length() > 4.0:
			var tail := from.lerp(to, Anim.ease_in(fade))
			var n := span.orthogonal().normalized()
			var w := 9.0 * trail_k * (1.0 - fade)
			var a := 0.5 * (1.0 - fade)
			ci.draw_colored_polygon(PackedVector2Array([tail, to + n * w, to + d * w * 0.6, to - n * w]), Color(seve, a * 0.55))
			ci.draw_line(tail, to, Color(clair, a), maxf(2.5 * (1.0 - fade), 1.0), true)
			# Trois filets de vitesse de part et d'autre.
			for j in 3:
				var off := n * (j - 1) * w * 0.9
				var u := 0.25 + 0.2 * j
				ci.draw_line(tail.lerp(to, u) + off, to.lerp(tail, 0.15) + off, Color(clair, a * 0.6), 1.2, true)
		# Images rémanentes : la silhouette du héros, en sève pâle, qui se défait.
		var facing: float = e.get("facing", d.angle())
		var ghosts: Array = e.get("ghosts", [])
		for i in ghosts.size():
			var g: Dictionary = ghosts[i]
			var gk := clampf((t - float(g["t"])) / life, 0.0, 1.0)
			if gk >= 1.0:
				continue
			var ga := (0.5 - 0.1 * (ghosts.size() - 1 - i)) * (1.0 - Anim.ease_in(gk))
			HeroArt.draw_ghost(ci, g["pos"] + Vector2(0, -2.0 * gk), 14.0 * (1.0 + 0.12 * gk), facing, Color(clair.lerp(seve, gk), ga))
		return
	# Feuilles soulevées au départ : jaillissent à l'opposé de l'élan, tournoient, retombent.
	var n_leaves := _take(leaf_count())
	var lk := clampf(t / ESQUIVE_FEUILLES, 0.0, 1.0)
	if lk >= 1.0:
		return
	var leaf_col := Art.c("joueur_accent").darkened(0.25)
	var grass := Art.c("decor_vivant").lightened(0.2)
	for i in n_leaves:
		var h := fposmod(i * 0.618 + 0.17, 1.0)
		var la := d.angle() + PI + (h - 0.5) * 2.2
		var sp := 40.0 + 70.0 * fposmod(i * 0.382 + 0.5, 1.0)
		var q := from + Vector2.from_angle(la) * sp * Anim.ease_out(lk) + Vector2(0, -34.0 * sin(lk * PI) * (0.6 + h) + 10.0 * lk)
		q.x += sin(lk * 9.0 + i) * 5.0 * lk
		var col := leaf_col if i % 3 != 0 else grass
		ci.draw_colored_polygon(HeroArt.leaf_pts(q, 4.0 + 1.5 * h, la + lk * (6.0 + 4.0 * h) * (1.0 if i % 2 == 0 else -1.0)), Color(col, 1.0 - lk * lk))


## Relâche d'un lancer : à la lanterne, un anneau dans la couleur de l'élément s'ouvre d'un coup,
## des rais filent vers la visée et une onde courte part au sol sous les pieds. Toutes les
## compétences l'ont : leur départ se voit même au milieu de la mêlée.
static func _relache(ci: CanvasItem, e: Dictionary, k: float) -> void:
	var p: Vector2 = e["pos"]
	var d: Vector2 = e.get("dir", Vector2.RIGHT)
	var col: Color = e.get("col", Art.ec("seve"))
	var hi := col.lerp(Color.WHITE, 0.45)
	var lantern := p + d * 20.0
	var g := Anim.ease_out(k)
	var a := 1.0 - k
	ci.draw_circle(lantern, 13.0 * Anim.flash(k * 1.6), Color(hi, 0.55 * a))
	ci.draw_arc(lantern, 6.0 + 22.0 * g, 0.0, TAU, 28, Color(hi, 0.85 * a), 1.0 + 3.0 * a, true)
	# Onde au sol, écrasée en ellipse sous le héros.
	var ring := Art.ellipse(p + Vector2(0, 10), 12.0 + 26.0 * g, (12.0 + 26.0 * g) * 0.42, 24)
	ring.append(ring[0])
	ci.draw_polyline(ring, Color(col, 0.5 * a), 2.0 * a + 0.5, true)
	var rays := _take(amount(int(feel("release_rays", 7))))
	for i in rays:
		var la := d.angle() + (i / float(maxi(rays - 1, 1)) - 0.5) * 1.3
		var u := Vector2.from_angle(la)
		var l0 := 10.0 + 26.0 * g
		var l1 := l0 + 14.0 * (1.0 - g) + 4.0
		ci.draw_line(lantern + u * l0, lantern + u * l1, Color(hi, a), 2.0, true)


## Compétence de nouveau prête : un anneau dans la couleur de l'élément se resserre sur le héros,
## puis la lanterne lance un éclat en étoile. Pas d'éclair d'écran : le héros seul s'allume.
static func _pret(ci: CanvasItem, e: Dictionary, k: float, on_ground: bool) -> void:
	var p: Vector2 = e["pos"]
	var col: Color = e.get("col", Art.ec("seve"))
	var hi := col.lerp(Color.WHITE, 0.5)
	var close := 0.45
	if on_ground:
		var c := Anim.ease_in(clampf(k / close, 0.0, 1.0))
		ci.draw_arc(p, lerpf(52.0, 18.0, c), 0.0, TAU, 40, Color(hi, 0.75 * (1.0 - c * 0.4)), 3.5, true)
		if k > close:
			var u := (k - close) / (1.0 - close)
			ci.draw_circle(p, 18.0 + 10.0 * Anim.ease_out(u), Color(col, 0.18 * (1.0 - u)))
		return
	if k < close:
		# Quatre lueurs aspirées vers le héros avec l'anneau.
		var c := Anim.ease_in(k / close)
		for i in amount(4):
			var la := i * TAU / 4.0 + 0.6 + c * 1.4
			ci.draw_circle(p + Vector2.from_angle(la) * lerpf(46.0, 16.0, c), 2.6, Color(hi, 0.9))
		return
	var u := (k - close) / (1.0 - close)
	var a := 1.0 - u
	var star := p + Vector2(0, -26.0)
	var s := 6.0 + 16.0 * Anim.ease_out(minf(u * 2.0, 1.0)) * a
	for i in 4:
		var la := i * PI / 2.0
		var dir := Vector2.from_angle(la)
		ci.draw_colored_polygon(PackedVector2Array([star + dir * s * 1.6, star + dir.orthogonal() * s * 0.28, star - dir * 0.0, star - dir.orthogonal() * s * 0.28]), Color(hi, a))
	ci.draw_circle(star, 2.5 * a + 1.0, Color(Color.WHITE, a))
	ci.draw_circle(p, 15.0, Color(hi, 0.3 * a))
	ci.draw_arc(p, 16.0 + 14.0 * u, 0.0, TAU, 32, Color(hi, 0.9 * a), 3.0 * a + 0.5, true)
