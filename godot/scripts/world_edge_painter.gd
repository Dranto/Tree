## Dessin du bord du monde (voir world_edge.gd) : où va quoi. Les formes elles-mêmes sont dans
## world_art/bord.gd.
##
## Le bord suit un champ de distance (px du monde) au carré du monde aux coins arrondis (CORNER_R), dont
## la ligne ondule (lip_off) : pas de coupure droite ni de coin net. e = distance au-delà de la ligne du
## bord (négative dans le monde) : de -INSET à 0, le sol de la région se défait (miettes, touffes, voile
## qui assombrit) ; au-delà, le paysage propre à la région (bord.gd), qui se perd dans le noir (voile).
## Entre deux régions, le bord suit la bande des frontières du monde (world_art/frontieres.gd, tâche B) :
## mêmes langues, même largeur, prolongées au-delà du carré.
##
## Le bord est coupé en tuiles : quatre côtés (normales NORMALS), des tuiles de CHUNK px le long du côté,
## joints en onglet aux coins (|u| ≤ WORLD_HALF + d). Une tuile a quatre couches : le fond (dégradé de
## sommets, un lot), le décor proche (d < NEAR_D) et lointain, cuits (world_edge.gd), et le voile de
## profondeur (un lot). Chaque élément a son pied dans une seule tuile et déborde librement autour
## (PAD_*) : aucune couture. Tout est tiré avec une graine fixe : le bord est le même à chaque partie.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const DrawBatch = preload("res://scripts/draw_batch.gd")
const Fr = preload("res://scripts/world_art/frontieres.gd")
const Bord = preload("res://scripts/world_art/bord.gd")

## Le bord commence à INSET px à l'intérieur du monde (le sol s'y défait).
const INSET := 170.0
## Profondeur du bord (px) : l'écran le plus large (3440 x 1440) posé contre le bord du monde ne voit pas plus loin.
const DEPTH := 2000.0
## Longueur d'une tuile le long du bord.
const CHUNK := 1000.0
## Limite entre le décor proche (cuit à pleine résolution) et le lointain (moitié, sous le voile).
const NEAR_D := 700.0
## Rayon des coins arrondis du bord.
const CORNER_R := 160.0
## Pas du dégradé de fond le long du bord, et ses rangées (distance au bord du monde).
const STEP := 62.5
const ROWS := [-170.0, -130.0, -95.0, -65.0, -40.0, -20.0, 0.0, 20.0, 45.0, 80.0, 130.0, 200.0, 300.0, 430.0, 600.0, 800.0, 1050.0, 1350.0, 1650.0, 2000.0]
## Débord des formes autour de la tuile : sur les côtés, vers le haut (formes hautes), vers le bas.
const PAD_SIDE := 170.0
const PAD_UP := 400.0
const PAD_DOWN := 190.0
## Pas des points du bord (bande continue de bord.gd › strip).
const STRIP_STEP := 20.0
## Côtés : normale sortante et tangente (dans l'ordre : nord, est, sud, ouest).
const NORMALS := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
const TANGENTS := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]
## Bandes de décor d'une tuile.
const NEAR := 0
const FAR := 1


# --- Le champ du bord ---

static func half() -> float:
	return Regions.WORLD_HALF


## Distance signée au carré du monde aux coins arrondis (positive dehors).
static func edge_dist(p: Vector2) -> float:
	var c := half() - CORNER_R
	var q := p.abs() - Vector2(c, c)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - CORNER_R


## Normale sortante du bord au plus près de p.
static func outward(p: Vector2) -> Vector2:
	var c := half() - CORNER_R
	var q := p.abs() - Vector2(c, c)
	var sg := Vector2(1.0 if p.x >= 0.0 else -1.0, 1.0 if p.y >= 0.0 else -1.0)
	if q.x > 0.0 and q.y > 0.0:
		return (q.normalized() * sg)
	if q.x > q.y:
		return Vector2(sg.x, 0.0)
	return Vector2(0.0, sg.y)


## Ondulation de la ligne du bord (px, positive : la ligne recule hors du monde). Continue tout autour.
static func lip_off(p: Vector2) -> float:
	var t := p.x + p.y
	var s := p.x - p.y
	return 22.0 * (sin(t * 0.0047 + 1.3) * 0.6 + sin(t * 0.0113 + 0.4) * 0.4) + 10.0 * sin(s * 0.019 + 2.1) - 6.0


## Distance au-delà de la ligne du bord (négative dans le monde).
static func beyond(p: Vector2) -> float:
	return edge_dist(p) - lip_off(p)


## Point du côté « side » à l'abscisse u (le long du côté), à la distance e au-delà de la ligne du bord
## (suit l'arrondi des coins et l'ondulation).
static func place(side: int, u: float, e: float) -> Vector2:
	var p: Vector2 = NORMALS[side] * (half() + e) + TANGENTS[side] * u
	for k in 3:
		p -= outward(p) * (beyond(p) - e)
	return p


