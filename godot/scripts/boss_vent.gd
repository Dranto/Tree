## Le Harfang de cendre, boss de la région de Vent : un grand rapace flétri qui plane au-dessus de
## son aire, au centre de l'arène des hauts plateaux.
##
## Trois phases (100–66 %, 66–33 %, 33–0 % de sa vie). Chaque coup est annoncé avec Art.telegraph :
##   - plumes    : éventail de plumes de cendre vers le joueur (une, puis deux salves) ; les rafales
##                 du plateau les dévient (wind.gd) ;
##   - battement : un grand coup d'ailes autour de lui (cercle au sol) qui blesse et repousse ;
##   - piqué (dès la phase 2) : il s'envole (hors d'atteinte), son ombre suit le joueur puis se fige,
##                 il fond sur elle ; posé au sol un moment, il prend plus de dégâts ;
##   - nuée (dès la phase 2) : des Piqueurs naissent autour de lui (pas un coup : pas de rouge) ;
##   - tempête (phase 3) : deux tornades errent dans l'arène et repoussent ; un vent tournant
##                 pousse le joueur le long du bord (réglé par les options, Settings.wind).
## Mort : il replie les ailes et tombe, ses plumes s'envolent en cendre, la sève remonte.
##
## Le socle commun (vie, phases, états, mort, interface d'ennemi) est dans boss_base.gd ; ce
## fichier ne décrit que ses attaques et son dessin. Nommé dans data/regions/vent.json › boss.
extends BossBase

const Enemy = preload("res://scripts/enemy.gd")
const Wind = preload("res://scripts/wind.gd")

const RADIUS := 62.0
const INTRO := 1.6
const DEATH_TIME := 2.0
const BASE_HP := 680.0
const HP_PER_LEVEL := 210.0
const DAMAGE_PER_LEVEL := 0.03
const CONTACT_DAMAGE := 14.0
const PHASE_LIMITS := [0.66, 0.33]
## Par phase : pause entre deux attaques, ordre des attaques, et leur ampleur.
const PHASES := {
	1: {"gap": 1.6, "order": ["plumes", "battement", "plumes"], "feathers": 7, "volleys": 1, "minions": 0},
	2: {"gap": 1.3, "order": ["plumes", "pique", "nuee", "battement"], "feathers": 9, "volleys": 2, "minions": 3},
	3: {"gap": 1.0, "order": ["tempete", "pique", "plumes", "battement", "pique", "nuee"], "feathers": 11, "volleys": 2, "minions": 3},
}
const FEATHER := {"annonce": 0.9, "between": 0.38, "damage": 13.0, "speed": 380.0, "radius": 8.0, "spread": 0.19}
const BEAT := {"annonce": 1.1, "frappe": 0.3, "radius": 250.0, "damage": 16.0, "push": 620.0, "push_time": 0.35}
## Piqué : envol, ombre qui suit le joueur, ombre figée, chute, pose au sol, retour au centre.
const DIVE := {"rise": 0.55, "track": 1.0, "lock": 0.5, "fall": 0.18, "ground": 1.3, "back": 0.6, "radius": 120.0, "damage": 24.0, "landed_mult": 1.25}
const STORM := {"annonce": 1.0, "count": 2, "life": 7.5, "speed": 95.0, "radius": 46.0, "damage": 9.0, "tick": 0.6, "push": 240.0, "swirl": 45.0}
const SUMMON := {"annonce": 1.0, "max_alive": 5, "kind": "plongeur"}
const PHASE_PAUSE := 1.5
const ROOTED_CADENCE := 0.6
const ROOT_IMMUNITY := 6.0
const BLEED_STACKS := 5
## Altitude du vol stationnaire (en rayons) et de l'envol du piqué (pixels).
const HOVER := 0.9
const SKY := 900.0

## Attaque en cours ("" pendant la pause), son étape ("annonce" ou "frappe") et le temps restant.
var attack := ""
var stage := ""
var timer := 0.0
var stage_time := 1.0
var gap := 1.4
var cycle := 0
var aim := Vector2.DOWN
var volleys_left := 0
var volley_timer := 0.0
## Plumes en vol : {"pos", "vel"}.
var feathers: Array = []
## Piqué : étape ("envol", "suit", "fige", "chute", "pose", "retour"), son temps, la cible au sol.
var dive_step := ""
var dive_t := 0.0
var dive_target := Vector2.ZERO
var home := Vector2.ZERO
## Battement : temps restant de la poussée sur le joueur (s'il a été pris).
var push_left := 0.0
## Tornades : {"pos", "vel", "life", "tick", "seed"} ; points d'apparition annoncés.
var tornadoes: Array = []
var storm_spots: Array = []
## Petits de la nuée annoncés (positions).
var nest: Array = []
## Vent tournant de la phase 3 (0 → 1).
var swirl := 0.0
var _dodge_text := -10.0


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
	color = Color("4a5058")


func _ready() -> void:
	super._ready()
	home = anchor


