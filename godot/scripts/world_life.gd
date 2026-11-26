## Monde vivant (refonte du monde « Paysages d'herbier », vague 1 V) : le décor bouge, la petite vie
## du monde réagit au héros, aux Flétris et aux combats. Moteur unique, piloté par world_fx.gd (qui le
## crée et lui passe world_fx.react) ; dosage dans res://data/feel.json › world › life.
##
## Animations ambiantes :
##   - balancement du décor par shader (shaders/decor_sway.gdshaderinc, inclus par le décor cuit et par
##     le matériau du décor dessiné en direct) : vent de fond, rafales qui traversent l'écran (sur les
##     Plateaux, calées sur wind.gd), impulsions locales (héros qui traverse un buisson, charge, coup
##     lourd), torsion près d'un élite, lueur de la lanterne du héros sur le décor proche ;
##   - l'herbe de world_fx.gd suit les rafales (gust_at) ;
##   - l'eau se ride (mares du Marais, sources de la Vallée), la faune ambiante vit sa vie.
## Réactions :
##   - au héros : buissons qui frémissent et lâchent des feuilles, flaques qui éclaboussent, faune qui
##     s'envole puis revient, lanterne, pas fleuris sur la terre ravivée ;
##   - aux Flétris (positions lues sur main, rien dans enemy.gd) : cendre sous les pas sur la terre
##     vivante, buissons secoués par une charge, herbe fauchée par les projectiles, plantes qui se
##     tordent près d'un élite, faune qui fuit ;
##   - aux combats : secousse du décor proche sur un coup lourd, chute de feuilles, cailloux ou éclats
##     selon la région, le décor proche d'une trace de combat (world_fx.add_trace) frémit aussi.
## Événements du monde (vague 2 E) : world_life.event(kind, pos, data) ; branchés ici sur les crochets
## des lieux (heart.gd › siege_ticked, bloomed ; sanctuary.gd › lit ; altar.gd › activated), sur
## main.elite_killed et sur world_fx.level_up/graft_pickup :
##   - « bloom » : vague de vie depuis le Cœur purifié : le décor reverdit au passage du front (fondu de
##     l'image cuite morte à la vivante, sans recuisson), pousse, se relève et s'éclaire, pétales et spores ;
##   - « siege » : chaque seconde tenue, le décor proche du Cœur se tord et s'assombrit un peu plus ;
##   - « lit » (sanctuaire), « altar » (autel ravivé) : lueur sur le décor proche, qui s'efface ;
##   - « level », « graft » : souffle autour du héros (le décor se couche puis revient, feuilles) ;
##   - « fane » (mort d'un élite) : la flore proche se fane, se tasse, puis se relève.
## Arènes des boss (vague 3 A, boss_arena.gd › _watch_boss) :
##   - « boss_phase » : le boss change de phase : le décor autour de l'arène se couche vers elle et
##     s'assombrit, la faune fuit, débris de la région qui tombent du mur (data : r, wall : rayon du mur) ;
##   - « boss_hit » : le boss est touché : un souffle bref autour de lui (sans zone du shader).
## Le décor les reçoit par shader (life_zone/life_tint/life_shape de shaders/decor_sway.gdshaderinc,
## 4 zones à la fois) ; une région ajoute les siens par <région>_vivant.gd › event (facultatif).
## API : world_fx.react(kind, pos, force) ; une région ajoute ses réactions propres dans
## res://scripts/world_art/<région>_vivant.gd (fonctions statiques facultatives react et ambient,
## voir world_art/spore_vivant.gd), sans registre partagé.
##
## Performance : tout passe par shader (balancement) ou par images cuites (world_life_atlas.gd) envoyées
## en un seul appel de rendu par calque ; tout est borné (rayon autour du héros, plafonds de faune, de
## débris et de marques) ; les Flétris sont lus par la grille spatiale, quelques fois par seconde.
## Dessin seul : aucune collision, aucun chiffre de jeu, le hasard du jeu n'est jamais tiré.
## « Réduire les effets » : un tiers de tout (faune, débris, marques, amplitude du balancement).
## Tests visuels : `still` fige tout (rien n'est posé ni dessiné), sauf dans le scénario « vivant ».
extends Node2D

const Flora = preload("res://scripts/flora.gd")
const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")
const Atlas = preload("res://scripts/world_life_atlas.gd")
const Vie = preload("res://scripts/world_life_vie.gd")
const DecorMarais = preload("res://scripts/decor_marais.gd")
const DecorPlateau = preload("res://scripts/decor_plateau.gd")
const DecorVallee = preload("res://scripts/decor_vallee.gd")
const DecorFalaise = preload("res://scripts/decor_falaise.gd")
const DecorForet = preload("res://scripts/decor_foret.gd")
const Wind = preload("res://scripts/wind.gd")
const DecorBake = preload("res://scripts/world_bake/decor_bake.gd")
const SWAY_SHADER = preload("res://shaders/decor_sway.gdshader")
const LIFE_SHADER = preload("res://shaders/world_life.gdshader")
const Heart = preload("res://scripts/heart.gd")

## Tests visuels : tout figé (aucun matériau posé, rien dessiné). Le scénario « vivant » le rouvre.
static var still := false

const PUSH_SLOTS := 8

var main
var world_fx
## Calque du dessus des personnages (débris en l'air, faune qui vole, lucioles).
var air: Layer
var cfg := {}
var clock := 0.0
var rng := RandomNumberGenerator.new()

## Calque de dessin : quadrilatères texturés de l'atlas, en un seul appel de rendu.
class Layer extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)


# --- Balancement ---
var _push: Array = []   # {pos, r, f, t}
## Rafale en cours : front le long du vent, demi-largeur, force, vitesse ; inactive si force nulle.
var gust := {"front": 0.0, "width": 220.0, "force": 0.0, "speed": 600.0, "end": 0.0}
var gust_dir := Vector2(0.94, 0.34)
var _gust_wait := 4.0
var _light := 0.0
var _scan_i := 0

# --- Petite vie ---
## Débris : {f (image), pos, z, v (Vector2), vz, rot, vr, t, dur, col, s, flutter}.
var bits: Array = []
## Marques au sol : {f, pos, t, dur, col, s, grow}.
var marks: Array = []
## Faune non hostile et formes guéries (make_beast) : {sp, key, reg, gueri, move, pos, z, state, t, timer,
## home, dest, v, face, col, seed, vz, ph}. Dessins cuits en couleur : world_life_vie.gd.
var fauna: Array = []
var _tick := 0.0
var _enemy_tick := 0.0
var _fauna_tick := 0.0
var _step_clock := 0.0
var _step_side := 1.0
## Un pas de Flétri sur deux laisse sa cendre.
var _ash_n := 0
var _last_pos := {}       # instance_id -> Vector2 (Flétris)
var _cooldown := {}       # instance_id -> temps (décor, Flétris)
var _region_hooks := {}   # région -> script ou null
var _region := ""

# Lots du dessin (points, couleurs, coordonnées de texture, indices).
var _pts := PackedVector2Array()
var _cols := PackedColorArray()
var _uvs := PackedVector2Array()
var _idx := PackedInt32Array()


func setup(m, wfx) -> void:
	main = m
	world_fx = wfx
	rng.seed = 41017
	cfg = Content.feel().get("world", {}).get("life", {})
	name = "WorldLife" # i18n: non
	air = Layer.new()
	air.fn = _draw_air
	air.name = "WorldLifeAir" # i18n: non
	var mat := ShaderMaterial.new()
	mat.shader = LIFE_SHADER
	material = mat
	air.material = mat
	_gust_wait = _num("gust", "first", 3.0)
	# Les lieux et les élites naissent après le monde vivant (main._ready) : branchés à la fin de l'image.
	_connect_events.call_deferred()


func _ready() -> void:
	if not still:
		Atlas.bake(self)


## Sortie du jeu : rien de gardé dans des variables statiques (atlas, tables de scripts), et les copies du
## matériau du décor oubliées (DecorBake.release() en refait un neuf à la partie suivante).
func _exit_tree() -> void:
	Atlas.clear()
	Vie.clear()
	_tabs = []
	_variants.clear()


func _less() -> bool:
	return Settings.reduce_effects


## Quantité divisée par trois avec « Réduire les effets » (au moins 1).
func _qty(n: int) -> int:
	return maxi(1, int(round(n / 3.0))) if _less() else n


func _num(section: String, key: String, default: float) -> float:
	var s = cfg.get(section, {})
	return float(s.get(key, default)) if s is Dictionary else default


func _region_cfg(reg: String) -> Dictionary:
	var r: Dictionary = cfg.get("regions", {})
	return r.get(reg, r.get("ronce", {}))


## Couleur de la petite vie d'une région (Art.MONDE › vivant).
func col(reg: String, key: String) -> Color:
	var v: Dictionary = Art.MONDE.get("vivant", {})
	var r: Dictionary = v.get(reg, v.get("ronce", {}))
	if r.has(key):
		return r[key]
	return v.get("commun", {}).get(key, Color.MAGENTA)


func _player():
	return main.player if main != null else null


# ---------------------------------------------------------------- API