## Région d'un point du bord (une seule, avec les langues des frontières : même calcul que le sol,
## world_art/frontieres.gd, prolongé au-delà du carré du monde).
static func region_of(p: Vector2) -> String:
	var ids := Regions.ids()
	if ids.is_empty():
		return "ronce"
	var n := Fr.noise(p)
	var best := ""
	var best_v := -INF
	for id in ids:
		var v := Fr.inside(p, id, n)
		if v > 0.0:
			return id
		if v > best_v:
			best_v = v
			best = id
	return best


## Frontière la plus proche d'un point du bord : {a, b, s, w} comme Frontieres.mix, prolongée au-delà du
## carré du monde (b vide : pas de voisine).
static func mix(p: Vector2) -> Dictionary:
	var a := ""
	var best := -INF
	for id in Regions.ids():
		var d := Regions.inside_distance(p, id)
		if d > best:
			best = d
			a = id
	if a == "":
		return {"a": "ronce", "b": "", "s": 1.0e6, "w": 0.0}
	var nn: Array = Regions.edge_normals(a)
	var s1 := p.dot(nn[0])
	var s2 := p.dot(nn[1])
	var s := minf(s1, s2)
	var b := Fr.neighbour(a, s == s1)
	return {"a": a, "b": b, "s": s, "w": Fr.weight_s(s) if b != "" else 0.0}


## Région dont le bord.gd sait dessiner le paysage (une région d'essai prend le roncier ; le fichier d'une
## région peut choisir le sien avec le champ « edge », data/README.md).
static func theme_of(rid: String) -> String:
	var th := str(Regions.def(rid).get("edge", rid))
	return th if th in ["ronce", "spore", "vent", "seve", "aube", "racine"] else "ronce"


## État dessiné d'une région : "ravive" si son Cœur est purifié (states : région → vrai).
static func etat_of(rid: String, states: Dictionary) -> String:
	return "ravive" if bool(states.get(rid, false)) else "fletri"


# --- Tuiles ---

static func to_world(side_: int, u: float, d: float) -> Vector2:
	return NORMALS[side_] * (half() + d) + TANGENTS[side_] * u


static func chunk_count() -> int:
	return int(ceil(2.0 * (half() + DEPTH) / CHUNK))


static func chunk_u0(i: int) -> float:
	return -(half() + DEPTH) + i * CHUNK


## Distances [d0, d1] couvertes par une bande (pied des éléments).
static func band_range(band: int, depth := DEPTH) -> Vector2:
	if band == NEAR:
		return Vector2(-INSET - 40.0, minf(NEAR_D, depth))
	return Vector2(NEAR_D, depth)


## Rectangle du monde qui contient la tuile (côté, rang), jusqu'aux distances [d0, d1], sans débord.
static func chunk_rect(side_: int, i: int, depth := DEPTH, d0 := -INSET - 40.0) -> Rect2:
	var a := chunk_u0(i)
	var r := Rect2(to_world(side_, a, d0), Vector2.ZERO)
	for u in [a, a + CHUNK]:
		for d in [d0, depth]:
			r = r.expand(to_world(side_, u, d))
	return r


## Rectangle de la texture d'une bande : la tuile et le débord de ses formes.
static func band_rect(side_: int, i: int, band: int) -> Rect2:
	var dr := band_range(band)
	var r := chunk_rect(side_, i, dr.y, dr.x)
	return Rect2(r.position - Vector2(PAD_SIDE, PAD_UP), r.size + Vector2(PAD_SIDE * 2.0, PAD_UP + PAD_DOWN))


## Vrai si la tuile (côté, rang) touche le monde ou son bord dessiné (hors des onglets des coins).
static func chunk_live(side_: int, i: int) -> bool:
	var a := chunk_u0(i)
	return a + CHUNK > -(half() + DEPTH) and a < half() + DEPTH


## Vrai si le pied (u, d) est à la tuile (côté, rang) : dans ses bornes et du bon côté des onglets.
static func owns(side_: int, i: int, u: float, d: float) -> bool:
	var a := chunk_u0(i)
	return u >= a and u < a + CHUNK and absf(u) <= half() + d


## Régions présentes le long de la tuile (pour son état : purifiée ou non).
static func present(side_: int, i: int) -> Array:
	var out := []
	var a := chunk_u0(i)
	for k in 17:
		for d in [-INSET, -60.0, 0.0, 200.0, 600.0, 1200.0, DEPTH]:
			var u := lerpf(a - PAD_SIDE, a + CHUNK + PAD_SIDE, k / 16.0)
			if absf(u) > half() + d + PAD_SIDE:
				continue
			var p := to_world(side_, u, d)
			var m := mix(p)
			for rid in [m["a"], m["b"], region_of(p)]:
				if rid != "" and not out.has(rid):
					out.append(rid)
	out.sort()
	return out


