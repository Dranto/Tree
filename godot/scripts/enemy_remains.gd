## Ce qui reste d'un Flétri purifié : sa silhouette meurt selon l'élément du coup final (jalon
## Éclat B), puis une pousse de vie sort du sol à sa place et se fond dans la terre.
## Morts (data/feel.json › deaths) :
## - « cendre » : la mort d'avant (coup sans élément, purification du Cœur) : il s'éteint et s'effrite ;
## - « venin » (Spore, poison) : dissous en fumée verte ;
## - « sang » (Ronce, saignement) : éclate en éclats et en gouttes ;
## - « tranche » (fouet) : tranché en deux moitiés qui glissent et retombent ;
## - « vent » : emporté en cendres dans le sens du coup ;
## - « aube » : consumé en lumière ;
## - « racine » : pétrifié, puis effrité en cailloux ;
## - « seve » : fondu en sève qui rentre dans la terre.
## Surpuissance (power > 0) : les morceaux partent plus loin et plus vite. Élite : une onde de
## fleurs ou de cendres propre à la région court au sol. Apparence seulement : aucun effet de jeu.
## Tout le dessin est une fonction du temps (draw_at), sans état qui avance : la galerie et les
## tests peuvent figer n'importe quel instant.
extends Node2D

const FletriArt = preload("res://scripts/fletri_art.gd")
const DrawBatch = preload("res://scripts/draw_batch.gd")
const Content = preload("res://scripts/content.gd")
## Mort « cendre » : la silhouette s'éteint et s'effondre pendant ASH ; la pousse vit de SPROUT_FROM à DURATION.
const ASH := 0.5
const SPROUT_FROM := 0.32
const DURATION := 1.25
## Durée de vie de la pousse (même pour toutes les morts).
const SPROUT_LIFE := DURATION - SPROUT_FROM
const STYLES := ["cendre", "venin", "sang", "tranche", "vent", "aube", "racine", "seve"]

var kind_id := "fletri"
var radius := 14.0
var face := Vector2.RIGHT
var elite := false
var t := 0.0
## Façon de mourir (voir STYLES et death_style) ; « cendre » par défaut.
var style := "cendre"
## Sens du coup final (du héros vers le Flétri).
var dir := Vector2.RIGHT
## Surpuissance, de 0 (coup juste suffisant) à 1 (coup qui dépasse de très loin la vie restante).
var power := 0.0
## Teinte du corps (éclats, moitiés).
var color := Color(0.5, 0.4, 0.4)
## Région de l'élite (onde au sol) ; vide : fleurs.
var region := ""

## Morts élémentaires en cours (plafond feel.json › deaths › max_styled) ; au-delà, mort « cendre ».
static var active := 0
## Morts élémentaires lancées depuis le départ, par façon (lu par les tests).
static var started := {}

var _styled := false
var _body := ASH          # durée de la mort elle-même
var _sprout := SPROUT_FROM
var _end := DURATION
var _pieces: Array = []   # morceaux (éclats, gouttes, flocons, cailloux, bouffées, lueurs)
var _wave: Array = []     # onde de l'élite
var _halves: Array = []   # tranche : deux moitiés en triangles, calculées au premier dessin


## Façon de mourir selon le coup final : forme de l'attaque (fouet), branche du coup, état qui a
## porté le coup (poison, saignement) ou élément de ses étincelles (fx.hit_element).
static func death_style(branch: String, form := "", element := "", dot := "") -> String:
	if form == "fouet":
		return "tranche"
	match branch:
		"ronce":
			return "sang"
		"spore":
			return "venin"
		"vent", "aube", "racine", "seve":
			return branch
	match dot:
		"poison":
			return "venin"
		"saignement":
			return "sang"
	match element:
		"racine":
			return "racine"
		"lumiere":
			return "aube"
		"epine":
			return "sang"
	return "cendre"


static func _feel(key: String, default := 0.0) -> float:
	return float(Content.feel().get("deaths", {}).get(key, default))


static func _style_feel(s: String, key: String, default := 0.0) -> float:
	return float(Content.feel().get("deaths", {}).get("styles", {}).get(s, {}).get(key, default))


## Prépare la mort (temps, morceaux). Appelé à l'entrée dans l'arbre, ou par la galerie.
func prepare() -> void:
	if not STYLES.has(style):
		style = "cendre"
	_body = ASH if style == "cendre" else _style_feel(style, "time", 0.6)
	_sprout = SPROUT_FROM if style == "cendre" else _body * _feel("sprout_at", 0.7)
	_end = _sprout + SPROUT_LIFE
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(position.x), roundi(position.y))) ^ hash(style)
	_pieces = _make_pieces(rng)
	_wave = _make_wave(rng) if elite else []
	if elite:
		_end = maxf(_end, _feel("elite_wave_time", 0.9) + 0.05)


func _enter_tree() -> void:
	if style != "cendre" and STYLES.has(style) and not _styled:
		if active >= int(_feel("max_styled", 14.0)):
			style = "cendre"   # plafond : les morts de trop gardent la mort la plus légère
		else:
			_styled = true
			active += 1
			started[style] = int(started.get(style, 0)) + 1
	prepare()


