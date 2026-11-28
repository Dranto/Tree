## L'Amanite-Mère, boss de la région de Spore : une amanite géante plantée au centre de son arène,
## au milieu du marais. Nommée dans data/regions/spore.json › boss.
##
## Trois phases (100–66 %, 66–33 %, 33–0 % de sa vie). Chaque coup est annoncé avant de frapper
## (Art.telegraph, charte § 6) et le chapeau se gonfle ou se soulève pendant l'annonce :
##   - nuages   : des cercles se posent sous le joueur, puis crèvent en nuages de spores qui restent
##                quelques secondes et blessent qui s'y tient (sortir des nuages, ne pas s'y battre) ;
##   - salve    : un éventail de spores tiré vers le joueur (cône au sol), deux ou trois fois ;
##   - onde     : le chapeau s'abat, une onde de choc frappe autour d'elle (cercle au sol) : reculer ;
##   - spirale  (dès la phase 2) : deux puis trois bras de spores tournent depuis son pied (les bras
##                de départ sont marqués au sol) : tourner avec eux ;
##   - invocation (dès la phase 2) : des boutons éclosent en Scissipores et Sporules (pas en rouge :
##                ce n'est pas un coup) ;
##   - mycélium (phase 3) : des filaments fendent le sol en lignes vers le joueur, puis jaillissent ;
##                l'arène se resserre (boss_arena.gd).
## Cycle exalté (NG+, à partir du cycle 2, boss_base.gd › Cycle exalté) :
##   - anneaux (phase exaltée, et phase 3 quand cycles.json le demande) : des ronds de sorcière
##                partent de son pied l'un après l'autre, un par temps de sa musique, chacun ouvert d'une
##                brèche (la première face au joueur, les suivantes décalées) : passer par les brèches ;
##                l'annonce montre la première vague et sa brèche ;
##   - phase exaltée (sous 22 % de sa vie) : le chapeau s'embrase d'encre, chaque coup tombe sur un
##                temps, cinq anneaux par vague, plus d'invocation.
## Sa mort : le chapeau s'affaisse et se vide de ses spores ; à sa place pousse un cercle de
## champignons clairs dans la mousse (draw_victory).
##
## Le socle (vie, phases, états, mort, interface d'ennemi) est dans boss_base.gd.
extends BossBase

const PHASE_LIMITS := [0.66, 0.33]
## Par phase : pause entre deux attaques, ordre des attaques et ampleur.
const PHASES := {
	1: {"gap": 1.3, "order": ["nuages", "salve", "onde", "nuages", "salve"], "clouds": 3, "volleys": 2, "spores": 7, "arms": 0},
	2: {"gap": 1.1, "order": ["salve", "invocation", "nuages", "spirale", "onde"], "clouds": 4, "volleys": 2, "spores": 9, "arms": 2, "minions": 3},
	3: {"gap": 0.9, "order": ["mycelium", "nuages", "spirale", "onde", "invocation", "salve"], "clouds": 5, "volleys": 3, "spores": 9, "arms": 3, "minions": 4, "lines": 3, "rings": 3},
	# Phase exaltée (cycle 2 et plus seulement).
	4: {"gap": 0.8, "order": ["anneaux", "nuages", "salve", "anneaux", "mycelium", "spirale"], "clouds": 4, "volleys": 3, "spores": 11, "arms": 3, "minions": 0, "lines": 4, "rings": 5},
}
## Attaque nouvelle du cycle exalté (boss_base.gd › Cycle exalté).
const EXALTED_ATTACK := "anneaux"
## Ronds de sorcière : annonce, un anneau par temps (« every » temps de LOOP_BEAT), vitesse, largeur de
## la bande, brèche (radians), décalage de la brèche d'un anneau au suivant, dégâts.
const FAIRY := {"annonce": 1.0, "every": 1.0, "speed": 230.0, "width": 34.0, "gap": 1.05, "turn": 0.75, "damage": 16.0}
const CLOUD := {"annonce": 1.0, "radius": 70.0, "spread": 170.0, "life": 3.2, "dps": 16.0, "tick": 0.5}
const VOLLEY := {"annonce": 0.85, "between": 0.4, "damage": 12.0, "speed": 300.0, "radius": 9.0, "spread": 0.17}
const WAVE := {"annonce": 1.05, "radius": 230.0, "radius_p3": 290.0, "damage": 22.0, "flash": 0.3}
const SPIRAL := {"annonce": 0.9, "duration": 2.2, "rate": 9.0, "turn": 1.4, "damage": 10.0, "speed": 240.0}
const SUMMON := {"annonce": 1.0, "max_alive": 6, "kinds": ["scissipore", "sporule", "sporule", "scissipore"]}
const MYCELIUM := {"annonce": 1.0, "length": 430.0, "width": 44.0, "damage": 20.0, "flash": 0.3, "fan": 0.42}
const PHASE_PAUSE := 1.4

