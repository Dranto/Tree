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
## roulements d'épines sur les caisses claires du morceau, ses étincelles sur les charlestons et
## ses piqûres de racines sur les caisses douces, jusqu'au déluge du sommet de la phase 3.
## Elle bat la mesure de tout son corps. Sans morceau, elle reprend l'ordre de PHASES.
##
## Le socle (vie, phases, états, mort, interface d'ennemi) est dans boss_base.gd.
extends BossBase

const FinaleArt = preload("res://scripts/boss_art/finale.gd")
const Choreo = preload("res://scripts/boss_art/finale_choreo.gd")
const LiveBake = preload("res://scripts/boss_art/live_bake.gd")
const TINT_SHADER = preload("res://shaders/sprite_tint.gdshader")

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
#   - ondes    : une grosse caisse franche (sur les mesures à ondes) lance une onde de choc de cendre,
#                un anneau qui s'élargit d'elle jusqu'au mur, percé de brèches (s'y glisser, ou
#                esquiver au travers) ; une onde sur deux s'ouvre devant le joueur, l'autre à côté ;
#   - pouls    : les autres grosses caisses, et les douces, lancent une onde courte et fine ;
#   - roulements : chaque caisse claire tire des épines en spirale ;
#   - etincelles : chaque charleston tire de petites braises, de jets qui tournent autour d'elle
#                comme un arroseur ;
#   - piqures  : chaque caisse claire douce (note fantôme) fait poindre de petites racines autour du
#                joueur, annoncées deux temps avant ;
#   - deluge   : au sommet de la phase 3 (« deluge » dans la phrase), toutes les grosses caisses
#                lancent des ondes et les roulements partent de ses six bras.
# Aucune percussion relevée ne reste sans attaque, et chaque phase frappe plus (POWER : mesures à
# ondes, bras, jets, piqûres par coup, portée des pouls ; plus de coups et d'attaques combinées par
# phrase). Les mesures sont comptées dans la phrase (0-3). Sans morceau, enracinée (cadence ralentie) ou hors
# grille, elle revient à l'ordre de PHASES. Les phrases d'une phase se répètent si sa boucle est
# plus longue que la liste.
const SCORE := {
	1: {"loop": "boucle_1", "phrases": [
		{"coups": [[0, "epines"], [5, "spores"], [9, "epines"], [13, "spores"]]},
		{"coups": [[0, "epines"], [6, "spores"], [11, "epines"]], "ondes": [0, 2]},
	]},
	2: {"loop": "boucle_2", "phrases": [
		{"coups": [[0, "rafale"], [4, "spores"], [8, "epines"], [13, "rafale"]]},
		{"coups": [[0, "siphon"], [8, "rafale"], [11, "spores"], [14, "rejetons"]]},
		{"coups": [[0, "rafale"], [3, "spores"], [7, "epines"], [11, "spores"], [13, "rafale"]], "ondes": [0, 1, 2, 3]},
	]},
	3: {"loop": "boucle_3", "phrases": [
		{"coups": [[0, "tempete"], [4, "floraison"], [7, "aurore"], [11, "floraison"], [14, "lumiere"]]},
		{"coups": [[0, "aurore"], [5, "tempete"], [9, "floraison"], [12, "lumiere"], [14, "spores"]]},
		{"coups": [[0, "floraison"], [3, "tempete"], [7, "aurore"], [11, "floraison"], [14, "lumiere"]]},
		{"coups": [[0, "tempete"], [4, "racines"], [8, "floraison"], [11, "lumiere"], [14, "rejetons"]]},
		{"coups": [[0, "tempete"], [4, "floraison"], [7, "aurore"], [11, "floraison"], [14, "lumiere"]]},
		{"coups": [[0, "aurore"], [5, "tempete"], [9, "floraison"], [12, "lumiere"], [14, "spores"]]},
		{"coups": [[0, "tempete"], [4, "floraison"], [7, "aurore"], [11, "floraison"], [14, "lumiere"]], "deluge": true},
		{"coups": [[0, "tempete"], [4, "racines"], [8, "floraison"], [11, "lumiere"], [14, "rejetons"]], "deluge": true},
		{"coups": [[0, "lumiere"], [4, "spores"], [8, "aurore"], [13, "lumiere"]]},
		{"coups": [[0, "siphon"], [8, "tempete"], [12, "aurore"], [14, "spores"]]},
	]},
}
## Toute la batterie frappe, et plus fort à chaque phase. Pour chaque coup relevé dans le morceau :
## grosse caisse franche → onde de choc sur les mesures « ondes » (de la phase, ou de la phrase),
## pouls (petite onde courte) ailleurs ; grosse caisse douce → pouls ; caisse claire → roulement ;
## charleston → étincelles ; caisse douce → piqûres. Par phase : mesures à ondes, bras des
## roulements, jets d'étincelles, piqûres par coup, portée des pouls.
const POWER := {
	1: {"ondes": [0], "roll": 2, "spark": 1, "prick": 1, "pulse": 200.0},
	2: {"ondes": [0, 2], "roll": 3, "spark": 2, "prick": 2, "pulse": 260.0},
	3: {"ondes": [0, 1, 2, 3], "roll": 4, "spark": 3, "prick": 3, "pulse": 320.0},
}
## Annonce (en temps) de chaque attaque de la partition, et la plus courte admise.
const ANNOUNCE_BEATS := {"epines": 3, "spores": 3, "siphon": 3, "rafale": 3, "tempete": 4, "lumiere": 3, "aurore": 3, "floraison": 3, "racines": 2, "rejetons": 3}
## Sur la partition, elle frappe plus souvent qu'au gré des pauses : chaque coup blesse moins.
const SCORE_DAMAGE := 0.6
const MIN_ANNOUNCE := 2.0  # (1,75 admis : la fin d’une attaque tombe à une image près)
## Coups de batterie quand le morceau n'en donne pas (une phrase de quatre mesures, doubles croches).
const DRUMS := {"kick": [[0], [2, 8, 14], [0, 6, 12], []], "kick_doux": [[6], [], [], [4]], "caisse": [[], [2, 6], [0, 10], [6, 8, 10, 12]],
	"charleston": [[0, 4, 8, 12], [2, 6, 10, 14], [0, 4, 8, 12], [0, 2, 4, 6, 8, 10, 12, 14]], "caisse_douce": [[4, 12], [0, 12], [6], [0, 4, 14]]}
