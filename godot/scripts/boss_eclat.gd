## Moments signatures des boss (jalon Éclat, tâche C) : l'arrivée, les changements de phase et la
## mort propres à chaque boss. Purement visuel : rien ne change dans le combat (durée de l'entrée en
## scène, dégâts, vie, attaques). Dosage : data/feel.json › boss.
##
##   - Arrivée (boss_arena._start_fight) : le mur de l'arène se referme en poussant dans la matière de
##     la région (ronces, champignons, pierres levées, tiges de sève, éclats de verre, pierre, racines),
##     le sol se fend sous le boss et il émerge pendant son entrée en scène (BossBase.intro, inchangée :
##     il ne frappe pas avant). Le joueur garde la main.
##   - Changement de phase (BossBase, à côté de fx.boss_phase et du ralenti de moments.gd) : une onde
##     de sa matière court jusqu'au mur et transforme une partie de l'arène (fissures épineuses, spores
##     au sol, plumes, sève qui monte, éclats de verre, dalles de pierre, veines de lumière).
##   - Mort (BossBase._die, avec l'impact frame « region » et le ralenti existants) : la Mère-Ronce se
##     dénoue en lianes qui rentrent dans le sol, l'Amanite s'effondre en nuage de spores, le Harfang
##     se disperse en plumes, le Saule se vide en sève qui reverdit, la Phalène se brise en verre,
##     l'Ancien s'effrite en pierres, la Flétrissure se déchire en lumière. Puis tout s'efface sous la
##     reverdie de l'arène (draw_victory, region_fanfare.gd), sans la toucher.
##
## Un nœud par arène, créé au premier combat : au sol (enfant de l'arène, sous les personnages) pour le
## mur, les fissures, les décors de phase, les lianes et ce qui est retombé ; « over » (au-dessus des
## personnages) pour ce qui vole. Aucun nœud par particule, plafond global (« max_particles », divisé
## par trois avec « Réduire les effets »). Il ne tourne que pendant un combat et le temps que ses traces
## s'effacent. Un boss figé (tests visuels) ne déclenche rien.
extends Node2D

const Content = preload("res://scripts/content.gd")

## Couche au-dessus des personnages (débris, plumes, éclats, lueurs).
class Over extends Node2D:
	var src

	func _draw() -> void:
		src.draw_over(self)


var main
var arena
## Matière de la région (feel.json › boss › materials) : ronce, spore, vent, seve, aube, racine, finale.
var mat := "ronce"
var boss
var over: Node2D
## Vrai tant qu'il reste quelque chose à animer ou à dessiner.
var active := false
## Arrivée : temps écoulé depuis le début (-1 : aucune), durée de l'entrée en scène du boss, côté de
## la brèche (le mur s'y referme d'abord) et étapes des jaillissements de débris déjà jouées.
var arrive_t := -1.0
var intro_len := 1.4
var gap_dir := Vector2.DOWN
var _bursts := 0
## Le boss est en train d'émerger (échelle et teinte posées ici, rendues à la fin).
var _emerging := false
## Fissures sous le boss : {"pts": PackedVector2Array (relatifs au centre, longueur 1)}.
var cracks: Array = []
## Décors posés par les phases : {"pos", "kind", "size", "rot", "born", "seed"}.
var decor: Array = []
## Ondes des changements de phase : {"t", "dur", "r0", "r1"}.
var waves: Array = []
## Particules : {"k", "p", "z", "v", "vz", "g", "t", "life", "s", "c", "rot", "spin", "rest"}.
var parts: Array = []
## Lianes de la Mère-Ronce mourante : {"a", "len", "seed"}.
var vines: Array = []
## Déchirures de lumière de la Flétrissure mourante : {"a", "len", "w"}.
var rays: Array = []
## Mort : temps écoulé depuis la mort du boss (-1 : vivant), centre et rayon.
var death_t := -1.0
var death_at := Vector2.ZERO
var death_r := 70.0
## Horloge du nœud (temps de jeu : suit le ralenti).
var clock := 0.0
var rng := RandomNumberGenerator.new()
## Particules lancées depuis la création (lu par les tests).
var spawned := 0


static func cfg(key: String, default: Variant = 0.0) -> Variant:
	return Content.feel().get("boss", {}).get(key, default)


static func num(group: String, key: String, default := 0.0) -> float:
	return float(Content.feel().get("boss", {}).get(group, {}).get(key, default))


## Matière d'une région (ronce par défaut : arène des régions d'essai).
static func material_of(region_id: String) -> String:
	var m: Dictionary = cfg("materials", {})
	return str(m.get(region_id, m.get("defaut", "ronce")))


## Couleurs d'une matière : [principale, claire, sombre].
static func colors(m: String) -> Array:
	match m:
		"spore":
			return [Art.ec("poison"), Art.ec("poison", "clair"), Art.ec("poison", "sombre")]
		"vent":
			return [Color("8d8a86"), Art.ec("vent", "clair"), Art.ec("vent", "sombre")]
		"seve":
			return [Art.ec("seve"), Art.ec("seve", "clair"), Art.ec("seve", "sombre")]
		"aube":
			return [Color(Art.ec("lumiere", "clair"), 0.8), Art.ec("lumiere"), Color("8c7f3a")]
		"racine":
			return [Art.ec("racine"), Color("c9b98f"), Art.ec("racine", "sombre")]
		"finale":
			return [Color("5a4632"), Art.ec("cendre", "clair"), Art.ec("cendre", "sombre")]
	return [Art.c("ennemi").lerp(Art.ec("saignement"), 0.35), Art.ec("saignement", "clair"), Art.ec("saignement", "sombre")]


