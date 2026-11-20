## La Flétrissure, boss final de l'aventure (data/finale.json › boss), sous la graine : un cœur de
## cendre noué de racines, d'où sortent six bras. Chacun porte ce qu'elle a pris à un gardien de
## région : les épines de Ronce, les spores de Spore, la sève de Sève, le vent de Vent, la lumière
## d'Aube et les racines de Racine. Un bras s'éveille (prend sa couleur) quand sa phase commence.
##
## Trois phases (100–66 %, 66–33 %, 33–0 % de sa vie), deux traits nouveaux par phase, les
## anciens restent. Chaque coup est annoncé avant de frapper (Art.telegraph, charte § 6), et le bras
## qui le porte s'allume pendant l'annonce.
##   - epines  (Ronce)  : un éventail d'épines tiré vers le joueur, deux ou trois fois ;
##   - spores  (Spore)  : des cercles se marquent autour du joueur, puis des nuages de spores y
##                        restent quelques secondes (sortir des cercles, ne pas y revenir) ;
##   - siphon  (Sève)   : un grand cercle autour d'elle, où elle boit la vie : chaque dégât porté la
##                        soigne (s'éloigner) ;
##   - rafale  (Vent)   : une bande de vent part d'elle vers le joueur ; touché, il est repoussé ;
##   - lumiere (Aube)   : des rayons partent d'elle en étoile, l'un vers le joueur (se glisser entre) ;
##   - racines (Racine) : une ligne de racines jaillit d'elle jusqu'au joueur, l'une après l'autre ;
##   - rejetons (dès la phase 2) : des Flétris sortent du sol (pas en rouge : ce n'est pas un coup).
## Phase 3 : le mur de racines se resserre (finale_arena.gd › start_shrink).
## Sa mort : les bras retombent en cendre, le cœur se fend, et la sève qu'il retenait jaillit ; à
## sa place, une pousse de l'Arbre de vie aux six couleurs (draw_victory).
##
## Le socle (vie, phases, états, mort, interface d'ennemi) est dans boss_base.gd.
extends BossBase

const PHASE_LIMITS := [0.66, 0.33]
## Vie : BASE_HP + HP_PER_LEVEL par niveau du joueur (multipliée par la difficulté).
const BASE_HP := 2400.0
const HP_PER_LEVEL := 850.0
## Par phase : pause entre deux attaques, ordre des attaques et ampleur.
const PHASES := {
	1: {"gap": 1.25, "order": ["epines", "spores", "epines", "spores"], "volleys": 2, "thorns": 9, "clouds": 3},
	2: {"gap": 1.05, "order": ["siphon", "rafale", "spores", "rejetons", "epines", "rafale"], "volleys": 2, "thorns": 11, "clouds": 4, "minions": 2},
	3: {"gap": 0.85, "order": ["lumiere", "racines", "rafale", "siphon", "lumiere", "racines", "spores", "rejetons"], "volleys": 3, "thorns": 11, "clouds": 4, "minions": 2, "rays": 5},
}
## Les six bras, dans l'ordre où ils s'éveillent : trait, élément de la charte (couleur et motif),
## phase où il s'éveille et attaque qu'il porte.
const ARMS := [
	{"trait": "epines", "element": "epine", "phase": 1},
	{"trait": "spores", "element": "poison", "phase": 1},
	{"trait": "siphon", "element": "seve", "phase": 2},
	{"trait": "rafale", "element": "vent", "phase": 2},
	{"trait": "lumiere", "element": "lumiere", "phase": 3},
	{"trait": "racines", "element": "racine", "phase": 3},
]
const THORNS := {"annonce": 0.85, "between": 0.42, "damage": 11.0, "speed": 330.0, "radius": 9.0, "spread": 0.16}
const SPORES := {"annonce": 1.0, "radius": 72.0, "spread": 175.0, "linger": 3.0, "tick": 0.5, "dps": 12.0}
const SIPHON := {"annonce": 1.1, "radius": 230.0, "duration": 2.0, "tick": 0.5, "dps": 14.0, "drain": 1.5}
const GUST := {"annonce": 0.9, "length": 900.0, "width": 150.0, "damage": 16.0, "push": 170.0}
## Les rayons vont jusqu'au mur de l'arène.
const LIGHT := {"annonce": 1.0, "rays": 4, "opening": 0.3, "damage": 20.0}
const ROOTS := {"annonce": 0.7, "count": 7, "step": 0.12, "first": 120.0, "spacing": 78.0, "radius": 52.0, "damage": 18.0}
const SPROUTS := {"annonce": 0.9, "max_alive": 4, "kind": "fletri"}
const PHASE_PAUSE := 1.5
const FLASH := 0.35

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
## Épines en vol : {"pos", "vel"}.
var thorns: Array = []
## Cercles des spores annoncées (positions), puis nuages posés : {"pos", "time"}.
var spore_marks: Array = []
var clouds: Array = []
var _cloud_tick := 0.0
var _siphon_tick := 0.0
## Longueur de la rafale en cours (jusqu'au mur de l'arène).
var gust_len := 900.0
## Rayons de lumière de l'attaque en cours (angles).
var rays: Array = []
## Racines de la ligne en cours : {"pos", "fuse", "burst"} (fuse : temps avant de jaillir ;
## burst : temps depuis le jaillissement, -1 avant).
var roots: Array = []
## Rejetons annoncés (positions).
var buds: Array = []
## Éclair de la dernière frappe (rafale, lumière), de 0 à FLASH ; -1 : aucun.
var strike_flash := -1.0
var flash_kind := ""


