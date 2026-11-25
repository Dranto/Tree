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
## Seconde forme (à 33 %, phase 3) : elle se transforme sur place (TRANSFORM, sans écran à part,
## invulnérable le temps de la transformation). Le creux s'effondre autour d'elle (finale_arena.gd
## › start_collapse) : il ne reste qu'une île plus étroite au-dessus du gouffre. Elle rejette son
## manteau d'écorce et sa couronne, son cœur se fend sur un noyau de braise, six éclats des
## gardiens tournent autour d'elle (draw_colossus, « form »). Aux traits des phases 1 et 2
## s'ajoutent les attaques combinées des six régions, deux gardiens à la fois :
##   - tempete  (Vent + Ronce)   : la rafale part vers le joueur, et des épines volent dans son souffle ;
##   - floraison (Spore + Sève)  : des cercles de spores qui boivent : chaque dégât porté la soigne ;
##   - aurore   (Aube + Racine)  : les rayons de lumière, puis des racines jaillissent le long de chacun.
## Sa mort : les bras retombent en cendre, le cœur se fend, et la sève qu'il retenait jaillit ; à
## sa place, une pousse de l'Arbre de vie aux six couleurs (draw_victory).
##
## Au rythme du breakcore (assets/music/hand/finale.json) : elle ne tire plus au gré d'une pause,
## elle joue une partition (SCORE), phrase de quatre mesures par phrase de quatre mesures, chaque
## frappe sur son temps ; par-dessus, ses ondes de choc partent sur les grosses caisses et ses
## roulements d'épines sur les caisses claires du morceau, jusqu'au déluge du sommet de la phase 3.
## Elle bat la mesure de tout son corps. Sans morceau, elle reprend l'ordre de PHASES.
##
## Le socle (vie, phases, états, mort, interface d'ennemi) est dans boss_base.gd.
extends BossBase

const PHASE_LIMITS := [0.66, 0.33]
## Rayon du corps (contact, coups reçus) ; le dessin s'étend bien au-delà (bras, couronne, racines).
const BODY_RADIUS := 100.0
## Vie : BASE_HP + HP_PER_LEVEL par niveau du joueur (multipliée par la difficulté).
## Réglée pour un combat de 3 à 4 minutes du robot au niveau 20 (« -- --autotest=boss --region=finale »).
const BASE_HP := 5600.0
const HP_PER_LEVEL := 2000.0
## Par phase : pause entre deux attaques, ordre des attaques et ampleur.
const PHASES := {
	1: {"gap": 1.25, "order": ["epines", "spores", "epines", "spores"], "volleys": 2, "thorns": 9, "clouds": 3},
	2: {"gap": 1.05, "order": ["siphon", "rafale", "spores", "rejetons", "epines", "rafale"], "volleys": 2, "thorns": 11, "clouds": 4, "minions": 2},
	3: {"gap": 0.95, "order": ["tempete", "lumiere", "floraison", "racines", "aurore", "rafale", "rejetons", "tempete", "siphon", "floraison", "epines", "aurore"], "volleys": 3, "thorns": 11, "clouds": 4, "minions": 2, "rays": 5},
}
## La transformation en seconde forme : durée (invulnérable), et part de cette durée où le corps
## se défait (le manteau et la couronne tombent, le cœur s'ouvre).
const TRANSFORM := {"time": 3.6, "morph": 0.7}
## Attaques combinées de la seconde forme. tempete : épines plus rapides, éventail plus large ;
## floraison : nuages en plus, part des dégâts reprise ; aurore : racines par rayon, après l'éclair.
const STORM := {"thorn_speed": 1.3, "spread": 1.35, "volleys": 2}
const BLOOM := {"extra": 1, "drain": 1.0}
const DAWN := {"per_ray": 4, "delay": 0.35, "first": 150.0, "spacing": 95.0}
## Les six éclats qui tournent autour d'elle en seconde forme : rayon et vitesse de l'orbite.
const SHARDS := {"orbit": 2.05, "speed": 0.45}
## Attaque combinée -> les deux bras (rangs dans ARMS) qui s'allument pendant son annonce.
const COMBO_ARMS := {"tempete": [3, 0], "floraison": [1, 2], "aurore": [4, 5]}
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

# --- Partition sur le morceau ---
# Avec le morceau (boss_sync.gd : horloge audio, ou temps du jeu sans son), elle ne tire plus au
# hasard d'une pause : elle joue une partition. Chaque phase suit sa boucle, découpée en phrases de
# quatre mesures (16 temps) ; chaque phrase dit quelle attaque frappe sur quel temps (« coups »),
# l'annonce partant ANNOUNCE_BEATS temps avant (ramenée à MIN_ANNOUNCE si l'attaque d'avant déborde,
# sautée en dessous). Par-dessus, deux attaques suivent la batterie elle-même (les coups relevés dans
# le morceau, assets/music/hand/finale.json › sections › coups, tools/boss_track.py) :
#   - ondes    : chaque coup de grosse caisse des mesures données lance une onde de choc de cendre,
#                un anneau qui s'élargit d'elle jusqu'au mur, percé de brèches (s'y glisser, ou
#                esquiver au travers) ; une onde sur deux s'ouvre devant le joueur, l'autre à côté ;
#   - roulements : chaque coup de caisse claire des mesures données tire des épines en spirale
#                (les fills de fin de phrase) ;
#   - deluge   : au sommet de la phase 3 (« deluge » dans la phrase), toutes les mesures portent des
#                ondes et les roulements partent de ses six bras.
# Les mesures sont comptées dans la phrase (0-3). Sans morceau, enracinée (cadence ralentie) ou hors
# grille, elle revient à l'ordre de PHASES. Les phrases d'une phase se répètent si sa boucle est
# plus longue que la liste.
const SCORE := {
	1: {"loop": "boucle_1", "phrases": [
		{"coups": [[0, "epines"], [6, "spores"], [11, "epines"]], "ondes": [0, 1]},
		{"coups": [[0, "epines"], [6, "spores"], [12, "spores"]], "ondes": [0, 1, 2], "roulements": [3]},
		{"coups": [[0, "epines"], [6, "spores"], [11, "epines"]], "ondes": [1]},
		{"coups": [[0, "epines"], [6, "spores"], [12, "spores"]], "ondes": [0, 1, 2], "roulements": [3]},
	]},
	2: {"loop": "boucle_2", "phrases": [
		{"coups": [[0, "rafale"], [6, "spores"], [11, "epines"]], "ondes": [0, 2], "roulements": [3]},
		{"coups": [[0, "siphon"], [10, "rafale"], [14, "rejetons"]], "ondes": [1], "roulements": [3]},
		{"coups": [[0, "rafale"], [5, "epines"], [10, "spores"], [14, "rafale"]], "ondes": [2], "roulements": [3]},
		{"coups": [[0, "rafale"], [6, "spores"], [11, "epines"]], "ondes": [0, 2], "roulements": [3]},
		{"coups": [[0, "siphon"], [10, "rafale"], [14, "rejetons"]], "ondes": [1], "roulements": [1, 3]},
		{"coups": [[0, "rafale"], [6, "spores"], [11, "epines"]], "ondes": [0, 2], "roulements": [3]},
	]},
	3: {"loop": "boucle_3", "phrases": [
		{"coups": [[0, "tempete"], [6, "lumiere"], [10, "racines"], [14, "floraison"]], "ondes": [0, 2], "roulements": [3]},
		{"coups": [[0, "aurore"], [6, "rafale"], [9, "rejetons"], [11, "epines"]], "ondes": [1, 2], "roulements": [3]},
		{"coups": [[0, "siphon"], [8, "floraison"], [12, "aurore"]], "ondes": [0, 2], "roulements": [3]},
		{"coups": [[0, "tempete"], [7, "racines"], [11, "lumiere"], [14, "spores"]], "ondes": [0, 1, 2], "roulements": [3]},
		{"coups": [[0, "tempete"], [6, "lumiere"], [10, "racines"], [14, "floraison"]], "ondes": [0, 2], "roulements": [1, 3]},
		{"coups": [[0, "aurore"], [6, "rafale"], [9, "rejetons"], [11, "epines"]], "ondes": [0, 1, 2], "roulements": [3]},
		{"coups": [[0, "tempete"], [6, "lumiere"], [10, "racines"], [14, "floraison"]], "ondes": [0, 1, 2, 3], "roulements": [1, 3], "deluge": true},
		{"coups": [[0, "tempete"], [7, "racines"], [11, "lumiere"], [14, "spores"]], "ondes": [0, 1, 2, 3], "roulements": [1, 3], "deluge": true},
		{"coups": [[0, "lumiere"], [8, "aurore"]]},
		{"coups": [[0, "siphon"], [10, "lumiere"]], "roulements": [3]},
	]},
}
## Annonce (en temps) de chaque attaque de la partition, et la plus courte admise.
const ANNOUNCE_BEATS := {"epines": 3, "spores": 3, "siphon": 3, "rafale": 3, "tempete": 4, "lumiere": 3, "aurore": 3, "floraison": 3, "racines": 2, "rejetons": 3}
const MIN_ANNOUNCE := 2.0  # (1,75 admis : la fin d’une attaque tombe à une image près)
## Coups de batterie quand le morceau n'en donne pas (une phrase de quatre mesures, doubles croches).
const DRUMS := {"kick": [[0], [2, 8, 14], [0, 6, 12], []], "caisse": [[], [2, 6], [0, 10], [6, 8, 10, 12]]}
## Onde de choc : annonce (temps : elle se ramasse avant de partir), vitesse, épaisseur, brèches
## (nombre et ouverture en radians), dégâts, ondes au plus en vol.
const WAVE := {"lead": 2.0, "speed": 500.0, "width": 26.0, "gaps": 4, "gap": 0.9, "damage": 7.0, "max": 6}
## Roulement : bras qui tirent (2 ; 3 en seconde forme ; 6 au déluge), pas de la spirale (radians par
## coup), vitesse et dégâts des épines (part de THORNS).
const ROLL := {"arms": 2, "arms_unbound": 3, "arms_deluge": 6, "spin": 0.55, "speed": 300.0, "damage": 0.8}

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
## Marqué « boss final » : son dernier coup est le plus grand moment du jeu (moments.gd › _final_blow).
var grand_finale := true
## Temps du morceau où tombe la frappe annoncée, et où commence l'attaque suivante ; -1 : sans grille.
var _strike_beat := -1.0
var _begin_beat := -1.0
## Attaques qui tombent sur un temps fort (le premier ou le troisième temps de la mesure).
const HEAVY := ["siphon", "rafale", "tempete", "lumiere", "aurore", "floraison"]
## Éclair de la dernière frappe (rafale, lumière), de 0 à FLASH ; -1 : aucun.
var strike_flash := -1.0
var flash_kind := ""
## Transformation en seconde forme : temps écoulé (0 → TRANSFORM › time), -1 hors transformation.
var morph_time := -1.0
## Seconde forme atteinte (phase 3 entamée).
var unbound := false
## Durée de la transformation : TRANSFORM › time, ou tout le drop de la musique (boss_sync.gd).
var morph_len := 3.6
## Mue de la phase 2 sur le drop de la musique : durée totale (s) et avancée (0 → 1) ; -1 hors mue.
var mue_total := 0.0
var mue_k := -1.0
## Partition : temps du morceau où commence la boucle de la phase en cours (-1 : pas encore calée),
## ses coups ({"beat", "kind"}, en temps depuis le début de la boucle), ses coups de batterie
## ({"beat", "kind" : "onde" | "roulement", "arms"}) et sa longueur (temps).
var score_origin := -1.0
var score_phase := 0
var score_hits: Array = []
var score_drums: Array = []
var score_len := 64.0
## Temps (absolu) de la dernière frappe de la partition lancée, et jusqu'où la batterie est jouée.
var _score_last := -INF
var _drums_done := -INF
## Phrase en cours au déluge (pour le dessin et les bras).
var deluge := false
## Coups de la partition sautés (l'attaque d'avant débordait sur leur annonce) : 0 si elle est bien écrite.
var score_skipped := 0
var _rooted_skip := false
## Ondes de choc : {"r", "fuse" (s avant de partir), "gaps" (angles), "hit"}.
var waves: Array = []
var _wave_count := 0
var _roll_spin := 0.0
## Éclair du corps sur un coup de batterie (0 → 1), -1 : aucun.
var drum_flash := -1.0


