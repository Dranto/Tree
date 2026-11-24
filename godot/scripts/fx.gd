## Effets visuels éphémères (ondes, textes flottants, particules) et nuages de spores,
## et ressenti des coups : secousse d'écran, arrêt sur image (« hit stop »), éclats, étoile des
## critiques, morts marquées. Dosage dans res://data/feel.json (réglages d'image seulement).
## Options (tâche K) : Settings.shake_strength(), flash_strength(), hitstop_strength() multiplient
## la secousse, les flashs et la durée des arrêts ; « Réduire les effets » coupe tout et allège les particules.
extends Node2D

## Nombre maximal de particules et de textes en même temps (garde le dessin léger dans la foule).
const MAX_PARTICLES := 160
const MAX_TEXTS := 28
## Secousse maximale (pixels) à pleine puissance, et vitesse à laquelle elle retombe.
const SHAKE_MAX := 16.0
const SHAKE_DECAY := 2.2
## Vitesse du jeu pendant une micro-pause, et délai minimal entre deux micro-pauses (secondes réelles),
## si data/feel.json ne les donne pas.
const HITSTOP_SCALE := 0.05
const HITSTOP_COOLDOWN := 0.2

const UiTheme = preload("res://scripts/ui_theme.gd")
const Content = preload("res://scripts/content.gd")

var main
var rings: Array = []
var texts: Array = []
var clouds: Array = []
var particles: Array = []
## Étoiles des coups critiques : rayons qui jaillissent puis s'éteignent (une forme, pas seulement une couleur).
var stars: Array = []
var font: Font
## Élément du coup en cours de résolution (posé par main.player_hit_enemy, lu par impact()).
var hit_element := ""
var _rng := RandomNumberGenerator.new()
var _trauma := 0.0
var _shake_t := 0.0
var _hitstop_left := 0.0
var _hitstop_cd := 0.0
## Nombre d'arrêts sur image réellement lancés et durée du dernier (lus par les tests).
var hitstops := 0
var last_hitstop := 0.0
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


## style : 0 discret (coup normal), 1 marqué (critique : gras, contour), 2 reçu (gras, contour, plus lent).
func text(pos: Vector2, s: String, color: Color, size := 18, dur := 1.0, style := 0) -> void:
	texts.append({"pos": pos, "s": s, "t": 0.0, "dur": dur, "color": color, "size": size, "pop": 0.0, "style": style})


# --- Ressenti des coups ---

## Réglage de data/feel.json (section, clé), ou la valeur par défaut.
func feel(section: String, key: String, default := 0.0) -> float:
	return float(Content.feel().get(section, {}).get(key, default))


## Un coup touche un Flétri (ou un boss) : éclats, chiffre de dégâts, et selon le coup, secousse et
## arrêt sur image. element : élément du coup (charte) : il donne leur couleur aux éclats ; vide,
## ils sont blancs. heavy : coup lourd (grosse part de la vie, voir feel.json › heavy). boss : la
## cible est un boss (moins d'éclats sur un coup normal, critique plus appuyé).
func impact(pos: Vector2, amount: float, crit: bool, radius := 14.0, element := "", heavy := false, boss := false) -> void:
	var reduce: bool = Settings.reduce_effects
	if element == "":
		element = hit_element
	_damage_number(pos, amount, crit, radius)
	var key := "crit" if crit else ("heavy" if heavy else "hit")
	if boss:
		key = "boss_crit" if crit else "boss_hit"
	var n := 0 if reduce else int(feel("sparks", key, 4.0))
	var spark: Color = Art.ec(element, "clair") if element != "" else Art.c("or")
	if not crit and element == "":
		spark = Art.c("texte")
	var strong := crit or heavy
	for i in n:
		var a := _rng.randf() * TAU
		var v := _rng.randf_range(90.0, 260.0 if strong else 190.0)
		_particle(0, pos + Vector2.from_angle(a) * radius * 0.6, Vector2.from_angle(a) * v,
			_rng.randf_range(0.18, 0.34), 2.0 if strong else 1.5,
			spark if strong else spark.lerp(Art.c("texte"), 0.5), 0.0, 6.0)
	if crit:
		# Le critique se reconnaît à sa forme : une étoile de rayons, plus une onde courte.
		if not reduce:
			ring(pos, radius * 0.6, radius * 2.6, Anim.DUREE["eclair"] * 3.0, Color(spark, 0.85), 3.0)
			star(pos, radius * feel("sparks", "crit_star", 2.4), int(feel("sparks", "crit_rays", 8.0)), Color(Art.c("butin"), 1.0))
		shake(feel("shake", "boss_crit" if boss else "crit", 0.32))
		hitstop(feel("hitstop", "boss_crit" if boss else "crit", 0.055))
	elif heavy:
		shake(feel("shake", "heavy", 0.16))
		hitstop(feel("hitstop", "heavy", 0.035))
	elif boss:
		shake(feel("shake", "boss_hit", 0.05))