## En vol (envol, ombre, chute), il est hors d'atteinte : aucun coup direct ne le touche.
func airborne() -> bool:
	return attack == "pique" and dive_step in ["envol", "suit", "fige", "chute"]


## Posé après un piqué : il prend plus de dégâts.
func landed() -> bool:
	return attack == "pique" and dive_step == "pose"


func take_damage(amount: float, crit: bool, dot := false) -> void:
	if not dot and airborne():
		if t - _dodge_text > 0.8:
			_dodge_text = t
			main.fx.text(dive_target + Vector2(0, -60), "Hors d'atteinte", Art.ec("vent", "clair"), 16, 0.6)
		return
	if landed() and not dot:
		amount *= DIVE["landed_mult"]
	super.take_damage(amount, crit, dot)


func _projectiles_step(delta: float) -> void:
	_update_feathers(delta)
	_update_tornadoes(delta)
	var p = main.player
	if push_left > 0.0:
		push_left -= delta
		var out: Vector2 = p.position - anchor
		# Repoussé, mais pas jusque dans le mur de l'arène.
		if out.length() > 1.0 and p.position.distance_to(arena.center) < arena.radius - 70.0 and p.dash_time <= 0.0:
			p.position += out.normalized() * BEAT["push"] * delta
	if phase >= 3 and not dead:
		swirl = minf(1.0, swirl + delta / 2.0)
		var rel: Vector2 = p.position - arena.center
		if rel.length() > 40.0 and p.dash_time <= 0.0:
			p.position += rel.normalized().orthogonal() * STORM["swirl"] * swirl * Settings.wind * delta


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
	elif attack == "pique":
		_dive_step(delta)
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
	if kind == "nuee" and minions.size() >= SUMMON["max_alive"]:
		kind = "plumes"
	if kind == "tempete" and not tornadoes.is_empty():
		kind = "battement"
	attack = kind
	stage = "annonce"
	Sfx.play("annonce", anchor)
	var to: Vector2 = main.player.position - anchor
	aim = to.normalized() if to.length() > 1.0 else Vector2.DOWN
	match kind:
		"plumes":
			_set_timer(FEATHER["annonce"])
		"battement":
			_set_timer(BEAT["annonce"])
		"pique":
			stage = "frappe"
			dive_step = "envol"
			dive_t = DIVE["rise"]
			dive_target = main.player.position
			radius = 0.0
		"nuee":
			_set_timer(SUMMON["annonce"])
			nest = []
			var n: int = PHASES[phase]["minions"]
			for i in n:
				var a := aim.angle() + PI + (i - (n - 1) / 2.0) * 0.7
				nest.append(anchor + Vector2.from_angle(a) * 160.0)
		"tempete":
			_set_timer(STORM["annonce"])
			storm_spots = []
			var base: float = (main.player.position - arena.center).angle()
			for i in STORM["count"]:
				var a: float = base + PI * 0.6 + i * PI * 0.8
				storm_spots.append(arena.center + Vector2.from_angle(a) * arena.radius * 0.7)


func _set_timer(v: float) -> void:
	timer = v
	stage_time = v


## Pendant l'annonce, l'éventail suit le joueur puis se verrouille.
func _announce_step() -> void:
	if attack == "plumes" and timer > stage_time * 0.4:
		var to: Vector2 = main.player.position - anchor
		if to.length() > 1.0:
			aim = to.normalized()


func _strike() -> void:
	stage = "frappe"
	var p = main.player
	match attack:
		"plumes":
			volleys_left = PHASES[phase]["volleys"]
			volley_timer = 0.0
			_set_timer(FEATHER["between"] * volleys_left)
		"battement":
			_set_timer(BEAT["frappe"])
			main.fx.ring(anchor, radius, BEAT["radius"], 0.35, Color(Art.ec("vent", "clair"), 0.8), 6.0)
			if p.position.distance_to(anchor) < BEAT["radius"] + p.radius and p.invuln <= 0.0:
				p.take_hit(BEAT["damage"] * damage_scale, self)
				push_left = BEAT["push_time"]
		"nuee":
			var kind := Enemy.kind_index(SUMMON["kind"])
			for b in nest:
				if kind >= 0:
					minions.append(main.spawn_enemy_at(b, kind))
				main.fx.ring(b, 6.0, 46.0, 0.35, Color(Art.ec("cendre"), 0.8), 3.0)
			nest = []
			_end_attack()
		"tempete":
			for i in storm_spots.size():
				tornadoes.append({"pos": storm_spots[i], "vel": Vector2.ZERO, "life": STORM["life"], "tick": 0.0, "seed": i * 1.7 + cycle})
			storm_spots = []
			_end_attack()


func _strike_step(delta: float) -> void:
	if attack == "plumes":
		volley_timer -= delta
		if volleys_left > 0 and volley_timer <= 0.0:
			volley_timer = FEATHER["between"]
			_fire_volley(volleys_left % 2 == 0)
			volleys_left -= 1


