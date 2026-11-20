## Dessin de l'Arbre de vie, dans la charte du jeu (Art, Anim) : fond, médaillons des nœuds,
## liens feuillus, icônes des nœuds et petites animations (sève, éclosion, survol, braises).
##
## Fonctions statiques et pures : tree_ui.gd décide quoi dessiner et où (couches, niveau de détail),
## ce fichier décide de quoi ça a l'air. Aucune ne change le jeu.
extends RefCounted

## Icône (Art.icon) de chaque statistique : la même que dans la barre, le journal et les infobulles.
const ICON_OF_STAT := {
	"damage": "degats", "melee_damage": "degats", "thorns": "epine",
	"projectile_damage": "projectile", "projectiles": "projectile", "projectile_size": "projectile", "pierce": "projectile",
	"bleed": "saignement", "bleed_duration": "saignement", "lifesteal": "saignement",
	"max_hp": "vie", "regen": "regen",
	"move_speed": "vitesse", "fire_rate": "attaque", "dash_cd": "esquive", "pickup": "collecte",
	"poison": "poison", "area": "zone", "area_damage": "zone",
	"crit": "critique", "crit_mult": "critique",
	"armor": "armure", "armor_cap": "armure",
	"root_duration": "racine", "skill_slots": "competence",
}
const ICON_OF_ACTION := {"explode": "cendre", "spread_poison": "poison", "survive": "vie", "reduce_cooldown": "attaque"}

## Nombre de points des cercles des médaillons (assez pour rester ronds au zoom maximal).
const CIRCLE_PTS := 28

## Durée de l'ouverture de l'arbre (onde de sève depuis la graine) et du rebond au survol.
const INTRO_DUR := 0.75
const HOVER_POP := 0.3


## Icône d'un nœud : la compétence qu'il donne ou transforme, la forme de l'attaque qu'il donne,
## sinon son premier effet visible.
static func icon_of(n: Dictionary) -> String:
	# Nœud d'attaque : l'icône de la forme qu'il donne, sinon celle d'une attaque modifiée.
	for e in n["effects"]:
		if e.has("attack_form"):
			return "attaque_" + str(e["attack_form"])
	for e in n["effects"]:
		if e.has("attack_mod"):
			return "attaque_mod"
	for e in n["effects"]:
		if e.has("attack_form"):
			var form := "attaque_" + str(e["attack_form"])
			return form if Art.icon_ids().has(form) else "attaque"
	for e in n["effects"]:
		if e.has("attack_mod"):
			return "attaque_mod" if Art.icon_ids().has("attaque_mod") else "attaque"
	for e in n["effects"]:
		for key in ["skill", "skill_mod"]:
			if e.has(key):
				var sid := str(e[key])
				return sid if Art.ELEMENT_DE_COMPETENCE.has(sid) else "competence"
	for e in n["effects"]:
		if e.get("hidden", false):
			continue
		if e.has("stat") and ICON_OF_STAT.has(e["stat"]):
			return ICON_OF_STAT[e["stat"]]
		if e.has("do") and ICON_OF_ACTION.has(e["do"]):
			return ICON_OF_ACTION[e["do"]]
	return ""


# --- Dessin par lots ---

## Triangle sans triangulation (draw_primitive) : jamais d'erreur « triangulation failed », même aplati.
static func tri(c: CanvasItem, a: Vector2, b: Vector2, d: Vector2, col: Color) -> void:
	c.draw_primitive(PackedVector2Array([a, b, d]), PackedColorArray([col, col, col]), PackedVector2Array())


## Lot de triangles (points, couleurs par sommet, indices), envoyé en un seul appel de dessin.
static func batch() -> Dictionary:
	return {"p": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}


static func flush(c: CanvasItem, b: Dictionary) -> void:
	if b["i"].size() > 0:
		RenderingServer.canvas_item_add_triangle_array(c.get_canvas_item(), b["i"], b["p"], b["c"])


