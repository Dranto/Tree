## La Mère-Ronce, boss de la région de Ronce : une rose de cendre enracinée au centre de son arène.
##
## Trois phases (100–66 %, 66–33 %, 33–0 % de sa vie). Chaque attaque est annoncée avant de
## frapper : marque au sol et recul du corps.
##   - volée   : épines en éventail (le corps recule, l'éventail se dessine au sol) ;
##   - fouets  : un ou deux fouets balaient un secteur de l'arène (secteur marqué au sol) ;
##   - racines : des racines jaillissent sous le joueur (cercle qui se fissure) ;
##   - invocation (dès la phase 2) : des bourgeons éclosent en petits Flétris ;
##   - en phase 3, l'arène rétrécit (boss_arena.gd) : plus d'anneau à l'abri des fouets.
##
## Le socle commun (vie, phases, états, mort, interface d'ennemi) est dans boss_base.gd ; ce
## fichier ne décrit que ses attaques et son dessin. Nommée dans data/regions/ronce.json › boss.
extends BossBase

const RADIUS := 70.0
const INTRO := 1.4
const DEATH_TIME := 1.6
## Vie : BASE_HP + HP_PER_LEVEL par niveau du joueur au début du combat.
const BASE_HP := 600.0
const HP_PER_LEVEL := 200.0
## Les dégâts montent de DAMAGE_PER_LEVEL par niveau du joueur.
const DAMAGE_PER_LEVEL := 0.03
const CONTACT_DAMAGE := 16.0
const PHASE_LIMITS := [0.66, 0.33]
## Par phase : pause entre deux attaques, ordre des attaques, et leur ampleur.
const PHASES := {
	1: {"gap": 1.7, "order": ["volee", "racines", "fouets"], "thorns": 7, "volleys": 1, "roots": 3, "whips": 1, "minions": 0},
	2: {"gap": 1.3, "order": ["volee", "invocation", "fouets", "racines"], "thorns": 9, "volleys": 2, "roots": 4, "whips": 2, "minions": 4},
	3: {"gap": 1.0, "order": ["fouets", "volee", "racines", "invocation"], "thorns": 11, "volleys": 3, "roots": 5, "whips": 2, "minions": 5},
}
const VOLLEY := {"annonce": 0.9, "between": 0.35, "damage": 14.0, "speed": 360.0, "radius": 8.0, "spread": 0.2}
const WHIP := {"annonce": 1.1, "frappe": 0.75, "damage": 20.0, "length": 340.0, "width": 22.0}
const ROOT := {"every": 0.45, "fuse": 0.85, "damage": 18.0, "radius": 64.0, "burst": 0.35}
const SUMMON := {"annonce": 1.0, "max_alive": 6}
const PHASE_PAUSE := 1.4
## Enracinée, elle prépare ses attaques plus lentement, puis y résiste un moment.
const ROOTED_CADENCE := 0.55
const ROOT_IMMUNITY := 6.0
const BLEED_STACKS := 5

## Attaque en cours ("" pendant la pause), son étape ("annonce" ou "frappe") et le temps restant.
var attack := ""
var stage := ""
var timer := 0.0
var stage_time := 1.0
var gap := 1.2
var cycle := 0
## Direction visée par l'attaque en cours.
var aim := Vector2.DOWN
var volleys_left := 0
var volley_timer := 0.0
var roots_left := 0
var root_timer := 0.0
## Épines en vol : {"pos", "vel"}.
var thorns: Array = []
## Racines : {"pos", "fuse" (avant de jaillir), "burst" (depuis le jaillissement, -1 avant)}.
var roots: Array = []
## Fouets de l'attaque en cours : {"from", "to", "angle", "prev"} (angles en radians).
var whips: Array = []
## Bourgeons de l'invocation en cours (positions).
var buds: Array = []


## Nombres du socle (boss_base.gd) : ceux de la Mère-Ronce.
func _setup() -> void:
	body_radius = RADIUS
	intro_time = INTRO
	death_time = DEATH_TIME
	base_hp = BASE_HP
	hp_per_level = HP_PER_LEVEL
	damage_per_level = DAMAGE_PER_LEVEL
	contact_damage = CONTACT_DAMAGE
	phase_limits = PHASE_LIMITS
	rooted_cadence = ROOTED_CADENCE
	root_immunity = ROOT_IMMUNITY
	max_bleed_stacks = BLEED_STACKS