func _exit_tree() -> void:
	if _styled:
		_styled = false
		active = maxi(0, active - 1)


## Durée totale (pousse et onde comprises).
func duration() -> float:
	return _end


func _process(delta: float) -> void:
	t += delta
	if t >= _end:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_at(self, Vector2.ZERO, t)


## Lot de triangles fidèle (mêmes pixels que les draw_* du CanvasItem) : la silhouette qui
## s'effondre part en un appel de rendu au lieu d'une trentaine. Une mort en série (purification
## du Cœur : 40 Flétris d'un coup) en faisait plus de mille par image.
static var _b = _exact_batch()

static func _exact_batch():
	var b = DrawBatch.new()
	b.exact = true
	return b


## Quantité de morceaux : un tiers avec « Réduire les effets », plus avec la surpuissance.
func _count(n: float) -> int:
	n *= 1.0 + power * _feel("overkill_more", 0.5)
	if _reduce():
		n /= 3.0
	return maxi(1, ceili(n))


## « Réduire les effets » (autoload Settings, cherché à l'exécution : enemy.gd, qui précharge ce
## script, est aussi chargé par des tests « -s » où les autoloads ne sont pas encore connus).
static func _reduce() -> bool:
	var tree = Engine.get_main_loop()
	var s = tree.root.get_node_or_null("Settings") if tree is SceneTree else null
	return s != null and bool(s.reduce_effects)


## Élan des morceaux (surpuissance : plus loin et plus vite).
func _boost() -> float:
	return 1.0 + power * (_feel("overkill_speed", 1.9) - 1.0)


# --- Morceaux (tirés une fois, puis dessinés en fonction du temps) ---

func _make_pieces(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var r := radius
	var b := _boost()
	var n := int(_style_feel(style, "pieces", 8.0))
	match style:
		"venin":
			for i in _count(n):
				out.append({"at": Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.1, 0.6),
					"v": Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-48.0, -26.0)) * b,
					"d": rng.randf_range(0.0, 0.25), "life": rng.randf_range(0.55, 0.8), "s": rng.randf_range(0.28, 0.42) * r,
					"k": i % 3})
		"sang":
			for i in _count(n):
				var a := dir.angle() + rng.randf_range(-1.9, 1.9) if i % 3 != 0 else rng.randf() * TAU
				out.append({"kind": "eclat" if i % 2 == 0 else "goutte", "a": a,
					"v": rng.randf_range(140.0, 260.0) * b, "vz": rng.randf_range(60.0, 140.0) * b,
					"rot": rng.randf() * TAU, "spin": rng.randf_range(-12.0, 12.0), "s": rng.randf_range(0.16, 0.3) * r,
					"pts": _shard(rng)})
		"tranche":
			for i in _count(n):
				out.append({"a": dir.angle() + rng.randf_range(-0.6, 0.6) + (PI / 2.0 if i % 2 == 0 else -PI / 2.0),
					"v": rng.randf_range(60.0, 130.0) * b, "vz": rng.randf_range(40.0, 90.0), "s": rng.randf_range(0.07, 0.12) * r})
		"vent":
			for i in _count(n):
				var at := Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.0, 0.8)
				# Le côté frappé part le premier : délai selon la position le long du coup.
				var d := clampf(0.5 + at.dot(dir) / (2.0 * r), 0.0, 1.0) * 0.28
				out.append({"at": at, "d": d, "v": rng.randf_range(150.0, 240.0) * b, "w": rng.randf_range(-1.0, 1.0),
					"s": rng.randf_range(0.07, 0.13) * r, "ember": i % 5 == 0})
		"aube":
			for i in _count(n):
				out.append({"at": Vector2(rng.randf_range(-0.6, 0.6) * r, rng.randf_range(-0.4, 0.5) * r),
					"d": rng.randf_range(0.15, 0.45), "v": rng.randf_range(50.0, 90.0) * b, "s": rng.randf_range(0.08, 0.14) * r})
		"racine":
			for i in _count(n):
				var at := Vector2(rng.randf_range(-0.7, 0.7) * r, rng.randf_range(-0.8, 0.4) * r)
				out.append({"at": at, "a": dir.angle() + rng.randf_range(-1.2, 1.2), "v": rng.randf_range(10.0, 50.0) * b,
					"d": rng.randf_range(0.0, 0.12), "rot": rng.randf() * TAU, "s": rng.randf_range(0.18, 0.3) * r,
					"pts": _shard(rng), "dust": i % 3 == 0})
		"seve":
			for i in _count(n):
				out.append({"x": rng.randf_range(-0.6, 0.6) * r, "d": rng.randf_range(0.05, 0.45), "s": rng.randf_range(0.08, 0.12) * r})
	return out


