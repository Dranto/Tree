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
## Cycle exalté (NG+, à partir du cycle 2, boss_base.gd › Cycle exalté) :
##   - étreinte (phase exaltée, et phase 3 quand cycles.json le demande) : un anneau de ronces se
##     referme autour du joueur, ouvert d'une brèche tournée à l'opposé d'elle (anneau au sol qui suit le joueur puis se fige) ; la bande
##     jaillit, puis reste un moment hérissée et blesse qui la traverse : sortir par la brèche ;
##   - phase exaltée (sous 22 % de sa vie) : la rose s'embrase d'encre, chaque coup tombe sur un temps
##     de sa musique, l'étreinte se double d'une racine en son centre (il faut sortir de l'anneau),
##     les fouets tournent comme en phase 3, plus d'invocation.
##
## Au rythme de son morceau (ronce.wav d'Antoine, 160 BPM, la mineur ; assets/music/hand/ronce.json) :
## l'intro monte sous la musique du monde à l'approche de son enceinte, elle charge pendant la
## dernière mesure avant le drop et frappe sur le drop. Puis elle joue une partition (SCORE) : chaque
## phase suit sa boucle en phrases de quatre mesures, chaque attaque frappe sur son temps ; par-dessus,
## la batterie elle-même attaque (DRUMS_POWER) : ses grosses caisses lancent des ondes de ronces, ses
## caisses claires des épines en spirale, ses charlestons des aiguilles en jet tournant et ses caisses
## douces de petites racines autour du joueur. Chaque phase en joue plus (plus de percussions suivies,
## plus de jets, des ondes plus larges), jusqu'à la phase exaltée. Sans morceau, l'ordre de PHASES.
##
## Le socle commun (vie, phases, états, mort, interface d'ennemi) est dans boss_base.gd ; ce
## fichier ne décrit que ses attaques et son dessin. Nommée dans data/regions/ronce.json › boss.
extends BossBase

const Mere = preload("res://scripts/creature_art/ronce/_mere_ronce.gd")
const O = preload("res://scripts/creature_art/ronce/_outils.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")
const BossBake = preload("res://scripts/boss_bake.gd")
const Exalte = preload("res://scripts/boss_art/exalte.gd")
const BossScore = preload("res://scripts/boss_score.gd")

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
	# Phase exaltée (cycle 2 et plus seulement).
	4: {"gap": 0.85, "order": ["etreinte", "fouets", "volee", "etreinte", "racines"], "thorns": 13, "volleys": 3, "roots": 6, "whips": 2, "minions": 0},
}
## Attaque nouvelle du cycle exalté (boss_base.gd › Cycle exalté).
const EXALTED_ATTACK := "etreinte"
## Étreinte : anneau (rayons intérieur et extérieur), brèche (radians), annonce dont la part « lock »
## finale est figée, dégâts du jaillissement, puis le roncier tient « hold » s et pique tous les « tick ».
const EMBRACE := {"annonce": 1.25, "lock": 0.45, "inner": 62.0, "outer": 132.0, "gap": 1.1, "damage": 20.0, "flash": 0.3, "hold": 1.8, "tick": 0.5, "wall_damage": 8.0}
const VOLLEY := {"annonce": 0.9, "between": 0.35, "damage": 14.0, "speed": 360.0, "radius": 8.0, "spread": 0.2}
const WHIP := {"annonce": 1.1, "frappe": 0.75, "damage": 20.0, "length": 340.0, "width": 22.0}
const ROOT := {"every": 0.45, "fuse": 0.85, "damage": 18.0, "radius": 64.0, "burst": 0.35}
const SUMMON := {"annonce": 1.0, "max_alive": 6}
const PHASE_PAUSE := 1.4
## Enracinée, elle prépare ses attaques plus lentement, puis y résiste un moment.
const ROOTED_CADENCE := 0.55
const ROOT_IMMUNITY := 6.0
const BLEED_STACKS := 5

