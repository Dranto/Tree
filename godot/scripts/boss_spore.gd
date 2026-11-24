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
	3: {"gap": 0.9, "order": ["mycelium", "nuages", "spirale", "onde", "invocation", "salve"], "clouds": 5, "volleys": 3, "spores": 9, "arms": 3, "minions": 4, "lines": 3},
}
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
			var order: Array = PHASES[phase]["order"]
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
				clouds.append({"pos": at, "fuse": CLOUD["annonce"], "life": CLOUD["life"] + (0.8 if phase == 3 else 0.0)})
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
	return WAVE["radius_p3"] if phase == 3 else WAVE["radius"]


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


func _enter_phase(n: int) -> void:
	phase = n
	transition = PHASE_PAUSE
	cycle = 0
	gap = 0.3
	main.fx.ring(anchor, radius, 420.0, 0.7, Color(Art.ec("poison", "clair"), 0.9), 8.0)
	if n != 2:
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


## Le robot tourne autour d'elle, hors de l'onde quand elle s'annonce.
func bot_ring(arena_radius: float) -> float:
	var ring := minf(250.0, arena_radius - 60.0)
	if attack == "onde" and arena_radius - 50.0 > _wave_radius() + 40.0:
		ring = _wave_radius() + 45.0
	return ring


# --- Dessin ---
#
# Charte : les Flétris sont sombres et saturés, contour clair, braise dans les fentes. L'Amanite-Mère
# est un chapeau de vin et de violet (ennemi, nuancé de poison) couvert de verrues pâles, sur un pied
# à collerette planté dans une volve. Phase 2 : le chapeau se soulève et montre ses lamelles qui
# luisent. Phase 3 : il se fend, la braise couve dans les fentes, le mycélium sort de terre.

func _cap_color() -> Color:
	return Art.c("ennemi").lerp(Art.ec("poison", "sombre"), 0.35)


## Avancée de l'annonce en cours (0 → 1), 0 hors annonce.
func _announce_k() -> float:
	if stage != "annonce" or stage_time <= 0.0:
		return 0.0
	return clampf(1.0 - timer / stage_time, 0.0, 1.0)