## Ajoute au lot une bande qui suit pts et s'affine de w0 (début) à w1 (fin), couleurs c0 → c1.
static func strip(b: Dictionary, pts: PackedVector2Array, w0: float, w1: float, c0: Color, c1: Color) -> void:
	var n := pts.size()
	if n < 2:
		return
	var p: PackedVector2Array = b["p"]
	var start := p.size()
	for i in n:
		var d: Vector2
		if i == 0:
			d = pts[1] - pts[0]
		elif i == n - 1:
			d = pts[n - 1] - pts[n - 2]
		else:
			d = pts[i + 1] - pts[i - 1]
		var o := d.normalized().orthogonal()
		var k := float(i) / (n - 1)
		var hw := lerpf(w0, w1, k) * 0.5
		var col := c0.lerp(c1, k)
		b["p"].append(pts[i] + o * hw)
		b["p"].append(pts[i] - o * hw)
		b["c"].append(col)
		b["c"].append(col)
	for i in n - 1:
		var a := start + i * 2
		b["i"].append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))


## Ajoute au lot un disque (éventail de seg triangles).
static func disc(b: Dictionary, p: Vector2, r: float, col: Color, seg := 20) -> void:
	var start: int = b["p"].size()
	b["p"].append(p)
	b["c"].append(col)
	for i in seg:
		b["p"].append(p + Vector2.from_angle(TAU * i / seg) * r)
		b["c"].append(col)
	for i in seg:
		b["i"].append_array(PackedInt32Array([start, start + 1 + i, start + 1 + (i + 1) % seg]))


# --- Silhouette ---

## Squelette de l'arbre : chaque nœud est rattaché à son voisin le plus proche de la graine
## (parcours en largeur), et porte le nombre de nœuds qui en dépendent. Les liens du squelette
## sont dessinés comme des branches, d'autant plus épaisses qu'elles portent de nœuds.
## Retourne {"tree": PackedByteArray (1 si le lien i est une branche), "weight": poids du nœud
## extérieur de chaque lien, "outer": nœud extérieur de chaque lien}.
static func skeleton(nodes: Array, edges: Array) -> Dictionary:
	var n := nodes.size()
	var depth := PackedInt32Array()
	depth.resize(n)
	depth.fill(-1)
	depth[0] = 0
	var order: Array = [0]
	var head := 0
	while head < order.size():
		var u: int = order[head]
		head += 1
		for m in nodes[u]["neighbors"]:
			if depth[m] < 0:
				depth[m] = depth[u] + 1
				order.append(m)
	var edge_of := {}
	for i in edges.size():
		edge_of[edges[i]] = i
	var parent := PackedInt32Array()
	parent.resize(n)
	parent.fill(-1)
	for u in order:
		if u == 0:
			continue
		var best := -1
		var bd := INF
		for m in nodes[u]["neighbors"]:
			if depth[m] == depth[u] - 1:
				var d: float = nodes[u]["pos"].distance_squared_to(nodes[m]["pos"])
				if d < bd:
					bd = d
					best = m
		parent[u] = best
	var weight := PackedFloat32Array()
	weight.resize(n)
	weight.fill(1.0)
	for j in range(order.size() - 1, 0, -1):
		var u: int = order[j]
		if parent[u] >= 0:
			weight[parent[u]] += weight[u]
	var is_tree := PackedByteArray()
	is_tree.resize(edges.size())
	is_tree.fill(0)
	var w := PackedFloat32Array()
	w.resize(edges.size())
	w.fill(1.0)
	var outer := PackedInt32Array()
	outer.resize(edges.size())
	for i in edges.size():
		var e: Vector2i = edges[i]
		outer[i] = e.y if depth[e.y] >= depth[e.x] else e.x
	for u in order:
		if parent[u] >= 0:
			var i: int = edge_of[Vector2i(mini(u, parent[u]), maxi(u, parent[u]))]
			is_tree[i] = 1
			w[i] = weight[u]
			outer[i] = u
	return {"tree": is_tree, "weight": w, "outer": outer}


## Largeur (coordonnées de l'arbre) d'une branche qui porte weight nœuds.
static func limb_width(weight: float) -> float:
	return clampf(2.8 * sqrt(weight), 3.0, 30.0)


## Écorce d'une branche de la couleur col (bois sombre, teinté).
static func bark(col: Color) -> Color:
	return col.darkened(0.72).lerp(Color(0.13, 0.095, 0.07), 0.45)