## Clé d'état d'une tuile : les régions présentes et leur état.
static func state_key(side_: int, i: int, states: Dictionary) -> String:
	var parts := []
	for rid in present(side_, i):
		parts.append("%s%d" % [rid, 1 if bool(states.get(rid, false)) else 0])
	return ",".join(parts)


# --- Fond et voile (lots de triangles aux couleurs de sommet) ---

## Couleur du fond (veil faux) ou du voile (veil vrai) au point p, mêlée entre régions voisines.
static func field_color(p: Vector2, states: Dictionary, veil: bool) -> Color:
	var e := beyond(p)
	var m := mix(p)
	var w: float = m["w"]
	var out := Color(0, 0, 0, 0)
	for k in 2:
		var rid: String = m["a"] if k == 0 else m["b"]
		var wt: float = 1.0 - w if k == 0 else w
		if wt <= 0.0 or rid == "":
			continue
		var th := theme_of(rid)
		var c: Color = Bord.veil(th, etat_of(rid, states), e) if veil else Bord.base(th, etat_of(rid, states), e)
		# Mélange en alpha prémultiplié (un voile transparent ne noircit pas).
		out += Color(c.r * c.a * wt, c.g * c.a * wt, c.b * c.a * wt, c.a * wt)
	if out.a > 0.0001:
		out = Color(out.r / out.a, out.g / out.a, out.b / out.a, out.a)
	return out


## Fond (veil faux) ou voile (veil vrai) de la tuile (côté, rang) jusqu'à « depth » dans « batch ».
static func build_field(batch: DrawBatch, side_: int, i: int, states: Dictionary, veil: bool, depth := DEPTH) -> void:
	var h := half()
	var a := chunk_u0(i)
	var cols := int(ceil(CHUNK / STEP))
	for r in ROWS.size() - 1:
		var d0: float = ROWS[r]
		var d1: float = ROWS[r + 1]
		if d0 >= depth:
			break
		d1 = minf(d1, depth)
		if veil and d1 <= 150.0:
			continue
		for k in cols:
			var ua := a + k * STEP
			var ub := ua + STEP
			var pts := PackedVector2Array()
			var cs := PackedColorArray()
			for q in [[ua, d0], [ub, d0], [ub, d1], [ua, d1]]:
				# Coins en onglet : le côté ne dépasse pas la diagonale (|u| ≤ half + d).
				var uu := clampf(q[0], -(h + q[1]), h + q[1])
				var p := to_world(side_, uu, q[1])
				pts.append(p)
				cs.append(field_color(p, states, veil))
			if pts[0].distance_squared_to(pts[1]) < 1.0 and pts[2].distance_squared_to(pts[3]) < 1.0:
				continue
			var any := false
			for c in cs:
				if c.a > 0.003:
					any = true
					break
			if any:
				batch.draw_primitive(pts, cs)


# --- Décor d'une bande ---

## Dessine le décor de la bande « band » de la tuile (côté, rang) sur ci, en coordonnées du monde.
## lod : 0 en jeu, 1 sur la carte (formes simples, sans détails). depth : profondeur dessinée.
static func paint(ci: CanvasItem, side_: int, i: int, band: int, states: Dictionary, lod := 0, depth := DEPTH) -> void:
	draw_items(ci, items(side_, i, band, states, lod, depth), states, 0, lod)