## Le monde réagit : « kind » parmi rustle (froissement), charge, hit, heavy, trace, death, blast,
## splash, scare (la faune fuit), gust (rafale) ; « force » vers 1. Une région peut le prendre en
## charge elle-même (world_art/<région>_vivant.gd › react).
func react(kind: String, pos: Vector2, force := 1.0) -> void:
	if still or main == null:
		return
	var p = _player()
	if p != null and pos.distance_squared_to(p.position) > pow(_num("near", "radius", 900.0), 2):
		return
	var reg := _region_of(pos)
	var hook = _hook(reg)
	if hook != null and hook.has_method("react") and hook.react(self, kind, pos, force):
		return
	match kind:
		"rustle":
			push(pos, 70.0, 0.8 * force)
		"charge":
			push(pos, 80.0, 1.1 * force)
			_shed(pos, 60.0, 1, reg)
			scare(pos, 160.0)
		"hit":
			push(pos, 90.0, 0.8 * force)
			_shed(pos, 80.0, 1, reg)
			scare(pos, 150.0)
		"heavy", "blast":
			push(pos, 150.0 * clampf(force, 0.6, 1.6), 1.6 * force)
			_shed(pos, 170.0, _qty(int(_num("combat", "heavy_bits", 10))), reg)
			scare(pos, 300.0)
		"trace":
			if not decor_near(pos, 60.0).is_empty():
				push(pos, 70.0, 0.7 * force)
				_shed(pos, 60.0, 1, reg, pos)
		"death":
			push(pos, 60.0, 0.5 * force)
			scare(pos, 180.0)
		"splash":
			splash(pos, force)
		"scare":
			scare(pos, 200.0 * force)
		"gust":
			start_gust(force)


## Impulsion de balancement (centre, rayon, force ; force < 0 : torsion). Remplace la plus faible.
func push(pos: Vector2, r: float, f: float) -> void:
	if still:
		return
	f *= 0.34 if _less() else 1.0
	for e in _push:
		# Même endroit : rafraîchie plutôt que doublée.
		if e["pos"].distance_squared_to(pos) < 20.0 * 20.0 and signf(e["f"]) == signf(f):
			e["t"] = minf(e["t"], 0.04)
			e["f"] = f if absf(f) > absf(e["f"]) else e["f"]
			e["r"] = maxf(e["r"], r)
			return
	if _push.size() >= PUSH_SLOTS:
		var weakest := 0
		var wv := INF
		for i in _push.size():
			var v: float = absf(_push[i]["f"]) * exp(-_push[i]["t"] * 3.2)
			if v < wv:
				wv = v
				weakest = i
		_push.remove_at(weakest)
	_push.append({"pos": pos, "r": r, "f": f, "t": 0.0})


## Rafale qui traverse l'écran (force 0 à 1).
func start_gust(force := 1.0, dir := Vector2.ZERO) -> void:
	var p = _player()
	if p == null:
		return
	if dir != Vector2.ZERO:
		gust_dir = dir.normalized()
	var along: float = p.position.dot(gust_dir)
	var span := _num("gust", "span", 1100.0)
	gust["front"] = along - span
	gust["end"] = along + span
	gust["width"] = _num("gust", "width", 240.0)
	gust["speed"] = _num("gust", "speed", 620.0)
	gust["force"] = force * _num("gust", "force", 0.55)


## Vent de la rafale à « pos » (direction × force), pour l'herbe de world_fx.gd.
func gust_at(pos: Vector2) -> Vector2:
	if gust["force"] <= 0.0:
		return Vector2.ZERO
	var x: float = (pos.dot(gust_dir) - gust["front"]) / maxf(gust["width"], 1.0)
	return gust_dir * gust["force"] * exp(-x * x)


## Éléments du décor dont le pied est dans le disque (celui de flora.gd s'il existe, sinon la grille
## par carrés de flora).
func decor_near(pos: Vector2, r: float) -> Array:
	var fl = main.flora if main != null else null
	if fl == null:
		return []
	if fl.has_method("decor_near"):
		return fl.decor_near(pos, r)
	var out: Array = []
	var a := Vector2i(floori((pos.x - r) / Flora.CHUNK), floori((pos.y - r) / Flora.CHUNK))
	var b := Vector2i(floori((pos.x + r) / Flora.CHUNK), floori((pos.y + r) / Flora.CHUNK))
	for cy in range(a.y, b.y + 1):
		for cx in range(a.x, b.x + 1):
			for t in fl.tree_cells.get(Vector2i(cx, cy), []):
				if is_instance_valid(t) and t.position.distance_squared_to(pos) < r * r:
					out.append(t)
	return out


## La faune proche de « pos » s'enfuit.
func scare(pos: Vector2, r: float) -> void:
	for a in fauna:
		if a["pos"].distance_squared_to(pos) < r * r:
			_flee(a, pos)


## Éclaboussure (mare, flaque) : gouttes et une ride.
func splash(pos: Vector2, force := 1.0) -> void:
	var reg := _region_of(pos)
	add_mark("eclabous", pos, 0.45, col(reg, "eau"), 0.9 + 0.3 * force, 0.4)
	add_mark("ride", pos, 1.1, col(reg, "eau"), 0.7, 1.2)
	for i in _qty(4):
		var a := rng.randf_range(PI * 1.1, PI * 1.9)
		add_bit("goutte", pos, 2.0, Vector2.from_angle(a) * rng.randf_range(30.0, 60.0), rng.randf_range(60.0, 110.0), col(reg, "eau"), 0.7, 0.6)


## Mélange avec le hasard du monde vivant (Array.shuffle tirerait le hasard global, celui du jeu).
func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var v = a[i]
		a[i] = a[j]
		a[j] = v


## Débris (image de l'atlas) lâché à « pos », hauteur « z », vitesse au sol « v », vitesse montante « vz ».
func add_bit(f: String, pos: Vector2, z: float, v: Vector2, vz: float, c: Color, s := 1.0, dur := 2.2, flutter := 0.0) -> void:
	var cap := _qty(int(_num("caps", "bits", 72)))
	while bits.size() >= cap:
		bits.pop_front()
	bits.append({"f": f, "pos": pos, "z": z, "v": v, "vz": vz, "rot": rng.randf() * TAU, "vr": rng.randf_range(-6.0, 6.0),
		"t": 0.0, "dur": dur, "col": c, "s": s, "flutter": flutter, "seed": rng.randf() * TAU})


## Marque au sol (cendre, fleur, ride, éclaboussure) qui naît, tient puis s'efface en « dur » secondes.
func add_mark(f: String, pos: Vector2, dur: float, c: Color, s := 1.0, grow := 0.0) -> void:
	var cap := _qty(int(_num("caps", "marks", 60)))
	while marks.size() >= cap:
		marks.pop_front()
	marks.append({"f": f, "pos": pos, "t": 0.0, "dur": dur, "col": c, "s": s, "grow": grow, "rot": 0.0})


# ---------------------------------------------------------------- boucle

func _process(delta: float) -> void:
	if still or main == null:
		return
	clock += delta
	var p = _player()
	if p == null:
		return
	_region = _region_of(p.position)
	_ensure_sheets(delta)
	_update_gust(delta)
	for e in _push:
		e["t"] += delta
	_push = _push.filter(func(e): return e["t"] < 1.6)
	var lit := _num("lantern", "strength", 0.3) * (1.0 if main.ground.life_at(p.position) < 0.45 else _num("lantern", "alive", 0.4))
	_light = move_toward(_light, lit, delta * 0.6)
	_scan_decor()
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.1
		_hero_step(p)
		_projectiles()
	_enemy_tick -= delta
	if _enemy_tick <= 0.0:
		_enemy_tick = _num("enemies", "every", 0.15)
		_enemies(p)
	_fauna_tick -= delta
	if _fauna_tick <= 0.0:
		_fauna_tick = 0.25
		_fauna_spawn(p)
	_ambient_water(p, delta)
	var hook = _hook(_region)
	if hook != null and hook.has_method("ambient"):
		hook.ambient(self, delta)
	_update_bits(delta)
	_update_marks(delta)
	_update_fauna(p, delta)
	_update_events(p, delta)
	_apply_uniforms(p)
	queue_redraw()
	air.queue_redraw()


func _update_gust(delta: float) -> void:
	# Sur les Plateaux, la rafale de wind.gd mène : le front part à son annonce, dans son sens.
	var w = Wind.active
	if w != null and w.here > 0.3:
		if w.state == "rafale" and gust["force"] <= 0.0:
			start_gust(1.0 + w.strength, w.dir)
	if gust["force"] > 0.0:
		gust["front"] += gust["speed"] * delta
		if gust["front"] > gust["end"]:
			gust["force"] = 0.0
		return
	_gust_wait -= delta
	if _gust_wait <= 0.0:
		var rc := _region_cfg(_region)
		var every: Array = rc.get("gust_every", [7.0, 14.0])
		_gust_wait = rng.randf_range(float(every[0]), float(every[1]))
		var dir := Vector2.from_angle(rng.randf_range(-0.5, 0.5) + float(rc.get("wind_angle", 0.35)))
		start_gust(float(rc.get("gust", 0.7)), dir)
		# Quelques feuilles emportées par la rafale.
		var p = _player()
		for i in _qty(int(_num("gust", "bits", 5))):
			var at: Vector2 = p.position + Vector2(rng.randf_range(-700, 500), rng.randf_range(-420, 420)) - gust_dir * 200.0
			var reg := _region_of(at)
			add_bit(_bit_kind(reg, null), at, rng.randf_range(20.0, 60.0), gust_dir * rng.randf_range(180.0, 260.0), 10.0,
				_bit_col(reg, at), 0.75, 3.5, 1.0)


