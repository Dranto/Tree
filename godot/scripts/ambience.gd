## Lumière et air du monde : cendres en suspension sur la terre morte, pollen, pétales et papillons sur la
## terre vivante, un air teinté par la région (flétri sombre et froid, ravivé clair et chaud, lumière d'en haut
## à gauche comme l'encre des créatures), une vignette, et du temps par région (pluie fine au Marais, rafales
## sur les Plateaux). Tout est dessiné par le code, rien ne change le jeu.
## « Réduire les effets » (options) garde un tiers des particules et du temps ; l'air et la vignette restent.
##
## Les couleurs de l'air viennent d'Art.MONDE_AIR et Art.AIR_ETAT. Le centre de l'écran reste presque intact :
## l'air ne retire jamais de contraste aux personnages.
##
## Une région peut avoir ses propres particules (data/audio.json › regions › <id> › ambience, voir
## region_audio.gd) : spores qui montent dans le marais, brins d'herbe et rafales sur les plateaux.
## Formes : point, halo, brin de vent, goutte (Sève), copeau de sciure (Racine), plume (Plateaux, « alt »).
## Une particule prend le style de la région où elle naît ; sans réglage, c'est la cendre et le pollen de Ronce.
extends Node2D

const RegionAudio = preload("res://scripts/region_audio.gd")
const Regions = preload("res://scripts/regions.gd")

const MOTES := 22
const BUTTERFLIES := 4
## Marge (pixels du monde) autour de l'écran où les particules naissent et disparaissent.
const MARGIN := 80.0
## Temps par région (calque simple, sous la limite de particules) : pluie fine, rafales.
const WEATHER := {"spore": "rain", "vent": "gust"}
const RAIN_DROPS := 40
const GUST_STREAKS := 16
## Durée d'une rafale et pause entre deux (secondes).
const GUST_LEN := 2.4
const GUST_GAP := Vector2(7.0, 14.0)
## Vitesse à laquelle l'air rejoint sa teinte cible (par seconde).
const AIR_RATE := 1.6
const BUTTERFLY_COLORS := [Color("f2d06b"), Color("e98aa5"), Color("9fd8e8"), Color("f4efd8"), Color("c9a2e8")]

var main
var motes: Array = []
var butterflies: Array = []
var vignette_layer: CanvasLayer
var air: Air
## Air actuel (rejoint doucement l'air cible) : teinte de la lumière + opacité du haut ; voile + opacité de
## la vignette ; opacité du bas ; opacité des rayons.
var _air_luz := Color(1, 1, 1, 0.0)
var _air_voile := Color(0.02, 0.03, 0.02, 0.4)
var _air_bas := 0.0
var _air_rays := 0.0
var _life := 0.0
var _life_timer := 0.0
var _region := "ronce"
## Temps : intensité de chaque calque (0 à 1) et rafale en cours.
var _rain := 0.0
var _gust := 0.0
var _gust_timer := 4.0
var _gust_t := -1.0
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _skip := false
## Papillons permis là où se trouve le joueur (faux dans les régions qui règlent « butterflies » à 0).
var _butterflies_ok := true
var _region_timer := 0.0


func _ready() -> void:
	_rng.seed = 4141
	z_index = 4
	_show_vignette(true)
	var rect := _view_rect()
	for i in MOTES:
		motes.append(_new_mote(rect, true))
	for i in BUTTERFLIES:
		butterflies.append({
			"pos": _random_in(rect), "heading": _rng.randf() * TAU, "ph": _rng.randf() * TAU,
			"color": BUTTERFLY_COLORS[i % BUTTERFLY_COLORS.size()], "size": _rng.randf_range(5.0, 7.0), "a": 0.0})


## L'air vit sur son propre calque. Quand l'arbre couvre l'écran, calque et texture disparaissent tout
## à fait : une texture ou un calque inutilisé coûte encore du temps de rendu à chaque image.
func _show_vignette(on: bool) -> void:
	if on and vignette_layer == null:
		vignette_layer = CanvasLayer.new()
		vignette_layer.layer = 2
		air = Air.new()
		air.luz = _air_luz
		air.voile = _air_voile
		air.bas = _air_bas
		air.rays = _air_rays
		vignette_layer.add_child(air)
		add_child(vignette_layer)
	elif not on and vignette_layer != null:
		vignette_layer.queue_free()
		vignette_layer = null
		air = null