## Attaque en cours ("" pendant la pause), son étape ("annonce" ou "frappe") et le temps restant.
var attack := ""
var stage := ""
var timer := 0.0
var stage_time := 1.0
var gap := 1.4
var cycle := 0
## Direction visée par l'attaque en cours.
var aim := Vector2.DOWN
var volleys_left := 0
var volley_timer := 0.0
var spiral_clock := 0.0
var spiral_angle := 0.0
## Spores en vol : {"pos", "vel"}.
var spores: Array = []
## Nuages : {"pos", "fuse" (avant d'éclater, > 0), "life" (après)}.
var clouds: Array = []
var _cloud_tick := 0.0
## Boutons de l'invocation en cours (positions).
var buds: Array = []
## Lignes du mycélium (directions) et éclair de leur frappe.
var lines: Array = []
var strike_flash := -1.0
## Ronds de sorcière : brèches prévues de la vague en cours, et anneaux qui s'étendent
## {"r", "gap", "hit", "born"}.
var ring_gaps: Array = []
var rings: Array = []
var ring_timer := 0.0


func _setup() -> void:
	body_radius = 72.0
	intro_time = 1.4
	death_time = 1.9
	base_hp = 620.0
	hp_per_level = 205.0
	damage_per_level = 0.03
	contact_damage = 16.0
	phase_limits = PHASE_LIMITS
	color = Color("3a2a44")


func _projectiles_step(delta: float) -> void:
	_update_spores(delta)
	_update_clouds(delta)
	_update_rings(delta)
	if strike_flash >= 0.0:
		strike_flash += delta
		if strike_flash > WAVE["flash"]:
			strike_flash = -1.0
			if attack == "" or attack == "mycelium":
				lines = []


func _fight_step(delta: float) -> void:
	var cad := cadence()
	if attack == "":
		var wanted := phase_for(hp / max_hp)
		if wanted > phase:
			_enter_phase(wanted)
			return
		gap -= delta * cad
		if gap <= 0.0:
			var order: Array = exalted_order(PHASES[phase]["order"], EXALTED_ATTACK)
			_begin(order[cycle % order.size()])
			cycle += 1
	elif stage == "annonce":
		timer -= delta * cad
		_announce_step()
		if timer <= 0.0:
			_strike()
	else:
		timer -= delta
		_strike_step(delta)
		if timer <= 0.0:
			_end_attack()


# --- Attaques ---

