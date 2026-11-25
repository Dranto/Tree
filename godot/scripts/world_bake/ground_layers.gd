## Sol « Paysages d'herbier » (refonte du monde, vague 1 S) : couches 2 et 3 et bord de vie.
##
## Le shader du sol (shaders/ground.gdshader) ne peint que le lavis (couche 1 : grandes plaques nettes,
## trois tons par région et par état) et le front net du bord de vie. Chaque carré de sol en cache
## (ground.gd, TILE_PX) reçoit par-dessus un calque dessiné une fois, à sa construction :
##   - couche 2, la matière de la région à l'encre fine : craquelures et feuilles mortes, tiges à
##     épines (Roncier) ; rides de vase et mycélium (Marais) ; craquelures (autres régions, matière
##     provisoire commune en attendant la vague 2) ; herbe rase couchée sur la terre ravivée ;
##   - couche 3, les détails en grappes de 3 à 9 avec un plus grand : cailloux éclairés d'en haut à
##     gauche, touffes sèches ; touffes, fleurs de la région, baies, petits chapeaux du Marais ;
##   - le bord de vie : brins et fleurs de la région qui poussent sur une bande juste derrière le front.
##
## La géométrie ne dépend pas de la vie : chaque élément porte son point d'ancrage, et le shader du
## calque (shaders/ground_layer.gdshader) choisit au rendu s'il se montre (mort, ravivé ou front) en
## lisant la carte de vie. Une vague de vie ne refait que le rendu des carrés touchés. Seule exception :
## un carré tout mort ne tire que la terre morte, et il est redessiné une fois, quand la vie l'atteint
## pour la première fois (masque des sortes, voir needs()).
##
## Les éléments sont tirés par cases du monde (CELL pixels, hachage de la case) : deux carrés voisins
## dessinent les mêmes éléments sur leur bord, sans couture.
## Aucun texte visible, aucun chiffre de jeu, aucune collision : apparence seulement.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")

## Sortes d'éléments (bits du masque d'un carré).
const DEAD := 1
const ALIVE := 2
const FRONT := 4
## Commun : oasis de la graine et hors des régions (indice de région du shader).
const COMMUN := 6

## Taille des carrés de sol (pixels d'écran), « --sol-tile=256|512|1024 » ; 0 : celle de ground.gd.
static var tile_px := 0
## Densité des éléments (« --sol-densite=0.5 » : moitié moins).
static var density := 1.0
static var _pals := {}


## Lit les réglages sur la ligne de commande.
static func configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sol-tile="):
			tile_px = clampi(a.get_slice("=", 1).to_int(), 128, 2048)
		elif a.begins_with("--sol-densite="):
			density = clampf(a.get_slice("=", 1).to_float(), 0.0, 4.0)