## Pouls (grosses caisses douces, et franches hors des mesures à ondes) : une onde courte et fine,
## annoncée un temps avant, qui s'éteint à POWER › pulse px d'elle.
const PULSE := {"lead": 1.0, "width": 16.0, "damage": 3.0}
## Étincelles (charlestons) : pas du jet entre deux braises (radians), vitesse, rayon, dégâts (part de
## THORNS) ; le nombre de jets vient de POWER.
const SPARK := {"step": 0.42, "speed": 250.0, "radius": 5.0, "damage": 0.15}
## Piqûres (caisses douces) : annonce (temps), rayon, dégâts, distance au joueur (de près à loin :
## elles l'encerclent, rester en place les évite, filer au travers non), au plus à la fois.
const PRICK := {"lead": 2.0, "radius": 30.0, "damage": 4.0, "near": 48.0, "far": 95.0, "max": 14}
## Onde de choc : annonce (temps : elle se ramasse avant de partir), vitesse, épaisseur, brèches
## (nombre et ouverture en radians), pas de côté demandé une onde sur deux (radians au-delà du bord
## de la brèche), dégâts, ondes au plus en vol.
const WAVE := {"lead": 2.0, "speed": 500.0, "width": 26.0, "gaps": 4, "gap": 0.9, "step": 0.3, "damage": 6.0, "max": 10}
## Roulement : bras qui tirent au déluge (sinon POWER › roll), pas de la spirale (radians par
## coup), vitesse et dégâts des épines (part de THORNS).
const ROLL := {"arms_deluge": 6, "spin": 0.55, "speed": 300.0, "damage": 0.8}

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
## Piqûres : {"pos", "fuse", "total", "burst"} ; angle du jet d'étincelles ; tirage des piqûres.
var pricks: Array = []
var _spark_angle := 0.0
var _prick_rng := RandomNumberGenerator.new()
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
	_update_pricks(delta)
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
	if on_music_grid():
		amount *= SCORE_DAMAGE
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
		var pw: Dictionary = POWER[phase]
		var flood: bool = ph.get("deluge", false)
		var wave_bars: Array = ph.get("ondes", pw["ondes"])
		for m in 4:
			var bar_i: int = i * 4 + m
			if bar_i >= bars:
				continue
			for src in ["kick", "kick_doux", "caisse", "charleston", "caisse_douce"]:
				var hits: Array = drums[src][bar_i] if drums.has(src) and bar_i < drums[src].size() else DRUMS[src][m]
				var kind := ""
				match src:
					"kick":
						kind = "onde" if (flood or m in wave_bars) else "pouls"
					"kick_doux":
						kind = "pouls"
					"caisse":
						kind = "roulement"
					"charleston":
						kind = "etincelle"
					"caisse_douce":
						kind = "piqure"
				for six in hits:
					score_drums.append({"beat": float(bar_i * bb) + float(six) / 4.0, "kind": kind, "deluge": flood, "phrase": i})
	score_drums.sort_custom(func(a, b): return a["beat"] < b["beat"])
	_score_last = beats_now()
	# Le premier coup de la boucle (l'entrée de la batterie) part tout de suite, sans s'annoncer.
	_drums_done = beats_now() - WAVE["lead"] - 0.01


## Charge de la partition de la phase, en projectiles et coups par temps : ce qui doit monter à
## chaque phase (tests). Une attaque combinée compte double, une onde trois fois un pouls.
func score_weight() -> float:
	var pw: Dictionary = POWER[phase]
	var w := 0.0
	for h in score_hits:
		w += 8.0 if COMBO_ARMS.has(h["kind"]) else 4.0
	for d in score_drums:
		match d["kind"]:
			"onde":
				w += 3.0
			"pouls":
				w += 1.0
			"roulement":
				w += float(ROLL["arms_deluge"] if d["deluge"] else pw["roll"])
			"etincelle":
				w += 3.0 if d["deluge"] else float(pw["spark"])
			"piqure":
				w += float(pw["prick"])
	return w / maxf(1.0, score_len)


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
			var lead := 0.0
			match d["kind"]:
				"onde":
					lead = WAVE["lead"]
				"pouls":
					lead = PULSE["lead"]
				"piqure":
					lead = PRICK["lead"]
			var start: float = at - lead
			if start <= _drums_done or start > now:
				continue
			match d["kind"]:
				"onde":
					_launch_wave((at - now) * beat_len(), d.get("deluge", false))
				"pouls":
					_launch_wave((at - now) * beat_len(), false, true)
				"roulement":
					_roll(ROLL["arms_deluge"] if d.get("deluge", false) else int(POWER[phase]["roll"]))
				"etincelle":
					_spark(3 if d.get("deluge", false) else int(POWER[phase]["spark"]))
				"piqure":
					_prick((at - now) * beat_len(), int(POWER[phase]["prick"]))
	_drums_done = now