## Onde d'une élite : des fleurs (ou des cendres, plumes, cailloux…) qui courent au sol en cercle.
func _make_wave(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var n := _count(_feel("elite_wave_items", 18.0) / (1.0 + power * _feel("overkill_more", 0.5)))
	for i in n:
		out.append({"a": TAU * (i + rng.randf_range(-0.3, 0.3)) / n, "row": rng.randf_range(0.8, 1.1),
			"rot": rng.randf() * TAU, "s": rng.randf_range(0.8, 1.2)})
	return out


## Petit éclat irrégulier (quatre pointes), dans un rayon 1.
static func _shard(rng: RandomNumberGenerator) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 4:
		pts.append(Vector2.from_angle(i * TAU / 4.0 + rng.randf_range(-0.35, 0.35)) * rng.randf_range(0.5, 1.0))
	return pts


## Distance parcourue avec un freinage « drag » (par seconde), à la vitesse de départ v.
static func _glide(v: float, drag: float, time: float) -> float:
	return v * (1.0 - exp(-drag * time)) / drag


## Hauteur d'un morceau lancé en l'air (vz), qui retombe au sol (jamais en dessous).
static func _hop(vz: float, time: float) -> float:
	return maxf(0.0, vz * time - 520.0 * time * time)


# --- Dessin ---

## Dessine l'état des restes au temps time (sert aussi à la galerie).
func draw_at(ci: CanvasItem, pos: Vector2, time: float) -> void:
	if _pieces.is_empty() and style != "cendre":
		prepare()
	if elite and not _wave.is_empty():
		_draw_wave(ci, pos, time)
	match style:
		"venin":
			_venin(ci, pos, time)
		"sang":
			_sang(ci, pos, time)
		"tranche":
			_tranche(ci, pos, time)
		"vent":
			_vent(ci, pos, time)
		"aube":
			_aube(ci, pos, time)
		"racine":
			_racine(ci, pos, time)
		"seve":
			_seve(ci, pos, time)
		_:
			_cendre(ci, pos, time)
	_draw_sprout(ci, pos, time)
	_b.flush(ci)


## La silhouette, transformée (échelle, décalage, rotation), teinte « tint » et opacité « alpha ».
func _silhouette(ci: CanvasItem, pos: Vector2, sc: Vector2, o: Dictionary, alpha := 1.0, rot := 0.0) -> void:
	if alpha <= 0.01 or sc.x <= 0.01 or sc.y <= 0.01:
		return
	_b.flush(ci)
	ci.draw_set_transform(pos, rot, sc)
	FletriArt.draw(_b, kind_id, Vector2.ZERO, radius, face, 0.0, o)
	if alpha < 0.999:
		_b.colors = _fade(_b.colors, alpha)
	_b.flush(ci)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _fade(cols: PackedColorArray, alpha: float) -> PackedColorArray:
	for i in cols.size():
		var c := cols[i]
		c.a *= alpha
		cols[i] = c
	return cols


## Mort d'avant : la silhouette se tasse, s'éteint et s'effrite en cendre.
func _cendre(ci: CanvasItem, pos: Vector2, time: float) -> void:
	var r := radius
	if time < ASH:
		var k := time / ASH
		var e := Anim.ease_in(k)
		# La silhouette se tasse et s'éteint, puis s'effrite par le haut.
		ci.draw_set_transform(pos + Vector2(0, r * 0.35 * e), 0.0, Vector2(1.0 + 0.15 * e, 1.0 - 0.55 * e))
		var o := {"ash": minf(1.0, k * 1.6)}
		FletriArt.draw(_b, kind_id, Vector2.ZERO, r, face, 0.0, o)
		_b.flush(ci)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if e > 0.6:
			# Un voile de cendre recouvre la fin de l'effondrement.
			_b.draw_colored_polygon(Art.ellipse(pos + Vector2(0, r * 0.3), r * 1.1, r * 0.55), Color(FletriArt.ash_color(), (e - 0.6) * 1.5))
	# Flocons qui s'envolent et un petit tas de cendre au sol.
	var heap := clampf((time - ASH * 0.6) / 0.3, 0.0, 1.0) * (1.0 - clampf((time - 0.8) / (DURATION - 0.8), 0.0, 1.0))
	if heap > 0.0:
		_b.draw_colored_polygon(Art.ellipse(pos + Vector2(0, r * 0.45), r * 0.9, r * 0.3), Color(FletriArt.ash_color().darkened(0.25), 0.7 * heap))
	var n := 6 if r < 15.0 else 9
	for i in n:
		var u := clampf((time - 0.12 - i * 0.025) / 0.8, 0.0, 1.0)
		if u <= 0.0 or u >= 1.0:
			continue
		var a := -PI / 2.0 + (i - (n - 1) / 2.0) * 0.38
		var q := pos + Vector2.from_angle(a) * r * (0.4 + 1.4 * Anim.ease_out(u)) + Vector2(sin(u * 6.0 + i) * 4.0, -r * 0.8 * u)
		var col := Art.ec("cendre", "clair") if i % 4 == 0 else FletriArt.ash_color().lightened(0.2)
		FletriArt._flake(_b, q, maxf(1.4, r * 0.08) * (1.0 - u * 0.6), Color(col, 1.0 - u))


## Venin : il verdit, gonfle de bulles, puis se dissout en fumée verte qui monte.
func _venin(ci: CanvasItem, pos: Vector2, time: float) -> void:
	var r := radius
	var k := clampf(time / _body, 0.0, 1.0)
	var green := _venin_color()
	var swell := 1.0 + 0.08 * sin(k * PI * 4.0) * (1.0 - k)
	var shrink := 1.0 - 0.45 * Anim.ease_in(k)
	_silhouette(ci, pos + Vector2(0, -r * 0.2 * k), Vector2(swell, swell) * shrink, {"tint": Color(green, minf(0.85, k * 3.0))}, 1.0 - Anim.ease_in(k))
	# Bulles qui crèvent à la surface.
	if k < 0.7:
		for i in 4:
			var u := fposmod(k * 2.2 + i * 0.27, 1.0)
			var q := pos + Vector2(cos(i * 2.4) * r * 0.45, sin(i * 1.7) * r * 0.3 - r * 0.2)
			_b.draw_arc(q, r * (0.08 + 0.12 * u), 0.0, TAU, 12, Color(Art.ec("poison", "clair"), 0.8 * (1.0 - u)), maxf(1.0, r * 0.05))
	# Flaque qui s'étale puis sèche.
	var pud := clampf(time / (_body * 0.5), 0.0, 1.0) * (1.0 - clampf((time - _body) / 0.5, 0.0, 1.0))
	if pud > 0.0:
		_b.draw_colored_polygon(Art.ellipse(pos + Vector2(0, r * 0.45), r * (0.5 + 0.6 * pud), r * 0.28), Color(green.darkened(0.35), 0.45 * pud))
	# Bouffées de fumée qui montent, grossissent et s'effacent.
	for p in _pieces:
		var u: float = (time - p["d"]) / p["life"]
		if u <= 0.0 or u >= 1.0:
			continue
		var q: Vector2 = pos + p["at"] + p["v"] * u * p["life"] + Vector2(sin(u * 5.0 + p["s"]) * r * 0.15, 0)
		var col := green if p["k"] != 1 else Art.ec("poison", "clair").lerp(green, 0.5)
		var s: float = p["s"] * (0.6 + 1.2 * Anim.ease_out(u))
		_b.draw_circle(q, s, Color(col, 0.5 * (1.0 - u) * minf(1.0, u * 6.0)))
		_b.draw_circle(q + Vector2(-s * 0.25, -s * 0.25), s * 0.5, Color(col.lightened(0.3), 0.35 * (1.0 - u)))


static func _venin_color() -> Color:
	return Art.ec("racine", "clair").lerp(Art.ec("poison"), 0.18)


## Sang : il gonfle d'un coup puis éclate en éclats de son corps et en gouttes qui retombent en taches.
func _sang(ci: CanvasItem, pos: Vector2, time: float) -> void:
	var r := radius
	var pop := 0.12
	if time < pop:
		var k := time / pop
		_silhouette(ci, pos, Vector2.ONE * (1.0 + 0.25 * Anim.ease_in(k)), {"tint": Color(Art.ec("saignement", "clair"), 0.55 * k)})
	var blood := Art.ec("saignement")
	var u0 := time - pop * 0.6
	if u0 <= 0.0:
		return
	# Gerbe rouge au centre, juste à l'éclatement.
	if u0 < 0.22:
		var g := u0 / 0.22
		_b.draw_arc(pos, r * (0.4 + 1.2 * Anim.ease_out(g)), 0.0, TAU, 32, Color(Art.ec("saignement", "clair"), 0.9 * (1.0 - g)), maxf(1.5, r * 0.18) * (1.0 - g))
	var life := _end - pop
	for p in _pieces:
		var dist := _glide(p["v"], 4.5, u0)
		var h := _hop(p["vz"], u0)
		var ground: Vector2 = pos + Vector2.from_angle(p["a"]) * (r * 0.3 + dist)
		var fade := 1.0 - clampf((u0 - life * 0.55) / (life * 0.4), 0.0, 1.0)
		if fade <= 0.0:
			continue
		if p["kind"] == "goutte":
			if h > 0.0 or u0 < 0.05:
				_b.draw_circle(ground + Vector2(0, -h), p["s"] * 0.55, Color(blood.lightened(0.15), fade))
			else:
				# Tombée au sol : une tache aplatie.
				_b.draw_colored_polygon(Art.ellipse(ground, p["s"] * 0.95, p["s"] * 0.45, 10), Color(blood.darkened(0.15), 0.85 * fade))
		else:
			var rot: float = p["rot"] + p["spin"] * minf(u0, 0.5)
			var pts := PackedVector2Array()
			for q in p["pts"]:
				pts.append(ground + Vector2(0, -h) + q.rotated(rot) * p["s"])
			_b.draw_colored_polygon(pts, Color(color.lerp(blood, 0.25), fade))


## Tranche : un trait clair le coupe, les deux moitiés glissent de part et d'autre, puis retombent en cendre.
func _tranche(ci: CanvasItem, pos: Vector2, time: float) -> void:
	var r := radius
	var k := clampf(time / _body, 0.0, 1.0)
	if _halves.is_empty():
		_halves = _cut_halves()
	var axis := dir.orthogonal()   # le trait de coupe suit le geste du fouet, en travers du coup
	var n := dir                    # les moitiés s'écartent de part et d'autre du trait
	var slide := r * (0.35 + 0.35 * power) * Anim.ease_out(minf(1.0, k * 1.6)) * _boost()
	var drop := Anim.ease_in(clampf((k - 0.45) / 0.55, 0.0, 1.0))
	var alpha := 1.0 - drop
	var ash := clampf((k - 0.3) / 0.5, 0.0, 1.0)
	for i in 2:
		var h: Dictionary = _halves[i]
		var sgn := 1.0 if i == 0 else -1.0
		var off := n * sgn * slide + axis * sgn * r * 0.12 * k + Vector2(0, r * 0.35 * drop)
		var rot := sgn * 0.35 * Anim.ease_out(k)
		var cols: PackedColorArray = h["cols"].duplicate()
		var ash_col := FletriArt.ash_color()
		for j in cols.size():
			var c := cols[j].lerp(Color(ash_col, cols[j].a), ash * 0.7)
			c.a *= alpha
			cols[j] = c
		if not h["idx"].is_empty() and alpha > 0.01:
			_b.flush(ci)
			ci.draw_set_transform(pos + off, rot, Vector2(1.0, 1.0 - 0.4 * drop))
			RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), h["idx"], h["pts"], cols)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Trait de la coupe : il jaillit en travers du corps puis s'amincit.
	if k < 0.3:
		var u := k / 0.3
		var len := r * (1.4 + 0.9 * power) * Anim.ease_out(minf(1.0, u * 2.0))
		var w := maxf(1.5, r * 0.22) * (1.0 - u)
		_b.draw_colored_polygon(PackedVector2Array([pos - axis * len, pos + n * w * 0.5, pos + axis * len, pos - n * w * 0.5]),
			Color(Art.c("danger_eclair"), 0.95 * (1.0 - u)))
	# Quelques gouttes de sève sombre qui tombent de la coupe.
	for p in _pieces:
		var dist := _glide(p["v"], 5.0, time)
		var hgt := _hop(p["vz"], time)
		var fade := 1.0 - clampf((time - _body * 0.6) / (_body * 0.5), 0.0, 1.0)
		if fade > 0.0:
			_b.draw_circle(pos + Vector2.from_angle(p["a"]) * dist + Vector2(0, -hgt), p["s"], Color(Art.ec("saignement", "clair").lerp(color, 0.4), fade))
	# Cendre au sol là où les moitiés retombent.
	if drop > 0.0:
		_b.draw_colored_polygon(Art.ellipse(pos + Vector2(0, r * 0.45), r * (0.7 + 0.5 * drop) + slide * 0.6, r * 0.28),
			Color(FletriArt.ash_color().darkened(0.25), 0.6 * sin(PI * minf(1.0, drop * 0.9 + 0.1))))


