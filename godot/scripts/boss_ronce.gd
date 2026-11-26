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

const Mere = preload("res://scripts/creature_art/ronce/_mere_ronce.gd")
const O = preload("res://scripts/creature_art/ronce/_outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const BossBake = preload("res://scripts/boss_bake.gd")

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
# « Bestiaire d'herbier » (refonte des personnages, vague 2 B1) : la Mère-Ronce est la souche-mère des
# Flétris de Ronce (scripts/creature_art/ronce/_mere_ronce.gd) : une galle-mère couleur de mûre sur
# quatre pattes d'insecte épineuses, cerclée de grandes tiges arquées, couronnée d'une rose de cendre
# en bouton (phase 1), qui s'ouvre (phase 2), puis brûle à cœur ouvert (phase 3). Vue de trois quarts,
# tournée vers le joueur. Son corps et le sol sont cuits en sprites (boss_bake.gd) ; les lianes au
# repos, les yeux de braise et les braises sont dessinés en direct. Les annonces au sol (draw_marks)
# gardent la grammaire de Art.telegraph.

## Pieds du dessin sous le centre du boss (fraction de son rayon) : le corps se pose sur son ombre.
const FEET := 0.3

## Côté vers lequel elle regarde (1 : droite), avec une marge pour ne pas se retourner sans cesse.
var facing := 1.0
var _life: Node2D


func _ready() -> void:
	super._ready()
	use_tint_material()
	# Ce qui ne prend ni la cendre ni l'éclair : la vie qui reprend à sa mort, les états.
	_life = Layer2.new()
	_life.boss = self
	add_child(_life)


class Layer2 extends Node2D:
	var boss

	func _draw() -> void:
		boss.draw_life(self)


func redraw() -> void:
	super.redraw()
	if _life != null:
		_life.queue_redraw()


## Repère du dessin (pixels du jeu, pieds à l'origine) : entrée en scène, recul, retournement.
func _body_xf() -> Transform2D:
	var wake := 1.0 - clampf(intro / INTRO, 0.0, 1.0)
	var dk := clampf(dying / DEATH_TIME, 0.0, 1.0) if dead else 0.0
	var s := lerpf(0.3, 1.0, Anim.ease_out(wake)) * (1.0 - 0.1 * Anim.ease_in(dk))
	# Recul avant la volée (elle se tasse), élan au tir, tremblement avant les fouets et pendant un
	# changement de phase.
	var shift := Vector2.ZERO
	var crouch := 0.0
	if attack == "volee":
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
		shift = -aim * 22.0 * Anim.ease_out(k) if stage == "annonce" else aim * 12.0 * Anim.flash(k * 3.0)
		crouch = k if stage == "annonce" else 0.0
	elif attack == "fouets" and stage == "annonce":
		shift = Vector2(4.0 * sin(t * 30.0), 0)
	if transition > 0.0:
		shift += Vector2(sin(t * 50.0), cos(t * 43.0)) * 4.0
	var sq := Vector2(1.0 + 0.06 * crouch, 1.0 - 0.1 * crouch)
	return Transform2D(0.0, Vector2(s * facing * sq.x, s * sq.y), 0.0, Vector2(0, radius * FEET) + shift)


func _draw() -> void:
	update_tint()
	var dk := clampf(dying / DEATH_TIME, 0.0, 1.0) if dead else 0.0
	modulate.a = 1.0 - Anim.ease_in(clampf((dk - 0.55) / 0.45, 0.0, 1.0))
	if main and main.player and not dead:
		var dx: float = main.player.position.x - anchor.x
		if absf(dx) > 30.0:
			facing = signf(dx)
	var xf := _body_xf()
	var ux := xf * Transform2D(0.0, Vector2.ONE * Mere.HEIGHT / 100.0, 0.0, Vector2.ZERO)
	var atlas = BossBake.get_atlas(self, Mere)
	var anim := "mort" if dead else "p%d" % phase
	var u := dk if dead else fposmod(t / Mere.LOOP, 1.0)
	_draw_part(atlas, "sol", "p%d" % phase, 0.0, xf, {"groupe": "sol", "phase": phase})
	# Lianes au repos derrière elle (une de plus à chaque phase), qui ondulent ; elles rentrent à la mort.
	if dk < 0.5:
		_rest_vines(ux, 1.0 - dk * 2.0)
	var o := {"phase": phase, "t": fposmod(t, Mere.LOOP)}
	if dead:
		o = {"phase": 3, "die": dk}
	_draw_part(atlas, "corps", anim, u, xf, o, not dead)
	if dead:
		return
	# Yeux de braise : plus vifs pendant une annonce.
	var ann := 1.0 if stage == "annonce" else 0.0
	var lift := Vector2(0, -Mere.LIFT)
	for i in Mere.EYES.size():
		var e: Array = Mere.EYES[i]
		O.eye(self, ux, e[0] + lift, e[1], e[2], e[3], 0.45 + 0.55 * ann, 1.0 if hit_flash > 0.0 else 0.0, t, 0.0, 0.7 + i * 0.13)
	# Phase 3 : des braises s'échappent du cœur de la rose.
	if phase >= 3:
		Ink.sparks(self, ux, Mere.HEART, Vector2(0.1, -1.6), 7, t * 0.8, 3.0, 1.0)


## Un groupe cuit (sprite) ou, faute d'atlas, le même dessin en direct.
func _draw_part(atlas, group: String, anim: String, u: float, xf: Transform2D, o: Dictionary, loop := true) -> void:
	if atlas != null and atlas.draw_blend(self, group, anim, u, xf, loop):
		return
	if BossBake.no_render():
		return
	o["groupe"] = group
	draw_set_transform_matrix(xf)
	Mere.draw(self, Vector2.ZERO, Mere.HEIGHT, o)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Les fouets au repos : de longues tiges de ronce qui sortent de derrière elle et ondulent.
func _rest_vines(ux: Transform2D, k: float) -> void:
	var rage: float = [0.0, 0.5, 1.0][phase - 1]
	var n := 2 + phase
	var cane := Art.bc("ronce", "detail").lerp(Art.bc("ronce", "ombre"), 0.4)
	var bone := Art.bc("os")
	for i in n:
		var foot: Vector2 = Mere.VINE_FEET[i]
		var out := -1.0 if foot.x < 0.0 else 1.0
		var a0 := -PI * 0.5 + out * (0.55 + 0.25 * (i % 2))
		var len := (95.0 + 20.0 * (i % 3)) * k
		var pts := PackedVector2Array()
		var p := foot
		var ang := a0
		for j in 9:
			var u := j / 8.0
			pts.append(p)
			ang += out * (0.16 + 0.1 * sin(t * (1.4 + 0.6 * rage) + i * 2.0 + u * 3.0))
			p += Vector2.from_angle(ang) * len / 8.0
		Ink.brush(self, ux, pts, 9.0, Ink.encre(), 1.0, 0.0)
		Ink.brush(self, ux, pts, 6.0, cane, 1.0, 0.0)
		for j in range(1, 8):
			var d := (pts[j + 1] - pts[j - 1]).normalized()
			var side := 1.0 if j % 2 else -1.0
			var b: Vector2 = pts[j] + d.orthogonal() * side * 2.0
			var tip := b + (d.orthogonal() * side - d * 0.6).normalized() * (8.0 - j * 0.5)
			var w := d * 2.2
			draw_colored_polygon(ux * PackedVector2Array([b - w, tip, b + w]), bone.darkened(0.15 * (j % 2)))


## Au-dessus de la teinte : la vie qui reprend au cœur de la rose à sa mort, les états visibles.
func draw_life(c: CanvasItem) -> void:
	var xf := _body_xf()
	var ux := xf * Transform2D(0.0, Vector2.ONE * Mere.HEIGHT / 100.0, 0.0, Vector2.ZERO)
	var heart: Vector2 = ux * Mere.HEART
	var mid: Vector2 = ux * Vector2(0, -60)
	if statuses.has("saignement"):
		Art.status(c, "saignement", mid, radius * 0.7, t * 1.25)
		for i in int(statuses["saignement"]["stacks"]):
			Art._drop(c, heart + Vector2(-radius * 0.5 + i * radius * 0.25, -radius * 0.45), 4.5, Art.ec("saignement", "clair"))
	if statuses.has("enracine"):
		Art.status(c, "racine", ux * Vector2(0, -20), radius * 0.9, t)
	if poison_time > 0.0:
		Art.status(c, "poison", mid, radius * 0.7, t)
	# Mort : la vie reprend au cœur de la rose (vert sève : le vivant), des pousses sortent de la galle.
	var dk := clampf(dying / DEATH_TIME, 0.0, 1.0) if dead else 0.0
	if dead and dk > 0.4:
		var g := Anim.ease_out((dk - 0.4) / 0.6)
		var at: Vector2 = ux * Vector2(0, -60.0 + 30.0 * dk)
		Art.glow(c, at, radius * 0.9 * g, "seve")
		var green := Art.ec("seve", "clair")
		for i in 5:
			var foot := Vector2(-36.0 + i * 18.0, -40.0 + 30.0 * dk - 8.0 * (i % 2))
			var top := foot + Vector2(4.0 * sin(i * 1.7), -26.0 * g)
			Ink.brush(c, ux, PackedVector2Array([foot, foot.lerp(top, 0.5) + Vector2(2, 0), top]), 3.2, Color(green.darkened(0.3), g), 1.0, 0.0)
			c.draw_colored_polygon(ux * Ink.leaf(top, -PI * 0.5 + (0.7 if i % 2 else -0.7), 12.0 * g, 6.0 * g), Color(green, g))


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
	# Invocation : des galles sortent du sol et enflent, une larve y pointe (pas un coup : couleur de cendre).
	for b in buds:
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
		var e := Art.ec("cendre")
		c.draw_arc(b, 30.0, 0.0, TAU, 28, Color(e, 0.25 + 0.4 * k), Art.TRAIT, true)
		c.draw_circle(b, 30.0 * k, Color(e, 0.1))
		var size := 5.0 + 9.0 * Anim.ease_out(k)
		var gall := Ink.lumpy(b + Vector2(0, -size * 0.7), size * 0.9, size, 16, 0.08, 10.0)
		Ink.part(c, Transform2D.IDENTITY, gall, O.pal(), 1.6, 1.0, 0.6)
		if k > 0.5:
			Ink.ember(c, Transform2D.IDENTITY, Ink.leaf(b + Vector2(-size * 0.3, -size * 0.9), -0.2, size * 0.5, size * 0.25), k)


## Fouet (liane épineuse) en coordonnées monde : encre, tige de ronce, épines d'os.
func _vine(c: CanvasItem, pts: PackedVector2Array, width: float, _thorns: float) -> void:
	var cane := Art.bc("ronce", "detail").lerp(Art.bc("ronce", "ombre"), 0.4)
	Ink.brush(c, Transform2D.IDENTITY, pts, width + 4.0, Ink.encre(), 1.0, 0.4)
	Ink.brush(c, Transform2D.IDENTITY, pts, width, cane, 1.0, 0.4)
	Ink.brush(c, Transform2D.IDENTITY, pts, width * 0.3, cane.lightened(0.3), 1.0, 0.0)
	var bone := Art.bc("os")
	for j in range(2, pts.size(), 2):
		var d: Vector2 = (pts[j] - pts[j - 1]).normalized()
		var n := d.orthogonal() * (1.0 if j % 4 == 0 else -1.0)
		var b: Vector2 = pts[j] + n * width * 0.4
		var tip: Vector2 = b + (n - d * 0.5).normalized() * width * 1.3
		var side := (tip - b).orthogonal() * 0.25
		c.draw_colored_polygon(PackedVector2Array([b + side, tip, b]), bone)
		c.draw_colored_polygon(PackedVector2Array([b, tip, b - side]), bone.darkened(0.3))


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
			c.draw_colored_polygon(PackedVector2Array([pts[12] + side, tip, pts[12] - side]), Art.bc("os"))
	for r in roots:
		if r["burst"] >= 0.0:
			var pos: Vector2 = r["pos"]
			var k := clampf(r["burst"] / ROOT["burst"], 0.0, 1.0)
			var rise := maxf(0.08, sin(k * PI))
			for i in 6:
				var a := TAU * i / 6.0 + pos.y * 0.01
				var foot := pos + Vector2.from_angle(a) * ROOT["radius"] * 0.5 * Vector2(1.0, 0.6)
				var tip := foot + Vector2(cos(a) * 14.0, -70.0 * rise)
				var body := Art.bc("ronce", "detail").lerp(Art.bc("ronce", "ombre"), 0.4)
				var spike := PackedVector2Array([foot + Vector2(-10, 0), tip, foot + Vector2(10, 0)])
				Art.outline(c, spike, Art.bc("encre"), Art.TRAIT)
				c.draw_colored_polygon(PackedVector2Array([foot + Vector2(-10, 0), tip, foot]), body.lightened(0.2))
				c.draw_colored_polygon(PackedVector2Array([foot, tip, foot + Vector2(10, 0)]), body.darkened(0.3))
				# Pointe d'os.
				var d := (tip - foot).normalized()
				c.draw_colored_polygon(PackedVector2Array([tip - d * 12.0 + d.orthogonal() * 3.5, tip + d * 4.0, tip - d * 12.0 - d.orthogonal() * 3.5]), Art.bc("os"))


# --- Dessinés par l'arène (boss_arena.gd), coordonnées de l'arène ---

## La Mère-Ronce endormie : repliée sur ses pattes, la rose en bouton, les yeux clos. Arène ouverte :
## la braise couve entre les pétales.
static func draw_sleeper(a: Node2D) -> void:
	var feet: Vector2 = a.center + Vector2(0, RADIUS * FEET)
	var xf := Transform2D(0.0, feet)
	var atlas = BossBake.get_atlas(a, Mere)
	if BossBake.no_render():
		return
	if atlas == null or not atlas.draw_blend(a, "sol", "p1", 0.0, xf):
		a.draw_set_transform_matrix(xf)
		Mere.draw(a, Vector2.ZERO, Mere.HEIGHT, {"groupe": "sol", "phase": 1})
	if atlas == null or not atlas.draw_blend(a, "corps", "dort", 0.0, xf):
		a.draw_set_transform_matrix(xf)
		Mere.draw(a, Vector2.ZERO, Mere.HEIGHT, {"sleep": true})
	a.draw_set_transform_matrix(Transform2D.IDENTITY)
	if a.state == "ouverte":
		var ux := xf * Transform2D(0.0, Vector2.ONE * Mere.HEIGHT / 100.0, 0.0, Vector2.ZERO)
		var pulse := 0.5 + 0.5 * sin(a.t * 2.0)
		Ink.halo(a, ux * (Mere.HEART + Vector2(0, 18)), 34.0 * (0.8 + 0.3 * pulse), Art.bc("braise"), 0.8 + 0.8 * pulse)


## Après la victoire : un roncier vivant, en fleurs et en fruits, à la place de la Mère-Ronce.
static func draw_victory(a: Node2D) -> void:
	var feet: Vector2 = a.center + Vector2(0, RADIUS * FEET)
	var xf := Transform2D(0.0, feet)
	var atlas = BossBake.get_atlas(a, Mere)
	if BossBake.no_render():
		return
	if atlas == null or not atlas.draw_blend(a, "vaincu", "vaincu", 0.0, xf):
		a.draw_set_transform_matrix(xf)
		Mere.draw(a, Vector2.ZERO, Mere.HEIGHT, {"groupe": "vaincu"})
		a.draw_set_transform_matrix(Transform2D.IDENTITY)