## Chiffre de dégâts : le coup normal reste discret, le critique est gras, doré et plus grand.
func _damage_number(pos: Vector2, amount: float, crit: bool, radius: float) -> void:
	if not Settings.shows_number(crit) or texts.size() >= MAX_TEXTS or not (crit or texts.size() < MAX_TEXTS * 2 / 3):
		return
	var spot := pos + Vector2(_rng.randf_range(-10.0, 10.0), -radius - 8.0)
	if crit:
		var size := 26 + mini(int(amount / 12.0), 8)
		text(spot, "%d !" % roundi(amount), Art.c("butin"), size, 1.05, 1)
		texts[-1]["pop"] = 0.16
	else:
		var size := 13 + mini(int(amount / 25.0), 4)
		text(spot, str(roundi(amount)), Color(Art.c("texte"), 0.78), size, 0.6, 0)


## Étoile d'un critique : n rayons qui jaillissent jusqu'à r puis se rétractent.
func star(pos: Vector2, r: float, n: int, color: Color, dur := 0.22) -> void:
	if stars.size() >= 12:
		return
	stars.append({"pos": pos, "r": r, "n": maxi(n, 4), "t": 0.0, "dur": dur, "color": color, "rot": _rng.randf() * TAU})


## Un Flétri meurt : des traits jaillissent, une onde claire, puis il part en cendres qui
## s'envolent, ou en pétales sur une terre vivante. Une élite meurt plus fort : plus de traits,
## arrêt plus long, secousse et voile bref sur l'écran.
func death(pos: Vector2, radius: float, color: Color, on_living_land: bool, elite := false) -> void:
	var reduce: bool = Settings.reduce_effects
	var n := 3 if reduce else clampi(int(radius * 0.9), 8, 24)
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
	if not reduce:
		# Traits qui jaillissent du corps : la mort se lit même dans la foule.
		var streaks := int(feel("death", "elite_streaks" if elite else "streaks", 6.0))
		var light := Art.c("danger_eclair")
		for i in streaks:
			var a := TAU * (i + _rng.randf_range(-0.3, 0.3)) / streaks
			_particle(0, pos + Vector2.from_angle(a) * radius * 0.5, Vector2.from_angle(a) * _rng.randf_range(240.0, 420.0),
				_rng.randf_range(0.16, 0.26), 2.6 if elite else 2.0, Color(light, 0.95), 0.0, 7.0)
		ring(pos, radius * 0.4, radius * (2.0 if elite else 1.5), 0.18, Color(light, 0.9 * Settings.flash_strength()), 3.0 if elite else 2.0)
	if elite:
		shake(feel("shake", "elite_kill", 0.45))
		hitstop(feel("hitstop", "elite_kill", 0.11))
		screen_flash(Art.c("elite"), feel("death", "elite_flash", 0.22), 0.3)
		return
	shake(feel("shake", "kill_base", 0.1) + radius * feel("shake", "kill_per_radius", 0.006))
	hitstop(feel("hitstop", "kill_small", 0.035) if radius < 20.0 else feel("hitstop", "kill_big", 0.06))


## Un boss change de phase : onde, secousse et arrêt marqué (le combat change de rythme).
func boss_phase(pos: Vector2, radius: float) -> void:
	if not Settings.reduce_effects:
		ring(pos, radius * 0.8, radius * 3.0, 0.5, Color(Art.c("danger_eclair"), 0.9), 6.0)
	shake(feel("shake", "boss_phase", 0.6))
	hitstop(feel("hitstop", "boss_phase", 0.14))


