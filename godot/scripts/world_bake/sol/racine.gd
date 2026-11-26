## Matière du sol de la région « racine » (Forêt), refonte du monde vague 2 (ground_layers.gd › SOL_REGION).
##
## Chaque fonction dessine un élément du calque d'un carré de sol à la place de la matière provisoire
## commune, et rend true ; elle rend false pour garder le dessin commun, **sans avoir tiré e** (les
## tirages suivants doivent rester les mêmes). L : le calque (ground_layers.gd › TileLayer), dont on
## appelle les primitives : L._tri, L._fan, L._oval, L._line, L._polyline, L._blade, L._leaf,
## L._pebble, L._tuft, L._flower ; L._p : palette de la région (fletri, apaise, ravive) ; e : le tirage
## de l'élément (RandomNumberGenerator), le même à chaque construction du carré.
## La géométrie ne dépend pas de la vie : le shader du calque choisit quoi montrer (mort, ravivé, front).
## Couleurs depuis Art.MONDE (palette de la région) ou pal ; aucune collision, aucun texte.
##
## Forêt pétrifiée (P6) :
##   - flétrie : des souches arasées au ras du sol, leurs cernes changés en pierre ; des racines qui
##     affleurent et replongent ; des congères de feuilles brunes ; de la sciure grise et des éclats
##     de pierre dans les grappes ;
##   - ravivée : un tapis de feuilles d'or et d'ocre, des racines brunes couvertes de mousse ; dans les
##     grappes, de la mousse, des glands, de petits champignons ocre et des feuilles tombées ;
##   - bord de vie : de petites fleurs d'or et de rouille.
extends RefCounted


static func _c(etat: String, cle: String):
	return Art.mc("racine", etat, cle)


## Terre morte, matière (couche 2) en p ; i : 0 ou 1 (deux tirages par case), sd : graine de e.
static func dead_matter(L, p: Vector2, i: int, sd: int, e: RandomNumberGenerator) -> bool:
	if i == 0:
		_rings(L, p, e)
	elif sd & 1:
		_root(L, p, e, false)
	else:
		_leaves(L, p, e, "fletri", 0.75)
	return true


## Terre ravivée, matière vivante (couche 2) en p.
static func alive_matter(L, p: Vector2, e: RandomNumberGenerator) -> bool:
	if e.randf() < 0.45:
		_root(L, p, e, true)
	else:
		_leaves(L, p, e, "ravive", 0.9)
	return true


