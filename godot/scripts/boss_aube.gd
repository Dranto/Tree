## La Phalène de verre, boss de la région d'Aube : une grande phalène flétrie aux ailes de verre
## fumé, qui plane au centre du cercle d'aiguilles des falaises et brise la lumière.
##
## Trois phases (100–66 %, 66–33 %, 33–0 % de sa vie). Chaque coup est annoncé avec Art.telegraph :
##   - écailles : éventail d'écailles de verre vers le joueur (une, puis deux salves) ;
##   - éclair : elle ouvre grand les ailes vers le joueur (cône au sol), puis jette un éclair de
##              lumière crue : le joueur pris est blessé et ébloui (player.gd › apply_dazzle) ;
##   - rayons (dès la phase 2) : ses ailes brisent la lumière en rayons qui partent d'elle en étoile
##              (couloirs au sol), deux salves décalées en phase 3 ;
##   - nuée (dès la phase 2) : des Lucioles flétries naissent autour d'elle (pas un coup : pas de rouge) ;
##   - pluie (phase 3) : des colonnes de lumière tombent du ciel autour du joueur (cercles au sol).
## Cycle 2 et après (New Game+, BossBase › cycle exalté) :
##   - balayage (attaque nouvelle) : un rayon de lumière part d'elle et balaie un grand arc (le cône
##               annoncé), d'un bord à l'autre : passer derrière elle, ou hors de l'arc ;
##   - phase 4 exaltée (« le vitrail se brise ») : le balayage revient aussitôt en sens inverse, et ses
##               salves de rayons sont plus fournies.
## Mort : ses ailes se fendent et tombent en éclats, la lumière d'aube remonte.
##
## Le socle commun (vie, phases, états, mort, interface d'ennemi) est dans boss_base.gd ; ce
## fichier ne décrit que ses attaques et son dessin. Nommé dans data/regions/aube.json › boss.
extends BossBase