# --- Partition sur son morceau (boss_sync.gd : horloge audio, ou temps du jeu sans son) ---
# Une phrase = quatre mesures (16 temps), une attaque par mesure environ, souvent sur la grosse caisse
# du premier temps ; « coups » : [temps de la phrase, attaque] ; l'annonce part
# ANNOUNCE_BEATS temps avant (un coup que l'attaque d'avant serre trop est sauté : boss_score.gd › skipped).
# « ondes » : mesures de la phrase (0-3) où les grosses caisses lancent de vraies ondes (sinon celles
# de DRUMS_POWER) ; « deluge » : toute la batterie, au plus fort. Les phrases se répètent sur la boucle.
const SCORE := {
	1: {"loop": "boucle_1", "phrases": [
		{"coups": [[0, "volee"], [4, "fouets"], [8, "racines"], [12, "volee"]]},
		{"coups": [[0, "fouets"], [6, "volee"], [10, "racines"], [13, "volee"]]},
	]},
	2: {"loop": "boucle_2", "phrases": [
		{"coups": [[0, "volee"], [5, "fouets"], [9, "racines"], [12, "volee"]]},
		{"coups": [[1, "invocation"], [4, "fouets"], [8, "volee"], [12, "racines"]]},
		{"coups": [[0, "fouets"], [5, "volee"], [9, "racines"], [12, "fouets"]]},
		{"coups": [[0, "volee"], [4, "racines"], [8, "fouets"], [12, "volee"]], "ondes": [0, 2]},
	]},
	3: {"loop": "boucle_3", "phrases": [
		{"coups": [[0, "fouets"], [4, "volee"], [9, "racines"], [12, "fouets"]]},
		{"coups": [[1, "invocation"], [4, "fouets"], [8, "volee"], [13, "racines"]], "ondes": [0, 1, 2, 3]},
	]},
	4: {"loop": "boucle_4", "phrases": [
		{"coups": [[0, "etreinte"], [3, "fouets"], [8, "volee"], [13, "racines"]]},
		{"coups": [[1, "etreinte"], [4, "fouets"], [9, "volee"], [14, "racines"]]},
		{"coups": [[2, "etreinte"], [5, "fouets"], [9, "volee"], [14, "racines"]]},
		{"coups": [[2, "etreinte"], [5, "fouets"], [9, "volee"]], "deluge": true},
	]},
}
## Ce que la batterie déclenche, phase par phase (la difficulté monte avec elles) :
##   ondes : mesures de la phrase où une grosse caisse franche lance une onde de ronces (les autres
##           grosses caisses, et les douces, un pouls : onde courte qui s'éteint à « pulse » px) ;
##   roll  : épines par caisse claire (0 : elles ne tirent pas), « roll_grid » : seulement les caisses
##           sur une double croche multiple (4 : sur les temps, 2 : les croches, 1 : toutes) ;
##   spark : aiguilles par charleston, « spark_grid » : même filtre ;
##   prick : petites racines par caisse douce (note fantôme), autour du joueur.
const DRUMS_POWER := {
	1: {"ondes": [], "pulse": 200.0, "roll": 1, "roll_grid": 4, "spark": 1, "spark_grid": 2, "prick": 0},
	2: {"ondes": [0], "pulse": 240.0, "roll": 2, "roll_grid": 4, "spark": 1, "spark_grid": 2, "prick": 1},
	3: {"ondes": [0, 2], "pulse": 280.0, "roll": 2, "roll_grid": 2, "spark": 2, "spark_grid": 2, "prick": 1},
	4: {"ondes": [0, 1, 2, 3], "pulse": 320.0, "roll": 3, "roll_grid": 1, "spark": 2, "spark_grid": 1, "prick": 2},
}
## Annonce (en temps) de chaque attaque de la partition.
const ANNOUNCE_BEATS := {"volee": 2, "fouets": 3, "racines": 2, "invocation": 3, "etreinte": 4}
const MIN_ANNOUNCE := 2.0
## Sur la partition, elle frappe plus souvent qu'au gré des pauses : chaque coup blesse moins.
const SCORE_DAMAGE := 0.6
## Coups de batterie quand le morceau n'en donne pas (une phrase de quatre mesures, doubles croches).
const DRUMS := {"kick": [[0, 8], [2, 8, 12], [0, 8], [2, 8, 12]], "kick_doux": [[], [], [], []], "caisse": [[4, 12], [4, 12], [4, 12], [4, 10, 12, 14]],
	"charleston": [[0, 2, 4, 6, 8, 10, 12, 14], [0, 4, 7, 10, 14], [0, 2, 4, 6, 8, 10, 12, 14], [0, 4, 7, 10, 14]], "caisse_douce": [[11, 15], [2, 6], [11, 15], [2, 6]]}
## Onde de ronces (grosses caisses) : annonce (temps : la bande se ramasse autour d'elle), vitesse,
## épaisseur, brèches (nombre, ouverture en radians, pas de côté une onde sur deux), dégâts, au plus.
const WAVE := {"lead": 2.0, "speed": 430.0, "width": 24.0, "gaps": 4, "gap": 0.95, "step": 0.3, "damage": 5.0, "max": 8}
## Pouls (autres grosses caisses) : annonce (temps), épaisseur, dégâts.
const PULSE := {"lead": 1.0, "width": 14.0, "damage": 2.0}
## Épines en spirale (caisses claires) : pas de la spirale (radians par coup), vitesse, rayon, dégâts.
const ROLL := {"spin": 0.55, "speed": 280.0, "radius": 6.0, "damage": 4.0}
## Aiguilles (charlestons) : pas du jet, vitesse, rayon, dégâts.
const SPARK := {"step": 0.42, "speed": 240.0, "radius": 4.0, "damage": 1.5}
## Petites racines (caisses douces) : annonce (temps), rayon, dégâts, distance au joueur, au plus.
const PRICK := {"lead": 2.0, "radius": 28.0, "damage": 3.0, "near": 50.0, "far": 100.0, "max": 12, "burst": 0.25}

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
## Étreintes : {"pos", "gap" (angle de la brèche), "fuse" (avant de jaillir), "hold" (après), "tick"}.
var embraces: Array = []

