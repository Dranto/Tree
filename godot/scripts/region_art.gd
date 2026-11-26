## Dessins propres à une région : son Cœur de flétrissure (flétri, puis purifié) et le mur de l'arène
## de son boss. Ce fichier donne ceux du roncier, et les parties communes à toutes les régions.
##
## Une région en change par le champ « art » de data/regions/<id>.json : "art": "spore" fait dessiner
## son Cœur et son arène par scripts/region_art/spore.gd, qui étend ce fichier et ne remplace que les
## fonctions qui changent (Regions.art). Tout est statique : h est le Cœur (heart.gd : t, state,
## ratio(), pulse()), a l'arène (boss_arena.gd : center, radius, max_radius, gap_open, state, t,
## heart, _wall) ; on dessine sur le CanvasItem c.
##
## - heart_body(c, region, s, purified, k) : le Cœur, partie fixe (cuite), pied en (0, 0) ;
## - heart_live(c, h, s)                   : le Cœur, partie animée (lueur, braises, halo) ;
## - draw_arena_floor(c, a)             : le sol de l'arène (sombre, puis une clairière une fois vaincue) ;
## - draw_arena_wall(c, a)              : le mur, avec une brèche du côté du Cœur quand l'arène s'ouvre.
##
## Arène en décor (refonte du monde, vague 3 A) : une région dont arena_baked rend vrai n'utilise plus
## draw_arena_floor ni draw_arena_wall. Le moteur (boss_arena.gd) pose alors son mur en pièces de décor
## dans le calque trié en profondeur (le héros passe devant ou derrière, une pièce qui le cache
## s'efface), les fait cuire par lieux_bake.gd (jeux « arene/<région>/fletri » et « …/ravive »), ouvre
## la brèche en animation (les pièces s'écartent et rentrent sous terre), les fait trembler aux phases
## et aux coups du boss, les rapproche quand le mur se resserre et les fond dans leur image ravivée
## après la victoire. Contrat (Roncier ici, Marais dans region_art/spore.gd, dessins dans
## world_art/arenes.gd) :
## - arena_baked(region) -> bool          : la région a son arène en décor ;
## - arena_pieces(region, a) -> Array     : les pièces, [{key, ang, out, ring, flip, size}] : clé du
##   dessin, angle autour du centre, écart vers l'extérieur (px), ring : suit le rayon quand le mur se
##   resserre (faux pour un repère), flip : retournée, size : échelle ;
## - arena_piece_keys(region) -> Array    : toutes les clés (une image cuite par clé et par état) ;
## - arena_piece_box(region, key) -> Rect2 : place d'une pièce autour de son pied ;
## - arena_piece(ci, region, key, etat)   : une pièce, pied en (0, 0), etat « fletri » ou « ravive » ;
## - arena_piece_live(ci, region, key, a, i) : ce qui bouge sur la pièce i (dessiné à chaque image) ;
## - arena_floor(ci, a, etat)             : le sol (fixe, redessiné quand l'état change) ;
## - arena_live(ci, a)                    : ce qui bouge au sol (lueurs du combat, sillons du resserrement).
extends RefCounted

const Lieux = preload("res://scripts/world_art/lieux.gd")
const Arenes = preload("res://scripts/world_art/arenes.gd")


## Le Cœur (refonte du monde, vague 1 C) : une chose vivante et enracinée de la région, vue de trois
## quarts (scripts/world_art/lieux.gd : Roncier, Marais, et un Cœur commun en attendant ceux des autres
## régions). Sa partie fixe est cuite en image (heart_body, à la taille s, flétri ou purifié, k : ce
## qu'il a cédé) ; sa partie animée (lueur qui bat, braises, halo) est dessinée à chaque image
## (heart_live). Une région change de Cœur en remplaçant ces fonctions dans region_art/<art>.gd.
static func heart_body(c: CanvasItem, region: String, s: float, purified: bool, k: float) -> void:
	Lieux.heart_body(c, region, Vector2.ZERO, s, purified, k)


## Partie animée du Cœur h (heart.gd : region, t, state, ratio()), pied en (0, 0), taille s.
static func heart_live(c: CanvasItem, h, s: float) -> void:
	Lieux.heart_live(c, h.region, Vector2.ZERO, s, h.state == "purifie", h.ratio(), h.t, h.state == "siege")


## Place prise par heart_body autour du pied (pixels du monde), pour la cuisson.
static func heart_box(s: float) -> Rect2:
	return Lieux.heart_box(s)


## Sol de l'arène : sombre tant que le boss vit, une clairière qui respire une fois vaincu.
static func draw_arena_floor(c: CanvasItem, a) -> void:
	if a.state == "vaincue":
		c.draw_circle(a.center, a.max_radius * 0.5, Color(0.55, 0.95, 0.5, 0.08 + 0.03 * sin(a.t * 2.0)))
	else:
		c.draw_circle(a.center, a.radius, Color(0.08, 0.02, 0.03, 0.3 if a.state == "combat" else 0.2))