## Air et vignette dessinés par le code : un dégradé de lumière (clair en haut à gauche, voilé en bas à droite),
## quelques rayons obliques, et quatre bandes le long des bords, sombres au bord et transparentes vers l'intérieur.
## Peu de surface à remplir ; le centre reste intact. Redessiné seulement quand l'air change.
class Air extends Control:
	const DEPTH := 0.13
	var luz := Color(1, 1, 1, 0.0)
	var voile := Color(0.02, 0.03, 0.02, 0.4)
	var bas := 0.0
	var rays := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var clear_l := Color(luz, 0.0)
		var clear_v := Color(voile, 0.0)
		if luz.a > 0.004 or bas > 0.004:
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([luz, clear_l, Color(voile, bas), clear_v]))
		if rays > 0.004:
			# Rayons obliques depuis le haut à gauche (même direction que la lumière commune).
			var d := -Art.LUMIERE_DIR * h * 1.25
			for i in 3:
				var x := w * (0.04 + 0.2 * i)
				var rw := 36.0 + 26.0 * (i % 2)
				draw_polygon(PackedVector2Array([Vector2(x, -10), Vector2(x + rw, -10), Vector2(x + rw * 2.2, -10) + d, Vector2(x, -10) + d]),
					PackedColorArray([Color(luz, rays), Color(luz, rays), Color(luz, 0.0), Color(luz, 0.0)]))
		var dark := voile
		var clear := Color(voile, 0.0)
		var d2 := h * DEPTH
		_strip(Vector2(0, 0), Vector2(w, 0), Vector2(w, d2), Vector2(0, d2), dark, clear)
		_strip(Vector2(0, h), Vector2(w, h), Vector2(w, h - d2), Vector2(0, h - d2), dark, clear)
		_strip(Vector2(0, 0), Vector2(0, h), Vector2(d2, h), Vector2(d2, 0), dark, clear)
		_strip(Vector2(w, 0), Vector2(w, h), Vector2(w - d2, h), Vector2(w - d2, 0), dark, clear)

	func _strip(a: Vector2, b: Vector2, c: Vector2, e: Vector2, edge: Color, inner: Color) -> void:
		draw_polygon(PackedVector2Array([a, b, c, e]), PackedColorArray([edge, edge, inner, inner]))


## Air visé là où se trouve le joueur : teinte et force du côté flétri et du côté ravivé, mêlées selon la vie
## de la terre sous ses pieds.
func _air_target() -> Array:
	var s := smoothstep(0.25, 0.75, _life)
	var f: Dictionary = Art.AIR_ETAT["fletri"]
	var r: Dictionary = Art.AIR_ETAT["ravive"]
	var af: Array = Art.air_de(_region, "fletri")
	var ar: Array = Art.air_de(_region, "ravive")
	var luz: Color = (af[0] as Color).lerp(ar[0], s)
	luz.a = lerpf(f["haut"], r["haut"], s)
	var voile: Color = (af[1] as Color).lerp(ar[1], s)
	voile.a = lerpf(f["vignette"], r["vignette"], s)
	return [luz, voile, lerpf(f["bas"], r["bas"], s), lerpf(f["rayons"], r["rayons"], s)]


func _step_air(delta: float) -> void:
	_life_timer -= delta
	if _life_timer <= 0.0:
		_life_timer = 0.25
		_region = Regions.region_at(main.player.position)
		_life = main.ground.life_at(main.player.position)
	var t := _air_target()
	var k := 1.0 - exp(-delta * AIR_RATE)
	var before := [_air_luz, _air_voile, _air_bas, _air_rays]
	_air_luz = _air_luz.lerp(t[0], k)
	_air_voile = _air_voile.lerp(t[1], k)
	_air_bas = lerpf(_air_bas, t[2], k)
	_air_rays = lerpf(_air_rays, t[3], k)
	if air == null:
		return
	var moved: bool = not (_air_luz.is_equal_approx(before[0]) and _air_voile.is_equal_approx(before[1])) or absf(_air_bas - before[2]) > 0.0005 or absf(_air_rays - before[3]) > 0.0005
	if moved:
		air.luz = _air_luz
		air.voile = _air_voile
		air.bas = _air_bas
		air.rays = _air_rays
		air.queue_redraw()


func _view_rect() -> Rect2:
	var half := get_viewport_rect().size / 2.0 + Vector2(MARGIN, MARGIN)
	var center: Vector2 = main.player.position if main != null and main.player != null else Vector2.ZERO
	return Rect2(center - half, half * 2.0)


func _random_in(rect: Rect2) -> Vector2:
	return rect.position + Vector2(_rng.randf(), _rng.randf()) * rect.size


