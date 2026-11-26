## Un monde qui réagit (jalon Éclat, tâche F) : l'herbe et les fleurs se couchent sous les pas, l'esquive
## et les coups ; le combat laisse des traces au sol qui s'effacent ; le héros au repos respire,
## regarde une fleur et plante une graine ; une montée de niveau, une greffe ramassée et un sanctuaire
## ravivé ont chacun leur élan de sève et de lumière.
##
## Tout est visuel : aucun chiffre de jeu ne bouge et le hasard du jeu n'est jamais tiré (tirages à part).
## Dosage dans res://data/feel.json › world. Options : « Réduire les effets » (Settings.reduce_effects)
## divise par trois les traces, les brins et les particules ; Settings.flash_strength() règle la
## colonne de lumière du sanctuaire (à 0, il n'en reste que le contour) ; rien ici ne ralentit le jeu
## ni ne bouge la caméra.
##
## Deux calques : celui-ci, au niveau du sol sous les personnages (traces, brins d'herbe, graine
## qui germe), et « over », au-dessus (spirale, couronne, greffe, colonne de lumière).
## Performance : un seul lot de triangles par calque (draw_batch.gd), des brins seulement autour du
## héros, un plafond de traces, et le calque ne se redessine que s'il y a quelque chose à animer.
extends Node2D

const Content = preload("res://scripts/content.gd")
const DrawBatch = preload("res://scripts/draw_batch.gd")
const Flora = preload("res://scripts/flora.gd")
const GraftPickup = preload("res://scripts/graft_pickup.gd")
const WorldLife = preload("res://scripts/world_life.gd")

var main
## Calque du dessus (créé par setup).
var over: Layer
## Monde vivant (refonte du monde, vague 1 V) : balancement du décor, petite vie, faune, réactions
## (world_life.gd). Son calque du sol est un enfant de ce nœud, celui du dessus un enfant de « over ».
var life

## Calque de dessin : appelle une fonction avec lui-même comme toile.
class Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


var clock := 0.0
var _rng := RandomNumberGenerator.new()
var _b := DrawBatch.new()
var _ob := DrawBatch.new()

# --- Herbe ---
var _bent: Dictionary = {}   # Vector2i -> Vector2 (couchage de la case)
var _g := {}
var _walk_clock := 0.0
var _last_draw_pos := Vector2(INF, INF)
var _since_draw := 1.0

# --- Traces ---
## Traces au sol : {kind, pos, a, size, t, dur, seed}.
var traces: Array = []
var _trace_clock := 0.0
var _trace_count := 0
var _tr := {}

# --- Repos ---
var rest_t := 0.0
## Respiration, courbette (graine plantée) et regard (0 à 1), lus par player.gd pour le dessin.
var breath := 0.0
var crouch := 0.0
var look_k := 0.0
var look_angle := 0.0
var _look_tried := false
var _has_look := false
var sprout: Dictionary = {}
var _last_seed := -100.0
var _rest := {}

# --- Moments ---
var level_ups: Array = []
var graft_flights: Array = []
var columns: Array = []
var _lv := {}
var _gf := {}
var _sc := {}


func setup(m) -> void:
	main = m
	_rng.seed = 90210
	_b.lean = true
	_ob.lean = true
	var w: Dictionary = Content.feel().get("world", {})
	_g = w.get("grass", {})
	_tr = w.get("traces", {})
	_rest = w.get("rest", {})
	_lv = w.get("level_up", {})
	_gf = w.get("graft", {})
	_sc = w.get("sanctuary", {})
	name = "WorldFx" # i18n: non
	over = Layer.new()
	over.fn = _draw_over
	over.name = "WorldFxOver" # i18n: non
	life = WorldLife.new()
	life.setup(m, self)
	add_child(life)
	over.add_child(life.air)


func _less() -> bool:
	return Settings.reduce_effects


## Quantité divisée par trois avec « Réduire les effets » (au moins 1).
func _qty(n: int) -> int:
	return maxi(1, int(round(n / 3.0))) if _less() else n


## Le monde réagit à « pos » (coup lourd, charge, mort, éclaboussure… voir world_life.gd › react).
func react(kind: String, pos: Vector2, force := 1.0) -> void:
	if life != null:
		life.react(kind, pos, force)


# ---------------------------------------------------------------- herbe et fleurs

## Couche l'herbe et les fleurs du disque (centre, rayon) à l'opposé du centre, et dans le sens « dir »
## à demi ; « force » : 1 = couchées franchement. Elles se relèvent d'elles-mêmes.
func disturb(center: Vector2, radius: float, dir := Vector2.ZERO, force := 1.0) -> void:
	var cell := float(_g.get("cell", 32.0))
	var a := Vector2i(floori((center.x - radius) / cell), floori((center.y - radius) / cell))
	var b := Vector2i(floori((center.x + radius) / cell), floori((center.y + radius) / cell))
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			var cc := (Vector2(cx, cy) + Vector2(0.5, 0.5)) * cell
			var d := cc.distance_to(center)
			if d > radius:
				continue
			var away := (cc - center).normalized() if d > 0.01 else Vector2.RIGHT
			var tgt := (away + dir * 0.6).normalized() * minf(1.4, force * (1.0 - d / radius) * 1.5)
			var key := Vector2i(cx, cy)
			var cur: Vector2 = _bent.get(key, Vector2.ZERO)
			if tgt.length_squared() > cur.length_squared():
				_bent[key] = tgt
	if main != null and main.flora != null:
		main.flora.disturb(center, radius, dir, force)


