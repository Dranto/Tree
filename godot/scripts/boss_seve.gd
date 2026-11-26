## Le Saule exsangue, boss de la région de Sève : un saule pleureur flétri planté au milieu de son
## étang, qui boit la vie de la vallée. Nommé dans data/regions/seve.json › boss.
##
## Trois phases (100–66 %, 66–33 %, 33–0 % de sa vie). Chaque coup est annoncé avant de frapper
## (Art.telegraph, charte § 6) et ses rideaux de branches se soulèvent ou frémissent pendant
## l'annonce. Il boit : tout coup qu'il porte lui rend de la vie (« drain »), un texte vert le dit.
##   - racines  : des cercles se marquent sous le joueur, puis des racines-siphons en jaillissent
##                (sortir des cercles) ;
##   - rideau   : il balaie devant lui de ses branches (cône au sol vers le joueur) : passer derrière
##                ou reculer ;
##   - graines  : un éventail de graines lourdes tiré vers le joueur, deux ou trois fois ;
##   - siphon   (dès la phase 2) : un grand cercle autour de lui ; il y boit tout ce qui reste
##                dedans pendant deux secondes : s'éloigner ;
##   - invocation (dès la phase 2) : des Sangsues de vase sortent de l'étang (pas en rouge : ce n'est
##                pas un coup) ;
##   - phase 3 : l'étang se vide et l'arène se resserre (boss_arena.gd) ; plus de racines à la fois.
## Sa mort : les rideaux tombent, le tronc se fend et rend l'eau bue ; à sa place, une source claire
## et un jeune saule (draw_victory).
##
## Le socle (vie, phases, états, mort, interface d'ennemi) est dans boss_base.gd.
extends BossBase

const PHASE_LIMITS := [0.66, 0.33]
## Par phase : pause entre deux attaques, ordre des attaques et ampleur.
const PHASES := {
	1: {"gap": 1.3, "order": ["racines", "graines", "rideau", "racines", "graines"], "roots": 3, "volleys": 2, "seeds": 7},
	2: {"gap": 1.1, "order": ["graines", "invocation", "racines", "siphon", "rideau"], "roots": 4, "volleys": 2, "seeds": 9, "minions": 2},
	3: {"gap": 0.9, "order": ["racines", "rideau", "siphon", "graines", "invocation", "racines"], "roots": 5, "volleys": 3, "seeds": 9, "minions": 2},
}
const ROOTS := {"annonce": 1.0, "radius": 64.0, "spread": 180.0, "damage": 18.0, "flash": 0.35}
const CURTAIN := {"annonce": 0.95, "radius": 330.0, "opening": 1.5, "damage": 22.0, "flash": 0.3}
const SEEDS := {"annonce": 0.85, "between": 0.42, "damage": 12.0, "speed": 290.0, "radius": 10.0, "spread": 0.18}
const SIPHON := {"annonce": 1.1, "radius": 220.0, "duration": 2.0, "tick": 0.5, "dps": 14.0}
const SUMMON := {"annonce": 1.0, "max_alive": 4, "kind": "sangsue_vase"}
## Part des dégâts portés qu'il reprend en vie.
const DRAIN := 2.0
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
## Graines en vol : {"pos", "vel"}.
var seeds: Array = []
## Cercles des racines de l'attaque en cours (positions).
var roots: Array = []
## Éclair de la dernière frappe (racines, rideau), de 0 à sa durée ; -1 : aucun.
var strike_flash := -1.0
var flash_kind := ""
var _siphon_tick := 0.0
## Bourgeons de l'invocation en cours (positions).
var buds: Array = []


func _setup() -> void:
	body_radius = 74.0
	intro_time = 1.4
	death_time = 1.9
	# Moins de vie que l'Amanite-Mère : il en reprend à chaque coup porté.
	base_hp = 460.0
	hp_per_level = 150.0
	damage_per_level = 0.03
	contact_damage = 16.0
	phase_limits = PHASE_LIMITS
	color = Color("2c3a30")