func _new_mote(rect: Rect2, anywhere: bool) -> Dictionary:
	var pos := _random_in(rect)
	if not anywhere:
		# Ressort sur un bord de l'écran, côté du vent pour la cendre.
		pos = Vector2(rect.position.x if _rng.randf() < 0.5 else rect.end.x, rect.position.y + _rng.randf() * rect.size.y)
	var living: bool = main.ground.life_at(pos) > 0.4
	var m := {"pos": pos, "living": living, "ph": _rng.randf() * TAU, "size": _rng.randf_range(1.2, 2.6),
		"ember": not living and _rng.randf() < 0.12, "speed": _rng.randf_range(0.6, 1.4),
		# Pétales de Ronce : un grain de pollen sur trois, sur la terre vivante.
		"petal": living and _rng.randf() < 0.34}
	var amb := RegionAudio.ambience(Regions.region_at(pos))
	var sty = amb.get("alive" if living else "dead", null)
	if sty is Dictionary:
		# Particule de région : tout est lu une fois ici, pas à chaque image.
		var vel: Array = sty.get("vel", [0.0, 0.0])
		var sway: Array = sty.get("sway", [0.0, 0.0])
		var sz: Array = sty.get("size", [1.2, 2.6])
		m["shape"] = str(sty.get("shape", "dot"))
		if sty.has("alt") and _rng.randf() < float(sty.get("alt_ratio", 0.2)):
			m["shape"] = str(sty["alt"])
		m["col"] = Regions.color(sty.get("color", "#ffffff"))
		m["alpha"] = float(sty.get("alpha", 0.6))
		m["vel"] = Vector2(vel[0], vel[1])
		m["sway"] = Vector2(sway[0], sway[1])
		m["len"] = float(sty.get("length", 14.0))
		m["size"] = _rng.randf_range(sz[0], sz[1])
	return m


func _process(delta: float) -> void:
	var tree_open: bool = main.tree_ui != null and main.tree_ui.visible
	_show_vignette(not tree_open)
	if tree_open:
		return
	_t = maxf(_t, 0.0) + delta
	_step_air(delta)
	_step_weather(delta)
	_region_timer -= delta
	if _region_timer <= 0.0:
		_region_timer = 0.5
		var amb := RegionAudio.ambience(Regions.region_at(main.player.position))
		_butterflies_ok = int(amb.get("butterflies", BUTTERFLIES)) > 0
	var rect := _view_rect()
	var far := rect.grow(MARGIN * 2.0)
	for i in _mote_count():
		var m: Dictionary = motes[i]
		var v: Vector2
		if m.has("shape"):
			v = m["vel"] + Vector2(m["sway"].x * sin(_t * 0.8 + m["ph"]), m["sway"].y * sin(_t * 0.5 + m["ph"] * 2.0))
		elif m["living"]:
			v = Vector2(sin(_t * 0.8 + m["ph"]) * 14.0, -10.0 - 6.0 * sin(_t * 0.5 + m["ph"]))
		else:
			v = Vector2(22.0 + 8.0 * sin(_t * 0.6 + m["ph"]), 12.0 + 6.0 * sin(_t * 0.9 + m["ph"] * 2.0))
		m["pos"] += v * m["speed"] * delta
		if not far.has_point(m["pos"]):
			motes[i] = _new_mote(rect, false)
	for i in _butterfly_count():
		_step_butterfly(butterflies[i], delta, rect, far)
	# Mouvements lents : redessiner une image sur deux suffit et allège le rendu.
	_skip = not _skip
	if not _skip:
		queue_redraw()


func _step_butterfly(b: Dictionary, delta: float, rect: Rect2, far: Rect2) -> void:
	var life: float = main.ground.life_at(b["pos"])
	var want := smoothstep(0.4, 0.6, life) if _butterflies_ok else 0.0
	b["a"] = move_toward(b["a"], want, delta * 0.8)
	# Vol saccadé : le cap change doucement, la vitesse pulse.
	b["heading"] += sin(_t * 1.7 + b["ph"]) * 2.2 * delta
	var speed := 38.0 + 22.0 * sin(_t * 3.1 + b["ph"])
	b["pos"] += Vector2.from_angle(b["heading"]) * speed * delta
	if not far.has_point(b["pos"]):
		# Revient dans l'écran, de préférence sur une terre vivante.
		var best := _random_in(rect)
		for i in 5:
			var p := _random_in(rect)
			if main.ground.life_at(p) > main.ground.life_at(best):
				best = p
		b["pos"] = best
		b["heading"] = _rng.randf() * TAU
		b["a"] = 0.0