func _decay_bends(delta: float) -> void:
	if _bent.is_empty():
		return
	var k := 1.0 - exp(-delta / maxf(float(_g.get("relax", 2.2)), 0.1))
	for key in _bent.keys():
		var v: Vector2 = _bent[key] * (1.0 - k)
		if v.length_squared() < 0.0009:
			_bent.erase(key)
		else:
			_bent[key] = v


## Le héros marche, esquive : l'herbe sous ses pieds se couche.
func _walk_steps(p, delta: float) -> void:
	_walk_clock -= delta
	if _walk_clock > 0.0:
		return
	_walk_clock = 0.05
	var feet: Vector2 = p.position + Vector2(0.0, p.radius * 0.8)
	if p.dash_time > 0.0:
		disturb(feet, float(_g.get("dash_radius", 46.0)), p.dash_dir, float(_g.get("dash_force", 1.6)))
	elif p.walk > 0.12:
		disturb(feet, float(_g.get("walk_radius", 26.0)), p.move_dir, float(_g.get("walk_force", 0.9)) * p.walk)


# ---------------------------------------------------------------- traces de combat

## Un coup du joueur a touché « pos » : l'herbe se couche autour, et selon la branche ou l'élément
## le sol garde une trace (sillon, fissure, brûlure, flaque, tache). Appelé par main.player_hit_enemy.
func on_hit(pos: Vector2, branch: String, element: String, crit: bool, poison := false, bleed := false) -> void:
	if main == null or main.player == null:
		return
	var from: Vector2 = main.player.position
	var dir := (pos - from).normalized() if pos.distance_squared_to(from) > 1.0 else Vector2.RIGHT
	disturb(pos, float(_g.get("hit_radius", 70.0)), dir, float(_g.get("hit_force", 1.3)) * (1.25 if crit else 1.0))
	var kind := ""
	if element == "racine" or branch == "racine":
		kind = "crack"
	elif element == "lumiere" or branch == "aube":
		kind = "scorch"
	elif element == "epine" or branch == "ronce":
		kind = "furrow"
	elif branch == "spore" or poison:
		kind = "puddle"
	elif bleed or branch == "seve":
		kind = "splat"
	if kind != "":
		add_trace(kind, pos, dir.angle(), 1.25 if crit else 1.0)


## Pose une trace (si le plafond, le délai et la place le permettent). Renvoie vrai si elle est posée.
func add_trace(kind: String, pos: Vector2, angle: float, size := 1.0) -> bool:
	if _trace_clock > 0.0:
		return false
	if _less():
		# Un tiers des traces : une sur trois seulement.
		_trace_count += 1
		if _trace_count % 3 != 0:
			return false
	var cap := _qty(int(_tr.get("max", 28)))
	for t in traces:
		if t["pos"].distance_squared_to(pos) < 14.0 * 14.0:
			return false
	if traces.size() >= cap:
		traces.pop_front()
	_trace_clock = float(_tr.get("every", 0.1))
	traces.append({"kind": kind, "pos": pos, "a": angle, "size": size, "t": 0.0,
		"dur": float(_tr.get(kind, 4.0)), "seed": _rng.randi()})
	# Le décor proche de la trace frémit et y lâche quelques débris (world_life.gd).
	react("trace", pos, size)
	return true


# ---------------------------------------------------------------- moments

## Montée de niveau : spirale de sève et couronne de feuilles autour du héros.
func level_up() -> void:
	if level_ups.size() >= 2:
		level_ups.pop_front()
	level_ups.append({"t": 0.0, "dur": float(_lv.get("dur", 1.5))})
	# Souffle sur le décor autour du héros (world_life.gd › event).
	if life != null and main != null and main.player != null:
		life.event("level", main.player.position)


## Greffe ramassée à « pos » : elle jaillit, tourne autour du héros et le rejoint.
func graft_pickup(pos: Vector2, graft_id: String) -> void:
	if graft_flights.size() >= 4:
		graft_flights.pop_front()
	var from: Vector2 = main.player.position if main != null and main.player != null else pos
	graft_flights.append({"id": graft_id, "pos": pos, "a0": (pos - from).angle() if pos.distance_squared_to(from) > 1.0 else 0.0,
		"r0": clampf(pos.distance_to(from), 18.0, 40.0), "t": 0.0})
	if life != null:
		life.event("graft", from)