func setup(a) -> void:
	arena = a
	main = a.main
	mat = material_of(str(a.region))
	rng.seed = 4242 + str(a.region).hash() % 1000
	arena.add_child(self)
	over = Over.new()
	over.src = self
	main.projectiles_layer.add_sibling(over)
	_set_active(false)


func _exit_tree() -> void:
	if is_instance_valid(over):
		over.queue_free()


func _set_active(on: bool) -> void:
	active = on
	set_process(on)
	visible = on
	if is_instance_valid(over):
		over.visible = on


func _cap() -> int:
	var n := int(cfg("max_particles", 150))
	return maxi(1, n / 3) if Settings.reduce_effects else n


func _count(n: float) -> int:
	return maxi(1, int(round(n / 3.0))) if Settings.reduce_effects else int(n)


# =============================================================================================
# Accroches (boss_arena._start_fight, BossBase)
# =============================================================================================

## Le combat commence (boss_arena._start_fight) : l'arrivée se joue au premier pas du boss, sauf s'il
## est figé (tests visuels : la pose reste celle d'avant).
func arrive(b) -> void:
	clear()
	boss = b
	intro_len = maxf(0.1, float(b.intro_time))
	var to: Vector2 = main.player.position - arena.center
	gap_dir = to.normalized() if to.length() > 1.0 else Vector2.DOWN
	arrive_t = -1.0
	_bursts = 0
	_set_active(true)


## Le boss change de phase : onde de sa matière, puis une partie de l'arène se transforme.
func phase(b) -> void:
	if b == null or b.frozen:
		return
	boss = b
	_set_active(true)
	var r0: float = b.radius * 1.2
	var r1 := _room() / 0.85
	var dur := num("phase", "wave_time", 0.7)
	waves.append({"t": 0.0, "dur": dur, "r0": r0, "r1": r1})
	var n := _count(num("phase", "decor", 9.0))
	var rmin: float = b.radius * 1.6
	var rmax := _room()
	for i in n:
		var a: float = TAU * (i + rng.randf_range(0.1, 0.9)) / n + b.phase * 0.7
		var r := lerpf(rmin, rmax, sqrt(rng.randf()))
		_add_decor(b.anchor + Vector2.from_angle(a) * r, mat, rng.randf_range(0.8, 1.3) * num("phase", "decor_scale", 1.6), clock + dur * (r - r0) / maxf(1.0, r1 - r0))
	_burst(b.anchor, b.radius, _count(num("phase", "particles", 10.0)), 0.6)


## Le boss meurt (BossBase._die, avant fx.boss_kill) : sa mort signature.
func die(b) -> void:
	if b == null or b.frozen:
		return
	boss = b
	_set_active(true)
	_end_emerge()
	death_t = 0.0
	death_at = b.anchor
	death_r = b.radius
	var r := death_r
	var c: Array = colors(mat)
	match mat:
		"ronce":
			var n := _count(num("death", "vines", 9.0))
			for i in n:
				vines.append({"a": TAU * (i + rng.randf_range(-0.2, 0.2)) / n, "len": r * rng.randf_range(2.2, 3.4), "seed": rng.randf() * 10.0})
			for i in _count(num("death", "petals", 18.0)):
				var a := rng.randf() * TAU
				_part("petal", death_at + Vector2.from_angle(a) * r * 0.4, r * rng.randf_range(0.6, 1.2), Vector2.from_angle(a) * rng.randf_range(40.0, 140.0),
					rng.randf_range(60.0, 180.0), rng.randf_range(1.6, 2.6), rng.randf_range(5.0, 8.0), c[1].lerp(c[0], rng.randf()), 260.0)
		"spore":
			for i in _count(num("death", "puffs", 16.0)):
				var a := rng.randf() * TAU
				_part("puff", death_at + Vector2.from_angle(a) * r * rng.randf_range(0.1, 0.7), r * rng.randf_range(0.2, 0.9), Vector2.from_angle(a) * rng.randf_range(30.0, 110.0),
					rng.randf_range(10.0, 40.0), rng.randf_range(1.8, 2.8), r * rng.randf_range(0.35, 0.6), Color(c[0].lerp(c[1], rng.randf() * 0.5), 0.5), 0.0)
			for i in _count(num("death", "spores", 26.0)):
				var a := rng.randf() * TAU
				_part("dot", death_at + Vector2.from_angle(a) * r * 0.5, r * rng.randf_range(0.3, 1.0), Vector2.from_angle(a) * rng.randf_range(60.0, 200.0),
					rng.randf_range(20.0, 70.0), rng.randf_range(1.5, 3.0), rng.randf_range(1.5, 3.0), c[1], 0.0)
		"vent":
			for i in _count(num("death", "feathers", 30.0)):
				var a := rng.randf() * TAU
				var out := Vector2.from_angle(a) * rng.randf_range(80.0, 260.0)
				_part("feather", death_at + Vector2.from_angle(a) * r * 0.5, r * rng.randf_range(0.4, 1.2), out + out.orthogonal() * 0.6,
					rng.randf_range(80.0, 220.0), rng.randf_range(2.2, 3.4), rng.randf_range(9.0, 15.0), c[1].lerp(c[0], rng.randf() * 0.7), 120.0)
		"seve":
			for i in _count(num("death", "drops", 26.0)):
				var a := rng.randf() * TAU
				_part("drop", death_at + Vector2.from_angle(a) * r * 0.3, r * rng.randf_range(0.6, 1.3), Vector2.from_angle(a) * rng.randf_range(60.0, 220.0),
					rng.randf_range(80.0, 260.0), 4.0, rng.randf_range(3.0, 5.0), c[0].lerp(c[1], rng.randf() * 0.4), 900.0)
			_add_decor(death_at, "pool", r / 24.0, clock)
		"aube":
			for i in _count(num("death", "shards", 28.0)):
				var a := rng.randf() * TAU
				_part("shard", death_at + Vector2.from_angle(a) * r * 0.4, r * rng.randf_range(0.3, 1.1), Vector2.from_angle(a) * rng.randf_range(120.0, 340.0),
					rng.randf_range(120.0, 320.0), rng.randf_range(2.6, 3.6), rng.randf_range(6.0, 13.0), c[0], 900.0)
			for i in _count(num("death", "motes", 10.0)):
				_mote(death_at, r, c[1])
		"racine":
			for i in _count(num("death", "stones", 20.0)):
				var a := rng.randf() * TAU
				_part("stone", death_at + Vector2.from_angle(a) * r * 0.5, r * rng.randf_range(0.4, 1.4), Vector2.from_angle(a) * rng.randf_range(50.0, 200.0),
					rng.randf_range(40.0, 220.0), rng.randf_range(3.0, 4.0), rng.randf_range(6.0, 12.0), c[0].lerp(c[2], rng.randf() * 0.6), 900.0)
			for i in _count(num("death", "dust", 8.0)):
				var a := rng.randf() * TAU
				_part("puff", death_at + Vector2.from_angle(a) * r * 0.8, 4.0, Vector2.from_angle(a) * 60.0, 10.0, 1.6, r * 0.4, Color(c[1], 0.35), 0.0)
		"finale":
			var n := _count(num("death", "rays", 10.0))
			for i in n:
				rays.append({"a": TAU * (i + rng.randf_range(-0.25, 0.25)) / n, "len": r * rng.randf_range(2.5, 4.5), "w": r * rng.randf_range(0.12, 0.22)})
			for i in _count(num("death", "light_motes", 24.0)):
				_mote(death_at, r, Art.ec("lumiere", "clair"))
	if not Settings.reduce_effects:
		_ring_of_glyphs(death_at, r * 1.1)