const Enemy = preload("res://scripts/enemy.gd")
const A = preload("res://scripts/region_art/aube.gd")
const Phalene = preload("res://scripts/creature_art/aube/_phalene.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const PoseCache = preload("res://scripts/pose_cache.gd")

const RADIUS := 60.0
const INTRO := 1.6
const DEATH_TIME := 2.0
const BASE_HP := 620.0
const HP_PER_LEVEL := 200.0
const DAMAGE_PER_LEVEL := 0.03
const CONTACT_DAMAGE := 14.0
const PHASE_LIMITS := [0.66, 0.33]
## Par phase : pause entre deux attaques, ordre des attaques, et leur ampleur.
const PHASES := {
	1: {"gap": 1.6, "order": ["ecailles", "eclair", "ecailles"], "scales": 7, "volleys": 1, "beams": 3, "salvos": 1, "minions": 0, "pillars": 3},
	2: {"gap": 1.3, "order": ["ecailles", "rayons", "nuee", "eclair"], "scales": 9, "volleys": 2, "beams": 4, "salvos": 1, "minions": 4, "pillars": 3},
	3: {"gap": 1.0, "order": ["pluie", "rayons", "ecailles", "eclair", "pluie", "nuee"], "scales": 11, "volleys": 2, "beams": 5, "salvos": 2, "minions": 4, "pillars": 5},
	# Phase exaltée (cycle 2 et après seulement).
	4: {"gap": 0.9, "order": ["balayage", "pluie", "rayons", "balayage", "ecailles", "eclair", "nuee"], "scales": 11, "volleys": 2, "beams": 6, "salvos": 2, "minions": 4, "pillars": 5, "sweeps": 2},
}
## Attaque nouvelle du cycle exalté (BossBase).
const EXALTED_ATTACK := "balayage"
## Balayage : arc couvert (radians), durée d'un passage, largeur du rayon.
const SWEEP := {"annonce": 1.05, "frappe": 0.9, "arc": 2.2, "width": 30.0, "damage": 16.0}
const SCALE := {"annonce": 0.9, "between": 0.38, "damage": 12.0, "speed": 360.0, "radius": 8.0, "spread": 0.2}
const FLASH := {"annonce": 1.2, "frappe": 0.35, "range": 330.0, "cone": 1.3, "damage": 14.0, "dazzle": 2.2}
const BEAM := {"annonce": 1.15, "frappe": 0.4, "width": 34.0, "damage": 18.0}
const RAIN := {"annonce": 1.3, "frappe": 0.35, "radius": 70.0, "damage": 16.0, "spread": 230.0}
const SUMMON := {"annonce": 1.0, "max_alive": 6, "kind": "luciole"}
const PHASE_PAUSE := 1.5
const ROOTED_CADENCE := 0.6
const ROOT_IMMUNITY := 6.0
const BLEED_STACKS := 5
## Altitude du vol stationnaire (en rayons).
const HOVER := 0.8

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
## Écailles en vol : {"pos", "vel"}.
var scales: Array = []
## Rayons : directions de la salve en cours, et salves restantes.
var beams: Array = []
var salvos_left := 0
## Colonnes de lumière annoncées ou qui frappent (positions).
var pillars: Array = []
## Petits de la nuée annoncés (positions).
var nest: Array = []
## Balayage : angles de départ et d'arrivée du passage en cours, passages restants, déjà touché.
var sweep_from := 0.0
var sweep_to := 0.0
var sweeps_left := 0
var sweep_hit := false


func _setup() -> void:
	body_radius = RADIUS
	# Corps à l'écran (héros caché derrière : player.gd) : ailes de verre.
	cover = Vector2(2.2, 3.0)
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
	color = Color("5a5662")


func _projectiles_step(delta: float) -> void:
	_update_scales(delta)


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
			_after_strike()


# --- Attaques ---

func _begin(kind: String) -> void:
	if kind == "nuee" and minions.size() >= SUMMON["max_alive"]:
		kind = "ecailles"
	attack = kind
	stage = "annonce"
	Sfx.play("annonce", anchor)
	var to: Vector2 = main.player.position - anchor
	aim = to.normalized() if to.length() > 1.0 else Vector2.DOWN
	match kind:
		"ecailles":
			_set_timer(SCALE["annonce"])
		"eclair":
			_set_timer(FLASH["annonce"])
		"rayons":
			salvos_left = PHASES[phase]["salvos"]
			_announce_beams(false)
		"nuee":
			_set_timer(SUMMON["annonce"])
			nest = []
			var n: int = PHASES[phase]["minions"]
			for i in n:
				var a := aim.angle() + PI + (i - (n - 1) / 2.0) * 0.6
				nest.append(anchor + Vector2.from_angle(a) * 150.0)
		"pluie":
			_set_timer(RAIN["annonce"])
			pillars = rain_spots(main.player.position, PHASES[phase]["pillars"])
		"balayage":
			exalted_attacks += 1
			# Le rayon part sur un temps de la musique ; il va d'un bord de l'arc à l'autre, en
			# alternant le sens d'une fois sur l'autre.
			_set_timer(loop_snap(SWEEP["annonce"]))
			var side := 1.0 if cycle % 2 == 0 else -1.0
			sweep_from = aim.angle() - side * SWEEP["arc"] * 0.5
			sweep_to = aim.angle() + side * SWEEP["arc"] * 0.5
			sweeps_left = int(PHASES[phase].get("sweeps", 1))


func _set_timer(v: float) -> void:
	timer = v
	stage_time = v


## Une salve de rayons en étoile, l'un d'eux vers le joueur (la seconde salve est décalée d'un demi-écart).
func _announce_beams(offset: bool) -> void:
	stage = "annonce"
	_set_timer(BEAM["annonce"])
	var to: Vector2 = main.player.position - anchor
	if to.length() > 1.0:
		aim = to.normalized()
	beams = beam_dirs(PHASES[phase]["beams"], offset)


## Directions des rayons : n en étoile, en partant du joueur visé.
func beam_dirs(n: int, offset := false) -> Array:
	var out: Array = []
	var shift := 0.5 if offset else 0.0
	for i in n:
		out.append(Vector2.from_angle(aim.angle() + (i + shift) * TAU / n))
	return out


## Points d'impact de la pluie : un sur le joueur, les autres autour, dans l'arène.
func rain_spots(at: Vector2, n: int) -> Array:
	var out: Array = [_in_arena(at, RAIN["radius"])]
	for i in n - 1:
		var a := TAU * i / maxf(1.0, n - 1.0) + cycle * 0.7
		out.append(_in_arena(at + Vector2.from_angle(a) * RAIN["spread"] * (0.7 + 0.3 * (i % 2)), RAIN["radius"]))
	return out


func _in_arena(p: Vector2, margin: float) -> Vector2:
	var rel: Vector2 = p - arena.center
	return arena.center + rel.limit_length(arena.radius - margin)


## Pendant l'annonce, l'éventail et le cône suivent le joueur puis se verrouillent.
func _announce_step() -> void:
	if attack in ["ecailles", "eclair"] and timer > stage_time * 0.4:
		var to: Vector2 = main.player.position - anchor
		if to.length() > 1.0:
			aim = to.normalized()


func _strike() -> void:
	stage = "frappe"
	var p = main.player
	match attack:
		"ecailles":
			volleys_left = PHASES[phase]["volleys"]
			volley_timer = 0.0
			_set_timer(SCALE["between"] * volleys_left)
		"eclair":
			_set_timer(FLASH["frappe"])
			main.fx.ring(anchor, radius, FLASH["range"], 0.3, Color(A.pal("lumiere_clair"), 0.8), 6.0)
			if p.invuln <= 0.0 and in_flash(p.position, p.radius):
				p.take_hit(FLASH["damage"] * damage_scale, self)
				p.apply_dazzle(FLASH["dazzle"])
		"rayons":
			_set_timer(BEAM["frappe"])
			main.fx.shake(0.15)
			for d in beams:
				if p.invuln <= 0.0 and in_beam(d, p.position, p.radius):
					p.take_hit(BEAM["damage"] * damage_scale, self)
					break
		"nuee":
			var kind := Enemy.kind_index(SUMMON["kind"])
			for b in nest:
				if kind >= 0:
					minions.append(main.spawn_enemy_at(b, kind))
				main.fx.ring(b, 6.0, 40.0, 0.35, Color(A.pal("lumiere"), 0.8), 3.0)
			nest = []
			_end_attack()
		"balayage":
			_set_timer(SWEEP["frappe"])
			sweep_hit = false
			main.fx.shake(0.2)
			main.fx.ring(anchor, radius, radius * 3.0, 0.3, Color(A.pal("lumiere_clair"), 0.8), 5.0)
		"pluie":
			_set_timer(RAIN["frappe"])
			main.fx.shake(0.2)
			for c in pillars:
				main.fx.ring(c, 10.0, RAIN["radius"] * 1.2, 0.35, Color(A.pal("lumiere_clair"), 0.9), 5.0)
			for c in pillars:
				if p.invuln <= 0.0 and p.position.distance_to(c) < RAIN["radius"] + p.radius * 0.5:
					p.take_hit(RAIN["damage"] * damage_scale, self)
					break


## Direction du rayon du balayage à cet instant de la frappe.
func sweep_dir() -> Vector2:
	var k := 1.0 - clampf(timer / maxf(stage_time, 0.001), 0.0, 1.0)
	return Vector2.from_angle(lerp_angle(sweep_from, sweep_to, Anim.ease_in_out(k)))


func _strike_step(delta: float) -> void:
	if attack == "balayage":
		var p = main.player
		if not sweep_hit and p.invuln <= 0.0 and in_beam(sweep_dir(), p.position, p.radius * 0.5):
			sweep_hit = true
			p.take_hit(SWEEP["damage"] * damage_scale, self)
		return
	if attack == "ecailles":
		volley_timer -= delta
		if volleys_left > 0 and volley_timer <= 0.0:
			volley_timer = SCALE["between"]
			_fire_volley(volleys_left % 2 == 0)
			volleys_left -= 1


## Fin d'une frappe : une autre salve de rayons (phase 3), sinon la pause.
func _after_strike() -> void:
	if attack == "balayage":
		sweeps_left -= 1
		if sweeps_left > 0:
			# Phase exaltée : le rayon repart aussitôt dans l'autre sens.
			var a := sweep_from
			sweep_from = sweep_to
			sweep_to = a
			_set_timer(SWEEP["frappe"])
			sweep_hit = false
			return
	if attack == "rayons":
		salvos_left -= 1
		if salvos_left > 0:
			_announce_beams(true)
			return
	_end_attack()


## Vrai si un cercle (pos, r) est dans le cône de l'éclair.
func in_flash(pos: Vector2, r: float) -> bool:
	var to: Vector2 = pos - anchor
	var d := to.length()
	if d > FLASH["range"] + r:
		return false
	if d < radius + r:
		return true
	var half: float = FLASH["cone"] / 2.0 + asin(clampf(r / d, 0.0, 1.0))
	return absf(angle_difference(aim.angle(), to.angle())) <= half


## Vrai si un cercle (pos, r) est dans l'arc du balayage (jusqu'au mur de l'arène).
func in_sweep(pos: Vector2, r: float) -> bool:
	var to: Vector2 = pos - anchor
	var d := to.length()
	if d > beam_length() + r:
		return false
	if d < radius + r:
		return true
	var mid := lerp_angle(sweep_from, sweep_to, 0.5)
	var half: float = absf(angle_difference(sweep_from, sweep_to)) * 0.5 + asin(clampf(r / d, 0.0, 1.0))
	return absf(angle_difference(mid, to.angle())) <= half


## Vrai si un cercle (pos, r) est dans le couloir du rayon de direction d (jusqu'au mur de l'arène).
func in_beam(d: Vector2, pos: Vector2, r: float) -> bool:
	var to: Vector2 = pos - anchor
	var along := to.dot(d)
	if along < 0.0 or along > beam_length() + r:
		return false
	return absf(to.dot(d.orthogonal())) < BEAM["width"] / 2.0 + r


## Les rayons vont jusqu'au mur de l'arène, de l'autre côté.
func beam_length() -> float:
	return arena.radius + anchor.distance_to(arena.center)


## Directions des écailles d'une salve (les salves paires sont décalées d'un demi-écart).
func volley_dirs(offset := false) -> Array:
	var n: int = PHASES[phase]["scales"]
	var out: Array = []
	var shift := 0.5 if offset else 0.0
	for i in n:
		out.append(Vector2.from_angle(aim.angle() + (i - (n - 1) / 2.0 + shift) * SCALE["spread"]))
	return out


func _fire_volley(offset: bool) -> void:
	for dir in volley_dirs(offset):
		scales.append({"pos": anchor + dir * radius * 0.8 + Vector2(0, -RADIUS * HOVER * 0.5), "vel": dir * SCALE["speed"]})


func _end_attack() -> void:
	attack = ""
	stage = ""
	beams = []
	pillars = []
	salvos_left = 0
	sweeps_left = 0
	gap = PHASES[phase]["gap"]


func _update_scales(delta: float) -> void:
	if scales.is_empty():
		return
	var p = main.player
	var limit: float = arena.radius + 30.0
	var kept: Array = []
	for f in scales:
		f["pos"] += f["vel"] * delta
		var pos: Vector2 = f["pos"]
		if pos.distance_to(p.position) < SCALE["radius"] + p.radius and p.invuln <= 0.0:
			p.take_hit(SCALE["damage"] * damage_scale, self)
			continue
		if pos.distance_squared_to(arena.center) < limit * limit:
			kept.append(f)
	scales = kept


func _enter_phase(n: int) -> void:
	phase = n
	transition = PHASE_PAUSE
	cycle = 0
	gap = 0.3
	main.fx.ring(anchor, radius, 440.0, 0.7, Color(A.pal("lumiere_clair"), 0.9), 8.0)


func danger_time(pos: Vector2, margin := 26.0) -> float:
	var best := INF
	for f in scales:
		var v: Vector2 = f["vel"]
		var u := clampf((pos - f["pos"]).dot(v) / v.length_squared(), 0.0, 1.5)
		if (f["pos"] + v * u).distance_to(pos) < SCALE["radius"] + margin:
			best = minf(best, u)
	var to := pos - anchor
	var d := to.length()
	match attack:
		"ecailles":
			var wait := timer if stage == "annonce" else maxf(volley_timer, 0.0)
			for offset in [false, true]:
				for dir in volley_dirs(offset):
					var along := to.dot(dir)
					if along > 0.0 and absf(to.dot(dir.orthogonal())) < SCALE["radius"] + margin:
						best = minf(best, wait + along / SCALE["speed"])
		"eclair":
			if stage == "annonce" and in_flash(pos, margin):
				best = minf(best, timer)
		"rayons":
			for dir in beams:
				if in_beam(dir, pos, margin):
					best = minf(best, timer if stage == "annonce" else 0.0)
			if stage == "frappe" and salvos_left > 1:
				# La salve suivante, décalée : à éviter dès maintenant.
				for dir in beam_dirs(PHASES[phase]["beams"], true):
					if in_beam(dir, pos, margin):
						best = minf(best, timer + BEAM["annonce"])
		"pluie":
			if stage == "annonce":
				for c in pillars:
					if pos.distance_to(c) < RAIN["radius"] + margin:
						best = minf(best, timer)
		"balayage":
			if in_sweep(pos, margin):
				best = minf(best, timer if stage == "annonce" else 0.0)
	if radius > 0.0 and d < radius + margin + 20.0:
		best = minf(best, 0.0)
	return best


func _clear_attacks() -> void:
	attack = ""
	stage = ""
	scales = []
	beams = []
	pillars = []
	nest = []
	salvos_left = 0
	sweeps_left = 0


## Le robot recule hors de portée de l'éclair quand elle l'annonce.
func bot_ring(arena_radius: float) -> float:
	var ring := minf(240.0, arena_radius - 60.0)
	if attack == "eclair":
		ring = minf(FLASH["range"] + 50.0, arena_radius - 50.0)
	return ring


func _exalt_color() -> Color:
	return A.pal("lumiere_clair").lerp(Art.ec("saignement", "clair"), 0.45)


# --- Dessin ---
#
# « Bestiaire d'herbier » (refonte des personnages, vague 2) : la Phalène est une grande phalène de
# trois quarts, fourrure d'or et ailes de vitre, dessinée par scripts/creature_art/aube/_phalene.gd
# (encre commune avec le héros et les Flétris d'Aube, braise = ennemi), tournée vers le joueur.
# Le dessin direct coûte plusieurs ms : chaque animation est découpée en quelques images (TRACKS), et
# chaque image n'est dessinée qu'une fois (pose_cache.gd). Ce fichier choisit l'animation et l'image ;
# l'ombre et les états restent dessinés à chaque image.

## Hauteur du thorax au-dessus du centre du boss (px) : les rayons partent de là.
const BODY_Y := 76.0
## Repère qui contient toutes les poses du Phalène (pieds en 0, px du dessin), mesuré sur ses 3 phases,
## plus une marge : les poses sont rendues dans une image de cette taille (pose_cache.gd › bake_box).
const POSE_BOX := Rect2(-165, -224, 322, 331)

## Images par animation.
const TRACKS := {"vol": 12, "eclair": 8, "eclair_f": 6, "rayons": 6, "rayons_f": 6, "pluie": 8, "pluie_f": 6,
	"ecailles": 6, "nuee": 6, "mort": 16}
## Animations qui vont d'un bout à l'autre (pas en boucle).
const ONCE := ["eclair", "eclair_f", "rayons", "rayons_f", "pluie", "pluie_f", "ecailles", "nuee", "mort"]
## Écart minimal (px) avant de se retourner vers le joueur.
const TURN_MARGIN := 24.0
## Teinte du coup reçu (sur la pose déjà dessinée).
const HIT_TINT := Color(1.7, 1.5, 1.3)

var facing := 1.0
var _over: Node2D
var _body_at := Vector2.ZERO


func _beat_speed() -> float:
	return 5.0 + 1.5 * (phase - 1)


## Animation en cours et son avancement u (0 → 1).
func _track() -> Array:
	if dead:
		return ["mort", clampf(dying / DEATH_TIME, 0.0, 1.0)]
	var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
	var ann := stage == "annonce"
	match attack:
		"eclair":
			return ["eclair", k] if ann else ["eclair_f", k]
		"rayons":
			return ["rayons", k] if ann else ["rayons_f", k]
		"pluie":
			return ["pluie", k] if ann else ["pluie_f", k]
		"balayage":
			# Mêmes poses que les rayons (ailes ouvertes, lumière qui monte puis s'éteint).
			return ["rayons", k] if ann else ["rayons_f", k]
		"ecailles":
			if ann:
				return ["ecailles", k]
		"nuee":
			if ann:
				return ["nuee", k]
	return ["vol", fposmod(t * _beat_speed() / TAU, 1.0)]


## Pose du dessin (clés de _phalene.gd) pour l'image u d'une animation.
func pose_at(track: String, u: float) -> Dictionary:
	var rage: float = [0.0, 0.5, 1.0][mini(phase, 3) - 1]
	var o := {"rage": rage, "alt": 0.0, "beat": 0.15, "open": 1.0, "t": u}
	var tremble := sin(u * 40.0) * u
	match track:
		"vol":
			o["t"] = u * TAU / _beat_speed()
			o["beat"] = 0.15 + 0.45 * sin(TAU * u)
			o["open"] = 1.0 + 0.05 * sin(TAU * u)
		"eclair":
			o["open"] = lerpf(1.0, 1.25, Anim.ease_out(u))
			o["beat"] = lerpf(0.15, 0.35, u) + 0.04 * tremble
			o["glow"] = Anim.ease_in(u)
			o["k"] = u
		"eclair_f":
			o["t"] = 1.0 + u
			o["open"] = 1.25
			o["beat"] = 0.35
			o["glow"] = 1.0 - u
		"rayons":
			o["glow"] = 0.6 * u
			o["beat"] = lerpf(0.15, 0.7, u)
			o["k"] = u
		"rayons_f":
			o["t"] = 1.0 + u
			o["glow"] = 0.8 * (1.0 - u)
			o["beat"] = lerpf(0.7, 0.15, u)
		"pluie":
			o["beat"] = lerpf(0.15, 1.0, Anim.ease_out(u)) + 0.05 * tremble
			o["glow"] = 0.5 * u
			o["k"] = u
		"pluie_f":
			o["t"] = 1.0 + u
			o["beat"] = lerpf(1.0, -0.6, Anim.ease_out(u))
		"ecailles":
			o["beat"] = 0.2 + 0.6 * sin(u * 22.0) * u
			o["k"] = u
		"nuee":
			o["beat"] = 0.2 + 0.7 * sin(u * 18.0)
			o["k"] = 0.5 * u
		"mort":
			o["t"] = u * 2.0
			o["dk"] = u
			o["crack"] = Anim.ease_out(u)
			o["open"] = lerpf(1.0, 0.6, Anim.ease_out(clampf(u * 1.6, 0.0, 1.0)))
			o["beat"] = lerpf(0.15, -0.4, u)
	return o


func _draw() -> void:
	var wake := 1.0 - clampf(intro / INTRO, 0.0, 1.0)
	var dk := clampf(dying / DEATH_TIME, 0.0, 1.0) if dead else 0.0
	var r := RADIUS
	var art_h: float = Phalene.HEIGHT
	var feet := Vector2(0, r * 0.15)
	var body_y := BODY_Y + r * 0.1 * sin(t * 2.0)
	if dead:
		body_y = lerpf(body_y, art_h * 0.3, Anim.ease_in(clampf(dk * 1.3, 0.0, 1.0)))
	var s := lerpf(0.35, 1.0, Anim.ease_out(wake)) * (1.0 - 0.15 * Anim.ease_in(dk))
	modulate.a = 1.0 - Anim.ease_in(clampf((dk - 0.6) / 0.4, 0.0, 1.0))
	draw_colored_polygon(Art.ellipse(feet, r * 1.9 * s, r * 0.6 * s, 24), Color(Art.c("ombre"), 0.35))
	draw_exalt_aura(self, Vector2(0, -(BODY_Y + r * 0.1 * sin(t * 2.0)) * s), r * 1.5 * s)
	if main != null and main.player != null:
		var dx: float = main.player.position.x - position.x
		if absf(dx) > TURN_MARGIN:
			facing = signf(dx)
	var shift := Vector2.ZERO
	if transition > 0.0:
		shift += Vector2(sin(t * 50.0), cos(t * 43.0)) * 4.0
	var tr: Array = _track()
	var n: int = TRACKS[tr[0]]
	var i := clampi(int(tr[1] * n), 0, n - 1)
	var u := float(i) / maxf(1.0, n - 1.0) if tr[0] in ONCE else float(i) / n
	var o := pose_at(tr[0], u)
	o["look"] = 0.25
	# Retourné par le nœud (comme les sprites des Flétris) : une seule pose cuite pour les deux sens.
	var key := "%s/%d/%d" % [tr[0], i, mini(phase, 3)]
	var mod := _tint()
	if hit_flash > 0.0 and not dead:
		mod = mod * HIT_TINT
	var drawer := func(ci: CanvasItem) -> void:
		Phalene.draw(ci, Vector2.ZERO, art_h, o)
		Ink.flash = 0.0
		Ink.ash = 0.0
	# Le dessin est posé de sorte que le thorax soit à body_y au-dessus du centre (alt = 0 : thorax à
	# 30 unités au-dessus des pieds).
	var lift := body_y + feet.y - art_h * 0.3
	var cache := PoseCache.on(self)
	cache.bake_box = POSE_BOX
	cache.show_pose(key, drawer, Transform2D(0.0, Vector2(s * facing, s), 0.0, feet + shift + Vector2(0, -lift * s)), mod)
	_body_at = Vector2(0, -body_y * s)
	if _over == null:
		_over = Node2D.new()
		_over.draw.connect(_draw_over)
		add_child(_over)
	_over.queue_redraw()


## États visibles (motifs des éléments, charte § 3) et lueur de la mort, par-dessus le dessin.
func _draw_over() -> void:
	var r := RADIUS
	if statuses.has("saignement"):
		Art.status(_over, "saignement", _body_at, r * 0.7, t * 1.25)
	if statuses.has("enracine"):
		Art.status(_over, "racine", _body_at + Vector2(0, r * 0.3), r * 0.9, t)
	if poison_time > 0.0:
		Art.status(_over, "poison", _body_at, r * 0.7, t)
	var dk := clampf(dying / DEATH_TIME, 0.0, 1.0) if dead else 0.0
	if dead and dk > 0.5:
		Art.glow(_over, _body_at, r * 0.9 * Anim.ease_out((dk - 0.5) / 0.5), "seve")


## Teinte d'ensemble : poison (la cendre de la mort est dans le dessin, Ink.ash).
func _tint() -> Color:
	var c := Color.WHITE
	if poison_time > 0.0:
		c = c.lerp(Art.ec("poison", "clair"), 0.3)
	return c


## Annonces au sol, en coordonnées monde (Art.telegraph). La nuée (qui ne blesse pas) n'est pas
## en rouge.
func draw_marks(c: CanvasItem) -> void:
	if dead:
		return
	match attack:
		"ecailles":
			var n: int = PHASES[phase]["scales"]
			var reach: float = arena.radius + anchor.distance_to(arena.center)
			var cone := {"type": "cone", "centre": anchor, "direction": aim.angle(), "ouverture": (n - 1) * SCALE["spread"] + 0.14, "rayon": reach}
			if stage == "annonce":
				var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
				Art.telegraph(c, cone, k, -1.0, t)
				for dir in volley_dirs():
					c.draw_line(anchor + dir * radius, anchor + dir * reach, Color(Art.c("danger"), 0.25 + 0.3 * k), 1.5, true)
			else:
				var since: float = stage_time - timer
				if since < 0.3:
					Art.telegraph(c, cone, 1.0, since / 0.3, t)
		"eclair":
			var cone := {"type": "cone", "centre": anchor, "direction": aim.angle(), "ouverture": FLASH["cone"], "rayon": FLASH["range"]}
			if stage == "annonce":
				Art.telegraph(c, cone, 1.0 - clampf(timer / stage_time, 0.0, 1.0), -1.0, t)
			else:
				var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
				Art.telegraph(c, cone, 1.0, k, t)
				# L'éclair : un éventail de lumière blanche.
				var pts := PackedVector2Array([anchor])
				var half: float = FLASH["cone"] / 2.0
				for i in 11:
					pts.append(anchor + Vector2.from_angle(aim.angle() - half + 2.0 * half * i / 10.0) * FLASH["range"])
				c.draw_colored_polygon(pts, Color(1.0, 0.97, 0.86, 0.5 * (1.0 - k)))
		"rayons":
			var ln := beam_length()
			for d in beams:
				var line := {"type": "ligne", "de": anchor + d * radius, "a": anchor + d * ln, "largeur": BEAM["width"]}
				if stage == "annonce":
					Art.telegraph(c, line, 1.0 - clampf(timer / stage_time, 0.0, 1.0), -1.0, t)
				else:
					var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
					Art.telegraph(c, line, 1.0, k, t)
		"nuee":
			var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
			for b in nest:
				c.draw_arc(b, 26.0, 0.0, TAU, 24, Color(A.pal("lumiere"), 0.25 + 0.4 * k), Art.TRAIT, true)
				c.draw_circle(b, 26.0 * k, Color(A.pal("lumiere"), 0.12))
		"balayage":
			var cone := {"type": "cone", "centre": anchor, "direction": lerp_angle(sweep_from, sweep_to, 0.5), "ouverture": absf(angle_difference(sweep_from, sweep_to)), "rayon": beam_length()}
			if stage == "annonce":
				var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
				Art.telegraph(c, cone, k, -1.0, t)
				# Le bord où le rayon partira, plus marqué, et une flèche du sens.
				var d0 := Vector2.from_angle(sweep_from)
				c.draw_line(anchor + d0 * radius, anchor + d0 * beam_length(), Color(Art.c("danger"), 0.4 + 0.5 * k), 3.0, true)
				var mid := lerp_angle(sweep_from, sweep_to, 0.5)
				var r := beam_length() * 0.55
				c.draw_arc(anchor, r, sweep_from, sweep_from + angle_difference(sweep_from, mid), 16, Color(Art.c("danger"), 0.35 + 0.4 * k), 2.0, true)
			else:
				# Reste affiché pendant le passage (et le retour en phase exaltée).
				Art.telegraph(c, cone, 1.0, -1.0, t)
		"pluie":
			for p in pillars:
				var circle := {"type": "cercle", "centre": p, "rayon": RAIN["radius"]}
				if stage == "annonce":
					var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
					Art.telegraph(c, circle, k, -1.0, t)
					# Un rai de lumière qui s'épaissit au-dessus du point d'impact.
					c.draw_line(p, p + Vector2(0, -260.0), Color(A.pal("lumiere_clair"), 0.15 + 0.3 * k), 4.0 + 18.0 * k, true)
				else:
					Art.telegraph(c, circle, 1.0, 1.0 - clampf(timer / stage_time, 0.0, 1.0), t)


## Écailles, rayons et colonnes de lumière, au-dessus des personnages, en coordonnées monde.
func draw_overlay(c: CanvasItem) -> void:
	for f in scales:
		var pos: Vector2 = f["pos"]
		var dir: Vector2 = (f["vel"] as Vector2).normalized()
		var n := dir.orthogonal()
		c.draw_line(pos - dir * 28.0, pos - dir * 8.0, Color(Art.c("danger"), 0.35), 6.0, true)
		var pts := PackedVector2Array([pos + dir * 12.0, pos + n * 6.0, pos - dir * 9.0, pos - n * 6.0])
		c.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2]]), A.pal("verre_clair"))
		c.draw_colored_polygon(PackedVector2Array([pts[0], pts[2], pts[3]]), A.pal("verre").darkened(0.2))
		Art.outline(c, pts, A.pal("verre_sombre"), 1.2)
		c.draw_circle(pos + dir * 3.0, 2.2, A.pal("lumiere"))
	if attack == "rayons" and stage == "frappe":
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
		var ln := beam_length()
		for d in beams:
			var a: Vector2 = anchor + d * radius * 0.6 + Vector2(0, -BODY_Y)
			var b: Vector2 = anchor + d * ln
			c.draw_line(a, b, Color(A.pal("lumiere"), 0.6 * (1.0 - k)), BEAM["width"] * (1.0 - 0.4 * k), true)
			c.draw_line(a, b, Color(A.pal("lumiere_clair"), 0.95 * (1.0 - k)), BEAM["width"] * 0.35, true)
	if attack == "balayage" and stage == "frappe":
		var d := sweep_dir()
		var a: Vector2 = anchor + d * radius * 0.6 + Vector2(0, -BODY_Y)
		var b: Vector2 = anchor + d * beam_length()
		c.draw_line(a, b, Color(A.pal("lumiere"), 0.65), SWEEP["width"], true)
		c.draw_line(a, b, Color(A.pal("lumiere_clair"), 0.95), SWEEP["width"] * 0.35, true)
		c.draw_circle(b, SWEEP["width"] * 0.6, Color(A.pal("lumiere_clair"), 0.7))
	if attack == "pluie" and stage == "frappe":
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
		for p in pillars:
			var w: float = RAIN["radius"] * 1.4 * (1.0 - 0.5 * k)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.5, 0), p + Vector2(-w * 0.25, -520), p + Vector2(w * 0.25, -520), p + Vector2(w * 0.5, 0)]), Color(A.pal("lumiere_clair"), 0.55 * (1.0 - k)))
			c.draw_colored_polygon(Art.ellipse(p, RAIN["radius"], RAIN["radius"] * 0.4, 20), Color(A.pal("lumiere"), 0.5 * (1.0 - k)))