## Partition et batterie sur son morceau (boss_score.gd : coups, coups sautés, coups joués).
var score
## Temps du morceau où tombe la frappe annoncée (-1 : sans grille) ; racines de la partition : temps
## de la première et racines posées.
var _strike_beat := -1.0
var _roots_beat := -1.0
var _roots_placed := 0
## Ondes de ronces : {"r", "fuse", "total", "gaps", "hit", "reach", "small"}.
var waves: Array = []
var _wave_count := 0
var _roll_spin := 0.0
var _spark_angle := 0.0
## Petites racines des caisses douces : {"pos", "fuse", "total", "burst"}.
var pricks: Array = []
var _prick_rng := RandomNumberGenerator.new()
## Sursaut du corps sur une grosse caisse (0 → 1), -1 : aucun.
var drum_flash := -1.0


## Nombres du socle (boss_base.gd) : ceux de la Mère-Ronce.
func _setup() -> void:
	score = BossScore.new(self, SCORE, DRUMS_POWER, ANNOUNCE_BEATS, {"onde": WAVE["lead"], "pouls": PULSE["lead"], "piqure": PRICK["lead"]}, DRUMS)
	score.min_announce = MIN_ANNOUNCE
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


## Ordre des attaques de la phase en cours (l'étreinte glissée en phase 3 si le cycle le veut).
func _order() -> Array:
	return exalted_order(PHASES[phase]["order"], EXALTED_ATTACK)


func _exalt_color() -> Color:
	return Art.bc("braise")


## Ce qu'elle charge sur la dernière mesure avant le drop : la braise de sa rose.
func _charge_color() -> Color:
	return Art.bc("braise")


## Le drop : le combat part d'un coup, une couronne d'épines jaillit d'elle.
func _music_resume() -> void:
	super._music_resume()
	if Settings.reduce_effects:
		return
	for i in 24:
		var dir := Vector2.from_angle(TAU * i / 24.0 + 0.13)
		main.fx.mote(anchor + dir * radius * 0.7, dir * 620.0, 0.55, 4.0, Color(Art.ec("epine", "clair"), 0.95))


## Phase du dessin : la phase exaltée garde le dessin de la phase 3 (rose à cœur ouvert).
func art_phase() -> int:
	return mini(phase, 3)


func _projectiles_step(delta: float) -> void:
	_place_roots()
	_update_thorns(delta)
	_update_roots(delta)
	_update_embraces(delta)
	_update_waves(delta)
	_update_pricks(delta)
	if drum_flash >= 0.0:
		drum_flash += delta * 4.0
		if drum_flash > 1.0:
			drum_flash = -1.0


func _fight_step(delta: float) -> void:
	var cad := cadence()
	var scored: bool = score.ready()
	if scored:
		score.drums_step(_drum)
	if attack == "":
		var wanted := phase_for(hp / max_hp)
		if wanted > phase:
			_enter_phase(wanted)
			return
		if scored:
			var nxt: Dictionary = score.step(_swap)
			if nxt.has("wait"):
				gap = nxt["wait"]
			elif nxt.has("kind"):
				_begin(nxt["kind"], nxt["at"])
				cycle += 1
			return
		gap -= delta * cad
		if gap <= 0.0:
			var order: Array = _order()
			_begin(order[cycle % order.size()])
			cycle += 1
	elif stage == "annonce":
		if _strike_beat >= 0.0 and on_music_grid():
			timer = (_strike_beat - beats_now()) * beat_len()
		else:
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

func _begin(kind: String, strike_at := -1.0) -> void:
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
		"etreinte":
			_set_timer(EMBRACE["annonce"])
			exalted_attacks += 1
	_strike_beat = -1.0
	if strike_at >= 0.0 and on_music_grid():
		# Partition : la frappe tombe sur son temps. Les racines : la première jaillit sur lui, puis une
		# par temps (_place_roots), pendant que l'attaque suivante s'annonce déjà.
		_strike_beat = strike_at
		if kind == "racines":
			_roots_beat = strike_at - float(ANNOUNCE_BEATS["racines"])
			_roots_placed = 0
		_set_timer(maxf(0.0, (_strike_beat - beats_now()) * beat_len()))
	elif is_exalted_phase() and kind != "racines":
		# Phase exaltée sans partition : la frappe tombe sur un temps de la musique.
		_set_timer(loop_snap(timer))
	if kind == "etreinte":
		var at: Vector2 = main.player.position
		embraces.append({"pos": at, "gap": _gap_angle(at), "fuse": timer, "total": timer, "hold": EMBRACE["hold"], "tick": 0.0, "flash": -1.0, "sync": _strike_beat >= 0.0})


## La brèche de l'étreinte est tournée à l'opposé de la Mère-Ronce.
func _gap_angle(at: Vector2) -> float:
	var away := at - anchor
	return away.angle() if away.length() > 1.0 else PI * 0.5