## Le combat est perdu (le boss a disparu) : tout s'efface d'un coup.
func clear() -> void:
	_end_emerge()
	boss = null
	arrive_t = -1.0
	cracks.clear()
	decor.clear()
	waves.clear()
	parts.clear()
	vines.clear()
	rays.clear()
	death_t = -1.0
	_set_active(false)


## Rayon au-delà duquel rien ne se pose (l'arène peut se resserrer ou s'effondrer).
func _room() -> float:
	var r: float = minf(arena.radius, arena.min_radius)
	if arena.get("collapse_radius") != null:
		r = minf(r, float(arena.collapse_radius))
	return r * 0.85


# =============================================================================================
# Pas
# =============================================================================================

func _process(delta: float) -> void:
	clock += delta
	var b = boss if is_instance_valid(boss) else null
	if b != null and b.frozen:
		_end_emerge()
		return
	# Arrivée : jouée au premier pas du boss (pas s'il a été figé ou si son entrée est déjà finie).
	if b != null and not b.dead and arrive_t < 0.0 and cracks.is_empty() and b.intro > 0.0 and b.intro >= b.intro_time - 0.25:
		_begin_arrival(b)
	if arrive_t >= 0.0:
		_arrival_step(b, delta)
	for w in waves:
		w["t"] += delta
	waves = waves.filter(func(w): return w["t"] < w["dur"])
	_parts_step(delta)
	if death_t >= 0.0:
		death_t += delta
		_death_step(delta)
	queue_redraw()
	over.queue_redraw()
	if _idle():
		clear()


func _idle() -> bool:
	if not parts.is_empty() or not waves.is_empty() or arrive_t >= 0.0:
		return false
	if death_t >= 0.0:
		return death_t > num("death", "decor_hold", 2.2) + num("death", "decor_fade", 2.0) and vines.is_empty() and rays.is_empty()
	# Combat en cours : on garde les décors des phases tant que le boss vit.
	return not is_instance_valid(boss)


func _begin_arrival(b) -> void:
	arrive_t = 0.0
	intro_len = maxf(0.1, float(b.intro_time))
	cracks.clear()
	var n := _count(num("arrival", "cracks", 7.0))
	for i in n:
		var a := TAU * (i + rng.randf_range(-0.3, 0.3)) / n
		var pts := PackedVector2Array([Vector2.ZERO])
		var d := Vector2.from_angle(a)
		var steps := 6
		for j in steps:
			var u := float(j + 1) / steps
			pts.append(d * u + d.orthogonal() * rng.randf_range(-0.09, 0.09) * (1.0 - u * 0.5))
		cracks.append({"pts": pts, "len": rng.randf_range(0.7, 1.15)})
	# Poussière dans la brèche, là où le mur se referme d'abord.
	var gap: Vector2 = arena.center + gap_dir * arena.radius
	for i in _count(num("arrival", "gap_dust", 8.0)):
		var side := gap_dir.orthogonal() * rng.randf_range(-70.0, 70.0)
		_part("puff", gap + side, 6.0, -gap_dir * rng.randf_range(10.0, 50.0) + side * 0.3, 20.0, rng.randf_range(0.9, 1.4), rng.randf_range(16.0, 28.0), Color(colors(mat)[1], 0.3), 0.0)