## Une onde de choc qui partira dans « fuse » secondes, sur le coup de grosse caisse.
func _launch_wave(fuse: float, flood: bool, small := false) -> void:
	if waves.size() >= WAVE["max"]:
		return
	if small:
		# Pouls : une onde courte, brèches tournées d'un cran à chaque coup.
		var gaps_s: Array = []
		var base_s := _roll_spin + float(_wave_count) * 0.9
		for i in WAVE["gaps"]:
			gaps_s.append(base_s + TAU * i / WAVE["gaps"])
		waves.append({"r": radius * 0.9, "fuse": maxf(0.0, fuse), "total": maxf(0.05, fuse), "gaps": gaps_s, "hit": false, "reach": float(POWER[phase]["pulse"]), "small": true})
		return
	var n: int = WAVE["gaps"]
	var to: Vector2 = main.player.position - anchor
	var base := to.angle() if to.length() > 1.0 else PI / 2.0
	# Une onde sur deux s'ouvre devant le joueur ; l'autre juste à côté (d'un côté puis de l'autre) :
	# un pas de côté sur le temps.
	if _wave_count % 2 == 1:
		base += (WAVE["gap"] * 0.5 + WAVE["step"]) * (1.0 if _wave_count % 4 == 1 else -1.0)
	if flood:
		base += 0.35 * sin(float(_wave_count))
	var gaps: Array = []
	for i in n:
		gaps.append(base + TAU * i / n)
	waves.append({"r": radius * 0.9, "fuse": maxf(0.0, fuse), "total": maxf(0.05, fuse), "gaps": gaps, "hit": false, "reach": INF, "small": false})
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


## Un charleston : une petite braise par jet, le jet tourne d'un pas à chaque coup.
func _spark(n: int) -> void:
	_spark_angle += SPARK["step"]
	for i in n:
		var dir := Vector2.from_angle(_spark_angle + TAU * i / n)
		thorns.append({"pos": anchor + dir * radius * 0.8, "vel": dir * SPARK["speed"], "spark": true, "r": SPARK["radius"], "dmg": SPARK["damage"]})


## Une caisse douce : une petite racine pointe autour du joueur, « fuse » secondes plus tard.
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
				if p.position.distance_to(r["pos"]) < PRICK["radius"] + p.radius * 0.5:
					_hurt_player(PRICK["damage"] * damage_scale)
				if not Settings.reduce_effects:
					main.fx.ring(r["pos"], 4.0, PRICK["radius"], 0.2, Color(Art.ec("racine", "clair"), 0.8), 2.0)
		else:
			r["burst"] += delta
		if r["burst"] < FLASH:
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
				main.fx.shake(2.5)
				if not Settings.reduce_effects:
					main.fx.ring(anchor, radius * 0.5, radius * 2.0, 0.25, Color(Art.ec("cendre", "clair"), 0.9), 6.0)
			kept.append(wv)
			continue
		var small: bool = wv.get("small", false)
		var r0: float = wv["r"]
		var r1: float = r0 + WAVE["speed"] * delta
		wv["r"] = r1
		var d: float = p.position.distance_to(anchor)
		var half: float = (PULSE["width"] if small else WAVE["width"]) * 0.5 + p.radius * 0.6
		if not wv["hit"] and d > r0 - half and d < r1 + half and r0 < float(wv.get("reach", INF)) and not _in_wave_gap(wv, p.position, p.radius * 0.5):
			if p.invuln <= 0.0:
				wv["hit"] = true
				_hurt_player((PULSE["damage"] if small else WAVE["damage"]) * damage_scale)
		if r1 < minf(limit, float(wv.get("reach", INF)) + 40.0):
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
	_gesture_begin(kind)
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
	_gesture_mark("struck")
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
	_gesture_mark("ended")
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
		if pos.distance_to(p.position) < float(s.get("r", THORNS["radius"])) + p.radius and p.invuln <= 0.0:
			_hurt_player(THORNS["damage"] * damage_scale * float(s.get("dmg", ROLL["damage"] if s.get("roll", false) else 1.0)))
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
	pricks = []
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
	for r in pricks:
		if r["burst"] < 0.0 and pos.distance_to(r["pos"]) < PRICK["radius"] + margin:
			best = minf(best, maxf(0.0, r["fuse"]))
	for wv in waves:
		var ahead: float = d - float(wv["r"])
		if d > float(wv.get("reach", INF)) + margin:
			continue
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
	_gesture_mark("ended")
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
	pricks = []


