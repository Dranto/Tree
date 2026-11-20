## L'Ancien pétrifié, boss de la région de Racine : le plus vieux chêne de la forêt, changé en pierre
## par la Flétrissure, qui s'arrache à la roche au milieu de sa clairière. Nommé dans
## data/regions/racine.json › boss.
##
## Trois phases (100–66 %, 66–33 %, 33–0 % de sa vie). Chaque coup est annoncé avant de frapper
## (Art.telegraph, charte § 6) ; son corps le montre aussi (racines qui rougeoient, bras levé, cime
## qui tremble). Racine est la branche de l'armure : son pieu la perce.
##   - racines  : des racines de pierre filent sous le sol en éventail vers le joueur (couloirs au
##                sol) puis jaillissent : se placer entre deux couloirs ;
##   - eboulis  : la cime se secoue, des pierres tombent dans des cercles autour du joueur ;
##   - pieu     : il lève un bras-branche et plante un pieu de pierre en ligne droite vers le joueur ;
##                ce coup perce l'armure (« pierce ») : l'écorce ne suffit pas, il faut s'écarter ;
##   - chute    (dès la phase 2) : un pan de sa cime se détache et tombe, un grand cercle sous le
##                joueur, plus lent à venir ;
##   - invocation (dès la phase 2) : des Termites (phase 2) puis des Scarabées (phase 3) sortent
##                de la roche (pas en rouge : ce n'est pas un coup) ;
##   - phase 3 : la forêt se referme (l'arène se resserre, boss_arena.gd) ; plus de racines à la fois.
## L'enracinement ne le tient pas (no_root). Sa mort : l'écorce de pierre se fend et tombe par
## plaques, le bois vivant apparaît dessous ; à sa place, une clairière moussue et un jeune chêne
## (draw_victory).
##
## Le socle (vie, phases, états, mort, interface d'ennemi) est dans boss_base.gd.
extends BossBase

const PHASE_LIMITS := [0.66, 0.33]
## Vie : base + par niveau du joueur (réglée au robot : --autotest=boss au niveau 20).
const BASE_HP := 440.0
const HP_PER_LEVEL := 145.0
## Par phase : pause entre deux attaques, ordre des attaques et ampleur.
const PHASES := {
	1: {"gap": 1.3, "order": ["racines", "eboulis", "pieu", "racines", "eboulis", "pieu"], "lines": 3, "stones": 4},
	2: {"gap": 1.1, "order": ["eboulis", "invocation", "racines", "chute", "pieu", "racines"], "lines": 4, "stones": 5, "minions": 3, "minion": "termite"},
	3: {"gap": 0.95, "order": ["racines", "pieu", "chute", "eboulis", "invocation", "racines", "pieu"], "lines": 5, "stones": 6, "minions": 2, "minion": "scarabee"},
}
const ROOTS := {"annonce": 1.0, "width": 54.0, "length": 560.0, "spread": 0.42, "damage": 20.0}
const STONES := {"annonce": 1.1, "radius": 58.0, "spread": 190.0, "damage": 17.0}
const STAKE := {"annonce": 0.8, "width": 64.0, "length": 600.0, "damage": 26.0, "pierce": 0.7}
const FALL := {"annonce": 1.35, "radius": 118.0, "damage": 30.0}
const SUMMON := {"annonce": 1.0, "max_alive": 5}
const PHASE_PAUSE := 1.4
## Durée de l'éclair d'une frappe (s).
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
## Directions des couloirs de racines (attaque « racines »).
var lines: Array = []
## Centres des cercles (« eboulis » : plusieurs, « chute » : un seul).
var circles: Array = []
## Éclair de la dernière frappe, de 0 à FLASH ; -1 : aucun.
var strike_flash := -1.0
var flash_kind := ""
var flash_lines: Array = []
var flash_circles: Array = []
var flash_aim := Vector2.DOWN
## Points de sortie de l'invocation en cours.
var buds: Array = []
## L'enracinement (compétence de Racine) ne le tient pas.
var no_root := true


