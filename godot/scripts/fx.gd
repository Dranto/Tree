## Effets visuels éphémères (ondes, textes flottants, particules) et nuages de spores,
## et ressenti des coups : secousse d'écran et micro-pause (« hit stop »).
## « Réduire les effets » (options) coupe la secousse et la micro-pause et allège les particules.
extends Node2D

## Nombre maximal de particules et de textes en même temps (garde le dessin léger dans la foule).
const MAX_PARTICLES := 160
const MAX_TEXTS := 28
## Secousse maximale (pixels) à pleine puissance, et vitesse à laquelle elle retombe.
const SHAKE_MAX := 16.0
const SHAKE_DECAY := 2.2
## Vitesse du jeu pendant une micro-pause, et délai minimal entre deux micro-pauses (secondes réelles).
const HITSTOP_SCALE := 0.05
const HITSTOP_COOLDOWN := 0.2

var main
var rings: Array = []
var texts: Array = []
var clouds: Array = []
var particles: Array = []
var font: Font
## Élément du coup en cours de résolution (posé par main.player_hit_enemy, lu par impact()).
var hit_element := ""
var _rng := RandomNumberGenerator.new()
var _trauma := 0.0
var _shake_t := 0.0
var _hitstop_left := 0.0
var _hitstop_cd := 0.0
## Vrai si la dernière image dessinait quelque chose (pour l'effacer une fois tout fini).
var drawn_something := false


func _ready() -> void:
	font = ThemeDB.fallback_font
	_rng.seed = 7071


func _exit_tree() -> void:
	# Ne jamais laisser le jeu au ralenti si la scène disparaît pendant une micro-pause.
	if _hitstop_left > 0.0:
		Engine.time_scale = 1.0


func ring(pos: Vector2, r0: float, r1: float, dur: float, color: Color, width := 4.0) -> void:
	rings.append({"pos": pos, "r0": r0, "r1": r1, "t": 0.0, "dur": dur, "color": color, "width": width})


func text(pos: Vector2, s: String, color: Color, size := 18, dur := 1.0) -> void:
	texts.append({"pos": pos, "s": s, "t": 0.0, "dur": dur, "color": color, "size": size, "pop": 0.0})


# --- Ressenti des coups ---

## Un coup touche un Flétri : étincelles, chiffre de dégâts, et (critique) secousse et micro-pause.
## element : élément du coup (charte) : il donne leur couleur aux étincelles ; vide, elles sont blanches.
func impact(pos: Vector2, amount: float, crit: bool, radius := 14.0, element := "") -> void:
	var reduce: bool = Settings.reduce_effects
	if element == "":
		element = hit_element
	if texts.size() < MAX_TEXTS and (crit or texts.size() < MAX_TEXTS * 2 / 3):
		var spot := pos + Vector2(_rng.randf_range(-10.0, 10.0), -radius - 8.0)
		var size := 22 + mini(int(amount / 12.0), 8) if crit else 14 + mini(int(amount / 18.0), 6)
		var col: Color = Art.c("or") if crit else Art.c("texte")
		text(spot, str(roundi(amount)), col, size, 0.95 if crit else 0.7)
		texts[-1]["pop"] = 0.12
	var n := 0 if reduce else (9 if crit else 4)
	var spark: Color = Art.ec(element, "clair") if element != "" else Art.c("or")
	if not crit and element == "":
		spark = Art.c("texte")
	for i in n:
		var a := _rng.randf() * TAU
		var v := _rng.randf_range(90.0, 260.0 if crit else 190.0)
		_particle(0, pos + Vector2.from_angle(a) * radius * 0.6, Vector2.from_angle(a) * v,
			_rng.randf_range(0.18, 0.34), 2.0 if crit else 1.5,
			spark if crit else spark.lerp(Art.c("texte"), 0.5), 0.0, 6.0)
	if crit:
		# L'impact marque le coup : une onde courte à la couleur de l'élément (anticipation : aucune).
		if not reduce:
			ring(pos, radius * 0.6, radius * 2.6, Anim.DUREE["eclair"] * 3.0, Color(spark, 0.85), 3.0)
		shake(0.32)
		hitstop(0.055)


## Un Flétri meurt : il part en cendres qui s'envolent, ou en pétales sur une terre vivante.
func death(pos: Vector2, radius: float, color: Color, on_living_land: bool) -> void:
	var n := 3 if Settings.reduce_effects else clampi(int(radius * 0.9), 8, 24)
	for i in n:
		var a := _rng.randf() * TAU
		var from := pos + Vector2.from_angle(a) * _rng.randf() * radius * 0.7
		if on_living_land:
			var petal: Color = [Color("f6b8c8"), Color("f7dfe6"), Color("f2d06b"), Color("e98aa5")][_rng.randi() % 4]
			_particle(2, from, Vector2.from_angle(a) * _rng.randf_range(30.0, 110.0) + Vector2(0, -40.0),
				_rng.randf_range(0.9, 1.5), _rng.randf_range(3.0, 5.0), petal, _rng.randf() * TAU, 1.6)
		else:
			var ash := color.lerp(Color("9a8f8a"), _rng.randf_range(0.2, 0.7))
			if _rng.randf() < 0.15:
				ash = Color("ff9a4a")
			_particle(1, from, Vector2.from_angle(a) * _rng.randf_range(20.0, 90.0) + Vector2(0, -60.0),
				_rng.randf_range(1.0, 1.8), _rng.randf_range(1.6, 3.2), ash, 0.0, 1.8)
	shake(0.1 + radius * 0.006)
	hitstop(0.04 if radius < 20.0 else 0.06)