## « Réduire les effets » : un tiers des particules, des papillons et du temps.
func _mote_count() -> int:
	return maxi(1, motes.size() / 3) if Settings.reduce_effects else motes.size()


func _butterfly_count() -> int:
	return 1 if Settings.reduce_effects else butterflies.size()


## Temps de la région où se trouve le joueur : la pluie et les rafales montent et descendent doucement
## quand on entre ou sort. Moins de pluie sur la terre ravivée du Marais (elle y tombe moins dense) : le ciel s'éclaircit.
func _step_weather(delta: float) -> void:
	var kind: String = WEATHER.get(_region, "")
	var clear := smoothstep(0.25, 0.75, _life)
	var want_rain := (1.0 - 0.5 * clear) if kind == "rain" else 0.0
	_rain = move_toward(_rain, want_rain, delta * 0.5)
	_gust = move_toward(_gust, 1.0 if kind == "gust" else 0.0, delta * 0.5)
	if _gust > 0.05:
		if _gust_t >= 0.0:
			_gust_t += delta
			if _gust_t > GUST_LEN:
				_gust_t = -1.0
				_gust_timer = _rng.randf_range(GUST_GAP.x, GUST_GAP.y)
		else:
			_gust_timer -= delta
			if _gust_timer <= 0.0:
				_gust_t = 0.0
	else:
		_gust_t = -1.0


func _draw() -> void:
	_draw_weather()
	for i in _mote_count():
		var m: Dictionary = motes[i]
		var p: Vector2 = m["pos"]
		var tw := 0.5 + 0.5 * sin(_t * 2.0 + m["ph"] * 3.0)
		if m.has("shape"):
			_draw_region_mote(m, p, tw)
		elif m["petal"]:
			_draw_petal(p, m["size"], _t * 1.4 + m["ph"], tw)
		elif m["living"]:
			var col := Color(1.0, 0.95, 0.6, 0.35 + 0.4 * tw)
			draw_circle(p, m["size"] * 0.9, col)
		elif m["ember"]:
			draw_circle(p, m["size"] * 2.4, Color(1.0, 0.55, 0.25, 0.12 * (0.5 + tw)))
			draw_circle(p, m["size"] * 0.8, Color(1.0, 0.65, 0.3, 0.5 + 0.4 * tw))
		else:
			draw_circle(p, m["size"], Color(0.62, 0.58, 0.55, 0.28 + 0.2 * tw))
	for i in _butterfly_count():
		if butterflies[i]["a"] > 0.02:
			_draw_butterfly(butterflies[i])


## Pluie fine (Marais) et rafale (Plateaux) : un seul tracé de traits par calque, positions rejouées à partir
## du temps (aucun état par goutte), dans le repère de l'écran.
func _draw_weather() -> void:
	if _rain <= 0.01 and _gust_t < 0.0:
		return
	var rect := _view_rect().grow(-MARGIN)
	var tint: Color = (Art.air_de(_region, "ravive")[0] as Color).lerp(Art.air_de(_region, "fletri")[0], 1.0 - smoothstep(0.25, 0.75, _life))
	if _rain > 0.01:
		var n := maxi(1, int(RAIN_DROPS * _rain * (0.34 if Settings.reduce_effects else 1.0)))
		var pts := PackedVector2Array()
		for i in n:
			var u := fposmod(i * 0.6180339 + 0.13, 1.0)
			var fall := 520.0 + 120.0 * fposmod(i * 0.7548776, 1.0)
			var x := fposmod(u * rect.size.x + _t * 60.0 * (0.8 + fposmod(i * 0.317, 0.4)), rect.size.x)
			var y := fposmod(fposmod(i * 0.4142, 1.0) * rect.size.y + _t * fall, rect.size.y)
			var p := rect.position + Vector2(x, y)
			pts.append(p)
			pts.append(p + Vector2(7.0, 18.0))
		draw_multiline(pts, Color(tint, 0.32), 1.0)
	if _gust_t >= 0.0:
		# Une rafale traverse l'écran de gauche à droite : bande de traits clairs, en tête d'un souffle.
		var k := _gust_t / GUST_LEN
		var env := sin(k * PI)
		var front := rect.position.x - 200.0 + (rect.size.x + 400.0) * k
		var n := maxi(1, int(GUST_STREAKS * (0.34 if Settings.reduce_effects else 1.0)))
		var pts := PackedVector2Array()
		for i in n:
			var y := rect.position.y + rect.size.y * fposmod(i * 0.6180339 + 0.21, 1.0)
			var x := front - 220.0 * fposmod(i * 0.7548776, 1.0)
			pts.append(Vector2(x - 70.0, y + 4.0 * sin(_t * 3.0 + i)))
			pts.append(Vector2(x, y))
		draw_multiline(pts, Color(tint, 0.38 * env * _gust), 1.4)