func _setup() -> void:
	body_radius = 78.0
	intro_time = 1.5
	death_time = 2.0
	base_hp = BASE_HP
	hp_per_level = HP_PER_LEVEL
	damage_per_level = 0.03
	contact_damage = 17.0
	phase_limits = PHASE_LIMITS
	color = Color("3c3830")


func _projectiles_step(delta: float) -> void:
	if strike_flash >= 0.0:
		strike_flash += delta
		if strike_flash > FLASH:
			strike_flash = -1.0
			flash_kind = ""


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
	else:
		timer -= delta * cad
		_announce_step()
		if timer <= 0.0:
			_strike()


## Coup porté au joueur ; « pierce » : part de son armure ignorée (le pieu).
func _hurt_player(amount: float, pierce := 0.0) -> void:
	var p = main.player
	armor_pierce = pierce
	p.take_hit(amount, self)
	armor_pierce = 0.0


# --- Attaques ---

func _begin(kind: String) -> void:
	var cfg: Dictionary = PHASES[phase]
	if kind == "invocation" and minions.size() >= SUMMON["max_alive"]:
		kind = "eboulis"
	attack = kind
	stage = "annonce"
	Sfx.play("annonce", anchor)
	var to: Vector2 = main.player.position - anchor
	aim = to.normalized() if to.length() > 1.0 else Vector2.DOWN
	match kind:
		"racines":
			_set_timer(ROOTS["annonce"])
			lines = root_dirs(int(cfg["lines"]))
		"eboulis":
			_set_timer(STONES["annonce"])
			circles = []
			var p: Vector2 = main.player.position
			var n := int(cfg["stones"])
			for i in n:
				var at := p
				if i > 0:
					at = p + Vector2.from_angle(TAU * i / float(n - 1) + randf() * 0.5) * randf_range(0.6, 1.0) * STONES["spread"]
				circles.append(_in_arena(at, STONES["radius"] * 0.5))
		"pieu":
			_set_timer(STAKE["annonce"])
		"chute":
			_set_timer(FALL["annonce"])
			circles = [_in_arena(main.player.position, FALL["radius"] * 0.4)]
		"invocation":
			_set_timer(SUMMON["annonce"])
			buds = []
			var n: int = cfg.get("minions", 3)
			for i in n:
				var a := aim.angle() + PI + (i - (n - 1) / 2.0) * 0.8
				buds.append(_in_arena(anchor + Vector2.from_angle(a) * 180.0, 40.0))


func _set_timer(v: float) -> void:
	timer = v
	stage_time = v


## Garde un point dans l'arène (à « margin » du bord).
func _in_arena(p: Vector2, margin: float) -> Vector2:
	var to: Vector2 = p - arena.center
	var lim: float = maxf(40.0, arena.radius - margin)
	return arena.center + to.limit_length(lim)