func _arrival_step(b, delta: float) -> void:
	arrive_t += delta
	var k := arrive_t / intro_len
	# Le boss émerge : écrasé et sombre, il se dresse en dépassant un peu sa taille, puis se pose.
	if b != null and not b.dead:
		if b.intro > 0.0:
			var e := clampf((1.0 - b.intro / b.intro_time - 0.12) / 0.88, 0.0, 1.0)
			var squash := num("emerge", "squash", 0.25)
			var up := lerpf(squash, 1.0, Anim.ease_out_back(e, num("emerge", "overshoot", 1.6)))
			b.scale = Vector2(lerpf(1.25, 1.0, Anim.ease_out(e)), maxf(0.05, up))
			var m := lerpf(num("emerge", "dark", 0.3), 1.0, Anim.ease_in_out(e))
			b.modulate = Color(m, m, m, b.modulate.a)
			_emerging = true
		else:
			_end_emerge()
	# Débris : quand le sol cède, puis quand le corps sort.
	var steps: Array = [0.12, 0.5]
	if _bursts < steps.size() and k >= float(steps[_bursts]):
		var at: Vector2 = b.anchor if b != null else arena.center
		var rad: float = b.radius if b != null else 60.0
		_burst_clods(at, rad, _count(num("arrival", "clods", 16.0) * (0.5 if _bursts == 0 else 0.7)))
		if _bursts == 1:
			main.fx.shake(num("arrival", "shake", 0.3))
		_bursts += 1
	var end := 1.0 + num("arrival", "crack_fade", 1.6) / intro_len
	var wall_end := (num("arrival", "wall_wave", 0.8) + num("arrival", "spike_rise", 0.22) + num("arrival", "spike_hold", 0.25) + num("arrival", "spike_sink", 0.5)) / intro_len
	if k > maxf(end, wall_end):
		arrive_t = -1.0
		cracks.clear()
		_end_emerge()


func _end_emerge() -> void:
	if not _emerging:
		return
	_emerging = false
	if is_instance_valid(boss):
		boss.scale = Vector2.ONE
		boss.modulate = Color(1, 1, 1, boss.modulate.a)


func _death_step(_delta: float) -> void:
	# Lianes et déchirures : finies, elles disparaissent.
	if death_t > num("death", "vine_out", 0.35) + num("death", "vine_in", 1.4):
		vines.clear()
	if death_t > num("death", "ray_time", 1.8):
		rays.clear()


func _parts_step(dt: float) -> void:
	var kept: Array = []
	for q in parts:
		q["t"] += dt
		if q["t"] >= q["life"]:
			continue
		if not q["rest"]:
			q["p"] += q["v"] * dt
			q["vz"] -= q["g"] * dt
			q["z"] += q["vz"] * dt
			q["rot"] += q["spin"] * dt
			match q["k"]:
				"feather":
					q["v"] *= exp(-1.4 * dt)
					q["vz"] = maxf(q["vz"], -45.0)
					q["p"].x += sin(q["t"] * 4.0 + q["s"]) * 30.0 * dt
				"petal":
					q["v"] *= exp(-1.2 * dt)
					q["vz"] = maxf(q["vz"], -70.0)
				"puff", "dot", "mote":
					q["v"] *= exp(-1.8 * dt)
			if q["z"] <= 0.0 and q["vz"] < 0.0 and q["g"] > 0.0:
				q["z"] = 0.0
				match q["k"]:
					"stone", "clod":
						if absf(q["vz"]) > 90.0:
							q["vz"] = -q["vz"] * 0.35
							q["v"] *= 0.5
						else:
							_settle(q)
					"drop":
						# La sève tombe et reverdit le sol : une flaque, parfois une pousse.
						_add_decor(q["p"], "pool", rng.randf_range(0.3, 0.6), clock)
						if rng.randf() < num("death", "sprout_chance", 0.5):
							_add_decor(q["p"] + Vector2(rng.randf_range(-6, 6), 0), "sprout", rng.randf_range(0.7, 1.2), clock + 0.15)
						continue
					_:
						_settle(q)
		kept.append(q)
	parts = kept


func _settle(q: Dictionary) -> void:
	q["rest"] = true
	q["z"] = 0.0
	q["vz"] = 0.0
	q["v"] = Vector2.ZERO
	q["spin"] = 0.0


# =============================================================================================
# Création
# =============================================================================================

func _part(k: String, p: Vector2, z: float, v: Vector2, vz: float, life: float, s: float, c: Color, g: float) -> void:
	if parts.size() >= _cap():
		return
	spawned += 1
	parts.append({"k": k, "p": p, "z": z, "v": v, "vz": vz, "g": g, "t": 0.0, "life": life, "s": s, "c": c,
		"rot": rng.randf() * TAU, "spin": rng.randf_range(-7.0, 7.0), "rest": false})


func _mote(at: Vector2, r: float, c: Color) -> void:
	var a := rng.randf() * TAU
	_part("mote", at + Vector2.from_angle(a) * r * rng.randf_range(0.2, 1.0), r * rng.randf_range(0.2, 1.2), Vector2.from_angle(a) * rng.randf_range(20.0, 90.0),
		rng.randf_range(40.0, 120.0), rng.randf_range(1.2, 2.2), rng.randf_range(2.0, 3.5), c, 0.0)


func _burst_clods(at: Vector2, r: float, n: int) -> void:
	var earth := Art.c("decor").lightened(0.15)
	var c: Array = colors(mat)
	for i in n:
		var a := rng.randf() * TAU
		var col: Color = earth if i % 3 else c[2].lerp(earth, 0.4)
		_part("clod", at + Vector2.from_angle(a) * r * rng.randf_range(0.2, 0.8), 2.0, Vector2.from_angle(a) * rng.randf_range(60.0, 220.0),
			rng.randf_range(160.0, 360.0), rng.randf_range(1.4, 2.2), rng.randf_range(3.0, 6.0), col, 900.0)