# --- Dessinés par l'arène (boss_arena.gd), coordonnées de l'arène ---

## La Phalène endormie : posée sur une aiguille de cristal au centre du cercle, ailes repliées en
## toit, yeux clos ; ils couvent quand le cercle est ouvert.
static func draw_sleeper(a: Node2D) -> void:
	var r := RADIUS * 0.8
	var c: Vector2 = a.center
	a.draw_colored_polygon(Art.ellipse(c + Vector2(0, r * 0.25), r * 1.4, r * 0.4, 18), Color(Art.c("ombre"), 0.3))
	A.draw_prism(a, A.prism(c + Vector2(0, r * 0.2), r * 0.45, r * 1.1, 0.0), A.pal("verre_fume"), A.pal("verre"))
	var open: bool = a.state == "ouverte"
	# Ouverte : les yeux couvent (8 images sur une période de π s).
	var i := int(fposmod(a.t * 2.0 / TAU, 1.0) * 8.0) if open else 0
	var o := {"t": i * 0.4, "alt": -20.0, "beat": -0.1, "open": 0.6, "sleep": 0.0 if open else 1.0, "k": 0.2 + 0.2 * sin(TAU * i / 8.0) if open else 0.0}
	var drawer := func(ci: CanvasItem) -> void:
		Phalene.draw(ci, Vector2.ZERO, Phalene.HEIGHT * 0.75, o)
		Ink.flash = 0.0
		Ink.ash = 0.0
	_arena_cache(a).show_pose("dort/%d" % i if open else "dort", drawer, Transform2D(0.0, c + Vector2(0, -r * 0.6)))