## Silhouette de l'arbre, sous le réseau : le tronc, vu d'en haut autour de la graine, et six
## maîtresses branches qui en partent et s'affinent, chacune avec quatre rameaux. sap[bi] (0 à 1) :
## jusqu'où la sève est montée dans la branche bi (le nœud appris le plus éloigné).
static func silhouette(c: CanvasItem, extent: float, colors: Array, sap: Array, z: float) -> void:
	var count := colors.size()
	var sector := TAU / count
	var under := batch()
	var body := batch()
	var light := batch()
	var sapb := batch()
	var tips: Array = []
	for bi in count:
		var col: Color = colors[bi]
		var a := (bi + 0.5) * sector - PI / 2.0
		var line := _limb_line(a, 0.0, 0.93 * extent, bi, extent)
		var w0 := 0.13 * extent
		var w1 := 0.01 * extent
		var bk := limb_bark(col)
		strip(under, line, w0 + 8.0 / z, w1 + 3.0 / z, Color(Art.c("contour"), 0.7), Color(Art.c("contour"), 0.25))
		strip(body, line, w0, w1, Color(bk, 0.95), Color(bk, 0.5))
		# Reflet d'un côté de la branche : elle prend du volume.
		strip(light, _offset(line, w0 * 0.22, w1 * 0.2), w0 * 0.22, w1 * 0.2, Color(col.lerp(bk, 0.45), 0.4), Color(col.lerp(bk, 0.45), 0.05))
		# Rameaux : deux de chaque côté, de plus en plus courts.
		for j in 4:
			var k: float = [0.26, 0.4, 0.54, 0.68][j]
			var side := 1.0 if (j + bi) % 2 == 0 else -1.0
			var q := _at(line, k)
			var ra := a + side * (0.45 - 0.05 * j)
			var twig := _limb_line(ra, 0.0, (0.36 - 0.045 * j) * extent, bi * 7 + j, extent, q)
			var tw0 := lerpf(w0, w1, k) * 0.6
			strip(under, twig, tw0 + 6.0 / z, 2.0 / z, Color(Art.c("contour"), 0.6), Color(Art.c("contour"), 0.15))
			strip(body, twig, tw0, w1 * 0.5, Color(bk, 0.9), Color(bk, 0.35))
			strip(light, _offset(twig, tw0 * 0.2, w1 * 0.1), tw0 * 0.2, w1 * 0.1, Color(col.lerp(bk, 0.45), 0.3), Color(col.lerp(bk, 0.45), 0.0))
		# Sève montée dans la branche : un filet clair, du tronc jusqu'au nœud appris le plus éloigné.
		var lvl: float = sap[bi] if bi < sap.size() else 0.0
		if lvl > 0.0:
			var part := PackedVector2Array()
			var steps := line.size() - 1
			for i in line.size():
				var k := float(i) / steps
				if k >= lvl:
					break
				part.append(line[i])
			part.append(_at(line, lvl))
			if part.size() >= 2:
				var sc := col.lerp(Art.ec("seve", "clair"), 0.35)
				var sw := lerpf(w0, w1, lvl) * 0.16
				strip(sapb, part, w0 * 0.14, sw, Color(sc, 0.55), Color(sc, 0.75))
				tips.append([part[part.size() - 1], sw, sc])
	flush(c, under)
	flush(c, body)
	flush(c, light)
	# Le tronc vu d'en haut : un disque d'écorce, ses cernes, puis la sève qui en part.
	var rt := 0.075 * extent
	var trunk := limb_bark(Color("b08a5c"))
	c.draw_circle(Vector2.ZERO, rt + 8.0 / z, Color(Art.c("contour"), 0.75))
	c.draw_circle(Vector2.ZERO, rt, trunk)
	for i in 4:
		var rr := rt * (0.3 + 0.17 * i)
		c.draw_arc(Vector2.ZERO, rr, 0.0, TAU, 48, Color(trunk.lightened(0.3), 0.4), maxf(1.0, 2.0 / z))
	c.draw_arc(Vector2.ZERO, rt * 0.96, PI * 1.05, PI * 1.7, 24, Color(trunk.lightened(0.45), 0.6), maxf(1.5, 3.0 / z))
	flush(c, sapb)
	for tip in tips:
		c.draw_circle(tip[0], tip[1] * 2.2, Color(tip[2], 0.25))
		c.draw_circle(tip[0], tip[1] * 0.9, Color(tip[2], 0.85))