func _setup() -> void:
	body_radius = BODY_RADIUS
	intro_time = 1.8
	death_time = 2.4
	base_hp = BASE_HP
	hp_per_level = HP_PER_LEVEL
	damage_per_level = 0.03
	contact_damage = 18.0
	phase_limits = PHASE_LIMITS
	color = Color("2a2226")


func _projectiles_step(delta: float) -> void:
	var on_drop: bool = music_waiting() and sync.stage == "drop"
	if morph_time >= 0.0:
		morph_time += delta
		if on_drop:
			# La transformation dure tout le drop : elle s'achève au retour de la batterie, et le creux
			# s'effondre au même rythme.
			morph_len = morph_time + sync.left()
			if arena.get("collapse_t") != null and arena.collapse_t >= 0.0:
				arena.collapse_time = maxf(0.5, morph_len)
		if morph_time >= morph_len and not on_drop:
			morph_time = -1.0
	# Mue de la phase 2 : elle se recroqueville et boit la cendre de l'arène pendant le drop.
	if on_drop and phase == 2:
		mue_total = maxf(mue_total, sync.left())
		mue_k = sync.wait_k(mue_total)
	else:
		mue_total = 0.0
		mue_k = -1.0
	_update_thorns(delta)
	_update_clouds(delta)
	_update_roots(delta)
	_update_waves(delta)
	if drum_flash >= 0.0:
		drum_flash += delta * 4.0
		if drum_flash > 1.0:
			drum_flash = -1.0
	if strike_flash >= 0.0:
		strike_flash += delta
		if strike_flash > FLASH:
			strike_flash = -1.0


func _fight_step(delta: float) -> void:
	var cad := cadence()
	var scored := _score_ready()
	if scored:
		_drums_step()
	if attack == "":
		var wanted := phase_for(hp / max_hp)
		if wanted > phase:
			_enter_phase(wanted)
			return
		if scored:
			_score_step()
			return
		if _begin_beat >= 0.0 and on_music_grid():
			gap = (_begin_beat - beats_now()) * beat_len()
		else:
			gap -= delta * cad
		if gap <= 0.0:
			_begin_beat = -1.0
			var order: Array = PHASES[phase]["order"]
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


## Pendant sa transformation, elle ne prend aucun dégât (la vie reste sur le seuil de la phase 3).
func take_damage(amount: float, crit: bool, dot := false) -> void:
	if transforming():
		return
	super.take_damage(amount, crit, dot)


func transforming() -> bool:
	return morph_time >= 0.0


## Avancée de la transformation du corps (0 : première forme, 1 : seconde forme).
func form_k() -> float:
	if not unbound:
		return 0.0
	if morph_time < 0.0:
		return 1.0
	return Anim.ease_out(clampf(morph_time / (morph_len * TRANSFORM["morph"]), 0.0, 1.0))


# --- Partition ---

## Elle suit le morceau même enracinée : la musique ne ralentit pas. Enracinée, elle saute un coup
## de la partition sur deux (_score_step) au lieu d'annoncer plus lentement.
func on_music_grid() -> bool:
	return sync != null and sync.running and sync.stage == ""


## Vrai quand la partition mène le combat (morceau calé, pas ralentie) ; la cale sur la boucle de la
## phase au premier passage.
func _score_ready() -> bool:
	if not on_music_grid() or not SCORE.has(phase):
		return false
	if score_phase != phase or score_origin < 0.0:
		_build_score()
	return true


## Pose la partition de la phase : sa boucle commence au temps où le combat a repris (resume_bar).
func _build_score() -> void:
	score_phase = phase
	var bb: int = sync.beats
	var start_bar: int = sync.resume_bar if sync.resume_bar >= 0 else int(floor(sync.bars_now()))
	score_origin = float(start_bar * bb)
	var cfg: Dictionary = SCORE[phase]
	var sec: Dictionary = sync.data.get("sections", {}).get(cfg["loop"], {})
	var bars := 16
	if sec.has("mesures"):
		bars = int(sec["mesures"][1]) - int(sec["mesures"][0]) + 1
	score_len = float(bars * bb)
	var drums: Dictionary = sec.get("coups", {})
	var phrases: Array = cfg["phrases"]
	score_hits = []
	score_drums = []
	for i in int(ceil(bars / 4.0)):
		var ph: Dictionary = phrases[i % phrases.size()]
		var base := float(i * 4 * bb)
		for h in ph["coups"]:
			if float(h[0]) + base < score_len:
				score_hits.append({"beat": base + float(h[0]), "kind": str(h[1]), "phrase": i})
		var arms: int = ROLL["arms_deluge"] if ph.get("deluge", false) else (ROLL["arms_unbound"] if unbound else ROLL["arms"])
		for kind in ["ondes", "roulements"]:
			var src := "kick" if kind == "ondes" else "caisse"
			for m in ph.get(kind, []):
				var bar_i: int = i * 4 + int(m)
				if bar_i >= bars:
					continue
				var hits: Array = drums[src][bar_i] if drums.has(src) and bar_i < drums[src].size() else DRUMS[src][int(m) % 4]
				for six in hits:
					score_drums.append({"beat": float(bar_i * bb) + float(six) / 4.0, "kind": "onde" if kind == "ondes" else "roulement", "arms": arms, "deluge": ph.get("deluge", false), "phrase": i})
	score_drums.sort_custom(func(a, b): return a["beat"] < b["beat"])
	_score_last = beats_now()
	# Le premier coup de la boucle (l'entrée de la batterie) part tout de suite, sans s'annoncer.
	_drums_done = beats_now() - WAVE["lead"] - 0.01


## Temps absolu (depuis le début du morceau) du prochain coup de la partition après « after ».
func _next_hit(after: float) -> Dictionary:
	var loop_i := floorf((after - score_origin) / score_len)
	for k in 2:
		var o := score_origin + (loop_i + k) * score_len
		for h in score_hits:
			var at: float = o + float(h["beat"])
			if at > after + 0.001:
				return {"at": at, "kind": h["kind"], "phrase": h["phrase"]}
	return {}


## Entre deux attaques : attend que l'annonce du prochain coup doive partir, et la lance pour
## qu'il frappe juste sur son temps. Un coup que l'attaque d'avant a trop serré est sauté.
func _score_step() -> void:
	var now := beats_now()
	var after := maxf(_score_last, now + MIN_ANNOUNCE - 0.25)
	var nxt := _next_hit(after)
	if nxt.is_empty():
		return
	var lead: float = ANNOUNCE_BEATS.get(nxt["kind"], 3)
	var left: float = nxt["at"] - now
	deluge = SCORE[phase]["phrases"][int(nxt["phrase"]) % SCORE[phase]["phrases"].size()].get("deluge", false)
	if left > lead:
		gap = (left - lead) * beat_len()
		return
	var planned := _next_hit(_score_last)
	if not planned.is_empty() and planned["at"] < nxt["at"] - 0.001:
		score_skipped += 1
	_score_last = nxt["at"]
	if cadence() < 0.999:
		_rooted_skip = not _rooted_skip
		if _rooted_skip:
			return
	_begin(nxt["kind"], nxt["at"])


## La batterie : les ondes s'annoncent WAVE › lead temps avant leur coup, les roulements tirent sur
## le coup même.
func _drums_step() -> void:
	var now := beats_now()
	var loop_i := floorf((_drums_done - score_origin) / score_len)
	for k in 2:
		var o := score_origin + (loop_i + k) * score_len
		for d in score_drums:
			var at: float = o + float(d["beat"])
			var start: float = at - (WAVE["lead"] if d["kind"] == "onde" else 0.0)
			if start <= _drums_done or start > now:
				continue
			if d["kind"] == "onde":
				_launch_wave((at - now) * beat_len(), d.get("deluge", false))
			else:
				_roll(int(d["arms"]))
	_drums_done = now


## Une onde de choc qui partira dans « fuse » secondes, sur le coup de grosse caisse.
func _launch_wave(fuse: float, flood: bool) -> void:
	if waves.size() >= WAVE["max"]:
		return
	var n: int = WAVE["gaps"]
	var to: Vector2 = main.player.position - anchor
	var base := to.angle() if to.length() > 1.0 else PI / 2.0
	# Une onde sur deux s'ouvre devant le joueur ; l'autre entre deux brèches : il faut bouger.
	if _wave_count % 2 == 1:
		base += PI / n
	if flood:
		base += 0.35 * sin(float(_wave_count))
	var gaps: Array = []
	for i in n:
		gaps.append(base + TAU * i / n)
	waves.append({"r": radius * 0.9, "fuse": maxf(0.0, fuse), "total": maxf(0.05, fuse), "gaps": gaps, "hit": false})
	_wave_count += 1


## Un coup de caisse claire : des épines en spirale, une par bras.
func _roll(arms: int) -> void:
	_roll_spin += ROLL["spin"]
	var to: Vector2 = main.player.position - anchor
	var base := (to.angle() if to.length() > 1.0 else 0.0) + _roll_spin
	for i in arms:
		var dir := Vector2.from_angle(base + TAU * i / arms)
		thorns.append({"pos": anchor + dir * radius * 0.9, "vel": dir * ROLL["speed"], "roll": true})
	drum_flash = 0.0
	if not Settings.reduce_effects:
		main.fx.ring(anchor, radius * 0.6, radius * 1.4, 0.18, Color(Art.ec("epine", "clair"), 0.7), 3.0)


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
				main.fx.shake(2.5)
				if not Settings.reduce_effects:
					main.fx.ring(anchor, radius * 0.5, radius * 2.0, 0.25, Color(Art.ec("cendre", "clair"), 0.9), 6.0)
			kept.append(wv)
			continue
		var r0: float = wv["r"]
		var r1: float = r0 + WAVE["speed"] * delta
		wv["r"] = r1
		var d: float = p.position.distance_to(anchor)
		var half: float = WAVE["width"] * 0.5 + p.radius * 0.6
		if not wv["hit"] and d > r0 - half and d < r1 + half and not _in_wave_gap(wv, p.position, p.radius * 0.5):
			if p.invuln <= 0.0:
				wv["hit"] = true
				_hurt_player(WAVE["damage"] * damage_scale)
		if r1 < limit:
			kept.append(wv)
	waves = kept


# --- Attaques ---