## Un boss meurt : long arrêt sur image, pleine secousse, voile clair sur l'écran.
func boss_kill(pos: Vector2, radius: float) -> void:
	if not Settings.reduce_effects:
		star(pos, radius * 2.6, 12, Art.c("danger_eclair"), 0.5)
		ring(pos, radius * 0.6, radius * 4.0, 0.7, Color(Art.c("danger_eclair"), 0.9), 8.0)
	shake(feel("shake", "boss_kill", 1.0))
	hitstop(feel("hitstop", "boss_kill", 0.32))
	screen_flash(Art.c("danger_eclair"), feel("death", "boss_flash", 0.4), 0.5)


## Voile bref sur l'écran (screen_fx.gd), dosé par l'option des flashs.
func screen_flash(color: Color, alpha: float, dur: float) -> void:
	var a := alpha * Settings.flash_strength()
	if a <= 0.01 or main == null or main.get("screen_fx") == null:
		return
	main.screen_fx.glow(color, a, dur)


## Le Porte-Graine encaisse un coup. frac : part de sa vie maximale perdue (0 à 1).
## Réponse immédiate : secousse (plus forte si le coup est gros), vignette rouge sur l'écran
## (screen_fx.gd) et quelques éclats rouges qui jaillissent de lui.
## amount (> 0) : le chiffre des dégâts reçus, d'une autre couleur que ceux qu'on inflige.
func player_hurt(frac := 0.1, amount := 0.0, pos := Vector2.ZERO) -> void:
	shake(clampf(0.4 + frac * 1.6, 0.4, 0.9))
	if main != null and main.get("screen_fx") != null:
		main.screen_fx.hurt(frac)
	if amount > 0.0 and Settings.shows_number(true) and texts.size() < MAX_TEXTS:
		text(pos + Vector2(0, -34.0), "-%d" % roundi(amount), Color("ff6b5e"), 22 + mini(int(amount / 10.0), 8), 1.0, 2)
		texts[-1]["pop"] = 0.14
	if Settings.reduce_effects or main == null or main.player == null:
		return
	var danger := Art.c("danger")
	for i in 7:
		var a := _rng.randf() * TAU
		_particle(0, main.player.position + Vector2.from_angle(a) * 10.0, Vector2.from_angle(a) * _rng.randf_range(110.0, 240.0),
			_rng.randf_range(0.16, 0.3), 2.0, danger, 0.0, 6.0)


## Coup reçu puni (jalon 10 C) : étourdissement (éclat jaune pâle), sève perdue (goutte verte qui
## s'échappe) et soin bloqué (le texte l'annonce ; la barre de vie se grise, voir hud_widgets.gd).
func player_punished(pos: Vector2, stunned: bool, sap_lost: float, heal_blocked: bool) -> void:
	if stunned:
		ring(pos, 12.0, 54.0, 0.28, Art.c("or"), 4.0)
		if main != null and main.get("screen_fx") != null:
			main.screen_fx.glow(Color(Art.c("or"), 0.5), 0.35, 0.3)
		Sfx.play("etourdi")
	if Settings.shows_number(true) and texts.size() < MAX_TEXTS - 2:
		if sap_lost >= 1.0:
			text(pos + Vector2(26.0, -52.0), "Sève −%d" % roundi(sap_lost), Art.ec("seve"), 17, 1.1, 2)
		if heal_blocked and stunned:
			text(pos + Vector2(-26.0, -70.0), "étourdi", Art.c("or"), 16, 0.8, 2)
	if sap_lost >= 1.0 and not Settings.reduce_effects:
		for i in mini(4, 1 + int(sap_lost / 15.0)):
			var a := _rng.randf_range(-PI, 0.0)
			_particle(0, pos, Vector2.from_angle(a) * _rng.randf_range(60.0, 140.0), _rng.randf_range(0.4, 0.7), 3.0, Art.ec("seve"), 0.0, -40.0)


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


## Cendre qui reflue (fin de la dernière région, region_fanfare.gd) : des flocons gris qui partent
## autour de « pos » et dérivent dans la direction « dir » (vers la graine).
func ash_drift(pos: Vector2, dir: Vector2, count := 3) -> void:
	if Settings.reduce_effects:
		count = mini(count, 1)
	for i in count:
		var at := pos + Vector2(_rng.randf_range(-640.0, 640.0), _rng.randf_range(-380.0, 380.0))
		var grey := Color(0.36, 0.34, 0.33, 0.9).lerp(Color(0.55, 0.52, 0.5, 0.9), _rng.randf())
		_particle(1, at, dir * _rng.randf_range(160.0, 260.0), _rng.randf_range(1.4, 2.2), _rng.randf_range(2.4, 3.8), grey, 0.0, 0.2)