func _draw() -> void:
	var r := radius
	var k := _announce_k()
	var die := clampf(dying / death_time, 0.0, 1.0) if dead else 0.0
	var b := Anim.breathe(t, 0.025)
	# Gonflement pendant l'annonce (nuages, onde), recul juste après l'onde.
	var swell := 1.0 + (0.1 * Anim.ease_out(k) if attack in ["nuages", "onde", "spirale"] else 0.0)
	if strike_flash >= 0.0:
		swell *= 1.0 - 0.12 * (1.0 - strike_flash / WAVE["flash"])
	# Mort : le chapeau s'affaisse et s'étale.
	var sag := Anim.ease_out(die)
	var cap_c := Vector2(0, -r * (0.95 - 0.6 * sag))
	var rx := r * 1.18 * swell * b * (1.0 + 0.15 * sag)
	var ry := r * 0.64 * swell * (2.0 - b) * (1.0 - 0.45 * sag)
	var lift := (0.18 if phase >= 2 else 0.0) * (1.0 - sag) + 0.12 * k * float(attack == "spirale")
	Art.shadow(self, Vector2(0, r * 0.08), r * 0.95)
	# Mycélium au pied (phase 3) : filaments clairs qui rampent sur le sol.
	if phase >= 3 and not dead:
		var fil := Color(Art.ec("poison", "clair"), 0.55)
		for i in 9:
			var a := TAU * i / 9.0 + 0.2
			var pts := PackedVector2Array()
			for j in 6:
				var u := j / 5.0
				pts.append(Vector2.from_angle(a + 0.25 * sin(u * 4.0 + t + i)) * r * (0.5 + 0.9 * u) + Vector2(0, r * 0.2))
			draw_polyline(pts, fil, Art.TRAIT_FIN, true)
	# Volve : la coupe déchirée d'où sort le pied.
	var volve := PackedVector2Array()
	for i in 14:
		var a := PI * i / 13.0
		var jag := 1.0 if i % 2 == 0 else 0.82
		volve.append(Vector2(cos(a) * r * 0.62 * jag, r * 0.12 + sin(a) * r * 0.3 * jag))
	volve.append(Vector2(-r * 0.62, r * 0.05))
	volve.append(Vector2(r * 0.62, r * 0.05))
	Art.volume(self, volve, _color(Art.c("ennemi").darkened(0.25)), 0.5)
	# Pied et collerette.
	var stem := PackedVector2Array([Vector2(-r * 0.3, r * 0.18), Vector2(-r * 0.24, cap_c.y), Vector2(r * 0.24, cap_c.y), Vector2(r * 0.3, r * 0.18)])
	Art.volume(self, stem, _color(Art.c("ennemi_contour").darkened(0.45).lerp(Art.ec("poison", "sombre"), 0.25)), 0.7)
	var skirt := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		skirt.append(Vector2(cos(a) * r * 0.42, cap_c.y + ry + r * 0.04 + sin(a) * r * (0.18 + 0.05 * (i % 2))))
	Art.volume(self, skirt, _color(Art.c("ennemi_contour").darkened(0.3)), 0.6)
	# Yeux de braise sur le pied (la marque des Flétris).
	for sgn in [-1, 1]:
		var e := Vector2(sgn * r * 0.11, cap_c.y + ry + r * 0.32)
		var glow := 0.4 + 0.6 * k
		draw_circle(e, r * 0.07, Color(Art.c("ennemi_oeil"), 0.35 * glow * (1.0 - die)))
		draw_line(e + Vector2(-r * 0.06, -sgn * r * 0.02), e + Vector2(r * 0.06, sgn * r * 0.02), Color(Art.c("ennemi_oeil"), 1.0 - die), 2.5, true)
	# Lamelles (dessous du chapeau), visibles quand il se soulève : elles luisent de spores.
	if lift > 0.0:
		var gills := Art.ellipse(cap_c + Vector2(0, ry * 0.35), rx * 0.92, ry * (0.35 + lift), 28)
		draw_colored_polygon(gills, _color(Art.ec("poison", "sombre").darkened(0.2)))
		for i in 12:
			var a := PI * (i + 0.5) / 12.0
			var q := cap_c + Vector2(0, ry * 0.35) + Vector2(cos(a) * rx * 0.88, sin(a) * ry * (0.33 + lift))
			draw_line(cap_c + Vector2(0, ry * 0.35), q, Color(Art.ec("poison", "clair"), (0.25 + 0.5 * k) * (1.0 - die)), Art.TRAIT_FIN, true)
	# Le chapeau : dôme en volume, contour clair des Flétris.
	var cap := Art.ellipse(cap_c - Vector2(0, lift * r * 0.4), rx, ry, 36)
	if phase >= 3:
		# Fendu : deux encoches dans le bord.
		for notch in [0.6, 2.4]:
			var idx := int(notch / TAU * cap.size())
			cap[idx] = cap[idx].lerp(cap_c, 0.32)
	# Bord du chapeau vu de trois quarts : une bande sombre sous le dôme, qui le fait lire en relief.
	var rim := Art.ellipse(cap_c + Vector2(0, ry * 0.32 - lift * r * 0.4), rx * 0.97, ry * 0.72, 32)
	draw_colored_polygon(rim, _color(_cap_color().darkened(0.5)))
	draw_colored_polygon(cap, Color(Art.c("contour"), 0.6))
	Art.volume(self, cap, _color(_cap_color()), 0.8)
	Art.outline(self, cap, Color(Art.c("ennemi_contour"), 1.0 - die * 0.8), Art.TRAIT_FORT)
	# Verrues pâles, en volume.
	var wart := _color(Art.ec("epine", "clair").lerp(Art.c("ennemi_contour"), 0.3))
	for w in [[-0.45, -0.25, 0.13], [0.1, -0.45, 0.11], [0.5, -0.15, 0.12], [-0.15, 0.1, 0.1], [0.32, 0.25, 0.08], [-0.6, 0.18, 0.08], [0.0, -0.1, 0.07]]:
		var p: Vector2 = cap_c - Vector2(0, lift * r * 0.4) + Vector2(w[0] * rx, w[1] * ry)
		Art.volume_circle(self, p, r * w[2] * (1.0 - 0.4 * sag), wart, 0.6)
	# Fentes de braise (phase 3).
	if phase >= 3:
		var ember := Color(Art.ec("cendre"), (0.6 + 0.3 * sin(t * 5.0)) * (1.0 - die))
		var c0 := cap_c - Vector2(0, lift * r * 0.4)
		draw_polyline(PackedVector2Array([c0 + Vector2(-rx * 0.1, -ry * 0.1), c0 + Vector2(-rx * 0.4, -ry * 0.45), c0 + Vector2(-rx * 0.55, -ry * 0.4)]), ember, 3.0, true)
		draw_polyline(PackedVector2Array([c0 + Vector2(rx * 0.05, ry * 0.05), c0 + Vector2(rx * 0.45, ry * 0.3), c0 + Vector2(rx * 0.7, ry * 0.2)]), ember, 3.0, true)
	# Pores qui fument pendant l'annonce des nuages.
	if attack == "nuages" and stage == "annonce":
		for i in 5:
			var u := fposmod(t * 1.5 + i / 5.0, 1.0)
			var q := cap_c + Vector2((i - 2) * rx * 0.3, -ry * (0.6 + 0.9 * u))
			draw_circle(q, r * (0.06 + 0.12 * u), Color(Art.ec("poison", "clair"), 0.6 * (1.0 - u)))
	# Mort : les spores s'échappent en bouffées qui montent et pâlissent.
	if dead:
		for i in 10:
			var a := TAU * i / 10.0 + 0.3
			var u := clampf(die * 1.3 - (i % 3) * 0.12, 0.0, 1.0)
			if u <= 0.0 or u >= 1.0:
				continue
			var q := cap_c + Vector2.from_angle(a) * rx * (0.4 + 0.9 * u) - Vector2(0, r * 0.8 * u)
			draw_circle(q, r * (0.1 + 0.18 * u), Color(Art.ec("poison", "clair").lerp(Art.ec("seve", "clair"), u), 0.55 * (1.0 - u)))


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