## Pose les uniforms du balancement sur chaque matériau du décor.
func _apply_uniforms(p) -> void:
	var less := 0.34 if _less() else 1.0
	var wind := Vector4(gust_dir.x, gust_dir.y, _num("sway", "ambient", 0.12) * less * float(_region_cfg(_region).get("breeze", 1.0)), clock)
	var g := Vector4(gust["front"], gust["width"], gust["force"] * less, 0.0)
	var pushes: Array = []
	var forces := PackedFloat32Array()
	for i in PUSH_SLOTS:
		if i < _push.size():
			var e: Dictionary = _push[i]
			pushes.append(Vector4(e["pos"].x, e["pos"].y, e["r"], e["t"]))
			forces.append(e["f"])
		else:
			pushes.append(Vector4(0, 0, 0, 0))
			forces.append(0.0)
	var light := Vector4(p.position.x, p.position.y - p.radius, _num("lantern", "radius", 180.0), _light)
	# Événements : posés aussi sur le matériau de base du décor cuit (rochers, falaises : couleur seule).
	if not events.is_empty() or _ev_dirty:
		_ev_dirty = not events.is_empty()
		var ev := _event_uniforms(p)
		var mats: Array = _variants.values()
		if DecorBake.enabled:
			mats.append(DecorBake.material())
		for m in mats:
			m.set_shader_parameter("life_zone", ev[0])
			m.set_shader_parameter("life_tint", ev[1])
			m.set_shader_parameter("life_shape", ev[2])
	for m in _variants.values():
		m.set_shader_parameter("sway_wind", wind)
		m.set_shader_parameter("sway_gust", g)
		m.set_shader_parameter("sway_push", pushes)
		m.set_shader_parameter("sway_force", forces)
		m.set_shader_parameter("sway_light", light)


## Paliers de souplesse : chaque élément prend une copie de son matériau au palier le plus proche.
const SWAY_STEPS := [0.15, 0.3, 0.55, 0.8, 1.0, 1.3]
## [matériau de base, palier] -> copie au palier (les uniforms y sont posés chaque image).
var _variants := {}


## Copie de « base » (null : le matériau du décor dessiné en direct) à la souplesse « s ».
func sway_material(base: ShaderMaterial, s: float) -> ShaderMaterial:
	var step := 0
	for i in SWAY_STEPS.size():
		if absf(SWAY_STEPS[i] - s) < absf(SWAY_STEPS[step] - s):
			step = i
	var key := [base.get_instance_id() if base != null else 0, step]
	if not _variants.has(key):
		var m: ShaderMaterial
		if base == null:
			m = ShaderMaterial.new()
			m.shader = SWAY_SHADER
		else:
			m = base.duplicate()
		m.set_shader_parameter("sway", SWAY_STEPS[step])
		m.set_meta("vivant", true)
		_variants[key] = m
	return _variants[key]


## Donne aux éléments du décor leur matériau balancé, quelques-uns par image (le décor cuit garde le
## sien, en copie à sa souplesse ; un élément que le décor remet sur le matériau de base est repris au
## passage suivant).
func _scan_decor() -> void:
	var trees: Array = main.flora.trees if main.flora != null else []
	if trees.is_empty():
		return
	var baked: ShaderMaterial = DecorBake.material() if DecorBake.enabled else null
	for k in 48:
		_scan_i = (_scan_i + 1) % trees.size()
		var t = trees[_scan_i]
		if not is_instance_valid(t):
			continue
		var m = t.material
		if m != null and m.has_meta("vivant"):
			continue
		var s := sway_of(t)
		if s <= 0.0:
			continue
		if m == null:
			t.material = sway_material(null, s)
		elif m == baked:
			t.material = sway_material(baked, s)


## Souplesse d'un élément : sa propriété « sway » si le décor la donne, sinon selon sa sorte.
static func sway_of(t) -> float:
	# La souplesse posée par le décor composé (D) l'emporte ; 0 (valeur par défaut de DecorTree) laisse
	# la table par sorte décider.
	var v = t.get("sway")
	if v != null and float(v) > 0.0:
		return float(v)
	var s = t.get_script()
	var tab: Dictionary = _tables()[0]
	if tab.has(s):
		return tab[s]
	return 1.0 if t is Flora.DecorTree else 0.0


static var _tabs: Array = []

## Tables par sorte de décor : [souplesse, débris lâchés].
static func _tables() -> Array:
	if _tabs.is_empty():
		var sw := {
			DecorMarais.DecorReeds: 1.3, DecorPlateau.Grass: 1.3, DecorVallee.Willow: 1.1, DecorVallee.Fern: 1.0,
			Flora.DecorBramble: 0.8, DecorPlateau.Twisted: 0.65, DecorFalaise.Bleached: 0.65, Flora.DecorBush: 0.55,
			DecorMarais.DecorMushroom: 0.3, Flora.DecorLandmark: 0.2, DecorForet.StoneTree: 0.12,
		}
		for r in [DecorMarais.DecorPool, DecorMarais.DecorLog, DecorPlateau.Stone, DecorVallee.Spring, DecorVallee.MossRock,
				DecorFalaise.Crystals, DecorFalaise.Cliff, DecorFalaise.Shards, DecorForet.GiantRoot, DecorForet.Stump,
				DecorForet.Scree, DecorForet.Petrified]:
			sw[r] = 0.0
		var bk := {DecorMarais.DecorMushroom: "spore", DecorFalaise.Crystals: "eclat", DecorFalaise.Shards: "eclat",
			DecorFalaise.Cliff: "eclat", DecorForet.Stump: "sciure", DecorForet.GiantRoot: "sciure",
			DecorForet.StoneTree: "caillou", DecorForet.Scree: "caillou", DecorForet.Petrified: "caillou",
			DecorPlateau.Stone: "caillou", DecorVallee.MossRock: "caillou"}
		_tabs = [sw, bk]
	return _tabs


## Ce que lâche un élément secoué : feuille, spore, éclat, caillou… (sinon celui de la région).
func _bit_kind(reg: String, t) -> String:
	if t != null:
		var bk: Dictionary = _tables()[1]
		var s = t.get_script()
		if bk.has(s):
			return bk[s]
	return str(_region_cfg(reg).get("bits", "feuille"))


func _bit_col(reg: String, at: Vector2) -> Color:
	var alive: bool = main.ground.life_at(at) > 0.45
	return col(reg, "bris_vif" if alive else "bris_mort")


## Lâche jusqu'à « n » débris depuis le haut des éléments du décor proches de « pos » (vers « to »).
func _shed(pos: Vector2, r: float, n: int, reg: String, to := Vector2.INF) -> void:
	var near := decor_near(pos, r)
	var done := 0
	_shuffle(near)
	for t in near:
		if done >= n:
			break
		if sway_of(t) <= 0.0 and _bit_kind(reg, t) == str(_region_cfg(reg).get("bits", "feuille")):
			continue
		var h := 34.0 * float(t.get("size") if t.get("size") != null else 1.0)
		var top: Vector2 = t.position
		var k := _bit_kind(reg, t)
		var c := _bit_col(reg, top)
		if k == "spore":
			c = col(reg, "spore")
		for j in maxi(1, n / maxi(1, near.size())):
			var dest: Vector2 = (to if to != Vector2.INF else top) + Vector2(rng.randf_range(-24, 24), rng.randf_range(-8, 12))
			var at := top + Vector2(rng.randf_range(-12, 12), 0)
			var heavy := k in ["caillou", "eclat", "sciure"]
			add_bit(k, at, h * rng.randf_range(0.7, 1.2), (dest - at) * 0.6, 30.0 if not heavy else 70.0, c,
				rng.randf_range(0.65, 0.85), 2.6 if not heavy else 1.8, 0.0 if heavy else 1.0)
			done += 1


# ---------------------------------------------------------------- événements du monde

const EVENT_SLOTS := 4
## Événements en cours : {kind, pos, t, dur, r, reg, src (Cœur…), k (siège), last (dernier tic)}.
var events: Array = []
## Décor encore flétri au départ d'une vague de vie (instance_id -> élément) : il pousse en fondu
## quand la vague l'atteint (flora.gd le réveille d'un coup quand le Cœur peint le sol par disques).
var _bloom_watch := {}
var _ev_dirty := false
var _ev_bits := 0.0


func _connect_events() -> void:
	if main == null or not is_instance_valid(main):
		return
	for h in main.get("all_hearts") if main.get("all_hearts") != null else []:
		if h.has_signal("siege_ticked") and not h.siege_ticked.is_connected(_on_siege_tick):
			h.siege_ticked.connect(_on_siege_tick.bind(h))
			h.bloomed.connect(_on_bloomed.bind(h))
	for sc in main.get("sanctuaries") if main.get("sanctuaries") != null else []:
		if sc.has_signal("lit"):
			sc.lit.connect(func(): event("lit", sc.position))
	for a in main.get("altars") if main.get("altars") != null else []:
		if a.has_signal("activated"):
			a.activated.connect(func(): event("altar", a.position))
	if main.has_signal("elite_killed"):
		main.elite_killed.connect(func(e): event("fane", e.position))
	if main.get("ground") != null and main.ground.has_signal("painted"):
		main.ground.painted.connect(_on_painted)


func _on_siege_tick(k: float, h) -> void:
	event("siege", h.center, {"src": h, "k": k, "r": h.zone * 1.7})


func _on_bloomed(with_wave: bool, h) -> void:
	# Une partie chargée ne rejoue rien : le décor y est déjà vivant.
	if not with_wave:
		return
	event("bloom", h.center, {"src": h, "r": h.life_radius, "dur": Heart.LIFE_TIME})