func _projectiles_step(delta: float) -> void:
	_update_thorns(delta)
	_update_roots(delta)


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
		_announce_step(delta * cad)
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
		kind = "volee"
	attack = kind
	stage = "annonce"
	Sfx.play("annonce", anchor)
	var to: Vector2 = main.player.position - anchor
	aim = to.normalized() if to.length() > 1.0 else Vector2.DOWN
	match kind:
		"volee":
			_set_timer(VOLLEY["annonce"])
		"fouets":
			_set_timer(WHIP["annonce"])
			_plan_whips(cfg["whips"])
		"racines":
			roots_left = cfg["roots"]
			root_timer = 0.0
			_set_timer(ROOT["every"] * roots_left)
		"invocation":
			_set_timer(SUMMON["annonce"])
			buds = []
			var n: int = cfg["minions"]
			for i in n:
				var a := aim.angle() + PI + (i - (n - 1) / 2.0) * 0.55
				buds.append(anchor + Vector2.from_angle(a) * 170.0)


func _set_timer(v: float) -> void:
	timer = v
	stage_time = v


## Les fouets partent de part et d'autre du joueur et balaient vers lui. Phase 1 : un seul fouet.
## Phase 2 : deux fouets qui se referment sur lui. Phase 3 : deux fouets opposés qui tournent
## dans le même sens et couvrent presque toute l'arène.
func _plan_whips(count: int) -> void:
	whips = []
	var a := aim.angle()
	var side := 1.0 if cycle % 2 == 0 else -1.0
	if count == 1:
		whips.append(_whip(a - side * 1.15, a + side * 1.15))
	elif phase == 2:
		whips.append(_whip(a - 1.9, a - 0.05))
		whips.append(_whip(a + 1.9, a + 0.05))
	else:
		whips.append(_whip(a - side * 1.2, a + side * 1.9))
		whips.append(_whip(a - side * 1.2 + PI, a + side * 1.9 + PI))


func _whip(from: float, to: float) -> Dictionary:
	return {"from": from, "to": to, "angle": from, "prev": from}


## Pendant l'annonce : la volée suit le joueur puis se verrouille ; les racines se posent une à une.
func _announce_step(delta: float) -> void:
	var p = main.player
	match attack:
		"volee":
			if timer > stage_time * 0.4:
				var to: Vector2 = p.position - anchor
				if to.length() > 1.0:
					aim = to.normalized()
		"racines":
			root_timer -= delta
			if roots_left > 0 and root_timer <= 0.0:
				root_timer = ROOT["every"]
				roots_left -= 1
				roots.append({"pos": p.position, "fuse": ROOT["fuse"], "burst": -1.0})


func _strike() -> void:
	stage = "frappe"
	match attack:
		"volee":
			volleys_left = PHASES[phase]["volleys"]
			volley_timer = 0.0
			_set_timer(VOLLEY["between"] * volleys_left)
		"fouets":
			_set_timer(WHIP["frappe"])
		"racines":
			_end_attack()
		"invocation":
			for b in buds:
				minions.append(main.spawn_enemy_at(b, 1))
				main.fx.ring(b, 6.0, 46.0, 0.35, Color(1.0, 0.5, 0.3, 0.8), 3.0)
			buds = []
			_end_attack()


func _strike_step(delta: float) -> void:
	match attack:
		"volee":
			volley_timer -= delta
			if volleys_left > 0 and volley_timer <= 0.0:
				volley_timer = VOLLEY["between"]
				_fire_volley(volleys_left % 2 == 0)
				volleys_left -= 1
		"fouets":
			var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
			# Départ lent, fin rapide : le fouet claque.
			var eased := k * k * (3.0 - 2.0 * k)
			for w in whips:
				w["prev"] = w["angle"]
				w["angle"] = lerpf(w["from"], w["to"], eased)
				_whip_hit(w)


## Directions des épines d'une volée (les salves paires sont décalées d'un demi-écart).
func volley_dirs(offset := false) -> Array:
	var n: int = PHASES[phase]["thorns"]
	var out: Array = []
	var shift := 0.5 if offset else 0.0
	for i in n:
		out.append(Vector2.from_angle(aim.angle() + (i - (n - 1) / 2.0 + shift) * VOLLEY["spread"]))
	return out


func _fire_volley(offset: bool) -> void:
	for dir in volley_dirs(offset):
		thorns.append({"pos": anchor + dir * (radius * 0.8), "vel": dir * VOLLEY["speed"]})