## Racines de la partition : une par temps sous le joueur, qui jaillit deux temps plus tard (sur un
## temps) ; elles continuent pendant l'attaque suivante.
func _place_roots() -> void:
	if _roots_beat < 0.0:
		return
	if not on_music_grid():
		_roots_beat = -1.0
		return
	var lead := float(ANNOUNCE_BEATS["racines"])
	var n := int(PHASES[phase]["roots"])
	while _roots_placed < n and beats_now() >= _roots_beat + _roots_placed - 0.001:
		var fuse := (_roots_beat + _roots_placed + lead - beats_now()) * beat_len()
		roots.append({"pos": main.player.position, "fuse": maxf(0.05, fuse), "burst": -1.0, "total": maxf(0.05, fuse)})
		_roots_placed += 1
	if _roots_placed >= n:
		_roots_beat = -1.0


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


## Entre deux salves : sur la partition, une croche (les salves claquent en croches).
func _volley_between() -> float:
	return beat_len() * 0.5 if _strike_beat >= 0.0 and on_music_grid() else VOLLEY["between"]


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
			if _strike_beat >= 0.0:
				return
			root_timer -= delta
			if roots_left > 0 and root_timer <= 0.0:
				root_timer = ROOT["every"]
				roots_left -= 1
				roots.append({"pos": p.position, "fuse": ROOT["fuse"], "burst": -1.0})
		"etreinte":
			# L'anneau suit le joueur, puis se fige pour la fin de l'annonce.
			if timer > stage_time * EMBRACE["lock"] and not embraces.is_empty():
				var e: Dictionary = embraces[embraces.size() - 1]
				if e["fuse"] > 0.0:
					e["pos"] = _in_arena(p.position, EMBRACE["inner"])
					e["gap"] = _gap_angle(e["pos"])


func _strike() -> void:
	stage = "frappe"
	match attack:
		"volee":
			volleys_left = PHASES[phase]["volleys"]
			volley_timer = 0.0
			_set_timer(_volley_between() * volleys_left)
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
		"etreinte":
			# L'anneau jaillit de lui-même (son « fuse ») : l'attaque est finie.
			_end_attack()


func _strike_step(delta: float) -> void:
	match attack:
		"volee":
			volley_timer -= delta
			if volleys_left > 0 and volley_timer <= 0.0:
				volley_timer = _volley_between()
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
		_hurt(WHIP["damage"])


func _end_attack() -> void:
	attack = ""
	stage = ""
	whips = []
	gap = PHASES[phase]["gap"]
	_strike_beat = -1.0


## Blesse le joueur ; sur la partition, les coups des attaques blessent à SCORE_DAMAGE (« exact » :
## dégâts déjà réglés pour la batterie).
func _hurt(amount: float, exact := false) -> void:
	if not exact and score.phase == phase and on_music_grid():
		amount *= SCORE_DAMAGE
	main.player.take_hit(amount * damage_scale, self)


# --- Partition et batterie (avec son morceau) ---

## Elle suit le morceau même enracinée : la musique ne ralentit pas. Enracinée, elle saute un coup
## de la partition sur deux (boss_score.gd › step) au lieu d'annoncer plus lentement.
func on_music_grid() -> bool:
	return sync != null and sync.running and sync.stage == ""


## Partition : bourgeons déjà tous éclos → des racines à la place (elles ne retiennent pas l'attaque
## suivante).
func _swap(kind: String) -> String:
	if kind == "invocation" and minions.size() >= SUMMON["max_alive"]:
		return "racines"
	return kind


## Un coup de batterie dont l'annonce part (boss_score.gd) : « fuse » s avant le coup. Ondes, pouls
## et piqûres s'annoncent ; épines et aiguilles partent sur le coup même.
func _drum(kind: String, fuse: float, flood: bool) -> void:
	var pw: Dictionary = DRUMS_POWER[phase]
	match kind:
		"onde":
			_launch_wave(fuse, flood)
		"pouls":
			_launch_wave(fuse, false, true)
		"roulement":
			_roll(maxi(int(pw["roll"]), 4 if flood else 0))
		"aiguille":
			_spark(int(pw["spark"]) + (1 if flood else 0))
		"piqure":
			_prick(fuse, maxi(int(pw["prick"]), 1))


## Une onde de ronces qui partira dans « fuse » s, sur le coup de grosse caisse ; « small » : un pouls.
func _launch_wave(fuse: float, flood: bool, small := false) -> void:
	if waves.size() >= WAVE["max"]:
		return
	var to: Vector2 = main.player.position - anchor
	var base := to.angle() if to.length() > 1.0 else PI / 2.0
	if small:
		base = _roll_spin + float(_wave_count) * 0.9
	elif _wave_count % 2 == 1:
		# Une onde sur deux s'ouvre devant le joueur ; l'autre juste à côté : un pas de côté sur le temps.
		base += (WAVE["gap"] * 0.5 + WAVE["step"]) * (1.0 if _wave_count % 4 == 1 else -1.0)
	if flood:
		base += 0.35 * sin(float(_wave_count))
	var gaps: Array = []
	for i in WAVE["gaps"]:
		gaps.append(base + TAU * i / WAVE["gaps"])
	var reach := float(DRUMS_POWER[phase]["pulse"]) if small else INF
	waves.append({"r": radius * 0.9, "fuse": maxf(0.0, fuse), "total": maxf(0.05, fuse), "gaps": gaps, "hit": false, "reach": reach, "small": small})
	if not small:
		_wave_count += 1


