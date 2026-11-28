## L'Amanite-Mère, boss de la région de Spore : une amanite géante plantée au centre de son arène,
## au milieu du marais. Nommée dans data/regions/spore.json › boss.
##
## Trois phases (100–66 %, 66–33 %, 33–0 % de sa vie). Chaque coup est annoncé avant de frapper
## (Art.telegraph, charte § 6) et le chapeau se gonfle ou se soulève pendant l'annonce :
##   - nuages   : des cercles se posent sous le joueur, puis crèvent en nuages de spores qui restent
##                quelques secondes et blessent qui s'y tient (sortir des nuages, ne pas s'y battre) ;
##   - salve    : un éventail de spores tiré vers le joueur (cône au sol), deux ou trois fois ;
##   - onde     : le chapeau s'abat, une onde de choc frappe autour d'elle (cercle au sol) : reculer ;
##   - spirale  (dès la phase 2) : deux puis trois bras de spores tournent depuis son pied (les bras
##                de départ sont marqués au sol) : tourner avec eux ;
##   - invocation (dès la phase 2) : des boutons éclosent en Scissipores et Sporules (pas en rouge :
##                ce n'est pas un coup) ;
##   - mycélium (phase 3) : des filaments fendent le sol en lignes vers le joueur, puis jaillissent ;
##                l'arène se resserre (boss_arena.gd).
## Cycle exalté (NG+, à partir du cycle 2, boss_base.gd › Cycle exalté) :
##   - anneaux (phase exaltée, et phase 3 quand cycles.json le demande) : des ronds de sorcière
##                partent de son pied l'un après l'autre, un par temps de sa musique, chacun ouvert d'une
##                brèche (la première face au joueur, les suivantes décalées) : passer par les brèches ;
##                l'annonce montre la première vague et sa brèche ;
##   - phase exaltée (sous 22 % de sa vie) : le chapeau s'embrase d'encre, chaque coup tombe sur un
##                temps, cinq anneaux par vague, plus d'invocation.
## Sa mort : le chapeau s'affaisse et se vide de ses spores ; à sa place pousse un cercle de
## champignons clairs dans la mousse (draw_victory).
##
##
## Au rythme de son morceau (amanitemere.wav d'Antoine, 165 BPM, la majeur / fa# mineur ;
## assets/music/hand/spore.json) : l'intro monte sous la musique du monde à l'approche de son enceinte,
## elle charge pendant la mesure du fill et frappe sur le drop. Puis elle joue une partition (SCORE,
## boss_score.gd) : chaque phase suit sa boucle en phrases de quatre mesures, chaque attaque frappe sur
## son temps (une par mesure environ, sur la claque ou la grosse caisse) ; par-dessus, la batterie
## elle-même attaque (DRUMS_POWER) : ses grosses caisses font courir des ronds de sorcière à brèches
## (ou un pouls court), ses claques des bouffées de spores en spirale, ses charlestons des spores en
## jet tournant et ses caisses douces de petites vesses autour du joueur. Chaque phase en joue plus,
## jusqu'à la phase exaltée. Sans morceau, l'ordre de PHASES.
##
## Le socle (vie, phases, états, mort, interface d'ennemi) est dans boss_base.gd.
extends BossBase

const BossScore = preload("res://scripts/boss_score.gd")
const Ink = preload("res://scripts/creature_art/ink.gd")

const PHASE_LIMITS := [0.66, 0.33]
## Par phase : pause entre deux attaques, ordre des attaques et ampleur.
const PHASES := {
	1: {"gap": 1.3, "order": ["nuages", "salve", "onde", "nuages", "salve"], "clouds": 3, "volleys": 2, "spores": 7, "arms": 0},
	2: {"gap": 1.1, "order": ["salve", "invocation", "nuages", "spirale", "onde"], "clouds": 4, "volleys": 2, "spores": 9, "arms": 2, "minions": 3},
	3: {"gap": 0.9, "order": ["mycelium", "nuages", "spirale", "onde", "invocation", "salve"], "clouds": 5, "volleys": 3, "spores": 9, "arms": 3, "minions": 4, "lines": 3, "rings": 3},
	# Phase exaltée (cycle 2 et plus seulement).
	4: {"gap": 0.8, "order": ["anneaux", "nuages", "salve", "anneaux", "mycelium", "spirale"], "clouds": 4, "volleys": 3, "spores": 11, "arms": 3, "minions": 0, "lines": 4, "rings": 5},
}
## Attaque nouvelle du cycle exalté (boss_base.gd › Cycle exalté).
const EXALTED_ATTACK := "anneaux"
## Ronds de sorcière : annonce, un anneau par temps (« every » temps de LOOP_BEAT), vitesse, largeur de
## la bande, brèche (radians), décalage de la brèche d'un anneau au suivant, dégâts.
const FAIRY := {"annonce": 1.0, "every": 1.0, "speed": 230.0, "width": 34.0, "gap": 1.05, "turn": 0.75, "damage": 16.0}
const CLOUD := {"annonce": 1.0, "radius": 70.0, "spread": 170.0, "life": 3.2, "dps": 16.0, "tick": 0.5}
const VOLLEY := {"annonce": 0.85, "between": 0.4, "damage": 12.0, "speed": 300.0, "radius": 9.0, "spread": 0.17}
const WAVE := {"annonce": 1.05, "radius": 230.0, "radius_p3": 290.0, "damage": 22.0, "flash": 0.3}
const SPIRAL := {"annonce": 0.9, "duration": 2.2, "rate": 9.0, "turn": 1.4, "damage": 10.0, "speed": 240.0}
const SUMMON := {"annonce": 1.0, "max_alive": 6, "kinds": ["scissipore", "sporule", "sporule", "scissipore"]}
const MYCELIUM := {"annonce": 1.0, "length": 430.0, "width": 44.0, "damage": 20.0, "flash": 0.3, "fan": 0.42}
const PHASE_PAUSE := 1.4