## Le Porte-Graine encaisse un coup. frac : part de sa vie maximale perdue (0 à 1).
## Réponse immédiate : secousse (plus forte si le coup est gros), vignette rouge sur l'écran
## (screen_fx.gd) et quelques éclats rouges qui jaillissent de lui.
func player_hurt(frac := 0.1) -> void:
	shake(clampf(0.4 + frac * 1.6, 0.4, 0.9))
	if main != null and main.get("screen_fx") != null:
		main.screen_fx.hurt(frac)
	if Settings.reduce_effects or main == null or main.player == null:
		return
	var danger := Art.c("danger")
	for i in 7:
		var a := _rng.randf() * TAU
		_particle(0, main.player.position + Vector2.from_angle(a) * 10.0, Vector2.from_angle(a) * _rng.randf_range(110.0, 240.0),
			_rng.randf_range(0.16, 0.3), 2.0, danger, 0.0, 6.0)


## Ramassage : un petit éclat à la couleur de l'élément (bref : l'essence est le butin le plus fréquent).
## « vers » (position du monde) : des particules qui s'envolent vers cet endroit, pour un butin rare.
func pickup(pos: Vector2, element := "seve", count := 5, vers := Vector2.INF) -> void:
	if Settings.reduce_effects:
		count = mini(count, 2)
	var clair := Art.ec(element, "clair")
	var col := Art.ec(element)
	for i in count:
		var a := _rng.randf() * TAU
		if vers != Vector2.INF:
			# Une gerbe qui s'éparpille puis file vers le joueur (retour : la vie revient à lui).
			_particle(3, pos + Vector2.from_angle(a) * _rng.randf_range(24.0, 46.0), Vector2.from_angle(a) * _rng.randf_range(40.0, 120.0),
				_rng.randf_range(0.5, 0.8), _rng.randf_range(2.4, 3.8), clair if i % 2 == 0 else col, 0.0, 3.0)
		else:
			_particle(1, pos, Vector2.from_angle(a) * _rng.randf_range(30.0, 90.0) + Vector2(0, -30.0),
				_rng.randf_range(0.25, 0.4), _rng.randf_range(1.8, 2.8), clair if i % 2 == 0 else col, 0.0, 4.0)


## Ajoute à la secousse d'écran (0 à 1, cumulée). Sans effet si la secousse est coupée.
func shake(amount: float) -> void:
	if Settings.shake_strength() <= 0.0:
		return
	_trauma = minf(1.0, _trauma + amount)


## Fige le jeu un instant (en secondes réelles). Espacé par un délai pour ne pas saccader la foule.
func hitstop(dur: float) -> void:
	if Settings.reduce_effects or _hitstop_cd > 0.0 or _hitstop_left > 0.0:
		return
	if main != null and "benchmark" in main and main.benchmark:
		return
	_hitstop_left = dur
	_hitstop_cd = HITSTOP_COOLDOWN
	Engine.time_scale = HITSTOP_SCALE


## kind : 0 étincelle (trait), 1 cendre, 2 pétale, 3 lueur qui file vers le joueur. drag : freinage par seconde.
func _particle(kind: int, pos: Vector2, vel: Vector2, dur: float, size: float, color: Color, rot: float, drag: float) -> void:
	if particles.size() >= MAX_PARTICLES:
		return
	particles.append({"kind": kind, "pos": pos, "vel": vel, "t": 0.0, "dur": dur, "size": size,
		"color": color, "rot": rot, "drag": drag, "spin": _rng.randf_range(-4.0, 4.0), "ph": _rng.randf() * TAU})


func cloud(pos: Vector2, radius: float, dur: float, dps: float) -> void:
	clouds.append({"pos": pos, "radius": radius, "t": 0.0, "dur": dur, "dps": dps})