func _whip_hit(w: Dictionary) -> void:
	var p = main.player
	var to: Vector2 = p.position - anchor
	var d := to.length()
	if d > WHIP["length"] + p.radius:
		return
	var span: float = w["angle"] - w["prev"]
	var rel := wrapf(to.angle() - w["prev"], -PI, PI)
	var margin: float = (WHIP["width"] + p.radius) / maxf(d, 1.0)
	var swept := (rel >= -margin and rel <= span + margin) if span >= 0.0 else (rel <= margin and rel >= span - margin)
	if swept:
		p.take_hit(WHIP["damage"] * damage_scale, self)


func _end_attack() -> void:
	attack = ""
	stage = ""
	whips = []
	gap = PHASES[phase]["gap"]


func _update_thorns(delta: float) -> void:
	if thorns.is_empty():
		return
	var p = main.player
	var limit: float = arena.radius + 30.0
	var kept: Array = []
	for th in thorns:
		th["pos"] += th["vel"] * delta
		var pos: Vector2 = th["pos"]
		if pos.distance_to(p.position) < VOLLEY["radius"] + p.radius and p.invuln <= 0.0:
			p.take_hit(VOLLEY["damage"] * damage_scale, self)
			continue
		if pos.distance_squared_to(arena.center) < limit * limit:
			kept.append(th)
	thorns = kept


func _update_roots(delta: float) -> void:
	if roots.is_empty():
		return
	var p = main.player
	var kept: Array = []
	for r in roots:
		if r["burst"] < 0.0:
			r["fuse"] -= delta
			if r["fuse"] <= 0.0:
				r["burst"] = 0.0
				if p.position.distance_to(r["pos"]) < ROOT["radius"] + p.radius * 0.5:
					p.take_hit(ROOT["damage"] * damage_scale, self)
		else:
			r["burst"] += delta
		if r["burst"] < ROOT["burst"]:
			kept.append(r)
	roots = kept


func _enter_phase(n: int) -> void:
	phase = n
	transition = PHASE_PAUSE
	cycle = 0
	gap = 0.3
	main.fx.ring(anchor, radius, 420.0, 0.7, Color(1.0, 0.45, 0.3, 0.9), 8.0)
	if n != 2:
		arena.start_shrink()


## Temps avant qu'une attaque annoncée ou en cours touche ce point (INF si rien ne le menace).
## Sert au robot du mode autotest pour choisir où se tenir.
func danger_time(pos: Vector2, margin := 26.0) -> float:
	var best := INF
	for r in roots:
		if r["burst"] < 0.0 and pos.distance_to(r["pos"]) < ROOT["radius"] + margin:
			best = minf(best, r["fuse"])
	for th in thorns:
		var v: Vector2 = th["vel"]
		var u := clampf((pos - th["pos"]).dot(v) / v.length_squared(), 0.0, 1.5)
		if (th["pos"] + v * u).distance_to(pos) < VOLLEY["radius"] + margin:
			best = minf(best, u)
	var to := pos - anchor
	var d := to.length()
	if attack == "volee":
		var wait := timer if stage == "annonce" else maxf(volley_timer, 0.0)
		for offset in [false, true]:
			for dir in volley_dirs(offset):
				var along := to.dot(dir)
				if along > 0.0 and absf(to.dot(dir.orthogonal())) < VOLLEY["radius"] + margin:
					best = minf(best, wait + along / VOLLEY["speed"])
	if attack == "fouets" and d < WHIP["length"] + margin:
		var m: float = (WHIP["width"] + margin) / maxf(d, 1.0)
		for w in whips:
			var span: float = w["to"] - w["angle"]
			var rel := wrapf(to.angle() - w["angle"], -PI, PI)
			var inside := (rel >= -m and rel <= span + m) if span >= 0.0 else (rel <= m and rel >= span - m)
			if inside:
				var frac := clampf(rel / span, 0.0, 1.0) if absf(span) > 0.001 else 0.0
				best = minf(best, (timer if stage == "annonce" else 0.0) + frac * WHIP["frappe"])
	if d < radius + margin + 20.0:
		best = minf(best, 0.0)
	return best


## À sa mort : plus d'attaque en cours, ni d'épines, de racines, de fouets ou de bourgeons.
func _clear_attacks() -> void:
	attack = ""
	stage = ""
	thorns = []
	roots = []
	whips = []
	buds = []


## Le robot tourne autour d'elle ; tant que l'arène est large, l'anneau extérieur est hors de portée
## des fouets.
func bot_ring(arena_radius: float) -> float:
	var ring := minf(250.0, arena_radius - 60.0)
	if attack == "fouets" and arena_radius - 60.0 > WHIP["length"] + 40.0:
		ring = WHIP["length"] + 50.0
	return ring