## Petits éclats de la matière autour du boss (changement de phase).
func _burst(at: Vector2, r: float, n: int, life: float) -> void:
	var c: Array = colors(mat)
	var k: String = {"ronce": "petal", "spore": "dot", "vent": "feather", "seve": "drop", "aube": "shard", "racine": "stone", "finale": "mote"}.get(mat, "clod")
	for i in n:
		var a := rng.randf() * TAU
		_part(k, at + Vector2.from_angle(a) * r * 0.7, r * 0.6, Vector2.from_angle(a) * rng.randf_range(90.0, 220.0),
			rng.randf_range(60.0, 160.0), life + rng.randf_range(0.6, 1.2), rng.randf_range(4.0, 8.0), c[1] if k in ["dot", "mote"] else c[0], 0.0 if k in ["dot", "mote"] else 500.0)


func _add_decor(p: Vector2, kind: String, size: float, born: float) -> void:
	var limit := _count(num("phase", "max_decor", 40.0))
	if decor.size() >= limit:
		decor.pop_front()
	decor.append({"pos": p, "kind": kind, "size": size, "rot": rng.randf() * TAU, "born": born, "seed": rng.randf() * 10.0})


## Couronne de la matière au pied du boss mourant (posée comme un décor qui s'efface ensuite).
func _ring_of_glyphs(at: Vector2, r: float) -> void:
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		_add_decor(at + Vector2.from_angle(a) * r, mat, 0.7, clock + 0.05 * i)


# =============================================================================================
# Dessin
# =============================================================================================

## Au sol (sous les personnages), en coordonnées monde.
func _draw() -> void:
	var c: Array = colors(mat)
	var fade := 1.0
	if death_t >= 0.0:
		fade = 1.0 - clampf((death_t - num("death", "decor_hold", 2.2)) / maxf(0.01, num("death", "decor_fade", 2.0)), 0.0, 1.0)
	# Décors des phases (et flaques, pousses).
	for d in decor:
		var g := clampf((clock - float(d["born"])) / 0.35, 0.0, 1.0)
		if g <= 0.0:
			continue
		_draw_decor(d, Anim.ease_out_back(g), fade, c)
	# Fissures sous le boss qui arrive.
	if arrive_t >= 0.0 and not cracks.is_empty():
		var k := arrive_t / intro_len
		var grow := Anim.ease_out(clampf(k / 0.45, 0.0, 1.0))
		var alpha := 1.0 - clampf((k - 1.0) * intro_len / maxf(0.01, num("arrival", "crack_fade", 1.6)), 0.0, 1.0)
		var b = boss if is_instance_valid(boss) else null
		var at: Vector2 = b.anchor if b != null else arena.center
		var len: float = (b.radius if b != null else 60.0) * num("arrival", "crack_len", 2.6)
		for cr in cracks:
			var pts := PackedVector2Array()
			var src: PackedVector2Array = cr["pts"]
			var upto := grow * (src.size() - 1)
			for j in src.size():
				if j > upto + 0.001:
					var last: Vector2 = src[j - 1].lerp(src[j], upto - (j - 1))
					pts.append(at + last * len * float(cr["len"]))
					break
				pts.append(at + src[j] * len * float(cr["len"]))
			if pts.size() >= 2:
				draw_polyline(pts, Color(Art.c("contour"), 0.85 * alpha), 10.0, true)
				draw_polyline(pts, Color(c[1], 0.9 * alpha * (0.6 + 0.4 * sin(clock * 9.0))), 4.0, true)
		# Le trou d'où il sort.
		var hole: float = (b.radius if b != null else 60.0) * 1.05 * grow
		if hole > 4.0:
			draw_colored_polygon(Art.ellipse(at + Vector2(0, hole * 0.15), hole, hole * 0.55, 24), Color(Art.c("contour"), 0.6 * alpha))
	# Le mur se referme : la matière pousse en vague depuis la brèche, puis rentre dans le mur.
	if arrive_t >= 0.0:
		_draw_wall_growth(c)
	# Ondes des phases.
	for w in waves:
		var u: float = w["t"] / w["dur"]
		var r := lerpf(w["r0"], w["r1"], Anim.ease_out(u))
		var n := 28
		var at: Vector2 = boss.anchor if is_instance_valid(boss) else arena.center
		draw_arc(at, r, 0.0, TAU, 72, Color(c[1], 0.55 * (1.0 - u)), 4.0 * (1.0 - u) + 1.0, true)
		for i in n:
			var dir := Vector2.from_angle(TAU * i / n + u * 0.4)
			glyph(self, mat, at + dir * r, dir, 16.0 * (1.0 - u * 0.6), c, 1.0 - u, clock + i)
	# Lianes de la Mère-Ronce : elles se dénouent vers l'extérieur, puis rentrent dans le sol par leur bout.
	if not vines.is_empty():
		var out_t := num("death", "vine_out", 0.35)
		var in_t := num("death", "vine_in", 1.4)
		var ext := Anim.ease_out(clampf(death_t / out_t, 0.0, 1.0))
		var back := Anim.ease_in_out(clampf((death_t - out_t) / in_t, 0.0, 1.0))
		for v in vines:
			_draw_vine(v, ext, back, c)
	# Ce qui est retombé au sol.
	for q in parts:
		if q["rest"]:
			_draw_part(self, q)