func _projectiles_step(delta: float) -> void:
	_update_seeds(delta)
	if strike_flash >= 0.0:
		strike_flash += delta
		if strike_flash > 0.35:
			strike_flash = -1.0
			if attack == "":
				roots = []


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


## Il boit : tout coup porté au joueur lui rend DRAIN fois les dégâts (sans dépasser sa vie).
func _hurt_player(amount: float) -> void:
	var p = main.player
	if p.invuln > 0.0 or p.hp <= 0.0:
		return
	var before: float = p.hp
	p.take_hit(amount, self)
	var dealt: float = maxf(0.0, before - p.hp)
	if dealt > 0.0 and not dead:
		var gain := dealt * DRAIN
		hp = minf(max_hp, hp + gain)
		main.fx.text(anchor + Vector2(0, -radius * 2.3), "+%d" % roundi(gain), Art.ec("seve", "clair"), 16, 0.7)


# --- Attaques ---

func _begin(kind: String) -> void:
	var cfg: Dictionary = PHASES[phase]
	if kind == "invocation" and minions.size() >= SUMMON["max_alive"]:
		kind = "graines"
	attack = kind
	stage = "annonce"
	Sfx.play("annonce", anchor)
	var to: Vector2 = main.player.position - anchor
	aim = to.normalized() if to.length() > 1.0 else Vector2.DOWN
	match kind:
		"racines":
			_set_timer(ROOTS["annonce"])
			roots = []
			var p: Vector2 = main.player.position
			for i in int(cfg["roots"]):
				var at := p
				if i > 0:
					at = p + Vector2.from_angle(TAU * i / float(cfg["roots"]) + randf() * 0.6) * randf_range(0.55, 1.0) * ROOTS["spread"]
				roots.append(_in_arena(at, ROOTS["radius"] * 0.5))
		"rideau":
			_set_timer(CURTAIN["annonce"])
		"graines":
			_set_timer(SEEDS["annonce"])
		"siphon":
			_set_timer(SIPHON["annonce"])
		"invocation":
			_set_timer(SUMMON["annonce"])
			buds = []
			var n: int = cfg.get("minions", 3)
			for i in n:
				var a := aim.angle() + PI + (i - (n - 1) / 2.0) * 0.7
				buds.append(anchor + Vector2.from_angle(a) * 170.0)


func _set_timer(v: float) -> void:
	timer = v
	stage_time = v


## Garde un point dans l'arène (à « margin » du bord).
func _in_arena(p: Vector2, margin: float) -> Vector2:
	var to: Vector2 = p - arena.center
	var lim: float = maxf(40.0, arena.radius - margin)
	return arena.center + to.limit_length(lim)


## Pendant l'annonce, le rideau et les graines suivent le joueur, puis se verrouillent.
func _announce_step() -> void:
	if attack in ["rideau", "graines"] and timer > stage_time * 0.4:
		var to: Vector2 = main.player.position - anchor
		if to.length() > 1.0:
			aim = to.normalized()


func _strike() -> void:
	stage = "frappe"
	var p = main.player
	match attack:
		"racines":
			for c in roots:
				if p.position.distance_to(c) < ROOTS["radius"] + p.radius * 0.5:
					_hurt_player(ROOTS["damage"] * damage_scale)
					break
			for c in roots:
				main.fx.ring(c, 8.0, ROOTS["radius"], 0.3, Color(Art.ec("seve", "clair"), 0.8), 4.0)
			strike_flash = 0.0
			flash_kind = "racines"
			main.fx.shake(3.0)
			_end_attack()
		"rideau":
			if _in_curtain(p.position, p.radius * 0.5):
				_hurt_player(CURTAIN["damage"] * damage_scale)
			strike_flash = 0.0
			flash_kind = "rideau"
			main.fx.shake(4.0)
			_end_attack()
		"graines":
			volleys_left = PHASES[phase]["volleys"]
			volley_timer = 0.0
			_set_timer(SEEDS["between"] * volleys_left)
		"siphon":
			_siphon_tick = 0.0
			_set_timer(SIPHON["duration"])
		"invocation":
			for b in buds:
				minions.append(main.spawn_enemy_kind(SUMMON["kind"], b, main.threat(b)))
				main.fx.ring(b, 6.0, 46.0, 0.35, Color(Art.ec("seve", "clair"), 0.8), 3.0)
			buds = []
			_end_attack()