## Palette du monde d'une région, par état (« fletri », « apaise », « ravive »), avec les clés de
## Art.MONDE (sol, sol_clair, sol_sombre, matiere, feuille, cendre, touffe, pierre, fleur…).
## Le Roncier et le Marais ont la leur dans Art.MONDE ; les autres régions la tirent de leur fichier
## (data/regions/<id>.json › ground) en attendant la vague 2 ; « » : l'oasis, depuis la charte.
static func world_palette(id: String) -> Dictionary:
	if _pals.has(id):
		return _pals[id]
	var out := {}
	if Art.MONDE.has(id) and id != "commun":
		for etat in ["fletri", "apaise", "ravive"]:
			var e := {}
			for k in ["sol", "sol_clair", "sol_sombre", "matiere", "feuille", "feuille_2", "cendre", "touffe", "touffe_2", "pierre", "fleur"]:
				e[k] = Art.mc(id, etat, k)
			out[etat] = e
		out["ravive"]["fleur_coeur"] = Art.mc(id, "ravive", "fleur_coeur")
	else:
		var dd: Color
		var dl: Color
		var cd: Color
		var cl: Color
		var ad: Color
		var al: Color
		var dot: Color
		if id == "" or not Regions.exists(id):
			dd = Art.c("sol_mort").darkened(0.14)
			dl = Art.c("sol_mort").lightened(0.04)
			cd = dd
			cl = dl
			ad = Art.c("sol_vivant").lightened(0.02)
			al = Art.c("sol_vivant").lerp(Art.c("decor_vivant"), 0.7).lightened(0.2)
			dot = Art.c("interactif")
		else:
			var p := _region_ground(id)
			dd = p["dead_dark"]
			dl = p["dead_light"]
			cd = p["purified_dark"]
			cl = p["purified_light"]
			ad = p["alive_dark"]
			al = p["alive_light"]
			dot = p["dot"]
		out["fletri"] = _derived(dd, dl, dot, false)
		out["apaise"] = _derived(cd, cl, dot, false)
		out["ravive"] = _derived(ad, al, dot, true)
	# Lisibilité (banc tests/paysages_test.gd) : le sol ravivé ne doit pas écraser le héros (clair) ni
	# trop contraster sous les personnages ; le flétri du Roncier, plus clair que le reste, s'assombrit
	# pour que les Flétris (sombres) s'en détachent.
	var ym: float = RAVIVE_Y_MAX.get(id, RAVIVE_Y_MAX[""])
	var rg: float = RAVIVE_GAIN.get(id, 1.0)
	var fg: float = FLETRI_GAIN.get(id, 1.0)
	out["ravive"] = _tones(out["ravive"], ym, RAVIVE_CONTRAST, rg)
	out["fletri"] = _tones(out["fletri"], 1.0, 1.0, fg)
	out["apaise"] = _tones(out["apaise"], 1.0, 1.0, fg)
	_pals[id] = out
	return out


## Luminance relative (linéaire) au plus du ton moyen du sol ravivé (≈ L* 42) : le héros, clair, reste
## au moins 10 L* au-dessus.
## Par région (« » : les autres), réglé au banc de lisibilité (tests/paysages_test.gd) : le Marais plus
## sombre, les Falaises plus claires (distinctes des Plateaux et de la Forêt, Flétris lisibles).
const RAVIVE_Y_MAX := {"": 0.125, "spore": 0.10, "aube": 0.21, "seve": 0.14}
## Écart des tons sombre et clair du lavis ravivé autour du ton moyen (1 : celui de la palette).
const RAVIVE_CONTRAST := 0.35
## Gain (linéaire) du sol ravivé par région, avant le plafond.
const RAVIVE_GAIN := {"seve": 1.3}
## Gain (linéaire) de la terre morte par région.
const FLETRI_GAIN := {"ronce": 0.72, "spore": 0.75, "aube": 0.62, "racine": 0.6}