# --- Dessin ---
#
# Charte graphique : les Flétris sont anguleux, en volume, contour clair, braise dans les fentes.
# La Mère-Ronce est une rose de cendre : bouton fermé (phase 1), qui s'ouvre (phase 2), puis
# brûle à cœur ouvert (phase 3). Toutes ses attaques s'annoncent avec Art.telegraph.

## Pétale : forme de goutte effilée, de la base vers dir, déchirée au bout en phase 3.
func _petal(base: Vector2, dir: Vector2, length: float, width: float, torn: float) -> PackedVector2Array:
	var n := dir.orthogonal()
	var pts := PackedVector2Array()
	for i in 7:
		var u := i / 6.0
		pts.append(base + dir * length * u + n * width * sin(u * PI * 0.92) * (1.0 - 0.25 * u))
	if torn > 0.0:
		pts.append(base + dir * length * (1.0 - 0.18 * torn) + n * width * 0.12)
	pts.append(base + dir * length * 1.04)
	if torn > 0.0:
		pts.append(base + dir * length * (1.0 - 0.12 * torn) - n * width * 0.1)
	for i in range(6, -1, -1):
		var u := i / 6.0
		pts.append(base + dir * length * u - n * width * sin(u * PI * 0.92) * (1.0 - 0.25 * u))
	return pts