func _ev(key: String, default: float, kind := "") -> float:
	var e: Dictionary = cfg.get("events", {})
	var s = e.get(kind, {}) if kind != "" else e
	return float(s.get(key, default)) if s is Dictionary else default


## Un événement du monde à « pos » : bloom, siege, lit, altar, level, graft, fane (voir l'en-tête).
## « data » : r (rayon), dur (durée), src (le lieu), k (avancée du siège).
func event(kind: String, pos: Vector2, data := {}) -> void:
	if still or main == null:
		return
	var reg := _region_of(pos)
	var hook = _hook(reg)
	if hook != null and hook.has_method("event") and hook.event(self, kind, pos, data):
		return
	var e := {"kind": kind, "pos": pos, "t": 0.0, "reg": reg, "src": data.get("src"),
		"r": float(data.get("r", _ev("radius", 260.0, kind))), "dur": float(data.get("dur", _ev("dur", 2.5, kind))),
		"k": float(data.get("k", 0.0)), "last": 0.0}
	match kind:
		"siege":
			# Un siège par Cœur : le même événement, ravivé à chaque seconde tenue.
			for o in events:
				if o["kind"] == "siege" and o["src"] == e["src"]:
					o["k"] = e["k"]
					o["last"] = o["t"]
					_siege_tick(o)
					return
			events.append(e)
			_siege_tick(e)
			return
		"bloom":
			events = events.filter(func(o): return not (o["kind"] == "siege" and o["src"] == e["src"]))
			_bloom_watch.clear()
			for t in decor_near(pos, e["r"] + 40.0):
				if not t.alive:
					_bloom_watch[t.get_instance_id()] = t
			e["dur"] += 0.8
			scare(pos, e["r"])
		"lit", "altar":
			push(pos, e["r"] * 0.85, _ev("push", 1.4, kind))
			_glow_bits(e, _qty(int(_ev("bits", 10, kind))))
		"level", "graft":
			push(pos, e["r"], _ev("push", 1.8, kind))
			_breath_bits(e, _qty(int(_ev("bits", 8, kind))))
		"fane":
			scare(pos, e["r"] * 1.4)
			_shed(pos, e["r"] * 0.6, _qty(4), reg)
		"boss_phase":
			scare(pos, e["r"] * 1.3)
			push(pos, e["r"], -_ev("push", 2.0, kind))
			_shed(pos, e["r"], _qty(int(_ev("bits", 6, kind))), reg, pos)
			_wall_bits(e, float(data.get("wall", e["r"] / 1.35)), _qty(int(_ev("wall_bits", 14, kind))))
		"boss_hit":
			push(pos, float(data.get("r", _ev("radius", 160.0, kind))), _ev("push", 0.6, kind))
			return
	if events.size() >= 8:
		events.pop_front()
	events.append(e)


## Vague de vie : flora.gd réveille d'un coup le décor que le Cœur peint ; celui qui était flétri au
## départ de la vague pousse en fondu (l'image cuite vivante éclot sur la morte).
func _on_painted(center: Vector2, radius: float) -> void:
	if _bloom_watch.is_empty() or radius == INF:
		return
	var r2 := (radius + 4.0) * (radius + 4.0)
	for id in _bloom_watch.keys():
		var t = _bloom_watch[id]
		if not is_instance_valid(t):
			_bloom_watch.erase(id)
			continue
		if t.alive and t.position.distance_squared_to(center) <= r2:
			_bloom_watch.erase(id)
			if t.leaf >= 1.0:
				t.revive(true)


func _siege_tick(e: Dictionary) -> void:
	var k: float = e["k"]
	push(e["pos"], e["r"] * 0.9, -_ev("twist", 0.9, "siege") * (0.5 + k))
	# Un peu de cendre arrachée au décor proche, qui monte vers le Cœur.
	var near := decor_near(e["pos"], e["r"] * 0.9)
	_shuffle(near)
	var n := 0
	for t in near:
		if n >= _qty(int(_ev("bits", 3, "siege"))):
			break
		n += 1
		var at: Vector2 = t.position + Vector2(rng.randf_range(-10, 10), 0)
		add_bit("cendre", at, 24.0 * float(t.get("size") if t.get("size") != null else 1.0),
			(e["pos"] - at) * 0.35, 16.0, col(e["reg"], "cendre"), 0.8, 2.0, 0.8)


## Débris de la région qui tombent du mur d'une arène (rayon w autour de e.pos) vers l'intérieur.
func _wall_bits(e: Dictionary, w: float, n: int) -> void:
	var reg: String = e["reg"]
	for i in n:
		var a := rng.randf() * TAU
		var at: Vector2 = e["pos"] + Vector2.from_angle(a) * w
		var k := _bit_kind(reg, null)
		var c := col(reg, "spore") if k == "spore" else col(reg, "bris_mort")
		add_bit(k, at, rng.randf_range(50.0, 90.0), -Vector2.from_angle(a) * rng.randf_range(30.0, 70.0), 20.0, c, rng.randf_range(0.7, 0.9), 2.2, 1.0)


func _glow_bits(e: Dictionary, n: int) -> void:
	var c := col(e["reg"], "lueur_lieu")
	for i in n:
		var at: Vector2 = e["pos"] + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, e["r"] * 0.45)
		add_bit("lueur", at, rng.randf_range(4.0, 20.0), Vector2(rng.randf_range(-10, 10), rng.randf_range(-6, 6)), 40.0,
			c, rng.randf_range(0.35, 0.55), 2.6, 0.4)


func _breath_bits(e: Dictionary, n: int) -> void:
	var reg: String = e["reg"]
	for i in n:
		var a := rng.randf() * TAU
		var at: Vector2 = e["pos"] + Vector2.from_angle(a) * rng.randf_range(30.0, 60.0)
		add_bit("petale" if i % 2 == 0 else _bit_kind(reg, null), at, rng.randf_range(10.0, 30.0),
			Vector2.from_angle(a + 0.9) * rng.randf_range(90.0, 150.0), 50.0, _bit_col(reg, at), 0.75, 2.2, 1.0)


## Avance les événements, lâche les pétales du front des vagues.
func _update_events(p, delta: float) -> void:
	if events.is_empty():
		if not _bloom_watch.is_empty():
			_bloom_watch.clear()
		return
	var near2 := pow(_num("near", "radius", 900.0), 2)
	_ev_bits -= delta
	var shed := _ev_bits <= 0.0
	if shed:
		_ev_bits = _ev("bits_every", 0.08, "bloom")
	for e in events:
		e["t"] += delta
		if e["kind"] == "bloom" and shed and e["t"] < e["dur"] - 0.8:
			var front := _bloom_front(e)
			for i in _qty(int(_ev("bits", 2, "bloom"))):
				var at: Vector2 = e["pos"] + Vector2.from_angle(rng.randf() * TAU) * front
				if at.distance_squared_to(p.position) > near2:
					continue
				var reg := _region_of(at)
				var k := "spore" if _bit_kind(reg, null) == "spore" else "petale"
				var c := col(reg, "spore") if k == "spore" else col(reg, "pas")
				add_bit(k, at, rng.randf_range(6.0, 24.0), (at - e["pos"]).normalized() * rng.randf_range(20.0, 50.0), 60.0, c, 0.75, 2.6, 1.0)
	var before := events.size()
	events = events.filter(func(e): return e["t"] < _ev_end(e))
	if events.is_empty() and before > 0:
		_bloom_watch.clear()


## Fin d'un événement : le siège dure tant que les secondes tombent, puis s'apaise.
func _ev_end(e: Dictionary) -> float:
	if e["kind"] == "siege":
		return e["t"] + 1.0 if _siege_held(e) else e["last"] + _ev("fade", 1.6, "siege")
	return e["dur"]


## Le siège tient : le Cœur est encore assiégé et une seconde est tombée il y a peu.
func _siege_held(e: Dictionary) -> bool:
	var h = e["src"]
	return h != null and is_instance_valid(h) and h.get("state") == "siege" and e["t"] - e["last"] < 2.0


## Couleur de la palette (≤ 1) changée en multiplicateur qui éclaire (× gain).
static func _gain(c: Color, g: float) -> Color:
	return Color(c.r * g, c.g * g, c.b * g, 1.0)


func _bloom_front(e: Dictionary) -> float:
	var k := clampf(e["t"] / maxf(e["dur"] - 0.8, 0.01), 0.0, 1.0)
	return lerpf(140.0, e["r"], k)