func _begin(kind: String, strike_at := -1.0) -> void:
	var cfg: Dictionary = PHASES[phase]
	if kind == "rejetons" and minions.size() >= SPROUTS["max_alive"]:
		# Sur la partition, des spores (qui ne débordent pas sur le coup suivant) ; sinon des épines.
		kind = "spores" if strike_at >= 0.0 else "epines"
	attack = kind
	stage = "annonce"
	Sfx.play("annonce", anchor)
	var p: Vector2 = main.player.position
	var to: Vector2 = p - anchor
	aim = to.normalized() if to.length() > 1.0 else Vector2.DOWN
	match kind:
		"epines":
			_set_timer(THORNS["annonce"])
		"spores", "floraison":
			_set_timer(SPORES["annonce"] * (1.1 if kind == "floraison" else 1.0))
			spore_marks = []
			var n: int = cfg["clouds"] + (BLOOM["extra"] if kind == "floraison" else 0)
			for i in n:
				var at := p
				if i > 0:
					at = p + Vector2.from_angle(TAU * i / float(n - 1) + randf() * 0.5) * randf_range(0.6, 1.0) * SPORES["spread"]
				spore_marks.append(_in_arena(at, SPORES["radius"] * 0.6))
		"siphon":
			_set_timer(SIPHON["annonce"])
		"rafale", "tempete":
			_set_timer(GUST["annonce"] * (1.15 if kind == "tempete" else 1.0))
			gust_len = _reach_to_wall(aim)
		"lumiere", "aurore":
			_set_timer(LIGHT["annonce"])
			rays = []
			var n: int = cfg.get("rays", LIGHT["rays"])
			for i in n:
				rays.append(aim.angle() + TAU * i / n)
			if kind == "aurore":
				# Les racines suivent chaque rayon, du centre vers le mur, après l'éclair de lumière.
				roots = []
				for a in rays:
					var dir := Vector2.from_angle(float(a))
					for i in DAWN["per_ray"]:
						var at: Vector2 = anchor + dir * (DAWN["first"] + DAWN["spacing"] * i)
						if at.distance_to(arena.center) > arena.radius - ROOTS["radius"] * 0.5:
							break
						roots.append({"pos": at, "fuse": LIGHT["annonce"] + DAWN["delay"] + ROOTS["step"] * i, "burst": -1.0, "i": i})
		"racines":
			_set_timer(ROOTS["annonce"])
			roots = []
			for i in ROOTS["count"]:
				var at: Vector2 = anchor + aim * (ROOTS["first"] + ROOTS["spacing"] * i)
				if at.distance_to(arena.center) > arena.radius - ROOTS["radius"] * 0.5:
					break
				roots.append({"pos": at, "fuse": ROOTS["annonce"] + ROOTS["step"] * i, "burst": -1.0, "i": i})
		"rejetons":
			_set_timer(SPROUTS["annonce"])
			buds = []
			var n: int = cfg.get("minions", 2)
			for i in n:
				var a := aim.angle() + PI + (i - (n - 1) / 2.0) * 0.8
				buds.append(_in_arena(anchor + Vector2.from_angle(a) * 180.0, 60.0))
	_sync_announce(strike_at)


## L'annonce qui vient d'être posée tombe sur la grille du morceau : la frappe sur le temps que donne
## la partition (« at »), sinon sur un temps (un temps fort pour les grosses attaques) ; les racines
## en doubles croches derrière elle.
func _sync_announce(at := -1.0) -> void:
	_strike_beat = -1.0
	if not on_music_grid():
		return
	_strike_beat = at if at >= 0.0 else beat_target(timer, 2.0 if attack in HEAVY else 1.0)
	var synced := (_strike_beat - beats_now()) * beat_len()
	timer = synced
	stage_time = synced
	if attack == "racines" or attack == "aurore":
		var step := beat_step(ROOTS["step"])
		var lead := beat_step(DAWN["delay"]) if attack == "aurore" else 0.0
		for r in roots:
			r["fuse"] = synced + lead + step * int(r.get("i", 0))
			r["total"] = r["fuse"]


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
	if attack in ["epines", "rafale", "tempete"] and timer > stage_time * 0.4:
		var to: Vector2 = main.player.position - anchor
		if to.length() > 1.0:
			aim = to.normalized()
			if attack != "epines":
				gust_len = _reach_to_wall(aim)


func _strike() -> void:
	stage = "frappe"
	_strike_beat = -1.0
	var p = main.player
	match attack:
		"epines":
			volleys_left = PHASES[phase]["volleys"]
			volley_timer = 0.0
			_set_timer((beat_len() if on_music_grid() else THORNS["between"]) * volleys_left)
		"spores", "floraison":
			var drinks := attack == "floraison"
			for m in spore_marks:
				clouds.append({"pos": m, "time": SPORES["linger"], "drain": drinks})
				main.fx.ring(m, 10.0, SPORES["radius"], 0.35, Color(Art.ec("seve" if drinks else "poison", "clair"), 0.8), 3.0)
			spore_marks = []
			_end_attack()
		"siphon":
			_siphon_tick = 0.0
			_set_timer(SIPHON["duration"])
		"rafale", "tempete":
			if _in_gust(p.position, p.radius * 0.5):
				_hurt_player(GUST["damage"] * damage_scale)
				p.position += aim * GUST["push"]
			strike_flash = 0.0
			flash_kind = "rafale"
			main.fx.shake(4.0)
			if attack == "tempete":
				# Les épines partent dans le souffle de la rafale, l'une après l'autre.
				volleys_left = STORM["volleys"]
				volley_timer = 0.0
				_set_timer((beat_len() if on_music_grid() else THORNS["between"]) * volleys_left)
			else:
				_end_attack()
		"lumiere", "aurore":
			if _in_rays(p.position, p.radius * 0.5):
				_hurt_player(LIGHT["damage"] * damage_scale)
			strike_flash = 0.0
			flash_kind = "lumiere"
			main.fx.shake(3.0)
			if attack == "aurore":
				var last := 0.0
				for r in roots:
					last = maxf(last, float(r["fuse"]))
				_set_timer(last + (0.0 if on_music_grid() else 0.1))
			else:
				_end_attack()
		"racines":
			# Les racines jaillissent l'une après l'autre (_update_roots) : l'attaque est finie quand la dernière est sortie.
			if on_music_grid():
				_set_timer(beat_step(ROOTS["step"]) * maxi(1, roots.size()))
			else:
				_set_timer(ROOTS["step"] * maxi(1, roots.size()) + 0.1)
		"rejetons":
			for b in buds:
				minions.append(main.spawn_enemy_kind(SPROUTS["kind"], b, main.threat(b)))
				main.fx.ring(b, 6.0, 46.0, 0.35, Color(Art.ec("racine", "clair"), 0.8), 3.0)
			buds = []
			_end_attack()


func _strike_step(delta: float) -> void:
	match attack:
		"epines", "tempete":
			volley_timer -= delta
			if volleys_left > 0 and volley_timer <= 0.0:
				volley_timer = beat_step(THORNS["between"]) if on_music_grid() else THORNS["between"]
				var storm := attack == "tempete"
				var speed: float = THORNS["speed"] * (STORM["thorn_speed"] if storm else 1.0)
				for dir in thorn_dirs(volleys_left % 2 == 0, STORM["spread"] if storm else 1.0):
					thorns.append({"pos": anchor + dir * radius * 0.9, "vel": dir * speed})
				volleys_left -= 1
		"siphon":
			_siphon_tick -= delta
			if _siphon_tick <= 0.0:
				_siphon_tick = SIPHON["tick"]
				var p = main.player
				if p.position.distance_to(anchor) < SIPHON["radius"] + p.radius * 0.3:
					_hurt_player(SIPHON["dps"] * SIPHON["tick"] * damage_scale * 2.0, SIPHON["drain"])


## Directions des épines d'une salve (les salves paires sont décalées d'un demi-écart).
func thorn_dirs(offset := false, widen := 1.0) -> Array:
	var n: int = PHASES[phase]["thorns"]
	var out: Array = []
	var shift := 0.5 if offset else 0.0
	for i in n:
		out.append(Vector2.from_angle(aim.angle() + (i - (n - 1) / 2.0 + shift) * THORNS["spread"] * widen))
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
	_begin_beat = beat_target(gap, 1.0) if on_music_grid() else -1.0


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
			_hurt_player(THORNS["damage"] * damage_scale * (ROLL["damage"] if s.get("roll", false) else 1.0))
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
	var drinks := false
	for c in clouds:
		c["time"] -= delta
		if tick and not hurt and p.position.distance_to(c["pos"]) < SPORES["radius"] + p.radius * 0.3:
			hurt = true
			drinks = c.get("drain", false)
		if c["time"] > 0.0:
			kept.append(c)
	if hurt:
		_hurt_player(SPORES["dps"] * SPORES["tick"] * damage_scale, BLOOM["drain"] if drinks else 0.0)
	clouds = kept


func _update_roots(delta: float) -> void:
	if roots.is_empty():
		return
	var p = main.player
	var kept: Array = []
	for r in roots:
		if r["burst"] < 0.0:
			# Le compte à rebours suit l'annonce (ralentie si elle est enracinée), puis le temps réel.
			r["fuse"] -= delta * (cadence() if stage == "annonce" and not on_music_grid() else 1.0)
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
	# La partition repart sur la boucle de la nouvelle phase ; les ondes pas encore parties s'éteignent.
	score_origin = -1.0
	deluge = false
	waves = waves.filter(func(wv): return wv["fuse"] <= 0.0)
	transition = PHASE_PAUSE
	cycle = 0
	gap = 0.3
	var arm_col := Art.ec(ARMS[(n - 1) * 2]["element"], "clair")
	main.fx.ring(anchor, radius, 460.0, 0.8, Color(arm_col, 0.9), 8.0)
	main.fx.shake(6.0)
	if n != 2:
		_unbind()


## Seconde forme : elle se transforme sur place, invulnérable ; le creux s'effondre autour d'elle.
## Ce qu'elle avait lancé s'éteint (rien ne frappe pendant la transformation).
func _unbind() -> void:
	unbound = true
	morph_time = 0.0
	morph_len = TRANSFORM["time"]
	transition = TRANSFORM["time"]
	_clear_attacks()
	strike_flash = -1.0
	main.fx.shake(10.0)
	main.screen_fx.glow(Art.ec("cendre"), 0.55, 1.4)
	for i in 3:
		main.fx.ring(anchor, radius * 0.8, 300.0 + 160.0 * i, 0.9 + 0.35 * i, Color(Art.ec(ARMS[i * 2 + 1]["element"], "clair"), 0.85), 6.0)
	if arena.has_method("start_collapse"):
		arena.start_collapse(TRANSFORM["time"])
	else:
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
	for wv in waves:
		var ahead: float = d - float(wv["r"])
		if ahead > -WAVE["width"] - margin and not _in_wave_gap(wv, pos, margin):
			best = minf(best, maxf(0.0, wv["fuse"]) + maxf(0.0, ahead - margin) / WAVE["speed"])
	match attack:
		"epines":
			var wait := timer if stage == "annonce" else maxf(volley_timer, 0.0)
			for offset in [false, true]:
				for dir in thorn_dirs(offset):
					var along := to.dot(dir)
					if along > 0.0 and absf(to.dot(dir.orthogonal())) < THORNS["radius"] + margin:
						best = minf(best, wait + along / THORNS["speed"])
		"spores", "floraison":
			for m in spore_marks:
				if pos.distance_to(m) < SPORES["radius"] + margin:
					best = minf(best, timer)
		"tempete":
			if stage == "annonce":
				if _in_gust(pos, margin):
					best = minf(best, timer)
				for offset in [false, true]:
					for dir in thorn_dirs(offset, STORM["spread"]):
						var along := to.dot(dir)
						if along > 0.0 and absf(to.dot(dir.orthogonal())) < THORNS["radius"] + margin:
							best = minf(best, timer + along / (THORNS["speed"] * STORM["thorn_speed"]))
			else:
				for offset in [false, true]:
					for dir in thorn_dirs(offset, STORM["spread"]):
						var along := to.dot(dir)
						if along > 0.0 and absf(to.dot(dir.orthogonal())) < THORNS["radius"] + margin:
							best = minf(best, maxf(volley_timer, 0.0) + along / (THORNS["speed"] * STORM["thorn_speed"]))
		"siphon":
			if d < SIPHON["radius"] + margin:
				best = minf(best, timer if stage == "annonce" else 0.0)
		"rafale":
			if stage == "annonce" and _in_gust(pos, margin):
				best = minf(best, timer)
		"lumiere", "aurore":
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
	volleys_left = 0
	waves = []


## Le robot tourne autour d'elle, hors du siphon quand il s'annonce.
func bot_ring(arena_radius: float) -> float:
	var ring := minf(250.0, arena_radius - 60.0)
	if attack == "siphon" and arena_radius - 50.0 > SIPHON["radius"] + 40.0:
		ring = SIPHON["radius"] + 45.0
	return ring


# --- Dessin ---
#
# Charte : les Flétris sont sombres et saturés, contour clair, braise dans les fentes. La
# Flétrissure est un colosse : ses racines s'étalent sur le sol du creux dans une flaque de brume de
# cendre (draw_floor, sous les annonces) ; derrière elle, une couronne de bois mort ; devant, six
# longs bras de racine noués et épineux, un manteau de plaques d'écorce, et le cœur, une graine
# noire côtelée, liée de racines, fendue de braises, avec un grand œil de braise au milieu. Un bras
# endormi reste gris de cendre ; éveillé, il prend la couleur de son élément (veine qui pulse) et
# porte son motif au bout (couronne d'épines, grappe de champignons, bulbe de sève, éventail de
# plumes, grappe de cristaux, griffe de racines) ; il s'allume pendant l'annonce de son attaque.
# Chaque phase ajoute des fentes et des braises (au sol, sur la couronne, dans la cendre qui monte).
# Endormie (draw_sleeper), c'est le même dessin replié, l'œil clos ; l'intro la déplie.