func _strike_step(delta: float) -> void:
	match attack:
		"graines":
			volley_timer -= delta
			if volleys_left > 0 and volley_timer <= 0.0:
				volley_timer = SEEDS["between"]
				for dir in seed_dirs(volleys_left % 2 == 0):
					seeds.append({"pos": anchor + dir * radius * 0.8 + Vector2(0, -radius * 0.6), "vel": dir * SEEDS["speed"]})
				volleys_left -= 1
		"siphon":
			_siphon_tick -= delta
			if _siphon_tick <= 0.0:
				_siphon_tick = SIPHON["tick"]
				var p = main.player
				if p.position.distance_to(anchor) < SIPHON["radius"] + p.radius * 0.3:
					_hurt_player(SIPHON["dps"] * SIPHON["tick"] * damage_scale * 2.0)


## Directions des graines d'une salve (les salves paires sont décalées d'un demi-écart).
func seed_dirs(offset := false) -> Array:
	var n: int = PHASES[phase]["seeds"]
	var out: Array = []
	var shift := 0.5 if offset else 0.0
	for i in n:
		out.append(Vector2.from_angle(aim.angle() + (i - (n - 1) / 2.0 + shift) * SEEDS["spread"]))
	return out


func _in_curtain(pos: Vector2, margin: float) -> bool:
	var to := pos - anchor
	if to.length() > CURTAIN["radius"] + margin:
		return false
	return absf(angle_difference(aim.angle(), to.angle())) < CURTAIN["opening"] * 0.5 + margin / maxf(to.length(), 1.0)


func _end_attack() -> void:
	attack = ""
	stage = ""
	gap = PHASES[phase]["gap"]


func _update_seeds(delta: float) -> void:
	if seeds.is_empty():
		return
	var p = main.player
	var limit: float = arena.radius + 30.0
	var kept: Array = []
	for s in seeds:
		s["pos"] += s["vel"] * delta
		var pos: Vector2 = s["pos"]
		if pos.distance_to(p.position) < SEEDS["radius"] + p.radius and p.invuln <= 0.0:
			_hurt_player(SEEDS["damage"] * damage_scale)
			continue
		if pos.distance_squared_to(arena.center) < limit * limit:
			kept.append(s)
	seeds = kept


func _enter_phase(n: int) -> void:
	phase = n
	transition = PHASE_PAUSE
	cycle = 0
	gap = 0.3
	main.fx.ring(anchor, radius, 420.0, 0.7, Color(Art.ec("seve", "clair"), 0.9), 8.0)
	if n != 2:
		arena.start_shrink()


## Temps avant qu'une attaque annoncée ou en cours touche ce point (INF si rien ne le menace).
func danger_time(pos: Vector2, margin := 26.0) -> float:
	var best := INF
	for s in seeds:
		var v: Vector2 = s["vel"]
		var u := clampf((pos - s["pos"]).dot(v) / v.length_squared(), 0.0, 1.5)
		if (s["pos"] + v * u).distance_to(pos) < SEEDS["radius"] + margin:
			best = minf(best, u)
	var to := pos - anchor
	var d := to.length()
	match attack:
		"racines":
			for c in roots:
				if pos.distance_to(c) < ROOTS["radius"] + margin:
					best = minf(best, timer)
		"rideau":
			if _in_curtain(pos, margin):
				best = minf(best, timer)
		"graines":
			var wait := timer if stage == "annonce" else maxf(volley_timer, 0.0)
			for offset in [false, true]:
				for dir in seed_dirs(offset):
					var along := to.dot(dir)
					if along > 0.0 and absf(to.dot(dir.orthogonal())) < SEEDS["radius"] + margin:
						best = minf(best, wait + along / SEEDS["speed"])
		"siphon":
			if d < SIPHON["radius"] + margin:
				best = minf(best, timer if stage == "annonce" else 0.0)
	if d < radius + margin + 20.0:
		best = minf(best, 0.0)
	return best