func _setup() -> void:
	body_radius = 82.0
	intro_time = 1.8
	death_time = 2.4
	base_hp = BASE_HP
	hp_per_level = HP_PER_LEVEL
	damage_per_level = 0.03
	contact_damage = 18.0
	phase_limits = PHASE_LIMITS
	color = Color("2a2226")


func _projectiles_step(delta: float) -> void:
	_update_thorns(delta)
	_update_clouds(delta)
	_update_roots(delta)
	if strike_flash >= 0.0:
		strike_flash += delta
		if strike_flash > FLASH:
			strike_flash = -1.0


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


## Blesse le joueur ; « drain » : elle reprend autant de vie que les dégâts portés, fois drain.
func _hurt_player(amount: float, drain := 0.0) -> void:
	var p = main.player
	if p.invuln > 0.0 or p.hp <= 0.0:
		return
	var before: float = p.hp
	p.take_hit(amount, self)
	var dealt: float = maxf(0.0, before - p.hp)
	if drain > 0.0 and dealt > 0.0 and not dead:
		var gain := dealt * drain
		hp = minf(max_hp, hp + gain)
		main.fx.text(anchor + Vector2(0, -radius * 2.2), "+%d" % roundi(gain), Art.ec("seve", "clair"), 16, 0.7)


# --- Attaques ---

func _begin(kind: String) -> void:
	var cfg: Dictionary = PHASES[phase]
	if kind == "rejetons" and minions.size() >= SPROUTS["max_alive"]:
		kind = "epines"
	attack = kind
	stage = "annonce"
	Sfx.play("annonce", anchor)
	var p: Vector2 = main.player.position
	var to: Vector2 = p - anchor
	aim = to.normalized() if to.length() > 1.0 else Vector2.DOWN
	match kind:
		"epines":
			_set_timer(THORNS["annonce"])
		"spores":
			_set_timer(SPORES["annonce"])
			spore_marks = []
			var n: int = cfg["clouds"]
			for i in n:
				var at := p
				if i > 0:
					at = p + Vector2.from_angle(TAU * i / float(n - 1) + randf() * 0.5) * randf_range(0.6, 1.0) * SPORES["spread"]
				spore_marks.append(_in_arena(at, SPORES["radius"] * 0.6))
		"siphon":
			_set_timer(SIPHON["annonce"])
		"rafale":
			_set_timer(GUST["annonce"])
			gust_len = _reach_to_wall(aim)
		"lumiere":
			_set_timer(LIGHT["annonce"])
			rays = []
			var n: int = cfg.get("rays", LIGHT["rays"])
			for i in n:
				rays.append(aim.angle() + TAU * i / n)
		"racines":
			_set_timer(ROOTS["annonce"])
			roots = []
			for i in ROOTS["count"]:
				var at: Vector2 = anchor + aim * (ROOTS["first"] + ROOTS["spacing"] * i)
				if at.distance_to(arena.center) > arena.radius - ROOTS["radius"] * 0.5:
					break
				roots.append({"pos": at, "fuse": ROOTS["annonce"] + ROOTS["step"] * i, "burst": -1.0})
		"rejetons":
			_set_timer(SPROUTS["annonce"])
			buds = []
			var n: int = cfg.get("minions", 2)
			for i in n:
				var a := aim.angle() + PI + (i - (n - 1) / 2.0) * 0.8
				buds.append(_in_arena(anchor + Vector2.from_angle(a) * 180.0, 60.0))


func _set_timer(v: float) -> void:
	timer = v
	stage_time = v


## Distance entre elle et le mur de l'arène dans la direction « dir » (au plus GUST › length).
func _reach_to_wall(dir: Vector2) -> float:
	var o: Vector2 = anchor - arena.center
	var bq := o.dot(dir)
	var cq: float = o.length_squared() - arena.radius * arena.radius
	return clampf(-bq + sqrt(maxf(0.0, bq * bq - cq)), 100.0, GUST["length"])