func _draw() -> void:
	var wake := 1.0 - clampf(intro / INTRO, 0.0, 1.0)
	var dk := clampf(dying / DEATH_TIME, 0.0, 1.0) if dead else 0.0
	var s := lerpf(0.3, 1.0, Anim.ease_out(wake)) * (1.0 - 0.2 * Anim.ease_in(dk))
	# Recul avant la volée, élan au tir, tremblement avant les fouets et pendant un changement de phase.
	var shift := Vector2.ZERO
	var crouch := 0.0
	if attack == "volee":
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
		shift = -aim * 22.0 * Anim.ease_out(k) if stage == "annonce" else aim * 12.0 * Anim.flash(k * 3.0)
		crouch = k if stage == "annonce" else 0.0
	elif attack == "fouets" and stage == "annonce":
		shift = Vector2(0, 5.0 * sin(t * 30.0))
	if transition > 0.0:
		shift += Vector2(sin(t * 50.0), cos(t * 43.0)) * 4.0
	var r := radius
	var open: float = [0.0, 0.45, 0.9][phase - 1]
	var rage: float = [0.0, 0.5, 1.0][phase - 1]
	if dead:
		open = lerpf(open, 1.3, Anim.ease_out(dk))
	modulate.a = 1.0 - Anim.ease_in(clampf((dk - 0.55) / 0.45, 0.0, 1.0))
	Art.shadow(self, Vector2(0, r * 0.1), r * 1.45)
	draw_set_transform(shift, 0.0, Vector2(s, s))
	var contour := Art.c("ennemi_contour")
	var body := Art.c("ennemi")

	# Racines maîtresses, étalées au sol, en volume (côté sombre, dos éclairé).
	for i in 9:
		var a := TAU * i / 9.0 + 0.2
		var pts := PackedVector2Array()
		for j in 6:
			var u := j / 5.0
			pts.append(Vector2.from_angle(a + 0.35 * sin(u * 3.0 + i)) * r * (0.6 + 1.5 * u) * Vector2(1.0, 0.7))
		var w := 13.0 - 1.2 * (i % 4)
		draw_polyline(pts, _color(Art.c("contour")), w + 3.0, true)
		draw_polyline(pts, _color(body.darkened(0.45)), w, true)
		draw_polyline(pts, _color(body.darkened(0.2)), w * 0.35, true)
	# Fouets au repos : lianes épineuses qui ondulent (une de plus à chaque phase).
	var vines := 2 + phase
	for i in vines:
		var a := TAU * (i + 0.5) / vines + 0.25 * sin(t * 0.9 + i * 1.7)
		var pts := PackedVector2Array()
		for j in 9:
			var u := j / 8.0
			var sway := 0.5 * sin(t * (1.6 + rage) + u * 4.0 + i * 2.0) * u
			pts.append(Vector2.from_angle(a + sway) * r * (0.8 + 1.6 * u) + Vector2(0, -r * 0.5 * sin(u * PI)))
		_vine(self, pts, 8.0, 1.0)
	var lift := Vector2(0, -r * 0.5) + Vector2(0, r * 0.08 * crouch)
	# Sépales épineux derrière la corolle, en volume.
	for i in 12:
		var a := TAU * i / 12.0 + 0.05 * sin(t * 2.0 + i)
		var dir := Vector2.from_angle(a)
		var base := lift + dir * r * 0.85
		var tip := lift + dir * r * (1.55 + 0.25 * rage)
		var side := dir.orthogonal() * r * 0.2
		draw_colored_polygon(PackedVector2Array([base + side, tip, base]), _color(body.darkened(0.35)))
		draw_colored_polygon(PackedVector2Array([base, tip, base - side]), _color(body.darkened(0.6)))
	# Corolle : deux couronnes de pétales de rose fanée, qui s'écartent et rougissent à chaque phase.
	var petal_far := body.lerp(Art.ec("saignement"), 0.35 + 0.3 * rage)
	var petal_near := body.lerp(Art.ec("saignement", "clair"), 0.15 + 0.45 * rage)
	for ring in 2:
		var n := 9 - ring * 3
		for i in n:
			var a := TAU * (i + 0.5 * ring) / n + 0.04 * sin(t * 1.5 + i * 1.3)
			var dir := Vector2.from_angle(a)
			var length: float = r * (1.25 - 0.4 * ring) * (1.0 + 0.22 * open)
			var width: float = r * (0.5 - 0.12 * ring) * (1.0 - 0.25 * open)
			var base: Vector2 = lift + dir * r * 0.22 * open
			if dead:
				# Les pétales se détachent et tombent en tournoyant.
				var fall := Anim.ease_in(clampf(dk * 1.3 - i * 0.03, 0.0, 1.0))
				base += dir * r * 0.8 * fall + Vector2(0, r * 0.5 * fall)
				dir = dir.rotated(fall * (1.5 if i % 2 else -1.5))
			var pts := _petal(base, dir, length, width, rage if ring == 0 else 0.0)
			Art.volume(self, pts, _color(petal_far if ring == 0 else petal_near), 0.8)
			Art.outline(self, pts, Color(_color(contour), 0.55 if ring == 0 else 0.8), Art.TRAIT_FIN)
			# Nervure.
			draw_line(base + dir * length * 0.15, base + dir * length * 0.75, _color((petal_far if ring == 0 else petal_near).darkened(0.35)), 1.5, true)
	# Bulbe central, fendu de braise.
	var bulb := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		bulb.append(lift + Vector2.from_angle(a) * r * (0.6 + 0.08 * open) * (1.0 + 0.06 * sin(a * 5.0 + t * 3.0)))
	Art.volume(self, bulb, _color(body.darkened(0.2).lerp(Art.ec("cendre", "sombre"), rage * 0.5)))
	var ember := Art.ec("cendre")
	var pulse := 0.5 + 0.5 * sin(t * (3.0 + 4.0 * rage))
	var fade := 1.0 - dk
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p0 := lift + Vector2.from_angle(a) * r * 0.2
		var p1 := lift + Vector2.from_angle(a + 0.25) * r * 0.42
		var p2 := lift + Vector2.from_angle(a - 0.1) * r * 0.58
		draw_polyline(PackedVector2Array([p0, p1, p2]), _color(Art.c("contour")), 4.0, true)
		draw_polyline(PackedVector2Array([p0, p1, p2]), Color(ember, (0.35 + 0.55 * rage) * (0.7 + 0.3 * pulse) * fade), 2.0, true)
	Art.outline(self, bulb, _color(contour), Art.TRAIT)
	# Cœur de braise, de plus en plus à nu ; il s'éteint à la mort.
	var core := r * (0.16 + 0.14 * open)
	if dead:
		core *= 1.0 + 0.6 * Anim.flash(dk * 3.0)
	draw_circle(lift, core * 2.1, Color(ember, (0.15 + 0.2 * pulse) * fade))
	draw_circle(lift, core * 1.45, Color(ember, (0.3 + 0.2 * pulse) * fade))
	Art.volume_circle(self, lift, core, _color(ember.lerp(Art.ec("cendre", "clair"), pulse * (0.3 + 0.7 * rage))), 0.9)
	# Trois yeux fendus tournés vers le joueur, plus vifs pendant une annonce.
	var look: Vector2 = (main.player.position - anchor).normalized() if main and main.player else Vector2.DOWN
	var glare := 0.35 + (0.5 if stage == "annonce" else 0.0)
	for i in 3:
		var eye := lift + look * r * 0.4 + look.orthogonal() * r * 0.22 * (i - 1) - look * r * 0.06 * absf(i - 1)
		var xf := Transform2D(look.angle(), Vector2(r, r), 0.0, eye)
		FletriArt._slit(self, xf, Vector2.ZERO, 0.075, 1 if i == 2 else -1, glare, {"ash": dk})
	# Phase 3 et mort : des braises s'échappent de la corolle.
	var embers := 0 if phase < 3 and not dead else 8
	for i in embers:
		var u := fposmod(t * 0.7 + i / 8.0, 1.0)
		var q := lift + Vector2(sin(i * 2.4 + t) * r * 0.9, -r * (0.3 + 1.6 * u))
		FletriArt._flake(self, q, 3.5 * (1.0 - 0.5 * u), Color(Art.ec("cendre", "clair") if i % 2 else FletriArt.ash_color(), 1.0 - u))
	# États visibles : motifs des éléments (charte, § 3).
	if statuses.has("saignement"):
		Art.status(self, "saignement", lift, r * 0.7, t * 1.25)
		for i in int(statuses["saignement"]["stacks"]):
			Art._drop(self, lift + Vector2(-r * 0.5 + i * r * 0.25, -r * 1.05), 4.5, Art.ec("saignement", "clair"))
	if statuses.has("enracine"):
		Art.status(self, "racine", lift + Vector2(0, r * 0.2), r * 0.9, t)
	if poison_time > 0.0:
		Art.status(self, "poison", lift, r * 0.7, t)
	# Mort : la vie reprend au cœur de la rose.
	if dead and dk > 0.45:
		var g := Anim.ease_out((dk - 0.45) / 0.55)
		Art.glow(self, lift, r * 0.9 * g, "seve")
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Liane épineuse (fouet) : contour sombre, corps, épines d'os en volume. thorns : densité (0 → 1).
func _vine(c: CanvasItem, pts: PackedVector2Array, width: float, thorns: float) -> void:
	c.draw_polyline(pts, _color(Art.c("contour")), width + 3.0, true)
	c.draw_polyline(pts, _color(Art.c("ennemi").darkened(0.3)), width, true)
	c.draw_polyline(pts, _color(Art.c("ennemi").lightened(0.1)), width * 0.3, true)
	if thorns <= 0.0:
		return
	var bone := _color(Art.ec("epine", "clair").darkened(0.15))
	for j in range(2, pts.size(), 2):
		var d: Vector2 = (pts[j] - pts[j - 1]).normalized()
		var n := d.orthogonal() * (1.0 if j % 4 == 0 else -1.0)
		var b: Vector2 = pts[j] + n * width * 0.4
		var tip: Vector2 = b + (n - d * 0.5).normalized() * width * 1.3
		var side := (tip - b).orthogonal() * 0.25
		c.draw_colored_polygon(PackedVector2Array([b + side, tip, b]), bone.lightened(0.15))
		c.draw_colored_polygon(PackedVector2Array([b, tip, b - side]), bone.darkened(0.3))