## Zone du shader d'un événement : [zone, teinte, forme, poids] (forme : pousse, penchant, éclosion).
func _ev_slot(e: Dictionary) -> Array:
	var t: float = e["t"]
	var less := 0.34 if _less() else 1.0
	var pos: Vector2 = e["pos"]
	var r: float = e["r"]
	match e["kind"]:
		"bloom":
			var fade := 1.0 - smoothstep(e["dur"] - 0.8, e["dur"], t)
			var c := _gain(col(e["reg"], "pousse"), _ev("gain", 1.4, "bloom"))
			return [Vector4(pos.x, pos.y, _bloom_front(e), _ev("width", 150.0, "bloom")),
				Vector4(c.r, c.g, c.b, _ev("tint", 0.55, "bloom") * fade),
				Vector4(_ev("lift", 0.14, "bloom") * fade * less, _ev("lean", 0.5, "bloom") * fade * less, _ev("puff", 0.06, "bloom") * fade * less, 0.0), 3.0]
		"siege":
			var calm := 1.0 if _siege_held(e) else 1.0 - smoothstep(e["last"], e["last"] + _ev("fade", 1.6, "siege"), t)
			var tick := exp(-(t - e["last"]) * 5.0)
			var s := (0.35 + 0.65 * clampf(e["k"], 0.0, 1.0)) * calm
			var c := col(e["reg"], "siege")
			return [Vector4(pos.x, pos.y, r, 0.0), Vector4(c.r, c.g, c.b, _ev("tint", 0.6, "siege") * s + 0.2 * tick * calm),
				Vector4(-_ev("lift", 0.05, "siege") * s * less, -_ev("lean", 0.35, "siege") * (s + 0.5 * tick) * less, 0.0, 0.0), 2.0]
		"lit", "altar":
			var env := smoothstep(0.0, 0.25, t) * exp(-maxf(0.0, t - 0.25) * 3.0 / e["dur"])
			var c := col(e["reg"], "lueur_lieu" if e["kind"] == "lit" else "lueur_autel")
			c = _gain(c, _ev("gain", 1.5, e["kind"]))
			var glow := Vector4(c.r, c.g, c.b, _ev("tint", 0.6, e["kind"]) * env)
			return [Vector4(pos.x, pos.y, r, 0.0), glow, Vector4(_ev("lift", 0.04, e["kind"]) * env * less, 0.0, 0.0, 0.0), 1.5]
		"level", "graft":
			var env := exp(-t * 3.0 / e["dur"])
			var c := _gain(col(e["reg"], "souffle"), _ev("gain", 1.2, e["kind"]))
			var ring := lerpf(40.0, r, minf(1.0, t / 0.5))
			return [Vector4(pos.x, pos.y, ring, r * 0.5), Vector4(c.r, c.g, c.b, _ev("tint", 0.35, e["kind"]) * env),
				Vector4(0.0, _ev("lean", 0.9, e["kind"]) * env * less, 0.0, 0.0), 1.0]
		"boss_phase":
			# Le décor se couche vers l'arène et s'assombrit d'un coup, puis se relève.
			var env := smoothstep(0.0, 0.15, t) * exp(-maxf(0.0, t - 0.15) * 3.0 / e["dur"])
			var c := col(e["reg"], "siege")
			return [Vector4(pos.x, pos.y, r, 0.0), Vector4(c.r, c.g, c.b, _ev("tint", 0.55, "boss_phase") * env),
				Vector4(-_ev("lift", 0.06, "boss_phase") * env * less, -_ev("lean", 0.8, "boss_phase") * env * less, 0.0, 0.0), 2.0]
		"fane":
			# Se fane (0,35 s), reste fanée, puis se relève en dépassant un peu.
			var dur: float = e["dur"]
			var down := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(dur * 0.4, dur * 0.6, t))
			var back := smoothstep(dur * 0.5, dur * 0.65, t) * (1.0 - smoothstep(dur * 0.7, dur, t))
			var c := col(e["reg"], "fane")
			return [Vector4(pos.x, pos.y, r, 0.0), Vector4(c.r, c.g, c.b, _ev("tint", 0.65, "fane") * down),
				Vector4((-_ev("lift", 0.16, "fane") * down + 0.05 * back) * less, -_ev("lean", 0.25, "fane") * down * less, 0.0, 0.0), 2.0]
	return []


## Les 4 zones les plus proches du héros, posées sur les matériaux du décor (rien quand tout est calme).
func _event_uniforms(p) -> Array:
	var slots: Array = []
	for e in events:
		var sl := _ev_slot(e)
		if sl.is_empty():
			continue
		var d: float = maxf(0.0, (e["pos"] as Vector2).distance_to(p.position) - float(sl[0].z))
		sl.append(d / float(sl[3]))
		slots.append(sl)
	if slots.size() > EVENT_SLOTS:
		slots.sort_custom(func(a, b): return a[4] < b[4])
		slots.resize(EVENT_SLOTS)
	var z: Array = []
	var tn: Array = []
	var sh: Array = []
	for i in EVENT_SLOTS:
		if i < slots.size():
			z.append(slots[i][0])
			tn.append(slots[i][1])
			sh.append(slots[i][2])
		else:
			z.append(Vector4.ZERO)
			tn.append(Vector4.ZERO)
			sh.append(Vector4.ZERO)
	return [z, tn, sh]


# ---------------------------------------------------------------- héros

func _hero_step(p) -> void:
	var feet: Vector2 = p.position + Vector2(0.0, p.radius * 0.8)
	var moving: bool = p.walk > 0.12 or p.dash_time > 0.0
	if not moving:
		return
	var dash: bool = p.dash_time > 0.0
	var r := 70.0 if dash else 44.0
	var near := decor_near(feet, r)
	var soft := false
	for t in near:
		if sway_of(t) > 0.0:
			soft = true
			if _ready_again(t, 0.6):
				var reg := _region_of(t.position)
				var k := _bit_kind(reg, t)
				var c := col(reg, "spore") if k == "spore" else _bit_col(reg, t.position)
				var h := 30.0 * float(t.get("size") if t.get("size") != null else 1.0)
				var dir: Vector2 = p.move_dir if p.move_dir != Vector2.ZERO else Vector2.RIGHT
				for i in _qty(2 if dash else 1):
					add_bit(k, t.position + Vector2(rng.randf_range(-10, 10), 0), h * rng.randf_range(0.5, 0.9),
						dir * rng.randf_range(20.0, 50.0) + Vector2(rng.randf_range(-20, 20), 0), 25.0, c, 0.75, 2.6, 1.0)
		if _is_water(t) and t.position.distance_to(feet) < _water_r(t) and _ready_again(t, 0.35):
			splash(feet, 1.2 if dash else 0.8)
	if soft:
		push(feet, r + 26.0, 1.2 if dash else 0.7)
	# Flaques du Marais (marsh_puddles.gd).
	if main.has_meta("flaques") and is_instance_valid(main.get_meta("flaques")):
		for q in main.get_meta("flaques").puddles:
			if q["pos"].distance_to(feet) < float(q.get("r", 30.0)) and _ready_again(p, 0.3):
				splash(feet, 0.8)
				break
	# Pas fleuris sur la terre ravivée.
	_step_clock -= 0.1
	if _step_clock <= 0.0 and main.ground.life_at(feet) > _num("hero", "bloom_life", 0.6):
		_step_clock = _num("hero", "bloom_every", 0.3)
		_step_side = -_step_side
		var side: Vector2 = (p.move_dir.orthogonal() if p.move_dir != Vector2.ZERO else Vector2.RIGHT) * 5.0 * _step_side
		var reg := _region_of(feet)
		add_mark("fleur_pas", feet + side, _num("hero", "bloom_time", 3.6), col(reg, "pas"), rng.randf_range(0.75, 1.0), 0.0)
	# La faune proche s'envole.
	for a in fauna:
		if a["pos"].distance_squared_to(p.position) < pow(_scare_r(a) * (1.6 if dash else 1.0), 2):
			_flee(a, p.position)


func _ready_again(o, every: float) -> bool:
	var id: int = o.get_instance_id()
	if clock - float(_cooldown.get(id, -100.0)) < every:
		return false
	_cooldown[id] = clock
	if _cooldown.size() > 400:
		for k in _cooldown.keys():
			if clock - float(_cooldown[k]) > 5.0:
				_cooldown.erase(k)
	return true


static func _is_water(t) -> bool:
	var s = t.get_script()
	return s == DecorMarais.DecorPool or s == DecorVallee.Spring


static func _water_r(t) -> float:
	var sz: float = float(t.get("size") if t.get("size") != null else 1.0)
	return (34.0 if t.get_script() == DecorMarais.DecorPool else 20.0) * sz


## Rides de l'eau : de temps en temps sur les mares et les sources proches.
var _water_clock := 0.0

func _ambient_water(p, delta: float) -> void:
	_water_clock -= delta
	if _water_clock > 0.0:
		return
	_water_clock = _num("water", "every", 0.5)
	for t in decor_near(p.position, _num("water", "radius", 520.0)):
		if _is_water(t) and rng.randf() < _num("water", "chance", 0.35):
			var r := _water_r(t)
			var at: Vector2 = t.position + Vector2(rng.randf_range(-0.5, 0.5) * r, rng.randf_range(-0.2, 0.2) * r)
			add_mark("ride", at, 1.6, col(_region_of(at), "eau"), rng.randf_range(0.35, 0.6), 1.0)
			break


# ---------------------------------------------------------------- Flétris et projectiles