## Garde un point dans l'arène (à « margin » du bord).
func _in_arena(pt: Vector2, margin: float) -> Vector2:
	var to: Vector2 = pt - arena.center
	return arena.center + to.limit_length(maxf(40.0, arena.radius - margin))


## Pendant le début de l'annonce, l'éventail et la rafale suivent le joueur, puis se verrouillent.
func _announce_step() -> void:
	if attack in ["epines", "rafale"] and timer > stage_time * 0.4:
		var to: Vector2 = main.player.position - anchor
		if to.length() > 1.0:
			aim = to.normalized()
			if attack == "rafale":
				gust_len = _reach_to_wall(aim)


func _strike() -> void:
	stage = "frappe"
	var p = main.player
	match attack:
		"epines":
			volleys_left = PHASES[phase]["volleys"]
			volley_timer = 0.0
			_set_timer(THORNS["between"] * volleys_left)
		"spores":
			for m in spore_marks:
				clouds.append({"pos": m, "time": SPORES["linger"]})
				main.fx.ring(m, 10.0, SPORES["radius"], 0.35, Color(Art.ec("poison", "clair"), 0.8), 3.0)
			spore_marks = []
			_end_attack()
		"siphon":
			_siphon_tick = 0.0
			_set_timer(SIPHON["duration"])
		"rafale":
			if _in_gust(p.position, p.radius * 0.5):
				_hurt_player(GUST["damage"] * damage_scale)
				p.position += aim * GUST["push"]
			strike_flash = 0.0
			flash_kind = "rafale"
			main.fx.shake(4.0)
			_end_attack()
		"lumiere":
			if _in_rays(p.position, p.radius * 0.5):
				_hurt_player(LIGHT["damage"] * damage_scale)
			strike_flash = 0.0
			flash_kind = "lumiere"
			main.fx.shake(3.0)
			_end_attack()
		"racines":
			# Les racines jaillissent l'une après l'autre (_update_roots) : l'attaque est finie quand la dernière est sortie.
			_set_timer(ROOTS["step"] * maxi(1, roots.size()) + 0.1)
		"rejetons":
			for b in buds:
				minions.append(main.spawn_enemy_kind(SPROUTS["kind"], b, main.threat(b)))
				main.fx.ring(b, 6.0, 46.0, 0.35, Color(Art.ec("racine", "clair"), 0.8), 3.0)
			buds = []
			_end_attack()


func _strike_step(delta: float) -> void:
	match attack:
		"epines":
			volley_timer -= delta
			if volleys_left > 0 and volley_timer <= 0.0:
				volley_timer = THORNS["between"]
				for dir in thorn_dirs(volleys_left % 2 == 0):
					thorns.append({"pos": anchor + dir * radius * 0.9, "vel": dir * THORNS["speed"]})
				volleys_left -= 1
		"siphon":
			_siphon_tick -= delta
			if _siphon_tick <= 0.0:
				_siphon_tick = SIPHON["tick"]
				var p = main.player
				if p.position.distance_to(anchor) < SIPHON["radius"] + p.radius * 0.3:
					_hurt_player(SIPHON["dps"] * SIPHON["tick"] * damage_scale * 2.0, SIPHON["drain"])


## Directions des épines d'une salve (les salves paires sont décalées d'un demi-écart).
func thorn_dirs(offset := false) -> Array:
	var n: int = PHASES[phase]["thorns"]
	var out: Array = []
	var shift := 0.5 if offset else 0.0
	for i in n:
		out.append(Vector2.from_angle(aim.angle() + (i - (n - 1) / 2.0 + shift) * THORNS["spread"]))
	return out


func _in_gust(pos: Vector2, margin: float) -> bool:
	var to := pos - anchor
	var along := to.dot(aim)
	return along > 0.0 and along < gust_len + margin and absf(to.dot(aim.orthogonal())) < GUST["width"] * 0.5 + margin


func _in_rays(pos: Vector2, margin: float) -> bool:
	var to := pos - anchor
	if to.length() > arena.radius + margin or to.length() < 1.0:
		return false
	for a in rays:
		if absf(angle_difference(float(a), to.angle())) < LIGHT["opening"] * 0.5 + margin / to.length():
			return true
	return false


func _end_attack() -> void:
	attack = ""
	stage = ""
	gap = PHASES[phase]["gap"]