## Les deux moitiés de la silhouette, coupées le long du trait (repère local, regard figé).
func _cut_halves() -> Array:
	var tmp = DrawBatch.new()
	tmp.exact = true
	FletriArt.draw(tmp, kind_id, Vector2.ZERO, radius, face, 0.0, {})
	var out: Array = []
	for sgn in [1.0, -1.0]:
		out.append(clip_half(tmp.points, tmp.colors, tmp.indices, dir * sgn))
	return out


## Garde la part des triangles du côté où dot(point, normal) ≥ 0 (découpe de Sutherland-Hodgman,
## couleurs interpolées sur les nouveaux sommets). Renvoie {"pts", "cols", "idx"}.
static func clip_half(pts: PackedVector2Array, cols: PackedColorArray, idx: PackedInt32Array, normal: Vector2) -> Dictionary:
	var out_p := PackedVector2Array()
	var out_c := PackedColorArray()
	var out_i := PackedInt32Array()
	for t0 in range(0, idx.size() - 2, 3):
		var poly_p: Array = []
		var poly_c: Array = []
		for j in 3:
			var a := pts[idx[t0 + j]]
			var b := pts[idx[t0 + (j + 1) % 3]]
			var ca := cols[idx[t0 + j]]
			var cb := cols[idx[t0 + (j + 1) % 3]]
			var da := a.dot(normal)
			var db := b.dot(normal)
			if da >= 0.0:
				poly_p.append(a)
				poly_c.append(ca)
			if (da >= 0.0) != (db >= 0.0):
				var f := da / (da - db)
				poly_p.append(a.lerp(b, f))
				poly_c.append(ca.lerp(cb, f))
		if poly_p.size() < 3:
			continue
		var base := out_p.size()
		for j in poly_p.size():
			out_p.append(poly_p[j])
			out_c.append(poly_c[j])
		for j in range(1, poly_p.size() - 1):
			out_i.append(base)
			out_i.append(base + j)
			out_i.append(base + j + 1)
	return {"pts": out_p, "cols": out_c, "idx": out_i}