# --- Partition sur son morceau (boss_score.gd ; boss_sync.gd : horloge audio, ou temps du jeu sans son) ---
# Une phrase = quatre mesures (16 temps), une attaque par mesure environ, sur la claque (temps 1 de la
# mesure) ou la grosse caisse ; « coups » : [temps de la phrase, attaque] ; l'annonce part
# ANNOUNCE_BEATS temps avant. « ondes » : mesures de la phrase où les grosses caisses lancent de vrais
# ronds (sinon ceux de DRUMS_POWER) ; « deluge » : toute la batterie, au plus fort.
# Une attaque qui dure (salve : une croche par volée ; spirale : SPIRAL_BEATS ; anneaux : un par temps)
# laisse plus de deux temps avant le coup suivant (sinon il serait sauté : tests) ; les anneaux de la
# phase exaltée (cinq, un par temps) en laissent sept.
const SCORE := {
	1: {"loop": "boucle_1", "phrases": [
		{"coups": [[1, "nuages"], [5, "salve"], [9, "onde"], [13, "salve"]]},
		{"coups": [[0, "onde"], [5, "nuages"], [9, "salve"], [13, "nuages"]]},
	]},
	2: {"loop": "boucle_2", "phrases": [
		{"coups": [[1, "salve"], [5, "spirale"], [9, "nuages"], [13, "onde"]]},
		{"coups": [[2, "invocation"], [5, "salve"], [9, "nuages"], [13, "spirale"]]},
		{"coups": [[1, "onde"], [5, "salve"], [9, "spirale"], [13, "nuages"]]},
		{"coups": [[1, "salve"], [5, "nuages"], [9, "onde"], [13, "salve"]], "ondes": [0, 2]},
	]},
	# A puis B (32 mesures) : la seconde moitié, plus lourde, lance plus de ronds.
	3: {"loop": "boucle_3", "phrases": [
		{"coups": [[1, "mycelium"], [5, "salve"], [9, "nuages"], [13, "onde"]]},
		{"coups": [[1, "spirale"], [5, "mycelium"], [9, "salve"], [13, "onde"]]},
		{"coups": [[2, "invocation"], [5, "nuages"], [9, "mycelium"], [13, "salve"]]},
		{"coups": [[1, "onde"], [5, "spirale"], [9, "nuages"], [13, "mycelium"]]},
		{"coups": [[1, "mycelium"], [5, "salve"], [9, "nuages"], [13, "onde"]], "ondes": [0, 2]},
		{"coups": [[1, "spirale"], [5, "mycelium"], [9, "salve"], [13, "onde"]], "ondes": [0, 2]},
		{"coups": [[2, "invocation"], [5, "nuages"], [9, "mycelium"], [13, "salve"]], "ondes": [0, 1, 2]},
		{"coups": [[1, "onde"], [5, "spirale"], [9, "nuages"], [13, "mycelium"]], "ondes": [0, 1, 2, 3]},
	]},
	4: {"loop": "boucle_4", "phrases": [
		{"coups": [[1, "anneaux"], [8, "salve"], [12, "mycelium"], [15, "nuages"]]},
		{"coups": [[1, "spirale"], [5, "onde"], [8, "anneaux"], [15, "mycelium"]]},
		{"coups": [[1, "nuages"], [4, "anneaux"], [11, "salve"], [15, "onde"]]},
		{"coups": [[2, "anneaux"], [9, "spirale"], [13, "onde"], [15, "nuages"]], "deluge": true},
	]},
}
## Ce que la batterie déclenche, phase par phase (boss_score.gd) : grosses caisses → ronds de sorcière
## (« ondes » : mesures où ils courent jusqu'au mur ; ailleurs un pouls qui s'éteint à « pulse » px),
## claques → bouffées de spores (« roll » bras, sur les doubles croches multiples de « roll_grid »),
## charlestons → spores en jet tournant (« spark »), caisses douces → petites vesses (« prick »).
const DRUMS_POWER := {
	1: {"ondes": [], "pulse": 200.0, "roll": 1, "roll_grid": 4, "spark": 1, "spark_grid": 2, "prick": 0},
	2: {"ondes": [0], "pulse": 240.0, "roll": 2, "roll_grid": 4, "spark": 1, "spark_grid": 2, "prick": 1},
	3: {"ondes": [0], "pulse": 280.0, "roll": 2, "roll_grid": 2, "spark": 2, "spark_grid": 2, "prick": 1},
	4: {"ondes": [0, 1, 2, 3], "pulse": 320.0, "roll": 3, "roll_grid": 1, "spark": 2, "spark_grid": 1, "prick": 2},
}
## Annonce (en temps) de chaque attaque de la partition ; annonce des coups de batterie qui en ont une.
const ANNOUNCE_BEATS := {"nuages": 3, "salve": 2, "onde": 3, "spirale": 3, "invocation": 3, "mycelium": 3, "anneaux": 3}
const DRUM_LEAD := {"onde": 2.0, "pouls": 1.0, "piqure": 2.0}
## Spirale de la partition : elle tourne deux temps.
const SPIRAL_BEATS := 2.0
## Sur la partition, elle frappe plus souvent qu'au gré des pauses : chaque coup blesse moins.
const SCORE_DAMAGE := 0.6
## Coups de batterie quand le morceau n'en donne pas (une phrase de quatre mesures, doubles croches).
const DRUMS := {"kick": [[0, 6], [6], [0, 6], [0]], "kick_doux": [[8], [11], [8], []], "caisse": [[4, 12], [4, 12], [4, 12], [4, 9, 11, 13, 15]],
	"charleston": [[4, 6, 8, 10, 12, 14], [4, 8, 10, 12, 14], [4, 6, 8, 10, 12, 14], [4, 6, 8, 9, 10, 11, 12, 13, 14, 15]], "caisse_douce": [[7, 15], [15], [15], [6, 8, 10]]}
## Rond de sorcière de la batterie (grosses caisses) : vitesse, épaisseur, brèches (nombre, ouverture
## en radians, pas de côté un rond sur deux), dégâts, au plus.
const DRUM_WAVE := {"speed": 400.0, "width": 22.0, "gaps": 3, "gap": 1.0, "step": 0.3, "damage": 6.0, "max": 8}
## Pouls (autres grosses caisses) : épaisseur, dégâts.
const PULSE := {"width": 12.0, "damage": 2.0}
## Bouffées de spores (claques) : pas de la spirale (radians par coup), vitesse, rayon, dégâts.
const PUFF := {"spin": 0.55, "speed": 260.0, "radius": 6.0, "damage": 4.0}
## Spores en jet (charlestons) : pas du jet, vitesse, rayon, dégâts.
const SPARK := {"step": 0.42, "speed": 230.0, "radius": 4.0, "damage": 1.5}
## Petites vesses (caisses douces) : rayon, dégâts, distance au joueur, au plus, durée de l'éclat.
const PRICK := {"radius": 30.0, "damage": 3.0, "near": 50.0, "far": 110.0, "max": 12, "burst": 0.3}

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
var spiral_clock := 0.0
var spiral_angle := 0.0
## Spores en vol : {"pos", "vel"}.
var spores: Array = []
## Nuages : {"pos", "fuse" (avant d'éclater, > 0), "life" (après)}.
var clouds: Array = []
var _cloud_tick := 0.0
## Boutons de l'invocation en cours (positions).
var buds: Array = []
## Lignes du mycélium (directions) et éclair de leur frappe.
var lines: Array = []
var strike_flash := -1.0
## Ronds de sorcière : brèches prévues de la vague en cours, et anneaux qui s'étendent
## {"r", "gap", "hit", "born"}.
var ring_gaps: Array = []
var rings: Array = []
var ring_timer := 0.0