## Cache des poses dessinées dans l'arène (endormie, victoire) : masqué pendant le combat.
static func _arena_cache(a: Node2D) -> Node2D:
	var cache := PoseCache.on(a)
	if not cache.visible_if.is_valid():
		cache.visible_if = func() -> bool: return a.state in ["ouverte", "fermee", "vaincue"]
	return cache


## Après la victoire : un lys de cristal clair au cœur d'or, entouré de fleurs d'aube et d'éclats
## qui brillent.
static func draw_victory(a: Node2D) -> void:
	var r := RADIUS
	var c: Vector2 = a.center
	for i in 6:
		var p := c + Vector2.from_angle(TAU * i / 6.0 + 0.4) * r * 1.5 * Vector2(1.0, 0.6)
		A.draw_prism(a, A.prism(p, 7.0, 26.0 + 10.0 * (i % 2), (i - 2.5) * 2.0), A.pal("verre"), A.pal("verre_clair"))
		for j in 5:
			a.draw_circle(p + Vector2(9, 2) + Vector2.from_angle(TAU * j / 5.0 + i) * 3.0, 2.4, A.pal("lumiere_clair"))
	# Le lys : cinq pétales de verre autour d'un cœur d'or.
	var top := c + Vector2(0, -r * 0.7)
	a.draw_line(c, top, Art.c("decor_vivant"), 5.0, true)
	for i in 5:
		var ang := -PI / 2.0 + (i - 2) * 0.55
		var pet := PackedVector2Array([top, top + Vector2.from_angle(ang - 0.2) * r * 0.5, top + Vector2.from_angle(ang) * r * 0.8, top + Vector2.from_angle(ang + 0.2) * r * 0.5])
		a.draw_colored_polygon(pet, Color(A.pal("verre_clair"), 0.85))
		a.draw_polyline(PackedVector2Array([pet[0], pet[2]]), A.pal("verre_sombre"), 1.2, true)
	Art.volume_circle(a, top, r * 0.16, A.pal("lumiere"), 0.9)
	# Une petite phalène guérie, aux yeux sombres, qui tourne autour du lys.
	var ang: float = a.t * 0.8
	var at := top + Vector2(cos(ang) * r * 0.9, -r * 0.2 + sin(ang) * r * 0.3)
	var i := int(fposmod(a.t * 14.0 / TAU, 1.0) * 6.0)
	var flip := sin(ang) > 0.0
	var o := {"t": i * 0.1, "alt": 0.0, "beat": sin(TAU * i / 6.0) * 0.7, "gueri": true, "flip": flip}
	var drawer := func(ci: CanvasItem) -> void:
		Phalene.draw(ci, Vector2.ZERO, Phalene.HEIGHT * 0.2, o)
	_arena_cache(a).show_pose("gueri/%d/%d" % [i, 1 if flip else 0], drawer, Transform2D(0.0, at + Vector2(0, 30)))
