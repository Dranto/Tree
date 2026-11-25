## Sol en trois couches (prototype technique, refonte du monde « Paysages d'herbier », vague 0 P).
##
## Réglage interne, éteint par défaut (« -- --paysage-sol ») : dans le Roncier, le shader du sol ne
## dessine plus que le lavis (couche 1 : grandes formes douces, sans bruit fin), et chaque carré de sol
## en cache (ground.gd, TILE_PX) reçoit par-dessus un calque dessiné une fois, au moment où le carré
## est rendu :
##   - couche 2, la matière de la région à l'encre fine : tiges rampantes et épines, fissures ;
##     ravivée, la tige verdit et se couvre de petites feuilles, la fissure se referme ;
##   - couche 3, les détails en grappes : cailloux éclairés d'en haut à gauche et feuilles sèches sur
##     la terre morte ; touffes d'herbe, fleurs de la région et baies sur la terre ravivée ;
##   - le bord de vie : sur le front (vie entre 0,28 et 0,65), des pousses claires et des fleurs.
##
## Les éléments sont tirés par cases du monde (CELL pixels, hachage de la case) : deux carrés voisins
## dessinent les mêmes éléments sur leur bord, sans couture. Un carré redessiné (vague de vie) relit
## la vie sous chaque élément. Rien n'est dessiné à chaque image : le coût est celui de la construction
## d'un carré (ground.gd la limite à TILE_BUDGET par image).
##
## Aucun texte visible, aucun chiffre de jeu, aucune collision : apparence seulement.
extends RefCounted

const Regions = preload("res://scripts/regions.gd")
const DrawBatch = preload("res://scripts/draw_batch.gd")

## Réglage interne : vrai avec « --paysage-sol ».
static var enabled := false
## Région du prototype (Roncier seulement en vague 0).
static var region := "ronce"
## Taille des carrés de sol (pixels d'écran), « --sol-tile=256|512|1024 » ; 0 : celle de ground.gd.
static var tile_px := 0
## Carrés préparés à l'avance dans le sens de la marche (ground.gd › ahead_frames), « --sol-avance=N »
## (0 : comme develop).
static var ahead_frames := -1
## Densité des éléments (« --sol-densite=0.5 » : moitié moins).
static var density := 1.0


## Lit les réglages sur la ligne de commande.
static func configure() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--paysage-sol":
			enabled = true
		elif a.begins_with("--sol-tile="):
			tile_px = clampi(a.get_slice("=", 1).to_int(), 128, 2048)
		elif a.begins_with("--sol-avance="):
			ahead_frames = clampi(a.get_slice("=", 1).to_int(), 0, 120)
		elif a.begins_with("--sol-densite="):
			density = clampf(a.get_slice("=", 1).to_float(), 0.0, 4.0)


## Prépare le sol (appelé par ground.gd dans _ready si le réglage est allumé) : lavis de la région.
static func setup(g) -> void:
	var i: int = g._region_ids.find(region)
	g.mat.set_shader_parameter("wash_region", i)
	for k in [["wash_dead_dark", "lavis_mort_sombre"], ["wash_dead_light", "lavis_mort_clair"],
			["wash_alive_dark", "lavis_vif_sombre"], ["wash_alive_light", "lavis_vif_clair"]]:
		var c := Art.mpc(region, k[1])
		g.mat.set_shader_parameter(k[0], Vector3(c.r, c.g, c.b))
	g.layered = true


## Calque d'un carré de sol : rect = rectangle du monde couvert par le carré.
static func make(g, rect: Rect2) -> Node2D:
	var l := TileLayer.new()
	l.ground = g
	l.area = rect
	l.reg = region
	l.dens = density
	return l


## Mesures (banc, tableau du prototype).
static func stats() -> Dictionary:
	return {"draws": TileLayer.draws, "usec": TileLayer.usec, "elements": TileLayer.elements, "verts": TileLayer.verts}


static func reset_stats() -> void:
	TileLayer.draws = 0
	TileLayer.usec = 0
	TileLayer.elements = 0
	TileLayer.verts = 0