## Une caisse claire : des épines en spirale, une par bras.
func _roll(arms: int) -> void:
	if arms <= 0:
		return
	_roll_spin += ROLL["spin"]
	var to: Vector2 = main.player.position - anchor
	var base := (to.angle() if to.length() > 1.0 else 0.0) + _roll_spin
	for i in arms:
		var dir := Vector2.from_angle(base + TAU * i / arms)
		thorns.append({"pos": anchor + dir * radius * 0.85, "vel": dir * ROLL["speed"], "r": ROLL["radius"], "dmg": ROLL["damage"], "size": 0.7})


## Un charleston : une aiguille par jet, le jet tourne d'un pas à chaque coup.
func _spark(n: int) -> void:
	_spark_angle += SPARK["step"]
	for i in n:
		var dir := Vector2.from_angle(_spark_angle + TAU * i / n)
		thorns.append({"pos": anchor + dir * radius * 0.8, "vel": dir * SPARK["speed"], "r": SPARK["radius"], "dmg": SPARK["damage"], "size": 0.45})


## Une caisse douce : de petites racines pointent autour du joueur, « fuse » s plus tard.
func _prick(fuse: float, n := 1) -> void:
	var p: Vector2 = main.player.position
	var a0 := _prick_rng.randf() * TAU
	for i in n:
		if pricks.size() >= PRICK["max"]:
			return
		var at := p + Vector2.from_angle(a0 + TAU * i / n) * _prick_rng.randf_range(PRICK["near"], PRICK["far"])
		pricks.append({"pos": _in_arena(at, PRICK["radius"]), "fuse": maxf(0.05, fuse), "total": maxf(0.05, fuse), "burst": -1.0})


func _update_pricks(delta: float) -> void:
	if pricks.is_empty():
		return
	var p = main.player
	var kept: Array = []
	for r in pricks:
		if r["burst"] < 0.0:
			r["fuse"] -= delta
			if r["fuse"] <= 0.0:
				r["burst"] = 0.0
				if p.position.distance_to(r["pos"]) < PRICK["radius"] + p.radius * 0.5 and p.invuln <= 0.0:
					_hurt(PRICK["damage"], true)
		else:
			r["burst"] += delta
		if r["burst"] < PRICK["burst"]:
			kept.append(r)
	pricks = kept


func _in_wave_gap(wv: Dictionary, pos: Vector2, margin: float) -> bool:
	var to := pos - anchor
	var d := maxf(to.length(), 1.0)
	for g in wv["gaps"]:
		if absf(angle_difference(float(g), to.angle())) < WAVE["gap"] * 0.5 - margin / d:
			return true
	return false


func _update_waves(delta: float) -> void:
	if waves.is_empty():
		return
	var p = main.player
	var limit: float = arena.radius + WAVE["width"]
	var kept: Array = []
	for wv in waves:
		if wv["fuse"] > 0.0:
			wv["fuse"] -= delta
			if wv["fuse"] <= 0.0:
				drum_flash = 0.0
				if not wv["small"]:
					main.fx.shake(1.5)
					if not Settings.reduce_effects:
						main.fx.ring(anchor, radius * 0.5, radius * 1.8, 0.25, Color(Art.bc("braise"), 0.8), 5.0)
			kept.append(wv)
			continue
		var small: bool = wv["small"]
		var r0: float = wv["r"]
		var r1: float = r0 + WAVE["speed"] * delta
		wv["r"] = r1
		var d: float = p.position.distance_to(anchor)
		var half: float = (PULSE["width"] if small else WAVE["width"]) * 0.5 + p.radius * 0.6
		if not wv["hit"] and d > r0 - half and d < r1 + half and r0 < float(wv["reach"]) and not _in_wave_gap(wv, p.position, p.radius * 0.5):
			if p.invuln <= 0.0:
				wv["hit"] = true
				_hurt(PULSE["damage"] if small else WAVE["damage"], true)
		if r1 < minf(limit, float(wv["reach"]) + 40.0):
			kept.append(wv)
	waves = kept


func _update_thorns(delta: float) -> void:
	if thorns.is_empty():
		return
	var p = main.player
	var limit: float = arena.radius + 30.0
	var kept: Array = []
	for th in thorns:
		th["pos"] += th["vel"] * delta
		var pos: Vector2 = th["pos"]
		if pos.distance_to(p.position) < float(th.get("r", VOLLEY["radius"])) + p.radius and p.invuln <= 0.0:
			_hurt(float(th.get("dmg", VOLLEY["damage"])), th.has("dmg"))
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
					_hurt(ROOT["damage"])
		else:
			r["burst"] += delta
		if r["burst"] < ROOT["burst"]:
			kept.append(r)
	roots = kept