## Le robot tourne autour d'elle, hors du siphon quand il s'annonce.
func bot_ring(arena_radius: float) -> float:
	var ring := minf(250.0, arena_radius - 60.0)
	if attack == "siphon" and arena_radius - 50.0 > SIPHON["radius"] + 40.0:
		ring = SIPHON["radius"] + 45.0
	return ring


# --- Dessin ---
#
# « Bestiaire d'herbier » (refonte des personnages, B4) : le corps, le sol, la victoire sont dessinés
# dans boss_art/finale.gd (vue de 3/4, encre fine, cendre, braise et bois brûlé des Flétris communs).
# Ici restent ce qui suit le combat : le battement sur la grille, la charge sur les ponts, la mort en
# cendre, le retournement vers le héros, et les annonces au sol (draw_marks, draw_overlay).


## Avancée de l'annonce en cours (0 → 1), 0 hors annonce.
## Le cœur (repère du boss) : là où se calent la charge, la mort et l'éclat (le dessin est ART fois
## plus grand que le rayon).
func heart_off() -> Vector2:
	return FinaleArt.HEART * FinaleArt.ART * radius / 100.0


# --- Gestes (dessin seul : boss_art/finale_choreo.gd) ---
# Chaque bras qui porte une attaque garde un enregistrement : l'attaque, l'heure de la frappe et de la
# fin (horloge t) ; l'annonce se lit dans _announce_k. Le retour au repos continue après la fin, même
# si une autre attaque commence ; un bras repris en plein retour part de sa pose du moment.
var _gestures: Array = [{}, {}, {}, {}, {}, {}]
var _anim := {}


## Les bras (rangs dans ARMS) qui jouent l'attaque « kind ».
static func gesture_arms(kind: String) -> Array:
	if COMBO_ARMS.has(kind):
		return COMBO_ARMS[kind]
	if kind == "rejetons":
		return [5]
	for i in ARMS.size():
		if ARMS[i]["trait"] == kind:
			return [i]
	return []


func _gesture_begin(kind: String) -> void:
	for i: int in gesture_arms(kind):
		var old: Dictionary = _gesture_rec(i)
		var rec := {"kind": kind, "struck": -1.0, "ended": -1.0, "begun": t}
		if not Choreo.done(old):
			rec["from"] = Choreo.arm_pose(old, str(ARMS[i]["trait"]), t)
		_gestures[i] = rec


func _gesture_mark(what: String) -> void:
	for i: int in gesture_arms(attack):
		var g: Dictionary = _gestures[i]
		if g.is_empty() or g["kind"] != attack or float(g[what]) >= 0.0:
			continue
		g[what] = t
		if what == "ended" and float(g["struck"]) < 0.0:
			g["struck"] = t


## L'enregistrement du bras i pour Choreo (k, s, e en secondes), {} au repos.
func _gesture_rec(i: int) -> Dictionary:
	var g: Dictionary = _gestures[i]
	if g.is_empty():
		return {}
	var rec := {"kind": g["kind"], "k": 1.0, "s": -1.0, "e": -1.0}
	if g.has("from"):
		rec["from"] = g["from"]
	if float(g["struck"]) < 0.0:
		rec["k"] = _announce_k() if g["kind"] == attack else 1.0
	else:
		rec["s"] = t - float(g["struck"])
		if float(g["ended"]) >= 0.0:
			rec["e"] = t - float(g["ended"])
	return rec


func _gesture_step() -> Dictionary:
	var recs: Array = []
	for i in ARMS.size():
		var rec := _gesture_rec(i)
		if not rec.is_empty() and Choreo.done(rec):
			_gestures[i] = {}
			rec = {}
		recs.append(rec)
	var to: Vector2 = main.player.position - anchor if main != null and main.player != null else Vector2.DOWN
	var anim := Choreo.build(recs, ARMS, to.normalized() if to.length() > 1.0 else Vector2.DOWN, t)
	if drum_flash >= 0.0 and drum_flash < 1.0:
		# Sur chaque coup de batterie, les bras au repos tressaillent (ils retombent, puis se relèvent).
		var j := (1.0 - drum_flash) * (1.0 - drum_flash)
		for i in ARMS.size():
			if recs[i].is_empty():
				var pose: Dictionary = anim["arms"][i].duplicate()
				pose["up"] = float(pose["up"]) - 0.09 * j
				pose["el"] = float(pose["el"]) + 0.12 * j
				anim["arms"][i] = pose
	return anim


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
	# Le corps est dessiné par couches (enfants, en partie cuites) ; ses battements et sa charge sont la transformation
	# de ce nœud. La charge passe derrière (ici) et devant (_front).
	var at := Transform2D.IDENTITY
	if charging:
		_draw_charge_back()
		# Elle gonfle sur chaque impulsion et tremble de plus en plus : l'énergie la déborde.
		var e := charge_energy()
		var sw := 1.0 + 0.05 * e + 0.05 * e * charge_pulse() + 0.08 * charge_overflow()
		var h := heart_off()
		at = Transform2D(0.0, Vector2(sw, sw), 0.0, charge_jitter() + h - h * sw)
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
		var h := heart_off()
		at = Transform2D(0.0, Vector2(sw, 2.0 - sw), 0.0, h - h * sw)
	_pose = [phase, _announce_k(), lit, die, _wake_k(), lit2, form_k(), _facing_step()]
	_anim = {} if dead or transforming() else _gesture_step()
	if _layers.is_empty():
		draw_set_transform_matrix(at)
		draw_colossus(self, Vector2.ZERO, radius, t, phase, _pose[1], lit, die, _pose[4], _color, lit2, _pose[6], _pose[7], _anim)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		if charging:
			_draw_charge_front(self)
		return
	# Les parties fixes (corps, chaque bras) sont recuites quand leur pose change ; le reste vit à chaque image.
	_bake_part("corps", [phase, snappedf(die, 0.05), snappedf(_pose[4], 0.1), snappedf(_pose[6], 0.05)])
	for i in ARMS.size():
		var on := FinaleArt.arm_on(i, _pose[1], lit, lit2, _pose[6])
		var key := [phase >= int(ARMS[i]["phase"]), snappedf(on, 0.25), snappedf(die, 0.05), snappedf(_pose[4], 0.1), snappedf(_pose[6], 0.05)]
		for part in [i, "f%d" % i, "m%d" % i]:
			_bake_part(part, key)
	var ready := true
	for key in _bakes:
		ready = ready and _bakes[key].ready
	_baked_ready = ready
	draw_set_transform_matrix(at)
	_compose(self, "fond")
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for n: Node2D in _layers:
		n.transform = at
		n.queue_redraw()
	_front.queue_redraw()