func _enemies(p) -> void:
	var near: Array = main.enemies_near(p.position, _num("enemies", "radius", 650.0), false)
	var ash_left := _qty(int(_num("enemies", "ash_per_tick", 3)))
	var elites := 0
	var seen := {}
	var dt := _num("enemies", "every", 0.15)
	for i in mini(near.size(), int(_num("enemies", "max", 40))):
		var e = near[i]
		var id: int = e.get_instance_id()
		seen[id] = true
		var last: Vector2 = _last_pos.get(id, e.position)
		_last_pos[id] = e.position
		var spd: float = last.distance_to(e.position) / dt
		# Boss et Flétris : seules la position et le rayon sont sûrs (les boss n'ont ni état ni pas).
		var er := float(e.get("radius") if e.get("radius") != null else 20.0)
		var feet: Vector2 = e.position + Vector2(0.0, er * 0.6)
		# Cendre sous les pas, sur la terre vivante.
		if spd > 20.0 and ash_left > 0 and main.ground.life_at(feet) > 0.45:
			_ash_n += 1
		if spd > 20.0 and ash_left > 0 and main.ground.life_at(feet) > 0.45 and _ash_n % 2 == 0:
			ash_left -= 1
			add_mark("cendre", feet + Vector2(rng.randf_range(-4, 4), 0), _num("enemies", "ash_time", 2.6), col(_region_of(feet), "cendre"), clampf(er / 16.0, 0.6, 1.6), 0.0)
		# Charge : bien plus vite que son pas, ou un état de charge.
		var st := str(e.get("state") if e.get("state") != null else "")
		var pace := float(e.get("speed") if e.get("speed") != null else 100.0)
		if (spd > maxf(pace * 1.7, 160.0) or st.contains("charge") or st.contains("dash")) and _ready_again(e, 0.25):
			var dir: Vector2 = (e.position - last).normalized() if spd > 1.0 else Vector2.RIGHT
			world_fx.disturb(feet, 40.0 + er, dir, 1.3)
			react("charge", feet, 1.0)
		# Élite : les plantes se tordent autour.
		if e.get("elite") == true and elites < 2:
			elites += 1
			push(e.position, 70.0 + er * 2.0, -0.55)
		# La faune fuit.
		for a in fauna:
			if a["pos"].distance_squared_to(e.position) < pow(_scare_r(a) * 0.8, 2):
				_flee(a, e.position)
	for id in _last_pos.keys():
		if not seen.has(id):
			_last_pos.erase(id)


## L'herbe est fauchée le long des projectiles en vol.
func _projectiles() -> void:
	var p = _player()
	var layer = main.projectiles_layer
	if layer == null:
		return
	var n := 0
	var lim := _qty(int(_num("projectiles", "max", 8)))
	for sh in layer.get_children():
		if n >= lim:
			break
		var v = sh.get("vel")
		if not (v is Vector2) or v.length_squared() < 400.0 or not (sh is Node2D):
			continue
		if sh.position.distance_squared_to(p.position) > 600.0 * 600.0:
			continue
		n += 1
		world_fx.disturb(sh.position + Vector2(0, 6), _num("projectiles", "radius", 18.0), v.normalized(), 1.0)


# ---------------------------------------------------------------- faune et formes guéries

var _keep_clock := 0.0
var _recent: Array = []


## Atlas de couleur utiles : la région du héros, « commun » et celles où des bêtes sont encore ; refaits si le
## mode daltonien change.
func _ensure_sheets(delta: float) -> void:
	if not Vie.sheets.is_empty() and Vie.baked_mode != Art.mode_daltonien:
		Vie.invalidate()
	_keep_clock -= delta
	if _keep_clock > 0.0:
		return
	_keep_clock = 0.5
	# Seules les régions qui ont des bêtes (leur naissance a lieu à 260-620 px du héros : l'atlas a le temps de cuire).
	var want: Array = []
	for a in fauna:
		if not (a["reg"] in want):
			want.append(a["reg"])
	# Gardés (sans être cuits d'avance) : l'atlas du héros et celui des communs, pour ne pas les refaire à chaque bête.
	# Les trois dernières régions vues restent aussi (aller-retour à la frontière : pas de nouvelle cuisson).
	for r in want:
		_recent.erase(r)
		_recent.push_front(r)
	if _recent.size() > 3:
		_recent.resize(3)
	Vie.keep(want + _recent + [_region, "commun"])
	for r in want:
		Vie.bake(self, r)


## Réglages d'une bête : sa section de feel.json (faune › espèce, ou « gueri » pour une forme guérie).
func _beast_cfg(a: Dictionary) -> Dictionary:
	if a.get("gueri", false):
		return cfg.get("gueri", {})
	return cfg.get("fauna", {}).get(a["sp"], {})


## Dessin d'une bête (hauteur, vitesse de marche, poses) : lu dans le script de sa région.
func _beast_info(a: Dictionary) -> Dictionary:
	return Vie.info(a["reg"], a["key"])


func _scare_r(a: Dictionary) -> float:
	return float(_beast_cfg(a).get("scare", 90.0))


## Vitesse de marche d'une bête (px/s) et de fuite.
func _walk_speed(a: Dictionary) -> float:
	var fc := _beast_cfg(a)
	if a.get("gueri", false):
		return float(_beast_info(a).get("v", 30.0))
	return float(fc.get("speed", 30.0))


func _flee_speed(a: Dictionary) -> float:
	var fc := _beast_cfg(a)
	if a.get("gueri", false):
		return maxf(float(fc.get("flee_min", 90.0)), _walk_speed(a) * float(fc.get("flee_mult", 4.5)))
	return float(fc.get("flee_speed", 200.0))


## Une bête neuve : « sp » de la faune de « reg » (ou forme guérie de la sorte « sp » si « gueri »), posée en « at ».
## Les bêtes nées sur la terre flétrie sont ternes ; une forme guérie ne naît que sur la terre ravivée.
func make_beast(sp: String, gueri: bool, at: Vector2, reg: String) -> Dictionary:
	var info := Vie.info(reg, Vie.key(sp, gueri))
	var poses: Dictionary = info.get("poses", {})
	var fc: Dictionary = cfg.get("gueri", {}) if gueri else cfg.get("fauna", {}).get(sp, {})
	var move := str(fc.get("move", "dash"))
	if gueri:
		move = "flutter" if poses.has("vol") and not poses.has("marche") else "dash"
	var life := 1.0
	if main != null and main.get("ground") != null:
		life = main.ground.life_at(at)
	var z := 0.0
	match move:
		"flutter":
			z = rng.randf_range(14.0, 30.0)
		"glow":
			z = rng.randf_range(20.0, 34.0)
		"glide":
			z = rng.randf_range(90.0, 130.0)
	return {"sp": sp, "key": Vie.key(sp, gueri), "reg": reg, "gueri": gueri, "move": move, "pos": at, "z": z,
		"state": "repos", "t": rng.randf() * 4.0, "timer": rng.randf_range(0.5, 3.0), "home": at, "dest": at,
		"v": Vector2.ZERO, "face": 1.0 if rng.randf() < 0.5 else -1.0,
		"col": Color.WHITE if (gueri or life > 0.45) else Color(0.68, 0.64, 0.7), "seed": rng.randf() * TAU, "vz": 0.0, "ph": 0.0}


func _fauna_spawn(p) -> void:
	var cap := _qty(int(_num("caps", "fauna", 10)))
	var cap_g := _qty(int(_num("caps", "gueri", 5)))
	var far := _num("near", "despawn", 1000.0)
	fauna = fauna.filter(func(a): return a["pos"].distance_squared_to(p.position) < far * far)
	var n_g := 0
	for a in fauna:
		if a["gueri"]:
			n_g += 1
	var n_f := fauna.size() - n_g
	var at: Vector2 = p.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(260.0, 620.0)
	if main.has_method("clamp_to_world"):
		at = main.clamp_to_world(at)
	var reg := _region_of(at)
	var life: float = main.ground.life_at(at)
	# Une forme guérie une fois sur trois quand la terre est ravivée ; sinon la faune de la région.
	if life > float(cfg.get("gueri", {}).get("min_life", 0.6)) and n_g < cap_g and rng.randf() < float(cfg.get("gueri", {}).get("chance", 0.4)):
		_spawn_gueri(at, reg, cap_g - n_g)
		return
	if n_f >= cap:
		return
	var list: Array = _region_cfg(reg).get("fauna", [])
	if list.is_empty():
		return
	var sp: String = list[rng.randi() % list.size()]
	if not (sp in Vie.faune_ids(reg)):
		return
	var fc: Dictionary = cfg.get("fauna", {}).get(sp, {})
	if life < float(fc.get("min_life", 0.0)) or life > float(fc.get("max_life", 1.1)):
		return
	var count := rng.randi_range(int(fc.get("group", [1, 1])[0]), int(fc.get("group", [1, 1])[1]))
	for i in count:
		if n_f >= cap:
			break
		n_f += 1
		var q := at + Vector2(rng.randf_range(-30, 30), rng.randf_range(-16, 16))
		fauna.append(make_beast(sp, false, q, reg))


## Une forme guérie (le plus souvent d'une sorte de la région, parfois d'un Flétri commun) naît en « at ».
func _spawn_gueri(at: Vector2, reg: String, room: int) -> void:
	var src := reg
	var ids: Array = Vie.gueri_ids(reg)
	var share := float(cfg.get("gueri", {}).get("commun", 0.35))
	if ids.is_empty() or rng.randf() < share:
		src = "commun"
		ids = Vie.gueri_ids("commun")
	if ids.is_empty():
		return
	var sp: String = ids[rng.randi() % ids.size()]
	var g: Array = cfg.get("gueri", {}).get("group", [1, 2])
	for i in mini(rng.randi_range(int(g[0]), int(g[1])), room):
		var q := at + Vector2(rng.randf_range(-34, 34), rng.randf_range(-18, 18))
		fauna.append(make_beast(sp, true, q, src))


func _flee(a: Dictionary, from: Vector2) -> void:
	if a["state"] == "fuite":
		return
	var away: Vector2 = (a["pos"] - from).normalized() if a["pos"].distance_squared_to(from) > 1.0 else Vector2.UP
	var fc := _beast_cfg(a)
	a["state"] = "fuite"
	a["timer"] = float(fc.get("away", 3.0))
	var spd := _flee_speed(a)
	match a["move"]:
		"hop":
			a["vz"] = 120.0
			a["timer"] = 0.45
			a["v"] = away * 110.0
		"flutter", "glow", "glide", "perch":
			a["v"] = (away + Vector2(rng.randf_range(-0.4, 0.4), -0.3)).normalized() * spd
		_:
			a["v"] = away.rotated(rng.randf_range(-0.4, 0.4)) * spd
	a["face"] = signf(a["v"].x) if absf(a["v"].x) > 1.0 else a["face"]