## Sanctuaire ravivé à « pos » : colonne de lumière qui s'élève, puis pluie de lueurs.
func sanctuary_lit(pos: Vector2) -> void:
	if columns.size() >= 3:
		columns.pop_front()
	columns.append({"pos": pos, "t": 0.0, "dur": float(_sc.get("dur", 3.0))})


# ---------------------------------------------------------------- boucle

func _process(delta: float) -> void:
	clock += delta
	_trace_clock -= delta
	_since_draw += delta
	var p = main.player if main != null else null
	var busy := false
	if p != null:
		_walk_steps(p, delta)
		_update_rest(p, delta)
	_decay_bends(delta)
	for list in [traces, level_ups, graft_flights, columns]:
		for e in list:
			e["t"] += delta
	traces = traces.filter(func(e): return e["t"] < e["dur"])
	level_ups = level_ups.filter(func(e): return e["t"] < e["dur"])
	columns = columns.filter(func(e): return e["t"] < e["dur"])
	var join_total := float(_gf.get("rise", 0.35)) + float(_gf.get("orbit", 0.6)) + float(_gf.get("join", 0.3)) + float(_gf.get("land", 0.35))
	graft_flights = graft_flights.filter(func(e): return e["t"] < join_total)
	if not sprout.is_empty():
		sprout["t"] += delta
		if sprout["t"] >= sprout["dur"]:
			_finish_sprout()
	# Calque du sol : redessiné quand le héros a avancé de quelques pixels, qu'il y a de quoi animer
	# (couchage, traces, graine) ou, au repos, douze fois par seconde (le balancement des brins).
	var moved: bool = p != null and p.position.distance_squared_to(_last_draw_pos) > 25.0
	busy = moved or not _bent.is_empty() or not traces.is_empty() or not sprout.is_empty() \
		or (life != null and life.gust["force"] > 0.0)
	if busy or _since_draw > 1.0 / 12.0:
		_since_draw = 0.0
		if p != null:
			_last_draw_pos = p.position
		queue_redraw()
	if not (level_ups.is_empty() and graft_flights.is_empty() and columns.is_empty()) or over_drawn:
		over.queue_redraw()
	over_drawn = not (level_ups.is_empty() and graft_flights.is_empty() and columns.is_empty())


var over_drawn := false


# ---------------------------------------------------------------- repos

func _update_rest(p, delta: float) -> void:
	var busy: bool = p.walk > 0.08 or p.dash_time > 0.0 or p.since_shot < 2.5 or p.cast_anim > 0.0 \
		or p.hurt_anim > 0.0 or p.has_dest or p.reborn < 1.0
	if busy:
		rest_t = 0.0
		_look_tried = false
		_has_look = false
	else:
		rest_t += delta
	var breathing := rest_t > float(_rest.get("breathe_after", 1.8))
	breath = move_toward(breath, 1.0 if breathing else 0.0, delta * 1.5)
	# Regard : une fleur proche, cherchée une fois par repos.
	var looking := rest_t > float(_rest.get("look_after", 4.5))
	if looking and not _look_tried:
		_look_tried = true
		_has_look = _find_flower(p)
	look_k = move_toward(look_k, 1.0 if (looking and _has_look) else 0.0, delta * (2.0 if (looking and _has_look) else 4.0))
	# Graine : après un long repos, sur la terre vivante, à bonne distance de la précédente.
	if sprout.is_empty() and rest_t > float(_rest.get("seed_after", 10.0)) \
			and clock - _last_seed > float(_rest.get("seed_every", 16.0)) and main.ground.life_at(p.position) > 0.45:
		_start_sprout(p)
	crouch = 0.0
	if not sprout.is_empty():
		crouch = sin(clampf(sprout["t"] / 0.9, 0.0, 1.0) * PI)


## Cherche la fleur la plus proche (dans look_range) et retient l'angle pour la regarder.
func _find_flower(p) -> bool:
	var rng := float(_rest.get("look_range", 170.0))
	var best := rng * rng
	var found := false
	for f in main.flora.flowers:
		var d2: float = f["pos"].distance_squared_to(p.position)
		if d2 < best and d2 > 22.0 * 22.0:
			best = d2
			look_angle = (f["pos"] - p.position).angle()
			found = true
	return found


func _start_sprout(p) -> void:
	_last_seed = clock
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var palette := [Art.c("interactif").lightened(0.3), Art.c("or"), Art.ec("seve", "clair"), Art.ec("poison", "clair")]
	sprout = {"pos": p.position + Vector2(side * 16.0, p.radius * 0.9), "t": 0.0, "dur": float(_rest.get("sprout_time", 3.0)),
		"color": palette[_rng.randi() % palette.size()], "size": _rng.randf_range(2.8, 4.2), "petals": _rng.randi_range(4, 6)}


## La graine a poussé : c'est maintenant une vraie fleur du monde (purement décorative).
func _finish_sprout() -> void:
	if main.flora != null:
		main.flora.plant(sprout["pos"], sprout["color"], sprout["size"], sprout["petals"])
	sprout = {}