## Avancée de l'annonce en cours (0 → 1), 0 hors annonce.
func _announce_k() -> float:
	if stage != "annonce" or stage_time <= 0.0:
		return 0.0
	return clampf(1.0 - timer / stage_time, 0.0, 1.0)


## Éveil pendant l'entrée en scène (0 : endormie comme dans le creux, 1 : dressée).
func _wake_k() -> float:
	if mue_k >= 0.0:
		# Mue : elle se replie sur elle-même, puis se redresse d'un coup sur la dernière mesure.
		return 1.0 - 0.45 * sin(PI * clampf(mue_k * 1.15, 0.0, 1.0))
	if intro_time <= 0.0:
		return 1.0
	return Anim.ease_out(clampf(1.0 - intro / intro_time, 0.0, 1.0))


func _draw() -> void:
	var lit := -1
	var lit2 := -1
	for i in ARMS.size():
		if attack == ARMS[i]["trait"] or (attack == "rejetons" and i == 5):
			lit = i
	if COMBO_ARMS.has(attack):
		lit = COMBO_ARMS[attack][0]
		lit2 = COMBO_ARMS[attack][1]
	var die := clampf(dying / death_time, 0.0, 1.0) if dead else 0.0
	var charging := sync != null and music_waiting() and charge >= 0.0
	if charging:
		_draw_charge_back()
		# Elle gonfle sur chaque impulsion et tremble de plus en plus : l'énergie la déborde.
		var e := charge_energy()
		var sw := 1.0 + 0.05 * e + 0.05 * e * charge_pulse() + 0.08 * charge_overflow()
		var h := Vector2(0, -radius * 0.45)
		draw_set_transform(charge_jitter() + h - h * sw, 0.0, Vector2(sw, sw))
	var pulsing := not charging and not dead and on_music_grid()
	if pulsing:
		# Elle bat la mesure : un sursaut sur chaque temps, plus fort sur les coups de batterie.
		var bk: float = pow(1.0 - fposmod(beats_now(), 1.0), 3.0)
		var sw := 1.0 + 0.022 * bk + (0.06 * (1.0 - drum_flash) if drum_flash >= 0.0 else 0.0)
		if deluge:
			sw += 0.02 * bk
			# Au déluge, ses bras s'allument tour à tour, un par temps.
			if lit < 0:
				lit = int(beats_now()) % ARMS.size()
		var h := Vector2(0, -radius * 0.45)
		draw_set_transform(h - h * sw, 0.0, Vector2(sw, 2.0 - sw))
	draw_colossus(self, Vector2.ZERO, radius, t, phase, _announce_k(), lit, die, _wake_k(), _color, lit2, form_k())
	if pulsing:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if charging:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_charge_front()


func _charge_color() -> Color:
	return Art.ec("cendre", "clair")


## Sa mort : la cendre de son corps s'envole par flocons, la sève jaillit de ses fentes en étincelles,
## puis, à mesure qu'elle s'efface, des pétales et des lueurs de sève montent de ce qui reste.
var _die_rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_die_rng.seed = 2323


func _dying_step(_delta: float) -> void:
	if Settings.reduce_effects:
		return
	var k := clampf(dying / death_time, 0.0, 1.0)
	var h := anchor + Vector2(0, -radius * 0.45)
	var fx = main.fx
	for i in 3:
		var a := _die_rng.randf() * TAU
		var at := h + Vector2.from_angle(a) * radius * _die_rng.randf_range(0.2, 1.1)
		fx.glow_mote(at, Vector2(_die_rng.randf_range(-40.0, 40.0), -_die_rng.randf_range(60.0, 160.0)), _die_rng.randf_range(1.2, 2.2), _die_rng.randf_range(2.0, 4.0), Color(FletriArt.ash_color().lightened(0.2), 0.85))
	if _die_rng.randf() < 0.8:
		var a := _die_rng.randf() * TAU
		fx.mote(h + Vector2.from_angle(a) * radius * 0.3, Vector2.from_angle(a) * _die_rng.randf_range(250.0, 520.0), _die_rng.randf_range(0.3, 0.6), _die_rng.randf_range(2.0, 3.5), Color(Art.ec("seve", "clair"), 0.95))
	if k > 0.35:
		var tint := Art.ec(str(ARMS[_die_rng.randi() % ARMS.size()]["element"]), "clair")
		fx.petal(h + Vector2(_die_rng.randf_range(-1.0, 1.0), _die_rng.randf_range(-0.6, 0.6)) * radius, Vector2(_die_rng.randf_range(-90.0, 90.0), -_die_rng.randf_range(120.0, 240.0)), _die_rng.randf_range(1.6, 2.6), _die_rng.randf_range(6.0, 10.0), Color(tint, 0.95))
		fx.glow_mote(anchor + Vector2(_die_rng.randf_range(-1.0, 1.0) * radius, 0.0), Vector2(0.0, -_die_rng.randf_range(40.0, 110.0)), 2.0, 3.0, Color(Art.ec("seve", "clair"), 0.9))


## La charge, derrière elle : le sol qui se creuse d'anneaux qui se resserrent sur la grille, la cendre
## de l'arène aspirée en spirale (de plus en plus vite, de plus en plus dense), et les six éléments
## de ses bras qui tournent autour d'elle en se rapprochant.
func _draw_charge_back() -> void:
	var e := charge_energy()
	var pulse := charge_pulse()
	var hot := Art.ec("cendre", "clair")
	var ember := Art.ec("cendre")
	var h := Vector2(0, -radius * 0.45)
	var beat: float = fposmod(sync.bars_now() * sync.beats * charge_rate(), 1.0)
	_draw_charge_cracks(e, pulse)
	_draw_charge_sigil(e, pulse)
	_draw_charge_streams(e, pulse)
	_draw_charge_debris(e, pulse)
	# Anneaux au sol qui se referment : un par impulsion.
	for j in 3:
		var f := fposmod(beat + j / 3.0, 1.0)
		var rr := radius * lerpf(5.5, 0.9, f)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 64, Color(ember, (0.12 + 0.4 * e) * sin(PI * f)), 2.0 + 4.0 * e, true)
	# Cendre aspirée : de 28 à 76 brins, de plus en plus vite.
	var n := 28 + int(48.0 * e)
	for i in n:
		var f := fposmod(charge_spin * 0.3 + i * 0.6180339, 1.0)
		var a := TAU * i / float(n) + f * (2.4 + 2.0 * e)
		var r := lerpf(radius * 5.5, radius * 0.4, f)
		var p := h + Vector2.from_angle(a) * r
		var q := h + Vector2.from_angle(a - 0.12 - 0.2 * e) * (r + radius * (0.3 + 0.6 * e))
		var c := Art.ec("cendre", "clair").lerp(ember, 0.5) if i % 3 else hot
		draw_line(q, p, Color(c, 0.55 * sin(PI * f) * (0.3 + 0.7 * charge)), 2.0 + 3.0 * e, true)
	# Les six éléments de ses bras : des orbes qui tournent et se resserrent, avec leur traîne.
	for i in ARMS.size():
		var col := Art.ec(str(ARMS[i]["element"]), "clair")
		var a0 := charge_spin * (1.0 + 0.5 * e) * 1.4 + TAU * i / ARMS.size()
		var rr := radius * lerpf(3.6, 0.75, Anim.ease_in(charge))
		for k in 6:
			var a := a0 - k * (0.07 + 0.08 * e)
			var p := h + Vector2.from_angle(a) * rr * Vector2(1.0, 0.62)
			draw_circle(p, radius * (0.11 - 0.014 * k) * (1.0 + 0.6 * pulse * e), Color(col, (0.85 - 0.13 * k) * (0.4 + 0.6 * charge)))


static func _rand(i: float) -> float:
	return fposmod(sin(i * 12.9898 + 78.233) * 43758.5453, 1.0)


## Le sol se fend autour d'elle : des failles de braise qui partent de son pied et gagnent l'arène à
## mesure qu'elle charge ; elles s'allument sur chaque impulsion et blanchissent à la fin.
func _draw_charge_cracks(e: float, pulse: float) -> void:
	var ember := Art.ec("cendre")
	var hot := Art.ec("cendre", "clair")
	var white := Color(1.0, 0.97, 0.9)
	var reach := radius * lerpf(1.2, 7.0, Anim.ease_out(charge))
	if arena != null and arena.get("max_radius") != null:
		reach = minf(reach, arena.max_radius * 0.85)
	for i in 14:
		var a := TAU * i / 14.0 + 0.4 * _rand(i)
		var pts := PackedVector2Array([Vector2.from_angle(a) * radius * 0.5])
		var dir := a
		var l := 0.0
		var seg := radius * 0.45
		var k := 0
		while l < reach * (0.6 + 0.4 * _rand(i + 50)):
			dir += (_rand(i * 7 + k) - 0.5) * 0.9
			l += seg
			pts.append(pts[pts.size() - 1] + Vector2.from_angle(dir) * seg * Vector2(1.0, 0.62))
			k += 1
			if k > 24:
				break
		if pts.size() < 2:
			continue
		var w := 2.0 + 5.0 * e
		draw_polyline(pts, Color(Art.ec("cendre", "sombre"), 0.55 * (0.3 + 0.7 * charge)), w + 5.0, true)
		draw_polyline(pts, Color(ember.lerp(hot, pulse), 0.35 + 0.6 * pulse * (0.4 + 0.6 * e)), w, true)
		if e > 0.5:
			draw_polyline(pts, Color(white, (e - 0.5) * 1.6 * pulse), 1.5, true)


## Le cercle de la charge, au sol : trois anneaux de glyphes qui tournent en sens contraires (de plus
## en plus vite) et un compte à rebours : un segment s'allume sur chaque temps jusqu'au drop.
func _draw_charge_sigil(e: float, pulse: float) -> void:
	var hot := Art.ec("cendre", "clair")
	var ember := Art.ec("cendre")
	var white := Color(1.0, 0.97, 0.9)
	var sq := Vector2(1.0, 0.62)
	var total := maxi(1, int(round(_charge_total / (sync.bar / float(sync.beats)))))
	var done := clampi(total - int(ceil(charge_beats_left())), 0, total)
	var r0 := radius * 2.2
	var al := 0.25 + 0.6 * minf(1.0, charge * 3.0)
	# Compte à rebours : un segment par temps.
	for i in total:
		var a0 := -PI / 2.0 + TAU * i / total + 0.03
		var a1 := -PI / 2.0 + TAU * (i + 1) / total - 0.03
		var lit := i < done
		var col := hot.lerp(white, e) if lit else Art.ec("cendre", "sombre")
		var pts := PackedVector2Array()
		for k in 7:
			pts.append(Vector2.from_angle(lerpf(a0, a1, k / 6.0)) * r0 * sq)
		draw_polyline(pts, Color(col, al * (1.0 if lit else 0.6)), (5.0 + 4.0 * e) * (1.0 + (0.6 * pulse if i == done - 1 else 0.0)), true)
	# Anneaux de glyphes.
	for j in 3:
		var rr := radius * (1.3 + 0.55 * j + 0.25 * e)
		var spin := charge_spin * (1.0 + 0.6 * j) * (1.0 if j % 2 == 0 else -1.0)
		var n := 12 + 6 * j
		var pts := PackedVector2Array()
		for k in 65:
			pts.append(Vector2.from_angle(TAU * k / 64.0) * rr * sq)
		draw_polyline(pts, Color(ember, al * 0.6), 1.5 + 1.5 * e, true)
		for k in n:
			var a := spin + TAU * k / n
			var p := Vector2.from_angle(a) * rr * sq
			var d := Vector2.from_angle(a) * sq
			var o := d.orthogonal()
			var g := radius * (0.07 + 0.03 * pulse)
			match (k + j) % 3:
				0:
					draw_line(p - d * g, p + d * g, Color(hot, al), 2.0, true)
				1:
					draw_polyline(PackedVector2Array([p - o * g, p + d * g, p + o * g]), Color(hot, al), 2.0, true)
				_:
					draw_circle(p, g * 0.45, Color(hot.lerp(white, e), al))
	# Hexagramme qui relie les six bras, quand la charge est à mi-chemin.
	if charge > 0.35:
		var hk := clampf((charge - 0.35) / 0.3, 0.0, 1.0)
		var rr := radius * 1.9
		for k in 6:
			var a := -charge_spin * 0.5 + TAU * k / 6.0
			var b := a + TAU * 2.0 / 6.0
			var p := Vector2.from_angle(a) * rr * sq
			var q := Vector2.from_angle(b) * rr * sq
			draw_line(p, p.lerp(q, hk), Color(Art.ec(str(ARMS[k]["element"]), "clair"), al * 0.9), 2.0 + 2.5 * e, true)