## Partition (boss_score.gd) ; temps du morceau où tombe la frappe annoncée (-1 : sans grille).
var score
var _strike_beat := -1.0
var _swap_count := 0
## Ronds de sorcière de la batterie : {"r", "fuse", "total", "gaps", "hit", "reach", "small", "born"}.
var waves: Array = []
var _wave_count := 0
var _roll_spin := 0.0
var _spark_angle := 0.0
## Petites vesses des caisses douces : {"pos", "fuse", "total", "burst"}.
var pricks: Array = []
var _prick_rng := RandomNumberGenerator.new()
## Sursaut du chapeau sur une grosse caisse (0 → 1), -1 : aucun.
var drum_flash := -1.0


func _setup() -> void:
	body_radius = 72.0
	intro_time = 1.4
	death_time = 1.9
	base_hp = 620.0
	hp_per_level = 205.0
	damage_per_level = 0.03
	contact_damage = 16.0
	phase_limits = PHASE_LIMITS
	color = Color("3a2a44")
	score = BossScore.new(self, SCORE, DRUMS_POWER, ANNOUNCE_BEATS, DRUM_LEAD, DRUMS)
	_prick_rng.seed = 5113


## Ce qu'elle charge pendant le fill d'avant le drop : le poison de ses spores.
func _charge_color() -> Color:
	return Art.ec("poison", "clair")


## Le drop : le combat part d'un coup, le chapeau crève en couronne de spores.
func _music_resume() -> void:
	super._music_resume()
	if Settings.reduce_effects:
		return
	for i in 24:
		var dir := Vector2.from_angle(TAU * i / 24.0 + 0.13)
		main.fx.mote(anchor + dir * radius * 0.7, dir * 560.0, 0.6, 4.5, Color(Art.ec("poison", "clair"), 0.95))


## Elle suit le morceau même enracinée : la musique ne ralentit pas (boss_score.gd saute un coup sur deux).
func on_music_grid() -> bool:
	return sync != null and sync.running and sync.stage == ""


func _projectiles_step(delta: float) -> void:
	_update_spores(delta)
	_update_clouds(delta)
	_update_rings(delta)
	_update_waves(delta)
	_update_pricks(delta)
	if drum_flash >= 0.0:
		drum_flash += delta * 4.0
		if drum_flash > 1.0:
			drum_flash = -1.0
	if strike_flash >= 0.0:
		strike_flash += delta
		if strike_flash > WAVE["flash"]:
			strike_flash = -1.0
			if attack == "" or attack == "mycelium":
				lines = []


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
			var order: Array = exalted_order(PHASES[phase]["order"], EXALTED_ATTACK)
			_begin(order[cycle % order.size()])
			cycle += 1
	elif stage == "annonce":
		if _strike_beat >= 0.0 and on_music_grid():
			timer = (_strike_beat - beats_now()) * beat_len()
		else:
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

## Partition : une attaque impossible devient une autre (bourgeons tous éclos → nuages) ; au cycle 3
## (attaque nouvelle dès la phase 3), une onde sur deux devient des ronds de sorcière.
func _swap(kind: String) -> String:
	if kind == "invocation" and minions.size() >= SUMMON["max_alive"]:
		return "nuages"
	if kind == "onde" and phase == 3 and EXALTED_ATTACK in exalted_order(PHASES[3]["order"], EXALTED_ATTACK):
		_swap_count += 1
		if _swap_count % 2 == 0:
			return EXALTED_ATTACK
	return kind


func _begin(kind: String, strike_at := -1.0) -> void:
	var cfg: Dictionary = PHASES[phase]
	if kind == "invocation" and minions.size() >= SUMMON["max_alive"]:
		kind = "salve"
	attack = kind
	stage = "annonce"
	Sfx.play("annonce", anchor)
	var to: Vector2 = main.player.position - anchor
	aim = to.normalized() if to.length() > 1.0 else Vector2.DOWN
	match kind:
		"nuages":
			_set_timer(CLOUD["annonce"])
			var p: Vector2 = main.player.position
			for i in int(cfg["clouds"]):
				var at := p
				if i > 0:
					at = p + Vector2.from_angle(randf() * TAU) * randf_range(0.45, 1.0) * CLOUD["spread"]
				at = _in_arena(at, CLOUD["radius"] * 0.5)
				clouds.append({"pos": at, "fuse": CLOUD["annonce"], "total": CLOUD["annonce"], "life": CLOUD["life"] + (0.8 if phase >= 3 else 0.0)})
		"salve":
			_set_timer(VOLLEY["annonce"])
		"onde":
			_set_timer(WAVE["annonce"])
		"spirale":
			_set_timer(SPIRAL["annonce"])
			spiral_angle = aim.angle() + PI / float(cfg["arms"])
		"invocation":
			_set_timer(SUMMON["annonce"])
			buds = []
			var n: int = cfg["minions"]
			for i in n:
				var a := aim.angle() + PI + (i - (n - 1) / 2.0) * 0.6
				buds.append(anchor + Vector2.from_angle(a) * 160.0)
		"mycelium":
			_set_timer(MYCELIUM["annonce"])
			lines = []
			var n: int = cfg.get("lines", 3)
			for i in n:
				lines.append(Vector2.from_angle(aim.angle() + (i - (n - 1) / 2.0) * MYCELIUM["fan"]))
		"anneaux":
			_set_timer(FAIRY["annonce"])
			exalted_attacks += 1
			# La première brèche fait face au joueur, les suivantes tournent d'un côté puis de l'autre.
			ring_gaps = []
			var side := 1.0 if cycle % 2 == 0 else -1.0
			var a := aim.angle()
			for i in int(cfg.get("rings", 3)):
				ring_gaps.append(a)
				a += side * FAIRY["turn"] * (1.0 if i % 2 == 0 else 0.6)
	_strike_beat = -1.0
	if strike_at >= 0.0 and on_music_grid():
		# Partition : la frappe tombe sur son temps ; les nuages crèvent dessus.
		_strike_beat = strike_at
		_set_timer(maxf(0.0, (_strike_beat - beats_now()) * beat_len()))
		if kind == "nuages":
			for cl in clouds:
				if cl["fuse"] > 0.0 and not cl.has("sync"):
					cl["fuse"] = timer
					cl["total"] = maxf(timer, 0.05)
					cl["sync"] = true
	elif is_exalted_phase() and kind != "nuages":
		# Phase exaltée sans partition : la frappe tombe sur un temps de la musique.
		_set_timer(loop_snap(timer))