func _begin(kind: String) -> void:
	var cfg: Dictionary = PHASES[phase]
	if kind == "invocation" and minions.size() >= SUMMON["max_alive"]:
		kind = "salve"
	attack = kind
	stage = "annonce"
	Sfx.play("annonce", anchor)
	var to: Vector2 = main.player.position - anchor
	aim = to.normalized() if to.length() > 1.0 else Vector2.DOWN
	match kind:
		"nuages":
			_set_timer(CLOUD["annonce"])
			var p: Vector2 = main.player.position
			for i in int(cfg["clouds"]):
				var at := p
				if i > 0:
					at = p + Vector2.from_angle(randf() * TAU) * randf_range(0.45, 1.0) * CLOUD["spread"]
				at = _in_arena(at, CLOUD["radius"] * 0.5)
				clouds.append({"pos": at, "fuse": CLOUD["annonce"], "life": CLOUD["life"] + (0.8 if phase >= 3 else 0.0)})
		"salve":
			_set_timer(VOLLEY["annonce"])
		"onde":
			_set_timer(WAVE["annonce"])
		"spirale":
			_set_timer(SPIRAL["annonce"])
			spiral_angle = aim.angle() + PI / float(cfg["arms"])
		"invocation":
			_set_timer(SUMMON["annonce"])
			buds = []
			var n: int = cfg["minions"]
			for i in n:
				var a := aim.angle() + PI + (i - (n - 1) / 2.0) * 0.6
				buds.append(anchor + Vector2.from_angle(a) * 160.0)
		"mycelium":
			_set_timer(MYCELIUM["annonce"])
			lines = []
			var n: int = cfg.get("lines", 3)
			for i in n:
				lines.append(Vector2.from_angle(aim.angle() + (i - (n - 1) / 2.0) * MYCELIUM["fan"]))
		"anneaux":
			_set_timer(FAIRY["annonce"])
			exalted_attacks += 1
			# La première brèche fait face au joueur, les suivantes tournent d'un côté puis de l'autre.
			ring_gaps = []
			var side := 1.0 if cycle % 2 == 0 else -1.0
			var a := aim.angle()
			for i in int(cfg.get("rings", 3)):
				ring_gaps.append(a)
				a += side * FAIRY["turn"] * (1.0 if i % 2 == 0 else 0.6)
	# Phase exaltée : la frappe tombe sur un temps de la musique.
	if is_exalted_phase() and kind != "nuages":
		_set_timer(loop_snap(timer))


func _set_timer(v: float) -> void:
	timer = v
	stage_time = v


## Garde un point dans l'arène (à « margin » du bord).
func _in_arena(p: Vector2, margin: float) -> Vector2:
	var to: Vector2 = p - arena.center
	var lim: float = maxf(40.0, arena.radius - margin)
	return arena.center + to.limit_length(lim)


## Pendant l'annonce, la salve suit le joueur puis se verrouille.
func _announce_step() -> void:
	if attack == "salve" and timer > stage_time * 0.4:
		var to: Vector2 = main.player.position - anchor
		if to.length() > 1.0:
			aim = to.normalized()


func _strike() -> void:
	stage = "frappe"
	match attack:
		"nuages":
			# Les nuages éclatent d'eux-mêmes (leur « fuse ») : l'attaque est finie.
			_end_attack()
		"salve":
			volleys_left = PHASES[phase]["volleys"]
			volley_timer = 0.0
			_set_timer(VOLLEY["between"] * volleys_left)
		"onde":
			var r := _wave_radius()
			var p = main.player
			if p.position.distance_to(anchor) < r + p.radius * 0.5:
				p.take_hit(WAVE["damage"] * damage_scale, self)
			strike_flash = 0.0
			main.fx.ring(anchor, radius, r, 0.4, Color(Art.ec("poison", "clair"), 0.9), 6.0)
			main.fx.shake(6.0)
			_end_attack()
		"spirale":
			spiral_clock = 0.0
			_set_timer(SPIRAL["duration"])
		"anneaux":
			# Un anneau tout de suite, puis un par temps de la musique.
			ring_timer = 0.0
			_set_timer(LOOP_BEAT * FAIRY["every"] * maxf(0.0, ring_gaps.size() - 1.0) + 0.05)
		"invocation":
			var kinds: Array = SUMMON["kinds"]
			for i in buds.size():
				var b: Vector2 = buds[i]
				minions.append(main.spawn_enemy_kind(kinds[i % kinds.size()], b, main.threat(b)))
				main.fx.ring(b, 6.0, 46.0, 0.35, Color(Art.ec("poison", "clair"), 0.8), 3.0)
			buds = []
			_end_attack()
		"mycelium":
			var p = main.player
			for d in lines:
				if _on_line(p.position, d, p.radius * 0.5):
					p.take_hit(MYCELIUM["damage"] * damage_scale, self)
					break
			strike_flash = 0.0
			main.fx.shake(4.0)
			_end_attack()