## Écorce d'une maîtresse branche : plus claire que celle des liens, teintée de sa branche.
static func limb_bark(col: Color) -> Color:
	return col.darkened(0.6).lerp(Color(0.2, 0.15, 0.1), 0.4)


## Ligne décalée sur le côté (de d0 au début à d1 à la fin).
static func _offset(pts: PackedVector2Array, d0: float, d1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var d := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		out.append(pts[i] + d.normalized().orthogonal() * lerpf(d0, d1, float(i) / (n - 1)))
	return out


## Ligne médiane d'une branche (dans la direction a, de r0 à r1), légèrement sinueuse.
static func _limb_line(a: float, r0: float, r1: float, key: int, extent: float, from := Vector2.ZERO) -> PackedVector2Array:
	var d := Vector2.from_angle(a)
	var o := d.orthogonal()
	var pts := PackedVector2Array()
	var steps := 18
	for i in steps + 1:
		var k := float(i) / steps
		var wig := sin(k * PI * 1.7 + key * 1.9) * 0.03 * extent * k
		pts.append(from + d * lerpf(r0, r1, k) + o * wig)
	return pts


## Point d'une ligne brisée à la fraction k (0 à 1) de ses segments.
static func _at(pts: PackedVector2Array, k: float) -> Vector2:
	var f := clampf(k, 0.0, 1.0) * (pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], f - i)


# --- Fond ---

## Cernes de croissance : un anneau légèrement ondulé par anneau de l'arbre, comme le bois coupé.
static func growth_rings(rings: int, gap: float) -> Array:
	var out: Array = []
	for r in range(1, rings + 1):
		var pts := PackedVector2Array()
		var n := 72 + r * 8
		var ph := r * 1.7
		for i in n + 1:
			var a := TAU * i / n
			var wob := 1.0 + 0.018 * sin(a * 5.0 + ph) + 0.011 * sin(a * 11.0 - ph * 2.0) + 0.006 * sin(a * 23.0 + ph)
			pts.append(Vector2.from_angle(a) * r * gap * wob)
		out.append(pts)
	return out


## Fond de l'arbre, en coordonnées de l'arbre : lueur de la graine qui se fond dans le secteur teinté
## de chaque branche (une seule couche de remplissage, pour le rendu logiciel), cernes de croissance
## et fines racines qui séparent les branches. Dessiné une fois par zoom.
static func background(c: CanvasItem, extent: float, colors: Array, rings: Array, z: float) -> void:
	var count := colors.size()
	var sector := TAU / count
	var steps := 12
	var glow := Art.c("sol_vivant")
	# Rayons (en part de l'étendue) : lueur au centre, teinte de la branche plus loin, fondu au bord.
	# D'un secteur à l'autre, la teinte se mélange à celle du voisin : aucune frontière nette.
	var radii := [0.03, 0.3, 0.65, 1.0, 1.22]
	var b := batch()
	for bi in count:
		var a0 := bi * sector - PI / 2.0
		var mixed: Array = []
		for i in steps + 1:
			var f := float(i) / steps
			var other: Color = colors[(bi - 1 + count) % count] if f < 0.5 else colors[(bi + 1) % count]
			mixed.append((colors[bi] as Color).lerp(other, absf(f - 0.5)))
		for ri in radii.size() - 1:
			# Une bande de quadrilatères par anneau du dégradé (sans triangulation).
			var start: int = b["p"].size()
			for i in steps + 1:
				var d := Vector2.from_angle(a0 + sector * i / steps)
				b["p"].append(d * extent * radii[ri])
				b["c"].append(_bg_tint(ri, mixed[i], glow))
				b["p"].append(d * extent * radii[ri + 1])
				b["c"].append(_bg_tint(ri + 1, mixed[i], glow))
			for i in steps:
				var q := start + i * 2
				b["i"].append_array(PackedInt32Array([q, q + 1, q + 2, q + 1, q + 3, q + 2]))
	flush(c, b)
	var ring_col := Color(Art.c("brume"), 0.11)
	var lw := maxf(1.0, 1.0 / z)
	for pts in rings:
		c.draw_polyline(pts, ring_col, lw)
	# Racines de séparation entre deux branches : un trait noueux.
	var root_col := Color(Art.c("brume"), 0.16)
	for bi in count:
		var a := bi * sector - PI / 2.0
		var d := Vector2.from_angle(a)
		var o := d.orthogonal()
		var line := PackedVector2Array()
		for i in 13:
			var k := i / 12.0
			line.append(d * extent * lerpf(0.1, 1.0, k) + o * extent * 0.018 * sin(k * 9.0 + bi * 2.3))
		c.draw_polyline(line, root_col, maxf(1.5, 1.6 / z))