static func _lum(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## Tons du sol d'un état : contraste resserré autour du ton moyen, puis assombri (gain linéaire, et
## plafond de luminance du ton moyen).
static func _tones(e: Dictionary, y_max: float, contrast: float, gain: float) -> Dictionary:
	var e2 := e.duplicate()
	var mid: Color = e["sol"]
	var k := gain
	var y := _lum(mid) * gain
	if y > y_max:
		k *= y_max / y
	for key in ["sol", "sol_clair", "sol_sombre"]:
		var c: Color = e[key]
		if key != "sol":
			c = mid.lerp(c, contrast)
		var l := c.srgb_to_linear()
		e2[key] = Color(l.r * k, l.g * k, l.b * k, c.a).linear_to_srgb()
	return e2


static func _region_ground(id: String) -> Dictionary:
	var g := Regions.section(id, "ground")
	var named := Regions.named_colors(g)
	var out := {}
	for k in ["dead_dark", "dead_light", "purified_dark", "purified_light", "alive_dark", "alive_light", "dot"]:
		out[k] = Regions.color(g.get(k, "sol_mort"), named)
	return out


## Palette tirée de deux tons de sol (régions sans palette dans Art.MONDE).
static func _derived(dark: Color, light: Color, dot: Color, alive: bool) -> Dictionary:
	var mid := dark.lerp(light, 0.5)
	return {
		"sol": mid, "sol_clair": light, "sol_sombre": dark,
		"matiere": dark.darkened(0.45), "feuille": mid.lerp(Art.c("decor"), 0.3).lightened(0.12),
		"feuille_2": mid.lerp(Art.c("decor"), 0.4), "cendre": light.lightened(0.3),
		"touffe": (light.lightened(0.06) if alive else mid.lightened(0.12)), "touffe_2": (dark.darkened(0.08) if alive else dark.lightened(0.05)),
		"pierre": {"clair": mid.lerp(Color("948a7c"), 0.5), "ombre": dark.darkened(0.3), "reflet": light.lerp(Color("cbc2b2"), 0.5)},
		"fleur": dot, "fleur_coeur": Art.mc("commun", "", "lumiere"),
	}


## Matériau des calques, partagé par tous les carrés.
static func material(g) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ground_layer.gdshader")
	m.set_shader_parameter("life_map", g.tex)
	m.set_shader_parameter("world_size", Vector2(g.SIZE, g.SIZE))
	m.set_shader_parameter("front", g.FRONT)
	var gains := PackedVector3Array()
	for id in g._region_ids:
		var p := world_palette(id)
		var a: Color = p["fletri"]["sol"]
		var b: Color = p["apaise"]["sol"]
		gains.append(Vector3(b.r / maxf(a.r, 0.02), b.g / maxf(a.g, 0.02), b.b / maxf(a.b, 0.02)))
	while gains.size() < 6:
		gains.append(Vector3.ONE)
	m.set_shader_parameter("region_calm_gain", gains)
	return m


## Sortes d'éléments utiles sur ce rectangle du monde, d'après la vie (min et max) sous lui, avec de
## la marge : la terre morte tant qu'elle peut se voir, le ravivé et le front dès que la vie approche.
static func needs(g, rect: Rect2) -> int:
	var k: float = g.RES / g.SIZE
	var h: float = g.SIZE / 2.0
	var x0 := clampi(int((rect.position.x + h) * k) - 1, 0, g.RES - 1)
	var x1 := clampi(int((rect.end.x + h) * k) + 1, 0, g.RES - 1)
	var y0 := clampi(int((rect.position.y + h) * k) - 1, 0, g.RES - 1)
	var y1 := clampi(int((rect.end.y + h) * k) + 1, 0, g.RES - 1)
	var lo := 255
	var hi := 0
	var data: PackedByteArray = g.data
	for y in range(y0, y1 + 1):
		var row: int = y * g.RES
		for x in range(x0, x1 + 1):
			var v: int = data[row + x]
			lo = mini(lo, v)
			hi = maxi(hi, v)
	var f: float = g.FRONT * 255.0
	var m := 0
	if lo < f + 8.0:
		m |= DEAD
	if hi > f - 50.0:
		m |= ALIVE | FRONT
	return m


## Calque d'un carré de sol : rect = rectangle du monde couvert par le carré.
static func make(g, rect: Rect2, mat: ShaderMaterial) -> Node2D:
	if TileLayer.pals.size() != Regions.ids().size() + 1:
		for id in Regions.ids() + [""]:
			TileLayer.pals[id] = world_palette(id)
	var l := TileLayer.new()
	l.area = rect
	l.dens = density
	l.mask = needs(g, rect)
	l.material = mat
	return l


## Mesures (banc, tableaux).
static func stats() -> Dictionary:
	return {"draws": TileLayer.draws, "usec": TileLayer.usec, "elements": TileLayer.elements, "verts": TileLayer.verts}


## Oublie la géométrie tirée (nouveau monde, palettes changées).
static func clear_cache() -> void:
	TileLayer._cache.clear()


static func reset_stats() -> void:
	TileLayer.draws = 0
	TileLayer.usec = 0
	TileLayer.elements = 0
	TileLayer.verts = 0


class TileLayer extends Node2D:
	## Case de tirage des éléments (pixels du monde).
	const CELL := 96.0
	## Marge : un élément qui part d'une case voisine peut déborder sur le carré.
	const REACH := 44.0
	const SIZE := 6000.0
	static var draws := 0
	static var usec := 0
	static var elements := 0
	static var verts := 0
	static var _r := RandomNumberGenerator.new()
	static var _e := RandomNumberGenerator.new()
	static var _pts := PackedVector2Array()
	static var _cols := PackedColorArray()
	static var _uvs := PackedVector2Array()
	static var _idx := PackedInt32Array()
	static var _uv := Vector2.ZERO
	static var _ids: Array = []
	## Géométrie des cases déjà tirées : Vector3i(x, y, sorte) -> [points, couleurs, ancrages].
	static var _cache := {}
	## Au-delà, le cache est vidé (≈ 2 Ko par entrée).
	const CACHE_MAX := 12000
	## Palettes de toutes les régions (et « » : l'oasis), remplies par make().
	static var pals := {}

	var area := Rect2()
	var dens := 1.0
	var mask := DEAD | ALIVE | FRONT
	var _p: Dictionary
	var _reg := ""

	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		if _ids != Regions.ids():
			_ids = Regions.ids().duplicate()
			_cache.clear()
		if _cache.size() > CACHE_MAX:
			_cache.clear()
		var out_p := PackedVector2Array()
		var out_c := PackedColorArray()
		var out_u := PackedVector2Array()
		var c0 := Vector2i(floori((area.position.x - REACH) / CELL), floori((area.position.y - REACH) / CELL))
		var c1 := Vector2i(floori((area.end.x + REACH) / CELL), floori((area.end.y + REACH) / CELL))
		for cy in range(c0.y, c1.y + 1):
			for cx in range(c0.x, c1.x + 1):
				for kind in 3:
					if mask & (1 << kind) == 0:
						continue
					var key := Vector3i(cx, cy, kind)
					var g = _cache.get(key)
					if g == null:
						g = _gen(Vector2i(cx, cy), kind)
						_cache[key] = g
					out_p.append_array(g[0])
					out_c.append_array(g[1])
					out_u.append_array(g[2])
		verts += out_p.size()
		if not out_p.is_empty():
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), PackedInt32Array(), out_p, out_c, out_u)
		draws += 1
		usec += Time.get_ticks_usec() - t0

	## Géométrie d'une case pour une sorte (0 mort, 1 ravivé, 2 front), en liste de triangles :
	## [points, couleurs, ancrages]. Gardée en cache (les carrés voisins partagent leurs cases de bord).
	func _gen(cell: Vector2i, kind: int) -> Array:
		var o := Vector2(cell) * CELL
		var reg := Regions.region_at(o + Vector2(CELL, CELL) * 0.5)
		var ri := _ids.find(reg)
		_reg = reg if ri >= 0 else ""
		_p = pals[_reg]
		_r.seed = hash(cell) ^ (0x5ca1ab1e + kind * 7919)
		_cell(o, ri if ri >= 0 else COMMUN, kind)
		var tp := PackedVector2Array()
		var tc := PackedColorArray()
		var tu := PackedVector2Array()
		var n := _idx.size()
		tp.resize(n)
		tc.resize(n)
		tu.resize(n)
		for k in n:
			var v := _idx[k]
			tp[k] = _pts[v]
			tc[k] = _cols[v]
			tu[k] = _uvs[v]
		_pts.clear()
		_cols.clear()
		_uvs.clear()
		_idx.clear()
		return [tp, tc, tu]

	## Éléments d'une case (origine o) pour une sorte : toujours les mêmes tirages, quelle que soit la vie.
	func _cell(o: Vector2, ri: int, kind: int) -> void:
		var style := _reg if _reg == "ronce" or _reg == "spore" else ""
		if kind == 0:
			# Terre morte : matière (deux tirages) et une grappe.
			for i in 3:
				var p := o + Vector2(_r.randf(), _r.randf()) * CELL
				var roll := _r.randf()
				var sd := _r.randi()
				if roll > (0.62 if i < 2 else 0.4) * dens:
					continue
				_anchor(p, 0, ri)
				_e.seed = sd
				elements += 1
				if i == 2:
					_dead_cluster(p, style)
				elif style == "spore":
					if i == 0:
						_rides(p)
					else:
						_mycelium(p, Color(_p["fletri"]["cendre"], 0.22))
				elif style == "ronce" and i == 1:
					if sd & 1:
						_thorns(p)
					else:
						_leaves(p, _p["fletri"])
				else:
					_crack(p, style == "ronce")
		elif kind == 1:
			# Terre ravivée : une grappe et la matière vivante de la région (l'herbe rase est peinte par
			# le shader du sol).
			for i in range(1, 3):
				var p := o + Vector2(_r.randf(), _r.randf()) * CELL
				var roll := _r.randf()
				var sd := _r.randi()
				if roll > (0.5 if i == 1 else 0.4) * dens:
					continue
				_anchor(p, 1, ri)
				_e.seed = sd
				elements += 1
				if i == 1:
					_alive_cluster(p, style)
				elif style == "spore":
					_mycelium(p, Color(Art.mc("spore", "ravive", "lueur"), 0.32))
				elif style == "ronce":
					_leafy_runner(p)
				else:
					_leaves(p, _p["ravive"])
		else:
			# Bord de vie : les brins sont peints par le shader du sol ; le calque y ajoute les fleurs de
			# la région, visibles seulement juste derrière le front.
			for i in int(1.5 * dens + _r.randf()):
				var p := o + Vector2(_r.randf(), _r.randf()) * CELL
				var r := _r.randf_range(2.6, 4.4)
				_anchor(p, 2, ri)
				elements += 1
				_region_flower(p + Vector2(0, -r * 1.6), r)

	## Point d'ancrage (et sorte) des sommets qui suivent.
	func _anchor(p: Vector2, kind: int, ri: int) -> void:
		var a := ((p + Vector2(SIZE, SIZE) * 0.5) / SIZE).clamp(Vector2(0.0005, 0.0005), Vector2(0.9995, 0.9995))
		_uv = a + Vector2(kind * 2.0, ri * 2.0)

	# --- Primitives (un seul lot de triangles par carré) ---

	func _tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
		var n := _pts.size()
		_pts.append(a)
		_pts.append(b)
		_pts.append(c)
		for i in 3:
			_cols.append(col)
			_uvs.append(_uv)
		_idx.append(n)
		_idx.append(n + 1)
		_idx.append(n + 2)

	## Polygone convexe (éventail depuis le premier point).
	func _fan(pts: PackedVector2Array, col: Color) -> void:
		var n := _pts.size()
		_pts.append_array(pts)
		for i in pts.size():
			_cols.append(col)
			_uvs.append(_uv)
		for i in range(1, pts.size() - 1):
			_idx.append(n)
			_idx.append(n + i)
			_idx.append(n + i + 1)

	func _oval(c: Vector2, rx: float, ry: float, col: Color, sides := 7) -> void:
		var pts := PackedVector2Array()
		for i in sides:
			var a := TAU * i / sides
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		_fan(pts, col)

	func _line(a: Vector2, b: Vector2, w: float, col: Color) -> void:
		var d := b - a
		if d.length_squared() < 0.01:
			return
		var nn := d.orthogonal().normalized() * (w * 0.5)
		_fan(PackedVector2Array([a + nn, b + nn, b - nn, a - nn]), col)

	func _polyline(pts: PackedVector2Array, w: float, col: Color) -> void:
		for i in pts.size() - 1:
			_line(pts[i], pts[i + 1], w, col)

	func _blade(b: Vector2, h: float, lean: float, w: float, col: Color) -> void:
		_tri(b + Vector2(-w * 0.5, 0), b + Vector2(lean * h, -h), b + Vector2(w * 0.5, 0), col)

	func _leaf(q: Vector2, a: float, l: float, col: Color) -> void:
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		_fan(PackedVector2Array([q, q + d * l * 0.5 + n * l * 0.26, q + d * l, q + d * l * 0.5 - n * l * 0.26]), col)

	## Caillou éclairé d'en haut à gauche : ombre portée, corps, reflet (les gros seulement).
	func _pebble(q: Vector2, rx: float, stone: Dictionary) -> void:
		_oval(q + Vector2(1.0, 1.3), rx, rx * 0.66, Color(stone["ombre"].darkened(0.4), 0.55), 6)
		_oval(q, rx, rx * 0.66, stone["clair"], 6)
		if rx > 4.0:
			_tri(q + Vector2(-0.75, -0.05) * rx, q + Vector2(-0.1, -0.5) * rx, q + Vector2(0.2, -0.25) * rx, stone["reflet"])

	func _tuft(q: Vector2, h: float, c1: Color, c2: Color) -> void:
		var n := 3 + (_e.randi() % 3)
		for j in n:
			var x := (j - (n - 1) * 0.5) * h * 0.16
			var hh := h * (0.6 + 0.4 * _e.randf()) * (1.0 if j == n / 2 else 0.8)
			_blade(q + Vector2(x, 0), hh, x / h * 1.8 + _e.randf_range(-0.12, 0.12), h * 0.13 + 0.6, c1 if j % 2 == 0 else c2)

	## Fleur à cinq pétales : une étoile arrondie (dix points) et son cœur.
	func _flower(q: Vector2, r0: float, petal: Color, heart: Color) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			pts.append(q + Vector2.from_angle(TAU * k / 10.0 - PI / 2.0) * r0 * (1.25 if k % 2 == 0 else 0.75))
		_fan(pts, petal)
		_oval(q, r0 * 0.4, r0 * 0.4, heart, 4)

	## Petit chapeau du Marais (de la taille d'une touffe). lit : luit (ravivé) ; sinon sombre et terne.
	func _cap(p: Vector2, r: float, lit: bool) -> void:
		var etat := "ravive" if lit else "fletri"
		var pied: Dictionary = Art.mc("spore", etat, "pied")
		var cap: Color = Art.mc("spore", "ravive", "fleur") if lit else Art.mc("spore", "fletri", "chapeau")["ombre"]
		if lit:
			_oval(p + Vector2(0, -r * 1.2), r * 2.2, r * 1.8, Color(cap, 0.1), 8)
		_line(p, p + Vector2(0, -r * 1.3), maxf(r * 0.45, 1.0), pied["ombre"])
		var c := p + Vector2(0, -r * 1.3)
		var dome := PackedVector2Array()
		for i in 7:
			var a := PI + PI * i / 6.0
			dome.append(c + Vector2(cos(a) * r, sin(a) * r * 0.8))
		_fan(dome, cap.darkened(0.25))
		_oval(c + Vector2(-r * 0.2, -r * 0.35), r * 0.45, r * 0.22, cap.lightened(0.3) if lit else cap, 6)

	func _region_flower(p: Vector2, r: float) -> void:
		if _reg == "spore":
			_cap(p, r * 0.8, true)
		else:
			_flower(p, r, _p["ravive"]["fleur"], _p["ravive"]["fleur_coeur"])

	# --- Matière et grappes ---

	## Craquelure : un trait brisé fin qui se divise ; braise au fond de certaines (Roncier flétri).
	func _crack(c: Vector2, ember: bool) -> void:
		var ink: Color = _p["fletri"]["matiere"]
		var p := c
		var a := _e.randf() * TAU
		var pts := PackedVector2Array([p])
		for i in _e.randi_range(3, 5):
			a += _e.randf_range(-0.7, 0.7)
			p += Vector2.from_angle(a) * _e.randf_range(9.0, 17.0) * Vector2(1.0, 0.7)
			pts.append(p)
		_polyline(pts, 1.1, Color(ink, 0.55))
		var b := pts[2] + Vector2.from_angle(a + 1.2) * _e.randf_range(7.0, 12.0)
		_line(pts[2], b, 0.8, Color(ink, 0.4))
		if ember and _e.randf() < 0.18:
			_polyline(pts.slice(1, 3), 0.9, Color(Art.bc("braise"), 0.8))

	## Feuilles couchées en congère : 3 à 7 (sèches sur la terre morte, neuves une fois ravivée).
	func _leaves(c: Vector2, pal: Dictionary) -> void:
		for i in _e.randi_range(3, 7):
			var p := c + Vector2(_e.randf_range(-20, 20), _e.randf_range(-9, 9))
			var col: Color = pal["feuille" if i % 2 == 0 else "feuille_2"]
			_leaf(p, _e.randf() * TAU, _e.randf_range(4.0, 7.0), Color(col, 0.85))

	## Tige rampante à épines (Roncier flétri), ombre d'encre en bas à droite (lumière d'en haut à gauche).
	func _thorns(p: Vector2) -> void:
		var a := _e.randf() * TAU
		var pts := PackedVector2Array([p])
		for i in 4 + _e.randi() % 3:
			a += _e.randf_range(-0.5, 0.5)
			pts.append(pts[-1] + Vector2.from_angle(a) * _e.randf_range(13.0, 20.0))
		var ink := Art.mpc("ronce", "encre_morte")
		var shadow := PackedVector2Array()
		for q in pts:
			shadow.append(q + Vector2(1.0, 1.3))
		_polyline(shadow, 2.0, Color(ink, 0.5))
		_polyline(pts, 1.3, Art.mpc("ronce", "tige_morte"))
		for i in range(1, pts.size() - 1):
			var d: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
			var nn := d.orthogonal() * (1.0 if i % 2 == 0 else -1.0)
			var q: Vector2 = pts[i]
			_tri(q + d * 1.4, q + nn * 3.4 + d * 0.8, q - d * 1.0, ink)

	## Tige de ronce ravivée : courte, couverte de petites feuilles.
	func _leafy_runner(p: Vector2) -> void:
		var a := _e.randf() * TAU
		var pts := PackedVector2Array([p])
		for i in 3:
			a += _e.randf_range(-0.5, 0.5)
			pts.append(pts[-1] + Vector2.from_angle(a) * _e.randf_range(13.0, 19.0))
		_polyline(pts, 1.4, Art.mpc("ronce", "tige_vive"))
		for i in range(1, pts.size()):
			var d: Vector2 = (pts[i] - pts[i - 1]).normalized()
			var side := 1.0 if i % 2 == 0 else -1.0
			_leaf(pts[i], d.angle() + 0.9 * side, _e.randf_range(5.0, 7.0), Art.mpc("ronce", "feuille"))

	## Rides de vase (Marais) : arcs plats concentriques autour d'un creux.
	func _rides(c: Vector2) -> void:
		var ink: Color = _p["fletri"]["matiere"]
		var a0 := _e.randf_range(-0.6, 0.2)
		for k in _e.randi_range(2, 3):
			var rad := 8.0 + k * 6.0
			var pts := PackedVector2Array()
			for i in 6:
				var a := a0 + PI * 0.9 * i / 5.0
				pts.append(c + Vector2(cos(a) * rad * 1.6, sin(a) * rad * 0.55))
			_polyline(pts, 1.0, Color(ink, 0.4 - k * 0.07))

	## Mycélium : fils pâles qui se ramifient (lumineux une fois ravivé).
	func _mycelium(c: Vector2, col: Color) -> void:
		var p := c
		var a := _e.randf() * TAU
		var pts := PackedVector2Array([p])
		for i in _e.randi_range(4, 7):
			a += _e.randf_range(-0.9, 0.9)
			p += Vector2.from_angle(a) * _e.randf_range(6.0, 12.0)
			pts.append(p)
			if _e.randf() < 0.3:
				_line(p, p + Vector2.from_angle(a + _e.randf_range(-1.6, 1.6)) * _e.randf_range(5.0, 9.0), 0.7, Color(col, col.a * 0.7))
		_polyline(pts, 0.8, col)

	## Grappe de la terre morte : cailloux, touffes sèches ou feuilles ; petits chapeaux ternes au Marais.
	func _dead_cluster(c: Vector2, style: String) -> void:
		var pal: Dictionary = _p["fletri"]
		var kind := _e.randi() % 3
		var n := _e.randi_range(3, 5)
		var items := []
		for i in n:
			var big := 1.0 if i == 0 else _e.randf_range(0.45, 0.8)
			var off := Vector2.ZERO if i == 0 else Vector2.from_angle(_e.randf() * TAU) * _e.randf_range(6.0, 20.0) * Vector2(1.0, 0.6)
			items.append([c + off, big])
		items.sort_custom(func(x, y): return x[0].y < y[0].y)
		for it in items:
			var p: Vector2 = it[0]
			var big: float = it[1]
			if style == "spore" and kind == 2:
				# Champignons du Marais assombris et moins nombreux (retour d'Antoine, 25/11).
				if big > 0.9 or _e.randf() < 0.4:
					_cap(p, 2.0 + 2.6 * big, false)
				else:
					_pebble(p, 2.5 + 3.5 * big, pal["pierre"])
			elif kind == 0:
				_tuft(p, 11.0 * big, pal["touffe"], pal["touffe_2"])
			elif kind == 1:
				_pebble(p, 2.6 + 4.0 * big, pal["pierre"])
			else:
				_oval(p, 3.5 + 4.5 * big, 1.8 + 2.0 * big, Color(pal["cendre"], 0.4), 6)
				if style == "ronce" and _e.randf() < 0.2:
					_oval(p + Vector2(0, -0.5), 1.2 * big, 1.2 * big, Art.bc("braise"), 5)

	## Grappe de la terre ravivée : touffes, fleurs et baies de la région, chapeaux luisants au Marais.
	func _alive_cluster(c: Vector2, style: String) -> void:
		var pal: Dictionary = _p["ravive"]
		var n := _e.randi_range(3, 6)
		var items := []
		for i in n:
			var big := 1.0 if i == 0 else _e.randf_range(0.45, 0.8)
			var off := Vector2.ZERO if i == 0 else Vector2.from_angle(_e.randf() * TAU) * _e.randf_range(6.0, 22.0) * Vector2(1.0, 0.6)
			items.append([c + off, big, _e.randf()])
		items.sort_custom(func(x, y): return x[0].y < y[0].y)
		for it in items:
			var p: Vector2 = it[0]
			var big: float = it[1]
			var k: float = it[2]
			if k < 0.55:
				_tuft(p, 13.0 * big, pal["touffe"], pal["touffe_2"])
			elif k < 0.85:
				if style == "spore":
					_cap(p, 2.0 + 2.4 * big, true)
				else:
					_tuft(p, 9.0 * big, pal["touffe"], pal["touffe_2"])
					_flower(p + Vector2(0, -8.0 * big), 2.2 + 2.0 * big, pal["fleur"], pal["fleur_coeur"])
			elif style == "ronce":
				_oval(p, 1.8 * big + 0.6, 1.8 * big + 0.6, Art.mpc("ronce", "baie"), 6)
				_oval(p + Vector2(-0.6, -0.6), 0.6, 0.6, Art.mpc("ronce", "fleur_coeur"), 4)
			else:
				_pebble(p, 2.4 + 3.0 * big, pal["pierre"])