func _draw_wall_growth(c: Array) -> void:
	var wave := num("arrival", "wall_wave", 0.8)
	var rise := num("arrival", "spike_rise", 0.22)
	var hold := num("arrival", "spike_hold", 0.25)
	var sink := num("arrival", "spike_sink", 0.5)
	var n := _count(num("arrival", "wall_spikes", 56.0))
	var base_a := gap_dir.angle()
	var r: float = arena.radius
	for i in n:
		var a := TAU * i / n
		var off := absf(wrapf(a - base_a, -PI, PI)) / PI
		var lt := arrive_t - off * wave
		if lt <= 0.0:
			continue
		var h := 0.0
		if lt < rise:
			h = Anim.ease_out_back(lt / rise)
		elif lt < rise + hold:
			h = 1.0
		elif lt < rise + hold + sink:
			h = 1.0 - Anim.ease_in((lt - rise - hold) / sink)
		else:
			continue
		var dir := Vector2.from_angle(a)
		var size := num("arrival", "spike_size", 52.0) * (0.8 + 0.4 * fposmod(i * 0.618, 1.0)) * (1.25 if off < 0.15 else 1.0)
		glyph(self, mat, arena.center + dir * (r - 6.0), dir, size * h, c, 1.0, clock + i)


func _draw_vine(v: Dictionary, ext: float, back: float, c: Array) -> void:
	var a: float = v["a"]
	var n := 12
	var pts := PackedVector2Array()
	var from := back * 0.92
	for j in n + 1:
		var u := lerpf(from, 1.0, float(j) / n)
		var sway := 0.35 * sin(u * 6.0 + float(v["seed"]) + death_t * 5.0) * u
		pts.append(death_at + Vector2.from_angle(a + sway) * (death_r * 0.4 + float(v["len"]) * u * ext))
	var w := 9.0 * (1.0 - back * 0.6)
	draw_polyline(pts, Art.c("contour"), w + 3.0, true)
	draw_polyline(pts, c[2].lerp(c[0], 0.4), w, true)
	# Épines le long de la liane.
	for j in range(1, pts.size() - 1, 2):
		var d := (pts[j + 1] - pts[j]).normalized()
		var side := d.orthogonal() * (1.0 if j % 4 == 1 else -1.0)
		_tri(self, pts[j] + side * w * 0.4, pts[j] + side * w * 1.3 + d * 3.0, pts[j] + d * w * 0.6, c[1])
	# Trou où elle rentre.
	var tip := pts[pts.size() - 1]
	draw_colored_polygon(Art.ellipse(tip, 9.0, 5.0, 12), Color(Art.c("contour"), 0.7 * ext))


func _draw_decor(d: Dictionary, g: float, fade: float, c: Array) -> void:
	if fade <= 0.0:
		return
	var p: Vector2 = d["pos"]
	var s: float = d["size"] * g
	if s < 0.08:
		return
	var rot: float = d["rot"]
	match d["kind"]:
		"pool":
			var rr := 22.0 * s
			if rr < 3.0:
				return
			draw_colored_polygon(Art.ellipse(p, rr, rr * 0.5, 16), Color(Art.ec("seve", "sombre"), 0.55 * fade))
			draw_colored_polygon(Art.ellipse(p + Vector2(-rr * 0.2, -rr * 0.1), rr * 0.6, rr * 0.25, 12), Color(Art.ec("seve"), 0.45 * fade))
		"sprout":
			var h := 12.0 * s
			draw_line(p, p + Vector2(0, -h), Color(Art.c("decor_vivant").lightened(0.2), fade), 2.0, true)
			for side in [-1.0, 1.0]:
				_tri(self, p + Vector2(0, -h * 0.7), p + Vector2(side * h * 0.6, -h * 1.05), p + Vector2(side * h * 0.1, -h * 1.1), Color(Art.ec("racine", "clair"), fade))
		"ronce":
			# Fissure du sol, hérissée d'épines.
			var dir := Vector2.from_angle(rot)
			var pts := PackedVector2Array([p - dir * 26.0 * s, p - dir * 8.0 * s + dir.orthogonal() * 5.0 * s, p + dir * 10.0 * s - dir.orthogonal() * 4.0 * s, p + dir * 28.0 * s])
			draw_polyline(pts, Color(Art.c("contour"), 0.8 * fade), 5.0, true)
			draw_polyline(pts, Color(c[1], 0.35 * fade), 1.5, true)
			for j in 3:
				glyph(self, "ronce", pts[j] + Vector2(0, 2.0), Vector2.UP.rotated((j - 1) * 0.5), 13.0 * s, c, fade, d["seed"])
		"spore":
			for j in 5:
				var q := p + Vector2.from_angle(rot + j * 1.3) * 12.0 * s * (0.4 + 0.15 * j)
				draw_circle(q, 7.0 * s * (1.0 - 0.1 * j), Color(c[0], 0.22 * fade))
			for j in 7:
				draw_circle(p + Vector2.from_angle(rot * 2.0 + j * 0.9) * 16.0 * s * fposmod(j * 0.37, 1.0), 1.6, Color(c[1], (0.5 + 0.3 * sin(clock * 3.0 + j)) * fade))
			glyph(self, "spore", p, Vector2.UP, 14.0 * s, c, fade, d["seed"])
		"vent":
			_draw_feather(self, p, rot, 13.0 * s, Color(c[1].lerp(c[0], 0.4), 0.9 * fade))
		"seve":
			# La sève monte : une flaque qui s'étend et luit, une tige.
			var rr := 18.0 * s * (1.0 + 0.15 * sin(clock * 1.5 + d["seed"]))
			if rr < 3.0:
				return
			draw_colored_polygon(Art.ellipse(p, rr, rr * 0.5, 16), Color(c[2], 0.5 * fade))
			draw_colored_polygon(Art.ellipse(p + Vector2(-rr * 0.2, -rr * 0.1), rr * 0.55, rr * 0.22, 12), Color(c[0], 0.4 * fade))
			glyph(self, "seve", p, Vector2.UP, 14.0 * s, c, fade, d["seed"])
		"aube":
			# Éclat de verre planté, qui accroche la lumière.
			var dir := Vector2.UP.rotated(sin(rot) * 0.5)
			glyph(self, "aube", p, dir, 18.0 * s, c, fade, d["seed"])
			var glint := maxf(0.0, sin(clock * 2.2 + float(d["seed"]) * 3.0)) ** 8.0
			if glint > 0.05:
				var at := p + dir * 12.0 * s
				draw_line(at - Vector2(5, 0) * glint, at + Vector2(5, 0) * glint, Color(Art.ec("lumiere", "clair"), glint * fade), 1.5)
				draw_line(at - Vector2(0, 5) * glint, at + Vector2(0, 5) * glint, Color(Art.ec("lumiere", "clair"), glint * fade), 1.5)
		"racine":
			# Dalle de pierre soulevée, fendue.
			var pts := PackedVector2Array()
			for j in 6:
				var a := rot + TAU * j / 6.0
				pts.append(p + Vector2(cos(a) * 18.0, sin(a) * 10.0) * s * (0.85 + 0.25 * fposmod(j * 0.618 + d["seed"], 1.0)))
			Art.fill_safe(self, pts, Color(c[2].lerp(c[0], 0.5), fade))
			Art.outline(self, pts, Color(Art.c("contour"), 0.8 * fade), 2.0)
			draw_line(p - Vector2(8, 2) * s, p + Vector2(6, 3) * s, Color(Art.c("contour"), 0.7 * fade), 1.5, true)
		"finale":
			# Veine de lumière qui fend le sol et pulse.
			var dir := Vector2.from_angle(rot)
			var pts := PackedVector2Array([p - dir * 30.0 * s, p - dir * 10.0 * s + dir.orthogonal() * 6.0 * s, p + dir * 8.0 * s - dir.orthogonal() * 5.0 * s, p + dir * 30.0 * s])
			draw_polyline(pts, Color(Art.c("contour"), 0.8 * fade), 6.0, true)
			draw_polyline(pts, Color(Art.ec("lumiere", "clair"), (0.45 + 0.3 * sin(clock * 4.0 + d["seed"])) * fade), 2.0, true)