## Teinte du fond au cercle ri du dégradé (voir background).
static func _bg_tint(ri: int, col: Color, glow: Color) -> Color:
	match ri:
		0:
			return Color(glow, 0.3)
		1:
			return Color(glow.lerp(col, 0.3), 0.16)
		2:
			return Color(col, 0.11)
		3:
			return Color(col, 0.08)
	return Color(col, 0.0)


## Particules d'ambiance (pollen de sève qui monte doucement), en coordonnées de l'écran.
static func motes(c: CanvasItem, size: Vector2, t: float) -> void:
	var count := clampi(int(size.x * size.y / 30000.0), 20, 90)
	var light := Art.ec("seve", "clair")
	var warm := Art.c("or")
	for i in count:
		var h1 := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(i * 78.233) * 12543.1234, 1.0)
		var h3 := fposmod(sin(i * 39.425) * 24634.6345, 1.0)
		var speed := 6.0 + 14.0 * h2
		var y := fposmod(h3 * (size.y + 40.0) - t * speed, size.y + 40.0) - 20.0
		var x := h1 * size.x + sin(t * (0.3 + 0.4 * h3) + i) * (8.0 + 10.0 * h2)
		var tw := 0.55 + 0.45 * sin(t * (1.2 + h1 * 1.6) + i * 2.1)
		var col := light if i % 5 != 0 else warm
		var r := 1.0 + 1.8 * h2
		c.draw_circle(Vector2(x, y), r, Color(col, (0.12 + 0.18 * h1) * tw))


# --- Nœuds ---

## Médaillon d'un nœud (tout sauf les petits) : ombre, double trait (contour sombre et anneau à la
## couleur de la branche), fond sombre ou plein selon l'état, volume et reflet.
## shape : contour du nœud (vide pour un cercle de rayon r). st : "locked", "available" ou "owned".
## detail : vrai au zoom proche seulement (ombre, volume, anneau intérieur, reflet).
static func medallion(c: CanvasItem, shape: PackedVector2Array, p: Vector2, r: float, st: String, col: Color, w: float, detail: bool, ring_w: float) -> void:
	var is_round := shape.is_empty()
	var closed := shape.duplicate()
	if not is_round:
		closed.append(shape[0])
	if detail:
		if is_round:
			c.draw_circle(p + Vector2(0, r * 0.14), r, Art.c("ombre"))
		else:
			var shadow := PackedVector2Array()
			for q in shape:
				shadow.append(q + Vector2(0, r * 0.14))
			c.draw_colored_polygon(shadow, Art.c("ombre"))
	var ring: Color
	var fill: Color
	match st:
		"owned":
			fill = col.darkened(0.12) if detail else col
			ring = col.lerp(Color.WHITE, 0.55)
		"available":
			fill = col.darkened(0.74)
			ring = Color(col, 0.9)
		_:
			fill = col.darkened(0.84).lerp(Color(0.1, 0.1, 0.1), 0.35)
			ring = Color(col, 0.38)
	var volume := st == "owned" and detail
	if is_round:
		if volume:
			Art.volume_circle(c, p, r, fill, 0.9)
		else:
			c.draw_circle(p, r, fill)
		c.draw_arc(p, r, 0.0, TAU, CIRCLE_PTS, Art.c("contour"), ring_w + 2.4 * w)
		c.draw_arc(p, r, 0.0, TAU, CIRCLE_PTS, ring, ring_w)
	else:
		if volume:
			Art.volume(c, shape, fill, 0.9)
		else:
			c.draw_colored_polygon(shape, fill)
		c.draw_polyline(closed, Art.c("contour"), ring_w + 2.4 * w)
		c.draw_polyline(closed, ring, ring_w)
	if not detail:
		return
	if st != "owned":
		# Anneau intérieur du médaillon.
		var inner_col := Color(col, 0.16 if st == "locked" else 0.3)
		var iw := maxf(w, ring_w * 0.4)
		if is_round:
			c.draw_arc(p, r * 0.8, 0.0, TAU, CIRCLE_PTS, inner_col, iw)
		else:
			var cen := _center(shape)
			var inner := PackedVector2Array()
			for q in closed:
				inner.append(cen + (q - cen) * 0.8)
			c.draw_polyline(inner, inner_col, iw)
	if is_round:
		c.draw_arc(p + Vector2(-0.04, -0.06) * r, r * 0.8, PI * 1.08, PI * 1.62, 12, Color(1, 1, 1, 0.22 if st == "owned" else 0.1), maxf(w, r * 0.09))