## Directions des plumes d'une salve (les salves paires sont décalées d'un demi-écart).
func volley_dirs(offset := false) -> Array:
	var n: int = PHASES[phase]["feathers"]
	var out: Array = []
	var shift := 0.5 if offset else 0.0
	for i in n:
		out.append(Vector2.from_angle(aim.angle() + (i - (n - 1) / 2.0 + shift) * FEATHER["spread"]))
	return out


func _fire_volley(offset: bool) -> void:
	for dir in volley_dirs(offset):
		feathers.append({"pos": anchor + dir * radius * 0.8 + Vector2(0, -RADIUS * HOVER * 0.5), "vel": dir * FEATHER["speed"]})


## Le piqué, étape par étape. L'ombre suit le joueur, se fige, puis il tombe dessus.
func _dive_step(delta: float) -> void:
	var p = main.player
	dive_t -= delta * (cadence() if dive_step in ["suit", "fige"] else 1.0)
	match dive_step:
		"envol":
			dive_target = p.position
			if dive_t <= 0.0:
				dive_step = "suit"
				dive_t = DIVE["track"]
		"suit":
			# L'ombre suit le joueur, un peu en retard, sans sortir de l'arène.
			dive_target = dive_target.lerp(p.position, 1.0 - exp(-4.0 * delta))
			var rel: Vector2 = dive_target - arena.center
			dive_target = arena.center + rel.limit_length(arena.radius - DIVE["radius"] * 0.5)
			if dive_t <= 0.0:
				dive_step = "fige"
				dive_t = DIVE["lock"]
		"fige":
			if dive_t <= 0.0:
				dive_step = "chute"
				dive_t = DIVE["fall"]
				anchor = dive_target
		"chute":
			if dive_t <= 0.0:
				dive_step = "pose"
				dive_t = DIVE["ground"]
				radius = body_radius
				main.fx.ring(anchor, 20.0, DIVE["radius"] * 1.3, 0.4, Color(Art.ec("vent", "clair"), 0.9), 6.0)
				main.fx.shake(0.35)
				if p.position.distance_to(anchor) < DIVE["radius"] + p.radius * 0.5 and p.invuln <= 0.0:
					p.take_hit(DIVE["damage"] * damage_scale, self)
		"pose":
			if dive_t <= 0.0:
				dive_step = "retour"
				dive_t = DIVE["back"]
		"retour":
			var k := 1.0 - clampf(dive_t / DIVE["back"], 0.0, 1.0)
			anchor = anchor.lerp(home, Anim.ease_out(k))
			if dive_t <= 0.0:
				anchor = home
				_end_attack()


func _end_attack() -> void:
	attack = ""
	stage = ""
	dive_step = ""
	radius = body_radius
	gap = PHASES[phase]["gap"]


func _update_feathers(delta: float) -> void:
	if feathers.is_empty():
		return
	var p = main.player
	var limit: float = arena.radius + 30.0
	var wind = Wind.active
	var kept: Array = []
	for f in feathers:
		if wind != null:
			f["vel"] += wind.accel_at(f["pos"]) * delta
		f["pos"] += f["vel"] * delta
		var pos: Vector2 = f["pos"]
		if pos.distance_to(p.position) < FEATHER["radius"] + p.radius and p.invuln <= 0.0:
			p.take_hit(FEATHER["damage"] * damage_scale, self)
			continue
		if pos.distance_squared_to(arena.center) < limit * limit:
			kept.append(f)
	feathers = kept


## Tornades : elles errent vers le joueur en ondulant, blessent et repoussent à leur contact.
func _update_tornadoes(delta: float) -> void:
	if tornadoes.is_empty():
		return
	var p = main.player
	var kept: Array = []
	for tw in tornadoes:
		tw["life"] -= delta
		if tw["life"] <= 0.0:
			continue
		var to: Vector2 = p.position - tw["pos"]
		var want: Vector2 = to.normalized().rotated(0.9 * sin(t * 1.3 + tw["seed"])) * STORM["speed"]
		tw["vel"] = (tw["vel"] as Vector2).lerp(want, 1.0 - exp(-1.5 * delta))
		tw["pos"] += tw["vel"] * delta
		var rel: Vector2 = tw["pos"] - arena.center
		tw["pos"] = arena.center + rel.limit_length(arena.radius - STORM["radius"])
		tw["tick"] -= delta
		var d: float = to.length()
		if d < STORM["radius"] + p.radius:
			if p.dash_time <= 0.0:
				p.position += (to.normalized().orthogonal() + to.normalized() * 0.6).normalized() * STORM["push"] * delta
			if tw["tick"] <= 0.0 and p.invuln <= 0.0:
				tw["tick"] = STORM["tick"]
				p.take_hit(STORM["damage"] * damage_scale, self)
		kept.append(tw)
	tornadoes = kept


func _enter_phase(n: int) -> void:
	phase = n
	transition = PHASE_PAUSE
	cycle = 0
	gap = 0.3
	main.fx.ring(anchor, radius, 440.0, 0.7, Color(Art.ec("vent", "clair"), 0.9), 8.0)
	if n == 2:
		main.hud.banner("Le Harfang de cendre prend son envol.", "combat")
	else:
		main.hud.banner("Le Harfang de cendre déchaîne la tempête !", "combat")