class TileLayer extends Node2D:
	## Case de tirage des éléments (pixels du monde).
	const CELL := 112.0
	## Marge : un élément qui part d'une case voisine peut déborder sur le carré.
	const REACH := 60.0
	static var draws := 0
	static var usec := 0
	static var elements := 0
	static var verts := 0
	static var _b = DrawBatch.new()

	var ground
	var area := Rect2()
	var reg := "ronce"
	var dens := 1.0

	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		var r := RandomNumberGenerator.new()
		var c0 := Vector2i(floori((area.position.x - REACH) / CELL), floori((area.position.y - REACH) / CELL))
		var c1 := Vector2i(floori((area.end.x + REACH) / CELL), floori((area.end.y + REACH) / CELL))
		for cy in range(c0.y, c1.y + 1):
			for cx in range(c0.x, c1.x + 1):
				var cell := Vector2i(cx, cy)
				var mid := (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
				if Regions.weight(mid, reg) < 0.3:
					continue
				r.seed = hash(cell) ^ 0x5ca1ab1e
				_cell(r, Vector2(cell) * CELL)
		verts += _b.points.size()
		_b.flush(self)
		draws += 1
		usec += Time.get_ticks_usec() - t0

	## Éléments d'une case (origine o) : tiges, fissures, grappes, pousses du front.
	func _cell(r: RandomNumberGenerator, o: Vector2) -> void:
		# Toujours le même nombre de tirages par élément : la case dessine la même chose quelle que
		# soit la vie (seul l'état de chaque élément change).
		for i in 2:
			var p := o + Vector2(r.randf(), r.randf()) * CELL
			var roll := r.randf()
			var sd := r.randi()
			if roll > 0.62 * dens or Regions.weight(p, reg) < 0.5:
				continue
			_runner(p, sd, ground.life_at(p))
		var p2 := o + Vector2(r.randf(), r.randf()) * CELL
		var roll2 := r.randf()
		var sd2 := r.randi()
		if roll2 < 0.3 * dens and Regions.weight(p2, reg) > 0.5:
			var l2: float = ground.life_at(p2)
			if l2 < 0.45:
				_crack(p2, sd2, l2)
		for i in 2:
			var p := o + Vector2(r.randf(), r.randf()) * CELL
			var roll := r.randf()
			var sd := r.randi()
			if roll > 0.5 * dens or Regions.weight(p, reg) < 0.5:
				continue
			_cluster(p, sd, ground.life_at(p))
		# Bord de vie : trois points par case, une pousse là où le front passe.
		for i in 3:
			var p := o + Vector2(r.randf(), r.randf()) * CELL
			var sd := r.randi()
			var l: float = ground.life_at(p)
			if l > 0.28 and l < 0.65 and Regions.weight(p, reg) > 0.5:
				_sprout(p, sd, l)

	## Tige rampante : une polyligne fine qui serpente au sol, ombre d'encre décalée en bas à droite
	## (lumière d'en haut à gauche), épines sur la terre morte, feuilles sur la terre ravivée.
	func _runner(p: Vector2, sd: int, life: float) -> void:
		elements += 1
		var r := RandomNumberGenerator.new()
		r.seed = sd
		var alive := life > 0.5
		var a := r.randf() * TAU
		var pts := PackedVector2Array([p])
		var n := 5 + r.randi() % 3
		# Ravivée, la tige s'efface sous l'herbe : plus courte, feuillue.
		if alive:
			n = 3
		for i in n:
			a += r.randf_range(-0.55, 0.55)
			pts.append(pts[-1] + Vector2.from_angle(a) * r.randf_range(14.0, 22.0))
		var ink := Art.mpc("ronce", "encre_vive" if alive else "encre_morte")
		var stem := Art.mpc("ronce", "tige_vive" if alive else "tige_morte")
		var shadow := PackedVector2Array()
		for q in pts:
			shadow.append(q + Vector2(1.0, 1.3))
		_b.draw_polyline(shadow, Color(ink, 0.55), 2.2)
		_b.draw_polyline(pts, stem, 1.4)
		for i in range(1, pts.size() - 1):
			var d: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
			var side := 1.0 if i % 2 == 0 else -1.0
			var nn := d.orthogonal() * side
			if alive:
				_leaf(pts[i], d.angle() + 0.9 * side, r.randf_range(5.0, 7.5), Art.mpc("ronce", "feuille"))
			else:
				var q: Vector2 = pts[i]
				_b.draw_colored_polygon(PackedVector2Array([q + d * 1.4, q + nn * 3.6 + d * 0.8, q - d * 1.0]), ink)

	## Fissure de la terre morte : un trait brisé très fin, avec une branche.
	func _crack(p: Vector2, sd: int, _life: float) -> void:
		elements += 1
		var r := RandomNumberGenerator.new()
		r.seed = sd
		var a := r.randf() * TAU
		var pts := PackedVector2Array([p])
		for i in 4:
			a += r.randf_range(-0.7, 0.7)
			pts.append(pts[-1] + Vector2.from_angle(a) * r.randf_range(8.0, 15.0))
		var col := Color(Art.mpc("ronce", "fissure"), 0.8)
		_b.draw_polyline(pts, col, 1.0)
		var br := PackedVector2Array([pts[2], pts[2] + Vector2.from_angle(a + 1.2) * 9.0, pts[2] + Vector2.from_angle(a + 0.8) * 15.0])
		_b.draw_polyline(br, Color(col, 0.6), 0.8)

	## Grappe de détails : cailloux éclairés et feuilles sèches (mort), herbe, fleurs et baies (ravivé).
	func _cluster(p: Vector2, sd: int, life: float) -> void:
		elements += 1
		var r := RandomNumberGenerator.new()
		r.seed = sd
		var n := 3 + r.randi() % 5
		var spread := r.randf_range(10.0, 22.0)
		var alive := life > 0.5
		for i in n:
			var q := p + Vector2.from_angle(r.randf() * TAU) * spread * sqrt(r.randf())
			var k := r.randf()
			var sz := r.randf_range(0.7, 1.3)
			if not alive:
				if k < 0.7:
					_pebble(q, 3.2 * sz)
				else:
					_leaf(q, r.randf() * TAU, 6.0 * sz, Art.mpc("ronce", "feuille_seche"))
			else:
				if k < 0.6:
					_tuft(q, sz, r.randf())
				elif k < 0.85:
					_flower(q, 1.7 * sz)
				else:
					_b.draw_circle(q, 1.8 * sz, Art.mpc("ronce", "baie"))
					_b.draw_circle(q + Vector2(-0.6, -0.6), 0.6 * sz, Art.mpc("ronce", "fleur_coeur"))

	## Pousse du bord de vie : deux brins clairs en V et parfois une fleur, plus nets que l'herbe.
	func _sprout(p: Vector2, sd: int, _life: float) -> void:
		elements += 1
		var col := Art.mpc("ronce", "pousse")
		var s := 0.9 + float(sd & 7) / 14.0
		_b.draw_colored_polygon(PackedVector2Array([p + Vector2(-1.0, 0), p + Vector2(-4.5, -8.0) * s, p + Vector2(0.6, 0)]), col)
		_b.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.6, 0), p + Vector2(4.0, -9.0) * s, p + Vector2(1.0, 0)]), col.darkened(0.1))
		if sd & 24 == 0:
			_flower(p + Vector2(0, -9.0 * s), 1.8)

	func _pebble(q: Vector2, rx: float) -> void:
		_b.draw_colored_polygon(Art.ellipse(q + Vector2(1.0, 1.4), rx, rx * 0.68, 8), Color(Art.mpc("ronce", "encre_morte"), 0.5))
		_b.draw_colored_polygon(Art.ellipse(q, rx, rx * 0.68, 8), Art.mpc("ronce", "caillou"))
		_b.draw_colored_polygon(Art.ellipse(q + Vector2(-0.3, -0.3) * rx, rx * 0.45, rx * 0.28, 6), Art.mpc("ronce", "caillou_lumiere"))

	func _tuft(q: Vector2, s: float, u: float) -> void:
		var dark := Art.mpc("ronce", "herbe")
		var light := Art.mpc("ronce", "herbe_claire")
		for j in 3:
			var x := (j - 1) * 2.2 * s
			var tip := q + Vector2(x * 1.8 + (u - 0.5) * 3.0, -(7.0 + 3.0 * ((j + int(u * 3.0)) % 3)) * s)
			_b.draw_colored_polygon(PackedVector2Array([q + Vector2(x - 1.0 * s, 0), tip, q + Vector2(x + 1.0 * s, 0)]), light if j == 0 else dark)

	func _flower(q: Vector2, r0: float) -> void:
		var pet := Art.mpc("ronce", "fleur")
		for k in 5:
			_b.draw_circle(q + Vector2.from_angle(TAU * k / 5.0 - PI / 2.0) * r0, r0 * 0.75, pet)
		_b.draw_circle(q, r0 * 0.55, Art.mpc("ronce", "fleur_coeur"))

	func _leaf(q: Vector2, a: float, l: float, col: Color) -> void:
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		_b.draw_colored_polygon(PackedVector2Array([q, q + d * l * 0.5 + n * l * 0.28, q + d * l, q + d * l * 0.5 - n * l * 0.28]), col)