func _update_fauna(p, delta: float) -> void:
	for a in fauna:
		a["t"] += delta
		a["timer"] -= delta
		match a["move"]:
			"hop":
				_upd_hop(a, p, delta)
			"perch":
				_upd_perch(a, p, delta)
			"glide":
				_upd_glide(a, p, delta)
			"flutter", "glow":
				_upd_flutter(a, delta)
			_:
				_upd_walk(a, delta)


## Bondisseur (rainette, grenouille) : saute de temps en temps, s'éclabousse en retombant près de l'eau.
func _upd_hop(a: Dictionary, _p, delta: float) -> void:
	if a["state"] == "repos":
		if a["timer"] <= 0.0:
			a["timer"] = rng.randf_range(3.0, 7.0)
			a["state"] = "fuite"
			a["vz"] = 90.0
			a["v"] = Vector2.from_angle(rng.randf() * TAU) * 50.0
			a["face"] = signf(a["v"].x) if absf(a["v"].x) > 1.0 else a["face"]
		return
	a["pos"] += a["v"] * delta
	a["vz"] -= 520.0 * delta
	a["z"] = maxf(0.0, a["z"] + a["vz"] * delta)
	if a["z"] <= 0.0 and a["vz"] < 0.0:
		a["z"] = 0.0
		a["state"] = "repos"
		a["timer"] = rng.randf_range(1.5, 4.0)
		if a["sp"] == "grenouille" and rng.randf() < 0.3:
			splash(a["pos"], 0.4)


## Oiseau posé (fauvette, alouette, colombe, pic) : picore, sautille ; s'envole si on approche, revient se poser plus loin.
func _upd_perch(a: Dictionary, p, delta: float) -> void:
	match a["state"]:
		"repos":
			if a["timer"] <= 0.0:
				a["timer"] = rng.randf_range(0.8, 2.4)
				if rng.randf() < 0.4:
					a["face"] = -a["face"]
				a["pos"] += Vector2(a["face"] * rng.randf_range(4.0, 10.0), rng.randf_range(-3.0, 3.0))
		"fuite":
			a["pos"] += a["v"] * delta
			a["v"] *= 1.0 + 0.6 * delta
			a["z"] = minf(a["z"] + 120.0 * delta, 220.0)
			if a["timer"] <= 0.0:
				a["state"] = "retour"
				# Revient se poser plus loin, hors de portée du héros.
				a["home"] = p.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(240.0, 420.0)
				a["pos"] = a["home"] + (a["pos"] - a["home"]).normalized() * 520.0
		"retour":
			var to: Vector2 = a["home"] - a["pos"]
			var d := to.length()
			a["face"] = signf(to.x) if absf(to.x) > 1.0 else a["face"]
			a["pos"] += to.normalized() * minf(d, 180.0 * delta)
			a["z"] = minf(a["z"], d * 0.35)
			if d < 2.0:
				a["state"] = "repos"
				a["z"] = 0.0
				a["timer"] = rng.randf_range(1.0, 3.0)


## Voilier (martinet) : tourne sans cesse en l'air autour de son point d'attache ; fuit vite, puis revient.
func _upd_glide(a: Dictionary, p, delta: float) -> void:
	match a["state"]:
		"repos":
			var u: float = a["t"] * 0.45 + a["seed"]
			var tgt: Vector2 = a["home"] + Vector2(cos(u) * 90.0, sin(u) * 40.0)
			var dv: Vector2 = tgt - a["pos"]
			a["face"] = signf(dv.x) if absf(dv.x) > 0.5 else a["face"]
			a["pos"] += dv * minf(1.0, delta * 3.0)
			a["z"] = 105.0 + 14.0 * sin(a["t"] * 0.8 + a["seed"])
		"fuite":
			a["pos"] += a["v"] * delta
			a["v"] *= 1.0 + 0.5 * delta
			a["z"] = minf(a["z"] + 50.0 * delta, 200.0)
			if a["timer"] <= 0.0:
				a["state"] = "retour"
				a["home"] = p.position + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(260.0, 460.0)
				a["pos"] = a["home"] + (a["pos"] - a["home"]).normalized() * 560.0
		"retour":
			var to: Vector2 = a["home"] - a["pos"]
			var d := to.length()
			a["face"] = signf(to.x) if absf(to.x) > 1.0 else a["face"]
			a["pos"] += to.normalized() * minf(d, 200.0 * delta)
			if d < 4.0:
				a["state"] = "repos"
				a["timer"] = rng.randf_range(1.0, 3.0)


## Voletant (papillon, libellule, luciole, formes guéries ailées) : flotte autour de son point d'attache, fuit en montant.
func _upd_flutter(a: Dictionary, delta: float) -> void:
	if a["state"] == "fuite":
		a["pos"] += a["v"] * delta
		a["v"] *= 1.0 + 0.6 * delta
		a["z"] = minf(a["z"] + 40.0 * delta, 90.0)
		if a["timer"] <= 0.0:
			a["state"] = "repos"
			a["home"] = a["pos"]
			a["v"] = Vector2.ZERO
		return
	var s: float = a["seed"]
	var tt: float = a["t"]
	var amp := float(_beast_cfg(a).get("amp", 1.0))
	if a["move"] == "glow":
		a["pos"] = a["pos"].lerp(a["home"] + Vector2(sin(tt * 0.4 + s) * 34.0, cos(tt * 0.5 + s) * 18.0), minf(1.0, delta))
		a["z"] = 26.0 + 10.0 * sin(tt * 0.9 + s)
		return
	var tgt: Vector2 = a["home"] + Vector2(sin(tt * 0.7 + s) * 46.0 * amp, sin(tt * 1.1 + s * 2.0) * 22.0 * amp)
	var dv: Vector2 = tgt - a["pos"]
	a["face"] = signf(dv.x) if absf(dv.x) > 0.5 else a["face"]
	a["pos"] += dv * minf(1.0, delta * 2.0)
	a["z"] = 20.0 + 8.0 * sin(tt * 2.3 + s)


## Marcheur (coccinelle, escargot, triton, lièvre, écureuil, formes guéries) : erre près de chez lui par petits trajets,
## s'enfuit droit devant s'il est surpris, puis revient lentement (sauf les rampants, qui s'installent là où ils sont).
func _upd_walk(a: Dictionary, delta: float) -> void:
	var spd := _walk_speed(a)
	var info := _beast_info(a)
	var stride := maxf(float(info.get("h", 30.0)) * 0.2, 4.0)
	match a["state"]:
		"repos":
			if a["timer"] <= 0.0:
				var r := 36.0 if a["move"] == "crawl" else 70.0
				a["dest"] = a["home"] + Vector2(rng.randf_range(-r, r), rng.randf_range(-r * 0.5, r * 0.5))
				a["state"] = "marche"
				a["timer"] = 8.0
		"marche", "retour":
			var to: Vector2 = a["dest"] - a["pos"]
			var d := to.length()
			var sp := spd * (2.4 if a["state"] == "retour" else 1.0)
			if d > 1.0:
				a["face"] = signf(to.x) if absf(to.x) > 1.0 else a["face"]
				a["pos"] += to.normalized() * minf(d, sp * delta)
				a["ph"] += sp * delta / stride
			if d < 2.0 or a["timer"] <= 0.0:
				a["state"] = "repos"
				a["timer"] = rng.randf_range(1.5, 4.5)
		"fuite":
			a["pos"] += a["v"] * delta
			a["ph"] += a["v"].length() * delta / stride
			if a["timer"] <= 0.0:
				a["v"] = Vector2.ZERO
				if a["move"] == "crawl":
					a["home"] = a["pos"]
					a["state"] = "repos"
					a["timer"] = rng.randf_range(1.0, 3.0)
				else:
					a["dest"] = a["home"]
					a["state"] = "retour"
					a["timer"] = 14.0


# ---------------------------------------------------------------- débris et marques

func _update_bits(delta: float) -> void:
	var g := _num("bits", "gravity", 260.0)
	for b in bits:
		b["t"] += delta
		if b["z"] > 0.0 or b["vz"] > 0.0:
			var fl: float = b["flutter"]
			# Les feuilles planent (chute freinée, va-et-vient) ; les cailloux tombent.
			b["vz"] -= g * delta * (0.32 if fl > 0.0 else 1.0)
			if fl > 0.0:
				b["vz"] = maxf(b["vz"], -40.0)
				b["pos"] += Vector2(sin(b["t"] * 4.0 + b["seed"]) * 30.0 * fl * delta, 0.0)
			b["z"] = b["z"] + b["vz"] * delta
			b["pos"] += b["v"] * delta
			b["rot"] += b["vr"] * delta * (0.5 if fl > 0.0 else 1.0)
			if b["z"] <= 0.0:
				b["z"] = 0.0
				if fl <= 0.0 and b["vz"] < -60.0:
					b["vz"] = -b["vz"] * 0.3
					b["v"] *= 0.5
				else:
					b["vz"] = 0.0
					b["v"] = Vector2.ZERO
		if b["f"] == "spore":
			# Les spores remontent doucement.
			b["z"] += 10.0 * delta
	bits = bits.filter(func(b): return b["t"] < b["dur"])


func _update_marks(delta: float) -> void:
	for m in marks:
		m["t"] += delta
	marks = marks.filter(func(m): return m["t"] < m["dur"])


# ---------------------------------------------------------------- dessin