## Un objet d'une grappe de la terre morte (couche 3) ; big : 1 pour le plus grand, 0,45-0,8 sinon ;
## kind : 0 touffes, 1 cailloux, 2 cendre (choisi une fois par grappe) ; pal : L._p["fletri"].
## Touffes sèches : le dessin commun ; cailloux : éclats de pierre anguleux ; cendre : sciure grise.
static func dead_item(L, p: Vector2, big: float, kind: int, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	if kind == 0:
		return false
	if kind == 1:
		_chip(L, p, 2.6 + 3.6 * big, pal["pierre"], e)
	else:
		_sawdust(L, p, big, Color(pal["cendre"], 0.55), e)
	return true


## Un objet d'une grappe de la terre ravivée (couche 3) ; k dans [0, 1) : < 0,55 touffe, < 0,85 fleur,
## sinon caillou ou baie ; pal : L._p["ravive"]. Touffes : la mousse olive du dessin commun ; à la
## place des fleurs, des glands et de petits champignons ocre ; à la place des cailloux, des feuilles
## d'or tombées.
static func alive_item(L, p: Vector2, big: float, k: float, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	if k < 0.55:
		return false
	if k < 0.7:
		_acorn(L, p, 2.2 + 1.6 * big)
		if big > 0.9:
			_acorn(L, p + Vector2(4.5, 1.5), 2.0 + 1.2 * big)
	elif k < 0.85:
		_mushroom(L, p, 2.6 + 2.4 * big, e)
	else:
		L._leaf(p, e.randf() * TAU, 6.0 + 4.0 * big, _c("ravive", "feuille"))
		L._leaf(p + Vector2(3, 1), e.randf() * TAU, 5.0 + 3.0 * big, _c("ravive", "feuille_2"))
	return true


## Une fleur du bord de vie, juste derrière le front, en p (rayon r) ; pal : L._p.
static func flower(L, p: Vector2, r: float, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	var petal: Color = pal["ravive"]["fleur"] if e.randf() < 0.65 else _c("ravive", "fleur_2")
	L._flower(p, r, petal, pal["ravive"]["fleur_coeur"])
	return true


# --- Dessins ---


## Souche arasée au ras du sol : ses cernes de pierre (ellipses aplaties), une fente qui la traverse.
static func _rings(L, c: Vector2, e: RandomNumberGenerator) -> void:
	var st: Dictionary = _c("fletri", "bois")
	var rr := e.randf_range(9.0, 15.0)
	L._oval(c + Vector2(1.2, 1.4), rr * 1.05, rr * 0.5, Color(st["ombre"], 0.5), 10)
	L._oval(c, rr, rr * 0.46, Color(st["clair"], 0.55), 10)
	var ink: Color = _c("fletri", "matiere")
	for k in range(1, 3):
		var f := 1.0 - 0.3 * k
		var pts := PackedVector2Array()
		var a0 := e.randf() * TAU
		for j in 8:
			var a := a0 + TAU * 0.8 * j / 7.0
			pts.append(c + Vector2(cos(a) * rr * f, sin(a) * rr * f * 0.46))
		L._polyline(pts, 0.8, Color(ink, 0.45))
	# La fente, du cœur vers le bord, et un éclat de reflet en haut à gauche.
	var a := e.randf() * TAU
	L._line(c, c + Vector2(cos(a) * rr * 1.1, sin(a) * rr * 0.55), 1.0, Color(ink, 0.6))
	L._oval(c + Vector2(-rr * 0.45, -rr * 0.18), rr * 0.25, rr * 0.08, Color(st["reflet"], 0.5), 5)


## Racine qui affleure : sort du sol, s'arque à peine et y replonge (ombre en bas à droite) ;
## ravivée, du bois brun avec des touffes de mousse.
static func _root(L, p: Vector2, e: RandomNumberGenerator, alive: bool) -> void:
	var etat := "ravive" if alive else "fletri"
	var wood: Dictionary = _c(etat, "bois")
	var a := e.randf_range(-0.5, 0.5) + (PI if e.randf() < 0.5 else 0.0)
	var l := e.randf_range(28.0, 46.0)
	var pts := PackedVector2Array()
	for j in 7:
		var u := j / 6.0
		pts.append(p + Vector2.from_angle(a + sin(u * 3.0) * 0.25) * l * u * Vector2(1.0, 0.7) + Vector2(0, -sin(u * PI) * 2.5))
	var shadow := PackedVector2Array()
	for q in pts:
		shadow.append(q + Vector2(1.0, 1.6))
	L._polyline(shadow, 4.2, Color(_c("fletri", "matiere"), 0.45))
	for j in pts.size() - 1:
		var w := 4.2 * sin(PI * (j + 0.5) / (pts.size() - 1)) + 1.0
		L._line(pts[j], pts[j + 1], w, wood["clair"])
	L._polyline(pts.slice(1, 5), 1.0, wood["reflet"].darkened(0.1))
	if alive:
		var moss: Dictionary = _c("ravive", "mousse")
		for j in [2, 4]:
			L._oval(pts[j] + Vector2(0, -1.5), 3.2, 1.6, moss["clair"], 6)
	else:
		# Veine d'ocre dans la racine pétrifiée.
		L._line(pts[2], pts[3], 0.8, Color(_c("fletri", "veine"), 0.7))


## Congère de feuilles couchées (brunes et sèches, ou d'or et d'ocre).
static func _leaves(L, c: Vector2, e: RandomNumberGenerator, etat: String, alpha: float) -> void:
	for i in e.randi_range(4, 7):
		var p := c + Vector2(e.randf_range(-22, 22), e.randf_range(-10, 10))
		var col: Color = _c(etat, "feuille" if i % 2 == 0 else "feuille_2")
		var a := e.randf() * TAU
		var l := e.randf_range(5.0, 8.0)
		L._leaf(p, a, l, Color(col, alpha))
		L._line(p, p + Vector2.from_angle(a) * l * 0.8, 0.6, Color(col.darkened(0.35), alpha))


## Éclat de pierre anguleux (lumière d'en haut à gauche).
static func _chip(L, q: Vector2, r: float, st: Dictionary, e: RandomNumberGenerator) -> void:
	var a := e.randf() * TAU
	var pts := PackedVector2Array()
	for j in 4:
		var aa := a + TAU * j / 4.0 + e.randf_range(-0.3, 0.3)
		pts.append(q + Vector2(cos(aa) * r, sin(aa) * r * 0.6))
	var sh := PackedVector2Array()
	for v in pts:
		sh.append(v + Vector2(1.0, 1.3))
	L._fan(sh, Color(st["ombre"].darkened(0.4), 0.55))
	L._fan(pts, st["clair"])
	L._tri(pts[0].lerp(q, 0.3), pts[1].lerp(q, 0.2), q + Vector2(-0.2, -0.3) * r, st["reflet"])


## Sciure : un petit tas pâle et des copeaux autour.
static func _sawdust(L, p: Vector2, big: float, col: Color, e: RandomNumberGenerator) -> void:
	L._oval(p, 3.0 + 4.0 * big, 1.4 + 1.8 * big, col, 7)
	for j in 3:
		var q := p + Vector2(e.randf_range(-9, 9), e.randf_range(-4, 4)) * (0.6 + big * 0.5)
		L._line(q, q + Vector2.from_angle(e.randf() * TAU) * 2.4, 1.0, col)


## Gland : la noix ocre et sa cupule sombre, reflet en haut à gauche.
static func _acorn(L, p: Vector2, r: float) -> void:
	var nut: Color = _c("ravive", "feuille")
	L._oval(p + Vector2(0.8, 1.2), r * 0.8, r * 0.45, Color(_c("ravive", "matiere"), 0.5), 6)
	L._oval(p, r * 0.7, r, nut.darkened(0.1), 7)
	L._oval(p + Vector2(0, -r * 0.75), r * 0.85, r * 0.45, _c("ravive", "fruit"), 7)
	L._oval(p + Vector2(-r * 0.25, -r * 0.05), r * 0.2, r * 0.35, nut.lightened(0.35), 4)


## Petit champignon ocre au chapeau rond.
static func _mushroom(L, p: Vector2, r: float, e: RandomNumberGenerator) -> void:
	var cap: Color = _c("ravive", "fleur_2")
	var foot: Color = _c("ravive", "cendre")
	var lean := e.randf_range(-0.2, 0.2)
	var top := p + Vector2(lean * r, -r * 1.3)
	L._line(p, top, maxf(r * 0.45, 1.0), foot.darkened(0.15))
	var dome := PackedVector2Array()
	for i in 7:
		var a := PI + PI * i / 6.0
		dome.append(top + Vector2(cos(a) * r, sin(a) * r * 0.8))
	L._fan(dome, cap)
	L._oval(top + Vector2(-r * 0.25, -r * 0.4), r * 0.35, r * 0.16, cap.lightened(0.35), 5)