## Ajoute à la secousse d'écran (0 à 1, cumulée). Sans effet si la secousse est coupée.
func shake(amount: float) -> void:
	if Settings.shake_strength() <= 0.0:
		return
	_trauma = minf(1.0, _trauma + amount)


## Fige le jeu un instant (en secondes réelles). Espacé par un délai pour ne pas saccader la foule ;
## un arrêt fort (mort d'élite, boss) passe outre le délai et prolonge l'arrêt en cours.
func hitstop(dur: float) -> void:
	dur *= Settings.hitstop_strength()
	if dur <= 0.0:
		return
	if main != null and "benchmark" in main and main.benchmark:
		return
	var strong := dur >= feel("hitstop", "strong", 0.08)
	if _hitstop_left > 0.0:
		if strong and dur > _hitstop_left:
			_hitstop_left = dur
			last_hitstop = dur
		return
	if _hitstop_cd > 0.0 and not strong:
		return
	_hitstop_left = dur
	_hitstop_cd = feel("hitstop", "cooldown", HITSTOP_COOLDOWN)
	Engine.time_scale = feel("hitstop", "scale", HITSTOP_SCALE)
	hitstops += 1
	last_hitstop = dur


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
	for list in [rings, texts, particles, stars]:
		for e in list:
			e["t"] += delta
	rings = rings.filter(func(e): return e["t"] < e["dur"])
	stars = stars.filter(func(e): return e["t"] < e["dur"])
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
	var busy := not (rings.is_empty() and texts.is_empty() and clouds.is_empty() and particles.is_empty() and stars.is_empty())
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
		# Un nuage qui suit le joueur (Brouillard vivant) reste centré sur lui.
		var f = c.get("follow")
		if f != null and is_instance_valid(f):
			c["pos"] = f.position
		for e in main.enemies_near(c["pos"], c["radius"]):
			if not e.dead:
				e.take_damage(c["dps"] * delta, false, true)
				e.apply_poison(c["dps"] * 0.3, 1.0)


func _draw() -> void:
	for c in clouds:
		if c.has("dessin"):
			continue   # dessiné ailleurs (signature du Nuage de spores, skill_fx.gd)
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
	for e in stars:
		_draw_star(e)
	for e in texts:
		var k: float = e["t"] / e["dur"]
		var col: Color = e["color"]
		col.a = 1.0 - k * k * k
		var lift := 34.0 * (1.0 - (1.0 - k) * (1.0 - k))
		var size: int = e["size"]
		var style: int = e.get("style", 0)
		var f: Font = UiTheme.font(style > 0)
		if e["pop"] > 0.0 and e["t"] < e["pop"]:
			size = roundi(size * (1.0 + 0.45 * (1.0 - e["t"] / e["pop"])))
		var p: Vector2 = e["pos"] + Vector2(-200, -lift)
		# Ombre portée (et contour pour les chiffres marqués) : lisibles sur le sol clair comme sur la cendre.
		draw_string(f, p + Vector2(1.5, 2.0), e["s"], HORIZONTAL_ALIGNMENT_CENTER, 400, size, Color(0.04, 0.03, 0.05, 0.9 * col.a))
		if style > 0:
			draw_string_outline(f, p, e["s"], HORIZONTAL_ALIGNMENT_CENTER, 400, size, 4, Color(0.06, 0.03, 0.03, 0.95 * col.a))
		draw_string(f, p, e["s"], HORIZONTAL_ALIGNMENT_CENTER, 400, size, col)


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


## Étoile d'un critique : les rayons jaillissent vite (premier tiers), puis se rétractent en
## s'amincissant ; un rayon sur deux est plus court.
func _draw_star(e: Dictionary) -> void:
	var k: float = e["t"] / e["dur"]
	var out := Anim.ease_out(clampf(k * 3.0, 0.0, 1.0))
	var back := clampf((k - 0.33) / 0.67, 0.0, 1.0)
	var col: Color = e["color"]
	col.a *= 1.0 - back * back
	var n: int = e["n"]
	for i in n:
		var d := Vector2.from_angle(e["rot"] + TAU * i / n)
		var r: float = e["r"] * (1.0 if i % 2 == 0 else 0.55) * out
		var from: Vector2 = e["pos"] + d * r * back
		draw_line(from, e["pos"] + d * r, col, 3.0 * (1.0 - 0.6 * back), true)
