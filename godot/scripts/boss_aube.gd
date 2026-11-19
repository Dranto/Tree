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
## Mort : ses ailes se fendent et tombent en éclats, la lumière d'aube remonte.
##
## Le socle commun (vie, phases, états, mort, interface d'ennemi) est dans boss_base.gd ; ce
## fichier ne décrit que ses attaques et son dessin. Nommé dans data/regions/aube.json › boss.
extends BossBase

const Enemy = preload("res://scripts/enemy.gd")
const A = preload("res://scripts/region_art/aube.gd")

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
}
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
		"pluie":
			_set_timer(RAIN["frappe"])
			main.fx.shake(0.2)
			for c in pillars:
				main.fx.ring(c, 10.0, RAIN["radius"] * 1.2, 0.35, Color(A.pal("lumiere_clair"), 0.9), 5.0)
			for c in pillars:
				if p.invuln <= 0.0 and p.position.distance_to(c) < RAIN["radius"] + p.radius * 0.5:
					p.take_hit(RAIN["damage"] * damage_scale, self)
					break


func _strike_step(delta: float) -> void:
	if attack == "ecailles":
		volley_timer -= delta
		if volleys_left > 0 and volley_timer <= 0.0:
			volley_timer = SCALE["between"]
			_fire_volley(volleys_left % 2 == 0)
			volleys_left -= 1


## Fin d'une frappe : une autre salve de rayons (phase 3), sinon la pause.
func _after_strike() -> void:
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
	if n == 2:
		main.hud.banner("La Phalène de verre brise la lumière.", "combat")
	else:
		main.hud.banner("La lumière tombe du ciel !", "combat")


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


## Le robot recule hors de portée de l'éclair quand elle l'annonce.
func bot_ring(arena_radius: float) -> float:
	var ring := minf(240.0, arena_radius - 60.0)
	if attack == "eclair":
		ring = minf(FLASH["range"] + 50.0, arena_radius - 50.0)
	return ring


# --- Dessin ---
#
# Charte graphique : les Flétris sont anguleux, en volume, contour clair, braise dans les fentes.
# La Phalène est vue de dessus, ailes ouvertes : un corps de cendre velu, deux grandes ailes
# antérieures de verre fumé à facettes, deux postérieures plus petites, des antennes en plumes,
# deux yeux de braise. Phase 2 : la lumière court dans les nervures ; phase 3 : les ailes se
# fendent et des éclats s'en détachent.