func _set_timer(v: float) -> void:
	timer = v
	stage_time = v


## Garde un point dans l'arène (à « margin » du bord).
func _in_arena(p: Vector2, margin: float) -> Vector2:
	var to: Vector2 = p - arena.center
	var lim: float = maxf(40.0, arena.radius - margin)
	return arena.center + to.limit_length(lim)


## Pendant l'annonce, la salve suit le joueur puis se verrouille.
func _announce_step() -> void:
	if attack == "salve" and timer > stage_time * 0.4:
		var to: Vector2 = main.player.position - anchor
		if to.length() > 1.0:
			aim = to.normalized()


func _strike() -> void:
	stage = "frappe"
	match attack:
		"nuages":
			# Les nuages éclatent d'eux-mêmes (leur « fuse ») : l'attaque est finie.
			_end_attack()
		"salve":
			volleys_left = PHASES[phase]["volleys"]
			volley_timer = 0.0
			_set_timer(_volley_between() * volleys_left)
		"onde":
			var r := _wave_radius()
			var p = main.player
			if p.position.distance_to(anchor) < r + p.radius * 0.5:
				_hurt(WAVE["damage"])
			strike_flash = 0.0
			main.fx.ring(anchor, radius, r, 0.4, Color(Art.ec("poison", "clair"), 0.9), 6.0)
			main.fx.shake(6.0)
			_end_attack()
		"spirale":
			spiral_clock = 0.0
			_set_timer(SPIRAL_BEATS * beat_len() if _strike_beat >= 0.0 else SPIRAL["duration"])
		"anneaux":
			# Un anneau tout de suite, puis un par temps de la musique.
			ring_timer = 0.0
			_set_timer(_ring_every() * maxf(0.0, ring_gaps.size() - 1.0) + 0.05)
		"invocation":
			var kinds: Array = SUMMON["kinds"]
			for i in buds.size():
				var b: Vector2 = buds[i]
				minions.append(main.spawn_enemy_kind(kinds[i % kinds.size()], b, main.threat(b)))
				main.fx.ring(b, 6.0, 46.0, 0.35, Color(Art.ec("poison", "clair"), 0.8), 3.0)
			buds = []
			_end_attack()
		"mycelium":
			var p = main.player
			for d in lines:
				if _on_line(p.position, d, p.radius * 0.5):
					_hurt(MYCELIUM["damage"])
					break
			strike_flash = 0.0
			main.fx.shake(4.0)
			_end_attack()


func _strike_step(delta: float) -> void:
	match attack:
		"anneaux":
			ring_timer -= delta
			if not ring_gaps.is_empty() and ring_timer <= 0.0:
				ring_timer += _ring_every()
				rings.append({"r": radius * 0.9, "gap": ring_gaps.pop_front(), "hit": false, "born": t})
				Sfx.play("nuage", anchor)
		"salve":
			volley_timer -= delta
			if volleys_left > 0 and volley_timer <= 0.0:
				volley_timer = _volley_between()
				for dir in volley_dirs(volleys_left % 2 == 0):
					spores.append({"pos": anchor + dir * radius * 0.8, "vel": dir * VOLLEY["speed"]})
				volleys_left -= 1
		"spirale":
			spiral_clock -= delta
			var arms: int = PHASES[phase]["arms"]
			spiral_angle += SPIRAL["turn"] * delta
			while spiral_clock <= 0.0:
				spiral_clock += 1.0 / SPIRAL["rate"]
				for i in arms:
					var d := Vector2.from_angle(spiral_angle + TAU * i / arms)
					spores.append({"pos": anchor + d * radius * 0.7, "vel": d * SPIRAL["speed"], "small": true})


## Entre deux volées : sur la partition, une croche.
func _volley_between() -> float:
	return beat_len() * 0.5 if _strike_beat >= 0.0 and on_music_grid() else VOLLEY["between"]


## Entre deux ronds de sorcière : un temps de son morceau, ou de la couche du code.
func _ring_every() -> float:
	return (beat_len() if sync != null and sync.running else LOOP_BEAT) * FAIRY["every"]


## Blesse le joueur ; sur la partition, les coups des attaques blessent à SCORE_DAMAGE (« exact » :
## dégâts déjà réglés pour la batterie).
func _hurt(amount: float, exact := false) -> void:
	if not exact and score.phase == phase and on_music_grid():
		amount *= SCORE_DAMAGE
	main.player.take_hit(amount * damage_scale, self)


## Directions des spores d'une salve (les salves paires sont décalées d'un demi-écart).
func volley_dirs(offset := false) -> Array:
	var n: int = PHASES[phase]["spores"]
	var out: Array = []
	var shift := 0.5 if offset else 0.0
	for i in n:
		out.append(Vector2.from_angle(aim.angle() + (i - (n - 1) / 2.0 + shift) * VOLLEY["spread"]))
	return out


func _wave_radius() -> float:
	return WAVE["radius_p3"] if phase >= 3 else WAVE["radius"]


func _on_line(pos: Vector2, d: Vector2, margin: float) -> bool:
	var to := pos - anchor
	var along := to.dot(d)
	return along > 0.0 and along < MYCELIUM["length"] and absf(to.dot(d.orthogonal())) < MYCELIUM["width"] * 0.5 + margin


func _end_attack() -> void:
	attack = ""
	stage = ""
	gap = PHASES[phase]["gap"]
	_strike_beat = -1.0


# --- Batterie (avec son morceau, boss_score.gd) ---

## Un coup de batterie dont l'annonce part : « fuse » s avant le coup.
func _drum(kind: String, fuse: float, flood: bool) -> void:
	var pw: Dictionary = DRUMS_POWER[phase]
	match kind:
		"onde":
			_launch_wave(fuse, flood)
		"pouls":
			_launch_wave(fuse, false, true)
		"roulement":
			_puff(maxi(int(pw["roll"]), 4 if flood else 0))
		"aiguille":
			_spark(int(pw["spark"]) + (1 if flood else 0))
		"piqure":
			_prick(fuse, maxi(int(pw["prick"]), 1))