func danger_time(pos: Vector2, margin := 26.0) -> float:
	var best := INF
	for f in feathers:
		var v: Vector2 = f["vel"]
		var u := clampf((pos - f["pos"]).dot(v) / v.length_squared(), 0.0, 1.5)
		if (f["pos"] + v * u).distance_to(pos) < FEATHER["radius"] + margin:
			best = minf(best, u)
	for tw in tornadoes:
		if pos.distance_to(tw["pos"]) < STORM["radius"] + margin + 30.0:
			best = minf(best, 0.0)
	for s in storm_spots:
		if pos.distance_to(s) < STORM["radius"] + margin:
			best = minf(best, timer)
	var to := pos - anchor
	var d := to.length()
	if attack == "plumes":
		var wait := timer if stage == "annonce" else maxf(volley_timer, 0.0)
		for offset in [false, true]:
			for dir in volley_dirs(offset):
				var along := to.dot(dir)
				if along > 0.0 and absf(to.dot(dir.orthogonal())) < FEATHER["radius"] + margin:
					best = minf(best, wait + along / FEATHER["speed"])
	if attack == "battement" and stage == "annonce" and d < BEAT["radius"] + margin:
		best = minf(best, timer)
	if attack == "pique" and dive_step in ["envol", "suit", "fige", "chute"]:
		if pos.distance_to(dive_target) < DIVE["radius"] + margin:
			var left := dive_t
			if dive_step == "envol":
				left += DIVE["track"] + DIVE["lock"] + DIVE["fall"]
			elif dive_step == "suit":
				left += DIVE["lock"] + DIVE["fall"]
			elif dive_step == "fige":
				left += DIVE["fall"]
			best = minf(best, left)
	if radius > 0.0 and d < radius + margin + 20.0:
		best = minf(best, 0.0)
	return best


func _clear_attacks() -> void:
	attack = ""
	stage = ""
	dive_step = ""
	feathers = []
	tornadoes = []
	storm_spots = []
	nest = []
	push_left = 0.0
	swirl = 0.0
	radius = body_radius


## Le robot reste hors du battement d'ailes.
func bot_ring(arena_radius: float) -> float:
	var ring := minf(240.0, arena_radius - 60.0)
	if attack == "battement":
		ring = minf(BEAT["radius"] + 60.0, arena_radius - 50.0)
	return ring


# --- Dessin ---
#
# Charte graphique : les Flétris sont anguleux, en volume, contour clair, braise dans les fentes.
# Le Harfang est un grand rapace de cendre vu de face, ailes ouvertes : plumage d'ardoise barré de
# chevrons, disque facial pâle, deux grands yeux de braise. Phase 2 : bords des ailes qui couvent ;
# phase 3 : rémiges en braise, cendres qui s'envolent.

## Aile du côté sgn (-1 gauche, 1 droite), en coordonnées locales du corps (y vers le bas) ;
## flap : battement (radians), fold : repli (0 ouverte, 1 repliée), torn : plumes déchirées (phase 3).
static func wing_shape(r: float, sgn: float, flap: float, fold: float, torn: float) -> PackedVector2Array:
	var span := lerpf(1.0, 0.35, fold)
	var pts := PackedVector2Array()
	var shoulder := Vector2(0.32 * sgn, -0.35) * r
	pts.append(shoulder)
	pts.append(Vector2(1.15 * sgn * span, -0.78 - 0.1 * fold) * r)
	pts.append(Vector2(2.25 * sgn * span, -0.42 + 0.3 * fold) * r)
	# Rémiges : cinq doigts le long du bord de fuite, du bout de l'aile vers le corps.
	for i in 5:
		var u := i / 4.0
		var base := Vector2(lerpf(2.2, 0.75, u) * sgn * span, lerpf(-0.2, 0.42, u) + 0.25 * fold) * r
		var tip := base + Vector2(0.08 * sgn, 0.34 - 0.12 * torn * float(i % 2)) * r
		pts.append(tip)
		pts.append(base + Vector2(-0.16 * sgn * span, 0.06) * r)
	pts.append(Vector2(0.38 * sgn, 0.35) * r)
	# Battement : l'aile tourne autour de l'épaule.
	var out := PackedVector2Array()
	for q in pts:
		out.append(shoulder + (q - shoulder).rotated(flap * sgn))
	return out