func _strike_step(delta: float) -> void:
	match attack:
		"anneaux":
			ring_timer -= delta
			if not ring_gaps.is_empty() and ring_timer <= 0.0:
				ring_timer += LOOP_BEAT * FAIRY["every"]
				rings.append({"r": radius * 0.9, "gap": ring_gaps.pop_front(), "hit": false, "born": t})
				Sfx.play("nuage", anchor)
		"salve":
			volley_timer -= delta
			if volleys_left > 0 and volley_timer <= 0.0:
				volley_timer = VOLLEY["between"]
				for dir in volley_dirs(volleys_left % 2 == 0):
					spores.append({"pos": anchor + dir * radius * 0.8, "vel": dir * VOLLEY["speed"]})
				volleys_left -= 1
		"spirale":
			spiral_clock -= delta
			var arms: int = PHASES[phase]["arms"]
			spiral_angle += SPIRAL["turn"] * delta
			while spiral_clock <= 0.0:
				spiral_clock += 1.0 / SPIRAL["rate"]
				for i in arms:
					var d := Vector2.from_angle(spiral_angle + TAU * i / arms)
					spores.append({"pos": anchor + d * radius * 0.7, "vel": d * SPIRAL["speed"], "small": true})


## Directions des spores d'une salve (les salves paires sont décalées d'un demi-écart).
func volley_dirs(offset := false) -> Array:
	var n: int = PHASES[phase]["spores"]
	var out: Array = []
	var shift := 0.5 if offset else 0.0
	for i in n:
		out.append(Vector2.from_angle(aim.angle() + (i - (n - 1) / 2.0 + shift) * VOLLEY["spread"]))
	return out


func _wave_radius() -> float:
	return WAVE["radius_p3"] if phase >= 3 else WAVE["radius"]


func _on_line(pos: Vector2, d: Vector2, margin: float) -> bool:
	var to := pos - anchor
	var along := to.dot(d)
	return along > 0.0 and along < MYCELIUM["length"] and absf(to.dot(d.orthogonal())) < MYCELIUM["width"] * 0.5 + margin


func _end_attack() -> void:
	attack = ""
	stage = ""
	gap = PHASES[phase]["gap"]


func _update_spores(delta: float) -> void:
	if spores.is_empty():
		return
	var p = main.player
	var limit: float = arena.radius + 30.0
	var kept: Array = []
	for s in spores:
		s["pos"] += s["vel"] * delta
		var pos: Vector2 = s["pos"]
		var small: bool = s.get("small", false)
		if pos.distance_to(p.position) < VOLLEY["radius"] * (0.8 if small else 1.0) + p.radius and p.invuln <= 0.0:
			p.take_hit((SPIRAL["damage"] if small else VOLLEY["damage"]) * damage_scale, self)
			continue
		if pos.distance_squared_to(arena.center) < limit * limit:
			kept.append(s)
	spores = kept


func _update_clouds(delta: float) -> void:
	if clouds.is_empty():
		return
	var burst := false
	for c in clouds:
		if c["fuse"] > 0.0:
			c["fuse"] -= delta * cadence()
			if c["fuse"] <= 0.0:
				burst = true
				main.fx.ring(c["pos"], 10.0, CLOUD["radius"], 0.3, Color(Art.ec("poison", "clair"), 0.8), 4.0)
		else:
			c["life"] -= delta
	if burst:
		Sfx.play("nuage", anchor)
	clouds = clouds.filter(func(c): return c["fuse"] > 0.0 or c["life"] > 0.0)
	_cloud_tick -= delta
	if _cloud_tick > 0.0:
		return
	_cloud_tick = CLOUD["tick"]
	var p = main.player
	for c in clouds:
		if c["fuse"] <= 0.0 and p.position.distance_to(c["pos"]) < CLOUD["radius"] + p.radius * 0.3:
			p.take_hit(CLOUD["dps"] * CLOUD["tick"] * damage_scale, self)
			break