## Vent : il grisonne, puis part en cendres emportées dans le sens du coup, le côté frappé d'abord.
func _vent(ci: CanvasItem, pos: Vector2, time: float) -> void:
	var r := radius
	var k := clampf(time / _body, 0.0, 1.0)
	var e := Anim.ease_in(k)
	var lean := dir * r * 0.5 * e * _boost()
	_silhouette(ci, pos + lean, Vector2(1.0 - 0.3 * e, 1.0 - 0.15 * e), {"ash": minf(1.0, k * 2.0)}, 1.0 - Anim.ease_in(minf(1.0, k * 1.15)))
	var side := dir.orthogonal()
	for p in _pieces:
		var u: float = time - p["d"]
		if u <= 0.0:
			continue
		var life := _body * 1.1
		if u >= life:
			continue
		var f := u / life
		# Emportés de plus en plus vite, en ondulant.
		var q: Vector2 = pos + p["at"] + dir * (p["v"] * u * (0.4 + 0.9 * f)) + side * sin(f * 7.0 + p["w"] * 3.0) * r * 0.25 * p["w"]
		var col := Art.ec("cendre", "clair") if p["ember"] else FletriArt.ash_color().lightened(0.15)
		var s: float = p["s"] * (1.0 - f * 0.5)
		# Flocon étiré dans le sens du vent.
		var d := dir * s * 2.2
		var w := side * s * 0.8
		_b.draw_colored_polygon(PackedVector2Array([q - d, q + w, q + d, q - w]), Color(col, (1.0 - f) * minf(1.0, f * 8.0 + 0.3)))
	# Traînée de poussière dans le sens du vent.
	if k > 0.1 and k < 1.0:
		var a := 0.25 * sin(PI * k)
		_b.draw_colored_polygon(Art.ellipse(pos + dir * r * (0.6 + 1.4 * k), r * (0.6 + 1.2 * k), r * 0.35, 14), Color(Art.ec("vent", "clair"), a))