## Le colosse en couches (boss_art/finale.gd › compose) : les parties fixes, cuites en textures
## (boss_art/live_bake.gd, alpha prémultiplié, shader sprite_tint qui porte l'éclair du coup, le
## poison et la cendre de la mort comme BossBase._color), et ce qui vit à chaque image (œil, lueurs,
## cendre, braises, éclats) sur des nœuds sans shader, intercalés. Tant qu'une partie n'est pas
## cuite, le corps est dessiné en direct. Sans rendu (--headless), tout est dessiné en direct.
var _pose: Array = []
var _layers: Array = []
var _front: Node2D
var _bakes := {}
var _bake_args := {}
var _baked_ready := false
var _floor_node: Node2D
var _floor_bake
var _floor_key := [0, 0.0, 0.0]


func _make_art() -> void:
	if not LiveBake.available():
		return
	var mat := ShaderMaterial.new()
	mat.shader = TINT_SHADER
	for stage in ["corps", "milieu", "devant", "dessus"]:
		var n := Node2D.new()
		n.name = "Couche_" + stage
		if stage == "corps" or stage == "devant":
			n.material = mat
		n.draw.connect(_draw_layer.bind(n, stage))
		add_child(n)
		_layers.append(n)
	_front = Node2D.new()
	_front.name = "ChargeDevant"  # i18n: non
	_front.draw.connect(func():
		if sync != null and music_waiting() and charge >= 0.0:
			_draw_charge_front(_front))
	add_child(_front)
	var plain := func(c): return c
	_bakes["corps"] = LiveBake.new(self, FinaleArt.body_box(), func(ci):
		var a: Array = _bake_args["corps"]
		FinaleArt.draw_body(ci, Transform2D.IDENTITY, a[0], a[1], a[2], a[3], plain), FinaleArt.ART)
	# Chaque bras en trois pièces (bras, avant-bras, motif) : ses gestes plient le coude et gonflent le
	# motif sans recuire (transformations des textures).
	for i in ARMS.size():
		for part in [i, "f%d" % i, "m%d" % i]:
			var pc := FinaleArt.piece_of(part)
			_bakes[part] = LiveBake.new(self, FinaleArt.arm_box(i, pc[1]), func(ci):
				var a: Array = _bake_args[part]
				FinaleArt.draw_arm(ci, Transform2D.IDENTITY, i, ARMS, a[0], a[1], a[2], a[3], a[4], plain, pc[1]), FinaleArt.ART)
	for key in _bakes:
		_bakes[key].rate = 0.001
	# Le sol (racines, brume) : cuit à chaque changement de phase, de forme ou de mort, sous les annonces.
	_floor_node = Node2D.new()
	_floor_node.name = "Sol"  # i18n: non
	_floor_node.material = mat
	_floor_node.show_behind_parent = true
	_floor_node.position = anchor
	_floor_node.draw.connect(func(): _floor_bake.draw(_floor_node))
	marks.add_child(_floor_node)
	var s := radius / 100.0
	_floor_bake = LiveBake.new(self, Rect2(Vector2(-420, -120) * s, Vector2(840, 260) * s), func(ci):
		FinaleArt.draw_floor_static(ci, Vector2.ZERO, radius, phase, _floor_key[1], _floor_key[2]))
	_floor_bake.rate = 0.001


## Demande la cuisson d'une partie si sa pose a changé (args : ce que son dessin lit).
func _bake_part(key, args: Array) -> void:
	var b = _bakes[key]
	if b.key != args:
		var p: Array = _pose
		if str(key) == "corps":
			_bake_args[key] = [p[0], p[3], p[4], p[6]]
		else:
			var pc := FinaleArt.piece_of(key)
			_bake_args[key] = [p[0], FinaleArt.arm_on(pc[0], p[1], p[2], p[5], p[6]), p[3], p[4], p[6]]
			b.set_box(FinaleArt.arm_piece_box(pc[0], ARMS, p[0], p[3], p[4], p[6], pc[1]))
	b.update(args, t)