## Aile du côté sgn (-1 gauche, 1 droite) : antérieure (fore) ou postérieure, ouverte de « open »
## (0,6 repliée à 1,2 grande ouverte), en coordonnées locales du corps (y vers le bas).
static func wing_shape(r: float, sgn: float, open: float, fore: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if fore:
		pts.append(Vector2(0.18 * sgn, -0.35) * r)
		pts.append(Vector2(0.9 * sgn, -1.05) * r)
		pts.append(Vector2(1.9 * sgn, -1.15) * r)
		pts.append(Vector2(2.3 * sgn, -0.75) * r)
		pts.append(Vector2(1.95 * sgn, -0.1) * r)
		pts.append(Vector2(0.95 * sgn, 0.12) * r)
		pts.append(Vector2(0.22 * sgn, 0.0) * r)
	else:
		pts.append(Vector2(0.2 * sgn, 0.05) * r)
		pts.append(Vector2(1.15 * sgn, 0.2) * r)
		pts.append(Vector2(1.45 * sgn, 0.75) * r)
		pts.append(Vector2(0.95 * sgn, 1.2) * r)
		pts.append(Vector2(0.35 * sgn, 0.85) * r)
	var out := PackedVector2Array()
	var root: Vector2 = pts[0]
	for q in pts:
		var rel: Vector2 = q - root
		out.append(root + Vector2(rel.x * open, rel.y * (0.85 + 0.15 * open)))
	return out


func _draw() -> void:
	var wake := 1.0 - clampf(intro / INTRO, 0.0, 1.0)
	var dk := clampf(dying / DEATH_TIME, 0.0, 1.0) if dead else 0.0
	var r := RADIUS
	var alt := r * HOVER + r * 0.1 * sin(t * 2.0)
	var open := 1.0 + 0.08 * sin(t * (2.6 + 0.8 * (phase - 1)))
	var glow := 0.0
	if attack == "eclair":
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
		if stage == "annonce":
			open = lerpf(1.0, 1.22, Anim.ease_out(k)) + 0.02 * sin(t * 30.0)
			glow = Anim.ease_in(k)
		else:
			open = 1.22
			glow = 1.0 - k
	elif attack == "rayons":
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
		glow = 0.6 * k if stage == "annonce" else 0.8 * (1.0 - k)
	if dead:
		open = lerpf(open, 0.6, Anim.ease_out(clampf(dk * 1.6, 0.0, 1.0)))
		alt = lerpf(alt, r * 0.1, Anim.ease_in(clampf(dk * 1.3, 0.0, 1.0)))
	var s := lerpf(0.35, 1.0, Anim.ease_out(wake)) * (1.0 - 0.15 * Anim.ease_in(dk))
	modulate.a = 1.0 - Anim.ease_in(clampf((dk - 0.6) / 0.4, 0.0, 1.0))
	draw_colored_polygon(Art.ellipse(Vector2(0, r * 0.15), r * 2.0 * s, r * 0.6 * s, 24), Color(Art.c("ombre"), 0.35))
	var shift := Vector2(0, -alt)
	if transition > 0.0:
		shift += Vector2(sin(t * 50.0), cos(t * 43.0)) * 4.0
	draw_set_transform(shift, 0.0, Vector2(s, s))
	_paint_body(self, r, open, glow, dk)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Le corps, les ailes et la tête, centrés sur le thorax (déjà décalés de l'altitude).
func _paint_body(c: CanvasItem, r: float, open: float, glow: float, dk: float) -> void:
	var rage: float = [0.0, 0.5, 1.0][phase - 1]
	var contour := _color(Art.c("ennemi_contour"))
	var fur := Art.c("ennemi").lerp(A.pal("verre_fume"), 0.3)
	var glass := A.pal("verre_fume").lerp(A.pal("verre"), 0.25 + 0.5 * glow)
	var light := A.pal("lumiere")
	var pulse := 0.5 + 0.5 * sin(t * (3.0 + 4.0 * rage))
	# Ailes postérieures, puis antérieures (devant).
	for fore in [false, true]:
		for sgn in [-1.0, 1.0]:
			var w := wing_shape(r, sgn, open, fore)
			c.draw_colored_polygon(w, Color(_color(glass), 0.82 * (1.0 - dk * 0.5)))
			# Facettes : deux nervures qui partent de la racine.
			var root: Vector2 = w[0]
			for i in range(2, w.size() - 1, 2):
				var vein := Color(_color(A.pal("verre_sombre")), 0.8)
				if rage > 0.0:
					vein = vein.lerp(Color(light, 0.9), (0.3 + 0.5 * rage) * (0.6 + 0.4 * pulse))
				c.draw_line(root, w[i], vein, 2.0, true)
			var closed := w.duplicate()
			closed.append(w[0])
			c.draw_polyline(closed, contour, Art.TRAIT, true)
			if fore:
				# Ocelle de lumière sale au milieu de l'aile (l'« œil » de la phalène).
				var eye: Vector2 = w[0].lerp(w[3], 0.55)
				c.draw_circle(eye, r * 0.22, _color(A.pal("lumiere_sombre").lerp(light, 0.3 + 0.7 * glow)))
				c.draw_circle(eye, r * 0.1, _color(Art.c("ennemi").darkened(0.3)))
				c.draw_arc(eye, r * 0.22, 0.0, TAU, 18, contour, Art.TRAIT_FIN, true)
				# Phase 3 : l'aile est fendue, un morceau manque au bord.
				if rage >= 1.0 or dead:
					var a2: Vector2 = w[3]
					var b2: Vector2 = w[4]
					c.draw_polyline(PackedVector2Array([a2.lerp(b2, 0.3), eye.lerp(a2, 0.5), eye]), Color(light, 0.8 * (1.0 - dk)), 2.0, true)
	# Lueur de l'éclair : les ailes blanchissent.
	if glow > 0.05:
		Art.glow(c, Vector2(0, -0.2 * r), r * (1.4 + 1.2 * glow), "seve")
		c.draw_circle(Vector2(0, -0.2 * r), r * 0.9 * glow, Color(A.pal("lumiere_clair"), 0.35 * glow))
	# Abdomen velu, annelé.
	var abdo := Art.ellipse(Vector2(0, 0.55 * r), r * 0.3, r * 0.68, 18)
	Art.volume(c, abdo, _color(fur), 0.6)
	for i in 4:
		var y := (0.15 + 0.22 * i) * r
		var hw := r * 0.28 * (1.0 - 0.12 * i)
		c.draw_line(Vector2(-hw, y), Vector2(hw, y), _color(fur.darkened(0.3)), 2.0, true)
	Art.outline(c, abdo, contour, Art.TRAIT)
	# Thorax et tête.
	var thorax := Art.ellipse(Vector2(0, -0.25 * r), r * 0.36, r * 0.38, 18)
	Art.volume(c, thorax, _color(fur.lightened(0.05)), 0.6)
	Art.outline(c, thorax, contour, Art.TRAIT)
	var head := Vector2(0, -0.72 * r)
	var skull := Art.ellipse(head, r * 0.26, r * 0.2, 14)
	Art.volume(c, skull, _color(fur.darkened(0.05)), 0.6)
	Art.outline(c, skull, contour, Art.TRAIT_FIN)
	# Antennes en plumes.
	for sgn in [-1.0, 1.0]:
		var base := head + Vector2(0.1 * sgn, -0.12) * r
		var tip := head + Vector2(0.55 * sgn, -0.75) * r
		c.draw_line(base, tip, _color(F_bone()), 2.0, true)
		for j in 5:
			var q := base.lerp(tip, 0.25 + 0.15 * j)
			c.draw_line(q, q + Vector2(0.12 * sgn, 0.02) * r, _color(F_bone().darkened(0.2)), 1.5, true)
	# Yeux de braise, plus vifs pendant une annonce.
	var bright := 0.4 + (0.45 if stage == "annonce" else 0.0)
	var eye_col := Art.c("ennemi_oeil")
	for sgn in [-1.0, 1.0]:
		var e := head + Vector2(0.15 * sgn * r, 0.0)
		c.draw_circle(e, r * 0.11, Color(eye_col, bright * 0.5 * (1.0 - dk)))
		c.draw_circle(e, r * 0.07, _color(eye_col.lerp(Art.ec("cendre"), 0.3 * rage)))
	# Phase 3 et mort : des éclats de verre se détachent et tombent.
	var flakes := 0 if phase < 3 and not dead else 8
	for i in flakes:
		var u := fposmod(t * 0.5 + i / 8.0, 1.0)
		var q := Vector2(sin(i * 2.4) * r * 1.8, -r * 0.6 + r * 1.6 * u)
		var sz := 5.0 * (1.0 - 0.4 * u)
		c.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -sz), q + Vector2(sz * 0.5, 0), q + Vector2(0, sz), q + Vector2(-sz * 0.5, 0)]), Color(A.pal("verre"), 1.0 - u))
	if statuses.has("saignement"):
		Art.status(c, "saignement", Vector2.ZERO, r * 0.7, t * 1.25)
	if statuses.has("enracine"):
		Art.status(c, "racine", Vector2(0, r * 0.3), r * 0.9, t)
	if poison_time > 0.0:
		Art.status(c, "poison", Vector2.ZERO, r * 0.7, t)
	if dead and dk > 0.5:
		Art.glow(c, Vector2.ZERO, r * 0.9 * Anim.ease_out((dk - 0.5) / 0.5), "seve")