## Aube : il s'éclaire de l'intérieur, devient lumière, se resserre en un point qui monte en rayon.
func _aube(ci: CanvasItem, pos: Vector2, time: float) -> void:
	var r := radius
	var k := clampf(time / _body, 0.0, 1.0)
	var light := Art.ec("lumiere", "clair")
	var gold := Art.ec("lumiere")
	var burn := clampf(k * 3.0, 0.0, 1.0)
	var shrink := 1.0 - Anim.ease_in(clampf((k - 0.3) / 0.6, 0.0, 1.0))
	# Halo derrière lui, qui grandit à mesure qu'il se consume.
	_b.draw_circle(pos, r * (1.1 + 0.5 * burn) * maxf(shrink, 0.4), Color(gold, 0.18 * burn * (1.0 - k * 0.5)))
	_silhouette(ci, pos, Vector2.ONE * (1.0 + 0.08 * burn) * shrink, {"tint": Color(light, 0.9 * burn)}, 1.0)
	if shrink > 0.0:
		_b.draw_circle(pos, r * 0.5 * shrink * burn, Color(Color.WHITE, 0.55 * burn))
	# Rayon qui monte du point où il disparaît.
	var beam := clampf((k - 0.5) / 0.5, 0.0, 1.0)
	if beam > 0.0 and time < _body + 0.35:
		var fade := 1.0 - clampf((time - _body) / 0.35, 0.0, 1.0)
		var h := r * (2.0 + 3.5 * Anim.ease_out(beam)) * _boost()
		var w := r * 0.32 * (1.0 - beam * 0.5)
		_b.draw_colored_polygon(PackedVector2Array([pos + Vector2(-w, 0), pos + Vector2(-w * 0.3, -h), pos + Vector2(w * 0.3, -h), pos + Vector2(w, 0)]),
			Color(gold, 0.45 * fade))
		_b.draw_colored_polygon(PackedVector2Array([pos + Vector2(-w * 0.4, 0), pos + Vector2(0, -h * 1.05), pos + Vector2(w * 0.4, 0)]),
			Color(light, 0.8 * fade))
	# Lueurs qui s'élèvent en scintillant.
	for p in _pieces:
		var u: float = time - p["d"]
		var life := 0.7
		if u <= 0.0 or u >= life:
			continue
		var f := u / life
		var q: Vector2 = pos + p["at"] + Vector2(sin(f * 6.0 + p["s"]) * r * 0.12, -p["v"] * u)
		var s: float = p["s"] * (1.0 - f * 0.5) * (0.75 + 0.25 * sin(f * 20.0))
		var col := Color(light, 1.0 - f)
		_b.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -s * 2.0), q + Vector2(s * 0.5, 0), q + Vector2(0, s * 2.0), q + Vector2(-s * 0.5, 0)]), col)
		_b.draw_colored_polygon(PackedVector2Array([q + Vector2(-s * 1.6, 0), q + Vector2(0, -s * 0.4), q + Vector2(s * 1.6, 0), q + Vector2(0, s * 0.4)]), col)