func _update_thorns(delta: float) -> void:
	if thorns.is_empty():
		return
	var p = main.player
	var limit: float = arena.radius + 30.0
	var kept: Array = []
	for s in thorns:
		s["pos"] += s["vel"] * delta
		var pos: Vector2 = s["pos"]
		if pos.distance_to(p.position) < THORNS["radius"] + p.radius and p.invuln <= 0.0:
			_hurt_player(THORNS["damage"] * damage_scale)
			continue
		if pos.distance_squared_to(arena.center) < limit * limit:
			kept.append(s)
	thorns = kept


func _update_clouds(delta: float) -> void:
	if clouds.is_empty():
		return
	_cloud_tick -= delta
	var tick := _cloud_tick <= 0.0
	if tick:
		_cloud_tick = SPORES["tick"]
	var p = main.player
	var kept: Array = []
	var hurt := false
	for c in clouds:
		c["time"] -= delta
		if tick and not hurt and p.position.distance_to(c["pos"]) < SPORES["radius"] + p.radius * 0.3:
			hurt = true
		if c["time"] > 0.0:
			kept.append(c)
	if hurt:
		_hurt_player(SPORES["dps"] * SPORES["tick"] * damage_scale)
	clouds = kept


func _update_roots(delta: float) -> void:
	if roots.is_empty():
		return
	var p = main.player
	var kept: Array = []
	for r in roots:
		if r["burst"] < 0.0:
			# Le compte à rebours suit l'annonce (ralentie si elle est enracinée), puis le temps réel.
			r["fuse"] -= delta * (cadence() if stage == "annonce" else 1.0)
			if r["fuse"] <= 0.0:
				r["burst"] = 0.0
				if p.position.distance_to(r["pos"]) < ROOTS["radius"] + p.radius * 0.5:
					_hurt_player(ROOTS["damage"] * damage_scale)
				main.fx.ring(r["pos"], 8.0, ROOTS["radius"], 0.3, Color(Art.ec("racine", "clair"), 0.8), 4.0)
		else:
			r["burst"] += delta
		if r["burst"] < FLASH:
			kept.append(r)
	roots = kept


func _enter_phase(n: int) -> void:
	phase = n
	transition = PHASE_PAUSE
	cycle = 0
	gap = 0.3
	var arm_col := Art.ec(ARMS[(n - 1) * 2]["element"], "clair")
	main.fx.ring(anchor, radius, 460.0, 0.8, Color(arm_col, 0.9), 8.0)
	main.fx.shake(6.0)
	if n == 2:
		main.hud.banner("La Flétrissure boit la sève et lève le vent : ne reste ni près d'elle, ni dans son souffle.", "combat")
	else:
		main.hud.banner("La lumière et les racines s'éveillent : les racines de la graine se resserrent !", "combat")
		arena.start_shrink()


## Temps avant qu'une attaque annoncée ou en cours touche ce point (INF si rien ne le menace).
func danger_time(pos: Vector2, margin := 26.0) -> float:
	var best := INF
	for s in thorns:
		var v: Vector2 = s["vel"]
		var u := clampf((pos - s["pos"]).dot(v) / v.length_squared(), 0.0, 1.5)
		if (s["pos"] + v * u).distance_to(pos) < THORNS["radius"] + margin:
			best = minf(best, u)
	for c in clouds:
		if pos.distance_to(c["pos"]) < SPORES["radius"] + margin:
			best = minf(best, 0.0)
	for r in roots:
		if r["burst"] < 0.0 and pos.distance_to(r["pos"]) < ROOTS["radius"] + margin:
			best = minf(best, maxf(0.0, r["fuse"]))
	var to := pos - anchor
	var d := to.length()
	match attack:
		"epines":
			var wait := timer if stage == "annonce" else maxf(volley_timer, 0.0)
			for offset in [false, true]:
				for dir in thorn_dirs(offset):
					var along := to.dot(dir)
					if along > 0.0 and absf(to.dot(dir.orthogonal())) < THORNS["radius"] + margin:
						best = minf(best, wait + along / THORNS["speed"])
		"spores":
			for m in spore_marks:
				if pos.distance_to(m) < SPORES["radius"] + margin:
					best = minf(best, timer)
		"siphon":
			if d < SIPHON["radius"] + margin:
				best = minf(best, timer if stage == "annonce" else 0.0)
		"rafale":
			if stage == "annonce" and _in_gust(pos, margin):
				best = minf(best, timer)
		"lumiere":
			if stage == "annonce" and _in_rays(pos, margin):
				best = minf(best, timer)
	if d < radius + margin + 20.0:
		best = minf(best, 0.0)
	return best


func _clear_attacks() -> void:
	attack = ""
	stage = ""
	thorns = []
	spore_marks = []
	clouds = []
	rays = []
	roots = []
	buds = []