## Angle (autour du centre de l'arène) du milieu de la brèche : du côté du Cœur.
static func gate_angle(a) -> float:
	return (a.heart.center - a.center).angle()


## Vrai si l'angle « ang » tombe dans la brèche (ouverte de gap_open, de 0 à 1).
static func in_gap(a, ang: float, half := 0.42) -> bool:
	return absf(wrapf(ang - gate_angle(a), -PI, PI)) < half * a.gap_open


## Mur de ronces du roncier : deux tiges sombres hérissées d'épines ; une brèche s'ouvre du côté du
## Cœur quand l'arène est ouverte ; une fois le boss vaincu, les ronces reverdissent et fleurissent.
static func draw_arena_wall(c: CanvasItem, a) -> void:
	var wall: Array = a._wall
	var n := wall.size()
	var center: Vector2 = a.center
	var fight: bool = a.state == "combat"
	var alive: bool = a.state == "vaincue"
	var stem := Color("2c2226")
	var thorn := Color("8a7f78")
	if fight:
		stem = Color("3d1f24")
		thorn = Color("e0a090")
	elif alive:
		stem = Color("2f6b2a")
		thorn = Color("468f38")
	var pts := PackedVector2Array()
	var pts2 := PackedVector2Array()
	for i in n + 1:
		var w: Array = wall[i % n]
		var ang := TAU * i / n
		if in_gap(a, ang):
			_wall_strip(c, pts, pts2, stem)
			pts = PackedVector2Array()
			pts2 = PackedVector2Array()
			continue
		var dir := Vector2.from_angle(ang)
		var r: float = a.radius * (1.0 + w[0])
		pts.append(center + dir * r)
		pts2.append(center + dir * (r + 16.0 + 8.0 * w[2]))
		var len: float = 16.0 * w[1]
		var lean := Vector2.from_angle(ang + 0.5 * w[2])
		c.draw_line(center + dir * r, center + dir * r - lean * len, thorn, 3.0)
		c.draw_line(center + dir * (r + 14.0), center + dir * (r + 14.0) + lean * len, thorn, 3.0)
		if alive and i % 3 == 0:
			var rose := center + dir * (r + 8.0)
			for j in 5:
				c.draw_circle(rose + Vector2.from_angle(TAU * j / 5.0 + i) * 5.0, 4.5, Color("e0675e").lerp(Color("f48fb1"), 0.5 + 0.5 * w[2]))
			c.draw_circle(rose, 3.0, Color("fff3c4"))
	_wall_strip(c, pts, pts2, stem)


static func _wall_strip(c: CanvasItem, pts: PackedVector2Array, pts2: PackedVector2Array, stem: Color) -> void:
	if pts.size() >= 2:
		c.draw_polyline(pts, stem, 13.0)
		c.draw_polyline(pts2, stem.darkened(0.25), 9.0)


# --- Arène en décor (vague 3 A) ---


## Vrai si l'arène de la région est en décor (pièces cuites). Ce fichier ne la donne qu'au Roncier : une
## région qui étend ce fichier garde son ancien mur tant qu'elle ne remplace pas cette fonction.
static func arena_baked(region: String) -> bool:
	return region == "ronce" or region == ""


## Mur en anneau : n pièces « m* » (variantes tirées une fois), plus basses côté sud (devant le héros
## dans la vue de trois quarts), et les repères « r* » au fond de l'arène, à l'opposé de la brèche.
static func arena_ring(a, n: int, variants: int, landmarks: Array, seed: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var out := []
	for i in n:
		var ang := TAU * i / n + r.randf_range(-0.25, 0.25) * TAU / n
		var south := clampf(sin(ang), 0.0, 1.0)
		out.append({"key": "m%d" % (r.randi() % variants), "ang": ang, "out": r.randf_range(-4.0, 10.0), "ring": true,
			"flip": r.randf() < 0.5, "size": lerpf(r.randf_range(0.95, 1.1), 0.72, south)})
	var back := gate_angle(a) + PI
	for l in landmarks:
		out.append({"key": l[0], "ang": back + float(l[1]), "out": float(l[2]), "ring": false, "flip": l[1] < 0.0, "size": 1.0})
	return out


static func arena_pieces(region: String, a) -> Array:
	return arena_ring(a, 42, Arenes.MUR_VARIANTES, [["r0", -0.42, 62.0], ["r0", 0.0, 80.0]], 41)


static func arena_piece_keys(region: String) -> Array:
	return Arenes.keys("ronce")


static func arena_piece_box(region: String, key: String) -> Rect2:
	return Arenes.piece_box("ronce", key)


static func arena_piece(ci: CanvasItem, region: String, key: String, etat: String) -> void:
	Arenes.piece(ci, "ronce", key, etat)


static func arena_piece_live(ci: CanvasItem, region: String, key: String, a, i: int) -> void:
	Arenes.piece_live(ci, "ronce", key, a, i)


static func arena_floor(ci: CanvasItem, a, etat: String) -> void:
	Arenes.ground(ci, a, "ronce", etat)


static func arena_live(ci: CanvasItem, a) -> void:
	Arenes.live(ci, a, "ronce")