## Au-dessus des personnages : ce qui vole, et la lumière de la Flétrissure qui se déchire.
func draw_over(ci: CanvasItem) -> void:
	for q in parts:
		if not q["rest"]:
			_draw_part(ci, q)
	if not rays.is_empty():
		var rt := num("death", "ray_time", 1.8)
		var open := Anim.ease_out(clampf(death_t / (rt * 0.4), 0.0, 1.0))
		var fade := 1.0 - Anim.ease_in(clampf((death_t - rt * 0.4) / (rt * 0.6), 0.0, 1.0))
		var col := Art.ec("lumiere", "clair")
		for r in rays:
			var d := Vector2.from_angle(r["a"])
			var len: float = r["len"] * open
			var w: float = r["w"] * fade
			if len < 2.0 or w < 0.5:
				continue
			var base := death_at + Vector2(0, -death_r * 0.4)
			_tri(ci, base + d.orthogonal() * w, base + d * len, base - d.orthogonal() * w, Color(col, 0.75 * fade))
			_tri(ci, base + d.orthogonal() * w * 0.35, base + d * len * 0.8, base - d.orthogonal() * w * 0.35, Color(1, 1, 1, 0.9 * fade))


func _draw_part(ci: CanvasItem, q: Dictionary) -> void:
	var u: float = q["t"] / q["life"]
	var a := 1.0 - clampf((u - 0.7) / 0.3, 0.0, 1.0)
	var p: Vector2 = q["p"] + Vector2(0, -q["z"])
	var s: float = q["s"]
	var col: Color = q["c"]
	col.a *= a
	var rot: float = q["rot"]
	match q["k"]:
		"clod", "stone":
			var pts := PackedVector2Array()
			var m := 5 if q["k"] == "stone" else 4
			for j in m:
				var an := rot + TAU * j / m
				pts.append(p + Vector2.from_angle(an) * s * (0.8 + 0.3 * fposmod(j * 0.618, 1.0)))
			Art.fill_safe(ci, pts, col)
			if q["k"] == "stone" and s > 5.0:
				Art.outline(ci, pts, Color(Art.c("contour"), 0.7 * a), 1.5)
		"petal":
			var d := Vector2.from_angle(rot)
			_tri(ci, p - d * s, p + d.orthogonal() * s * 0.45, p + d * s, col)
			_tri(ci, p - d * s, p - d.orthogonal() * s * 0.45, p + d * s, col.darkened(0.25))
		"puff":
			ci.draw_circle(p, s * (1.0 + 1.2 * u), Color(col, col.a * (1.0 - u * 0.6)))
		"dot", "mote":
			ci.draw_circle(p, s, col)
			if q["k"] == "mote":
				ci.draw_circle(p, s * 2.2, Color(col, col.a * 0.25))
		"feather":
			_draw_feather(ci, p, rot, s, col)
		"drop":
			var v: Vector2 = q["v"] + Vector2(0, -q["vz"])
			var d := v.normalized() if v.length() > 1.0 else Vector2.DOWN
			ci.draw_circle(p, s, col)
			_tri(ci, p + d.orthogonal() * s * 0.9, p - d * s * 2.4, p - d.orthogonal() * s * 0.9, col)
		"shard":
			var d := Vector2.from_angle(rot)
			var pts := PackedVector2Array([p + d * s, p + d.orthogonal() * s * 0.35 - d * s * 0.3, p - d * s * 0.7])
			_tri(ci, pts[0], pts[1], pts[2], col)
			ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(Art.ec("lumiere"), 0.8 * a), 1.0, true)
			var glint := maxf(0.0, sin(q["t"] * 14.0 + s)) ** 6.0
			if glint > 0.1 and not q["rest"]:
				ci.draw_circle(p, 2.0 + 2.0 * glint, Color(1, 1, 1, glint * a))


