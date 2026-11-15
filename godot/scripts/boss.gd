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
## Elle respecte l'interface d'un ennemi (position, radius, dead, take_damage, apply_poison,
## apply_status) et s'inscrit dans main.enemies ; trop grosse pour la grille spatiale, elle est
## aussi dans main.big_enemies (voir main.enemies_near).
extends Node2D

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

var main
var arena
## Rang dans main.enemies (voir main._rebuild_grid).
var index := -1
var radius := RADIUS
var dead := false
var hp := BASE_HP
var max_hp := BASE_HP
var xp_value := 60.0
var poison_dps := 0.0
var poison_time := 0.0
var hit_flash := 0.0
## États posés par les compétences : nom -> {"value", "time", "stacks"}.
var statuses: Dictionary = {}
var root_immune := 0.0
## Elle ne bouge pas : sa position est rétablie à chaque pas (reculs des coups, séparation).
var anchor := Vector2.ZERO
var damage_scale := 1.0
var phase := 1
var t := 0.0
var intro := INTRO
var transition := 0.0
var dying := 0.0
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
var minions: Array = []
## Figée par les tests visuels : la logique ne tourne plus, la pose reste affichée.
var frozen := false
var marks: Node2D
var overlay: Node2D


## Annonces au sol (sous les personnages) et projectiles (au-dessus) : dessinés en coordonnées monde.
class Layer extends Node2D:
	var boss
	var above := false

	func _draw() -> void:
		if above:
			boss.draw_overlay(self)
		else:
			boss.draw_marks(self)


func _ready() -> void:
	anchor = position
	max_hp = BASE_HP + HP_PER_LEVEL * Game.level
	hp = max_hp
	damage_scale = 1.0 + DAMAGE_PER_LEVEL * (Game.level - 1)
	xp_value = 40.0 + 12.0 * Game.level
	marks = Layer.new()
	marks.boss = self
	arena.add_child(marks)
	overlay = Layer.new()
	overlay.boss = self
	overlay.above = true
	main.projectiles_layer.add_child(overlay)


func _exit_tree() -> void:
	main.big_enemies.erase(self)
	for n in [marks, overlay]:
		if is_instance_valid(n):
			n.queue_free()


func _process(delta: float) -> void:
	if frozen:
		return
	t += delta
	redraw()


func redraw() -> void:
	queue_redraw()
	marks.queue_redraw()
	overlay.queue_redraw()


func phase_for(ratio: float) -> int:
	if ratio > PHASE_LIMITS[0]:
		return 1
	return 2 if ratio > PHASE_LIMITS[1] else 3


func _physics_process(delta: float) -> void:
	if frozen:
		return
	position = anchor
	hit_flash -= delta
	root_immune -= delta
	if dead:
		dying += delta
		if dying >= DEATH_TIME:
			queue_free()
		return
	_tick_statuses(delta)
	if dead:
		return
	_update_thorns(delta)
	_update_roots(delta)
	minions = minions.filter(func(e): return is_instance_valid(e) and not e.dead and not e.is_queued_for_deletion())
	var p = main.player
	if p.position.distance_to(anchor) < radius + p.radius:
		p.take_hit(CONTACT_DAMAGE * damage_scale, self)
	if intro > 0.0:
		intro -= delta
		return
	if transition > 0.0:
		transition -= delta
		return
	var cadence := ROOTED_CADENCE if statuses.has("enracine") else 1.0
	if attack == "":
		var wanted := phase_for(hp / max_hp)
		if wanted > phase:
			_enter_phase(wanted)
			return
		gap -= delta * cadence
		if gap <= 0.0:
			var order: Array = PHASES[phase]["order"]
			_begin(order[cycle % order.size()])
			cycle += 1
	elif stage == "annonce":
		timer -= delta * cadence
		_announce_step(delta * cadence)
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
	if n == 2:
		main.hud.banner("La Mère-Ronce s'ouvre : ses bourgeons éclosent.")
	else:
		main.hud.banner("La Mère-Ronce enrage : les ronces se resserrent !")
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


# --- Interface d'un ennemi ---

func take_damage(amount: float, crit: bool, dot := false) -> void:
	if dead:
		return
	hp -= amount
	if not dot:
		hit_flash = 0.08
		if crit:
			main.fx.text(position + Vector2(0, -radius * 2.0), str(roundi(amount)), Color("f2d06b"), 20, 0.6)
	if hp <= 0.0:
		_die()


func apply_poison(dps: float, duration: float) -> void:
	poison_dps = maxf(poison_dps if poison_time > 0.0 else 0.0, dps)
	poison_time = maxf(poison_time, duration)


