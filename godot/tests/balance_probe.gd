## Sonde de mesure d'équilibrage (jalon 14.5, lot B). Aucune valeur de jeu n'est lue pour être changée
## ni écrite : la sonde regarde seulement le jeu tourner, une image après l'autre, pendant l'aventure
## du robot (tests/aventure_test.gd). Elle compte, pour chaque région jouée et par contexte
## (exploration, siège d'un Cœur, boss, finale) :
## - la vie perdue (chute de la vie d'une image à l'autre, plus la vie restante à chaque mort), sa
##   provenance (ennemi ordinaire, élite, boss, ou à distance : aucun ennemi à moins de 250 px) ;
## - le déplacement (chemin parcouru, vitesse moyenne), la part du temps passé au contact (ennemi à
##   moins de 100 px), « en fuite » (le héros court à plus de 60 % de sa vitesse, un ennemi à moins de
##   400 px mais aucun à moins de 100 px : il kite) et libre (aucun ennemi à moins de 400 px) ;
## - le temps pour tuer : du premier coup reçu à la mort, pour les ennemis ordinaires et pour les élites ;
## - chaque combat de boss : durée, vie perdue, morts, niveau du héros ;
## - le niveau, les points d'arbre gagnés et dépensés, à chaque changement de niveau ;
## - les morts.
## Tout sort en lignes « MESURE… » (clé=valeur) que tools/mesure-equilibre.py met en tableaux.
extends RefCounted

const Difficulty = preload("res://scripts/difficulty.gd")
const Regions = preload("res://scripts/regions.gd")

## Distances (px) : contact, fuite, libre ; vie perdue « à distance » au-delà de FAR.
const CONTACT := 100.0
const CHASE := 400.0
const FAR := 250.0
const FLEE_SPEED := 0.6

var _seg := ""             ## région en cours (ou « finale »)
var _build := ""
var data: Dictionary = {}  ## segment -> compteurs
var level_log: Array = []  ## [t, région, niveau, points gagnés, points hors niveau, nœuds, menace]
var fights: Array = []     ## un combat de boss : {région, début, durée, vie_perdue, morts, niveau}
var _fight: Dictionary = {}
var _prev_hp := -1.0
var _prev_pos := Vector2.INF
var _main_id := 0
var _deaths_seen := 0
var _level_seen := 0
var _hit: Dictionary = {}  ## instance -> [temps du premier coup, référence faible, élite ?]
var _t := 0.0


func begin_region(region: String, build: String) -> void:
	_seg = region
	_build = build
	_seg_data()["build"] = build


func _seg_data() -> Dictionary:
	if not data.has(_seg):
		data[_seg] = {
			"build": _build, "niveau_debut": 0, "niveau_fin": 0, "temps": 0.0, "morts": 0,
			"ctx_temps": {"exploration": 0.0, "coeur": 0.0, "boss": 0.0},
			"ctx_vie": {"exploration": 0.0, "coeur": 0.0, "boss": 0.0},
			"vie_commun": 0.0, "vie_elite": 0.0, "vie_boss": 0.0, "vie_distance": 0.0,
			"chemin": 0.0, "temps_contact": 0.0, "temps_fuite": 0.0, "temps_libre": 0.0,
			"vie_max_somme": 0.0, "vitesse": 0.0,
			"ttk_commun": [], "ttk_elite": [], "elites_vues": 0, "elites_tuees": 0,
		}
	return data[_seg]


## Une image de jeu (t : temps de jeu en secondes).
func step(main, delta: float, game, t: float) -> void:
	_t = t
	if _seg == "" or main == null or not is_instance_valid(main) or main.player == null:
		return
	var d := _seg_data()
	var p = main.player
	var mid: int = main.get_instance_id()
	if mid != _main_id:
		_main_id = mid
		_deaths_seen = main.deaths
		_prev_hp = -1.0
		_prev_pos = Vector2.INF
		_hit.clear()
	if d["niveau_debut"] == 0:
		d["niveau_debut"] = game.level
	d["niveau_fin"] = game.level
	_log_level(main, game)
	var ctx := "exploration"
	var boss_now: bool = main.in_boss_fight()
	if boss_now:
		ctx = "boss"
	elif main.siege_heart() != null:
		ctx = "coeur"
	d["temps"] += delta
	d["ctx_temps"][ctx] += delta
	d["vie_max_somme"] += float(game.stats["max_hp"]) * delta
	# Ennemis proches : le plus près, et sa catégorie.
	var near := INF
	var near_kind := ""
	var chase := false
	for e in main.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var dist: float = e.position.distance_to(p.position)
		if dist < near:
			near = dist
			near_kind = "elite" if e.elite else "commun"
		if dist < CHASE:
			chase = true
		_track_hit(e)
	_collect_kills()
	# Déplacement.
	var moved := 0.0
	if _prev_pos != Vector2.INF:
		moved = p.position.distance_to(_prev_pos)
		if moved > 2000.0:
			moved = 0.0   # téléportation (renaissance, descente sous la graine)
	_prev_pos = p.position
	var speed := moved / maxf(delta, 0.0001)
	var max_speed: float = maxf(float(game.stats.get("move_speed", 230.0)), 1.0)
	if ctx != "boss":
		d["chemin"] += moved
		if near < CONTACT:
			d["temps_contact"] += delta
		elif chase and speed > FLEE_SPEED * max_speed:
			d["temps_fuite"] += delta
		elif not chase:
			d["temps_libre"] += delta
	# Vie perdue.
	var lost := 0.0
	var died: bool = main.deaths > _deaths_seen
	if died:
		d["morts"] += main.deaths - _deaths_seen
		if _fight.size() > 0:
			_fight["morts"] += main.deaths - _deaths_seen
		lost = maxf(_prev_hp, 0.0)
		_deaths_seen = main.deaths
	elif _prev_hp >= 0.0 and p.hp < _prev_hp:
		lost = _prev_hp - p.hp
	_prev_hp = p.hp
	if lost > 0.0:
		d["ctx_vie"][ctx] += lost
		if ctx == "boss":
			d["vie_boss"] += lost
		elif near > FAR:
			d["vie_distance"] += lost
		elif near_kind == "elite":
			d["vie_elite"] += lost
		else:
			d["vie_commun"] += lost
	# Combat de boss.
	if boss_now:
		if _fight.is_empty():
			_fight = {"region": _seg, "debut": t, "duree": 0.0, "vie_perdue": 0.0, "morts": 0, "niveau": game.level}
		_fight["duree"] += delta
		_fight["vie_perdue"] += lost
	elif not _fight.is_empty():
		fights.append(_fight)
		_fight = {}