func _quad(f: String, pos: Vector2, s: float, rot: float, c: Color, flip := false, sy := 1.0) -> void:
	var src := Atlas.rect(f)
	var tsz := Vector2(Atlas.tex.get_width(), Atlas.tex.get_height())
	var h := Atlas.CELL * 0.5 * s
	var cs := cos(rot)
	var sn := sin(rot)
	var base := _pts.size()
	var corners := [Vector2(-h, -h * sy), Vector2(h, -h * sy), Vector2(h, h * sy), Vector2(-h, h * sy)]
	var uv := [src.position, src.position + Vector2(src.size.x, 0), src.position + src.size, src.position + Vector2(0, src.size.y)]
	for i in 4:
		var q: Vector2 = corners[i]
		_pts.append(pos + Vector2(q.x * cs - q.y * sn, q.x * sn + q.y * cs))
		_cols.append(c)
		var u: Vector2 = uv[(i ^ 1) if flip else i]
		_uvs.append(u / tsz)
	_idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


func _flush(ci: CanvasItem) -> void:
	if not _idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _idx, _pts, _cols, _uvs, PackedInt32Array(), PackedFloat32Array(), Atlas.tex.get_rid())
	_pts.clear()
	_cols.clear()
	_uvs.clear()
	_idx.clear()


## Calque du sol : marques, débris posés, faune au sol et ombres de ce qui vole.
func _draw() -> void:
	if still or not Atlas.ready():
		return
	for m in marks:
		var u: float = m["t"] / m["dur"]
		var c: Color = m["col"]
		var fade := 1.0 - smoothstep(0.55, 1.0, u)
		var s: float = m["s"] * (1.0 + m["grow"] * u)
		match m["f"]:
			"fleur_pas":
				s *= Anim.pop(clampf(u / 0.12, 0.0, 1.0))
			"ride", "eclabous":
				fade = 1.0 - u
		_quad(m["f"], m["pos"], s, 0.0, Color(c, c.a * fade), false, 1.0)
	var shadow := Color(Art.c("ombre"), 0.22)
	for b in bits:
		if b["z"] <= 0.5:
			_quad(b["f"], b["pos"], b["s"] * 0.85, b["rot"], Color(b["col"], _bit_alpha(b)), false, 0.6)
		elif b["z"] < 80.0:
			_quad("cendre", b["pos"], 0.22 * b["s"], 0.0, Color(shadow, 0.5 * _bit_alpha(b)))
	_draw_beasts(false, shadow)
	_flush(self)
	_flush_beasts(self)


func _bit_alpha(b: Dictionary) -> float:
	var u: float = b["t"] / b["dur"]
	return 1.0 - smoothstep(0.7, 1.0, u)


## Calque du dessus : débris en l'air, faune qui vole, lucioles.
func _draw_air(ci: CanvasItem) -> void:
	if still or not Atlas.ready():
		return
	for b in bits:
		if b["z"] > 0.5:
			var sy := 1.0
			if b["flutter"] > 0.0:
				sy = 0.35 + 0.65 * absf(sin(b["t"] * 5.0 + b["seed"]))
			_quad(b["f"], b["pos"] + Vector2(0, -b["z"]), b["s"], b["rot"], Color(b["col"], _bit_alpha(b)), false, sy)
	_draw_beasts(true, Color.WHITE)
	_flush(ci)
	_flush_beasts(ci)


# --- Dessin des bêtes : quadrilatères texturés de l'atlas de leur région, un appel de rendu par région.
var _vb := {}   # région -> {pts, cols, uvs, idx}


func _vquad(reg: String, src: Rect2, at: Vector2, scale: float, flip: bool, c: Color) -> void:
	var sh = Vie.sheet(reg)
	var tsz := Vector2(sh.tex.get_width(), sh.tex.get_height())
	if not _vb.has(reg):
		_vb[reg] = {"pts": PackedVector2Array(), "cols": PackedColorArray(), "uvs": PackedVector2Array(), "idx": PackedInt32Array()}
	var q: Dictionary = _vb[reg]
	var base: int = q["pts"].size()
	var x0 := -Vie.ANCHOR.x
	var x1 := Vie.CELL - Vie.ANCHOR.x
	var y0 := -Vie.ANCHOR.y
	var y1 := Vie.CELL - Vie.ANCHOR.y
	var corners := [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]
	var uv := [src.position, src.position + Vector2(src.size.x, 0), src.position + src.size, src.position + Vector2(0, src.size.y)]
	for i in 4:
		var k: Vector2 = corners[i]
		q["pts"].append(at + Vector2(-k.x if flip else k.x, k.y) * scale)
		q["cols"].append(c)
		q["uvs"].append(uv[i] / tsz)
	q["idx"].append_array([base, base + 1, base + 2, base, base + 2, base + 3])


func _flush_beasts(ci: CanvasItem) -> void:
	for reg in _vb:
		var q: Dictionary = _vb[reg]
		if not q["idx"].is_empty() and Vie.ready(reg):
			RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), q["idx"], q["pts"], q["cols"], q["uvs"], PackedInt32Array(), PackedFloat32Array(), Vie.sheet(reg).tex.get_rid())
		q["pts"].clear()
		q["cols"].clear()
		q["uvs"].clear()
		q["idx"].clear()


## Pose et image d'une bête à cet instant : [pose, numéro], ou [] si rien n'est dessiné pour elle.
func _beast_pose(a: Dictionary) -> Array:
	var reg: String = a["reg"]
	var k: String = a["key"]
	var move: String = a["move"]
	var pose := "repos"
	var i := 0
	var airborne: bool = a["z"] > 1.0
	match move:
		"flutter", "glow", "glide":
			pose = "vol"
			i = int(fmod(a["t"] * (14.0 if a["state"] == "fuite" else 9.0) + a["seed"] * 3.0, 4.0))
		"perch":
			if airborne:
				pose = "vol"
				i = int(fmod(a["t"] * 12.0 + a["seed"], 4.0))
			else:
				i = int(fmod(a["t"] * 1.7 + a["seed"], 2.0) > 1.6)
		"hop":
			if airborne:
				pose = "saut"
				i = 0 if a["vz"] > 0.0 else 1
			else:
				i = int(a["t"] * 0.8 + a["seed"]) % 2
		_:
			if a["state"] != "repos":
				pose = "marche"
				i = int(a["ph"])
			else:
				i = int(a["t"] * 0.8 + a["seed"]) % 2
	var n := Vie.count(reg, k, pose)
	if n == 0:
		pose = "repos" if Vie.count(reg, k, "repos") > 0 else ("vol" if Vie.count(reg, k, "vol") > 0 else "marche")
		n = Vie.count(reg, k, pose)
		if n == 0:
			return []
	return [pose, i % n]


## Bêtes d'un calque : « air » pour ce qui vole (corps au-dessus des acteurs), sinon celles du sol (rangées par
## profondeur) ; les ombres de ce qui vole sont sur le sol.
func _draw_beasts(air_layer: bool, shadow: Color) -> void:
	var list := fauna
	if not air_layer:
		list = fauna.duplicate()
		list.sort_custom(func(x, y): return x["pos"].y < y["pos"].y)
	for a in list:
		var reg: String = a["reg"]
		if not Vie.ready(reg):
			continue
		var pi := _beast_pose(a)
		if pi.is_empty():
			continue
		var h := Vie.height_of(reg, a["key"])
		var flying: bool = a["z"] > 1.0 or a["move"] in ["flutter", "glow", "glide"]
		if not air_layer:
			# Ombre sous tout ce qui est posé ou qui vole.
			var sz := clampf(h * 0.028, 0.35, 1.5)
			var lift := clampf(1.0 - a["z"] / 140.0, 0.25, 1.0)
			if _is_dim(a):
				sz *= 0.9
			var cs := Color(shadow, 0.5 * lift) if flying else Color(shadow, 0.9)
			_quad("cendre", a["pos"], sz * (0.55 if flying else 1.0), 0.0, cs)
			if flying:
				continue
		elif not flying:
			continue
		var at: Vector2 = a["pos"] + Vector2(0, -a["z"])
		var c: Color = a["col"]
		_vquad(reg, Vie.frame(reg, a["key"], pi[0], pi[1]), at, 1.0, a["face"] < 0.0, c)
		if a["move"] == "glow" and air_layer:
			# Lueur de la luciole : un halo qui palpite autour de sa lanterne (additif).
			var blink := 0.5 + 0.5 * sin(a["t"] * 2.6 + a["seed"] * 3.0)
			var gc := col(a["reg"], "luciole")
			var lamp := at + Vector2(-3.0 * (1.0 if a["face"] >= 0.0 else -1.0), -h * 0.4)
			_quad("lueur", lamp, 0.55 + 0.25 * blink, 0.0, Color(gc.r * blink * 0.3, gc.g * blink * 0.3, gc.b * blink * 0.3, 0.0))


## Bête terne (terre flétrie) ?
func _is_dim(a: Dictionary) -> bool:
	return a["col"] != Color.WHITE


# ---------------------------------------------------------------- régions

func _region_of(pos: Vector2) -> String:
	var r := Regions.region_at(pos)
	return r if r != "" else "ronce"


## Réactions propres d'une région : res://scripts/world_art/<région>_vivant.gd (facultatif).
func _hook(reg: String):
	if not _region_hooks.has(reg):
		var path := "res://scripts/world_art/%s_vivant.gd" % reg
		_region_hooks[reg] = load(path) if ResourceLoader.exists(path) else null
	return _region_hooks[reg]