## États posés par les compétences de Ronce. « saignement » : dégâts par seconde, cumulable
## BLEED_STACKS fois. « enracine » : elle est déjà enracinée, mais prépare ses attaques plus
## lentement tant que l'état dure, puis y résiste ROOT_IMMUNITY secondes.
func apply_status(status: String, value: float, duration: float) -> void:
	if dead:
		return
	match status:
		"saignement":
			var s: Dictionary = statuses.get(status, {"value": 0.0, "time": 0.0, "stacks": 0})
			s["value"] = maxf(s["value"], value)
			s["time"] = maxf(s["time"], duration)
			s["stacks"] = mini(BLEED_STACKS, int(s["stacks"]) + 1)
			statuses[status] = s
		"enracine":
			if root_immune > 0.0 or statuses.has(status):
				return
			statuses[status] = {"value": value, "time": minf(duration, 3.0), "stacks": 1}
			main.fx.text(position + Vector2(0, -radius * 2.0), "Entravée", Color("9af07a"), 18, 0.8)
		_:
			statuses[status] = {"value": value, "time": duration, "stacks": 1}


func _tick_statuses(delta: float) -> void:
	if poison_time > 0.0:
		poison_time -= delta
		take_damage(poison_dps * delta, false, true)
	for status in statuses.keys():
		var s: Dictionary = statuses[status]
		s["time"] -= delta
		if status == "saignement" and not dead:
			take_damage(s["value"] * s["stacks"] * delta, false, true)
		if s["time"] <= 0.0:
			statuses.erase(status)
			if status == "enracine":
				root_immune = ROOT_IMMUNITY


func _die() -> void:
	dead = true
	dying = 0.0
	hp = 0.0
	attack = ""
	stage = ""
	thorns = []
	roots = []
	whips = []
	buds = []
	main.big_enemies.erase(self)
	for e in minions:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(e.hp + 1.0, false)
	main.on_enemy_killed(self)
	arena.boss_defeated()


# --- Dessin ---

func _color(base: Color) -> Color:
	var c := base
	if hit_flash > 0.0:
		c = c.lerp(Color.WHITE, 0.55)
	if poison_time > 0.0:
		c = c.lerp(Color("8f5fc0"), 0.35)
	if dead:
		c = c.lerp(Color("6d6470"), clampf(dying / DEATH_TIME, 0.0, 1.0))
	return c