## Racine : il se fige en pierre (des fissures le parcourent), tient un instant, puis s'effrite en cailloux.
func _racine(ci: CanvasItem, pos: Vector2, time: float) -> void:
	var r := radius
	var k := clampf(time / _body, 0.0, 1.0)
	var stone := _stone_color()
	var petrify := clampf(k / 0.3, 0.0, 1.0)
	var crumble := 0.5
	if k < crumble:
		_silhouette(ci, pos, Vector2.ONE * (1.0 - 0.04 * petrify), {"tint": Color(stone, petrify)})
		# Fissures qui courent du centre vers le bord.
		var grow := clampf((k - 0.15) / 0.3, 0.0, 1.0)
		if grow > 0.0:
			for i in 4:
				var a := i * TAU / 4.0 + 0.6 + dir.angle()
				var pts := PackedVector2Array([pos])
				for j in 3:
					var q := pos + Vector2.from_angle(a + (0.35 if j % 2 == 0 else -0.3)) * r * (j + 1) / 3.0 * 0.85 * grow
					pts.append(q)
				_b.draw_polyline(pts, Color(stone.darkened(0.6), 0.9), maxf(1.0, r * 0.07))
	# Cailloux : le haut tombe en premier, ils roulent un peu dans le sens du coup.
	for p in _pieces:
		var u: float = time - _body * crumble - p["d"]
		if u < 0.0:
			continue
		var at: Vector2 = p["at"]
		var fall := minf(r * 0.45 - at.y, 0.5 * 900.0 * u * u)
		var roll := _glide(p["v"], 4.0, u)
		var fade := 1.0 - clampf((time - (_end - 0.45)) / 0.4, 0.0, 1.0)
		if fade <= 0.0:
			continue
		var q: Vector2 = pos + at + Vector2(0, fall) + Vector2.from_angle(p["a"]) * roll
		var pts := PackedVector2Array()
		for c in p["pts"]:
			pts.append(q + c.rotated(p["rot"] + u * 2.0) * p["s"])
		_b.draw_colored_polygon(pts, Color(stone.lightened(0.05 * (int(p["s"]) % 3)), fade))
		if p["dust"] and u < 0.5:
			_b.draw_circle(q + Vector2(0, r * 0.1), p["s"] * (1.0 + 3.0 * u), Color(stone.lightened(0.35), 0.35 * (1.0 - u / 0.5)))


static func _stone_color() -> Color:
	return Art.ec("racine", "sombre").lerp(Color("8d867b"), 0.6)


## Sève : il fond, s'affaisse en une flaque de sève qui brille puis rentre dans la terre.
func _seve(ci: CanvasItem, pos: Vector2, time: float) -> void:
	var r := radius
	var k := clampf(time / _body, 0.0, 1.0)
	var sap := Art.ec("seve")
	var e := Anim.ease_in_out(k)
	var melt := Vector2(1.0 + 0.35 * e, 1.0 - 0.9 * e)
	_silhouette(ci, pos + Vector2(0, r * 0.45 * e), melt, {"tint": Color(sap.darkened(0.15), minf(0.85, k * 2.5))}, 1.0 - clampf((k - 0.75) / 0.25, 0.0, 1.0))
	# Flaque qui s'étale, puis rentre dans la terre (rétrécit et s'assombrit).
	var spread := Anim.ease_out(clampf(k / 0.7, 0.0, 1.0))
	var sink := clampf((time - _body * 0.8) / 0.6, 0.0, 1.0)
	if spread > 0.0 and sink < 1.0:
		var rx := r * (0.4 + 0.9 * spread) * (1.0 - 0.6 * sink) * _boost()
		_b.draw_colored_polygon(Art.ellipse(pos + Vector2(0, r * 0.42), rx, rx * 0.36, 18), Color(sap.darkened(0.3 + 0.4 * sink), 0.7 * (1.0 - sink)))
		_b.draw_colored_polygon(Art.ellipse(pos + Vector2(-rx * 0.2, r * 0.38), rx * 0.45, rx * 0.12, 12), Color(Art.ec("seve", "clair"), 0.5 * (1.0 - sink)))
	# Gouttes qui coulent du corps dans la flaque.
	for p in _pieces:
		var u: float = (time - p["d"]) / 0.3
		if u <= 0.0 or u >= 1.0:
			continue
		var top := -r * 0.4 * (1.0 - e)
		var q := pos + Vector2(p["x"] * (1.0 + 0.3 * e), lerpf(top, r * 0.4, u * u))
		_b.draw_circle(q, p["s"], Color(sap, 0.9 * (1.0 - u * 0.5)))


