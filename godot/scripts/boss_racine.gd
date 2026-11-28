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
## Cycle 2 et après (New Game+, BossBase › cycle exalté) :
##   - foulee (attaque nouvelle) : il marche sur le joueur : un grand cercle se marque sous lui, le pied
##              de pierre tombe sur un temps de la musique, puis le suivant là où le joueur est allé
##              (trois pas, quatre en phase exaltée) : ne pas rester, ne pas revenir sur ses pas ;
##   - phase 4 exaltée (« la pierre se fend ») : le pieu part en éventail de trois.
## L'enracinement ne le tient pas (no_root). Sa mort : l'écorce de pierre se fend et tombe par
## plaques, le bois vivant apparaît dessous ; à sa place, une clairière moussue et un jeune chêne
## (draw_victory).
##
## Le socle (vie, phases, états, mort, interface d'ennemi) est dans boss_base.gd.
extends BossBase

const Ancien = preload("res://scripts/creature_art/racine/_ancien.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const BossBake = preload("res://scripts/boss_bake.gd")

const PHASE_LIMITS := [0.66, 0.33]
## Vie : base + par niveau du joueur (réglée au robot : --autotest=boss au niveau 20).
const BASE_HP := 440.0
const HP_PER_LEVEL := 145.0
## Par phase : pause entre deux attaques, ordre des attaques et ampleur.
const PHASES := {
	1: {"gap": 1.3, "order": ["racines", "eboulis", "pieu", "racines", "eboulis", "pieu"], "lines": 3, "stones": 4},
	2: {"gap": 1.1, "order": ["eboulis", "invocation", "racines", "chute", "pieu", "racines"], "lines": 4, "stones": 5, "minions": 3, "minion": "termite"},
	3: {"gap": 0.95, "order": ["racines", "pieu", "chute", "eboulis", "invocation", "racines", "pieu"], "lines": 5, "stones": 6, "minions": 2, "minion": "scarabee"},
	# Phase exaltée (cycle 2 et après seulement).
	4: {"gap": 0.9, "order": ["foulee", "pieu", "racines", "chute", "foulee", "eboulis", "pieu"], "lines": 5, "stones": 6, "minions": 2, "minion": "scarabee", "steps": 4, "stakes": 3},
}
## Attaque nouvelle du cycle exalté (BossBase).
const EXALTED_ATTACK := "foulee"
## Foulée : pas (cercles successifs sous le joueur), première annonce, annonce des pas suivants.
const STRIDE := {"annonce": 1.0, "next": 0.7, "radius": 92.0, "damage": 22.0, "steps": 3}
## Phase exaltée : écart (radians) entre les pieux de l'éventail.
const STAKE_FAN := 0.5
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
## Pas de la foulée encore à faire (le premier compris).
var steps_left := 0
## L'enracinement (compétence de Racine) ne le tient pas.
var no_root := true


func _setup() -> void:
	body_radius = 78.0
	# Corps à l'écran (héros caché derrière : player.gd) : cime de pierre.
	cover = Vector2(1.7, 2.8)
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
			var order: Array = exalted_order(PHASES[phase]["order"], EXALTED_ATTACK)
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
		"foulee":
			exalted_attacks += 1
			steps_left = int(cfg.get("steps", STRIDE["steps"]))
			# Chaque pied tombe sur un temps de la musique.
			_set_timer(loop_snap(STRIDE["annonce"]))
			circles = [_in_arena(main.player.position, STRIDE["radius"] * 0.4)]
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


## Directions des pieux : un seul, ou l'éventail de trois en phase exaltée.
func stake_dirs() -> Array:
	var n := int(PHASES[phase].get("stakes", 1))
	var out: Array = []
	for i in n:
		out.append(aim.rotated((i - (n - 1) / 2.0) * STAKE_FAN))
	return out


func _strike() -> void:
	var p = main.player
	var hit_r: float = p.radius * 0.5
	if attack == "foulee":
		_stride_step(p, hit_r)
		return
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
			for d in stake_dirs():
				if in_line(p.position, d, STAKE["width"], STAKE["length"], hit_r):
					_hurt_player(STAKE["damage"] * damage_scale, STAKE["pierce"])
					break
			flash_lines = stake_dirs()
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


## Un pas de la foulée : le pied tombe dans le cercle ; s'il en reste, le suivant se marque sous le
## joueur (là où il est allé), et tombe sur le temps suivant.
func _stride_step(p, hit_r: float) -> void:
	var c: Vector2 = circles[0]
	if p.position.distance_to(c) < STRIDE["radius"] + hit_r:
		_hurt_player(STRIDE["damage"] * damage_scale)
	main.fx.ring(c, 12.0, STRIDE["radius"], 0.35, Color(Art.ec("racine", "clair"), 0.85), 6.0)
	main.fx.shake(5.0)
	flash_kind = "foulee"
	flash_circles = [c]
	strike_flash = 0.0
	steps_left -= 1
	if steps_left > 0:
		circles = [_in_arena(p.position, STRIDE["radius"] * 0.4)]
		_set_timer(loop_snap(STRIDE["next"]))
		return
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
	steps_left = 0
	gap = PHASES[phase]["gap"]


func _enter_phase(n: int) -> void:
	phase = n
	transition = PHASE_PAUSE
	cycle = 0
	gap = 0.3
	main.fx.ring(anchor, radius, 420.0, 0.7, Color(Art.ec("racine", "clair"), 0.9), 8.0)
	main.fx.shake(5.0)
	# Phase 3, ou la phase exaltée atteinte d'un coup : l'arène se resserre (une seule fois).
	if n >= 3 and not arena.shrinking and arena.radius >= arena.max_radius:
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
				var cone := 0.7 if stake_dirs().size() == 1 else 0.3
				if to.length() < STAKE["length"] and to.normalized().dot(aim) > cone:
					best = minf(best, timer)
			else:
				for d in stake_dirs():
					if in_line(pos, d, STAKE["width"], STAKE["length"], margin):
						best = minf(best, timer)
		"foulee":
			for c in circles:
				if pos.distance_to(c) < STRIDE["radius"] + margin:
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
	steps_left = 0
	strike_flash = -1.0


## Le robot tourne autour de lui à distance moyenne : les couloirs s'écartent avec la distance.
func bot_ring(arena_radius: float) -> float:
	return minf(240.0, arena_radius - 60.0)


func _exalt_color() -> Color:
	return Art.bc("braise")


# --- Dessin ---
#
# « Bestiaire d'herbier » (refonte des personnages, vague 2 B1) : l'Ancien est un chêne de pierre remis
# debout par ses racines, comme le Menhir et le Tertre (scripts/creature_art/racine/_ancien.gd). Vue de
# trois quarts, tourné vers le joueur. Son corps et le sol sont cuits en sprites (boss_bake.gd) ; les
# bras-branches (le bras du côté du joueur se lève pour planter le pieu), les yeux de braise et les
# pierres de l'éboulis sont dessinés en direct. Phase 2 : la cime se fend de braise. Phase 3 : l'écorce
# de pierre s'écaille, la braise court dans le fût. Les annonces au sol (draw_marks) gardent la
# grammaire de Art.telegraph.

const FEET := 0.3

var facing := 1.0
var _life: Node2D


func _ready() -> void:
	super._ready()
	use_tint_material()
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


func _stone() -> Color:
	return Art.bc("racine", "clair")


## Avancée de l'annonce en cours (0 → 1), 0 hors annonce.
func _announce_k() -> float:
	if stage != "annonce" or stage_time <= 0.0:
		return 0.0
	return clampf(1.0 - timer / stage_time, 0.0, 1.0)


func _body_xf() -> Transform2D:
	var wake := 1.0 - clampf(intro / intro_time, 0.0, 1.0) if intro_time > 0.0 else 1.0
	var k := _announce_k()
	var s := lerpf(0.4, 1.0, Anim.ease_out(wake))
	# La cime tremble avant l'éboulis et la chute ; un tremblement pendant un changement de phase.
	var shift := Vector2.ZERO
	if attack in ["eboulis", "chute", "foulee"]:
		shift.x = 3.0 * sin(t * 40.0) * k
	if transition > 0.0:
		shift += Vector2(sin(t * 50.0), cos(t * 43.0)) * 3.0
	return Transform2D(0.0, Vector2(s * facing, s), 0.0, Vector2(0, radius * FEET) + shift)


func _draw() -> void:
	update_tint()
	var die := clampf(dying / death_time, 0.0, 1.0) if dead else 0.0
	modulate.a = 1.0 - Anim.ease_in(clampf((die - 0.6) / 0.4, 0.0, 1.0))
	if main and main.player and not dead:
		var dx: float = main.player.position.x - anchor.x
		if absf(dx) > 30.0:
			facing = signf(dx)
	var xf := _body_xf()
	var ux := xf * Transform2D(0.0, Vector2.ONE * Ancien.HEIGHT / 100.0, 0.0, Vector2.ZERO)
	var atlas = BossBake.get_atlas(self, Ancien)
	draw_exalt_aura(self, xf * Vector2(0, -radius * 0.9), radius * 1.35)
	# La phase exaltée garde le dessin cuit de la phase 3 (sa lueur est dessinée en direct).
	var ph := mini(phase, 3)
	_draw_part(atlas, "sol", "p%d" % ph, 0.0, xf, {"phase": ph})
	var k := _announce_k()
	# Le bras du côté du joueur se lève pour le pieu (le bras « devant », côté +x du dessin).
	var raise: float = k if attack == "pieu" else 0.0
	if not dead:
		_arm(ux, -1.0, 0.0, false)
	if dead:
		_draw_part(atlas, "corps", "mort", die, xf, {"phase": 3, "die": die}, false)
		return
	_draw_part(atlas, "corps", "p%d" % ph, fposmod(t / Ancien.LOOP, 1.0), xf, {"phase": ph, "t": fposmod(t, Ancien.LOOP)})
	_arm(ux, 1.0, raise, attack == "pieu")
	# Yeux de braise, plus vifs pendant une annonce.
	var ann := 1.0 if stage == "annonce" else 0.0
	for i in Ancien.EYES.size():
		var e: Array = Ancien.EYES[i]
		var hit := 1.0 if hit_flash > 0.0 else 0.0
		if hit > 0.4:
			Ink.brush(self, ux, PackedVector2Array([e[0], e[0] + Vector2.from_angle(e[1]) * e[2]]), e[3] * 0.6, Ink.encre())
		else:
			Ink.ember(self, ux, Ink.leaf(e[0], e[1], e[2], e[3]), 0.4 + 0.6 * ann)
	# Pierres qui se détachent de la cime pendant l'annonce de l'éboulis.
	if attack == "eboulis" and stage == "annonce":
		var rock := Art.bc("racine", "cendre")
		for i in 5:
			var q: Vector2 = ux * (Ancien.CROWN + Vector2((i - 2) * 26.0, -20.0 + 40.0 * k * (1 + i % 2)))
			draw_circle(q, 6.0, Art.bc("encre"))
			draw_circle(q + Vector2(-0.8, -0.8), 4.6, rock)


func _draw_part(atlas, group: String, anim: String, u: float, xf: Transform2D, o: Dictionary, loop := true) -> void:
	if atlas != null and atlas.draw_blend(self, group, anim, u, xf, loop):
		return
	if BossBake.no_render():
		return
	o["groupe"] = group
	draw_set_transform_matrix(xf)
	Ancien.draw(self, Vector2.ZERO, Ancien.HEIGHT, o)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Bras-branche (unités du dessin) : sgn -1 au fond, 1 devant ; up : levé (0 → 1) ; stake : le pieu
## de pierre tenu au bout, qui rougit à mesure que l'annonce avance.
func _arm(ux: Transform2D, sgn: float, up: float, stake: bool) -> void:
	var sh: Vector2 = Ancien.SHOULDERS[0 if sgn < 0.0 else 1]
	var sway := sin(t * 1.3 + sgn) * 2.0
	var el := sh + Vector2(sgn * 30.0, 22.0 + sway).lerp(Vector2(sgn * 22.0, -34.0), up)
	var hand := el + Vector2(sgn * 12.0, 26.0).lerp(Vector2(sgn * 6.0, -40.0), up)
	var wood := Art.bc("racine", "bois")
	if sgn < 0.0:
		wood = Art.bc("racine", "bois_ombre")
	var pts := PackedVector2Array([sh, el, hand])
	Ink.brush(self, ux, pts, 15.0, Ink.encre(), 1.0, 0.5)
	Ink.brush(self, ux, pts, 11.0, wood, 1.0, 0.45)
	Ink.brush(self, ux, PackedVector2Array([sh.lerp(el, 0.2), el]), 3.0, wood.lightened(0.3), 0.0, 0.0)
	# Doigts de rameaux.
	var d := (hand - el).normalized()
	for i in 3:
		var f := hand + d.rotated((i - 1) * 0.6) * 12.0
		Ink.brush(self, ux, PackedVector2Array([hand, f]), 5.0, Ink.encre(), 1.0, 0.0)
		Ink.brush(self, ux, PackedVector2Array([hand, f]), 3.2, wood, 1.0, 0.0)
	if stake and up > 0.0:
		var col := Art.bc("racine", "cendre").lerp(Art.ec("saignement", "clair"), 0.5 * up)
		var spike := Ink.thorn(hand + Vector2(0, 6), -PI * 0.5, 56.0, 13.0)
		Ink.flat(self, ux, spike, col, 2.0)
		Ink.brush(self, ux, PackedVector2Array([hand + Vector2(-2, 0), hand + Vector2(-1, -44)]), 2.0, col.lightened(0.3))


## Au-dessus de la teinte : la vie qui reprend sous la pierre à sa mort, les états visibles.
func draw_life(c: CanvasItem) -> void:
	var xf := _body_xf()
	var ux := xf * Transform2D(0.0, Vector2.ONE * Ancien.HEIGHT / 100.0, 0.0, Vector2.ZERO)
	var mid: Vector2 = ux * Vector2(0, -70)
	if statuses.has("saignement"):
		Art.status(c, "saignement", mid, radius * 0.7, t * 1.25)
	if poison_time > 0.0:
		Art.status(c, "poison", mid, radius * 0.7, t)
	var die := clampf(dying / death_time, 0.0, 1.0) if dead else 0.0
	if dead and die > 0.35:
		Art.glow(c, mid, radius * 0.8 * Anim.ease_out((die - 0.35) / 0.65), "seve")


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
			for d in stake_dirs():
				Art.telegraph(c, {"type": "ligne", "de": anchor + d * radius * 0.6, "a": anchor + d * STAKE["length"], "largeur": STAKE["width"]}, k, -1.0, t)
		"foulee":
			for p in circles:
				Art.telegraph(c, {"type": "cercle", "centre": p, "rayon": STRIDE["radius"]}, k, -1.0, t)
				# L'ombre du pied de pierre qui descend.
				c.draw_colored_polygon(Art.ellipse(p, STRIDE["radius"] * 0.55 * k + 1.0, STRIDE["radius"] * 0.3 * k + 1.0, 16), Color(Art.c("ombre"), 0.55))
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
					# Pour certains angles la pointe tombe sur la base : triangle plat, rien à dessiner.
					Art.safe_polygon(c, PackedVector2Array([at - d * 9.0, tip, at + d * 9.0]), rock.darkened(0.1 * (j % 2)))
		"eboulis":
			for p in flash_circles:
				Art.telegraph(c, {"type": "cercle", "centre": p, "rayon": STONES["radius"]}, 1.0, f, t)
				Art.volume(c, Art.ellipse(p, 22.0, 15.0, 10), rock.lightened(0.1), 0.6)
		"pieu":
			for d in (flash_lines if not flash_lines.is_empty() else [flash_aim]):
				Art.telegraph(c, {"type": "ligne", "de": anchor + d * radius * 0.6, "a": anchor + d * STAKE["length"], "largeur": STAKE["width"]}, 1.0, f, t)
				# Les pieux plantés tout le long de la ligne.
				for j in 7:
					var at: Vector2 = anchor + d * (radius + 40.0 + j * 72.0)
					var tip: Vector2 = at + Vector2(0, -38.0 * (1.0 - 0.6 * f))
					c.draw_colored_polygon(PackedVector2Array([at + Vector2(-8, 0), tip, at + Vector2(8, 0)]), rock.lightened(0.12))
					c.draw_line(at, tip, Color(Art.ec("saignement", "clair"), 0.7 * (1.0 - f)), 1.5, true)
		"foulee":
			for p in flash_circles:
				Art.telegraph(c, {"type": "cercle", "centre": p, "rayon": STRIDE["radius"]}, 1.0, f, t)
				# Le pied de pierre posé : une large empreinte et des éclats.
				Art.volume(c, Art.ellipse(p, 46.0, 26.0, 14), rock.darkened(0.05), 0.6)
				for j in 5:
					var q: Vector2 = p + Vector2.from_angle(TAU * j / 5.0 + 0.3) * STRIDE["radius"] * (0.5 + 0.4 * f)
					c.draw_circle(q, 5.0 * (1.0 - f) + 1.0, rock.lightened(0.1))
		"chute":
			for p in flash_circles:
				Art.telegraph(c, {"type": "cercle", "centre": p, "rayon": FALL["radius"]}, 1.0, f, t)
				Art.volume(c, Art.ellipse(p, 54.0, 34.0, 14), rock.lightened(0.05), 0.6)


## Le pieu levé est dessiné par le corps ; rien au-dessus des personnages.
func draw_overlay(_c: CanvasItem) -> void:
	pass


## L'Ancien endormi : la cime basse, les yeux clos ; arène ouverte, la braise couve sous ses arcades.
static func draw_sleeper(a: Node2D) -> void:
	var feet: Vector2 = a.center + Vector2(0, 78.0 * FEET)
	var xf := Transform2D(0.0, feet)
	var atlas = BossBake.get_atlas(a, Ancien)
	if BossBake.no_render():
		return
	if atlas == null or not atlas.draw_blend(a, "sol", "p1", 0.0, xf):
		a.draw_set_transform_matrix(xf)
		Ancien.draw(a, Vector2.ZERO, Ancien.HEIGHT, {"groupe": "sol", "phase": 1})
	if atlas == null or not atlas.draw_blend(a, "corps", "dort", 0.0, xf):
		a.draw_set_transform_matrix(xf)
		Ancien.draw(a, Vector2.ZERO, Ancien.HEIGHT, {"sleep": true})
	a.draw_set_transform_matrix(Transform2D.IDENTITY)
	if a.state == "ouverte":
		var ux := xf * Transform2D(0.0, Vector2.ONE * Ancien.HEIGHT / 100.0, 0.0, Vector2.ZERO)
		var pulse := 0.45 + 0.35 * sin(a.t * 2.0)
		for e in Ancien.EYES:
			Ink.halo(a, ux * e[0], 12.0, Art.bc("braise"), 1.0 + 1.5 * pulse)


## Après la victoire : une clairière moussue et un jeune chêne, là où se tenait l'Ancien.
static func draw_victory(a: Node2D) -> void:
	var feet: Vector2 = a.center
	var xf := Transform2D(0.0, feet)
	var atlas = BossBake.get_atlas(a, Ancien)
	if BossBake.no_render():
		return
	if atlas == null or not atlas.draw_blend(a, "vaincu", "vaincu", 0.0, xf):
		a.draw_set_transform_matrix(xf)
		Ancien.draw(a, Vector2.ZERO, Ancien.HEIGHT, {"groupe": "vaincu"})
		a.draw_set_transform_matrix(Transform2D.IDENTITY)
	Art.glow(a, feet + Vector2(0, -20), 36.0, "racine")