## Six courants d'énergie, un par élément de ses bras, qui viennent du bord de l'arène et coulent vers
## son cœur : des traits qui filent de plus en plus vite le long de courbes qui se tordent.
func _draw_charge_streams(e: float, pulse: float) -> void:
	var h := Vector2(0, -radius * 0.45)
	var far: float = (arena.max_radius if arena != null and arena.get("max_radius") != null else radius * 7.0) * 0.95
	for i in ARMS.size():
		var col := Art.ec(str(ARMS[i]["element"]), "clair")
		var a := TAU * i / ARMS.size() + 0.3 + 0.25 * sin(charge_spin * 0.3 + i)
		var from := Vector2.from_angle(a) * far * Vector2(1.0, 0.62)
		var ctrl := Vector2.from_angle(a + 0.9 + 0.4 * e) * far * 0.55
		var pts := PackedVector2Array()
		for k in 25:
			var f := k / 24.0
			pts.append(from.lerp(ctrl, f).lerp(ctrl.lerp(h, f), f))
		var al := smoothstep(0.05, 0.4, charge)
		draw_polyline(pts, Color(col, 0.12 * al + 0.18 * e * pulse), 10.0 + 14.0 * e, true)
		draw_polyline(pts, Color(col, 0.3 * al + 0.3 * e), 2.0 + 2.0 * e, true)
		# Paquets d'énergie qui filent le long du courant.
		var m := 4 + int(10.0 * e)
		for k in m:
			var f := fposmod(charge_spin * (0.5 + 0.6 * e) + k / float(m) + i * 0.13, 1.0)
			var idx := int(f * 23.0)
			var p := pts[idx].lerp(pts[idx + 1], f * 23.0 - idx)
			draw_circle(p, (3.0 + 4.0 * e) * (0.5 + f), Color(col.lerp(Color.WHITE, f * e), al * (0.4 + 0.6 * f)))


## Des blocs du sol arrachés qui lévitent autour d'elle, tremblent, et sont aspirés vers elle à la fin.
func _draw_charge_debris(e: float, pulse: float) -> void:
	var stone := Art.ec("racine", "sombre").lerp(Art.c("ennemi"), 0.2).darkened(0.3)
	var hot := Art.ec("cendre", "clair")
	var h := Vector2(0, -radius * 0.45)
	for i in 16:
		var born := 0.05 + 0.5 * _rand(i + 3)
		if charge < born:
			continue
		var up := clampf((charge - born) / 0.3, 0.0, 1.0)
		var a := TAU * _rand(i + 11) + charge_spin * (0.15 + 0.2 * _rand(i)) * (1.0 + 2.0 * charge_overflow())
		var d := radius * lerpf(2.0 + 3.0 * _rand(i + 23), 0.5, pow(charge_overflow(), 0.7))
		var ground := Vector2.from_angle(a) * d * Vector2(1.0, 0.62)
		var lift := radius * (0.3 + 0.9 * _rand(i + 31)) * Anim.ease_out(up) + sin(t * 2.0 + i) * radius * 0.05
		var p := ground + Vector2(0, -lift) + Vector2(sin(t * 47.0 + i), cos(t * 53.0 + i)) * radius * 0.02 * e
		var s := radius * (0.08 + 0.1 * _rand(i + 41))
		draw_circle(ground, s * 0.9, Color(0, 0, 0, 0.25 * up))
		var rot := t * (0.5 + _rand(i + 5)) + i
		var poly := PackedVector2Array()
		for k in 5:
			poly.append(p + Vector2.from_angle(rot + TAU * k / 5.0) * s * (0.7 + 0.4 * _rand(i * 5 + k)))
		draw_colored_polygon(poly, stone)
		poly.append(poly[0])
		draw_polyline(poly, Color(hot, 0.3 + 0.6 * pulse * e), 1.5 + 1.5 * e, true)
		if e > 0.3:
			draw_line(p, p.lerp(h, 0.25), Color(hot, 0.25 * e * pulse), 1.5, true)


## La charge, devant elle : le cœur qui s'embrase et blanchit, la couronne de rayons, les éclairs
## qui crépitent (plus nombreux à chaque impulsion), les veines qui battent ; sur le dernier temps,
## elle déborde : un halo blanc qui vibre et des rayons qui fendent l'écran.
func _draw_charge_front() -> void:
	var e := charge_energy()
	var pulse := charge_pulse()
	var over := charge_overflow()
	var hot := Art.ec("cendre", "clair")
	var ember := Art.ec("cendre")
	var white := Color(1.0, 0.97, 0.9)
	var h := Vector2(0, -radius * 0.45) + charge_jitter()
	# Veines de braise sur le corps, qui battent sur les impulsions.
	for i in 9:
		var a := TAU * i / 9.0 + 0.5
		var from := h + Vector2.from_angle(a) * radius * 0.15
		var to := h + Vector2.from_angle(a + 0.3 * sin(i * 2.1)) * radius * (0.55 + 0.6 * e)
		draw_line(from, to, Color(ember.lerp(white, over), 0.35 + 0.6 * pulse), 3.0 + 6.0 * pulse + 4.0 * e, true)
	# Éclairs : 2 à 12, retirés à chaque impulsion.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_charge_hit) if _charge_hit >= 0 else 7
	var bolts := 2 + int(10.0 * e)
	for b in bolts:
		var a := rng.randf() * TAU
		var length := radius * rng.randf_range(1.0, 1.6 + 1.6 * e)
		var pts := PackedVector2Array([h])
		var steps := 6
		for k in range(1, steps + 1):
			var f := float(k) / steps
			var side := Vector2.from_angle(a).orthogonal() * rng.randf_range(-1.0, 1.0) * radius * 0.22 * f
			pts.append(h + Vector2.from_angle(a) * length * f + side)
		var al := (0.25 + 0.75 * pulse) * (0.4 + 0.6 * e)
		draw_polyline(pts, Color(hot, al * 0.5), 6.0 + 4.0 * e, true)
		draw_polyline(pts, Color(white, al), 2.0, true)
	# Couronne de rayons autour du cœur.
	var rays := 12 + int(12.0 * e)
	for i in rays:
		var a := TAU * i / rays + charge_spin * 0.5
		var l := radius * (0.5 + 0.9 * e * (0.6 + 0.4 * sin(t * 9.0 + i * 1.7)) + 0.5 * pulse * e)
		draw_line(h + Vector2.from_angle(a) * radius * 0.3, h + Vector2.from_angle(a) * (radius * 0.3 + l), Color(hot.lerp(white, e), 0.2 + 0.45 * e), 2.0 + 2.0 * e, true)
	# Le cœur : il grossit, blanchit, bat.
	var core := radius * (0.16 + 0.18 * e + 0.1 * pulse * (0.3 + e) + 0.15 * over)
	draw_circle(h, core * 1.9, Color(ember, 0.18 + 0.25 * e))
	draw_circle(h, core * 1.3, Color(hot, 0.3 + 0.4 * e))
	draw_circle(h, core, Color(hot.lerp(white, 0.4 + 0.6 * e), 0.55 + 0.45 * e))
	# Fissures de lumière sur son corps, de plus en plus nombreuses.
	var fissures := int(3.0 + 14.0 * e)
	for i in fissures:
		var a0 := TAU * _rand(i + 101)
		var p0 := h + Vector2.from_angle(a0) * radius * 0.35 * _rand(i + 102)
		var pts := PackedVector2Array([p0])
		for k in 3:
			pts.append(pts[k] + Vector2.from_angle(a0 + (_rand(i * 3 + k + 7) - 0.5) * 1.6) * radius * (0.12 + 0.1 * e))
		draw_polyline(pts, Color(hot.lerp(white, pulse), 0.4 + 0.6 * pulse), 2.0 + 2.0 * e, true)
	# Le dernier temps : elle déborde.
	if over > 0.0:
		var flick := 0.6 + 0.4 * sin(t * 90.0)
		draw_circle(h, radius * (1.0 + 1.6 * over), Color(white, 0.18 * over * flick))
		for i in 10:
			var a := TAU * i / 10.0 + 0.3 * sin(i * 4.1) + t * 0.7
			var l := radius * (2.0 + 10.0 * over)
			draw_line(h, h + Vector2.from_angle(a) * l, Color(white, 0.55 * over * flick), 3.0 + 8.0 * over, true)


## Le sol autour d'elle, sous les annonces (draw_marks) : une flaque de brume de cendre et les
## grosses racines qui l'ancrent au creux ; des braises y couvent dès la phase 2.
static func draw_floor(ci: CanvasItem, c: Vector2, r: float, t: float, phase: int, die := 0.0, form := 0.0) -> void:
	var fade := 1.0 - die
	var mist := FletriArt.ash_color().lerp(Art.c("ennemi"), 0.25).darkened(0.55)
	for j in 3:
		ci.draw_circle(c + Vector2(0, -r * 0.2), r * (1.5 + 0.55 * j + 0.05 * sin(t * 0.8 + j)), Color(mist, 0.16 * fade))
	var bark := Art.ec("racine", "sombre").lerp(Art.c("ennemi"), 0.25).darkened(0.25)
	var ember := Art.ec("cendre")
	for i in 11:
		var a := TAU * i / 11.0 + 0.23 * sin(i * 7.3)
		var length := r * (2.3 + 0.7 * fposmod(i * 0.618, 1.0)) * (1.0 - 0.45 * form)
		var path := _wiggle(c + Vector2.from_angle(a) * r * 0.55, a, length, r * 0.16, i * 1.9)
		_limb(ci, path, r * 0.15, r * 0.025, Color(bark, 0.95 * fade), Color(Art.c("ennemi_contour"), 0.18 * fade))
		# Une radicelle de côté.
		var fork := path[3]
		var sub := _wiggle(fork, a + (0.7 if i % 2 == 0 else -0.7), length * 0.35, r * 0.08, i * 3.1)
		_limb(ci, sub, r * 0.06, r * 0.015, Color(bark, 0.9 * fade))
		if phase >= 2 and die <= 0.0:
			var f := fposmod(t * 0.35 + i * 0.29, 1.0)
			var q := path[1].lerp(path[path.size() - 2], f)
			ci.draw_circle(q, r * 0.05, Color(ember, 0.55 * sin(PI * f)))
	# Seconde forme : les racines qui l'ancraient cassent, le sol se fend de braise sous elle.
	if form > 0.0:
		var hot := Art.ec("cendre", "clair")
		for i in 9:
			var a := TAU * i / 9.0 + 0.4
			var path := _wiggle(c + Vector2.from_angle(a) * r * 0.4, a, r * (1.4 + 0.9 * form + 0.3 * fposmod(i * 0.618, 1.0)), r * 0.12, i * 2.7)
			var pulse := 0.6 + 0.4 * sin(t * 3.0 + i)
			ci.draw_polyline(path, Color(Art.ec("cendre", "sombre"), 0.7 * form * fade), 9.0, true)
			ci.draw_polyline(path, Color(hot, 0.75 * form * pulse * fade), 3.0, true)