func _enter_phase(n: int) -> void:
	phase = n
	score.reset()
	transition = PHASE_PAUSE
	cycle = 0
	gap = 0.3
	main.fx.ring(anchor, radius, 420.0, 0.7, Color(1.0, 0.45, 0.3, 0.9), 8.0)
	if n == 3:
		arena.start_shrink()


## Garde un point dans l'arène (à « margin » du bord).
func _in_arena(p: Vector2, margin: float) -> Vector2:
	var to: Vector2 = p - arena.center
	return arena.center + to.limit_length(maxf(40.0, arena.radius - margin))


## Vrai si pos est sur la bande de l'étreinte e (hors de la brèche), à « margin » près.
func _on_embrace(e: Dictionary, pos: Vector2, margin: float) -> bool:
	var to: Vector2 = pos - e["pos"]
	var d := to.length()
	if d < EMBRACE["inner"] - margin or d > EMBRACE["outer"] + margin:
		return false
	return absf(wrapf(to.angle() - e["gap"], -PI, PI)) > EMBRACE["gap"] * 0.5


func _update_embraces(delta: float) -> void:
	if embraces.is_empty():
		return
	var p = main.player
	var kept: Array = []
	for e in embraces:
		if e["flash"] >= 0.0:
			e["flash"] += delta
		if e["fuse"] > 0.0:
			e["fuse"] -= delta * (1.0 if e.get("sync", false) else cadence())
			if e["fuse"] <= 0.0:
				e["flash"] = 0.0
				e["tick"] = EMBRACE["tick"]
				main.fx.ring(e["pos"], EMBRACE["inner"], EMBRACE["outer"] + 10.0, 0.3, Color(Art.c("danger_eclair"), 0.8), 5.0)
				main.fx.shake(0.25)
				Sfx.play("racine", e["pos"])
				if _on_embrace(e, p.position, p.radius * 0.5) and p.invuln <= 0.0:
					_hurt(EMBRACE["damage"])
				# Phase exaltée : une racine jaillit au centre, il faut sortir par la brèche.
				if is_exalted_phase():
					roots.append({"pos": e["pos"], "fuse": ROOT["fuse"], "burst": -1.0})
		else:
			e["hold"] -= delta
			e["tick"] -= delta
			if e["tick"] <= 0.0:
				e["tick"] = EMBRACE["tick"]
				if _on_embrace(e, p.position, p.radius * 0.3) and p.invuln <= 0.0:
					_hurt(EMBRACE["wall_damage"])
		if e["fuse"] > 0.0 or e["hold"] > 0.0:
			kept.append(e)
	embraces = kept


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
		if (th["pos"] + v * u).distance_to(pos) < float(th.get("r", VOLLEY["radius"])) + margin:
			best = minf(best, u)
	for r in pricks:
		if r["burst"] < 0.0 and pos.distance_to(r["pos"]) < PRICK["radius"] + margin:
			best = minf(best, maxf(0.0, r["fuse"]))
	for wv in waves:
		var ahead: float = pos.distance_to(anchor) - float(wv["r"])
		if pos.distance_to(anchor) > float(wv["reach"]) + margin:
			continue
		if ahead > -WAVE["width"] - margin and not _in_wave_gap(wv, pos, margin):
			best = minf(best, maxf(0.0, wv["fuse"]) + maxf(0.0, ahead - margin) / WAVE["speed"])
	for e in embraces:
		if _on_embrace(e, pos, margin):
			best = minf(best, maxf(e["fuse"], 0.0))
		elif e["fuse"] > 0.0 and is_exalted_phase() and pos.distance_to(e["pos"]) < EMBRACE["inner"]:
			# Dans l'anneau en phase exaltée : la racine du centre suivra.
			best = minf(best, e["fuse"] + ROOT["fuse"])
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
	embraces = []
	waves = []
	pricks = []
	_roots_beat = -1.0


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
	_prick_rng.seed = 7311
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
	# Charge sur la musique (boss_base.gd) : elle tremble de plus en plus, se gonfle sur chaque impulsion.
	shift += charge_jitter()
	var swell := 0.05 * charge_energy() * charge_pulse() + 0.08 * charge_overflow()
	# Elle bat la mesure : un sursaut sur chaque grosse caisse de la partition.
	if drum_flash >= 0.0:
		swell += 0.05 * (1.0 - drum_flash)
	s *= 1.0 + swell
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
	var anim := "mort" if dead else "p%d" % art_phase()
	var u := dk if dead else fposmod(t / Mere.LOOP, 1.0)
	_draw_part(atlas, "sol", "p%d" % art_phase(), 0.0, xf, {"groupe": "sol", "phase": art_phase()})
	# Lianes au repos derrière elle (une de plus à chaque phase), qui ondulent ; elles rentrent à la mort.
	if dk < 0.5:
		_rest_vines(ux, 1.0 - dk * 2.0)
	var o := {"phase": art_phase(), "t": fposmod(t, Mere.LOOP)}
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
	var rage: float = [0.0, 0.5, 1.0][art_phase() - 1]
	var n := 2 + art_phase()
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
	# Phase exaltée : couronne de flammes d'encre qui bat sur les temps de sa musique.
	var glow := exalt_glow()
	if glow > 0.0:
		Exalte.aura(c, mid, radius, 1.0, (glow - 0.55) / 0.45, t)
	# Charge sur la musique : la braise gonfle au cœur de la rose, battue par les impulsions.
	if charge >= 0.0 and not dead:
		var e := charge_energy()
		var pulse := charge_pulse()
		Ink.halo(c, heart, radius * (0.35 + 0.9 * e + 0.25 * pulse + 0.6 * charge_overflow()), Art.bc("braise"), 0.6 + 1.6 * e + 0.8 * pulse)
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
	for e in embraces:
		var forme := _embrace_shape(e)
		if e["fuse"] > 0.0:
			Art.telegraph(c, forme, 1.0 - clampf(e["fuse"] / maxf(e["total"], 0.01), 0.0, 1.0), -1.0, t)
		elif e["flash"] < EMBRACE["flash"]:
			Art.telegraph(c, forme, 1.0, e["flash"] / EMBRACE["flash"], t)
		else:
			# Le roncier tient : son bord reste rouge tant qu'il pique.
			var fade := clampf(e["hold"] / 0.4, 0.0, 1.0)
			c.draw_arc(e["pos"], EMBRACE["outer"], forme["debut"], forme["fin"], 40, Color(Art.c("danger"), 0.5 * fade), Art.TRAIT_FIN, true)
			c.draw_arc(e["pos"], EMBRACE["inner"], forme["debut"], forme["fin"], 30, Color(Art.c("danger"), 0.5 * fade), Art.TRAIT_FIN, true)
	_draw_waves(c)
	for r in pricks:
		var pf := {"type": "cercle", "centre": r["pos"], "rayon": PRICK["radius"]}
		if r["burst"] < 0.0:
			Art.telegraph(c, pf, 1.0 - clampf(r["fuse"] / maxf(float(r["total"]), 0.01), 0.0, 1.0), -1.0, t)
		else:
			Art.telegraph(c, pf, 1.0, clampf(r["burst"] / PRICK["burst"], 0.0, 1.0), t)
	for r in roots:
		var forme := {"type": "cercle", "centre": r["pos"], "rayon": ROOT["radius"]}
		if r["burst"] < 0.0:
			var k := 1.0 - clampf(r["fuse"] / float(r.get("total", ROOT["fuse"])), 0.0, 1.0)
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