func _draw() -> void:
	var wake := 1.0 - clampf(intro / INTRO, 0.0, 1.0)
	var dk := clampf(dying / DEATH_TIME, 0.0, 1.0) if dead else 0.0
	var r := RADIUS
	var alt := r * HOVER + r * 0.08 * sin(t * 2.4)
	var fold := 0.0
	var flap := 0.32 * sin(t * (3.2 + 1.2 * (phase - 1)))
	var fade := 1.0
	var shadow := 1.0
	if attack == "pique":
		match dive_step:
			"envol":
				var k := 1.0 - clampf(dive_t / DIVE["rise"], 0.0, 1.0)
				alt += SKY * Anim.ease_in(k)
				flap = 0.55 * sin(t * 16.0)
				fade = 1.0 - Anim.ease_in(k)
				shadow = 1.0 - k
			"suit", "fige":
				fade = 0.0
				shadow = 0.0
			"chute":
				var k := 1.0 - clampf(dive_t / DIVE["fall"], 0.0, 1.0)
				alt = lerpf(SKY, r * 0.25, Anim.ease_in(k))
				fold = 1.0 - k * 0.6
				fade = k
				shadow = k
			"pose":
				alt = r * 0.25
				fold = 0.2
				flap = 0.1 * sin(t * 6.0)
			"retour":
				alt = lerpf(r * 0.25, r * HOVER, 1.0 - clampf(dive_t / DIVE["back"], 0.0, 1.0))
				flap = 0.45 * sin(t * 12.0)
	if attack == "battement":
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
		if stage == "annonce":
			# Il lève les ailes très haut avant de les rabattre.
			flap = -0.55 * Anim.ease_out(k) + 0.05 * sin(t * 30.0)
		else:
			flap = lerpf(-0.55, 0.6, Anim.ease_out(k))
	if dead:
		fold = Anim.ease_out(clampf(dk * 1.6, 0.0, 1.0))
		alt = lerpf(alt, r * 0.1, Anim.ease_in(clampf(dk * 1.3, 0.0, 1.0)))
		flap = 0.0
	var s := lerpf(0.35, 1.0, Anim.ease_out(wake)) * (1.0 - 0.15 * Anim.ease_in(dk))
	modulate.a = (1.0 - Anim.ease_in(clampf((dk - 0.6) / 0.4, 0.0, 1.0))) * (0.15 + 0.85 * fade)
	if shadow > 0.0:
		draw_colored_polygon(Art.ellipse(Vector2(0, r * 0.15), r * 1.7 * s * (0.6 + 0.4 * shadow), r * 0.55 * s * (0.6 + 0.4 * shadow), 24), Color(Art.c("ombre"), 0.35 * shadow))
	if fade <= 0.01:
		return
	# Tremblement pendant un changement de phase.
	var shift := Vector2(0, -alt)
	if transition > 0.0:
		shift += Vector2(sin(t * 50.0), cos(t * 43.0)) * 4.0
	draw_set_transform(shift, 0.0, Vector2(s, s))
	_paint_body(self, r, flap, fold, dk)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Le corps, les ailes et la tête, centrés sur le ventre (déjà décalés de l'altitude).
func _paint_body(c: CanvasItem, r: float, flap: float, fold: float, dk: float) -> void:
	var rage: float = [0.0, 0.5, 1.0][phase - 1]
	var contour := _color(Art.c("ennemi_contour"))
	var plumage := Art.c("ennemi").lerp(Art.c("brume"), 0.35).lerp(Art.ec("vent", "sombre"), 0.3)
	var pale := Art.c("brume").lerp(Art.ec("vent", "clair"), 0.35)
	var ember := Art.ec("cendre")
	var pulse := 0.5 + 0.5 * sin(t * (3.0 + 4.0 * rage))
	# Ailes, en volume, bord de fuite qui couve en phase 2 et brûle en phase 3.
	for sgn in [-1.0, 1.0]:
		var w := wing_shape(r, sgn, flap, fold, rage)
		Art.volume(c, w, _color(plumage.darkened(0.12)), 0.5)
		Art.outline(c, w, contour, Art.TRAIT)
		# Barres claires des couvertures (chevrons du harfang), et rémiges.
		for i in 3:
			var u := (i + 1) / 4.0
			var a := w[0].lerp(w[2], u * 0.9)
			var b := a + Vector2(0.0, 0.32 * r).rotated(flap * sgn)
			c.draw_line(a, b, _color(pale.darkened(0.15)), 3.0, true)
		for i in 5:
			var tip: Vector2 = w[3 + i * 2]
			var base: Vector2 = w[4 + i * 2]
			if rage > 0.0:
				c.draw_line(base, tip, Color(ember, (0.25 + 0.5 * rage) * (0.7 + 0.3 * pulse) * (1.0 - dk)), 3.0, true)
	# Serres d'os sous le ventre.
	for sgn in [-1.0, 1.0]:
		var foot := Vector2(0.22 * sgn, 0.7) * r
		for j in 3:
			var d := Vector2((j - 1) * 0.35 + 0.15 * sgn, 1.0).normalized()
			var tip := foot + d * r * 0.28
			var side := d.orthogonal() * r * 0.06
			c.draw_colored_polygon(PackedVector2Array([foot + side, tip, foot - side]), _color(Art.ec("epine", "clair").darkened(0.15)))
	# Corps : un œuf de plumes, ventre pâle barré de chevrons.
	var body := Art.ellipse(Vector2(0, -0.05 * r), r * 0.62, r * 0.85, 22)
	Art.volume(c, body, _color(plumage), 0.6)
	var belly := Art.ellipse(Vector2(0, 0.12 * r), r * 0.4, r * 0.58, 18)
	c.draw_colored_polygon(belly, _color(pale.darkened(0.08)))
	for row in 3:
		for col in 3 - row % 2:
			var p := Vector2((col - (2 - row % 2) / 2.0) * r * 0.22, (-0.15 + row * 0.22) * r)
			c.draw_polyline(PackedVector2Array([p + Vector2(-0.07, -0.04) * r, p, p + Vector2(0.07, -0.04) * r]), _color(plumage.darkened(0.2)), 2.0, true)
	Art.outline(c, body, contour, Art.TRAIT)
	# Tête : disque facial pâle, deux aigrettes, deux grands yeux de braise, bec d'os.
	var head := Vector2(0, -0.92 * r)
	for sgn in [-1.0, 1.0]:
		var base := head + Vector2(0.3 * sgn, -0.3) * r
		var tip := base + Vector2(0.18 * sgn, -0.42) * r
		var side := Vector2(0.09, 0.0) * r
		c.draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), _color(plumage.darkened(0.25)))
	var skull := Art.ellipse(head, r * 0.5, r * 0.44, 20)
	Art.volume(c, skull, _color(plumage.lightened(0.04)), 0.6)
	Art.outline(c, skull, contour, Art.TRAIT)
	for sgn in [-1.0, 1.0]:
		c.draw_colored_polygon(Art.ellipse(head + Vector2(0.2 * sgn, 0.02 * r), r * 0.2, r * 0.22, 14), _color(pale))
	var glare := 0.4 + (0.45 if stage == "annonce" or dive_step in ["chute", "pose"] else 0.0)
	var eye_col := Art.c("ennemi_oeil")
	for sgn in [-1.0, 1.0]:
		var e := head + Vector2(0.2 * sgn * r, 0.02 * r)
		c.draw_circle(e, r * 0.17, Color(eye_col, glare * 0.45 * (1.0 - dk)))
		c.draw_circle(e, r * 0.11, _color(eye_col.lerp(ember, 0.3 * rage)))
		# Pupille fendue en biais, qui se ferme à la mort.
		c.draw_line(e + Vector2(-0.07 * sgn, -0.08) * r, e + Vector2(0.05 * sgn, 0.08) * r, Art.c("contour"), lerpf(3.5, 1.0, dk), true)
	var beak := PackedVector2Array([head + Vector2(-0.07, 0.12) * r, head + Vector2(0, 0.34) * r, head + Vector2(0.07, 0.12) * r])
	c.draw_colored_polygon(beak, _color(Art.ec("epine", "clair").darkened(0.2)))
	Art.outline(c, beak, Color(Art.c("contour"), 0.8), Art.TRAIT_FIN)
	# Phase 3 et mort : des plumes de cendre s'arrachent et s'envolent.
	var flakes := 0 if phase < 3 and not dead else 9
	for i in flakes:
		var u := fposmod(t * 0.6 + i / 9.0, 1.0)
		var q := Vector2(sin(i * 2.4 + t) * r * 1.4, -r * (0.2 + 1.6 * u))
		FletriArt._flake(c, q, 4.0 * (1.0 - 0.5 * u), Color(Art.ec("cendre", "clair") if i % 3 == 0 else FletriArt.ash_color(), 1.0 - u))
	# États visibles : motifs des éléments (charte, § 3).
	if statuses.has("saignement"):
		Art.status(c, "saignement", Vector2.ZERO, r * 0.7, t * 1.25)
	if statuses.has("enracine"):
		Art.status(c, "racine", Vector2(0, r * 0.3), r * 0.9, t)
	if poison_time > 0.0:
		Art.status(c, "poison", Vector2.ZERO, r * 0.7, t)
	if dead and dk > 0.5:
		Art.glow(c, Vector2.ZERO, r * 0.9 * Anim.ease_out((dk - 0.5) / 0.5), "seve")