## Angle de regard du héros (dessin seulement) : le sien, tourné vers la fleur regardée au repos.
func facing_angle(base: float) -> float:
	return lerp_angle(base, look_angle, Anim.ease_in_out(look_k)) if look_k > 0.0 else base


# ---------------------------------------------------------------- dessin du sol

func _tri(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	var base := _b.points.size()
	_b.points.append(a)
	_b.points.append(b)
	_b.points.append(c)
	_b.colors.append(ca)
	_b.colors.append(cb)
	_b.colors.append(cc)
	_b.indices.append(base)
	_b.indices.append(base + 1)
	_b.indices.append(base + 2)


func _draw() -> void:
	if main == null:
		return
	_draw_traces()
	_draw_blades()
	_draw_sprout()
	_b.flush(self)


## Touffes d'herbe : sur la terre vivante, dans un disque autour du héros, à des places fixes (une
## empreinte de la case). Chaque touffe a trois brins qui ondulent un peu et se couchent là où l'on
## est passé, dans le sens du passage ; ils se relèvent ensuite.
func _draw_blades() -> void:
	var p = main.player
	if p == null:
		return
	var cell := float(_g.get("cell", 36.0))
	var radius := float(_g.get("radius", 140.0))
	var fade_from := float(_g.get("fade_from", 80.0))
	var density := float(_g.get("density", 0.6)) * (0.34 if _less() else 1.0)
	var c0 := Vector2i(floori((p.position.x - radius) / cell), floori((p.position.y - radius) / cell))
	var c1 := Vector2i(floori((p.position.x + radius) / cell), floori((p.position.y + radius) / cell))
	var base_col := Art.c("decor_vivant")
	var ground = main.ground
	# Rafale du monde vivant (world_life.gd) : l'herbe se couche à son passage.
	var gusty: bool = life != null and not WorldLife.still and life.gust["force"] > 0.0
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var h := (cx * 73856093) ^ (cy * 19349663)
			h = (h ^ (h >> 13)) * 1274126177
			if float(h & 255) / 255.0 > density:
				continue
			var at := Vector2((cx + float((h >> 8) & 255) / 255.0) * cell, (cy + float((h >> 16) & 255) / 255.0) * cell)
			var d := at.distance_to(p.position)
			if d >= radius:
				continue
			var a := 1.0 - smoothstep(fade_from, radius, d)
			if ground.life_at(at) < 0.5:
				continue
			var hgt := 9.0 + float((h >> 24) & 15) * 0.6
			var lean: Vector2 = _bent.get(Vector2i(cx, cy), Vector2.ZERO)
			lean.x += sin(clock * 1.4 + float(h & 1023) * 0.01) * 0.1
			if gusty:
				lean += life.gust_at(at) * 0.9
			var m := minf(lean.length(), 1.2)
			var up := hgt * (1.0 - 0.6 * minf(m, 1.0))
			var tint := float((h >> 4) & 7) / 7.0
			var low := base_col.lightened(0.18 + 0.12 * tint)
			var high := base_col.lightened(0.42 + 0.2 * tint)
			low.a = 0.9 * a
			high.a = 0.95 * a
			for j in 3:
				var spread := (j - 1) * 0.5 * (1.0 - 0.6 * minf(m, 1.0))
				var root := at + Vector2((j - 1) * 2.2, 0.0)
				var tip := root + Vector2((lean.x * 0.95 + spread) * hgt, -up * (1.0 - 0.18 * absf(j - 1)) + lean.y * hgt * 0.3)
				var mid := root + Vector2((lean.x * 0.4 + spread * 0.5) * hgt, -up * 0.55)
				var w := 1.5
				_tri(root + Vector2(-w, 0.0), root + Vector2(w, 0.0), mid + Vector2(w * 0.6, 0.0), low, low, low.lerp(high, 0.5))
				_tri(root + Vector2(-w, 0.0), mid + Vector2(w * 0.6, 0.0), mid + Vector2(-w * 0.6, 0.0), low, low.lerp(high, 0.5), low.lerp(high, 0.5))
				_tri(mid + Vector2(-w * 0.6, 0.0), mid + Vector2(w * 0.6, 0.0), tip, low.lerp(high, 0.5), low.lerp(high, 0.5), high)


func _draw_traces() -> void:
	var dark := Art.c("decor").darkened(0.5)
	for tr in traces:
		var u: float = tr["t"] / tr["dur"]
		var fade := smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.5, 1.0, u))
		if fade <= 0.01:
			continue
		var pos: Vector2 = tr["pos"]
		var ang: float = tr["a"]
		var sz: float = tr["size"]
		var d := Vector2.from_angle(ang)
		var n := d.orthogonal()
		match tr["kind"]:
			"furrow":
				# Trois sillons courbes dans le sens du coup, avec un bourrelet de terre clair.
				for i in 3:
					var off := (i - 1) * 5.5 * sz
					var len := (30.0 + 8.0 * i) * sz
					var pts := PackedVector2Array()
					for k in 7:
						var s := k / 6.0 - 0.5
						pts.append(pos + d * s * len + n * (off + 5.0 * (1.0 - 4.0 * s * s)))
					_b.draw_polyline(pts, Color(dark, 0.7 * fade), 3.0 * sz)
					for k in pts.size():
						pts[k] += Vector2(0.0, -1.3)
					_b.draw_polyline(pts, Color(Art.c("sol_mort").lightened(0.25), 0.28 * fade), 1.1)
			"crack":
				var r := RandomNumberGenerator.new()
				r.seed = tr["seed"]
				var col := Color(Art.ec("racine", "sombre").darkened(0.3), 0.7 * fade)
				var p0 := pos - d * 22.0 * sz
				var pts := PackedVector2Array([p0])
				for k in 6:
					p0 += d * 7.5 * sz + n * r.randf_range(-5.0, 5.0)
					pts.append(p0)
					if k == 2 or k == 4:
						var br := PackedVector2Array([p0, p0 + (d + n * (1.0 if k == 2 else -1.0)).normalized() * 11.0 * sz])
						_b.draw_polyline(br, col, 1.4)
				_b.draw_polyline(pts, col, 2.0 * sz)
			"scorch":
				var warm := 1.0 - smoothstep(0.0, 0.12, u)
				_b.draw_colored_polygon(Art.ellipse(pos, 19.0 * sz, 19.0 * sz * 0.55, 14), Color(0.1, 0.07, 0.07, 0.45 * fade))
				_b.draw_colored_polygon(Art.ellipse(pos, 11.0 * sz, 11.0 * sz * 0.55, 12), Color(0.05, 0.03, 0.04, 0.3 * fade))
				if warm > 0.0:
					_b.draw_colored_polygon(Art.ellipse(pos, 14.0 * sz, 14.0 * sz * 0.55, 12), Color(Art.ec("lumiere", "clair"), 0.45 * warm))
			"puddle":
				_b.draw_colored_polygon(Art.ellipse(pos, 18.0 * sz, 18.0 * sz * 0.5, 14), Color(Art.ec("poison"), 0.5 * fade))
				_b.draw_colored_polygon(Art.ellipse(pos + Vector2(2, 0), 11.0 * sz, 11.0 * sz * 0.5, 12), Color(Art.ec("poison", "clair"), 0.22 * fade))
				var bub := 1.0 + 0.3 * sin(clock * 4.0 + float(tr["seed"] & 255))
				_b.draw_circle(pos + Vector2(-6, -1), 1.8 * bub, Color(Art.ec("poison", "clair"), 0.6 * fade))
				_b.draw_circle(pos + Vector2(7, 1), 1.3 * bub, Color(Art.ec("poison", "clair"), 0.5 * fade))
			"splat":
				var col := Color(Art.ec("saignement").darkened(0.15), 0.65 * fade)
				var r2 := RandomNumberGenerator.new()
				r2.seed = tr["seed"]
				for k in 4:
					var q := pos + d * r2.randf_range(-12.0, 14.0) * sz + n * r2.randf_range(-8.0, 8.0) * sz
					_b.draw_colored_polygon(Art.ellipse(q, r2.randf_range(3.0, 6.5) * sz, r2.randf_range(2.0, 3.6) * sz, 9), col)