func _draw() -> void:
	var wake := 1.0 - clampf(intro / INTRO, 0.0, 1.0)
	var fade := 1.0 - clampf(dying / DEATH_TIME, 0.0, 1.0) if dead else 1.0
	var s := lerpf(0.3, 1.0, 1.0 - (1.0 - wake) * (1.0 - wake)) * (0.55 + 0.45 * fade)
	# Recul avant la volée, élan au moment du tir, tremblement pendant un changement de phase.
	var shift := Vector2.ZERO
	if attack == "volee":
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
		shift = -aim * 22.0 * k if stage == "annonce" else aim * 12.0
	elif attack == "fouets" and stage == "annonce":
		shift = Vector2(0, 6.0 * sin(t * 30.0))
	if transition > 0.0:
		shift += Vector2(sin(t * 50.0), cos(t * 43.0)) * 4.0
	var r := radius
	var open: float = [0.0, 0.35, 0.8][phase - 1]
	var rage: float = [0.0, 0.5, 1.0][phase - 1]
	modulate.a = 0.35 + 0.65 * fade
	draw_set_transform(shift, 0.0, Vector2(s, s))

	# Racines maîtresses, étalées au sol.
	for i in 9:
		var a := TAU * i / 9.0 + 0.2
		var pts := PackedVector2Array()
		for j in 6:
			var u := j / 5.0
			pts.append(Vector2.from_angle(a + 0.35 * sin(u * 3.0 + i)) * r * (0.6 + 1.5 * u) * Vector2(1.0, 0.7))
		draw_polyline(pts, _color(Color("1c1418")), 12.0 - 1.2 * (i % 4))
	# Fouets au repos : des lianes épineuses qui ondulent (plus nombreuses à chaque phase).
	var vines := 2 + phase
	for i in vines:
		var a := TAU * (i + 0.5) / vines + 0.25 * sin(t * 0.9 + i * 1.7)
		var pts := PackedVector2Array()
		for j in 9:
			var u := j / 8.0
			var sway := 0.5 * sin(t * (1.6 + rage) + u * 4.0 + i * 2.0) * u
			pts.append(Vector2.from_angle(a + sway) * r * (0.8 + 1.6 * u) + Vector2(0, -r * 0.5 * sin(u * PI)))
		draw_polyline(pts, _color(Color("3d2a22")), 7.0)
		for j in range(2, 9, 2):
			var tip: Vector2 = pts[j] + (pts[j] - pts[j - 1]).orthogonal().normalized() * 10.0
			draw_line(pts[j], tip, _color(Color("c9b8a0")), 3.0)
	var lift := Vector2(0, -r * 0.5)
	# Sépales épineux derrière la corolle.
	for i in 12:
		var a := TAU * i / 12.0 + 0.05 * sin(t * 2.0 + i)
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * r * 0.2
		draw_colored_polygon(PackedVector2Array([lift + dir * r * 0.9 + side, lift + dir * r * (1.55 + 0.25 * rage), lift + dir * r * 0.9 - side]), _color(Color("231a1e")))
	# Corolle : pétales de rose fanée, qui s'écartent et rougissent à chaque phase.
	var petal_far := Color("5b2a3a").lerp(Color("b8323a"), rage)
	var petal_near := Color("7a3346").lerp(Color("e0675e"), rage)
	for ring in 2:
		var n := 9 - ring * 3
		for i in n:
			var a := TAU * (i + 0.5 * ring) / n + 0.04 * sin(t * 1.5 + i * 1.3)
			var length: float = r * (1.25 - 0.4 * ring) * (1.0 + 0.25 * open)
			var width: float = r * (0.46 - 0.1 * ring) * (1.0 - 0.3 * open)
			var dir := Vector2.from_angle(a)
			var side: Vector2 = dir.orthogonal() * width
			var base: Vector2 = lift + dir * r * 0.25 * open
			draw_colored_polygon(PackedVector2Array([base, base + dir * length * 0.5 + side, base + dir * length, base + dir * length * 0.5 - side]), _color(petal_far if ring == 0 else petal_near))
	# Bulbe central.
	var body := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		body.append(lift + Vector2.from_angle(a) * r * 0.62 * (1.0 + 0.06 * sin(a * 5.0 + t * 3.0)))
	draw_colored_polygon(body, _color(Color("3a2630").lerp(Color("5a2228"), rage)))
	# Cœur de braise, de plus en plus à nu.
	var ember := Color("ff9a4a")
	var pulse := 0.5 + 0.5 * sin(t * (3.0 + 4.0 * rage))
	draw_circle(lift, r * (0.26 + 0.16 * open), Color(ember.r, ember.g, ember.b, 0.25 + 0.2 * pulse))
	draw_circle(lift, r * (0.14 + 0.12 * open), _color(ember.lerp(Color("fff0b0"), pulse * rage)))
	# Trois braises (yeux) tournées vers le joueur.
	var look: Vector2 = (main.player.position - anchor).normalized()
	for i in 3:
		var eye := lift + look * r * 0.4 + look.orthogonal() * r * 0.22 * (i - 1) - look * r * 0.06 * absf(i - 1)
		draw_circle(eye, r * 0.075, _color(ember))
	# États visibles : gouttes du saignement, liens de l'enracinement.
	if statuses.has("saignement"):
		for i in int(statuses["saignement"]["stacks"]):
			draw_circle(lift + Vector2(-r * 0.5 + i * r * 0.25, r * 0.75 + 4.0 * sin(t * 6.0 + i)), 5.0, Color("c0283a"))
	if statuses.has("enracine"):
		for i in 3:
			draw_arc(lift, r * (0.75 + 0.12 * i), 0.4 + i, 2.4 + i, 12, Color("7a9a4a"), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Annonces au sol, en coordonnées monde.
func draw_marks(c: CanvasItem) -> void:
	var warn := Color(1.0, 0.35, 0.2)
	if attack == "volee" and stage == "annonce":
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
		var locked := timer <= stage_time * 0.4
		var reach: float = arena.radius * 2.0
		for dir in volley_dirs():
			var from: Vector2 = anchor + dir * radius
			var to: Vector2 = anchor + dir * lerpf(radius + 40.0, reach, k)
			to = arena.center + (to - arena.center).limit_length(arena.radius)
			c.draw_line(from, to, Color(warn.r, warn.g, warn.b, 0.16 + 0.1 * k), VOLLEY["radius"] * 2.0)
			c.draw_line(from, to, Color(warn.r, warn.g, warn.b, 0.9 if locked else 0.45), 2.0)
	if attack == "fouets":
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0) if stage == "annonce" else 1.0
		for w in whips:
			var a0: float = w["angle"]
			var a1: float = w["to"]
			var pts := PackedVector2Array([anchor])
			var steps := 20
			for i in steps + 1:
				pts.append(anchor + Vector2.from_angle(lerpf(a0, a1, i / float(steps))) * WHIP["length"])
			# Un secteur presque refermé n'a plus de surface à remplir.
			if absf(a1 - a0) > 0.05:
				c.draw_colored_polygon(pts, Color(warn.r, warn.g, warn.b, 0.08 + 0.14 * k))
			c.draw_arc(anchor, WHIP["length"], minf(a0, a1), maxf(a0, a1), 32, Color(warn.r, warn.g, warn.b, 0.75), 3.0)
			# Le bord de départ, en clair, et des chevrons qui donnent le sens du balayage.
			c.draw_line(anchor, anchor + Vector2.from_angle(a0) * WHIP["length"], Color(1.0, 0.85, 0.6, 0.9), 3.0)
			var sgn := signf(a1 - a0)
			for i in 4:
				var a := lerpf(a0, a1, (i + 0.5 + fmod(t * 1.5, 1.0) * 0.5) / 4.5)
				var mid: Vector2 = anchor + Vector2.from_angle(a) * WHIP["length"] * 0.72
				var tang := Vector2.from_angle(a + sgn * PI / 2.0)
				var out := Vector2.from_angle(a)
				c.draw_polyline(PackedVector2Array([mid - tang * 10.0 + out * 12.0, mid + tang * 8.0, mid - tang * 10.0 - out * 12.0]), Color(1.0, 0.85, 0.6, 0.7), 3.0)
	for r in roots:
		var pos: Vector2 = r["pos"]
		if r["burst"] < 0.0:
			var k := 1.0 - clampf(r["fuse"] / ROOT["fuse"], 0.0, 1.0)
			c.draw_circle(pos, ROOT["radius"], Color(0.12, 0.05, 0.04, 0.35 + 0.25 * k))
			c.draw_circle(pos, ROOT["radius"] * k, Color(warn.r, warn.g, warn.b, 0.22))
			c.draw_arc(pos, ROOT["radius"], 0.0, TAU, 40, Color(warn.r, warn.g, warn.b, 0.5 + 0.4 * k), 3.0)
			for i in 5:
				var a := TAU * i / 5.0 + pos.x * 0.01
				c.draw_line(pos + Vector2.from_angle(a) * 8.0, pos + Vector2.from_angle(a + 0.3) * ROOT["radius"] * (0.3 + 0.6 * k), Color(0.05, 0.02, 0.02, 0.8), 3.0)
		else:
			c.draw_circle(pos, ROOT["radius"], Color(0.1, 0.04, 0.03, 0.5))
	for b in buds:
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
		c.draw_circle(b, 30.0, Color(warn.r, warn.g, warn.b, 0.12 + 0.12 * k))
		c.draw_arc(b, 30.0, 0.0, TAU, 24, Color(warn.r, warn.g, warn.b, 0.7), 2.0)
		c.draw_circle(b, 6.0 + 12.0 * k, Color("5b2a3a"))
		c.draw_circle(b, 3.0 + 5.0 * k, Color("ff9a4a"))