## Vrai si pos est sur la bande de l'anneau g (hors de sa brèche), à « margin » près.
func _on_ring(g: Dictionary, pos: Vector2, margin: float) -> bool:
	var to := pos - anchor
	if absf(to.length() - g["r"]) > FAIRY["width"] * 0.5 + margin:
		return false
	return absf(wrapf(to.angle() - g["gap"], -PI, PI)) > FAIRY["gap"] * 0.5


func _update_rings(delta: float) -> void:
	if rings.is_empty():
		return
	var p = main.player
	var limit: float = arena.radius + anchor.distance_to(arena.center) + FAIRY["width"]
	var kept: Array = []
	for g in rings:
		g["r"] += FAIRY["speed"] * delta
		if not g["hit"] and _on_ring(g, p.position, p.radius * 0.5) and p.invuln <= 0.0:
			g["hit"] = true
			p.take_hit(FAIRY["damage"] * damage_scale, self)
		if g["r"] < limit:
			kept.append(g)
	rings = kept


func _enter_phase(n: int) -> void:
	phase = n
	transition = PHASE_PAUSE
	cycle = 0
	gap = 0.3
	main.fx.ring(anchor, radius, 420.0, 0.7, Color(Art.ec("poison", "clair"), 0.9), 8.0)
	if n == 3:
		arena.start_shrink()


## Temps avant qu'une attaque annoncée ou en cours touche ce point (INF si rien ne le menace).
func danger_time(pos: Vector2, margin := 26.0) -> float:
	var best := INF
	for c in clouds:
		if pos.distance_to(c["pos"]) < CLOUD["radius"] + margin:
			best = minf(best, maxf(c["fuse"], 0.0))
	for s in spores:
		var v: Vector2 = s["vel"]
		var u := clampf((pos - s["pos"]).dot(v) / v.length_squared(), 0.0, 1.5)
		if (s["pos"] + v * u).distance_to(pos) < VOLLEY["radius"] + margin:
			best = minf(best, u)
	var to := pos - anchor
	var d := to.length()
	match attack:
		"salve":
			var wait := timer if stage == "annonce" else maxf(volley_timer, 0.0)
			for offset in [false, true]:
				for dir in volley_dirs(offset):
					var along := to.dot(dir)
					if along > 0.0 and absf(to.dot(dir.orthogonal())) < VOLLEY["radius"] + margin:
						best = minf(best, wait + along / VOLLEY["speed"])
		"onde":
			if d < _wave_radius() + margin:
				best = minf(best, timer)
		"spirale":
			if d < 260.0:
				best = minf(best, timer if stage == "annonce" else 0.4)
		"mycelium":
			for dir in lines:
				if _on_line(pos, dir, margin):
					best = minf(best, timer)
		"anneaux":
			if stage == "annonce":
				best = minf(best, timer + maxf(0.0, d - radius) / FAIRY["speed"])
	for g in rings:
		var ahead: float = d - g["r"]
		if ahead > -FAIRY["width"] and absf(wrapf(to.angle() - g["gap"], -PI, PI)) > FAIRY["gap"] * 0.5 - margin / maxf(d, 1.0):
			best = minf(best, maxf(0.0, ahead) / FAIRY["speed"])
	if d < radius + margin + 20.0:
		best = minf(best, 0.0)
	return best


func _clear_attacks() -> void:
	attack = ""
	stage = ""
	spores = []
	clouds = []
	buds = []
	lines = []
	rings = []
	ring_gaps = []


## Le robot tourne autour d'elle, hors de l'onde quand elle s'annonce.
func bot_ring(arena_radius: float) -> float:
	var ring := minf(250.0, arena_radius - 60.0)
	if attack == "onde" and arena_radius - 50.0 > _wave_radius() + 40.0:
		ring = _wave_radius() + 45.0
	return ring


