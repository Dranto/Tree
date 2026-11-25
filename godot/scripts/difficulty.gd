## Difficulté du jeu : menace des ennemis, apparitions, courbe d'expérience et choix
## Facile / Normal / Difficile. Toutes les constantes sont dans res://data/difficulty.json.
##
## La menace d'un ennemi dépend de la progression du joueur (son niveau), de l'endroit où il
## naît (profondeur dans la région) et des Cœurs de flétrissure purifiés, jamais du temps passé.
## Logique pure (aucun nœud) : utilisée par main.gd, enemy.gd, game.gd, boss.gd et build_bot.gd.
extends RefCounted

const Content = preload("res://scripts/content.gd")
const MODES := ["facile", "normal", "difficile"]


static func data() -> Dictionary:
	return Content._load("difficulty")


static func _section(name: String) -> Dictionary:
	var d = data().get(name, {})
	return d if d is Dictionary else {}


## Menace d'un ennemi né à cette profondeur (0 au bord de la région, 1 au fond), pour un joueur
## de ce niveau, avec ce nombre de Cœurs purifiés. 1 = un Flétri du début de partie.
static func threat(level: int, depth: float, hearts: int) -> float:
	var t := _section("threat")
	var v: float = float(t.get("base", 1.0)) \
		+ float(t.get("per_level", 0.1)) * (level - 1) \
		+ float(t.get("depth", 0.0)) * clampf(depth, 0.0, 1.0) \
		+ float(t.get("per_heart", 0.0)) * hearts
	return minf(v, float(t.get("max", 99.0)))


## Facteurs appliqués aux statistiques d'un ennemi de menace p (avant le choix de difficulté).
static func hp_factor(p: float) -> float:
	return 1.0 + float(_section("scaling").get("hp", 1.0)) * (p - 1.0)


## Les dégâts ont en plus un multiplicateur général (« damage_mult ») : la vie et la régénération
## du joueur sont faibles au début, et c'est la durée des combats qui fait la difficulté.
static func damage_factor(p: float) -> float:
	var s := _section("scaling")
	return float(s.get("damage_mult", 1.0)) * (1.0 + float(s.get("damage", 0.5)) * (p - 1.0))


static func speed_factor(p: float) -> float:
	return 1.0 + float(_section("scaling").get("speed", 0.04)) * (p - 1.0)


static func xp_factor(p: float) -> float:
	return 1.0 + float(_section("scaling").get("xp", 1.0)) * (p - 1.0)


## Expérience pour passer du niveau donné au suivant.
static func xp_to_next(level: int) -> float:
	var x := _section("xp")
	var l := float(level - 1)
	return float(x.get("base", 10.0)) + float(x.get("per_level", 10.0)) * l + float(x.get("quad", 0.0)) * l * l


## Durée visée (en minutes) pour passer du niveau donné au suivant (robot d'équilibrage).
static func target_minutes(level: int) -> float:
	var x := _section("xp")
	return minf(float(x.get("target_max", 2.5)), float(x.get("target_start", 1.0)) + float(x.get("target_per_level", 0.25)) * (level - 1))


## Secondes entre deux salves d'apparitions (avant l'accélération en profondeur).
static func spawn_interval(level: int) -> float:
	var s := _section("spawn")
	return maxf(float(s.get("interval_min", 0.4)), float(s.get("interval_base", 1.3)) - float(s.get("interval_per_level", 0.03)) * (level - 1))


## Accélération du compte à rebours des apparitions à cette profondeur.
static func spawn_speedup(depth: float) -> float:
	return 1.0 + float(_section("spawn").get("depth_speedup", 0.0)) * clampf(depth, 0.0, 1.0)


## Nombre d'ennemis à l'écran au plus : calme près de la graine, dense au fond du roncier.
static func spawn_cap(level: int, depth: float) -> int:
	var c: Dictionary = _section("spawn").get("cap", {})
	var v := lerpf(float(c.get("near", 20)), float(c.get("far", 80)), clampf(depth, 0.0, 1.0)) + float(c.get("per_level", 0.0)) * (level - 1)
	return mini(int(v), int(c.get("max", 120)))


## Ennemis par salve.
static func spawn_burst(level: int, depth: float) -> int:
	var b: Dictionary = _section("spawn").get("burst", {})
	var v := lerpf(float(b.get("near", 1)), float(b.get("far", 3)), clampf(depth, 0.0, 1.0)) + float(b.get("per_level", 0.0)) * (level - 1)
	return clampi(int(v), 1, int(b.get("max", 6)))


## Réglages d'un mode de difficulté (« facile », « normal », « difficile ») : nom, vie, dégâts.
static func mode(id: String) -> Dictionary:
	var modes: Dictionary = _section("modes")
	var m = modes.get(id, modes.get("normal", {}))
	return m if m is Dictionary else {}


static func mode_name(id: String) -> String:
	return Loc.data(str(mode(id).get("name", id)))


## Multiplicateurs du mode choisi dans les options (Settings.difficulty).
static func hp_mult() -> float:
	return float(mode(_current()).get("hp", 1.0))


static func damage_mult() -> float:
	return float(mode(_current()).get("damage", 1.0))


## Multiplicateur de vie d'un boss régional (data/difficulty.json › bosses › hp).
static func boss_hp_factor(region_id: String) -> float:
	var h = _section("bosses").get("hp", {})
	return float(h.get(region_id, 1.0)) if h is Dictionary else 1.0


## Réglages des coups reçus punis (data/difficulty.json › punish).
static func punish() -> Dictionary:
	return _section("punish")


static func _current() -> String:
	var settings = Engine.get_main_loop().root.get_node_or_null("Settings") if Engine.get_main_loop() is SceneTree else null
	if settings != null and "difficulty" in settings:
		return settings.difficulty
	return "normal"


static func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var d := data()
	if d.is_empty():
		errors.append("difficulty.json est absent, vide ou illisible")
		return errors
	for section in ["threat", "scaling", "xp", "spawn", "modes", "bosses", "punish"]:
		if not d.get(section) is Dictionary:
			errors.append("difficulty.json : section « %s » manquante" % section)
	for m in MODES:
		var md = d.get("modes", {}).get(m)
		if not md is Dictionary:
			errors.append("difficulty.json : mode « %s » manquant" % m)
			continue
		for f in ["name", "hp", "damage"]:
			if not md.has(f):
				errors.append("difficulty.json, mode %s : champ « %s » manquant" % [m, f])
	for l in range(1, 41):
		if xp_to_next(l) <= 0.0:
			errors.append("difficulty.json : expérience du niveau %d nulle ou négative" % l)
			break
		if l > 1 and xp_to_next(l) < xp_to_next(l - 1):
			errors.append("difficulty.json : la courbe d'expérience baisse au niveau %d" % l)
			break
	if spawn_cap(1, 0.0) < 1 or spawn_interval(1) <= 0.0:
		errors.append("difficulty.json : apparitions impossibles (plafond ou cadence)")
	return errors