## Directions des n couloirs de racines, en éventail centré sur « aim ».
func root_dirs(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(Vector2.from_angle(aim.angle() + (i - (n - 1) / 2.0) * ROOTS["spread"]))
	return out


## Pendant le premier temps de l'annonce, le pieu suit le joueur, puis se verrouille.
func _announce_step() -> void:
	if attack == "pieu" and timer > stage_time * 0.4:
		var to: Vector2 = main.player.position - anchor
		if to.length() > 1.0:
			aim = to.normalized()


func _strike() -> void:
	var p = main.player
	var hit_r: float = p.radius * 0.5
	flash_kind = attack
	flash_aim = aim
	flash_lines = lines.duplicate()
	flash_circles = circles.duplicate()
	match attack:
		"racines":
			for d in lines:
				if in_line(p.position, d, ROOTS["width"], ROOTS["length"], hit_r):
					_hurt_player(ROOTS["damage"] * damage_scale)
					break
			main.fx.shake(3.5)
		"eboulis":
			for c in circles:
				if p.position.distance_to(c) < STONES["radius"] + hit_r:
					_hurt_player(STONES["damage"] * damage_scale)
					break
			for c in circles:
				main.fx.ring(c, 8.0, STONES["radius"], 0.3, Color(Art.c("brume"), 0.8), 4.0)
			main.fx.shake(3.0)
		"pieu":
			if in_line(p.position, aim, STAKE["width"], STAKE["length"], hit_r):
				_hurt_player(STAKE["damage"] * damage_scale, STAKE["pierce"])
			main.fx.shake(4.0)
		"chute":
			var c: Vector2 = circles[0]
			if p.position.distance_to(c) < FALL["radius"] + hit_r:
				_hurt_player(FALL["damage"] * damage_scale)
			main.fx.ring(c, 12.0, FALL["radius"], 0.4, Color(Art.ec("racine", "clair"), 0.8), 6.0)
			main.fx.shake(6.0)
		"invocation":
			var kind: String = PHASES[phase].get("minion", "termite")
			for b in buds:
				minions.append(main.spawn_enemy_kind(kind, b, main.threat(b)))
				main.fx.ring(b, 6.0, 46.0, 0.35, Color(Art.ec("racine", "clair"), 0.8), 3.0)
			buds = []
			flash_kind = ""
	if flash_kind != "":
		strike_flash = 0.0
	_end_attack()


## Vrai si pos est dans le couloir parti du boss dans la direction d (largeur w, longueur len).
func in_line(pos: Vector2, d: Vector2, w: float, len: float, margin: float) -> bool:
	var to := pos - anchor
	var along := to.dot(d)
	if along < 0.0 or along > len + margin:
		return false
	return absf(to.dot(d.orthogonal())) < w * 0.5 + margin


func _end_attack() -> void:
	attack = ""
	stage = ""
	lines = []
	circles = []
	gap = PHASES[phase]["gap"]


func _enter_phase(n: int) -> void:
	phase = n
	transition = PHASE_PAUSE
	cycle = 0
	gap = 0.3
	main.fx.ring(anchor, radius, 420.0, 0.7, Color(Art.ec("racine", "clair"), 0.9), 8.0)
	main.fx.shake(5.0)
	if n == 2:
		main.hud.banner("La cime de l'Ancien se fend : des pans de pierre vont tomber.", "combat")
	else:
		main.hud.banner("La forêt se referme autour de l'Ancien pétrifié !", "combat")
		arena.start_shrink()


## Temps avant qu'une attaque annoncée touche ce point (INF si rien ne le menace).
func danger_time(pos: Vector2, margin := 26.0) -> float:
	var best := INF
	match attack:
		"racines":
			for d in lines:
				if in_line(pos, d, ROOTS["width"], ROOTS["length"], margin):
					best = minf(best, timer)
		"eboulis":
			for c in circles:
				if pos.distance_to(c) < STONES["radius"] + margin:
					best = minf(best, timer)
		"pieu":
			# Tant qu'il vise encore, tout le devant est menacé.
			if timer > stage_time * 0.4:
				var to := pos - anchor
				if to.length() < STAKE["length"] and to.normalized().dot(aim) > 0.7:
					best = minf(best, timer)
			elif in_line(pos, aim, STAKE["width"], STAKE["length"], margin):
				best = minf(best, timer)
		"chute":
			for c in circles:
				if pos.distance_to(c) < FALL["radius"] + margin:
					best = minf(best, timer)
	if pos.distance_to(anchor) < radius + margin + 20.0:
		best = minf(best, 0.0)
	return best


func _clear_attacks() -> void:
	attack = ""
	stage = ""
	lines = []
	circles = []
	buds = []
	strike_flash = -1.0


## Le robot tourne autour de lui à distance moyenne : les couloirs s'écartent avec la distance.
func bot_ring(arena_radius: float) -> float:
	return minf(240.0, arena_radius - 60.0)


# --- Dessin ---
#
# Charte : les Flétris sont sombres et saturés, contour clair, braise dans les fentes. L'Ancien est un
# chêne énorme changé en pierre grise : un fût large aux contreforts de racines, un visage creusé
# dans l'écorce (arcades lourdes, yeux de braise), deux bras-branches cassés, une cime de branches
# de pierre où pendent quelques feuilles mortes. Phase 2 : la cime se fend, la braise y couve.
# Phase 3 : l'écorce de pierre s'écaille par plaques et la braise court dans les fentes du fût.

func _stone() -> Color:
	return Art.c("ennemi").lerp(Art.c("brume").darkened(0.42), 0.55).lerp(Art.ec("racine", "sombre"), 0.15)


## Avancée de l'annonce en cours (0 → 1), 0 hors annonce.
func _announce_k() -> float:
	if stage != "annonce" or stage_time <= 0.0:
		return 0.0
	return clampf(1.0 - timer / stage_time, 0.0, 1.0)


func _draw() -> void:
	var r := radius
	var k := _announce_k()
	var die := clampf(dying / death_time, 0.0, 1.0) if dead else 0.0
	var b := Anim.breathe(t, 0.015)
	var rock := _color(_stone())
	var ember := Art.ec("cendre")
	Art.shadow(self, Vector2(0, r * 0.1), r * 1.3)
	# Contreforts de racines qui s'enfoncent dans la roche ; ils rougeoient avant les racines.
	var root := _color(_stone().darkened(0.2))
	for i in 6:
		var a := PI * (0.04 + 0.92 * i / 5.0)
		var tip := Vector2(cos(a) * r * 1.4, sin(a) * r * 0.42 + r * 0.14)
		var base_l := Vector2(cos(a) * r * 0.3 - r * 0.12, r * 0.02)
		var base_r := Vector2(cos(a) * r * 0.3 + r * 0.12, r * 0.02)
		draw_colored_polygon(PackedVector2Array([base_l, tip, base_r]), root.darkened(0.06 * (i % 2)))
		if attack == "racines" and k > 0.0:
			draw_line(Vector2(cos(a) * r * 0.3, r * 0.02), tip, Color(Art.ec("saignement", "clair"), 0.65 * k), 2.5, true)
	# Le fût : large, un peu évasé au pied, qui s'affaisse à la mort.
	var sag := Anim.ease_out(die)
	var hh := r * (1.5 - 0.45 * sag)
	var top := Vector2(0, -hh)
	# Silhouette noueuse : un pied très évasé (contreforts), une taille plus fine, des bosses.
	var trunk := PackedVector2Array([
		Vector2(-r * 0.95, r * 0.14), Vector2(-r * 0.62, -r * 0.05), Vector2(-r * 0.46, -r * 0.4),
		Vector2(-r * 0.52, -hh * 0.55), Vector2(-r * 0.42, -hh * 0.78), top + Vector2(-r * 0.58, r * 0.05),
		top + Vector2(-r * 0.2, -r * 0.08), top + Vector2(r * 0.22, -r * 0.06), top + Vector2(r * 0.6, r * 0.06),
		Vector2(r * 0.44, -hh * 0.76), Vector2(r * 0.5, -hh * 0.5), Vector2(r * 0.45, -r * 0.38),
		Vector2(r * 0.6, -r * 0.04), Vector2(r * 0.98, r * 0.14), Vector2(r * 0.3, r * 0.2), Vector2(-r * 0.3, r * 0.2)])
	Art.volume(self, trunk, rock, 0.65)
	Art.outline(self, trunk, Color(Art.c("ennemi_contour"), 1.0 - die * 0.8), Art.TRAIT_FORT)
	# Fil du bois devenu pierre : des stries qui montent en se tordant.
	var grain := rock.darkened(0.28)
	for i in 5:
		var x := (i - 2) * r * 0.17
		draw_polyline(PackedVector2Array([Vector2(x * 1.5, r * 0.1), Vector2(x, -r * 0.45), Vector2(x * 1.1 + r * 0.04, -hh * 0.7), Vector2(x * 1.2, -hh + r * 0.1)]), grain, 1.6, true)
	# Plaques d'écorce de pierre ; en phase 3 (et à la mort) certaines tombent, la braise dessous.
	var flake_fall := (0.35 if phase >= 3 else 0.0) + die
	for i in 6:
		var px := (-0.3 + 0.2 * (i % 4)) * r
		var py := -hh * (0.2 + 0.13 * i)
		var plate := PackedVector2Array([Vector2(px - r * 0.1, py), Vector2(px + r * 0.08, py - r * 0.06), Vector2(px + r * 0.12, py + r * 0.12), Vector2(px - r * 0.06, py + r * 0.16)])
		if flake_fall > 0.0 and i % 2 == 0:
			draw_colored_polygon(plate, Color(ember, (0.55 + 0.3 * sin(t * 5.0 + i)) * (1.0 - die * 0.5)))
			if dead:
				var drop := Vector2(0, r * 0.9 * die * die) + Vector2((i - 2.5) * r * 0.08 * die, 0)
				var moved := PackedVector2Array()
				for q in plate:
					moved.append(q + drop)
				draw_colored_polygon(moved, Color(rock.lightened(0.1), 1.0 - die))
		else:
			draw_colored_polygon(plate, rock.lightened(0.08))
	# À la mort : le bois vivant apparaît sous la pierre.
	if dead:
		var wood := Art.ec("racine", "sombre").lerp(Art.c("decor_vivant"), 0.25)
		draw_colored_polygon(Art.ellipse(Vector2(0, -hh * 0.5), r * 0.32 * die, hh * 0.32 * die + 0.5, 14), Color(wood, die))
	# Fentes de braise dans le fût (phase 3).
	if phase >= 3 and not dead:
		var fl := Color(ember, 0.6 + 0.3 * sin(t * 5.0))
		draw_polyline(PackedVector2Array([Vector2(-r * 0.2, -r * 0.1), Vector2(-r * 0.05, -r * 0.5), Vector2(-r * 0.18, -hh * 0.8)]), fl, 3.0, true)
		draw_polyline(PackedVector2Array([Vector2(r * 0.25, -r * 0.2), Vector2(r * 0.12, -r * 0.6)]), fl, 2.5, true)
	# Visage : arcades lourdes, yeux de braise, bouche-crevasse.
	var face_y := -hh * 0.62
	var brow := rock.darkened(0.3)
	for sgn in [-1, 1]:
		var e := Vector2(sgn * r * 0.2, face_y)
		draw_colored_polygon(PackedVector2Array([e + Vector2(-sgn * r * 0.16, -r * 0.1), e + Vector2(sgn * r * 0.15, -r * 0.16), e + Vector2(sgn * r * 0.12, -r * 0.06)]), brow)
		draw_circle(e, r * 0.08, Color(Art.c("ennemi_oeil"), 0.35 * (0.4 + 0.6 * k) * (1.0 - die)))
		draw_line(e + Vector2(-r * 0.07, -sgn * r * 0.015), e + Vector2(r * 0.07, sgn * r * 0.015), Color(Art.c("ennemi_oeil"), 1.0 - die), 2.5, true)
	var mouth := PackedVector2Array([Vector2(-r * 0.16, face_y + r * 0.3), Vector2(-r * 0.05, face_y + r * 0.26), Vector2(r * 0.06, face_y + r * 0.31), Vector2(r * 0.16, face_y + r * 0.27), Vector2(r * 0.06, face_y + r * (0.36 + 0.06 * k))])
	draw_colored_polygon(mouth, Color(Art.c("contour"), 0.9))
	# Bras-branches : le droit (du côté visé) se lève pour planter le pieu.
	var raise: float = k if attack == "pieu" else 0.0
	for sgn in [-1.0, 1.0]:
		var up := raise if signf(aim.x if absf(aim.x) > 0.1 else 1.0) == sgn else 0.0
		var sh := top + Vector2(sgn * r * 0.42, r * 0.35)
		var el := sh + Vector2(sgn * r * 0.55, -r * (0.2 + 0.5 * up))
		var hand := el + Vector2(sgn * r * 0.25, -r * (0.35 + 0.5 * up))
		_branch(sh, el, r * 0.16, r * 0.11, rock.darkened(0.08))
		_branch(el, hand, r * 0.11, r * 0.05, rock.darkened(0.12))
		if up > 0.0:
			# Le pieu tenu au bout du bras, qui pâlit en rouge à mesure que l'annonce avance.
			var stake_tip := hand + Vector2(0, -r * 0.45)
			_branch(hand + Vector2(0, r * 0.1), stake_tip, r * 0.08, r * 0.01, rock.lightened(0.1).lerp(Art.ec("saignement", "clair"), 0.5 * up))
	# Cime : trois maîtresses branches de pierre qui portent des masses de feuillage pétrifié (des
	# blocs gris, fendus) ; des branches cassées dépassent. Elle tremble pendant l'éboulis et la chute ;
	# fendue de braise dès la phase 2, dégarnie en phase 3.
	var shake := (3.0 * sin(t * 40.0) * k) if attack in ["eboulis", "chute"] else 0.0
	var crown := top + Vector2(shake, -r * 0.02)
	var cr := rock.lightened(0.05)
	for i in 3:
		var a := -PI / 2.0 + (i - 1) * 0.75
		_branch(crown + Vector2((i - 1) * r * 0.25, r * 0.05), crown + Vector2.from_angle(a) * r * 0.75 + Vector2(0, r * 0.1), r * 0.2, r * 0.1, rock.darkened(0.05))
	for i in 5:
		var a := -PI / 2.0 + (i - 2) * 0.5
		var base := crown + Vector2.from_angle(a) * r * 0.6
		var tip := base + Vector2.from_angle(a + 0.25 * (1 if i % 2 else -1)) * r * (0.55 + 0.15 * (i % 2)) * b
		_branch(base, tip, r * 0.07, r * 0.025, cr.darkened(0.12))
	var thin := 0.82 if phase >= 3 else 1.0
	var lobes := [[0.0, -0.95, 0.5], [-0.62, -0.7, 0.42], [0.62, -0.7, 0.42], [-0.95, -0.3, 0.32], [0.95, -0.3, 0.32], [-0.32, -0.42, 0.4], [0.32, -0.42, 0.4]]
	var mass := _color(_stone().lerp(Art.ec("racine", "sombre"), 0.25).lightened(0.06))
	for l in lobes:
		var q: Vector2 = crown + Vector2(l[0] * r * b, l[1] * r) * thin
		draw_circle(q, r * l[2] * thin + 2.5, Color(Art.c("ennemi_contour"), 0.7 * (1.0 - die)))
	for li in lobes.size():
		var l: Array = lobes[li]
		var q: Vector2 = crown + Vector2(l[0] * r * b, l[1] * r) * thin
		if dead:
			q += Vector2((li - 3) * r * 0.1, r * 1.4 * die * die)
		Art.volume_circle(self, q, r * l[2] * thin, Color(mass.darkened(0.05 * (li % 3)), 1.0 - die * 0.7), 0.55)
		# Fentes de la pierre ; de braise dès la phase 2.
		var fl: Color = Color(ember, 0.55 + 0.3 * sin(t * 4.0 + li)) if phase >= 2 and not dead and li % 2 == 0 else mass.darkened(0.35)
		var cs: float = r * l[2] * thin
		var sd := 1.0 if li % 2 == 0 else -1.0
		draw_polyline(PackedVector2Array([q + Vector2(-0.55 * sd, -0.25) * cs, q + Vector2(-0.15 * sd, 0.05) * cs, q + Vector2(0.12 * sd, -0.12) * cs, q + Vector2(0.5 * sd, 0.18) * cs]), fl, 1.8, true)
	if not dead:
		var leaf := Art.c("decor").lerp(Art.ec("racine", "sombre"), 0.5)
		for i in 6:
			var q := crown + Vector2((i - 2.5) * r * 0.32, -r * (0.25 + 0.12 * (i % 3))) * thin
			draw_colored_polygon(Art.ellipse(q, r * 0.06, r * 0.035, 8), Color(leaf, 0.9))
	# Pierres qui se détachent de la cime pendant l'annonce de l'éboulis.
	if attack == "eboulis" and stage == "annonce":
		for i in 5:
			var q := crown + Vector2((i - 2) * r * 0.3, -r * 0.5 + r * 0.25 * k * (1 + i % 2))
			Art.volume_circle(self, q, r * 0.06, rock.lightened(0.15), 0.6)
	# Mort : des pousses vertes percent la pierre qui tombe.
	if dead:
		for i in 6:
			var u := clampf(die * 1.4 - (i % 3) * 0.15, 0.0, 1.0)
			if u <= 0.01:
				continue
			var foot := Vector2((i - 2.5) * r * 0.22, -hh * (0.15 + 0.12 * (i % 3)))
			draw_line(foot, foot + Vector2(0, -r * 0.25 * u), Art.c("decor_vivant").darkened(0.2), 2.0, true)
			draw_circle(foot + Vector2(0, -r * 0.25 * u), r * 0.05 * u + 0.5, Art.c("decor_vivant"))


## Une branche de pierre (de a à b, largeur w0 → w1), dessinée par un quadrilatère.
func _branch(a: Vector2, bb: Vector2, w0: float, w1: float, col: Color) -> void:
	var n := (bb - a).orthogonal().normalized()
	if n == Vector2.ZERO:
		return
	draw_colored_polygon(PackedVector2Array([a + n * w0, bb + n * w1, bb - n * w1, a - n * w0]), col)


## Annonces au sol, en coordonnées monde (grammaire de Art.telegraph). L'invocation, qui ne blesse
## pas, n'est pas en rouge.
func draw_marks(c: CanvasItem) -> void:
	var k := _announce_k()
	match attack:
		"racines":
			for d in lines:
				Art.telegraph(c, {"type": "ligne", "de": anchor + d * radius * 0.6, "a": anchor + d * ROOTS["length"], "largeur": ROOTS["width"]}, k, -1.0, t)
		"eboulis":
			for p in circles:
				Art.telegraph(c, {"type": "cercle", "centre": p, "rayon": STONES["radius"]}, k, -1.0, t)
				# L'ombre de la pierre qui tombe grandit au milieu du cercle.
				c.draw_colored_polygon(Art.ellipse(p, STONES["radius"] * 0.45 * k + 1.0, STONES["radius"] * 0.25 * k + 1.0, 14), Color(Art.c("ombre"), 0.5))
		"pieu":
			Art.telegraph(c, {"type": "ligne", "de": anchor + aim * radius * 0.6, "a": anchor + aim * STAKE["length"], "largeur": STAKE["width"]}, k, -1.0, t)
		"chute":
			for p in circles:
				Art.telegraph(c, {"type": "cercle", "centre": p, "rayon": FALL["radius"]}, k, -1.0, t)
				c.draw_colored_polygon(Art.ellipse(p, FALL["radius"] * 0.6 * k + 1.0, FALL["radius"] * 0.32 * k + 1.0, 18), Color(Art.c("ombre"), 0.55))
		"invocation":
			var col := Art.ec("racine", "clair")
			for bud in buds:
				c.draw_arc(bud, 30.0 - 12.0 * k, 0.0, TAU, 24, Color(col, 0.35 + 0.5 * k), Art.TRAIT, true)
				Art.volume_circle(c, bud, 6.0 + 8.0 * k, Art.ec("racine", "sombre").lerp(Art.c("ennemi"), k), 0.7)
	if strike_flash < 0.0:
		return
	var f := strike_flash / FLASH
	var rock := _stone()
	match flash_kind:
		"racines":
			for d in flash_lines:
				Art.telegraph(c, {"type": "ligne", "de": anchor + d * radius * 0.6, "a": anchor + d * ROOTS["length"], "largeur": ROOTS["width"]}, 1.0, f, t)
				# Racines de pierre qui jaillissent le long du couloir.
				for j in 6:
					var at: Vector2 = anchor + d * (radius + 60.0 + j * 75.0)
					var n: Vector2 = d.orthogonal() * ((j % 2) * 2 - 1)
					var tip: Vector2 = at + Vector2(0, -26.0 * (1.0 - f)) + n * 8.0
					c.draw_colored_polygon(PackedVector2Array([at - d * 9.0, tip, at + d * 9.0]), rock.darkened(0.1 * (j % 2)))
		"eboulis":
			for p in flash_circles:
				Art.telegraph(c, {"type": "cercle", "centre": p, "rayon": STONES["radius"]}, 1.0, f, t)
				Art.volume(c, Art.ellipse(p, 22.0, 15.0, 10), rock.lightened(0.1), 0.6)
		"pieu":
			Art.telegraph(c, {"type": "ligne", "de": anchor + flash_aim * radius * 0.6, "a": anchor + flash_aim * STAKE["length"], "largeur": STAKE["width"]}, 1.0, f, t)
			# Les pieux plantés tout le long de la ligne.
			for j in 7:
				var at: Vector2 = anchor + flash_aim * (radius + 40.0 + j * 72.0)
				var tip: Vector2 = at + Vector2(0, -38.0 * (1.0 - 0.6 * f))
				c.draw_colored_polygon(PackedVector2Array([at + Vector2(-8, 0), tip, at + Vector2(8, 0)]), rock.lightened(0.12))
				c.draw_line(at, tip, Color(Art.ec("saignement", "clair"), 0.7 * (1.0 - f)), 1.5, true)
		"chute":
			for p in flash_circles:
				Art.telegraph(c, {"type": "cercle", "centre": p, "rayon": FALL["radius"]}, 1.0, f, t)
				Art.volume(c, Art.ellipse(p, 54.0, 34.0, 14), rock.lightened(0.05), 0.6)


## Le pieu levé est dessiné par le corps ; rien au-dessus des personnages.
func draw_overlay(_c: CanvasItem) -> void:
	pass


## L'Ancien endormi : un chêne de pierre trapu, cime cassée, au milieu de sa clairière.
static func draw_sleeper(a: Node2D) -> void:
	var c: Vector2 = a.center
	var r := 48.0
	Art.shadow(a, c + Vector2(0, r * 0.3), r * 1.3)
	var rock := Art.c("ennemi").lerp(Art.c("brume").darkened(0.42), 0.55).darkened(0.2)
	var trunk := PackedVector2Array([c + Vector2(-r * 0.5, r * 0.2), c + Vector2(-r * 0.36, -r * 1.1), c + Vector2(r * 0.36, -r * 1.1), c + Vector2(r * 0.52, r * 0.2)])
	Art.volume(a, trunk, rock, 0.6)
	for i in 5:
		var ang := -PI / 2.0 + (i - 2) * 0.45
		var base := c + Vector2((i - 2) * r * 0.15, -r * 1.05)
		var tip := base + Vector2.from_angle(ang) * r * 0.65
		var n := (tip - base).orthogonal().normalized()
		a.draw_colored_polygon(PackedVector2Array([base + n * 5.0, tip + n * 2.0, tip - n * 2.0, base - n * 5.0]), rock.darkened(0.08))
	if a.state == "ouverte":
		var pulse := 0.45 + 0.35 * sin(a.t * 2.0)
		for sgn in [-1, 1]:
			a.draw_circle(c + Vector2(sgn * r * 0.18, -r * 0.7), r * 0.07, Color(Art.ec("cendre", "clair"), pulse))


## Après la victoire : une clairière moussue et un jeune chêne, là où se tenait l'Ancien.
static func draw_victory(a: Node2D) -> void:
	var c: Vector2 = a.center
	a.draw_colored_polygon(Art.ellipse(c, 80.0, 30.0, 24), Color(Art.c("decor_vivant").darkened(0.2), 0.7))
	# Débris de pierre moussus autour.
	for i in 6:
		var ang := TAU * i / 6.0 + 0.3
		var p := c + Vector2(cos(ang) * 70.0, sin(ang) * 26.0)
		Art.volume(a, Art.ellipse(p, 11.0, 7.0, 8), Art.c("brume").darkened(0.35), 0.5)
		a.draw_colored_polygon(Art.ellipse(p + Vector2(0, -4), 7.0, 2.5, 8), Art.c("decor_vivant"))
	var bark := Art.ec("racine", "sombre").lerp(Art.c("decor_vivant"), 0.15)
	a.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-3, -52), c + Vector2(4, -52), c + Vector2(7, 0)]), bark)
	var leaf := Art.c("decor_vivant").lerp(Art.ec("racine", "clair"), 0.25)
	for l in [[0, -66, 20], [-16, -56, 15], [16, -56, 15], [-8, -46, 13], [9, -46, 13]]:
		Art.volume_circle(a, c + Vector2(l[0], l[1]), l[2], leaf, 0.6)
	Art.glow(a, c + Vector2(0, -20), 36.0, "racine")