## Pétale de Ronce : ovale rose qui tourne en tombant ; dans la lumière du haut à gauche, un bord clair.
func _draw_petal(p: Vector2, size: float, a: float, tw: float) -> void:
	var col: Color = Art.mc("ronce", "ravive", "particule")
	var d := Vector2.from_angle(a)
	var n := d.orthogonal()
	var l := size * 2.2
	var w := size * (0.5 + 0.5 * absf(sin(a * 1.7)))
	draw_colored_polygon(PackedVector2Array([p - d * l, p + n * w, p + d * l, p - n * w]), Color(col, 0.55 + 0.3 * tw))


## Particule de région : point, halo qui scintille, ou brin qui file dans le sens du vent.
func _draw_region_mote(m: Dictionary, p: Vector2, tw: float) -> void:
	var col: Color = m["col"]
	var a: float = m["alpha"]
	match m["shape"]:
		"glow":
			draw_circle(p, m["size"] * 2.6, Color(col, a * 0.16 * (0.5 + tw)))
			draw_circle(p, m["size"] * 0.8, Color(col, a * (0.55 + 0.4 * tw)))
		"drop":
			# Goutte de sève : tombe tout droit, pointe vers le haut.
			var r: float = m["size"]
			draw_circle(p, r, Color(col, a * (0.7 + 0.3 * tw)))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.85, -r * 0.3), p + Vector2(0, -r * 2.6), p + Vector2(r * 0.85, -r * 0.3)]), Color(col, a * 0.7))
		"chip":
			# Copeau de sciure : petit rectangle qui culbute.
			var ang: float = _t * 1.8 + m["ph"] * 4.0
			var d: Vector2 = Vector2.from_angle(ang) * float(m["size"]) * 1.5
			var n: Vector2 = d.orthogonal() * 0.45
			draw_colored_polygon(PackedVector2Array([p - d - n, p + d - n, p + d + n, p - d + n]), Color(col, a * (0.6 + 0.4 * tw)))
		"feather":
			# Plume : fuseau clair, tracé d'une nervure, qui ondule dans le vent.
			var ang: float = sin(_t * 1.1 + m["ph"]) * 0.7 + 0.2
			var d: Vector2 = Vector2.from_angle(ang) * float(m["size"]) * 5.0
			var n: Vector2 = d.orthogonal() * 0.28
			draw_colored_polygon(PackedVector2Array([p - d, p - n, p + d, p + n]), Color(col, a * 0.75))
			draw_line(p - d, p + d, Color(col.darkened(0.3), a * 0.6), 1.0)
		"streak":
			var d: Vector2 = (m["vel"] + Vector2(0.0, m["sway"].y * sin(_t * 0.5 + m["ph"] * 2.0))).normalized()
			draw_line(p - d * m["len"], p, Color(col, a * (0.5 + 0.5 * tw)), m["size"])
		_:
			draw_circle(p, m["size"], Color(col, a * (0.55 + 0.4 * tw)))


func _draw_butterfly(b: Dictionary) -> void:
	var p: Vector2 = b["pos"]
	var d := Vector2.from_angle(b["heading"])
	var n := d.orthogonal()
	var s: float = b["size"]
	var col: Color = b["color"]
	col.a = 0.9 * b["a"]
	# Battement d'ailes : la largeur apparente oscille vite.
	var flap := 0.25 + 0.75 * absf(sin(_t * 16.0 + b["ph"]))
	for side in [-1.0, 1.0]:
		var wn: Vector2 = n * side * flap
		var up := PackedVector2Array([p + d * s * 0.2, p + d * s * 1.1 + wn * s * 1.0, p + d * s * 0.2 + wn * s * 1.4, p - d * s * 0.1 + wn * s * 0.3])
		var low := PackedVector2Array([p, p - d * s * 0.9 + wn * s * 0.5, p - d * s * 0.1 + wn * s * 1.0])
		draw_colored_polygon(up, col)
		draw_colored_polygon(low, Color(col.r * 0.85, col.g * 0.85, col.b * 0.85, col.a))
	draw_line(p + d * s * 0.5, p - d * s * 0.5, Color(0.12, 0.1, 0.1, col.a), 1.6)