## Un rond de sorcière qui partira dans « fuse » s, sur la grosse caisse ; « small » : un pouls.
func _launch_wave(fuse: float, flood: bool, small := false) -> void:
	if waves.size() >= DRUM_WAVE["max"]:
		return
	var to: Vector2 = main.player.position - anchor
	var base := to.angle() if to.length() > 1.0 else PI / 2.0
	if small:
		base = _roll_spin + float(_wave_count) * 0.9
	elif _wave_count % 2 == 1:
		# Un rond sur deux s'ouvre devant le joueur ; l'autre juste à côté : un pas de côté sur le temps.
		base += (DRUM_WAVE["gap"] * 0.5 + DRUM_WAVE["step"]) * (1.0 if _wave_count % 4 == 1 else -1.0)
	if flood:
		base += 0.35 * sin(float(_wave_count))
	var gaps: Array = []
	for i in DRUM_WAVE["gaps"]:
		gaps.append(base + TAU * i / DRUM_WAVE["gaps"])
	var reach := float(DRUMS_POWER[phase]["pulse"]) if small else INF
	waves.append({"r": radius * 0.9, "fuse": maxf(0.0, fuse), "total": maxf(0.05, fuse), "gaps": gaps, "hit": false, "reach": reach, "small": small, "born": -1.0})
	if not small:
		_wave_count += 1


## Une claque : une bouffée de spores, un par bras, la spirale tourne d'un pas.
func _puff(arms: int) -> void:
	if arms <= 0:
		return
	_roll_spin += PUFF["spin"]
	var to: Vector2 = main.player.position - anchor
	var base := (to.angle() if to.length() > 1.0 else 0.0) + _roll_spin
	for i in arms:
		var dir := Vector2.from_angle(base + TAU * i / arms)
		spores.append({"pos": anchor + dir * radius * 0.8, "vel": dir * PUFF["speed"], "r": PUFF["radius"], "dmg": PUFF["damage"]})


## Un charleston : un spore par jet, le jet tourne d'un pas à chaque coup.
func _spark(n: int) -> void:
	_spark_angle += SPARK["step"]
	for i in n:
		var dir := Vector2.from_angle(_spark_angle + TAU * i / n)
		spores.append({"pos": anchor + dir * radius * 0.75, "vel": dir * SPARK["speed"], "r": SPARK["radius"], "dmg": SPARK["damage"]})


## Une caisse douce : de petites vesses gonflent autour du joueur et crèvent « fuse » s plus tard.
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
		if absf(angle_difference(float(g), to.angle())) < DRUM_WAVE["gap"] * 0.5 - margin / d:
			return true
	return false


func _update_waves(delta: float) -> void:
	if waves.is_empty():
		return
	var p = main.player
	var limit: float = arena.radius + anchor.distance_to(arena.center) + DRUM_WAVE["width"]
	var kept: Array = []
	for wv in waves:
		if wv["fuse"] > 0.0:
			wv["fuse"] -= delta
			if wv["fuse"] <= 0.0:
				drum_flash = 0.0
				wv["born"] = t
				if not wv["small"]:
					main.fx.shake(1.5)
					if not Settings.reduce_effects:
						main.fx.ring(anchor, radius * 0.5, radius * 1.8, 0.25, Color(Art.ec("poison", "clair"), 0.8), 5.0)
			kept.append(wv)
			continue
		var small: bool = wv["small"]
		var r0: float = wv["r"]
		var r1: float = r0 + DRUM_WAVE["speed"] * delta
		wv["r"] = r1
		var d: float = p.position.distance_to(anchor)
		var half: float = (PULSE["width"] if small else DRUM_WAVE["width"]) * 0.5 + p.radius * 0.6
		if not wv["hit"] and d > r0 - half and d < r1 + half and r0 < float(wv["reach"]) and not _in_wave_gap(wv, p.position, p.radius * 0.5):
			if p.invuln <= 0.0:
				wv["hit"] = true
				_hurt(PULSE["damage"] if small else DRUM_WAVE["damage"], true)
		if r1 < minf(limit, float(wv["reach"]) + 40.0):
			kept.append(wv)
	waves = kept


func _update_spores(delta: float) -> void:
	if spores.is_empty():
		return
	var p = main.player
	var limit: float = arena.radius + 30.0
	var kept: Array = []
	for s in spores:
		s["pos"] += s["vel"] * delta
		var pos: Vector2 = s["pos"]
		var small: bool = s.get("small", false)
		if pos.distance_to(p.position) < _spore_radius(s) + p.radius and p.invuln <= 0.0:
			if s.has("dmg"):
				_hurt(float(s["dmg"]), true)
			else:
				_hurt(SPIRAL["damage"] if small else VOLLEY["damage"])
			continue
		if pos.distance_squared_to(arena.center) < limit * limit:
			kept.append(s)
	spores = kept


## Rayon d'un spore en vol (salve, spirale, ou batterie).
func _spore_radius(s: Dictionary) -> float:
	return float(s.get("r", VOLLEY["radius"] * (0.8 if s.get("small", false) else 1.0)))


func _update_clouds(delta: float) -> void:
	if clouds.is_empty():
		return
	var burst := false
	for c in clouds:
		if c["fuse"] > 0.0:
			c["fuse"] -= delta * (1.0 if c.get("sync", false) else cadence())
			if c["fuse"] <= 0.0:
				burst = true
				main.fx.ring(c["pos"], 10.0, CLOUD["radius"], 0.3, Color(Art.ec("poison", "clair"), 0.8), 4.0)
		else:
			c["life"] -= delta
	if burst:
		Sfx.play("nuage", anchor)
	clouds = clouds.filter(func(c): return c["fuse"] > 0.0 or c["life"] > 0.0)
	_cloud_tick -= delta
	if _cloud_tick > 0.0:
		return
	_cloud_tick = CLOUD["tick"]
	var p = main.player
	for c in clouds:
		if c["fuse"] <= 0.0 and p.position.distance_to(c["pos"]) < CLOUD["radius"] + p.radius * 0.3:
			_hurt(CLOUD["dps"] * CLOUD["tick"])
			break


## Vrai si pos est sur la bande de l'anneau g (hors de sa brèche), à « margin » près.
func _on_ring(g: Dictionary, pos: Vector2, margin: float) -> bool:
	var to := pos - anchor
	if absf(to.length() - g["r"]) > FAIRY["width"] * 0.5 + margin:
		return false
	return absf(wrapf(to.angle() - g["gap"], -PI, PI)) > FAIRY["gap"] * 0.5


func _update_rings(delta: float) -> void:
	if rings.is_empty():
		return
	var p = main.player
	var limit: float = arena.radius + anchor.distance_to(arena.center) + FAIRY["width"]
	var kept: Array = []
	for g in rings:
		g["r"] += FAIRY["speed"] * delta
		if not g["hit"] and _on_ring(g, p.position, p.radius * 0.5) and p.invuln <= 0.0:
			g["hit"] = true
			_hurt(FAIRY["damage"])
		if g["r"] < limit:
			kept.append(g)
	rings = kept


func _enter_phase(n: int) -> void:
	phase = n
	score.reset()
	transition = PHASE_PAUSE
	cycle = 0
	gap = 0.3
	main.fx.ring(anchor, radius, 420.0, 0.7, Color(Art.ec("poison", "clair"), 0.9), 8.0)
	if n == 3:
		arena.start_shrink()