func _clear_attacks() -> void:
	attack = ""
	stage = ""
	seeds = []
	roots = []
	buds = []


## Le robot tourne autour de lui, hors du siphon quand il s'annonce.
func bot_ring(arena_radius: float) -> float:
	var ring := minf(250.0, arena_radius - 60.0)
	if attack == "siphon" and arena_radius - 50.0 > SIPHON["radius"] + 40.0:
		ring = SIPHON["radius"] + 45.0
	return ring


# --- Dessin ---
#
# Bestiaire d'herbier (refonte des personnages, B2) : le dessin est dans
# scripts/creature_art/seve/_saule_exsangue.gd (vue de trois quarts, encre fine, palette de Sève,
# braise = ennemi, sève verte = la vie bue), le saule-mère des Souches gorgées. Ici, la pose seulement :
# rideaux soulevés du côté visé, siphon, gousses des graines, racines allumées, phase 3 dégarnie,
# affaissement et cendre à la mort, regard tourné vers le joueur visé.

const Art_ = preload("res://scripts/creature_art/seve/_saule_exsangue.gd")
const BodyCache = preload("res://scripts/boss_body_cache.gd")

## Tourné vers la gauche (vers la dernière cible visée).
var face_left := false


## Avancée de l'annonce en cours (0 → 1), 0 hors annonce.
func _announce_k() -> float:
	if stage != "annonce" or stage_time <= 0.0:
		return 0.0
	return clampf(1.0 - timer / stage_time, 0.0, 1.0)


func pose() -> Dictionary:
	var k := _announce_k()
	if absf(aim.x) > 0.25:
		face_left = aim.x < 0.0
	# Le siphon agite les rideaux pendant toute la frappe.
	if attack == "siphon" and stage == "frappe":
		k = 1.0
	# Valeurs quantifiées : le corps est cuit une fois par pose (boss_body_cache.gd) ; les rideaux du
	# siphon s'agitent sur 4 images (« wig », 12 par seconde).
	return {"t": t, "k": snappedf(k, 0.25) if attack != "invocation" else 0.0, "attack": attack, "stage": stage if attack == "graines" else "", "phase": phase,
		"die": snappedf(clampf(dying / death_time, 0.0, 1.0), 0.1) if dead else 0.0, "aim": signf(aim.x) if attack == "rideau" else 0.0,
		"hit": 1.0 if hit_flash > 0.0 else 0.0, "poison": poison_time > 0.0,
		"ash": snappedf(Anim.ease_out(clampf(dying / death_time * 1.4, 0.0, 1.0)), 0.1) if dead else 0.0, "flip": face_left,
		"wig": int(t * 12.0) % 4 if attack == "siphon" else 0}


var _cache


func _draw() -> void:
	var h := Art_.HEIGHT * radius / 72.0
	if _cache == null:
		_cache = BodyCache.new(self, Rect2(Vector2(-0.92, -1.32) * h, Vector2(1.84, 1.68) * h), func(ci, p): Art_.draw(ci, Vector2.ZERO, h, p))
	# Respiration et balancement : la couronne se gonfle et le saule ploie doucement, autour des pieds.
	var live := 0.0 if dead else 1.0
	var b := sin(t * TAU / 3.6) * live
	var xf := Transform2D(0.0, Vector2(1.0 + 0.01 * b, 1.0 + 0.012 * b), 0.03 * sin(t * TAU / 5.3) * live, Vector2.ZERO)
	_cache.paint(self, Art_, h, Vector2(0, radius * 0.35), pose(), xf, frozen or BodyCache.headless())