## Projectiles et coups, au-dessus des personnages, en coordonnées monde.
func draw_overlay(c: CanvasItem) -> void:
	for th in thorns:
		var pos: Vector2 = th["pos"]
		var dir: Vector2 = (th["vel"] as Vector2).normalized()
		var side := dir.orthogonal() * VOLLEY["radius"] * 0.7
		c.draw_line(pos - dir * 26.0, pos, Color(1.0, 0.5, 0.3, 0.3), 5.0)
		c.draw_colored_polygon(PackedVector2Array([pos + dir * 14.0, pos - dir * 8.0 + side, pos - dir * 8.0 - side]), Color("e8d6b8"))
		c.draw_circle(pos, 3.0, Color("ff9a4a"))
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
			c.draw_polyline(pts, Color("2a1a16"), WHIP["width"] * 0.7)
			c.draw_polyline(pts, Color("6a3a2a"), WHIP["width"] * 0.35)
			for i in range(2, 13, 2):
				var n: Vector2 = (pts[i] - pts[i - 1]).orthogonal().normalized()
				c.draw_line(pts[i] - n * 12.0, pts[i] + n * 12.0, Color("e8d6b8"), 3.0)
	for r in roots:
		if r["burst"] >= 0.0:
			var pos: Vector2 = r["pos"]
			var k := clampf(r["burst"] / ROOT["burst"], 0.0, 1.0)
			var rise := maxf(0.08, sin(k * PI))
			for i in 6:
				var a := TAU * i / 6.0 + pos.y * 0.01
				var foot := pos + Vector2.from_angle(a) * ROOT["radius"] * 0.5 * Vector2(1.0, 0.6)
				var tip := foot + Vector2(cos(a) * 14.0, -70.0 * rise)
				c.draw_colored_polygon(PackedVector2Array([foot + Vector2(-9, 0), tip, foot + Vector2(9, 0)]), Color("2a1a16"))
				c.draw_line(foot, tip, Color("6a3a2a"), 3.0)