static func _center(pts: PackedVector2Array) -> Vector2:
	var cen := Vector2.ZERO
	for q in pts:
		cen += q
	return cen / pts.size()


## Petit nœud : une perle. Pleine et bombée une fois apprise.
static func pearl(c: CanvasItem, p: Vector2, r: float, st: String, col: Color, w: float, detail: bool) -> void:
	match st:
		"owned":
			c.draw_circle(p, r * 1.8, Color(col, 0.16))
			if detail:
				Art.volume_circle(c, p, r, col, 0.9)
				c.draw_arc(p, r, 0.0, TAU, 20, col.lerp(Color.WHITE, 0.5), maxf(1.5, 1.0 * w))
			else:
				c.draw_circle(p, r, col)
		"available":
			c.draw_circle(p, r, col.darkened(0.7))
			c.draw_arc(p, r, 0.0, TAU, 20, Color(col, 0.85), maxf(2.0, 1.2 * w))
			if detail:
				c.draw_circle(p, r * 0.3, Color(col, 0.5))
		_:
			c.draw_circle(p, r, col.darkened(0.86).lerp(Color(0.1, 0.1, 0.1), 0.35))
			c.draw_arc(p, r, 0.0, TAU, 16, Color(col, 0.2), maxf(2.0, 1.2 * w))


## Couture d'un nœud de frontière hybride : un anneau en deux moitiés autour du nœud, chacune à la
## couleur de la branche qui est de son côté (dir : vecteur unitaire de « own » vers « other »).
static func border_seam(c: CanvasItem, p: Vector2, r: float, dir: Vector2, own: Color, other: Color, st: String, w: float) -> void:
	var alpha := 1.0 if st == "owned" else (0.85 if st == "available" else 0.4)
	var rr := r + maxf(3.0, 3.0 * w)
	var width := maxf(2.0, 1.6 * w)
	var a := dir.angle()
	var gap := 0.32
	c.draw_arc(p, rr, a + PI * 0.5 + gap, a + PI * 1.5 - gap, 12, Color(own.lerp(Color.WHITE, 0.15), alpha), width)
	c.draw_arc(p, rr, a - PI * 0.5 + gap, a + PI * 0.5 - gap, 12, Color(other.lerp(Color.WHITE, 0.15), alpha), width)


## Icône d'un nœud dans son médaillon : à la couleur de la branche, sombre sur un nœud appris.
static func node_icon(c: CanvasItem, id: String, p: Vector2, s: float, st: String, col: Color) -> void:
	if id == "":
		c.draw_circle(p, s * 0.35, Art.c("contour") if st == "owned" else Color(col, 0.6))
		return
	var ic: Color
	match st:
		"owned":
			ic = Art.c("contour").lerp(col, 0.18)
		"available":
			ic = col.lerp(Color.WHITE, 0.15)
		_:
			ic = Color(col.lerp(Color(0.5, 0.5, 0.5), 0.35), 0.6)
	Art.icon(c, id, Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0), ic)