## Annonces au sol, en coordonnées monde (grammaire de Art.telegraph). L'invocation, qui ne blesse
## pas, n'est pas en rouge.
func draw_marks(c: CanvasItem) -> void:
	var k := _announce_k()
	match attack:
		"racines":
			for p in roots:
				Art.telegraph(c, {"type": "cercle", "centre": p, "rayon": ROOTS["radius"]}, k, -1.0, t)
		"rideau":
			Art.telegraph(c, {"type": "cone", "centre": anchor, "direction": aim.angle(), "ouverture": CURTAIN["opening"], "rayon": CURTAIN["radius"]}, k, -1.0, t)
		"graines":
			if stage == "annonce":
				var n: int = PHASES[phase]["seeds"]
				Art.telegraph(c, {"type": "cone", "centre": anchor, "direction": aim.angle(), "ouverture": SEEDS["spread"] * n, "rayon": 360.0}, k, -1.0, t)
		"siphon":
			if stage == "annonce":
				Art.telegraph(c, {"type": "cercle", "centre": anchor, "rayon": SIPHON["radius"]}, k, -1.0, t)
			else:
				# Le siphon boit : le cercle reste rouge, des gouttes filent vers le tronc.
				var u := 1.0 - timer / SIPHON["duration"]
				Art.telegraph(c, {"type": "cercle", "centre": anchor, "rayon": SIPHON["radius"]}, 1.0, u, t)
				for i in 10:
					var a := TAU * i / 10.0 + t * 0.6
					var f := fposmod(t * 1.4 + i * 0.37, 1.0)
					c.draw_circle(anchor + Vector2.from_angle(a) * SIPHON["radius"] * (1.0 - f), 3.0, Color(Art.ec("saignement", "clair"), 0.8 * sin(PI * f)))
		"invocation":
			var col := Art.ec("seve", "clair")
			for b in buds:
				c.draw_arc(b, 30.0 - 12.0 * k, 0.0, TAU, 24, Color(col, 0.35 + 0.5 * k), Art.TRAIT, true)
				Art.volume_circle(c, b, 6.0 + 8.0 * k, Art.ec("seve", "sombre").lerp(Art.c("ennemi"), k), 0.7)
	if strike_flash >= 0.0:
		var f := strike_flash / 0.35
		if flash_kind == "racines":
			for p in roots:
				Art.telegraph(c, {"type": "cercle", "centre": p, "rayon": ROOTS["radius"]}, 1.0, f, t)
				# Racines-siphons qui jaillissent du cercle.
				for j in 3:
					var a := -PI / 2.0 + (j - 1) * 0.6
					c.draw_line(p, p + Vector2.from_angle(a) * ROOTS["radius"] * (0.9 - 0.5 * f), Art.c("ennemi").darkened(0.3), 5.0, true)
		elif flash_kind == "rideau":
			Art.telegraph(c, {"type": "cone", "centre": anchor, "direction": aim.angle(), "ouverture": CURTAIN["opening"], "rayon": CURTAIN["radius"]}, 1.0, f, t)


## Graines en vol, au-dessus des personnages, en coordonnées monde.
func draw_overlay(c: CanvasItem) -> void:
	var husk := Art.ec("racine", "sombre").lerp(Art.c("ennemi"), 0.3)
	for s in seeds:
		var p: Vector2 = s["pos"]
		var rr: float = SEEDS["radius"]
		var d: Vector2 = s["vel"].normalized()
		c.draw_circle(p, rr + 2.0, Art.c("contour"))
		Art.volume(c, Art.ellipse(p, rr * 1.2, rr * 0.8, 10), husk, 0.8)
		c.draw_line(p - d * rr * 0.6, p + d * rr * 0.6, Art.ec("saignement", "clair"), 2.0, true)


## Le Saule endormi : un saule bas aux rideaux immobiles, au milieu de l'étang.
static func draw_sleeper(a: Node2D) -> void:
	Art_.draw_sleeper(a, a.center + Vector2(0, 20.0), Art_.HEIGHT, a.t, a.state == "ouverte")


## Après la victoire : une source claire et un jeune saule, là où se tenait le Saule exsangue.
static func draw_victory(a: Node2D) -> void:
	Art_.draw_healed(a, a.center, 1.0, a.t)