## Le robot tourne autour d'elle, hors du siphon quand il s'annonce.
func bot_ring(arena_radius: float) -> float:
	var ring := minf(250.0, arena_radius - 60.0)
	if attack == "siphon" and arena_radius - 50.0 > SIPHON["radius"] + 40.0:
		ring = SIPHON["radius"] + 45.0
	return ring


# --- Dessin ---
#
# Charte : les Flétris sont sombres et saturés, contour clair, braise dans les fentes. La
# Flétrissure est un cœur de cendre fendu (couleur ennemi assombrie), noué de racines, où couvent des
# braises ; ses six bras sont des racines effilées. Un bras endormi reste gris de cendre ; éveillé,
# il prend la couleur de son élément et porte son motif au bout (épines, chapeau de champignon,
# goutte, plume, cristal, griffe de racines) ; il s'allume pendant l'annonce de son attaque.

## Avancée de l'annonce en cours (0 → 1), 0 hors annonce.
func _announce_k() -> float:
	if stage != "annonce" or stage_time <= 0.0:
		return 0.0
	return clampf(1.0 - timer / stage_time, 0.0, 1.0)


## Angle d'un bras (vu de dessus, les six en étoile, un peu de balancement).
func _arm_angle(i: int) -> float:
	return -PI / 2.0 + TAU * (i + 0.5) / ARMS.size() + 0.06 * sin(t * 1.3 + i * 1.7)


func _draw() -> void:
	var r := radius
	var k := _announce_k()
	var die := clampf(dying / death_time, 0.0, 1.0) if dead else 0.0
	var ash := FletriArt.ash_color()
	Art.shadow(self, Vector2(0, r * 0.2), r * 1.3)
	# Les six bras, derrière le cœur.
	for i in ARMS.size():
		var arm: Dictionary = ARMS[i]
		var awake: bool = phase >= int(arm["phase"])
		var lit: float = k if attack == arm["trait"] or (attack == "rejetons" and i == 5) else 0.0
		_draw_arm(self, Vector2(0, -r * 0.35), _arm_angle(i), r, str(arm["element"]), awake, lit, die)
	# Le cœur de cendre : une graine noire et fendue, qui bat.
	var beat := Anim.breathe(t * (1.6 if phase >= 3 else 1.0), 0.04)
	var heart := Art.ellipse(Vector2(0, -r * 0.35), r * 0.78 * beat, r * 0.92 * beat, 28)
	var body := _color(Art.c("ennemi").darkened(0.45).lerp(Art.ec("cendre", "sombre"), 0.35))
	Art.volume(self, heart, body, 0.5)
	Art.outline(self, heart, Color(Art.c("ennemi_contour"), 1.0 - die * 0.8), Art.TRAIT_FORT)
	# Racines qui l'enserrent.
	var knot := _color(Art.ec("racine", "sombre").lerp(Art.c("ennemi"), 0.3))
	for j in 3:
		var y := -r * (0.75 - 0.4 * j)
		var w := r * (0.55 + 0.12 * (1 - absi(j - 1)))
		draw_polyline(PackedVector2Array([Vector2(-w, y + 6), Vector2(-w * 0.3, y - 4), Vector2(w * 0.3, y + 4), Vector2(w, y - 6)]), knot, 6.0, true)
	# Fentes de braise : plus nombreuses à chaque phase ; à la mort, la sève jaillit des fentes.
	var crack_col := Art.ec("seve", "clair") if dead else Art.ec("cendre")
	var glow := (0.55 + 0.35 * sin(t * (5.0 if phase >= 3 else 3.0))) if not dead else 1.0 - die * 0.5
	var cracks := [[Vector2(-0.1, -0.95), Vector2(0.05, -0.6), Vector2(-0.08, -0.3)], [Vector2(0.3, -0.5), Vector2(0.12, -0.2), Vector2(0.25, 0.1)], [Vector2(-0.35, -0.2), Vector2(-0.15, 0.05), Vector2(-0.3, 0.3)]]
	for j in mini(cracks.size(), phase + (1 if dead else 0)):
		var pts := PackedVector2Array()
		for q in cracks[j]:
			pts.append(Vector2(q.x * r, q.y * r))
		draw_polyline(pts, Color(crack_col, glow), 3.5 + 3.0 * die, true)
	# Yeux : deux braises au creux du cœur, qui s'ouvrent pendant l'annonce.
	for sgn in [-1, 1]:
		var e := Vector2(sgn * r * 0.24, -r * 0.55)
		draw_circle(e, r * (0.07 + 0.04 * k), Color(Art.c("ennemi_oeil"), (0.4 + 0.6 * k) * (1.0 - die)))
		draw_line(e + Vector2(-r * 0.1, -sgn * r * 0.03), e + Vector2(r * 0.1, sgn * r * 0.03), Color(Art.c("ennemi_oeil"), 1.0 - die), 3.0, true)
	# Mort : des gouttes de sève montent des fentes et pâlissent ; le cœur grisaille (BossBase._color).
	if dead:
		for i in 14:
			var a := TAU * i / 14.0 + 0.2
			var u := clampf(die * 1.4 - (i % 3) * 0.12, 0.0, 1.0)
			if u <= 0.0 or u >= 1.0:
				continue
			var q := Vector2(0, -r * 0.35) + Vector2.from_angle(a) * r * (0.3 + 0.9 * u) - Vector2(0, r * 0.7 * u)
			draw_circle(q, r * (0.04 + 0.07 * u), Color(Art.ec("seve", "clair"), 0.75 * (1.0 - u)))
		draw_circle(Vector2(0, -r * 0.35), r * 0.5 * die, Color(ash, 0.25 * die))