# --- Dessin ---
#
# Bestiaire d'herbier (refonte des personnages, B2) : le dessin est dans
# scripts/creature_art/spore/_amanite_mere.gd (vue de trois quarts, encre fine, palette de Spore,
# braise = ennemi), comme les Flétris du marais dont elle est la mère. Ici, la pose seulement :
# gonflement des annonces, recul après l'onde, chapeau soulevé (phase 2), fendu (phase 3),
# affaissement et cendre à la mort, regard tourné vers le joueur visé.

const Art_ = preload("res://scripts/creature_art/spore/_amanite_mere.gd")
const BodyCache = preload("res://scripts/boss_body_cache.gd")
const Exalte = preload("res://scripts/boss_art/exalte.gd")

## Tournée vers la gauche (vers la dernière cible visée).
var face_left := false


## Avancée de l'annonce en cours (0 → 1), 0 hors annonce.
func _announce_k() -> float:
	if stage != "annonce" or stage_time <= 0.0:
		return 0.0
	return clampf(1.0 - timer / stage_time, 0.0, 1.0)


func pose() -> Dictionary:
	var k := _announce_k()
	var die := clampf(dying / death_time, 0.0, 1.0) if dead else 0.0
	if absf(aim.x) > 0.25:
		face_left = aim.x < 0.0
	# Gonflement pendant l'annonce (nuages, onde, spirale), recul juste après l'onde.
	var swell := 1.0 + (0.1 * Anim.ease_out(k) if attack in ["nuages", "onde", "spirale", "anneaux"] else 0.0)
	if strike_flash >= 0.0:
		swell *= 1.0 - 0.12 * (1.0 - strike_flash / WAVE["flash"])
	var lift := (1.0 if phase >= 2 else 0.0) * (1.0 - Anim.ease_out(die)) + 0.7 * Anim.ease_out(k) * float(attack == "spirale")
	# Valeurs quantifiées : le corps est cuit une fois par pose (boss_body_cache.gd).
	return {"t": t, "k": snappedf(k, 0.25) if stage == "annonce" and attack in ["nuages", "onde", "spirale", "invocation", "anneaux"] else 0.0, "attack": attack, "phase": mini(phase, 3),
		"die": snappedf(die, 0.1), "swell": snappedf(swell, 0.02), "lift": snappedf(lift, 0.25),
		"hit": 1.0 if hit_flash > 0.0 else 0.0, "poison": poison_time > 0.0,
		"ash": snappedf(Anim.ease_out(clampf(dying / death_time * 1.4, 0.0, 1.0)), 0.1) if dead else 0.0, "flip": face_left}


var _cache


func _draw() -> void:
	var h := Art_.HEIGHT * radius / 72.0
	if _cache == null:
		_cache = BodyCache.new(self, Rect2(Vector2(-0.95, -1.25) * h, Vector2(1.9, 1.55) * h), func(ci, p): Art_.draw(ci, Vector2.ZERO, h, p))
	# Respiration : le chapeau s'élargit et s'aplatit doucement, autour des pieds.
	var b := sin(t * TAU / 3.2) * (0.0 if dead else 1.0)
	var xf := Transform2D(0.0, Vector2(1.0 + 0.018 * b, 1.0 - 0.018 * b), 0.0, Vector2.ZERO)
	_cache.paint(self, Art_, h, Vector2(0, radius * 0.35), pose(), xf, frozen or BodyCache.headless())
	# Phase exaltée : couronne de flammes d'encre autour du chapeau, qui bat sur les temps.
	var glow := exalt_glow()
	if glow > 0.0:
		Exalte.aura(self, Vector2(0, -h * 0.55), radius, 1.0, (glow - 0.55) / 0.45, t)