## Graine semée au repos : elle tombe, s'enfonce, puis une tige monte et le bouton s'ouvre.
func _draw_sprout() -> void:
	if sprout.is_empty():
		return
	var pos: Vector2 = sprout["pos"]
	var u: float = sprout["t"] / sprout["dur"]
	var green := Art.c("decor_vivant").lightened(0.15)
	if u < 0.18:
		# La graine tombe de la main du héros.
		var k := u / 0.18
		_b.draw_circle(pos + Vector2(0.0, -14.0 * (1.0 - k * k)), 1.8, Art.c("butin"))
		return
	var g := Anim.ease_out(clampf((u - 0.18) / 0.82, 0.0, 1.0))
	var h := 12.0 * g
	var top := pos + Vector2(sin(clock * 1.6) * 0.8, -h)
	_b.draw_colored_polygon(Art.ellipse(pos + Vector2(0, 1), 4.5, 2.0, 8), Color(Art.c("sol_mort").darkened(0.25), 0.7))
	_b.draw_line(pos, top, green, 1.6)
	var lf := clampf((g - 0.3) / 0.5, 0.0, 1.0)
	if lf > 0.0:
		for s in [-1.0, 1.0]:
			var base := pos.lerp(top, 0.55)
			_b.draw_colored_polygon(Flora.DecorTree.leaf_shape(base, 7.0 * lf, -PI / 2.0 + s * 0.9), green.lightened(0.1))
	var bud := clampf((g - 0.75) / 0.25, 0.0, 1.0)
	if bud > 0.0:
		_b.draw_circle(top, 2.4 * Anim.pop(bud), sprout["color"])