## La Flétrissure entière, en coordonnées locales autour de « c » (son pied) : la couronne de bois
## mort derrière, les six bras, le manteau d'écorce, le cœur noué de racines et fendu de braises,
## l'œil, et la cendre qui monte. Statique : sert aussi au boss endormi (draw_sleeper).
##   lit, lit2 : bras allumés par l'annonce (-1 : aucun), k : avancée de l'annonce ;
##   die : avancée de la mort (0 → 1) ; wake : 0 endormie, 1 dressée ;
##   tint : couleur d'une partie du corps (éclair du coup, poison, cendre ; BossBase._color) ;
##   form : seconde forme (0 → 1) : le manteau et la couronne tombent, les liens de racine cassent,
##          le cœur s'ouvre en deux sur un noyau de braise où l'œil grandit, six éclats des
##          gardiens tournent autour d'elle.
static func draw_colossus(ci: CanvasItem, c: Vector2, r: float, t: float, phase: int, k: float, lit: int, die: float, wake: float, tint: Callable, lit2 := -1, form := 0.0) -> void:
	var h := c + Vector2(0, -r * 0.45)
	var beat := Anim.breathe(t * (1.7 if phase >= 3 else 1.0) * (1.0 + 0.6 * form), (0.035 + 0.025 * form) * wake)
	var ash := FletriArt.ash_color()
	Art.shadow(ci, c + Vector2(0, r * 0.15), r * (1.7 + 0.2 * form))
	if form > 0.0:
		_draw_shards(ci, h, r, t, form, lit, lit2, k, die, false)
	if form < 1.0:
		_draw_crown(ci, h, r, t, phase, die, wake, tint, form)
	for i in ARMS.size():
		var awake: bool = phase >= int(ARMS[i]["phase"])
		var arm_lit := k if (i == lit or i == lit2) else 0.25 * form
		_draw_arm(ci, h, _arm_angle_at(i, t * (1.0 + form), wake), r, str(ARMS[i]["element"]), awake, arm_lit, die, wake, t + i * 1.3, tint, form)
	# Le manteau : des plaques d'écorce, en couronne autour du cœur ; elles s'écartent à la mort et
	# tombent pendant la transformation.
	if form < 1.0:
		var plate_col: Color = tint.call(Art.c("ennemi").darkened(0.55).lerp(Art.ec("racine", "sombre"), 0.4))
		for i in 10:
			var a := TAU * i / 10.0 + PI / 10.0 + 0.04 * sin(t * 0.9 + i) + 0.3 * form * (1 if i % 2 == 0 else -1)
			var d := Vector2.from_angle(a)
			var o := d.orthogonal()
			var off := 0.45 * die + 1.2 * form
			var base := h + d * r * (0.32 + off) + Vector2(0, r * 0.9 * form * form)
			var plen := r * (1.18 + 0.08 * sin(i * 2.7)) * beat * (1.0 - 0.35 * form)
			var plate := PackedVector2Array([base + o * r * 0.2, base + d * plen * 0.55 + o * r * 0.27, base + d * (plen - r * 0.32 + r * 0.45 * die), base + d * plen * 0.55 - o * r * 0.27, base - o * r * 0.2])
			var alpha := (1.0 - die * 0.85) * (1.0 - form)
			Art.volume(ci, plate, Color(plate_col, alpha), 0.45)
			Art.outline(ci, plate, Color(Art.c("ennemi_contour"), 0.45 * alpha), Art.TRAIT_FIN)
			ci.draw_line(base + d * r * 0.1, base + d * plen * 0.8, Color(plate_col.lightened(0.18), 0.7 * alpha), 2.0, true)
	# Le cœur : une graine noire, côtelée, qui bat. En seconde forme, elle s'ouvre en deux moitiés.
	var rx := r * 0.86 * beat
	var ry := r * 1.0 * beat
	var gap := r * 0.2 * form
	var body: Color = tint.call(Art.c("ennemi").darkened(0.45).lerp(Art.ec("cendre", "sombre"), 0.35))
	var crack_col := Art.ec("seve", "clair") if die > 0.0 else Art.ec("cendre")
	var glow := (0.6 + 0.35 * sin(t * (5.0 if phase >= 3 else 3.0))) * wake if die <= 0.0 else 1.0 - die * 0.5
	if form > 0.0:
		_draw_core(ci, h, r, t, form, die, glow)
	var halves: Array = [Art.ellipse(h, rx, ry, 32)]
	if form > 0.0:
		halves = [_half_ellipse(h - Vector2(gap, 0), rx, ry, -1, form), _half_ellipse(h + Vector2(gap, 0), rx, ry, 1, form)]
	for heart in halves:
		Art.volume(ci, heart, body, 0.55)
	var rib: Color = body.darkened(0.35)
	for j in 5:
		var u := (j + 1) / 6.0 * 2.0 - 1.0
		if form > 0.0 and absf(u) < 0.2:
			continue
		var sx := signf(u) * gap
		var pts := PackedVector2Array()
		for q in 9:
			var v := q / 8.0 * 2.0 - 1.0
			pts.append(h + Vector2(sx + u * rx * sqrt(maxf(1.0 - v * v, 0.0)) * 0.92, v * ry * 0.9))
		ci.draw_polyline(pts, Color(rib, 0.8), 2.5, true)
	# Les fentes de braise : deux, puis une de plus à chaque phase ; à la mort, la sève en jaillit.
	var cracks := [
		[Vector2(-0.12, -0.95), Vector2(0.04, -0.7), Vector2(-0.06, -0.45)],
		[Vector2(0.42, -0.55), Vector2(0.22, -0.3), Vector2(0.36, -0.02), Vector2(0.2, 0.2)],
		[Vector2(-0.45, -0.35), Vector2(-0.22, -0.1), Vector2(-0.38, 0.2)],
		[Vector2(0.05, 0.4), Vector2(-0.1, 0.62), Vector2(0.06, 0.85)],
		[Vector2(-0.6, 0.15), Vector2(-0.4, 0.45), Vector2(-0.5, 0.7)],
		[Vector2(0.62, 0.3), Vector2(0.45, 0.55), Vector2(0.55, 0.75)],
	]
	var shown := mini(cracks.size(), 1 + phase + (1 if die > 0.0 else 0))
	for j in shown:
		var pts := PackedVector2Array()
		for q in cracks[j]:
			# En seconde forme, chaque fente suit sa moitié du cœur.
			var x: float = q.x * rx + (gap if q.x >= 0.0 else -gap)
			pts.append(h + Vector2(x, q.y * ry))
		ci.draw_polyline(pts, Color(crack_col, 0.22 * glow), 10.0 + 6.0 * die, true)
		ci.draw_polyline(pts, Color(crack_col.lightened(0.2), glow), 3.0 + 3.0 * die, true)
	# Les racines qui l'enserrent : deux liens épais, en travers, par-dessus les fentes ; ils
	# cassent au début de la transformation.
	var bind := clampf(1.0 - form * 2.5, 0.0, 1.0)
	if bind > 0.0:
		var knot: Color = tint.call(Art.ec("racine", "sombre").lerp(Art.c("ennemi"), 0.3))
		for j in 2:
			var y0 := ry * (-0.25 + 0.6 * j)
			var pts := PackedVector2Array()
			for q in 11:
				var u := q / 10.0 * 2.0 - 1.0
				var x := u * rx * sqrt(maxf(1.0 - pow(y0 / ry, 2.0), 0.05)) * 1.04
				pts.append(h + Vector2(x + signf(u) * gap * 2.0, y0 + ry * 0.12 * u * (1 if j == 0 else -1) + 4.0 * sin(u * 5.0 + j) + r * 0.4 * form * absf(u)))
			ci.draw_polyline(pts, Color(knot.darkened(0.3), bind), 11.0, true)
			ci.draw_polyline(pts, Color(knot, bind), 7.0, true)
			for q in [2, 5, 8]:
				ci.draw_circle(pts[q], 6.5, Color(knot.lightened(0.08), bind))
	for heart in halves:
		Art.outline(ci, heart, Color(Art.c("ennemi_contour"), 1.0 - die * 0.8), Art.TRAIT_FORT)
	if form > 0.0:
		_draw_eye(ci, h + Vector2(0, -ry * 0.3 * (1.0 - form)), r * (1.0 + 0.3 * form), t, phase, k, die, wake)
	else:
		_draw_eye(ci, h + Vector2(0, -ry * 0.3), r, t, phase, k, die, wake)
	# La cendre qui monte autour d'elle ; des braises parmi, de plus en plus, à chaque phase.
	if die < 1.0:
		for i in 18:
			var f := fposmod(t * (0.18 + 0.04 * (i % 4) + 0.12 * form) + i * 0.137, 1.0)
			var x := sin(i * 12.9898) * r * 1.5 + sin(t + i) * r * 0.08
			var q := c + Vector2(x, r * 0.2 - f * r * 2.6)
			var hot := (i % 4 < phase - 1 or form > 0.0) and die <= 0.0
			var col := ash.lightened(0.15) if not hot else Art.ec("cendre", "clair")
			ci.draw_circle(q, r * (0.022 + 0.018 * (i % 3)), Color(col, 0.55 * sin(PI * f) * (1.0 - die) * (0.4 + 0.6 * wake)))
	# Mort : des gouttes de sève montent des fentes et pâlissent.
	if die > 0.0:
		for i in 16:
			var a := TAU * i / 16.0 + 0.2
			var u := clampf(die * 1.4 - (i % 3) * 0.12, 0.0, 1.0)
			if u <= 0.0 or u >= 1.0:
				continue
			var q := h + Vector2.from_angle(a) * r * (0.3 + 1.0 * u) - Vector2(0, r * 0.8 * u)
			ci.draw_circle(q, r * (0.04 + 0.07 * u), Color(Art.ec("seve", "clair"), 0.75 * (1.0 - u)))
		ci.draw_circle(h, r * 0.55 * die, Color(ash, 0.25 * die))
	if form > 0.0:
		_draw_shards(ci, h, r, t, form, lit, lit2, k, die, true)