## Pousse de vie : elle sort du sol, ouvre deux feuilles, puis se fond (commune à toutes les morts).
func _draw_sprout(ci: CanvasItem, pos: Vector2, time: float) -> void:
	if time <= _sprout:
		return
	var r := radius
	var u := (time - _sprout) / SPROUT_LIFE
	var grow := Anim.pop(clampf(u / 0.45, 0.0, 1.0))
	var fade := 1.0 - Anim.ease_in(clampf((u - 0.6) / 0.4, 0.0, 1.0))
	if fade <= 0.0:
		return
	var s := maxf(8.0, r * 0.75) * (1.3 if elite else 1.0)
	var base := pos + Vector2(0, r * 0.35)
	_b.draw_circle(base + Vector2(0, -s * 0.5), s * 1.1 * grow, Color(Art.ec("seve"), 0.12 * fade))
	_b.flush(ci)
	var top := base + Vector2(0, -s * 1.1 * grow)
	# Trait lissé : hors du lot (voir draw_batch.gd).
	ci.draw_line(base, top, Color(Art.ec("seve", "sombre").lightened(0.2), fade), maxf(1.5, s * 0.14), true)
	for sgn in [-1.0, 1.0]:
		var d := Vector2.from_angle(-PI / 2.0 + sgn * 0.95)
		var l := s * 0.3 * grow
		Art._leaf(_b, top + d * l, l, d.angle(), Color(Art.ec("seve"), fade))
	_b.draw_circle(top, maxf(1.2, s * 0.09) * grow, Color(Art.ec("seve", "clair"), fade))


## Onde d'une élite : un cercle de la matière de sa région court au sol (pétales, spores, plumes,
## feuilles, lueurs, cailloux ; fleurs hors des régions).
func _draw_wave(ci: CanvasItem, pos: Vector2, time: float) -> void:
	var life := _feel("elite_wave_time", 0.9)
	var u := time / life
	if u <= 0.0 or u >= 1.0:
		return
	var r := radius
	var reach := r + r * _feel("elite_wave_reach", 4.5) * Anim.ease_out(u) * (1.0 + 0.3 * power)
	var fade := 1.0 - Anim.ease_in(u)
	var cols := region_colors(region)
	# Le sol s'éclaire en anneau dans la couleur de la région.
	_b.draw_arc(pos, reach * 0.96, 0.0, TAU, 48, Color(Color(cols[0]).lerp(Color.WHITE, 0.35), 0.45 * fade), maxf(1.5, r * 0.16) * (1.0 - u * 0.6))
	for i in _wave.size():
		var w: Dictionary = _wave[i]
		var q: Vector2 = pos + Vector2.from_angle(w["a"]) * reach * w["row"] * Vector2(1.0, 0.8)
		var s: float = maxf(3.0, r * 0.22) * w["s"] * (0.6 + 0.4 * fade)
		var col: Color = Color(cols[i % 2], fade)
		var rot: float = w["rot"] + u * 3.0
		match region:
			"spore":
				_b.draw_circle(q, s * 0.55, col)
				_b.draw_circle(q + Vector2(-s * 0.15, -s * 0.15), s * 0.2, Color(Color.WHITE, 0.4 * fade))
			"vent":
				var d := Vector2.from_angle(rot) * s * 1.3
				var n := d.orthogonal() * 0.28
				_b.draw_colored_polygon(PackedVector2Array([q - d, q + n, q + d, q - n]), col)
			"seve":
				Art._leaf(_b, q, s * 0.7, rot, col)
			"aube":
				_b.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -s), q + Vector2(s * 0.3, 0), q + Vector2(0, s), q + Vector2(-s * 0.3, 0)]), col)
				_b.draw_colored_polygon(PackedVector2Array([q + Vector2(-s, 0), q + Vector2(0, -s * 0.3), q + Vector2(s, 0), q + Vector2(0, s * 0.3)]), col)
			"racine":
				var pts := PackedVector2Array()
				for j in 5:
					pts.append(q + Vector2.from_angle(rot + j * TAU / 5.0) * s * (0.5 + 0.2 * ((j + i) % 2)))
				_b.draw_colored_polygon(pts, col)
			_:
				# Pétale (fleurs de la Ronce et des terres vivantes).
				var d := Vector2.from_angle(rot)
				var nn := d.orthogonal()
				var wd := s * (0.35 + 0.65 * absf(sin(rot)))
				_b.draw_colored_polygon(PackedVector2Array([q + d * s, q + nn * wd * 0.6, q - d * s * 0.6, q - nn * wd * 0.6]), col)


## Deux couleurs de l'onde d'élite selon la région.
static func region_colors(reg: String) -> Array:
	match reg:
		"ronce":
			return [Color("e98aa5"), Art.ec("saignement", "clair")]
		"spore":
			return [Art.ec("poison"), _venin_color()]
		"vent":
			return [Art.ec("vent", "clair"), FletriArt.ash_color().lightened(0.2)]
		"seve":
			return [Art.ec("seve"), Art.ec("racine", "clair")]
		"aube":
			return [Art.ec("lumiere"), Art.ec("lumiere", "clair")]
		"racine":
			return [_stone_color(), Art.ec("racine", "clair")]
	return [Color("f6b8c8"), Color("f2d06b")]