## Un bras : une racine effilée, puis le motif de son élément au bout. Endormi, gris de cendre.
## lit : allumage pendant l'annonce (0 → 1). Statique : sert aussi au boss endormi (draw_sleeper).
static func _draw_arm(ci: CanvasItem, base: Vector2, ang: float, r: float, element: String, awake: bool, lit: float, die := 0.0) -> void:
	var dir := Vector2.from_angle(ang)
	var side := dir.orthogonal()
	var reach := r * (2.0 if awake else 1.6) * (1.0 - 0.35 * die)
	var root_col := Art.ec("racine", "sombre").lerp(Art.c("ennemi"), 0.35)
	var col := Art.ec(element) if awake else FletriArt.ash_color().lerp(Art.c("brume"), 0.4)
	if die > 0.0:
		col = col.lerp(FletriArt.ash_color(), die)
		root_col = root_col.lerp(FletriArt.ash_color(), die)
	var from := base + dir * r * 0.55
	var mid := base + dir * reach * 0.62 + side * r * 0.12
	var tip := base + dir * reach
	var w := r * 0.22
	var limb := PackedVector2Array([from - side * w, mid - side * w * 0.6, tip, mid + side * w * 0.6, from + side * w])
	ci.draw_colored_polygon(limb, root_col)
	Art.outline(ci, limb, Color(Art.c("ennemi_contour"), 0.55 * (1.0 - die)), Art.TRAIT_FIN)
	# Veine de l'élément le long du bras.
	if awake:
		ci.draw_polyline(PackedVector2Array([from, mid, tip]), Color(col, 0.55 + 0.45 * lit), 2.0 + 2.0 * lit, true)
	if lit > 0.0:
		ci.draw_circle(tip, r * (0.25 + 0.2 * lit), Color(Art.ec(element, "clair"), 0.25 * lit))
	var s := r * 0.32 * (1.0 + 0.25 * lit)
	var dark := col.darkened(0.45)
	match element:
		"epine":
			for j in 3:
				var d := Vector2.from_angle(ang + (j - 1) * 0.55)
				ci.draw_colored_polygon(PackedVector2Array([tip + d.orthogonal() * s * 0.25, tip + d * s * 1.4, tip - d.orthogonal() * s * 0.25]), col)
		"poison":
			# Chapeau de champignon, tourné vers l'extérieur, piqué de points clairs.
			var cap := PackedVector2Array()
			for j in 11:
				var a := ang - PI / 2.0 + PI * j / 10.0
				cap.append(tip + Vector2.from_angle(a) * s * 1.1)
			Art.volume(ci, cap, col, 0.6 if awake else 0.0)
			if awake:
				for j in 3:
					ci.draw_circle(tip + dir * s * 0.55 + side * s * (j - 1) * 0.45, s * 0.14, Art.ec(element, "clair"))
		"seve":
			# Goutte de sève, pointe vers le cœur.
			ci.draw_colored_polygon(PackedVector2Array([tip - dir * s * 0.9, tip + side * s * 0.6, tip + dir * s * 0.7, tip - side * s * 0.6]), dark)
			ci.draw_circle(tip + dir * s * 0.25, s * 0.62, col)
			if awake:
				ci.draw_circle(tip + dir * s * 0.1 - side * s * 0.2, s * 0.2, Art.ec(element, "clair"))
		"vent":
			# Plume : un rachis et des barbes qui s'écartent.
			var end := tip + dir * s * 1.4
			ci.draw_line(tip - dir * s * 0.4, end, dark, 2.5, true)
			for j in 5:
				var q := tip.lerp(end, j / 5.0)
				ci.draw_line(q, q + (side + dir * 0.6).normalized() * s * 0.6, col, 3.0, true)
				ci.draw_line(q, q + (-side + dir * 0.6).normalized() * s * 0.6, col, 3.0, true)
		"lumiere":
			# Cristal : un losange clair, ses rayons pendant l'annonce.
			var gem := PackedVector2Array([tip - dir * s * 0.5, tip + side * s * 0.55, tip + dir * s * 1.3, tip - side * s * 0.55])
			Art.volume(ci, gem, col, 1.0 if awake else 0.0)
			Art.outline(ci, gem, dark, Art.TRAIT_FIN)
			if lit > 0.0:
				for j in 4:
					var d := Vector2.from_angle(ang + (j - 1.5) * 0.5)
					ci.draw_line(tip + d * s, tip + d * s * (1.6 + lit), Color(Art.ec(element, "clair"), lit), 2.0, true)
		"racine":
			# Griffe de racines : trois crochets.
			for j in 3:
				var a := ang + (j - 1) * 0.6
				var d := Vector2.from_angle(a)
				var q1 := tip + d * s * 0.9
				ci.draw_polyline(PackedVector2Array([tip, q1, q1 + d.orthogonal() * s * 0.4 * (1 if j != 0 else -1)]), col, 4.0, true)