static func F_bone() -> Color:
	return Art.ec("epine", "clair").darkened(0.15)


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
			var a: Vector2 = anchor + d * radius * 0.6 + Vector2(0, -RADIUS * HOVER)
			var b: Vector2 = anchor + d * ln
			c.draw_line(a, b, Color(A.pal("lumiere"), 0.6 * (1.0 - k)), BEAM["width"] * (1.0 - 0.4 * k), true)
			c.draw_line(a, b, Color(A.pal("lumiere_clair"), 0.95 * (1.0 - k)), BEAM["width"] * 0.35, true)
	if attack == "pluie" and stage == "frappe":
		var k := 1.0 - clampf(timer / stage_time, 0.0, 1.0)
		for p in pillars:
			var w: float = RAIN["radius"] * 1.4 * (1.0 - 0.5 * k)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.5, 0), p + Vector2(-w * 0.25, -520), p + Vector2(w * 0.25, -520), p + Vector2(w * 0.5, 0)]), Color(A.pal("lumiere_clair"), 0.55 * (1.0 - k)))
			c.draw_colored_polygon(Art.ellipse(p, RAIN["radius"], RAIN["radius"] * 0.4, 20), Color(A.pal("lumiere"), 0.5 * (1.0 - k)))


# --- Dessinés par l'arène (boss_arena.gd), coordonnées de l'arène ---

## La Phalène endormie : posée sur une aiguille de cristal au centre du cercle, ailes repliées en
## toit, yeux clos.
static func draw_sleeper(a: Node2D) -> void:
	var r := RADIUS * 0.8
	var c: Vector2 = a.center
	a.draw_colored_polygon(Art.ellipse(c + Vector2(0, r * 0.25), r * 1.4, r * 0.4, 18), Color(Art.c("ombre"), 0.3))
	A.draw_prism(a, A.prism(c + Vector2(0, r * 0.2), r * 0.45, r * 1.1, 0.0), A.pal("verre_fume"), A.pal("verre"))
	var moth := c + Vector2(0, -r * 1.25)
	var glass := A.pal("verre_fume").lerp(A.pal("verre"), 0.2)
	for sgn in [-1.0, 1.0]:
		var w := PackedVector2Array([moth + Vector2(0.05 * sgn, -0.55) * r, moth + Vector2(0.75 * sgn, 0.1) * r, moth + Vector2(0.55 * sgn, 0.6) * r, moth + Vector2(0.05 * sgn, 0.45) * r])
		a.draw_colored_polygon(w, Color(glass, 0.9))
		var closed := w.duplicate()
		closed.append(w[0])
		a.draw_polyline(closed, Color(Art.c("ennemi_contour"), 0.5), Art.TRAIT_FIN, true)
	var head := moth + Vector2(0, -r * 0.62)
	a.draw_circle(head, r * 0.2, Art.c("ennemi").lerp(A.pal("verre_fume"), 0.3).darkened(0.2))
	var open: bool = a.state == "ouverte"
	for sgn in [-1.0, 1.0]:
		var e := head + Vector2(0.09 * sgn, 0.0) * r
		if open:
			a.draw_circle(e, r * 0.07, Color(Art.c("ennemi_oeil"), 0.45 + 0.35 * sin(a.t * 2.0)))
		a.draw_line(e - Vector2(0.06, 0) * r, e + Vector2(0.06, 0) * r, Art.c("contour"), 2.0, true)


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