## Annonces au sol, en coordonnées monde : toujours la grammaire de Art.telegraph. Pour que l'écran
## reste lisible, l'invocation (qui ne blesse pas) n'est pas en rouge, et une seule forme par attaque.
func draw_marks(c: CanvasItem) -> void:
	if dead:
		return
	if attack == "volee":
		var n: int = PHASES[phase]["thorns"]
		var reach: float = arena.radius + anchor.distance_to(arena.center)
		var cone := {"type": "cone", "centre": anchor, "direction": aim.angle(), "ouverture": (n - 1) * VOLLEY["spread"] + 0.14, "rayon": reach}
		if stage == "annonce":
			var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
			Art.telegraph(c, cone, k, -1.0, t)
			# Les trajectoires des épines, en traits fins dans l'éventail.
			for dir in volley_dirs():
				c.draw_line(anchor + dir * radius, anchor + dir * reach, Color(Art.c("danger"), 0.25 + 0.3 * k), 1.5, true)
		else:
			var since: float = stage_time - timer
			if since < 0.3:
				Art.telegraph(c, cone, 1.0, since / 0.3, t)
	if attack == "fouets":
		for w in whips:
			var a0: float = w["from"]
			var a1: float = w["to"]
			var sector := {"type": "cone", "centre": anchor, "direction": (a0 + a1) / 2.0, "ouverture": absf(a1 - a0), "rayon": WHIP["length"]}
			if stage == "annonce":
				var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
				Art.telegraph(c, sector, k, -1.0, t)
			else:
				# Pendant le balayage : la part balayée a frappé (éclair), le reste reste menacé.
				var cur: float = w["angle"]
				var done := {"type": "cone", "centre": anchor, "direction": (a0 + cur) / 2.0, "ouverture": absf(cur - a0), "rayon": WHIP["length"]}
				var left := {"type": "cone", "centre": anchor, "direction": (cur + a1) / 2.0, "ouverture": absf(a1 - cur), "rayon": WHIP["length"]}
				var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
				if absf(a1 - cur) > 0.02:
					Art.telegraph(c, left, 1.0, -1.0, t)
				if absf(cur - a0) > 0.02:
					Art.telegraph(c, done, 1.0, k, t)
			# Le sens du balayage : bord de départ et chevrons clairs.
			var sgn := signf(a1 - a0)
			var col := Color(Art.c("danger_eclair"), 0.8)
			c.draw_line(anchor, anchor + Vector2.from_angle(a0) * WHIP["length"], col, Art.TRAIT, true)
			if stage == "annonce":
				for i in 4:
					var a := lerpf(a0, a1, (i + 0.5 + fmod(t * 1.5, 1.0) * 0.5) / 4.5)
					var mid: Vector2 = anchor + Vector2.from_angle(a) * WHIP["length"] * 0.72
					var tang := Vector2.from_angle(a + sgn * PI / 2.0)
					var out := Vector2.from_angle(a)
					c.draw_polyline(PackedVector2Array([mid - tang * 10.0 + out * 12.0, mid + tang * 8.0, mid - tang * 10.0 - out * 12.0]), Color(col, 0.6), Art.TRAIT, true)
	for r in roots:
		var forme := {"type": "cercle", "centre": r["pos"], "rayon": ROOT["radius"]}
		if r["burst"] < 0.0:
			var k := 1.0 - clampf(r["fuse"] / ROOT["fuse"], 0.0, 1.0)
			Art.telegraph(c, forme, k, -1.0, t)
			# Le sol se fissure là où la racine va jaillir.
			var pos: Vector2 = r["pos"]
			for i in 5:
				var a := TAU * i / 5.0 + pos.x * 0.01
				c.draw_line(pos + Vector2.from_angle(a) * 6.0, pos + Vector2.from_angle(a + 0.3) * ROOT["radius"] * (0.25 + 0.6 * k), Color(Art.c("contour"), 0.85), 3.0, true)
		else:
			Art.telegraph(c, forme, 1.0, clampf(r["burst"] / ROOT["burst"], 0.0, 1.0), t)
	# Invocation : des boutons de rose sortent du sol et enflent (pas un coup : couleur de cendre).
	for b in buds:
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
		var e := Art.ec("cendre")
		c.draw_arc(b, 30.0, 0.0, TAU, 28, Color(e, 0.25 + 0.4 * k), Art.TRAIT, true)
		c.draw_circle(b, 30.0 * k, Color(e, 0.1))
		var size := 6.0 + 12.0 * Anim.ease_out(k)
		for i in 4:
			var a := TAU * i / 4.0 + 0.4 + k
			var pts := _petal(b, Vector2.from_angle(a), size, size * 0.6, 0.0)
			Art.volume(c, pts, Art.c("ennemi").lerp(Art.ec("saignement"), 0.4), 0.7)
		c.draw_circle(b, 3.0 + 4.0 * k, Art.ec("cendre", "clair"))