## Ondes de ronces (grosses caisses) : pendant l'annonce, la bande se ramasse autour d'elle en
## rouge ; partie, une couronne de ronces (tige sombre, épines d'os) qui file vers le mur, ouverte de
## ses brèches. Les pouls, plus fins, s'éteignent vite.
func _draw_waves(c: CanvasItem) -> void:
	if waves.is_empty():
		return
	var danger := Art.c("danger")
	var cane := Art.bc("ronce", "detail").lerp(Art.bc("ronce", "ombre"), 0.4)
	var bone := Art.bc("os")
	var half: float = WAVE["gap"] * 0.5
	for wv in waves:
		var gaps: Array = wv["gaps"].duplicate()
		gaps.sort()
		var fuse: float = wv["fuse"]
		var k := 1.0 - clampf(fuse / float(wv["total"]), 0.0, 1.0) if fuse > 0.0 else 1.0
		var small: bool = wv["small"]
		var r: float = wv["r"] if fuse <= 0.0 else radius * (0.9 + 1.4 * (1.0 - k))
		var reach: float = minf(arena.radius, float(wv["reach"]))
		var full_w: float = PULSE["width"] if small else WAVE["width"]
		var fade := 1.0
		if fuse <= 0.0:
			fade = clampf((reach + full_w - r) / (40.0 if small else 80.0), 0.0, 1.0)
		for i in gaps.size():
			var a0: float = float(gaps[i]) + half
			var a1: float = float(gaps[(i + 1) % gaps.size()]) - half
			if a1 <= a0:
				a1 += TAU
			var segs := maxi(4, int((a1 - a0) * (6.0 if small else 12.0)))
			if fuse > 0.0:
				c.draw_arc(anchor, r, a0, a1, segs, Color(danger, 0.25 + 0.55 * k), Art.TRAIT * (1.0 + k), true)
				continue
			c.draw_arc(anchor, r, a0, a1, segs, Color(Ink.encre(), 0.85 * fade), full_w * 0.7, true)
			c.draw_arc(anchor, r, a0, a1, segs, Color(cane, fade), full_w * 0.45, true)
			c.draw_arc(anchor, r + full_w * 0.45, a0, a1, segs, Color(danger, 0.8 * fade), Art.TRAIT_FIN, true)
			if small:
				continue
			# Épines d'os dressées le long de la couronne.
			var n := int((a1 - a0) * r / 26.0)
			for j in n:
				var a := lerpf(a0, a1, (j + 0.5) / float(n))
				var dir := Vector2.from_angle(a)
				var foot := anchor + dir * (r - full_w * 0.2)
				var tip := foot + dir * full_w * 0.9 + Vector2(0, -full_w * 0.5)
				var side := dir.orthogonal() * 3.5
				c.draw_colored_polygon(PackedVector2Array([foot + side, tip, foot - side]), Color(bone, fade))