## Premier coup reçu par un ennemi : on note l'instant, pour mesurer le temps pour le tuer.
func _track_hit(e) -> void:
	if e.hp >= e.max_hp:
		return
	var id: int = e.get_instance_id()
	if not _hit.has(id):
		_hit[id] = [_t, weakref(e), e.elite]
		if e.elite:
			_seg_data()["elites_vues"] += 1


func _collect_kills() -> void:
	for id in _hit.keys():
		var e = _hit[id][1].get_ref()
		if e == null:
			# Retiré de la scène sans passer par la mort (rechargement) : on l'oublie.
			_hit.erase(id)
		elif e.dead:
			var dur: float = _t - float(_hit[id][0])
			var d := _seg_data()
			if _hit[id][2]:
				d["ttk_elite"].append(dur)
				d["elites_tuees"] += 1
			elif not str(e.get("kind_id")).begins_with("boss"):
				d["ttk_commun"].append(dur)
			_hit.erase(id)


func _log_level(main, game) -> void:
	if game.level == _level_seen:
		return
	_level_seen = game.level
	var total: int = game.points + game.allocated.size() - 1
	var depth := 0.5
	var hearts: int = main.hearts_purified() if main != null and main.has_method("hearts_purified") else 0
	level_log.append([_t, _seg, game.level, total, int(game.flags.get("points_hors_niveau", 0)), game.allocated.size(), Difficulty.threat(game.level, depth, hearts)])


## Ferme la région (appelé à la fin de chaque région) : vide le combat de boss en cours.
func end_region() -> void:
	if not _fight.is_empty():
		fights.append(_fight)
		_fight = {}


static func _median(a: Array) -> float:
	if a.is_empty():
		return -1.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


static func _pct(a: Array, q: float) -> float:
	if a.is_empty():
		return -1.0
	var b := a.duplicate()
	b.sort()
	return float(b[mini(b.size() - 1, int(q * b.size()))])


## Une ligne « MESURE » par région et par combat de boss, une par niveau gagné.
func report(game) -> Array:
	end_region()
	var out: Array = []
	for seg in data:
		var d: Dictionary = data[seg]
		var tt: float = maxf(d["temps"], 1.0)
		var vie: float = d["ctx_vie"]["exploration"] + d["ctx_vie"]["coeur"] + d["ctx_vie"]["boss"]
		var avg_max: float = d["vie_max_somme"] / tt
		var non_boss: float = maxf(d["temps"] - d["ctx_temps"]["boss"], 1.0)
		out.append("MESURE region=%s build=%s temps=%.0f niveau=%d>%d morts=%d vie_max_moy=%.0f vie_perdue=%.0f vie_perdue_par_min=%.1f vie_max_par_min=%.2f part_commun=%.3f part_elite=%.3f part_boss=%.3f part_distance=%.3f vie_coeur=%.0f vie_expl=%.0f temps_coeur=%.0f temps_boss=%.0f chemin_px_s=%.1f part_contact=%.3f part_fuite=%.3f part_libre=%.3f ttk_commun_med=%.2f ttk_commun_p90=%.2f ttk_commun_n=%d elites_vues=%d elites_tuees=%d ttk_elite_med=%.2f ttk_elite_p90=%.2f ttk_elite_max=%.2f" % [
			seg, d["build"], d["temps"], d["niveau_debut"], d["niveau_fin"], d["morts"], avg_max, vie,
			vie / (tt / 60.0), vie / (tt / 60.0) / maxf(avg_max, 1.0),
			d["vie_commun"] / maxf(vie, 1.0), d["vie_elite"] / maxf(vie, 1.0), d["vie_boss"] / maxf(vie, 1.0), d["vie_distance"] / maxf(vie, 1.0),
			d["ctx_vie"]["coeur"], d["ctx_vie"]["exploration"], d["ctx_temps"]["coeur"], d["ctx_temps"]["boss"],
			d["chemin"] / non_boss, d["temps_contact"] / non_boss, d["temps_fuite"] / non_boss, d["temps_libre"] / non_boss,
			_median(d["ttk_commun"]), _pct(d["ttk_commun"], 0.9), d["ttk_commun"].size(),
			d["elites_vues"], d["elites_tuees"], _median(d["ttk_elite"]), _pct(d["ttk_elite"], 0.9), _pct(d["ttk_elite"], 1.0)])
	for f in fights:
		out.append("MESUREBOSS region=%s debut=%.0f duree=%.1f vie_perdue=%.0f morts=%d niveau=%d" % [f["region"], f["debut"], f["duree"], f["vie_perdue"], f["morts"], f["niveau"]])
	for l in level_log:
		out.append("MESURENIVEAU t=%.0f region=%s niveau=%d points_gagnes=%d points_hors_niveau=%d noeuds=%d menace=%.2f" % [l[0], l[1], l[2], l[3], l[4], l[5], l[6]])
	return out