## Annonces au sol, en coordonnées monde (grammaire de Art.telegraph). Les rejetons, qui ne
## blessent pas, ne sont pas en rouge ; les nuages de spores posés gardent leur couleur.
func draw_marks(c: CanvasItem) -> void:
	var k := _announce_k()
	# Nuages de spores posés : violets, bulles qui montent, bord rouge (toujours dangereux).
	for cl in clouds:
		var pos: Vector2 = cl["pos"]
		var fade := clampf(float(cl["time"]) / 0.6, 0.0, 1.0)
		c.draw_circle(pos, SPORES["radius"], Color(Art.ec("poison"), 0.28 * fade))
		c.draw_circle(pos, SPORES["radius"] * 0.65, Color(Art.ec("poison", "clair"), 0.12 * fade))
		for j in 7:
			var f := fposmod(t * 0.7 + j * 0.31, 1.0)
			var q: Vector2 = pos + Vector2.from_angle(j * 2.1) * SPORES["radius"] * 0.6 * f - Vector2(0, 10.0 * f)
			c.draw_circle(q, 3.0 + 3.0 * f, Color(Art.ec("poison", "clair"), 0.5 * (1.0 - f) * fade))
		c.draw_arc(pos, SPORES["radius"], 0.0, TAU, 32, Color(Art.c("danger"), 0.55 * fade), Art.TRAIT, true)
	match attack:
		"epines":
			if stage == "annonce":
				var n: int = PHASES[phase]["thorns"]
				Art.telegraph(c, {"type": "cone", "centre": anchor, "direction": aim.angle(), "ouverture": THORNS["spread"] * n, "rayon": 380.0}, k, -1.0, t)
		"spores":
			for m in spore_marks:
				Art.telegraph(c, {"type": "cercle", "centre": m, "rayon": SPORES["radius"]}, k, -1.0, t)
		"siphon":
			if stage == "annonce":
				Art.telegraph(c, {"type": "cercle", "centre": anchor, "rayon": SIPHON["radius"]}, k, -1.0, t)
			else:
				var u := 1.0 - timer / SIPHON["duration"]
				Art.telegraph(c, {"type": "cercle", "centre": anchor, "rayon": SIPHON["radius"]}, 1.0, u, t)
				for i in 10:
					var a := TAU * i / 10.0 + t * 0.6
					var f := fposmod(t * 1.4 + i * 0.37, 1.0)
					c.draw_circle(anchor + Vector2.from_angle(a) * SIPHON["radius"] * (1.0 - f), 3.0, Color(Art.ec("seve", "clair"), 0.8 * sin(PI * f)))
		"rafale":
			if stage == "annonce":
				Art.telegraph(c, {"type": "ligne", "de": anchor, "a": anchor + aim * gust_len, "largeur": GUST["width"]}, k, -1.0, t)
		"lumiere":
			if stage == "annonce":
				for a in rays:
					Art.telegraph(c, {"type": "cone", "centre": anchor, "direction": float(a), "ouverture": LIGHT["opening"], "rayon": arena.radius}, k, -1.0, t)
		"rejetons":
			var col := Art.ec("racine", "clair")
			for b in buds:
				c.draw_arc(b, 30.0 - 12.0 * k, 0.0, TAU, 24, Color(col, 0.35 + 0.5 * k), Art.TRAIT, true)
				Art.volume_circle(c, b, 6.0 + 8.0 * k, Art.ec("racine", "sombre").lerp(Art.c("ennemi"), k), 0.7)
	# Ligne de racines : chaque cercle s'annonce jusqu'à son jaillissement, puis l'éclair.
	for r in roots:
		var forme := {"type": "cercle", "centre": r["pos"], "rayon": ROOTS["radius"]}
		if r["burst"] < 0.0:
			var total: float = ROOTS["annonce"] + ROOTS["step"] * roots.find(r)
			Art.telegraph(c, forme, clampf(1.0 - float(r["fuse"]) / maxf(total, 0.01), 0.0, 1.0), -1.0, t)
		else:
			var f: float = r["burst"] / FLASH
			Art.telegraph(c, forme, 1.0, f, t)
			for j in 3:
				var a := -PI / 2.0 + (j - 1) * 0.6
				c.draw_line(r["pos"], r["pos"] + Vector2.from_angle(a) * ROOTS["radius"] * (0.9 - 0.5 * f), Art.ec("racine", "sombre"), 6.0, true)
	if strike_flash >= 0.0:
		var f := strike_flash / FLASH
		if flash_kind == "rafale":
			Art.telegraph(c, {"type": "ligne", "de": anchor, "a": anchor + aim * gust_len, "largeur": GUST["width"]}, 1.0, f, t)
			for j in 6:
				var o := aim.orthogonal() * GUST["width"] * ((j + 0.5) / 6.0 - 0.5)
				var u := fposmod(f + j * 0.17, 1.0)
				c.draw_line(anchor + o + aim * gust_len * u * 0.7, anchor + o + aim * gust_len * (u * 0.7 + 0.25), Color(Art.ec("vent", "clair"), 0.8 * (1.0 - f)), 3.0, true)
		elif flash_kind == "lumiere":
			for a in rays:
				Art.telegraph(c, {"type": "cone", "centre": anchor, "direction": float(a), "ouverture": LIGHT["opening"], "rayon": arena.radius}, 1.0, f, t)