## Temps avant qu'une attaque annoncée ou en cours touche ce point (INF si rien ne le menace).
func danger_time(pos: Vector2, margin := 26.0) -> float:
	var best := INF
	for c in clouds:
		if pos.distance_to(c["pos"]) < CLOUD["radius"] + margin:
			best = minf(best, maxf(c["fuse"], 0.0))
	for s in spores:
		var v: Vector2 = s["vel"]
		var u := clampf((pos - s["pos"]).dot(v) / v.length_squared(), 0.0, 1.5)
		if (s["pos"] + v * u).distance_to(pos) < _spore_radius(s) + margin:
			best = minf(best, u)
	for r in pricks:
		if r["burst"] < 0.0 and pos.distance_to(r["pos"]) < PRICK["radius"] + margin:
			best = minf(best, maxf(0.0, r["fuse"]))
	for wv in waves:
		var dw := pos.distance_to(anchor)
		if dw > float(wv["reach"]) + margin:
			continue
		var ahead: float = dw - float(wv["r"])
		if ahead > -DRUM_WAVE["width"] - margin and not _in_wave_gap(wv, pos, margin):
			best = minf(best, maxf(0.0, wv["fuse"]) + maxf(0.0, ahead - margin) / DRUM_WAVE["speed"])
	var to := pos - anchor
	var d := to.length()
	match attack:
		"salve":
			var wait := timer if stage == "annonce" else maxf(volley_timer, 0.0)
			for offset in [false, true]:
				for dir in volley_dirs(offset):
					var along := to.dot(dir)
					if along > 0.0 and absf(to.dot(dir.orthogonal())) < VOLLEY["radius"] + margin:
						best = minf(best, wait + along / VOLLEY["speed"])
		"onde":
			if d < _wave_radius() + margin:
				best = minf(best, timer)
		"spirale":
			if d < 260.0:
				best = minf(best, timer if stage == "annonce" else 0.4)
		"mycelium":
			for dir in lines:
				if _on_line(pos, dir, margin):
					best = minf(best, timer)
		"anneaux":
			if stage == "annonce":
				best = minf(best, timer + maxf(0.0, d - radius) / FAIRY["speed"])
	for g in rings:
		var ahead: float = d - g["r"]
		if ahead > -FAIRY["width"] and absf(wrapf(to.angle() - g["gap"], -PI, PI)) > FAIRY["gap"] * 0.5 - margin / maxf(d, 1.0):
			best = minf(best, maxf(0.0, ahead) / FAIRY["speed"])
	if d < radius + margin + 20.0:
		best = minf(best, 0.0)
	return best


func _clear_attacks() -> void:
	attack = ""
	stage = ""
	spores = []
	clouds = []
	buds = []
	lines = []
	rings = []
	ring_gaps = []
	waves = []
	pricks = []


## Le robot tourne autour d'elle, hors de l'onde quand elle s'annonce.
func bot_ring(arena_radius: float) -> float:
	var ring := minf(250.0, arena_radius - 60.0)
	if attack == "onde" and arena_radius - 50.0 > _wave_radius() + 40.0:
		ring = _wave_radius() + 45.0
	return ring


# --- Dessin ---
#
# Bestiaire d'herbier (refonte des personnages, B2) : le dessin est dans
# scripts/creature_art/spore/_amanite_mere.gd (vue de trois quarts, encre fine, palette de Spore,
# braise = ennemi), comme les Flétris du marais dont elle est la mère. Ici, la pose seulement :
# gonflement des annonces, recul après l'onde, chapeau soulevé (phase 2), fendu (phase 3),
# affaissement et cendre à la mort, regard tourné vers le joueur visé.

const Art_ = preload("res://scripts/creature_art/spore/_amanite_mere.gd")
const BodyCache = preload("res://scripts/boss_body_cache.gd")
const Exalte = preload("res://scripts/boss_art/exalte.gd")

## Tournée vers la gauche (vers la dernière cible visée).
var face_left := false


## Avancée de l'annonce en cours (0 → 1), 0 hors annonce.
func _announce_k() -> float:
	if stage != "annonce" or stage_time <= 0.0:
		return 0.0
	return clampf(1.0 - timer / stage_time, 0.0, 1.0)


func pose() -> Dictionary:
	var k := _announce_k()
	var die := clampf(dying / death_time, 0.0, 1.0) if dead else 0.0
	if absf(aim.x) > 0.25:
		face_left = aim.x < 0.0
	# Gonflement pendant l'annonce (nuages, onde, spirale), recul juste après l'onde.
	var swell := 1.0 + (0.1 * Anim.ease_out(k) if attack in ["nuages", "onde", "spirale", "anneaux"] else 0.0)
	if strike_flash >= 0.0:
		swell *= 1.0 - 0.12 * (1.0 - strike_flash / WAVE["flash"])
	var lift := (1.0 if phase >= 2 else 0.0) * (1.0 - Anim.ease_out(die)) + 0.7 * Anim.ease_out(k) * float(attack == "spirale")
	# Valeurs quantifiées : le corps est cuit une fois par pose (boss_body_cache.gd).
	return {"t": t, "k": snappedf(k, 0.25) if stage == "annonce" and attack in ["nuages", "onde", "spirale", "invocation", "anneaux"] else 0.0, "attack": attack, "phase": mini(phase, 3),
		"die": snappedf(die, 0.1), "swell": snappedf(swell, 0.02), "lift": snappedf(lift, 0.25),
		"hit": 1.0 if hit_flash > 0.0 else 0.0, "poison": poison_time > 0.0,
		"ash": snappedf(Anim.ease_out(clampf(dying / death_time * 1.4, 0.0, 1.0)), 0.1) if dead else 0.0, "flip": face_left}


var _cache