## Projectiles et coups, au-dessus des personnages, en coordonnées monde.
func draw_overlay(c: CanvasItem) -> void:
	for th in thorns:
		var pos: Vector2 = th["pos"]
		var dir: Vector2 = (th["vel"] as Vector2).normalized()
		var n := dir.orthogonal()
		c.draw_line(pos - dir * 30.0, pos - dir * 6.0, Color(Art.c("danger"), 0.35), 6.0, true)
		var tip := pos + dir * 15.0
		var back := pos - dir * 9.0
		c.draw_colored_polygon(PackedVector2Array([back + n * 5.5, tip, back]), Art.ec("epine", "clair"))
		c.draw_colored_polygon(PackedVector2Array([back, tip, back - n * 5.5]), Art.ec("epine").darkened(0.2))
		Art.outline(c, PackedVector2Array([back + n * 5.5, tip, back - n * 5.5]), Art.ec("epine", "sombre"), 1.2)
		c.draw_circle(back, 2.5, Art.ec("cendre"))
	if attack == "fouets":
		for w in whips:
			var a: float = w["angle"]
			var raised := stage == "annonce"
			var reach: float = WHIP["length"] * (0.45 if raised else 1.0)
			var pts := PackedVector2Array()
			for i in 13:
				var u := i / 12.0
				# Le fouet traîne derrière sa pointe pendant le balayage.
				var lag := 0.0 if raised else -0.25 * signf(w["to"] - w["from"]) * (1.0 - u) * u * 4.0
				var wave := 0.12 * sin(t * 14.0 + u * 6.0) * u if raised else 0.0
				pts.append(anchor + Vector2.from_angle(a + lag + wave) * (radius * 0.6 + reach * u) + Vector2(0, -24.0 * sin(u * PI)))
			_vine(c, pts, WHIP["width"] * 0.55, 1.0)
			# Une griffe d'os au bout.
			var d: Vector2 = (pts[12] - pts[11]).normalized()
			var tip: Vector2 = pts[12] + d * 18.0
			var side := d.orthogonal() * 7.0
			c.draw_colored_polygon(PackedVector2Array([pts[12] + side, tip, pts[12] - side]), Art.ec("epine", "clair"))
	for r in roots:
		if r["burst"] >= 0.0:
			var pos: Vector2 = r["pos"]
			var k := clampf(r["burst"] / ROOT["burst"], 0.0, 1.0)
			var rise := maxf(0.08, sin(k * PI))
			for i in 6:
				var a := TAU * i / 6.0 + pos.y * 0.01
				var foot := pos + Vector2.from_angle(a) * ROOT["radius"] * 0.5 * Vector2(1.0, 0.6)
				var tip := foot + Vector2(cos(a) * 14.0, -70.0 * rise)
				var body := Art.c("ennemi").darkened(0.3)
				c.draw_colored_polygon(PackedVector2Array([foot + Vector2(-10, 0), tip, foot]), body.lightened(0.15))
				c.draw_colored_polygon(PackedVector2Array([foot, tip, foot + Vector2(10, 0)]), body.darkened(0.35))
				Art.outline(c, PackedVector2Array([foot + Vector2(-10, 0), tip, foot + Vector2(10, 0)]), Art.c("ennemi_contour"), Art.TRAIT_FIN)
				c.draw_circle(tip, 2.5, Art.ec("epine", "clair"))