## Les éléments de la bande, triés dans l'ordre du dessin (vue de trois quarts : de haut en bas).
## Par morceaux (une cuisson s'étale sur plusieurs images) : seulement les sortes [kinds_from, kinds_to[,
## la ligne du bord si « strip », triés si « sorted » (sort_items sinon).
static func items(side_: int, i: int, band: int, _states: Dictionary, lod := 0, depth := DEPTH, kinds_from := 0, kinds_to := -1, strip := true, sorted := true) -> Array:
	var dr := band_range(band, depth)
	var items := []
	if dr.y <= dr.x:
		return items
	var rng := RandomNumberGenerator.new()
	var a := chunk_u0(i)
	var nrm: Vector2 = NORMALS[side_]
	var tan: Vector2 = TANGENTS[side_]
	var cache := {}
	for ki in range(kinds_from, Bord.KINDS.size() if kinds_to < 0 else mini(kinds_to, Bord.KINDS.size())):
		var kind: Dictionary = Bord.KINDS[ki]
		if lod > 0 and kind.get("detail", false):
			continue
		var e0: float = kind["e0"]
		var e1: float = kind["e1"]
		if e1 + 60.0 < dr.x or e0 - 60.0 > dr.y:
			continue
		rng.seed = hash([kind["id"], side_, i])
		var bias: float = kind.get("bias", 1.0)
		var n: int = kind["n"]
		for k in n:
			var u := rng.randf_range(a, a + CHUNK)
			var e := e0 + (e1 - e0) * pow(rng.randf(), bias)
			var sub := rng.randi()
			var p := place(side_, u, e)
			var d := p.dot(nrm) - half()
			var uu := p.dot(tan)
			if d < dr.x or d >= dr.y or not owns(side_, i, uu, d):
				continue
			var ck := Vector2i(int(floor(p.x / 40.0)), int(floor(p.y / 40.0)))
			var rid: String = cache.get(ck, "")
			if rid == "":
				rid = region_of(p)
				cache[ck] = rid
			var th := theme_of(rid)
			if kind["region"] != "*" and kind["region"] != th:
				continue
			items.append([p.y, 0, kind["id"], p, sub, rid, th, e])
	# La ligne du bord (bande continue), dans la bande proche.
	if band == NEAR and strip:
		var u := a - 2.0
		var prev: Array = []
		while u <= a + CHUNK + 2.0 + STRIP_STEP:
			var uc := minf(u, a + CHUNK + 2.0)
			var lim := half() + 2.0
			var p := place(side_, clampf(uc, -lim, lim), 0.0)
			if not prev.is_empty() and absf(uc) <= lim + STRIP_STEP:
				var pa: Vector2 = prev[0]
				var mid := (pa + p) * 0.5
				var rid := region_of(mid)
				items.append([minf(pa.y, p.y) + 0.5, 1, theme_of(rid), pa, p, rid, prev[1], outward(p)])
			prev = [p, outward(p)]
			if uc >= a + CHUNK + 2.0:
				break
			u += STRIP_STEP
	if sorted:
		sort_items(items)
	return items


## Coût de dessin estimé d'un élément (ms, mesuré par sorte ; les formes simples de la carte, bien moins).
const COST := {
	"ronce_masse": 1.2, "ronce_haie": 1.1, "fougere": 1.0, "ronce_arbre": 3.7, "chapeau_geant": 1.2,
	"roseaux": 0.7, "cime": 0.5, "ronce_arceau": 0.5, "racines": 0.5, "tronc": 0.4, "champignon": 0.4,
	"nuage": 0.25, "ruisseau": 0.25, "cristaux": 0.25, "bloc": 0.2, "souche": 0.2, "ronce_rampe": 0.2,
	"ile": 0.2, "fut_mort": 0.2, "touffe": 0.15, "herbe_vent": 0.15, "nenuphar": 0.12, "dalle": 0.1,
	"eclat": 0.1,
}


static func cost(it: Array, lod := 0) -> float:
	if it[1] == 1:
		return 0.02
	return (COST.get(it[2], 0.05) as float) * (0.25 if lod > 0 else 1.0)


static func sort_items(items: Array) -> void:
	items.sort_custom(func(x, y): return x[0] < y[0] if x[0] != y[0] else x[1] > y[1])


## Dessine les éléments à partir du rang « from » ; s'arrête après « budget_usec » µs (0 : tous). Renvoie
## le rang suivant (items.size() quand tout est dessiné) : une cuisson peut s'étaler sur plusieurs images.
## Avec « max_cost » > 0, s'arrête plutôt quand le coût estimé des éléments dessinés (COST, en ms d'une
## machine de développement) l'atteint : même découpage sur toutes les machines (tests visuels).
static func draw_items(ci: CanvasItem, items: Array, states: Dictionary, from := 0, lod := 0, budget_usec := 0, max_cost := 0.0) -> int:
	var r := RandomNumberGenerator.new()
	var bottom := half()
	var t0 := Time.get_ticks_usec()
	var spent := 0.0
	for n in range(from, items.size()):
		if max_cost > 0.0:
			if n > from and spent >= max_cost:
				return n
			spent += cost(items[n], lod)
		elif budget_usec > 0 and n > from and Time.get_ticks_usec() - t0 > budget_usec:
			return n
		var it: Array = items[n]
		if it[1] == 1:
			Bord.strip(ci, it[2], etat_of(it[5], states), it[3], it[4], it[6], it[7], lod)
			continue
		var p: Vector2 = it[3]
		r.seed = it[4]
		var on := outward(p)
		# Près du bord qui regarde vers le bas de l'écran, rien de haut ne doit monter devant le héros.
		var cap := 9999.0
		if on.y > 0.3:
			cap = maxf(10.0, (p.y - bottom) * 1.1 + 12.0)
		Bord.draw(ci, it[2], p, r, it[6], etat_of(it[5], states), it[7], on, cap, lod)
	return items.size()