## Forme d'annonce d'une étreinte : l'anneau, sans sa brèche.
func _embrace_shape(e: Dictionary) -> Dictionary:
	var half: float = EMBRACE["gap"] * 0.5
	return {"type": "anneau", "centre": e["pos"], "interieur": EMBRACE["inner"], "rayon": EMBRACE["outer"], "debut": e["gap"] + half, "fin": e["gap"] + TAU - half}


## Le roncier d'une étreinte jaillie : des tiges épineuses dressées tout le long de l'anneau, qui
## sortent d'un coup et rentrent à la fin.
func _draw_embrace(c: CanvasItem, e: Dictionary) -> void:
	var rise := clampf(e["flash"] / 0.12, 0.0, 1.0) * clampf(e["hold"] / 0.35, 0.0, 1.0)
	if rise <= 0.0:
		return
	var half: float = EMBRACE["gap"] * 0.5
	var body := Art.bc("ronce", "detail").lerp(Art.bc("ronce", "ombre"), 0.4)
	var bone := Art.bc("os")
	var n := 16
	for i in n:
		var a: float = e["gap"] + half + (TAU - 2.0 * half) * (i + 0.5) / n
		var band: float = lerpf(EMBRACE["inner"], EMBRACE["outer"], 0.3 + 0.4 * float(i % 2))
		var foot: Vector2 = e["pos"] + Vector2.from_angle(a) * band * Vector2(1.0, 0.85)
		var h := (34.0 + 16.0 * float((i * 7) % 3)) * rise
		var tip := foot + Vector2(cos(a) * 8.0, -h)
		var w := 7.0 + 2.0 * float(i % 2)
		var spike := PackedVector2Array([foot + Vector2(-w, 0), tip, foot + Vector2(w, 0)])
		Art.outline(c, spike, Art.bc("encre"), Art.TRAIT)
		c.draw_colored_polygon(PackedVector2Array([foot + Vector2(-w, 0), tip, foot]), body.lightened(0.2))
		c.draw_colored_polygon(PackedVector2Array([foot, tip, foot + Vector2(w, 0)]), body.darkened(0.3))
		var d := (tip - foot).normalized()
		c.draw_colored_polygon(PackedVector2Array([tip - d * 9.0 + d.orthogonal() * 2.5, tip + d * 3.0, tip - d * 9.0 - d.orthogonal() * 2.5]), bone)


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
		# Épines de la batterie (spirales, aiguilles) : les mêmes, plus petites.
		var z: float = th.get("size", 1.0)
		c.draw_line(pos - dir * 30.0 * z, pos - dir * 6.0 * z, Color(Art.c("danger"), 0.35), 6.0 * z, true)
		var tip := pos + dir * 15.0 * z
		var back := pos - dir * 9.0 * z
		c.draw_colored_polygon(PackedVector2Array([back + n * 5.5 * z, tip, back]), Art.ec("epine", "clair"))
		c.draw_colored_polygon(PackedVector2Array([back, tip, back - n * 5.5 * z]), Art.ec("epine").darkened(0.2))
		Art.outline(c, PackedVector2Array([back + n * 5.5 * z, tip, back - n * 5.5 * z]), Art.ec("epine", "sombre"), 1.2)
		c.draw_circle(back, 2.5 * z, Art.ec("cendre"))
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
	for e in embraces:
		if e["fuse"] <= 0.0:
			_draw_embrace(c, e)
	for r in pricks:
		if r["burst"] >= 0.0:
			var kp := clampf(r["burst"] / PRICK["burst"], 0.0, 1.0)
			var risep := maxf(0.08, sin(kp * PI))
			for i in 3:
				var a: float = TAU * i / 3.0 + float(r["pos"].x) * 0.02
				var foot: Vector2 = r["pos"] + Vector2.from_angle(a) * PRICK["radius"] * 0.35 * Vector2(1.0, 0.6)
				var tip := foot + Vector2(cos(a) * 6.0, -34.0 * risep)
				var spike := PackedVector2Array([foot + Vector2(-5, 0), tip, foot + Vector2(5, 0)])
				Art.outline(c, spike, Art.bc("encre"), Art.TRAIT_FIN)
				c.draw_colored_polygon(spike, Art.bc("ronce", "detail"))
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