# --- Dessinés par l'arène (boss_arena.gd), coordonnées de l'arène ---

## La Mère-Ronce endormie : un bouton fermé au centre de l'arène, tant que le combat n'a pas lieu.
static func draw_sleeper(a: Node2D) -> void:
	var r := RADIUS * 0.75
	var c: Vector2 = a.center + Vector2(0, -r * 0.4)
	for i in 9:
		var ang := TAU * i / 9.0 + 0.2
		a.draw_line(a.center, a.center + Vector2.from_angle(ang) * r * 1.9 * Vector2(1.0, 0.7), Color("1c1418"), 9.0)
	for i in 8:
		var ang := TAU * i / 8.0
		var dir := Vector2.from_angle(ang)
		var side := dir.orthogonal() * r * 0.4
		a.draw_colored_polygon(PackedVector2Array([c, c + dir * r * 0.6 + side, c + dir * r * 1.05, c + dir * r * 0.6 - side]), Color("3a2630") if i % 2 == 0 else Color("4a2a36"))
	a.draw_circle(c, r * 0.45, Color("2a1c22"))
	if a.state == "ouverte":
		a.draw_circle(c, r * 0.2, Color(1.0, 0.6, 0.3, 0.45 + 0.35 * sin(a.t * 2.0)))


## Après la victoire : un grand rosier en fleurs à la place de la Mère-Ronce.
static func draw_victory(a: Node2D) -> void:
	var r := RADIUS
	var c: Vector2 = a.center + Vector2(0, -r * 0.4)
	for i in 7:
		var ang := TAU * i / 7.0
		a.draw_circle(c + Vector2.from_angle(ang) * r * 0.55, r * 0.5, Color("2f6b2a") if i % 2 == 0 else Color("3b7d31"))
	a.draw_circle(c, r * 0.6, Color("468f38"))
	for i in 9:
		var ang := TAU * i / 9.0 + 0.4
		var rose := c + Vector2.from_angle(ang) * r * (0.35 + 0.5 * (i % 3) / 2.0)
		for j in 5:
			a.draw_circle(rose + Vector2.from_angle(TAU * j / 5.0 + i) * 7.0, 6.5, Color("e0675e") if i % 2 == 0 else Color("f48fb1"))
		a.draw_circle(rose, 4.0, Color("fff3c4"))