## Annonces au sol, en coordonnées monde (Art.telegraph). La nuée (qui ne blesse pas) n'est pas
## en rouge ; le vent tournant de la phase 3 est en traits clairs du vent.
func draw_marks(c: CanvasItem) -> void:
	if dead:
		return
	if swirl > 0.0:
		for i in 6:
			var a := -t * 0.8 + i * TAU / 6.0
			c.draw_arc(arena.center, arena.radius * 0.82, a, a + 0.5, 10, Color(Art.ec("vent", "clair"), 0.3 * swirl), Art.TRAIT, true)
	match attack:
		"plumes":
			var n: int = PHASES[phase]["feathers"]
			var reach: float = arena.radius + anchor.distance_to(arena.center)
			var cone := {"type": "cone", "centre": anchor, "direction": aim.angle(), "ouverture": (n - 1) * FEATHER["spread"] + 0.14, "rayon": reach}
			if stage == "annonce":
				var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
				Art.telegraph(c, cone, k, -1.0, t)
				for dir in volley_dirs():
					c.draw_line(anchor + dir * radius, anchor + dir * reach, Color(Art.c("danger"), 0.25 + 0.3 * k), 1.5, true)
			else:
				var since: float = stage_time - timer
				if since < 0.3:
					Art.telegraph(c, cone, 1.0, since / 0.3, t)
		"battement":
			var circle := {"type": "cercle", "centre": anchor, "rayon": BEAT["radius"]}
			if stage == "annonce":
				Art.telegraph(c, circle, 1.0 - clampf(timer / stage_time, 0.0, 1.0), -1.0, t)
			else:
				Art.telegraph(c, circle, 1.0, 1.0 - clampf(timer / stage_time, 0.0, 1.0), t)
		"pique":
			var circle := {"type": "cercle", "centre": dive_target, "rayon": DIVE["radius"]}
			match dive_step:
				"envol", "suit", "fige", "chute":
					var total: float = DIVE["rise"] + DIVE["track"] + DIVE["lock"] + DIVE["fall"]
					var left := dive_t
					if dive_step == "envol":
						left += DIVE["track"] + DIVE["lock"] + DIVE["fall"]
					elif dive_step == "suit":
						left += DIVE["lock"] + DIVE["fall"]
					elif dive_step == "fige":
						left += DIVE["fall"]
					var k := 1.0 - clampf(left / total, 0.0, 1.0)
					Art.telegraph(c, circle, k, -1.0, t)
					# Son ombre grandit à mesure qu'il descend.
					var sh := 0.35 + 0.65 * k
					c.draw_colored_polygon(Art.ellipse(dive_target, RADIUS * 1.6 * sh, RADIUS * 0.5 * sh, 20), Color(Art.c("ombre"), 0.25 + 0.3 * k))
				"pose":
					var since: float = DIVE["ground"] - dive_t
					if since < 0.3:
						Art.telegraph(c, circle, 1.0, since / 0.3, t)
		"nuee":
			var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
			var e := Art.ec("cendre")
			for b in nest:
				c.draw_arc(b, 30.0, 0.0, TAU, 28, Color(e, 0.25 + 0.4 * k), Art.TRAIT, true)
				c.draw_circle(b, 30.0 * k, Color(e, 0.1))
				# Une plume qui tourne et grandit au-dessus du sol.
				var d := Vector2.from_angle(t * 4.0 + b.x)
				c.draw_line(b - d * (6.0 + 10.0 * k), b + d * (6.0 + 10.0 * k), Art.ec("cendre", "clair"), 3.0, true)
		"tempete":
			var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
			for sp in storm_spots:
				Art.telegraph(c, {"type": "cercle", "centre": sp, "rayon": STORM["radius"]}, k, -1.0, t)
	for tw in tornadoes:
		var fadein := clampf((STORM["life"] - float(tw["life"])) / 0.4, 0.0, 1.0)
		Art.telegraph(c, {"type": "cercle", "centre": tw["pos"], "rayon": STORM["radius"]}, fadein, -1.0, t)