func _draw() -> void:
	var h := Art_.HEIGHT * radius / 72.0
	if _cache == null:
		_cache = BodyCache.new(self, Rect2(Vector2(-0.95, -1.25) * h, Vector2(1.9, 1.55) * h), func(ci, p): Art_.draw(ci, Vector2.ZERO, h, p))
	# Respiration : le chapeau s'élargit et s'aplatit doucement, autour des pieds.
	var b := sin(t * TAU / 3.2) * (0.0 if dead else 1.0)
	# Charge sur la musique (boss_base.gd) : elle tremble, se gonfle sur chaque impulsion ; puis elle
	# bat la mesure : un sursaut du chapeau sur chaque grosse caisse.
	var swell := 0.05 * charge_energy() * charge_pulse() + 0.08 * charge_overflow()
	if drum_flash >= 0.0:
		swell += 0.05 * (1.0 - drum_flash)
	var xf := Transform2D(0.0, Vector2(1.0 + 0.018 * b, 1.0 - 0.018 * b) * (1.0 + swell), 0.0, charge_jitter())
	_cache.paint(self, Art_, h, Vector2(0, radius * 0.35), pose(), xf, frozen or BodyCache.headless())
	# Charge : le poison gonfle sous le chapeau, battu par les impulsions.
	if charge >= 0.0 and not dead:
		var e := charge_energy()
		var pulse := charge_pulse()
		Ink.halo(self, Vector2(0, -h * 0.45), radius * (0.35 + 0.9 * e + 0.25 * pulse + 0.6 * charge_overflow()), Art.ec("poison", "clair"), 0.6 + 1.6 * e + 0.8 * pulse)
	# Phase exaltée : couronne de flammes d'encre autour du chapeau, qui bat sur les temps.
	var glow := exalt_glow()
	if glow > 0.0:
		Exalte.aura(self, Vector2(0, -h * 0.55), radius, 1.0, (glow - 0.55) / 0.45, t)


## Annonces au sol, en coordonnées monde (grammaire de Art.telegraph). L'invocation, qui ne blesse
## pas, n'est pas en rouge ; les nuages crevés restent bordés de rouge tant qu'ils blessent.
func draw_marks(c: CanvasItem) -> void:
	var k := _announce_k()
	for cl in clouds:
		if cl["fuse"] > 0.0:
			var ck := clampf(1.0 - cl["fuse"] / float(cl.get("total", CLOUD["annonce"])), 0.0, 1.0)
			Art.telegraph(c, {"type": "cercle", "centre": cl["pos"], "rayon": CLOUD["radius"]}, ck, -1.0, t)
	match attack:
		"salve":
			if stage == "annonce":
				var n: int = PHASES[phase]["spores"]
				Art.telegraph(c, {"type": "cone", "centre": anchor, "direction": aim.angle(), "ouverture": VOLLEY["spread"] * n, "rayon": 360.0}, k, -1.0, t)
		"onde":
			Art.telegraph(c, {"type": "cercle", "centre": anchor, "rayon": _wave_radius()}, k, -1.0, t)
		"spirale":
			if stage == "annonce":
				var arms: int = PHASES[phase]["arms"]
				for i in arms:
					var d := Vector2.from_angle(spiral_angle + TAU * i / arms)
					Art.telegraph(c, {"type": "ligne", "de": anchor + d * radius * 0.7, "a": anchor + d * 330.0, "largeur": 26.0}, k, -1.0, t)
		"invocation":
			var col := Art.ec("poison", "clair")
			for b in buds:
				c.draw_arc(b, 30.0 - 12.0 * k, 0.0, TAU, 24, Color(col, 0.35 + 0.5 * k), Art.TRAIT, true)
				Art.volume_circle(c, b, 6.0 + 8.0 * k, Art.ec("poison", "sombre").lerp(Art.ec("poison"), k), 0.7)
		"anneaux":
			# La première vague et sa brèche : l'anneau se remplit depuis son pied jusqu'au bord.
			if stage == "annonce" and not ring_gaps.is_empty():
				Art.telegraph(c, _ring_shape(ring_gaps[0], radius * 0.9, _ring_reach()), k, -1.0, t)
		"mycelium":
			for d in lines:
				Art.telegraph(c, {"type": "ligne", "de": anchor + d * radius * 0.6, "a": anchor + d * MYCELIUM["length"], "largeur": MYCELIUM["width"]}, k, -1.0, t)
				# Le sol se fend le long de la ligne.
				var pts := PackedVector2Array()
				for j in 9:
					var u := j / 8.0 * k
					pts.append(anchor + d * (radius * 0.6 + (MYCELIUM["length"] - radius * 0.6) * u) + d.orthogonal() * sin(j * 1.7) * 6.0)
				if pts.size() >= 2:
					c.draw_polyline(pts, Color(Art.ec("poison", "clair"), 0.7), Art.TRAIT, true)
	_draw_waves(c)
	for r in pricks:
		if r["burst"] < 0.0:
			Art.telegraph(c, {"type": "cercle", "centre": r["pos"], "rayon": PRICK["radius"]}, 1.0 - clampf(r["fuse"] / maxf(float(r["total"]), 0.01), 0.0, 1.0), -1.0, t)
	if strike_flash >= 0.0:
		var f := strike_flash / WAVE["flash"]
		if not lines.is_empty():
			for d in lines:
				Art.telegraph(c, {"type": "ligne", "de": anchor + d * radius * 0.6, "a": anchor + d * MYCELIUM["length"], "largeur": MYCELIUM["width"]}, 1.0, f, t)
		else:
			Art.telegraph(c, {"type": "cercle", "centre": anchor, "rayon": _wave_radius()}, 1.0, f, t)


## Portée des ronds de sorcière : jusqu'au bord de l'arène du côté le plus loin.
func _ring_reach() -> float:
	return minf(arena.radius + anchor.distance_to(arena.center), 420.0)


func _ring_shape(gap_a: float, r0: float, r1: float) -> Dictionary:
	var half: float = FAIRY["gap"] * 0.5
	return {"type": "anneau", "centre": anchor, "interieur": r0, "rayon": r1, "debut": gap_a + half, "fin": gap_a + TAU - half}


## Un rond de sorcière qui s'étend : bande bordée de rouge, chapeaux de champignons qui y poussent,
## rien dans la brèche.
func _draw_ring(c: CanvasItem, g: Dictionary) -> void:
	var r: float = g["r"]
	var w: float = FAIRY["width"]
	var half: float = FAIRY["gap"] * 0.5
	var a0: float = g["gap"] + half
	var a1: float = g["gap"] + TAU - half
	var spore := Art.ec("poison")
	var clair := Art.ec("poison", "clair")
	var shape := _ring_shape(g["gap"], r - w * 0.5, r + w * 0.5)
	c.draw_colored_polygon(Art.telegraph_polygon(shape, 1.0), Color(spore, 0.22))
	var danger := Color(Art.c("danger"), 0.8)
	c.draw_arc(anchor, r + w * 0.5, a0, a1, 64, danger, Art.TRAIT, true)
	c.draw_arc(anchor, r - w * 0.5, a0, a1, 48, Color(danger, 0.45), Art.TRAIT_FIN, true)
	# Chapeaux : un tous les ~28 px, qui sortent en grandissant.
	var grow := clampf((t - float(g["born"])) / 0.25, 0.3, 1.0)
	var n := maxi(6, int((a1 - a0) * r / 28.0))
	var ink := Art.c("contour")
	for i in n:
		var a := lerpf(a0, a1, (i + 0.5) / n)
		var q := anchor + Vector2.from_angle(a) * (r + w * 0.18 * sin(i * 2.3))
		var cap := (6.0 + 2.5 * float(i % 3)) * grow
		c.draw_line(q, q + Vector2(0, -cap * 0.9), ink, 2.4, true)
		var top := q + Vector2(0, -cap * 0.9)
		var dome := Art.ellipse(top, cap, cap * 0.55, 12)
		c.draw_colored_polygon(dome, Art.bc("braise") if i % 5 == 0 else spore)
		Art.outline(c, dome, ink, 1.4)
		c.draw_circle(top + Vector2(-cap * 0.3, -cap * 0.15), cap * 0.18, clair)