## Une moitié du cœur ouvert (side : -1 gauche, 1 droite), un peu penchée vers l'extérieur.
static func _half_ellipse(h: Vector2, rx: float, ry: float, side: int, form: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var tilt := 0.12 * form * side
	for q in 17:
		var a := -PI / 2.0 + PI * q / 16.0
		var p := Vector2(cos(a) * rx * side, sin(a) * ry)
		# Le bord intérieur est déchiqueté (la graine s'est fendue).
		if q == 0 or q == 16:
			p.x = 0.0
		pts.append(h + p.rotated(tilt))
	for q in 5:
		var v := 1.0 - (q + 1) / 6.0 * 2.0
		pts.append(h + Vector2(side * rx * (0.06 + 0.08 * (q % 2)), v * ry * 0.95).rotated(tilt))
	return pts


## Le noyau de braise entre les deux moitiés du cœur ouvert : une lueur qui bat, des veines des six
## couleurs qui y convergent.
static func _draw_core(ci: CanvasItem, h: Vector2, r: float, t: float, form: float, die: float, glow: float) -> void:
	var hot := Art.ec("cendre", "clair")
	var fade := form * (1.0 - die)
	var pulse := 0.75 + 0.25 * sin(t * 6.0)
	ci.draw_colored_polygon(Art.ellipse(h, r * 0.62 * form, r * 0.95, 24), Color(Art.ec("cendre", "sombre").darkened(0.3), fade))
	ci.draw_colored_polygon(Art.ellipse(h, r * 0.48 * form, r * 0.82, 24), Color(Art.ec("cendre"), 0.85 * fade * pulse))
	ci.draw_colored_polygon(Art.ellipse(h, r * 0.3 * form, r * 0.6, 20), Color(hot, 0.9 * fade * glow))
	for i in ARMS.size():
		var a := TAU * (i + 0.5) / ARMS.size() - PI / 2.0
		var from := h + Vector2(cos(a) * r * 0.45 * form, sin(a) * r * 0.8)
		var col := Art.ec(str(ARMS[i]["element"]), "clair")
		ci.draw_line(from, h.lerp(from, 0.25), Color(col, 0.8 * fade * pulse), 3.0, true)


## Les six éclats des gardiens, en orbite autour d'elle (vue de dessus, aplatie) : ceux de derrière
## (front faux) avant le corps, ceux de devant après. L'éclat d'un bras allumé brille.
static func _draw_shards(ci: CanvasItem, h: Vector2, r: float, t: float, form: float, lit: int, lit2: int, k: float, die: float, front: bool) -> void:
	var fade := form * (1.0 - die)
	if fade <= 0.0:
		return
	for i in ARMS.size():
		var a := t * SHARDS["speed"] + TAU * i / ARMS.size()
		if (sin(a) > 0.0) != front:
			continue
		var orbit: float = r * SHARDS["orbit"] * (0.5 + 0.5 * form)
		var p := h + Vector2(cos(a) * orbit, sin(a) * orbit * 0.42 - r * 0.15)
		var element := str(ARMS[i]["element"])
		var on := k if (i == lit or i == lit2) else 0.0
		var s := r * (0.15 + 0.03 * sin(t * 3.0 + i)) * (1.0 + 0.4 * on)
		ci.draw_circle(p, s * (2.0 + on), Color(Art.ec(element, "clair"), (0.14 + 0.3 * on) * fade))
		var gem := PackedVector2Array([p + Vector2(0, -s * 1.6), p + Vector2(s * 0.75, 0), p + Vector2(0, s * 1.1), p + Vector2(-s * 0.75, 0)])
		Art.volume(ci, gem, Color(Art.ec(element), fade), 1.0)
		Art.outline(ci, gem, Color(Art.ec(element, "sombre"), fade), Art.TRAIT_FIN)
		ci.draw_line(p + Vector2(0, -s * 1.2), p + Vector2(0, s * 0.6), Color(Art.ec(element, "clair"), 0.8 * fade), 1.5, true)


## L'œil : une fente de braise verticale au milieu du cœur, deux petits yeux de part et d'autre.
## Fermé (un trait) quand elle dort ; il s'ouvre grand pendant l'annonce.
static func _draw_eye(ci: CanvasItem, e: Vector2, r: float, t: float, phase: int, k: float, die: float, wake: float) -> void:
	var eye_col := Art.c("ennemi_oeil")
	var open := wake * (1.0 - die) * (0.55 + 0.1 * phase + 0.35 * k)
	var w := r * 0.36
	if open <= 0.05:
		ci.draw_line(e + Vector2(-w * 0.8, 0), e + Vector2(w * 0.8, 0), Color(Art.ec("cendre"), 0.5 + 0.3 * sin(t * 2.0)), 3.0, true)
		return
	ci.draw_circle(e, w * (1.1 + 0.4 * k), Color(eye_col, 0.16 * open))
	var hgt := r * 0.24 * open
	var lid := PackedVector2Array()
	for q in 13:
		var a := TAU * q / 12.0
		lid.append(e + Vector2(cos(a) * w, sin(a) * hgt * (1.0 - 0.35 * absf(cos(a)))))
	ci.draw_colored_polygon(lid, Color("1a0d0d"))
	ci.draw_circle(e, minf(hgt, w) * 0.85, eye_col)
	ci.draw_circle(e, minf(hgt, w) * 0.5, eye_col.lightened(0.35))
	# Pupille : une fente noire, qui s'amincit pendant l'annonce.
	var pw := r * (0.05 - 0.025 * k)
	ci.draw_colored_polygon(PackedVector2Array([e + Vector2(0, -hgt * 0.95), e + Vector2(pw, 0), e + Vector2(0, hgt * 0.95), e + Vector2(-pw, 0)]), Color("0b0606"))
	Art.outline(ci, lid, Color(Art.c("ennemi_contour"), 0.8), Art.TRAIT_FIN)
	for sgn in [-1, 1]:
		var s := e + Vector2(sgn * r * 0.5, -r * 0.2)
		ci.draw_circle(s, r * 0.075, Color(eye_col, 0.25 * open))
		ci.draw_circle(s, r * (0.035 + 0.015 * k), Color(eye_col.lightened(0.2), open))


## La couronne de bois mort au-dessus du cœur : cinq branches fourchues, braises au bout dès la phase 2.
## gone : seconde forme (0 → 1) : les branches basculent vers l'extérieur et tombent en cendre.
static func _draw_crown(ci: CanvasItem, h: Vector2, r: float, t: float, phase: int, die: float, wake: float, tint: Callable, gone := 0.0) -> void:
	var wood: Color = tint.call(Art.ec("racine", "sombre").lerp(Art.c("ennemi"), 0.2).darkened(0.35))
	var rise := 0.65 + 0.35 * wake
	var keep := (1.0 - die * 0.6) * (1.0 - gone)
	for i in 5:
		var u := (i - 2) / 2.0
		var a := -PI / 2.0 + u * 0.75 + 0.03 * sin(t * 0.7 + i) + gone * (1.1 if u >= 0.0 else -1.1) * (0.4 + absf(u))
		var from := h + Vector2(u * r * (0.45 + 0.6 * gone), -r * 0.7 + r * 0.8 * gone * gone)
		var length := r * (1.35 - 0.3 * absf(u)) * rise * (1.0 - 0.4 * die)
		var path := _wiggle(from, a, length, r * 0.12, i * 2.3)
		_limb(ci, path, r * 0.11, r * 0.02, Color(wood, keep), Color(Art.c("ennemi_contour"), 0.4 * (1.0 - die) * (1.0 - gone)), 0.5)
		for sgn in [-1, 1]:
			var at := path[2 if sgn < 0 else 3]
			var tw := _wiggle(at, a + sgn * 0.7, length * 0.42, r * 0.05, i + sgn)
			_limb(ci, tw, r * 0.05, r * 0.012, Color(wood, keep))
			if phase >= 2 and die <= 0.0 and gone <= 0.0:
				ci.draw_circle(tw[tw.size() - 1], r * 0.045, Color(Art.ec("cendre", "clair"), 0.5 + 0.4 * sin(t * 4.0 + i + sgn)))
		if phase >= 3 and die <= 0.0 and gone <= 0.0:
			Art.glow(ci, path[path.size() - 1], r * 0.18, "cendre")


## Angle d'un bras (vu de dessus, les six en étoile, un peu de balancement ; repliés en dormant).
static func _arm_angle_at(i: int, t: float, wake: float) -> float:
	return -PI / 2.0 + TAU * (i + 0.5) / ARMS.size() + (0.06 * sin(t * 1.3 + i * 1.7)) * wake


## Un bras : une longue racine courbe, nouée, épineuse, veinée de son élément, et le motif de
## l'élément au bout. Endormi, gris de cendre et replié ; lit : allumage pendant l'annonce (0 → 1).
## form : seconde forme (0 → 1) : le bras s'allonge et se tord davantage.
static func _draw_arm(ci: CanvasItem, h: Vector2, ang: float, r: float, element: String, awake: bool, lit: float, die: float, wake: float, t: float, tint: Callable, form := 0.0) -> void:
	var dir := Vector2.from_angle(ang)
	var side := dir.orthogonal()
	var stretch := lerpf(1.7, 2.6 if awake else 2.0, wake) * (1.0 - 0.4 * die) * (1.0 + 0.18 * form)
	var bend := r * (0.55 - 0.3 * wake + (0.12 + 0.12 * form) * sin(t * (0.9 + 0.8 * form))) * (1.0 + die)
	var from := h + dir * r * 0.6
	var tip := h + dir * r * stretch + side * bend * 0.35
	var ctrl := h + dir * r * stretch * 0.6 + side * bend
	var path := PackedVector2Array()
	for q in 13:
		var u := q / 12.0
		path.append(from.lerp(ctrl, u).lerp(ctrl.lerp(tip, u), u))
	var bark: Color = tint.call(Art.ec("racine", "sombre").lerp(Art.c("ennemi"), 0.35))
	var col := Art.ec(element) if awake else FletriArt.ash_color().lerp(Art.c("brume"), 0.4)
	if die > 0.0:
		col = col.lerp(FletriArt.ash_color(), die)
	_limb(ci, path, r * 0.27, r * 0.06, bark, Color(Art.c("ennemi_contour"), 0.5 * (1.0 - die)), 1.0)
	# Nœuds d'écorce, et des épines le long du bras.
	for f in [0.28, 0.52, 0.74]:
		var i := int(f * 12.0)
		var d := (path[i + 1] - path[i - 1]).normalized()
		var o := d.orthogonal()
		var w := lerpf(r * 0.27, r * 0.06, f) * 1.12
		ci.draw_line(path[i] - o * w, path[i] + o * w, bark.darkened(0.35), 4.0, true)
	for q in [2, 4, 6, 8, 10]:
		var d := (path[q + 1] - path[q - 1]).normalized()
		var o := d.orthogonal() * (1.0 if q % 4 == 2 else -1.0)
		var w := lerpf(r * 0.27, r * 0.06, q / 12.0)
		var b := path[q] + o * w * 0.85
		ci.draw_colored_polygon(PackedVector2Array([b - d * r * 0.05, b + (o + d * 0.7).normalized() * r * 0.14, b + d * r * 0.05]), bark.darkened(0.2))
	# La veine de l'élément, et sa sève qui monte vers le bout.
	if awake:
		var vein := path.slice(1, 12)
		ci.draw_polyline(vein, Color(col, 0.2 + 0.2 * lit), 7.0 + 5.0 * lit, true)
		ci.draw_polyline(vein, Color(col.lightened(0.15), 0.6 + 0.4 * lit), 2.0 + 2.0 * lit, true)
		var f := fposmod(t * 0.7, 1.0)
		var q := path[1 + int(f * 10.0)].lerp(path[2 + int(f * 10.0)], fposmod(f * 10.0, 1.0))
		ci.draw_circle(q, r * 0.05, Color(Art.ec(element, "clair"), 0.8 * sin(PI * f)))
	if lit > 0.0:
		ci.draw_circle(tip, r * (0.4 + 0.3 * lit), Color(Art.ec(element, "clair"), 0.22 * lit))
	_draw_motif(ci, tip, dir, r * 0.42 * (1.0 + 0.25 * lit), element, col, awake, lit, t)


## Le motif d'un élément au bout d'un bras, tourné vers l'extérieur (dir).
static func _draw_motif(ci: CanvasItem, tip: Vector2, dir: Vector2, s: float, element: String, col: Color, awake: bool, lit: float, t: float) -> void:
	var side := dir.orthogonal()
	var ang := dir.angle()
	var dark := col.darkened(0.45)
	var light := Art.ec(element, "clair") if awake else col.lightened(0.15)
	match element:
		"epine":
			# Une couronne de cinq épines, la plus longue au milieu.
			ci.draw_circle(tip, s * 0.32, dark)
			for j in 5:
				var d := Vector2.from_angle(ang + (j - 2) * 0.42)
				var l := s * (1.6 - 0.25 * absi(j - 2))
				var thorn := PackedVector2Array([tip + d.orthogonal() * s * 0.2, tip + d * l, tip - d.orthogonal() * s * 0.2])
				ci.draw_colored_polygon(thorn, col)
				ci.draw_line(tip, tip + d * l * 0.8, Color(light, 0.6), 1.5, true)
		"poison":
			# Une grappe de trois champignons, chapeaux piqués de points clairs.
			for j in 3:
				var off := side * s * (j - 1) * 0.75 + dir * s * (0.5 - 0.35 * absi(j - 1))
				var size := s * (0.95 - 0.3 * absi(j - 1))
				var base := tip + off
				ci.draw_line(tip, base, dark, 4.0, true)
				var cap := PackedVector2Array()
				for q in 11:
					cap.append(base + Vector2.from_angle(ang - PI / 2.0 + PI * q / 10.0) * size)
				Art.volume(ci, cap, col, 0.6 if awake else 0.0)
				Art.outline(ci, cap, dark, Art.TRAIT_FIN)
				if awake:
					for q in 3:
						ci.draw_circle(base + dir * size * 0.5 + side * size * (q - 1) * 0.42, size * 0.12, light)
			if awake:
				for q in 4:
					var f := fposmod(t * 0.5 + q * 0.25, 1.0)
					ci.draw_circle(tip + dir * s * (1.2 + f) + side * s * sin(q * 2.0) * 0.6, s * 0.1, Color(light, 0.6 * (1.0 - f)))
		"seve":
			# Un bulbe de sève, lourd, qui goutte.
			ci.draw_colored_polygon(PackedVector2Array([tip - dir * s * 0.9, tip + side * s * 0.6, tip + dir * s * 0.8, tip - side * s * 0.6]), dark)
			Art.volume_circle(ci, tip + dir * s * 0.35, s * 0.8, col, 0.8 if awake else 0.0)
			if awake:
				ci.draw_circle(tip + dir * s * 0.15 - side * s * 0.3, s * 0.22, light)
				var f := fposmod(t * 0.8, 1.0)
				ci.draw_circle(tip + dir * s * (1.2 + 0.8 * f), s * 0.16 * (1.0 - 0.4 * f), Color(col, 1.0 - f))
		"vent":
			# Un éventail de trois plumes.
			for j in 3:
				var d := Vector2.from_angle(ang + (j - 1) * 0.45)
				var end := tip + d * s * (1.7 - 0.25 * absi(j - 1))
				var o := d.orthogonal()
				ci.draw_line(tip - d * s * 0.2, end, dark, 2.5, true)
				for q in 5:
					var p := tip.lerp(end, 0.2 + q * 0.17)
					var l := s * 0.45 * (1.0 - q * 0.12)
					ci.draw_line(p, p + (o + d * 0.7).normalized() * l, col, 2.5, true)
					ci.draw_line(p, p + (-o + d * 0.7).normalized() * l, col, 2.5, true)
		"lumiere":
			# Une grappe de cristaux, des rayons pendant l'annonce.
			for j in 3:
				var d := Vector2.from_angle(ang + (j - 1) * 0.5)
				var o := d.orthogonal()
				var l := s * (1.5 - 0.35 * absi(j - 1))
				var gem := PackedVector2Array([tip - d * s * 0.2, tip + d * l * 0.45 + o * s * 0.32, tip + d * l, tip + d * l * 0.45 - o * s * 0.32])
				Art.volume(ci, gem, col, 1.0 if awake else 0.0)
				Art.outline(ci, gem, dark, Art.TRAIT_FIN)
				if awake:
					ci.draw_line(tip + d * l * 0.2, tip + d * l * 0.8, Color(light, 0.7), 1.5, true)
			if lit > 0.0:
				for j in 6:
					var d := Vector2.from_angle(ang + (j - 2.5) * 0.4)
					ci.draw_line(tip + d * s * 1.4, tip + d * s * (2.0 + lit), Color(light, lit), 2.0, true)
		"racine":
			# Une griffe de quatre crochets.
			ci.draw_circle(tip, s * 0.3, dark)
			for j in 4:
				var a := ang + (j - 1.5) * 0.45
				var d := Vector2.from_angle(a)
				var q1 := tip + d * s * 1.1
				var hook := q1 + d.orthogonal() * s * 0.45 * (1.0 if j >= 2 else -1.0) - d * s * 0.15
				ci.draw_polyline(PackedVector2Array([tip, q1, hook]), dark, 7.0, true)
				ci.draw_polyline(PackedVector2Array([tip, q1, hook]), col, 4.0, true)


## Un chemin ondulé de « length » dans la direction « a », depuis « from » (sept points).
static func _wiggle(from: Vector2, a: float, length: float, amp: float, salt: float) -> PackedVector2Array:
	var d := Vector2.from_angle(a)
	var o := d.orthogonal()
	var out := PackedVector2Array()
	for q in 7:
		var u := q / 6.0
		out.append(from + d * length * u + o * amp * sin(u * 5.0 + salt) * u)
	return out


## Un membre effilé le long d'un chemin (racine, bras, branche), dessiné quad par quad : pas de
## triangulation, donc rien ne casse quand il se tord. edge : contour (transparent : aucun) ;
## light : reflet clair du côté de la lumière (en haut à gauche, comme Art.volume).
static func _limb(ci: CanvasItem, path: PackedVector2Array, w0: float, w1: float, col: Color, edge := Color(0, 0, 0, 0), light := 0.0) -> void:
	var n := path.size()
	var poly := _taper(path, w0, w1)
	var dark := Color(col.darkened(0.38), col.a)
	for i in n - 1:
		var quad := PackedVector2Array([poly[i], poly[i + 1], poly[2 * n - 2 - i], poly[2 * n - 1 - i]])
		ci.draw_primitive(quad, PackedColorArray([col, col, dark, dark]), PackedVector2Array())
	if light > 0.0:
		var shine := PackedVector2Array()
		for i in n - 1:
			shine.append(poly[i].lerp(path[i], 0.45))
		ci.draw_polyline(shine, Color(col.lightened(0.3), 0.45 * light * col.a), maxf(w0 * 0.35, 1.5), true)
	if edge.a > 0.0:
		ci.draw_polyline(poly.slice(0, n), edge, Art.TRAIT_FIN, true)
		ci.draw_polyline(poly.slice(n), edge, Art.TRAIT_FIN, true)


## Polygone effilé le long d'un chemin : demi-largeur w0 à la base, w1 au bout.
static func _taper(path: PackedVector2Array, w0: float, w1: float) -> PackedVector2Array:
	var n := path.size()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var d := path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]
		var o := d.normalized().orthogonal()
		var w := lerpf(w0, maxf(w1, 0.5), float(i) / float(n - 1))
		left.append(path[i] + o * w)
		right.append(path[i] - o * w)
	right.reverse()
	left.append_array(right)
	return left