## Épines en vol, au-dessus des personnages, en coordonnées monde.
func draw_overlay(c: CanvasItem) -> void:
	var col := Art.ec("epine")
	for s in thorns:
		var p: Vector2 = s["pos"]
		var d: Vector2 = s["vel"].normalized()
		var o := d.orthogonal() * THORNS["radius"] * 0.55
		var tri := PackedVector2Array([p + d * THORNS["radius"] * 1.6, p + o - d * THORNS["radius"], p - o - d * THORNS["radius"]])
		c.draw_colored_polygon(tri, col)
		Art.outline(c, tri, Art.c("contour"), Art.TRAIT_FIN)


## La Flétrissure endormie : le cœur de cendre, ses six bras repliés et gris.
static func draw_sleeper(a: Node2D) -> void:
	var c: Vector2 = a.center
	var r := 60.0
	Art.shadow(a, c + Vector2(0, r * 0.2), r * 1.3)
	for i in ARMS.size():
		_draw_arm(a, c + Vector2(0, -r * 0.3), -PI / 2.0 + TAU * (i + 0.5) / ARMS.size(), r, str(ARMS[i]["element"]), false, 0.0)
	var heart := Art.ellipse(c + Vector2(0, -r * 0.3), r * 0.75, r * 0.9, 24)
	Art.volume(a, heart, Art.c("ennemi").darkened(0.5), 0.3)
	Art.outline(a, heart, Color(Art.c("ennemi_contour"), 0.6), Art.TRAIT)
	if a.state == "ouverte":
		var pulse := 0.45 + 0.35 * sin(a.t * 2.0)
		a.draw_circle(c + Vector2(0, -r * 0.4), r * 0.22, Color(Art.ec("cendre"), pulse * 0.6))


## Après la victoire : une pousse de l'Arbre de vie, ses six feuilles aux couleurs des régions.
static func draw_victory(a: Node2D) -> void:
	var c: Vector2 = a.center
	var k := 1.5
	Art.glow(a, c + Vector2(0, -40), 120.0, "seve")
	Art.shadow(a, c, 26.0)
	var bark := Art.ec("racine", "sombre").lerp(Art.c("decor_vivant"), 0.3)
	a.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 4), c + Vector2(-4, -70 * k), c + Vector2(5, -70 * k), c + Vector2(10, 4)]), bark)
	for i in ARMS.size():
		var ang := -PI / 2.0 + (i - 2.5) * 0.42
		var base := c + Vector2(0, (-60 + 6.0 * absf(i - 2.5)) * k)
		var tip := base + Vector2.from_angle(ang) * (34.0 + 4.0 * sin(a.t * 1.5 + i)) * k
		a.draw_line(base, tip, bark, 4.0, true)
		Art.volume(a, Art.ellipse(tip, 11.0 * k, 7.0 * k, 12), Art.ec(str(ARMS[i]["element"])).lerp(Art.c("decor_vivant"), 0.25), 0.6)