## Graine de l'Arbre-Monde (l'origine) : halo, perle crème bombée et petite graine.
static func seed_node(c: CanvasItem, p: Vector2, r: float, col: Color, w: float, detail: bool) -> void:
	c.draw_circle(p, r * 2.6, Color(col, 0.06))
	c.draw_circle(p, r * 1.75, Color(col, 0.12))
	if detail:
		Art.volume_circle(c, p, r, col, 1.0)
		# Le germe : une pousse de sève au cœur de la graine.
		Art._leaf(c, p + Vector2(-0.12, 0.05) * r, r * 0.26, -PI * 0.7, Art.ec("seve").darkened(0.2))
		Art._leaf(c, p + Vector2(0.14, 0.02) * r, r * 0.22, -PI * 0.25, Art.ec("seve"))
		c.draw_arc(p, r, 0.0, TAU, 40, Art.c("contour"), 2.5 * w)
		c.draw_arc(p, r * 0.98, 0.0, TAU, 40, col.lerp(Color.WHITE, 0.6), maxf(1.0, 1.4 * w))
	else:
		c.draw_circle(p, r, col)


## Feuilles le long d'une branche apprise (zoom proche) : deux feuilles alternées par lien.
static func link_leaves(c: CanvasItem, pts: PackedVector2Array, col: Color, size: float, key: int) -> void:
	var n := pts.size() - 1
	for j in 2:
		var k := 0.34 + 0.32 * j
		var f := k * n
		var i := mini(int(f), n - 1)
		var q := pts[i].lerp(pts[i + 1], f - i)
		var d := (pts[i + 1] - pts[i]).normalized()
		var side := 1.0 if (key + j) % 2 == 0 else -1.0
		var a := d.angle() + side * 0.85
		var leaf := col.darkened(0.15 + 0.1 * j)
		Art._leaf(c, q + Vector2.from_angle(a) * size * 0.95, size, a, leaf)


# --- Animations ---

## Braises qui montent d'un nœud flétri encore couvert de cendre.
static func embers(c: CanvasItem, p: Vector2, r: float, t: float, key: int) -> void:
	var col := Art.ec("cendre")
	var light := Art.ec("cendre", "clair")
	for i in 3:
		var u := fposmod(t * 0.55 + i / 3.0 + (key % 97) / 97.0, 1.0)
		var a := (key % 13) * 0.5 + i * 2.1
		var q := p + Vector2(cos(a) * r * 0.7 + sin(t * 2.0 + i) * r * 0.15, -r * 0.2 - u * r * 1.9)
		var fade := sin(u * PI)
		Art._ember(c, q, r * 0.11 * (1.0 - u * 0.5), Color(col, 0.85 * fade))
		c.draw_circle(q, r * 0.05, Color(light, fade))


## Rayons de la graine d'origine : une couronne qui tourne lentement et respire.
static func seed_rays(c: CanvasItem, p: Vector2, r: float, col: Color, t: float) -> void:
	var b := Anim.breathe(t, 0.08)
	var light := col.lerp(Art.c("or"), 0.5)
	for i in 12:
		var a := TAU * i / 12.0 + t * 0.12
		var d := Vector2.from_angle(a)
		var o := d.orthogonal()
		var long := 1.0 if i % 2 == 0 else 0.7
		var base := p + d * r * 1.12
		var tip := p + d * r * (1.12 + 0.75 * long * b)
		tri(c, base + o * r * 0.09, tip, base - o * r * 0.09, Color(light, 0.32 * long))


## Halo d'un nœud appris qui respire, décalé d'un nœud à l'autre.
static func owned_halo(c: CanvasItem, p: Vector2, r: float, col: Color, t: float, phase: float) -> void:
	var b := 0.5 + 0.5 * sin(t * TAU / Anim.DUREE["respiration"] + phase)
	c.draw_circle(p, r * (1.45 + 0.2 * b), Color(col, 0.07 + 0.07 * b))


## Invitation d'un nœud disponible : anneau qui pulse et trois arcs qui tournent autour.
static func invite(c: CanvasItem, p: Vector2, r: float, col: Color, t: float, w: float, phase: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 4.0 + phase)
	var lw := maxf(3.0, 2.0 * w)
	c.draw_arc(p, r + maxf(2.0, 2.0 * w), 0.0, TAU, 32, Color(col, 0.3 + 0.6 * pulse), lw)
	var rr := r + maxf(7.0, 7.0 * w) + 2.0 * w * pulse
	var spin := t * 0.9 + phase
	for i in 3:
		var a := spin + TAU * i / 3.0
		c.draw_arc(p, rr, a, a + 0.75, 8, Color(col.lerp(Color.WHITE, 0.3), 0.25 + 0.35 * pulse), maxf(2.0, 1.4 * w))