## Ondes et textes : purement visuels, ils suivent la fréquence d'affichage.
func _process(delta: float) -> void:
	# Micro-pause et secousse comptent en secondes réelles : delta est ralenti pendant la pause.
	var real := delta / maxf(Engine.time_scale, 0.01)
	_hitstop_cd -= real
	if _hitstop_left > 0.0:
		_hitstop_left -= real
		if _hitstop_left <= 0.0:
			Engine.time_scale = 1.0
	_update_shake(real)
	for list in [rings, texts, particles]:
		for e in list:
			e["t"] += delta
	rings = rings.filter(func(e): return e["t"] < e["dur"])
	texts = texts.filter(func(e): return e["t"] < e["dur"])
	particles = particles.filter(func(e): return e["t"] < e["dur"])
	for p in particles:
		var k: float = p["t"]
		p["vel"] = p["vel"] * maxf(0.0, 1.0 - p["drag"] * delta)
		if p["kind"] == 3 and main != null and main.player != null:
			# Particule qui rejoint le joueur : l'accélération grandit avec le temps.
			var to: Vector2 = main.player.position - p["pos"]
			p["vel"] += to.normalized() * (260.0 + 1600.0 * k) * delta
			if to.length() < 14.0:
				p["t"] = p["dur"]
		if p["kind"] == 2:
			# Un pétale tombe en tournoyant doucement.
			p["vel"] += Vector2(sin(k * 5.0 + p["ph"]) * 40.0, 70.0) * delta
			p["rot"] += p["spin"] * delta
		p["pos"] += p["vel"] * delta
	# Redessiné tant qu'il y a un effet, puis une dernière fois pour effacer le dernier.
	var busy := not (rings.is_empty() and texts.is_empty() and clouds.is_empty() and particles.is_empty())
	if busy or drawn_something:
		queue_redraw()
	drawn_something = busy


func _update_shake(real: float) -> void:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam == null:
		return
	var strength := Settings.shake_strength()
	if _trauma <= 0.0 or strength <= 0.0:
		_trauma = 0.0
		if cam.offset != Vector2.ZERO:
			cam.offset = Vector2.ZERO
		return
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY * real)
	_shake_t += real
	var amp := _trauma * _trauma * SHAKE_MAX * strength
	cam.offset = Vector2(sin(_shake_t * 61.0), cos(_shake_t * 53.0 + 1.7)) * amp


## Nuages de spores : ils infligent des dégâts, donc avancent à pas fixe (grille spatiale).
func _physics_process(delta: float) -> void:
	for c in clouds:
		c["t"] += delta
	clouds = clouds.filter(func(e): return e["t"] < e["dur"])
	for c in clouds:
		for e in main.enemies_near(c["pos"], c["radius"]):
			if not e.dead:
				e.take_damage(c["dps"] * delta, false, true)
				e.apply_poison(c["dps"] * 0.3, 1.0)


func _draw() -> void:
	for c in clouds:
		var k: float = c["t"] / c["dur"]
		var a := 0.22 * (1.0 - k * k)
		draw_circle(c["pos"], c["radius"], Color(0.55, 0.35, 0.75, a))
		draw_arc(c["pos"], c["radius"], 0.0, TAU, 48, Color(0.7, 0.5, 0.9, a * 2.0), 2.0)
	for e in rings:
		var k: float = e["t"] / e["dur"]
		var col: Color = e["color"]
		col.a *= 1.0 - k
		draw_arc(e["pos"], lerpf(e["r0"], e["r1"], k), 0.0, TAU, 56, col, e["width"])
	for p in particles:
		_draw_particle(p)
	for e in texts:
		var k: float = e["t"] / e["dur"]
		var col: Color = e["color"]
		col.a = 1.0 - k * k * k
		var lift := 34.0 * (1.0 - (1.0 - k) * (1.0 - k))
		var size: int = e["size"]
		if e["pop"] > 0.0 and e["t"] < e["pop"]:
			size = roundi(size * (1.0 + 0.45 * (1.0 - e["t"] / e["pop"])))
		var p: Vector2 = e["pos"] + Vector2(-200, -lift)
		# Ombre portée : les chiffres restent lisibles sur le sol clair comme sur la cendre.
		draw_string(font, p + Vector2(1.5, 2.0), e["s"], HORIZONTAL_ALIGNMENT_CENTER, 400, size, Color(0.04, 0.03, 0.05, 0.9 * col.a))
		draw_string(font, p, e["s"], HORIZONTAL_ALIGNMENT_CENTER, 400, size, col)


func _draw_particle(p: Dictionary) -> void:
	var k: float = p["t"] / p["dur"]
	var col: Color = p["color"]
	col.a *= 1.0 - k * k
	var pos: Vector2 = p["pos"]
	var sz: float = p["size"]
	match p["kind"]:
		0:
			var v: Vector2 = p["vel"]
			draw_line(pos, pos - v * 0.045, col, sz)
		1:
			draw_circle(pos, sz * (1.0 - 0.4 * k), col)
		3:
			draw_circle(pos, sz * 1.9, Color(col, col.a * 0.25))
			draw_circle(pos, sz, col)
		_:
			var a: float = p["rot"]
			# Le pétale pivote : sa largeur apparente oscille.
			var w := sz * (0.35 + 0.65 * absf(sin(a)))
			var d := Vector2.from_angle(a)
			var n := d.orthogonal()
			draw_colored_polygon(PackedVector2Array([pos + d * sz, pos + n * w * 0.6, pos - d * sz * 0.6, pos - n * w * 0.6]), col)