# ---------------------------------------------------------------- dessin du dessus

func _draw_over(ci: CanvasItem) -> void:
	if main == null or main.player == null:
		return
	_ob.clear()
	for e in columns:
		_draw_column(e)
	for e in level_ups:
		_draw_level_up(e)
	_ob.flush(ci)
	for e in graft_flights:
		_draw_graft(ci, e)


func _otri(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	var base := _ob.points.size()
	_ob.points.append(a)
	_ob.points.append(b)
	_ob.points.append(c)
	_ob.colors.append(ca)
	_ob.colors.append(cb)
	_ob.colors.append(cc)
	_ob.indices.append(base)
	_ob.indices.append(base + 1)
	_ob.indices.append(base + 2)


## Spirale de sève qui monte autour du héros, puis couronne de feuilles qui s'ouvre au-dessus de sa tête.
## Chaque brin est un ruban (trait épais sur un contour sombre, pour se lire sur l'herbe claire) dont la
## tête brille, avec une petite feuille de loin en loin.
func _draw_level_up(e: Dictionary) -> void:
	var p = main.player
	var r: float = p.radius
	var feet: Vector2 = p.position + Vector2(0.0, r * 0.9)
	var T: float = e["t"] / e["dur"]
	var strands := int(_lv.get("strands", 3))
	var dots := _qty(int(_lv.get("dots", 14)))
	var height := r * 5.6
	var head := clampf(T / 0.7, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.78, 1.0, T)
	var sap := Art.ec("seve", "clair")
	var ink := Art.c("contour")
	var green := Art.c("decor_vivant").lightened(0.3)
	# Départ : une onde de sève au sol et des feuilles qui jaillissent en cercle.
	if T < 0.4:
		var u := T / 0.4
		var f := 1.0 - u
		var ring := Art.ellipse(feet, r * (1.2 + 3.6 * Anim.ease_out(u)), r * (1.2 + 3.6 * Anim.ease_out(u)) * 0.4, 28)
		ring.append(ring[0])
		_ob.draw_polyline(ring, Color(sap, 0.85 * f), 1.5 + 3.0 * f)
		for i in _qty(8):
			var a := TAU * i / 8.0 + 0.4
			var q := feet + Vector2(cos(a), sin(a) * 0.4) * r * (1.0 + 3.0 * Anim.ease_out(u)) + Vector2(0.0, -16.0 * sin(u * PI))
			_ob.draw_colored_polygon(Flora.DecorTree.leaf_shape(q, 9.0 * f + 3.0, a + PI / 2.0), Color(green, f))
	for s in strands:
		var prev := Vector2.INF
		for i in dots:
			var u := float(i + 1) / dots
			var uu := head - (1.0 - u) * 0.42
			if uu < 0.0:
				continue
			var ang: float = TAU * 1.7 * uu + s * TAU / strands + e["t"] * 2.2
			var rad := (r * 2.4) * (1.0 - 0.3 * uu)
			var q: Vector2 = feet + Vector2(cos(ang) * rad, sin(ang) * rad * 0.4 - uu * height)
			var col := sap.lerp(Art.c("butin"), 0.25 * u)
			col.a = minf(1.0, u * 1.4) * fade
			if prev != Vector2.INF:
				_ob.draw_line(prev, q, Color(ink, 0.4 * col.a), 2.5 + 4.6 * u + 2.0)
				_ob.draw_line(prev, q, col, 2.5 + 4.6 * u)
			if i % 5 == 3 and u > 0.3:
				var la := ang + PI / 2.0
				_ob.draw_colored_polygon(Flora.DecorTree.leaf_shape(q, 8.0, la), Color(green, fade * 0.95))
			prev = q
		if prev != Vector2.INF and head < 1.0:
			_ob.draw_circle(prev, 5.5, Color(sap, 0.35 * fade))
			_ob.draw_circle(prev, 3.2, Color(1.0, 1.0, 0.9, fade))
	# Couronne : des feuilles qui s'ouvrent l'une après l'autre, puis s'élèvent en s'effaçant.
	if T > 0.5:
		var n := int(_lv.get("leaves", 8))
		var crown: Vector2 = p.position + Vector2(0.0, -r * 1.9 - 4.0 - maxf(0.0, T - 0.8) * 70.0)
		for i in n:
			var start := 0.5 + 0.2 * i / maxf(1.0, n - 1.0)
			var k := Anim.pop(clampf((T - start) / 0.16, 0.0, 1.0))
			if k <= 0.01:
				continue
			var a: float = TAU * i / n + e["t"] * 0.9
			var q: Vector2 = crown + Vector2(cos(a) * r * 1.5, sin(a) * r * 0.55)
			var col := green.lerp(Art.c("butin"), 0.35 if i % 4 == 0 else 0.0)
			_ob.draw_colored_polygon(Flora.DecorTree.leaf_shape(q, 13.0 * k, a + PI / 2.0), Color(ink, 0.5 * fade))
			_ob.draw_colored_polygon(Flora.DecorTree.leaf_shape(q, 10.5 * k, a + PI / 2.0), Color(col, fade))


func _graft_pos(e: Dictionary, t: float) -> Vector2:
	var p = main.player
	var rise := float(_gf.get("rise", 0.35))
	var orbit := float(_gf.get("orbit", 0.6))
	var join := float(_gf.get("join", 0.3))
	var chest: Vector2 = p.position + Vector2(0.0, -p.radius * 0.5)
	var start: Vector2 = e["pos"]
	if t < rise:
		return start.lerp(chest + Vector2.from_angle(e["a0"]) * e["r0"], 0.35 * Anim.ease_out(t / rise)) + Vector2(0.0, -48.0 * Anim.ease_out(t / rise))
	var orb: Vector2
	var u := clampf((t - rise) / orbit, 0.0, 1.0)
	var ang: float = e["a0"] + TAU * 1.5 * Anim.ease_in_out(u)
	var rad := lerpf(e["r0"], 30.0, u)
	var base := start.lerp(chest + Vector2.from_angle(e["a0"]) * e["r0"], 0.35)
	var center := base.lerp(chest, u)
	orb = center + Vector2(cos(ang) * rad, sin(ang) * rad * 0.45 - 48.0 * (1.0 - u) - 10.0 * sin(u * PI))
	if t < rise + orbit:
		return orb
	var j := Anim.ease_in(clampf((t - rise - orbit) / join, 0.0, 1.0))
	return orb.lerp(chest, j)


## Greffe qui vole. Éclosion : un anneau d'or et des rayons là où elle était. Vol : une comète (queue
## effilée aux couleurs de la greffe, halo, étoile qui tourne) portant son médaillon. Arrivée : un anneau
## et des étincelles sur le héros, qui s'illumine un instant.
func _draw_graft(ci: CanvasItem, e: Dictionary) -> void:
	var g: Dictionary = Content.grafts().get(e["id"], {})
	var col := Color(str(g.get("color", "#f2d06b")))
	var bright := col.lerp(Color.WHITE, 0.5)
	var gold := Art.c("butin")
	var rise := float(_gf.get("rise", 0.35))
	var join := float(_gf.get("join", 0.3))
	var flight := rise + float(_gf.get("orbit", 0.6)) + join
	var land := float(_gf.get("land", 0.35))
	var t: float = e["t"]
	var p = main.player
	var chest: Vector2 = p.position + Vector2(0.0, -p.radius * 0.5)
	var start: Vector2 = e["pos"]
	# Éclosion.
	if t < rise + 0.15:
		var u := t / (rise + 0.15)
		var f := 1.0 - u
		ci.draw_arc(start, 8.0 + 38.0 * Anim.ease_out(u), 0.0, TAU, 32, Color(gold, 0.85 * f), 1.0 + 3.0 * f, true)
		for i in _qty(8):
			var d := Vector2.from_angle(TAU * i / 8.0 + 0.3)
			ci.draw_line(start + d * (10.0 + 12.0 * u), start + d * (16.0 + 30.0 * Anim.ease_out(u)), Color(bright, 0.9 * f), 2.0, true)
	if t < flight:
		var shrink := 1.0 - 0.65 * Anim.ease_in(clampf((t - (flight - join)) / join, 0.0, 1.0))
		# Queue de comète : segments de plus en plus fins et pâles.
		var n := _qty(16)
		var prev: Vector2 = _graft_pos(e, t)
		for i in n:
			var tt := t - (i + 1) * 0.022
			if tt < 0.0:
				break
			var q: Vector2 = _graft_pos(e, tt)
			var f := 1.0 - float(i + 1) / (n + 1)
			var c := bright.lerp(gold, 1.0 - f)
			ci.draw_line(prev, q, Color(Art.c("contour"), 0.25 * f), 9.0 * f * shrink + 2.0, true)
			ci.draw_line(prev, q, Color(c, 0.9 * f), 7.0 * f * shrink + 1.0, true)
			prev = q
		var pos: Vector2 = _graft_pos(e, t)
		var sc := 1.9 * shrink
		var pulse := 0.5 + 0.5 * sin(t * 18.0)
		ci.draw_circle(pos, 19.0 * sc * 0.6, Color(bright, 0.16 + 0.1 * pulse))
		ci.draw_circle(pos, 13.0 * sc * 0.6, Color(gold, 0.3))
		ci.draw_circle(pos, 10.5 * sc * 0.6, Color(0.14, 0.09, 0.05, 0.95))
		ci.draw_arc(pos, 10.5 * sc * 0.6, 0.0, TAU, 24, gold, 1.8, true)
		GraftPickup.draw_shape(ci, str(g.get("shape", "feuille")), pos, 9.0 * sc * 0.6, col)
		# Étoile à quatre branches qui tourne.
		for i in 4:
			var d := Vector2.from_angle(t * 5.0 + TAU * i / 4.0)
			var len := (17.0 if i % 2 == 0 else 11.0) * sc * 0.6 * (0.8 + 0.4 * pulse)
			ci.draw_line(pos + d * 6.0 * sc * 0.6, pos + d * len, Color(1.0, 1.0, 0.9, 0.85), 1.6, true)
	# Arrivée : anneau, étincelles et lueur sur le héros.
	var lt := t - (flight - 0.05)
	if lt > 0.0 and lt < land + 0.05:
		var u := lt / (land + 0.05)
		var f := 1.0 - u
		ci.draw_circle(chest, 24.0 * f, Color(bright, 0.3 * f))
		ci.draw_arc(chest, 8.0 + 34.0 * Anim.ease_out(u), 0.0, TAU, 32, Color(gold, 0.9 * f), 1.0 + 3.5 * f, true)
		for i in _qty(8):
			var d := Vector2.from_angle(TAU * i / 8.0 + 0.5)
			ci.draw_circle(chest + d * (10.0 + 30.0 * Anim.ease_out(u)), 2.6 * f + 0.6, Color(bright if i % 2 == 0 else gold, f))


## Colonne de lumière du sanctuaire ravivé : elle s'élève, tient un instant, puis retombe en pluie de lueurs.
func _draw_column(e: Dictionary) -> void:
	var pos: Vector2 = e["pos"]
	var t: float = e["t"]
	var H := float(_sc.get("height", 280.0))
	var rise := float(_sc.get("rise", 0.9))
	var hold := rise + 0.5
	var top := H * Anim.ease_out(clampf(t / rise, 0.0, 1.0))
	var fall := clampf((t - hold) / 0.9, 0.0, 1.0)
	top *= 1.0 - Anim.ease_in(fall)
	var sap := Art.ec("seve", "clair")
	var strength := clampf(Settings.flash_strength(), 0.0, 1.0)
	if top > 2.0:
		var w := 28.0 * (1.0 - 0.4 * fall) * (1.0 + 0.06 * sin(t * 9.0))
		var bot := pos
		var up := pos + Vector2(0.0, -top)
		var w_top := w * 0.55
		var a_bot := 0.62 * strength
		var a_top := 0.04 * strength
		_otri(bot + Vector2(-w, 0), bot + Vector2(w, 0), up + Vector2(w_top, 0), Color(sap, a_bot), Color(sap, a_bot), Color(sap, a_top))
		_otri(bot + Vector2(-w, 0), up + Vector2(w_top, 0), up + Vector2(-w_top, 0), Color(sap, a_bot), Color(sap, a_top), Color(sap, a_top))
		var core := w * 0.35
		var ca := 0.45 * strength
		_otri(bot + Vector2(-core, 0), bot + Vector2(core, 0), up, Color(1, 1, 0.9, ca), Color(1, 1, 0.9, ca), Color(1, 1, 0.9, 0.0))
		# Onde au pied de la colonne.
		var ru := fposmod(t * 0.9, 1.0)
		var rg := Art.ellipse(bot, 20.0 + 70.0 * ru, (20.0 + 70.0 * ru) * 0.4, 24)
		rg.append(rg[0])
		_ob.draw_polyline(rg, Color(sap, 0.6 * (1.0 - ru) * (1.0 - fall)), 2.0)
		# Contour toujours là, même sans éclat (Settings.flash_strength() à 0) : deux fils de lumière.
		var edge := Color(sap, 0.55)
		_ob.draw_line(bot + Vector2(-w, 0), up + Vector2(-w_top, 0), edge, 1.2)
		_ob.draw_line(bot + Vector2(w, 0), up + Vector2(w_top, 0), edge, 1.2)
	# Pluie de lueurs : elles se détachent de la colonne et retombent doucement.
	var n := _qty(int(_sc.get("glints", 26)))
	var gold := Art.c("butin")
	for i in n:
		var rnd := fposmod(sin(i * 78.233 + 1.7) * 43758.5453, 1.0)
		var rnd2 := fposmod(sin(i * 12.9898 + 4.1) * 43758.5453, 1.0)
		var rnd3 := fposmod(sin(i * 39.346 + 9.2) * 43758.5453, 1.0)
		var start := hold * 0.7 + rnd * 1.1
		var life_t := 1.0 + rnd2 * 0.6
		var u := (t - start) / life_t
		if u <= 0.0 or u >= 1.0:
			continue
		var x := (rnd2 - 0.5) * 56.0 + sin(u * 5.0 + i) * 4.0
		var y0 := -H * (0.2 + 0.7 * rnd3)
		var y := y0 * (1.0 - 0.55 * Anim.ease_in(u))
		var q := pos + Vector2(x, y)
		var c := sap if i % 3 != 0 else gold
		_ob.draw_circle(q, 1.4 + 1.4 * rnd, Color(c, sin(u * PI) * 0.9))