## Survol : anneau clair, quatre épines qui tournent et pointent vers le nœud, onde au premier instant.
static func hover_mark(c: CanvasItem, p: Vector2, r: float, col: Color, t: float, since: float, w: float) -> void:
	var pop := Anim.pop(minf(since / HOVER_POP, 1.0))
	var rr := r + 6.0 * maxf(1.0, w)
	c.draw_arc(p, rr, 0.0, TAU, 40, Color(1, 1, 1, 0.95), 2.0 * w)
	var light := col.lerp(Color.WHITE, 0.6)
	var spin := t * 0.6
	for i in 4:
		var d := Vector2.from_angle(spin + TAU * i / 4.0)
		var o := d.orthogonal()
		var tip := p + d * (rr + 3.0 * w)
		var base := p + d * (rr + (3.0 + 11.0 * pop) * w)
		tri(c, base + o * 4.0 * w, tip, base - o * 4.0 * w, light)
	if since < HOVER_POP:
		var k := since / HOVER_POP
		c.draw_arc(p, rr + 18.0 * w * Anim.ease_out(k), 0.0, TAU, 40, Color(light, 0.7 * (1.0 - k)), 3.0 * w * (1.0 - k) + w)


## Goutte de sève qui coule vers un nœud qu'on vient d'apprendre : tête lumineuse et traînée.
static func sap_drop(c: CanvasItem, head: Vector2, tail: Vector2, col: Color, base: float) -> void:
	var light := col.lerp(Art.ec("seve", "clair"), 0.5).lerp(Color.WHITE, 0.3)
	c.draw_line(tail, head, Color(light, 0.55), base * 0.7)
	c.draw_circle(head, base * 1.6, Color(light, 0.22))
	c.draw_circle(head, base * 0.7, light)
	c.draw_circle(head, base * 0.3, Color.WHITE)


## Éclosion d'un nœud qu'on vient d'apprendre (k de 0 à 1) : éclair, onde, feuilles qui s'ouvrent
## et s'envolent, graines lumineuses projetées.
static func bloom(c: CanvasItem, p: Vector2, r: float, col: Color, k: float, petals: int, w: float, key: int) -> void:
	var light := col.lerp(Color.WHITE, 0.45)
	var open := Anim.ease_out(minf(k * 1.8, 1.0))
	var fade := 1.0 - maxf(0.0, k - 0.45) / 0.55
	# Anticipation : le nœud se gonfle, puis l'éclair.
	var swell := Anim.pop(minf(k * 3.0, 1.0))
	c.draw_circle(p, r * (1.0 + 0.35 * swell), Color(light, 0.55 * Anim.flash(k * 1.6)))
	c.draw_circle(p, r * 0.8, Color(Color.WHITE, 0.7 * Anim.flash(k * 3.0)))
	c.draw_arc(p, r * (1.0 + 2.6 * open), 0.0, TAU, 40, Color(light, 0.85 * (1.0 - k)), maxf(3.0, 3.0 * w) * (1.0 - 0.6 * k))
	c.draw_arc(p, r * (1.0 + 1.5 * open), 0.0, TAU, 40, Color(col, 0.5 * (1.0 - k)), maxf(2.0, 1.5 * w))
	var spin := k * 0.9
	for j in petals:
		var a := TAU * j / petals + spin
		var d := Vector2.from_angle(a)
		var l := r * (0.28 + 0.34 * open)
		Art._leaf(c, p + d * r * (0.9 + 1.6 * open), l, a, Color(light, 0.75 * fade))
	for j in 10:
		var h := fposmod(sin((key + j) * 12.9898) * 43758.5453, 1.0)
		var a := TAU * (j + h * 0.8) / 10.0
		var d := Vector2.from_angle(a)
		var dist := r * (1.2 + (2.6 + 1.6 * h) * Anim.ease_out(k))
		var q := p + d * dist
		var sf := clampf(1.0 - k * 1.1, 0.0, 1.0)
		c.draw_line(q - d * r * 0.5 * sf, q, Color(light, 0.5 * sf), maxf(1.5, w))
		c.draw_circle(q, r * 0.1 * (0.6 + h), Color(light, 0.95 * sf))