func _compose(ci: CanvasItem, stage: String) -> void:
	var p := _pose
	var tint := _tint_color()
	FinaleArt.compose(ci, Vector2.ZERO, radius, t, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], ARMS, func(cc: CanvasItem, xf: Transform2D, part):
		cc.draw_set_transform_matrix(xf)
		_bakes[part].draw(cc, Vector2.ZERO, tint)
		cc.draw_set_transform_matrix(Transform2D.IDENTITY), stage, _anim)


func _draw_layer(n: Node2D, stage: String) -> void:
	if _pose.size() != 8:
		return
	if not _baked_ready:
		# Pas encore cuit : tout en direct, sur la couche « milieu » (sans shader).
		if stage == "milieu":
			draw_colossus(n, Vector2.ZERO, radius, t, _pose[0], _pose[1], _pose[2], _pose[3], _pose[4], _color, _pose[5], _pose[6], _pose[7], _anim)
		return
	_compose(n, stage)


## La teinte de BossBase._color, pour le shader : rgb = couleur visée, alpha = 1 - sa part.
func _tint_color() -> Color:
	if dead:
		var k := Anim.ease_out(clampf(dying / death_time * 1.4, 0.0, 1.0))
		return Color(FletriArt.ash_color(), 1.0 - k)
	if hit_flash > 0.0:
		# Plus léger que sur l'ancien dessin (0,6 sur l'écorce seule) : ici, toute l'image s'éclaire.
		return Color(Art.c("danger_eclair"), 0.65)
	if poison_time > 0.0:
		return Color(Art.ec("poison"), 0.7)
	return Color.WHITE


## Elle se tourne vers le héros (vue de 3/4) : retournement en 0,3 s quand il passe franchement de
## l'autre côté ; immobile pendant la mort et la transformation. Dessin seul.
var _facing := 1.0
var _facing_to := 1.0
var _facing_at := -1.0


func _facing_step() -> float:
	var p = main.player if main != null else null
	if p != null and not dead and not transforming():
		var dx: float = p.position.x - anchor.x
		if absf(dx) > radius * 0.4:
			_facing_to = signf(dx)
	if _facing_at < 0.0 or frozen:
		_facing = _facing_to
	_facing_at = t
	_facing = move_toward(_facing, _facing_to, get_process_delta_time() / 0.15)
	return _facing


func _charge_color() -> Color:
	return Art.ec("cendre", "clair")


## Sa mort : la cendre de son corps s'envole par flocons, la sève jaillit de ses fentes en étincelles,
## puis, à mesure qu'elle s'efface, des pétales et des lueurs de sève montent de ce qui reste.
var _die_rng := RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_die_rng.seed = 2323
	_prick_rng.seed = 4141
	_make_art()


func _dying_step(_delta: float) -> void:
	if Settings.reduce_effects:
		return
	var k := clampf(dying / death_time, 0.0, 1.0)
	var h := anchor + heart_off()
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
	var h := heart_off()
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
		var seg := -heart_off().y
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
	var h := heart_off()
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
	var h := heart_off()
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
func _draw_charge_front(ci: CanvasItem) -> void:
	var e := charge_energy()
	var pulse := charge_pulse()
	var over := charge_overflow()
	var hot := Art.ec("cendre", "clair")
	var ember := Art.ec("cendre")
	var white := Color(1.0, 0.97, 0.9)
	var h := heart_off() + charge_jitter()
	# Veines de braise sur le corps, qui battent sur les impulsions.
	for i in 9:
		var a := TAU * i / 9.0 + 0.5
		var from := h + Vector2.from_angle(a) * radius * 0.15
		var to := h + Vector2.from_angle(a + 0.3 * sin(i * 2.1)) * radius * (0.55 + 0.6 * e)
		ci.draw_line(from, to, Color(ember.lerp(white, over), 0.35 + 0.6 * pulse), 3.0 + 6.0 * pulse + 4.0 * e, true)
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
		ci.draw_polyline(pts, Color(hot, al * 0.5), 6.0 + 4.0 * e, true)
		ci.draw_polyline(pts, Color(white, al), 2.0, true)
	# Couronne de rayons autour du cœur.
	var rays := 12 + int(12.0 * e)
	for i in rays:
		var a := TAU * i / rays + charge_spin * 0.5
		var l := radius * (0.5 + 0.9 * e * (0.6 + 0.4 * sin(t * 9.0 + i * 1.7)) + 0.5 * pulse * e)
		ci.draw_line(h + Vector2.from_angle(a) * radius * 0.3, h + Vector2.from_angle(a) * (radius * 0.3 + l), Color(hot.lerp(white, e), 0.2 + 0.45 * e), 2.0 + 2.0 * e, true)
	# Le cœur : il grossit, blanchit, bat.
	var core := radius * (0.16 + 0.18 * e + 0.1 * pulse * (0.3 + e) + 0.15 * over)
	ci.draw_circle(h, core * 1.9, Color(ember, 0.18 + 0.25 * e))
	ci.draw_circle(h, core * 1.3, Color(hot, 0.3 + 0.4 * e))
	ci.draw_circle(h, core, Color(hot.lerp(white, 0.4 + 0.6 * e), 0.55 + 0.45 * e))
	# Fissures de lumière sur son corps, de plus en plus nombreuses.
	var fissures := int(3.0 + 14.0 * e)
	for i in fissures:
		var a0 := TAU * _rand(i + 101)
		var p0 := h + Vector2.from_angle(a0) * radius * 0.35 * _rand(i + 102)
		var pts := PackedVector2Array([p0])
		for k in 3:
			pts.append(pts[k] + Vector2.from_angle(a0 + (_rand(i * 3 + k + 7) - 0.5) * 1.6) * radius * (0.12 + 0.1 * e))
		ci.draw_polyline(pts, Color(hot.lerp(white, pulse), 0.4 + 0.6 * pulse), 2.0 + 2.0 * e, true)
	# Le dernier temps : elle déborde.
	if over > 0.0:
		var flick := 0.6 + 0.4 * sin(t * 90.0)
		ci.draw_circle(h, radius * (1.0 + 1.6 * over), Color(white, 0.18 * over * flick))
		for i in 10:
			var a := TAU * i / 10.0 + 0.3 * sin(i * 4.1) + t * 0.7
			var l := radius * (2.0 + 10.0 * over)
			ci.draw_line(h, h + Vector2.from_angle(a) * l, Color(white, 0.55 * over * flick), 3.0 + 8.0 * over, true)