## Spores en vol et nuages crevés, au-dessus des personnages, en coordonnées monde.
func draw_overlay(c: CanvasItem) -> void:
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
	var c: Vector2 = a.center
	var r := 46.0
	Art.shadow(a, c + Vector2(0, r * 0.4), r * 1.1)
	var cap := Art.c("ennemi").lerp(Art.ec("poison", "sombre"), 0.35).darkened(0.3)
	var egg := Art.ellipse(c - Vector2(0, r * 0.15), r * 0.8, r, 24)
	Art.volume(a, egg, cap, 0.6)
	Art.outline(a, egg, Color(Art.c("ennemi_contour"), 0.6), Art.TRAIT)
	for w in [[-0.3, -0.5], [0.25, -0.3], [-0.05, 0.1], [0.35, 0.3]]:
		Art.volume_circle(a, c + Vector2(w[0], w[1]) * r, r * 0.1, Art.ec("epine", "clair").darkened(0.35), 0.5)
	if a.state == "ouverte":
		var pulse := 0.45 + 0.35 * sin(a.t * 2.0)
		a.draw_circle(c, r * 0.3, Color(Art.ec("poison"), pulse * 0.6))


## Après la victoire : un cercle de champignons clairs dans la mousse, à la place de l'Amanite-Mère.
static func draw_victory(a: Node2D) -> void:
	var c: Vector2 = a.center
	a.draw_circle(c, 70.0, Color(Art.c("decor_vivant"), 0.55))
	a.draw_circle(c + Vector2(-10, -8), 46.0, Color(Art.c("decor_vivant").lightened(0.1), 0.5))
	for i in 9:
		var ang := TAU * i / 9.0 + 0.2
		var p := c + Vector2(cos(ang), sin(ang) * 0.75) * 58.0
		var s := 8.0 + 3.0 * (i % 3)
		a.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.18, 0), p + Vector2(-s * 0.14, -s * 1.1), p + Vector2(s * 0.14, -s * 1.1), p + Vector2(s * 0.18, 0)]), Art.c("interactif").darkened(0.3))
		var dome := PackedVector2Array()
		for j in 9:
			var u := PI + PI * j / 8.0
			dome.append(p + Vector2(0, -s * 1.1) + Vector2(cos(u) * s * 0.75, sin(u) * s * 0.55))
		Art.volume(a, dome, Art.c("interactif").darkened(0.12) if i % 2 else Art.ec("seve", "sombre").lightened(0.3), 0.6)
	Art.glow(a, c, 36.0, "seve")
	a.draw_circle(c, 9.0, Art.ec("seve", "clair"))