static func _draw_feather(ci: CanvasItem, p: Vector2, rot: float, s: float, col: Color) -> void:
	var d := Vector2.from_angle(rot)
	var n := d.orthogonal()
	var pts := PackedVector2Array([p - d * s, p + n * s * 0.32 - d * s * 0.2, p + d * s * 0.9, p + d * s, p - n * s * 0.28 + d * s * 0.1])
	Art.fill_safe(ci, pts, col)
	ci.draw_line(p - d * s * 1.25, p + d * s, Color(col.darkened(0.45), col.a), 1.2, true)


## Un brin de la matière d'une région, planté en « base » et dressé vers « up » (hauteur h) : épine,
## champignon, pierre levée, tige de sève, éclat de verre, pilier de pierre, racine braisée.
static func glyph(ci: CanvasItem, m: String, base: Vector2, up: Vector2, h: float, c: Array, alpha: float, seed_: float) -> void:
	if h < 2.0 or alpha <= 0.01:
		return
	# Vue de dessus en légère perspective : la matière se dresse vers le haut de l'écran.
	var dir := (up * 0.35 + Vector2.UP).normalized()
	var side := dir.orthogonal()
	var main_c: Color = c[0]
	var light: Color = c[1]
	var dark: Color = c[2]
	match m:
		"spore":
			var top := base + dir * h * 0.75
			ci.draw_line(base, top, Color(Art.c("texte").darkened(0.3), alpha), maxf(1.5, h * 0.14), true)
			var cap := PackedVector2Array()
			for j in 9:
				var a := PI * j / 8.0
				cap.append(top + side * cos(a) * h * 0.45 + dir * sin(a) * h * 0.32)
			Art.fill_safe(ci, cap, Color(main_c, alpha))
			ci.draw_circle(top + dir * h * 0.15, maxf(1.0, h * 0.06), Color(light, alpha))
		"vent":
			var w := h * 0.28
			var pts := PackedVector2Array([base - side * w, base - side * w * 0.7 + dir * h, base + side * w * 0.8 + dir * h * 0.92, base + side * w])
			Art.fill_safe(ci, pts, Color(dark.lerp(main_c, 0.5), alpha))
			ci.draw_line(base - side * w * 0.7 + dir * h, base + side * w * 0.8 + dir * h * 0.92, Color(light, 0.8 * alpha), 1.5, true)
		"seve":
			var tip := base + dir * h + side * h * 0.15 * sin(seed_)
			ci.draw_line(base, tip, Color(dark, alpha), maxf(1.5, h * 0.12), true)
			ci.draw_circle(tip, maxf(1.5, h * 0.16), Color(main_c, alpha))
			ci.draw_circle(tip - side * h * 0.04, maxf(0.8, h * 0.06), Color(light, alpha))
		"aube":
			var w := h * 0.2
			_tri(ci, base - side * w, base + dir * h + side * w * 0.4, base + side * w, Color(main_c, main_c.a * alpha))
			ci.draw_line(base - side * w * 0.3, base + dir * h * 0.95, Color(1, 1, 1, 0.7 * alpha), 1.0, true)
		"racine":
			var w := h * 0.32
			var pts := PackedVector2Array([base - side * w, base - side * w * 0.6 + dir * h * 0.85, base + dir * h, base + side * w * 0.7 + dir * h * 0.8, base + side * w])
			Art.fill_safe(ci, pts, Color(dark.lerp(main_c, 0.6), alpha))
			ci.draw_line(base - side * w * 0.6 + dir * h * 0.85, base + dir * h, Color(light, 0.7 * alpha), 1.5, true)
		"finale":
			var tip := base + dir * h + side * h * 0.3 * sin(seed_ * 2.0)
			var mid := base.lerp(tip, 0.5) - side * h * 0.15
			ci.draw_polyline(PackedVector2Array([base, mid, tip]), Color(Art.c("contour"), alpha), maxf(2.0, h * 0.22), true)
			ci.draw_polyline(PackedVector2Array([base, mid, tip]), Color(main_c, alpha), maxf(1.2, h * 0.14), true)
			ci.draw_circle(tip, maxf(1.0, h * 0.08), Color(light, alpha))
		_:
			# Épine de ronce : un crochet, sombre à la base, clair à la pointe.
			var w := h * 0.22
			var tip := base + dir * h + side * h * 0.2
			_tri(ci, base - side * w, tip, base + side * w, Color(main_c, alpha))
			_tri(ci, base.lerp(tip, 0.55) - side * w * 0.3, tip, base.lerp(tip, 0.55) + side * w * 0.3, Color(light, alpha))


## Triangle plein, ignoré s'il est dégénéré (trop petit pour se voir).
static func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	if absf((b - a).cross(c - a)) < 0.5 or col.a <= 0.0:
		return
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), col)