## Annonces au sol, en coordonnées monde (grammaire de Art.telegraph). L'invocation, qui ne blesse
## pas, n'est pas en rouge ; les nuages crevés restent bordés de rouge tant qu'ils blessent.
func draw_marks(c: CanvasItem) -> void:
	var k := _announce_k()
	for cl in clouds:
		if cl["fuse"] > 0.0:
			var ck := clampf(1.0 - cl["fuse"] / CLOUD["annonce"], 0.0, 1.0)
			Art.telegraph(c, {"type": "cercle", "centre": cl["pos"], "rayon": CLOUD["radius"]}, ck, -1.0, t)
	match attack:
		"salve":
			if stage == "annonce":
				var n: int = PHASES[phase]["spores"]
				Art.telegraph(c, {"type": "cone", "centre": anchor, "direction": aim.angle(), "ouverture": VOLLEY["spread"] * n, "rayon": 360.0}, k, -1.0, t)
		"onde":
			Art.telegraph(c, {"type": "cercle", "centre": anchor, "rayon": _wave_radius()}, k, -1.0, t)
		"spirale":
			if stage == "annonce":
				var arms: int = PHASES[phase]["arms"]
				for i in arms:
					var d := Vector2.from_angle(spiral_angle + TAU * i / arms)
					Art.telegraph(c, {"type": "ligne", "de": anchor + d * radius * 0.7, "a": anchor + d * 330.0, "largeur": 26.0}, k, -1.0, t)
		"invocation":
			var col := Art.ec("poison", "clair")
			for b in buds:
				c.draw_arc(b, 30.0 - 12.0 * k, 0.0, TAU, 24, Color(col, 0.35 + 0.5 * k), Art.TRAIT, true)
				Art.volume_circle(c, b, 6.0 + 8.0 * k, Art.ec("poison", "sombre").lerp(Art.ec("poison"), k), 0.7)
		"anneaux":
			# La première vague et sa brèche : l'anneau se remplit depuis son pied jusqu'au bord.
			if stage == "annonce" and not ring_gaps.is_empty():
				Art.telegraph(c, _ring_shape(ring_gaps[0], radius * 0.9, _ring_reach()), k, -1.0, t)
		"mycelium":
			for d in lines:
				Art.telegraph(c, {"type": "ligne", "de": anchor + d * radius * 0.6, "a": anchor + d * MYCELIUM["length"], "largeur": MYCELIUM["width"]}, k, -1.0, t)
				# Le sol se fend le long de la ligne.
				var pts := PackedVector2Array()
				for j in 9:
					var u := j / 8.0 * k
					pts.append(anchor + d * (radius * 0.6 + (MYCELIUM["length"] - radius * 0.6) * u) + d.orthogonal() * sin(j * 1.7) * 6.0)
				if pts.size() >= 2:
					c.draw_polyline(pts, Color(Art.ec("poison", "clair"), 0.7), Art.TRAIT, true)
	if strike_flash >= 0.0:
		var f := strike_flash / WAVE["flash"]
		if not lines.is_empty():
			for d in lines:
				Art.telegraph(c, {"type": "ligne", "de": anchor + d * radius * 0.6, "a": anchor + d * MYCELIUM["length"], "largeur": MYCELIUM["width"]}, 1.0, f, t)
		else:
			Art.telegraph(c, {"type": "cercle", "centre": anchor, "rayon": _wave_radius()}, 1.0, f, t)


## Portée des ronds de sorcière : jusqu'au bord de l'arène du côté le plus loin.
func _ring_reach() -> float:
	return minf(arena.radius + anchor.distance_to(arena.center), 420.0)


func _ring_shape(gap_a: float, r0: float, r1: float) -> Dictionary:
	var half: float = FAIRY["gap"] * 0.5
	return {"type": "anneau", "centre": anchor, "interieur": r0, "rayon": r1, "debut": gap_a + half, "fin": gap_a + TAU - half}