## Le sol autour d'elle, sous les annonces (draw_marks) : la brume de cendre et les racines brûlées
## qui l'ancrent au creux (boss_art/finale.gd).
static func draw_floor(ci: CanvasItem, c: Vector2, r: float, t: float, phase: int, die := 0.0, form := 0.0) -> void:
	FinaleArt.draw_floor(ci, c, r, t, phase, die, form)


## La Flétrissure entière, autour de « c » (son pied) : dessin du « Bestiaire d'herbier », vue de 3/4
## (boss_art/finale.gd). Statique : sert aussi au boss endormi (draw_sleeper).
##   lit, lit2 : bras allumés par l'annonce (-1 : aucun), k : avancée de l'annonce ;
##   die : avancée de la mort (0 → 1) ; wake : 0 endormie, 1 dressée ;
##   tint : couleur d'une partie du corps (éclair du coup, poison, cendre ; BossBase._color) ;
##   form : seconde forme (0 → 1) ; facing : 1 tournée vers la droite, -1 vers la gauche.
static func draw_colossus(ci: CanvasItem, c: Vector2, r: float, t: float, phase: int, k: float, lit: int, die: float, wake: float, tint: Callable, lit2 := -1, form := 0.0, facing := 1.0, anim := {}) -> void:
	FinaleArt.draw(ci, c, r, t, phase, k, lit, die, wake, tint, lit2, form, facing, ARMS, anim)


## Annonces au sol, en coordonnées monde (grammaire de Art.telegraph). Les rejetons, qui ne
## blessent pas, ne sont pas en rouge ; les nuages de spores posés gardent leur couleur.
func draw_marks(c: CanvasItem) -> void:
	var k := _announce_k()
	var fdie := clampf(dying / death_time, 0.0, 1.0) if dead else 0.0
	if _floor_bake != null:
		_floor_key = [phase, snappedf(form_k(), 0.05), snappedf(fdie, 0.05)]
		_floor_bake.update(_floor_key, t)
		_floor_node.queue_redraw()
		if _floor_bake.ready:
			FinaleArt.draw_floor_live(c, anchor, radius, t, phase, fdie, form_k())
		else:
			draw_floor(c, anchor, radius, t, phase, fdie, form_k())
	else:
		draw_floor(c, anchor, radius, t, phase, fdie, form_k())
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
	# Piqûres : nombreuses, dessinées simplement (pas de hachures) : un disque qui se remplit sur
	# l'annonce, bord rouge, puis l'éclair et l'épine de racine.
	var danger := Art.c("danger")
	for r in pricks:
		var pos: Vector2 = r["pos"]
		if r["burst"] < 0.0:
			var pk := clampf(1.0 - float(r["fuse"]) / float(r["total"]), 0.0, 1.0)
			c.draw_circle(pos, PRICK["radius"] * maxf(pk, 0.05), Art.c("danger_annonce"))
			c.draw_arc(pos, PRICK["radius"], 0.0, TAU, 16, Color(danger, 0.5 + 0.5 * pk), Art.TRAIT, true)
		else:
			var f: float = r["burst"] / FLASH
			c.draw_circle(pos, PRICK["radius"], Color(Art.c("danger_eclair"), 0.8 * (1.0 - f)))
			c.draw_line(pos, pos + Vector2(0, -PRICK["radius"] * (1.1 - 0.6 * f)), Art.ec("racine", "sombre"), 5.0, true)
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
		var small: bool = wv.get("small", false)
		var reach: float = minf(arena.radius, float(wv.get("reach", INF)))
		var full_w: float = PULSE["width"] if small else WAVE["width"]
		var w: float = full_w * (0.35 + 0.65 * k) if fuse > 0.0 else full_w
		var fade := 1.0
		if fuse <= 0.0:
			fade = clampf((reach + full_w - r) / (40.0 if small else 80.0), 0.0, 1.0)
		# Couloirs des brèches : lumière pâle, jusqu'au mur.
		for g in gaps:
			var dir := Vector2.from_angle(float(g))
			var from := maxf(r, radius) if fuse <= 0.0 else radius
			if not small:
				c.draw_line(anchor + dir * from, anchor + dir * reach, Color(pale, (0.10 + 0.12 * k) * fade), w * 1.6, true)
		for i in gaps.size():
			var a0: float = float(gaps[i]) + half
			var a1: float = float(gaps[(i + 1) % gaps.size()]) - half
			if a1 <= a0:
				a1 += TAU
			var segs := maxi(4, int((a1 - a0) * (6.0 if small else 12.0)))
			if fuse > 0.0:
				c.draw_arc(anchor, r, a0, a1, segs, Color(danger, 0.25 + 0.55 * k), Art.TRAIT * (1.0 + k), true)
			else:
				c.draw_arc(anchor, r, a0, a1, segs, Color(ash, 0.85 * fade), w, true)
				c.draw_arc(anchor, r - w * 0.5, a0, a1, segs, Color(danger, 0.9 * fade), Art.TRAIT, true)
				c.draw_arc(anchor, r + w * 0.5, a0, a1, segs, Color(danger, 0.9 * fade), Art.TRAIT, true)
				if small:
					continue
				c.draw_arc(anchor, r, a0, a1, segs, Color(pale, 0.45 * fade), w * 0.25, true)
				# Éclats de cendre aux bords des brèches.
				for e in [a0, a1]:
					var tip := anchor + Vector2.from_angle(e) * r
					c.draw_circle(tip, w * 0.45, Color(danger, 0.8 * fade))