## Annonces au sol, en coordonnées monde (grammaire de Art.telegraph). Les rejetons, qui ne
## blessent pas, ne sont pas en rouge ; les nuages de spores posés gardent leur couleur.
func draw_marks(c: CanvasItem) -> void:
	var k := _announce_k()
	draw_floor(c, anchor, radius, t, phase, clampf(dying / death_time, 0.0, 1.0) if dead else 0.0, form_k())
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
		# Floraison (seconde forme) : le nuage boit, un filet de sève remonte jusqu'à elle.
		if cl.get("drain", false):
			var sap := Art.ec("seve", "clair")
			c.draw_circle(pos, SPORES["radius"] * 0.4, Color(Art.ec("seve"), 0.22 * fade))
			for j in 4:
				var f := fposmod(t * 0.9 + j * 0.25, 1.0)
				c.draw_circle(pos.lerp(anchor, f), 3.5 * (1.0 - 0.5 * f), Color(sap, 0.75 * sin(PI * f) * fade))
	_draw_waves(c)
	match attack:
		"epines", "tempete":
			if stage == "annonce":
				var n: int = PHASES[phase]["thorns"]
				var widen: float = STORM["spread"] if attack == "tempete" else 1.0
				Art.telegraph(c, {"type": "cone", "centre": anchor, "direction": aim.angle(), "ouverture": THORNS["spread"] * n * widen, "rayon": 380.0}, k, -1.0, t)
				if attack == "tempete":
					Art.telegraph(c, {"type": "ligne", "de": anchor, "a": anchor + aim * gust_len, "largeur": GUST["width"]}, k, -1.0, t)
		"spores", "floraison":
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
		"lumiere", "aurore":
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
			var total: float = r.get("total", ROOTS["annonce"] + ROOTS["step"] * roots.find(r))
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


## Ondes de choc : avant de partir, l'anneau se ramasse autour d'elle et les brèches s'éclairent
## en couloirs jusqu'au mur ; puis un anneau de cendre bordé de rouge (danger) court vers le mur.
func _draw_waves(c: CanvasItem) -> void:
	if waves.is_empty():
		return
	var danger := Art.c("danger")
	var ash := FletriArt.ash_color()
	var pale := Art.ec("cendre", "clair")
	var half: float = WAVE["gap"] * 0.5
	for wv in waves:
		var gaps: Array = wv["gaps"].duplicate()
		gaps.sort()
		var fuse: float = wv["fuse"]
		var k := 1.0 - clampf(fuse / float(wv["total"]), 0.0, 1.0) if fuse > 0.0 else 1.0
		var r: float = wv["r"] if fuse <= 0.0 else radius * (0.9 + 1.6 * (1.0 - k))
		var w: float = WAVE["width"] * (0.35 + 0.65 * k) if fuse > 0.0 else WAVE["width"]
		var fade := 1.0
		if fuse <= 0.0:
			fade = clampf((arena.radius + WAVE["width"] - r) / 80.0, 0.0, 1.0)
		# Couloirs des brèches : lumière pâle, jusqu'au mur.
		for g in gaps:
			var dir := Vector2.from_angle(float(g))
			var from := maxf(r, radius) if fuse <= 0.0 else radius
			c.draw_line(anchor + dir * from, anchor + dir * arena.radius, Color(pale, (0.10 + 0.12 * k) * fade), w * 1.6, true)
		for i in gaps.size():
			var a0: float = float(gaps[i]) + half
			var a1: float = float(gaps[(i + 1) % gaps.size()]) - half
			if a1 <= a0:
				a1 += TAU
			var segs := maxi(6, int((a1 - a0) * 18.0))
			if fuse > 0.0:
				c.draw_arc(anchor, r, a0, a1, segs, Color(danger, 0.25 + 0.55 * k), Art.TRAIT * (1.0 + k), true)
			else:
				c.draw_arc(anchor, r, a0, a1, segs, Color(ash, 0.85 * fade), w, true)
				c.draw_arc(anchor, r - w * 0.5, a0, a1, segs, Color(danger, 0.9 * fade), Art.TRAIT, true)
				c.draw_arc(anchor, r + w * 0.5, a0, a1, segs, Color(danger, 0.9 * fade), Art.TRAIT, true)
				c.draw_arc(anchor, r, a0, a1, segs, Color(pale, 0.45 * fade), w * 0.25, true)
				# Éclats de cendre aux bords des brèches.
				for e in [a0, a1]:
					var tip := anchor + Vector2.from_angle(e) * r
					c.draw_circle(tip, w * 0.45, Color(danger, 0.8 * fade))


## Épines en vol, au-dessus des personnages, en coordonnées monde.
func draw_overlay(c: CanvasItem) -> void:
	var col := Art.ec("epine")
	var roll_col := Art.ec("epine", "clair")
	for s in thorns:
		var p: Vector2 = s["pos"]
		var d: Vector2 = s["vel"].normalized()
		var o := d.orthogonal() * THORNS["radius"] * 0.55
		var tri := PackedVector2Array([p + d * THORNS["radius"] * 1.6, p + o - d * THORNS["radius"], p - o - d * THORNS["radius"]])
		c.draw_colored_polygon(tri, roll_col if s.get("roll", false) else col)
		Art.outline(c, tri, Art.c("contour"), Art.TRAIT_FIN)


## La Flétrissure endormie : la même, repliée, l'œil clos ; ses racines déjà dans le sol.
static func draw_sleeper(a: Node2D) -> void:
	var c: Vector2 = a.center
	var r := BODY_RADIUS
	draw_floor(a, c, r, a.t, 1)
	draw_colossus(a, c, r, a.t, 0, 0.0, -1, 0.0, 0.0, func(col): return col)
	if a.state == "ouverte":
		var pulse := 0.45 + 0.35 * sin(a.t * 2.0)
		Art.glow(a, c + Vector2(0, -r * 0.6), r * 0.35 * pulse, "cendre")


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


## Le retour de la batterie : elle se dresse d'un coup, une onde dans les couleurs des bras éveillés.
func _music_resume() -> void:
	super._music_resume()
	for i in mini(ARMS.size(), phase * 2):
		main.fx.ring(anchor, radius * 0.8, 260.0 + 70.0 * i, 0.5 + 0.08 * i, Color(Art.ec(ARMS[i]["element"], "clair"), 0.8), 5.0)
	main.screen_fx.glow(Art.ec("cendre"), 0.5, 0.8)