## Ronds de sorcière de la batterie : pendant l'annonce, la bande se ramasse autour d'elle en rouge ;
## partis, une bande de spores bordée de rouge où poussent des chapeaux (les pouls : un fil de spores
## qui s'éteint vite), ouverte de ses brèches.
func _draw_waves(c: CanvasItem) -> void:
	if waves.is_empty():
		return
	var danger := Art.c("danger")
	var spore := Art.ec("poison")
	var ink := Art.c("contour")
	var half: float = DRUM_WAVE["gap"] * 0.5
	for wv in waves:
		var gaps: Array = wv["gaps"].duplicate()
		gaps.sort()
		var fuse: float = wv["fuse"]
		var k := 1.0 - clampf(fuse / float(wv["total"]), 0.0, 1.0) if fuse > 0.0 else 1.0
		var small: bool = wv["small"]
		var r: float = wv["r"] if fuse <= 0.0 else radius * (0.9 + 1.4 * (1.0 - k))
		var reach: float = minf(_ring_reach(), float(wv["reach"]))
		var w: float = PULSE["width"] if small else DRUM_WAVE["width"]
		var fade := 1.0
		if fuse <= 0.0:
			fade = clampf((reach + w - r) / (40.0 if small else 80.0), 0.0, 1.0)
		for i in gaps.size():
			var a0: float = float(gaps[i]) + half
			var a1: float = float(gaps[(i + 1) % gaps.size()]) - half
			if a1 <= a0:
				a1 += TAU
			var segs := maxi(4, int((a1 - a0) * (6.0 if small else 12.0)))
			if fuse > 0.0:
				c.draw_arc(anchor, r, a0, a1, segs, Color(danger, 0.25 + 0.55 * k), Art.TRAIT * (1.0 + k), true)
				continue
			c.draw_arc(anchor, r, a0, a1, segs, Color(spore, 0.35 * fade), w, true)
			c.draw_arc(anchor, r + w * 0.5, a0, a1, segs, Color(danger, 0.8 * fade), Art.TRAIT_FIN, true)
			if small:
				continue
			# Chapeaux de champignons le long du rond.
			var grow := clampf((t - float(wv["born"])) / 0.2, 0.3, 1.0)
			var n := int((a1 - a0) * r / 34.0)
			for j in n:
				var a := lerpf(a0, a1, (j + 0.5) / float(n))
				var q := anchor + Vector2.from_angle(a) * r
				var cap := (5.0 + 2.0 * float(j % 3)) * grow
				var top := q + Vector2(0, -cap * 0.9)
				c.draw_line(q, top, Color(ink, fade), 2.0, true)
				var dome := Art.ellipse(top, cap, cap * 0.55, 10)
				c.draw_colored_polygon(dome, Color(Art.bc("braise") if j % 4 == 0 else spore, fade))
				Art.outline(c, dome, Color(ink, fade), 1.2)


## Spores en vol et nuages crevés, au-dessus des personnages, en coordonnées monde.
func draw_overlay(c: CanvasItem) -> void:
	for g in rings:
		_draw_ring(c, g)
	var spore := Art.ec("poison")
	var clair := Art.ec("poison", "clair")
	for cl in clouds:
		if cl["fuse"] > 0.0:
			continue
		var life: float = cl["life"]
		var fade := clampf(life / 0.6, 0.0, 1.0)
		var pos: Vector2 = cl["pos"]
		var rr: float = CLOUD["radius"]
		for i in 7:
			var a := TAU * i / 7.0 + t * 0.3
			var q := pos + Vector2.from_angle(a) * rr * 0.55
			c.draw_circle(q, rr * 0.42, Color(spore.darkened(0.2), 0.22 * fade))
		c.draw_circle(pos, rr * 0.6, Color(spore, 0.2 * fade))
		for i in 4:
			var u := fposmod(t * 0.8 + i / 4.0, 1.0)
			var q := pos + Vector2(sin(i * 2.3 + t) * rr * 0.5, rr * 0.3 - rr * 0.8 * u)
			c.draw_arc(q, 3.0 + 4.0 * u, 0.0, TAU, 10, Color(clair, (1.0 - u) * 0.8 * fade), Art.TRAIT_FIN, true)
		c.draw_arc(pos, rr, 0.0, TAU, 40, Color(Art.c("danger"), 0.45 * fade), Art.TRAIT_FIN, true)
	for r in pricks:
		if r["burst"] >= 0.0:
			# Une petite vesse crève : bouffée qui s'ouvre et s'efface.
			var kp := clampf(r["burst"] / PRICK["burst"], 0.0, 1.0)
			var pos: Vector2 = r["pos"]
			c.draw_circle(pos, PRICK["radius"] * (0.4 + 0.7 * kp), Color(spore, 0.35 * (1.0 - kp)))
			for i in 5:
				var q := pos + Vector2.from_angle(TAU * i / 5.0 + pos.x * 0.02) * PRICK["radius"] * 0.9 * kp
				c.draw_arc(q, 3.0 + 3.0 * kp, 0.0, TAU, 8, Color(clair, 0.9 * (1.0 - kp)), Art.TRAIT_FIN, true)
	for s in spores:
		var p: Vector2 = s["pos"]
		var rr: float = _spore_radius(s)
		c.draw_circle(p, rr + 2.0, Art.c("contour"))
		Art.volume_circle(c, p, rr, spore, 0.9)
		c.draw_circle(p + Vector2(-rr * 0.25, -rr * 0.25), rr * 0.3, clair)


## L'Amanite-Mère endormie : un gros bouton fermé dans sa volve, tant que le combat n'a pas lieu.
static func draw_sleeper(a: Node2D) -> void:
	Art_.draw_sleeper(a, a.center + Vector2(0, 20.0), Art_.HEIGHT, a.t, a.state == "ouverte")


## Après la victoire : un cercle de fées, amanites saines dans la mousse, à la place de l'Amanite-Mère.
static func draw_victory(a: Node2D) -> void:
	Art_.draw_healed(a, a.center, 1.0, a.t)