## Un rond de sorcière qui s'étend : bande bordée de rouge, chapeaux de champignons qui y poussent,
## rien dans la brèche.
func _draw_ring(c: CanvasItem, g: Dictionary) -> void:
	var r: float = g["r"]
	var w: float = FAIRY["width"]
	var half: float = FAIRY["gap"] * 0.5
	var a0: float = g["gap"] + half
	var a1: float = g["gap"] + TAU - half
	var spore := Art.ec("poison")
	var clair := Art.ec("poison", "clair")
	var shape := _ring_shape(g["gap"], r - w * 0.5, r + w * 0.5)
	c.draw_colored_polygon(Art.telegraph_polygon(shape, 1.0), Color(spore, 0.22))
	var danger := Color(Art.c("danger"), 0.8)
	c.draw_arc(anchor, r + w * 0.5, a0, a1, 64, danger, Art.TRAIT, true)
	c.draw_arc(anchor, r - w * 0.5, a0, a1, 48, Color(danger, 0.45), Art.TRAIT_FIN, true)
	# Chapeaux : un tous les ~28 px, qui sortent en grandissant.
	var grow := clampf((t - float(g["born"])) / 0.25, 0.3, 1.0)
	var n := maxi(6, int((a1 - a0) * r / 28.0))
	var ink := Art.c("contour")
	for i in n:
		var a := lerpf(a0, a1, (i + 0.5) / n)
		var q := anchor + Vector2.from_angle(a) * (r + w * 0.18 * sin(i * 2.3))
		var cap := (6.0 + 2.5 * float(i % 3)) * grow
		c.draw_line(q, q + Vector2(0, -cap * 0.9), ink, 2.4, true)
		var top := q + Vector2(0, -cap * 0.9)
		var dome := Art.ellipse(top, cap, cap * 0.55, 12)
		c.draw_colored_polygon(dome, Art.bc("braise") if i % 5 == 0 else spore)
		Art.outline(c, dome, ink, 1.4)
		c.draw_circle(top + Vector2(-cap * 0.3, -cap * 0.15), cap * 0.18, clair)


## Spores en vol et nuages crevés, au-dessus des personnages, en coordonnées monde.
func draw_overlay(c: CanvasItem) -> void:
	for g in rings:
		_draw_ring(c, g)
	var spore := Art.ec("poison")
	var clair := Art.ec("poison", "clair")
	for cl in clouds:
		if cl["fuse"] > 0.0:
			continue
		var life: float = cl["life"]
		var fade := clampf(life / 0.6, 0.0, 1.0)
		var pos: Vector2 = cl["pos"]
		var rr: float = CLOUD["radius"]
		for i in 7:
			var a := TAU * i / 7.0 + t * 0.3
			var q := pos + Vector2.from_angle(a) * rr * 0.55
			c.draw_circle(q, rr * 0.42, Color(spore.darkened(0.2), 0.22 * fade))
		c.draw_circle(pos, rr * 0.6, Color(spore, 0.2 * fade))
		for i in 4:
			var u := fposmod(t * 0.8 + i / 4.0, 1.0)
			var q := pos + Vector2(sin(i * 2.3 + t) * rr * 0.5, rr * 0.3 - rr * 0.8 * u)
			c.draw_arc(q, 3.0 + 4.0 * u, 0.0, TAU, 10, Color(clair, (1.0 - u) * 0.8 * fade), Art.TRAIT_FIN, true)
		c.draw_arc(pos, rr, 0.0, TAU, 40, Color(Art.c("danger"), 0.45 * fade), Art.TRAIT_FIN, true)
	for s in spores:
		var p: Vector2 = s["pos"]
		var rr: float = VOLLEY["radius"] * (0.8 if s.get("small", false) else 1.0)
		c.draw_circle(p, rr + 2.0, Art.c("contour"))
		Art.volume_circle(c, p, rr, spore, 0.9)
		c.draw_circle(p + Vector2(-rr * 0.25, -rr * 0.25), rr * 0.3, clair)


## L'Amanite-Mère endormie : un gros bouton fermé dans sa volve, tant que le combat n'a pas lieu.
static func draw_sleeper(a: Node2D) -> void:
	Art_.draw_sleeper(a, a.center + Vector2(0, 20.0), Art_.HEIGHT, a.t, a.state == "ouverte")


## Après la victoire : un cercle de fées, amanites saines dans la mousse, à la place de l'Amanite-Mère.
static func draw_victory(a: Node2D) -> void:
	Art_.draw_healed(a, a.center, 1.0, a.t)