## Épines en vol, au-dessus des personnages, en coordonnées monde.
func draw_overlay(c: CanvasItem) -> void:
	var col := Art.ec("epine")
	var roll_col := Art.ec("epine", "clair")
	var ember := Art.ec("cendre", "clair")
	for s in thorns:
		var p: Vector2 = s["pos"]
		if s.get("spark", false):
			# Braise : un point chaud et sa traînée.
			var back: Vector2 = s["vel"].normalized() * SPARK["radius"] * 2.6
			c.draw_line(p - back, p, Color(ember, 0.55), SPARK["radius"] * 1.1, true)
			c.draw_circle(p, SPARK["radius"], ember)
			c.draw_circle(p, SPARK["radius"] * 0.5, Color(1.0, 0.95, 0.85))
			continue
		var d: Vector2 = s["vel"].normalized()
		var o := d.orthogonal() * THORNS["radius"] * 0.55
		var tri := PackedVector2Array([p + d * THORNS["radius"] * 1.6, p + o - d * THORNS["radius"], p - o - d * THORNS["radius"]])
		c.draw_colored_polygon(tri, roll_col if s.get("roll", false) else col)
		Art.outline(c, tri, Art.c("contour"), Art.TRAIT_FIN)


## La Flétrissure endormie : la même, repliée, l'œil clos ; ses racines déjà dans le sol.
static func draw_sleeper(a: Node2D) -> void:
	var c: Vector2 = a.center
	var r := BODY_RADIUS
	# Cuite comme en combat (~10 i/s) dans un enfant de l'arène, qui ne se montre qu'avant le combat.
	var node: Node2D = a.get_node_or_null("FletrissureEndormie")  # i18n: non
	if node == null and LiveBake.available():
		node = Node2D.new()
		node.name = "FletrissureEndormie"  # i18n: non
		var mat := ShaderMaterial.new()
		mat.shader = TINT_SHADER
		node.material = mat
		var bake = LiveBake.new(a, Rect2(-420, -360, 840, 480), func(ci):
			FinaleArt.draw_floor_static(ci, Vector2.ZERO, r, 1, 0.0, 0.0)
			draw_colossus(ci, Vector2.ZERO, r, a.t, 0, 0.0, -1, 0.0, 0.0, func(col): return col))
		bake.rate = 5.0
		node.set_meta("bake", bake)
		node.draw.connect(func():
			if a.state == "ouverte" or a.state == "fermee":
				bake.draw(node, c))
		a.add_child.call_deferred(node)
	var baked = node.get_meta("bake") if node != null else null
	if baked != null:
		baked.update(0, a.t)
		node.queue_redraw()
	if baked == null or not baked.ready:
		draw_floor(a, c, r, a.t, 1)
		draw_colossus(a, c, r, a.t, 0, 0.0, -1, 0.0, 0.0, func(col): return col)
	if a.state == "ouverte":
		var pulse := 0.45 + 0.35 * sin(a.t * 2.0)
		Art.glow(a, c + Vector2(0, -r * 0.6), r * 0.35 * pulse, "cendre")


## Après la victoire : une pousse de l'Arbre de vie, ses six feuilles aux couleurs des régions.
static func draw_victory(a: Node2D) -> void:
	FinaleArt.draw_victory(a, a.center, a.t, ARMS)


## Le retour de la batterie : elle se dresse d'un coup, une onde dans les couleurs des bras éveillés.
func _music_resume() -> void:
	super._music_resume()
	for i in mini(ARMS.size(), phase * 2):
		main.fx.ring(anchor, radius * 0.8, 260.0 + 70.0 * i, 0.5 + 0.08 * i, Color(Art.ec(ARMS[i]["element"], "clair"), 0.8), 5.0)
	main.screen_fx.glow(Art.ec("cendre"), 0.5, 0.8)