## Plumes et tornades, au-dessus des personnages, en coordonnées monde.
func draw_overlay(c: CanvasItem) -> void:
	var vane := Art.c("ennemi").lerp(Art.ec("vent", "sombre"), 0.4).lightened(0.1)
	for f in feathers:
		var pos: Vector2 = f["pos"]
		var dir: Vector2 = (f["vel"] as Vector2).normalized()
		var n := dir.orthogonal()
		c.draw_line(pos - dir * 30.0, pos - dir * 8.0, Color(Art.c("danger"), 0.35), 6.0, true)
		var pts := PackedVector2Array([pos + dir * 14.0, pos + dir * 5.0 + n * 6.0, pos - dir * 9.0 + n * 5.0, pos - dir * 14.0, pos - dir * 9.0 - n * 5.0, pos + dir * 5.0 - n * 6.0])
		Art.volume(c, pts, vane, 0.7)
		Art.outline(c, pts, Art.c("ennemi_contour"), 1.2)
		c.draw_line(pos - dir * 15.0, pos + dir * 14.0, Art.ec("epine", "clair").darkened(0.15), 1.8, true)
		c.draw_circle(pos + dir * 14.0, 2.6, Art.ec("cendre"))
	for tw in tornadoes:
		_draw_tornado(c, tw)


## Tornade : un entonnoir de traits du vent qui tournent, plus large en haut, avec des débris.
func _draw_tornado(c: CanvasItem, tw: Dictionary) -> void:
	var pos: Vector2 = tw["pos"]
	var life: float = tw["life"]
	var a := clampf(minf(life / 0.6, (STORM["life"] - life) / 0.4), 0.0, 1.0)
	var light := Art.ec("vent", "clair")
	var dark := Art.ec("vent", "sombre")
	for i in 7:
		var u := i / 6.0
		var y := -u * 120.0
		var rx := 14.0 + u * 46.0
		var sway := sin(t * 3.0 + u * 3.0 + float(tw["seed"])) * 10.0 * u
		var cen := pos + Vector2(sway, y)
		var spin := t * 7.0 + u * 2.0
		c.draw_arc(cen, rx, spin, spin + 3.6, 14, Color(dark, 0.55 * a), 5.0, true)
		c.draw_arc(cen, rx, spin + 0.4, spin + 3.2, 14, Color(light, 0.75 * a), Art.TRAIT, true)
	# Débris de cendre emportés.
	for i in 5:
		var k := fposmod(t * 0.9 + i / 5.0, 1.0)
		var ang := t * 6.0 + i * 1.3
		var q := pos + Vector2(cos(ang) * (16.0 + 40.0 * k), -110.0 * k + sin(ang) * 6.0)
		FletriArt._flake(c, q, 3.0, Color(FletriArt.ash_color(), a * (1.0 - k)))


# --- Dessinés par l'arène (boss_arena.gd), coordonnées de l'arène ---

## Le Harfang endormi : perché sur un rocher au centre de l'aire, ailes repliées, yeux clos.
static func draw_sleeper(a: Node2D) -> void:
	var r := RADIUS * 0.8
	var c: Vector2 = a.center
	var stone := Art.c("brume").lerp(Art.ec("vent", "sombre"), 0.35).darkened(0.15)
	var rock := PackedVector2Array([c + Vector2(-1.2, 0.3) * r, c + Vector2(-1.0, -0.35) * r, c + Vector2(-0.3, -0.6) * r, c + Vector2(0.5, -0.55) * r, c + Vector2(1.15, -0.2) * r, c + Vector2(1.2, 0.3) * r])
	a.draw_colored_polygon(Art.ellipse(c + Vector2(0, r * 0.3), r * 1.4, r * 0.4, 18), Color(Art.c("ombre"), 0.3))
	Art.volume(a, rock, stone, 0.5)
	Art.outline(a, rock, Color(Art.c("contour"), 0.7), Art.TRAIT)
	var plumage := Art.c("ennemi").lerp(Art.c("brume"), 0.35).lerp(Art.ec("vent", "sombre"), 0.3).darkened(0.25)
	var bird := c + Vector2(0, -r * 1.2)
	var body := Art.ellipse(bird, r * 0.55, r * 0.75, 18)
	Art.volume(a, body, plumage, 0.4)
	for sgn in [-1.0, 1.0]:
		var w := PackedVector2Array([bird + Vector2(0.35 * sgn, -0.5) * r, bird + Vector2(0.7 * sgn, 0.0) * r, bird + Vector2(0.5 * sgn, 0.75) * r, bird + Vector2(0.25 * sgn, 0.6) * r])
		Art.volume(a, w, plumage.darkened(0.12), 0.3)
	var head := bird + Vector2(0, -r * 0.8)
	a.draw_circle(head, r * 0.42, plumage)
	Art.outline(a, body, Color(Art.c("ennemi_contour"), 0.5), Art.TRAIT_FIN)
	var open: bool = a.state == "ouverte"
	for sgn in [-1.0, 1.0]:
		var e := head + Vector2(0.17 * sgn, 0.02) * r
		if open:
			a.draw_circle(e, r * 0.1, Color(Art.c("ennemi_oeil"), 0.45 + 0.35 * sin(a.t * 2.0)))
		a.draw_line(e - Vector2(0.1, 0) * r, e + Vector2(0.1, 0) * r, Art.c("contour"), 2.5, true)


## Après la victoire : un cercle de pierres levées couvertes de lichen, un jeune arbre couché par
## le vent au milieu, et des plumes claires dans l'herbe.
static func draw_victory(a: Node2D) -> void:
	var r := RADIUS
	var c: Vector2 = a.center
	var stone := Art.c("brume").lerp(Art.ec("vent", "sombre"), 0.3)
	var moss := Art.c("decor_vivant").lerp(Art.c("or"), 0.15)
	for i in 6:
		var p := c + Vector2.from_angle(TAU * i / 6.0 + 0.3) * r * 1.6 * Vector2(1.0, 0.6)
		var pts := PackedVector2Array([p + Vector2(-9, 4), p + Vector2(-10, -30), p + Vector2(-2, -42), p + Vector2(9, -34), p + Vector2(10, 4)])
		Art.volume(a, pts, stone, 0.5)
		Art.outline(a, pts, Color(Art.c("contour"), 0.6), Art.TRAIT_FIN)
		a.draw_colored_polygon(Art.ellipse(p + Vector2(-2, -26), 6.0, 3.0, 10), moss)
	# Jeune arbre couché par le vent, en fleurs claires.
	var bark := Art.ec("racine", "sombre").lerp(Art.c("decor_vivant"), 0.25)
	var knee := c + Vector2(8, -40)
	var top := knee + Vector2(46, -26)
	a.draw_line(c, knee, bark, 9.0, true)
	a.draw_line(knee, top, bark, 6.0, true)
	for i in 5:
		var p := top + Vector2(-34 + i * 16, -6 + 10 * (i % 2))
		Art.volume_circle(a, p, 15.0, moss.darkened(0.08 * (i % 3)), 0.7)
		a.draw_circle(p + Vector2(4, -6), 3.0, Art.ec("vent", "clair"))
	for i in 4:
		var p := c + Vector2.from_angle(i * 1.7) * r * 0.9
		a.draw_line(p, p + Vector2.from_angle(i * 2.1) * 12.0, Art.ec("vent", "clair"), 3.0, true)
