## Matière du sol de la région « seve » (Vallée), refonte du monde vague 2 (ground_layers.gd › SOL_REGION).
##
## Terre morte : un limon gris-vert où la sève a coulé puis figé en ruisselets ambrés et ternes, des
## croûtes de vase craquelées, des crosses de fougère sèches et des cailloux mouillés. Terre ravivée :
## une prairie humide vert d'eau, des ruisselets d'eau claire bordés de mousse, des frondes, des coussins
## de mousse piqués de myosotis d'eau et des gouttes de rosée ; au bord de vie, des myosotis.
##
## Chaque fonction dessine un élément du calque d'un carré de sol à la place de la matière provisoire
## commune, et rend true ; elle rend false pour garder le dessin commun, **sans avoir tiré e** (les
## tirages suivants doivent rester les mêmes). L : le calque (ground_layers.gd › TileLayer), dont on
## appelle les primitives : L._tri, L._fan, L._oval, L._line, L._polyline, L._blade, L._leaf,
## L._pebble, L._tuft, L._flower ; L._p : palette de la région (fletri, apaise, ravive) ; e : le tirage
## de l'élément (RandomNumberGenerator), le même à chaque construction du carré.
## La géométrie ne dépend pas de la vie : le shader du calque choisit quoi montrer (mort, ravivé, front).
## Couleurs depuis Art.MONDE › seve (sol_couches et palette) ; aucune collision, aucun texte.
extends RefCounted


static func _c(key: String) -> Color:
	return Art.mpc("seve", key)


## Un tracé qui serpente (ruisselet) : n points depuis p, pas de 9 à 15 px, aplati en trois quarts.
static func _meander(p: Vector2, n: int, e: RandomNumberGenerator) -> PackedVector2Array:
	var a := e.randf() * TAU
	var pts := PackedVector2Array([p])
	for i in n:
		a += e.randf_range(-0.55, 0.55)
		pts.append(pts[-1] + Vector2.from_angle(a) * e.randf_range(9.0, 15.0) * Vector2(1.0, 0.62))
	return pts


## Ruban plat le long d'un tracé : large au milieu (w), effilé aux deux bouts (une flaque qui coule).
static func _ribbon(L, pts: PackedVector2Array, w: float, col: Color, off := Vector2.ZERO) -> void:
	var n := pts.size()
	for j in n - 1:
		var a: Vector2 = pts[j] + off
		var b: Vector2 = pts[j + 1] + off
		var d := (b - a).normalized().orthogonal()
		var wa := w * sin(PI * (j + 0.5) / n) * 0.5
		var wb := w * sin(PI * (j + 1.5) / n) * 0.5
		L._fan(PackedVector2Array([a + d * wa, b + d * wb, b - d * wb, a - d * wa]), col)
		L._oval(b, wb, wb * 0.8, col, 6)


## Terre morte, matière (couche 2) en p ; i : 0 ou 1 (deux tirages par case), sd : graine de e.
static func dead_matter(L, p: Vector2, i: int, _sd: int, e: RandomNumberGenerator) -> bool:
	if i == 0 and e.randf() < 0.55:
		# Tache de sève figée : une flaque ambrée terne, quelques perles autour.
		var rx := e.randf_range(4.0, 7.0)
		L._oval(p + Vector2(0.8, 1.0), rx * 1.1, rx * 0.55, Color(_c("encre_morte"), 0.35), 8)
		L._oval(p, rx, rx * 0.5, _c("seve_figee"), 8)
		L._oval(p + Vector2(-rx * 0.35, -rx * 0.15), rx * 0.35, rx * 0.12, Color(_c("seve_figee_reflet"), 0.45), 5)
		for j in e.randi_range(1, 3):
			var q := p + Vector2(e.randf_range(-2.2, 2.2) * rx, e.randf_range(-0.9, 0.9) * rx)
			L._oval(q, 1.4, 1.0, _c("seve_figee"), 5)
		return true
	if i == 0:
		# Ruisselet de sève figée : une coulée plate, ambrée et terne, ourlée d'encre en bas à droite ;
		# un reflet sourd en haut à gauche ; une petite mare figée au bout.
		var pts := _meander(p, e.randi_range(6, 8), e)
		var w := e.randf_range(3.0, 4.4)
		_ribbon(L, pts, w + 1.4, Color(_c("encre_morte"), 0.35), Vector2(0.9, 1.3))
		_ribbon(L, pts, w, _c("seve_figee"))
		var hl := PackedVector2Array()
		for q in pts.slice(1, pts.size() - 1):
			hl.append(q + Vector2(-0.8, -w * 0.18))
		if hl.size() >= 2:
			L._polyline(hl, 0.8, Color(_c("seve_figee_reflet"), 0.45))
		var end: Vector2 = pts[-1]
		L._oval(end + Vector2(0.8, 1.0), 7.0, 3.6, Color(_c("encre_morte"), 0.45), 8)
		L._oval(end, 6.5, 3.2, _c("seve_figee"), 8)
		L._oval(end + Vector2(-2.2, -0.9), 2.4, 0.8, Color(_c("seve_figee_reflet"), 0.5), 5)
		return true
	# Croûte de vase craquelée : des écailles plates et claires, séparées par des fentes sombres.
	var rx := e.randf_range(10.0, 16.0)
	for k in e.randi_range(3, 5):
		var q := p + Vector2(e.randf_range(-0.7, 0.7) * rx, e.randf_range(-0.35, 0.35) * rx)
		var r := e.randf_range(3.0, 5.5)
		var pts := PackedVector2Array()
		var a0 := e.randf() * TAU
		for j in 5:
			var a := a0 + TAU * j / 5.0
			pts.append(q + Vector2(cos(a), sin(a) * 0.55) * r * e.randf_range(0.7, 1.1))
		var sh := PackedVector2Array()
		for v in pts:
			sh.append(v + Vector2(0.7, 0.9))
		L._fan(sh, Color(_c("fissure"), 0.5))
		L._fan(pts, Color(_c("croute"), 0.55))
	return true


## Terre ravivée, matière vivante (couche 2) en p : un ruisselet d'eau claire bordé de mousse, ou un
## tapis de mousse.
static func alive_matter(L, p: Vector2, e: RandomNumberGenerator) -> bool:
	if e.randf() < 0.35:
		# Ruisselet d'eau claire : un ruban plat, berge sombre en bas à droite, reflets en tirets.
		var pts := _meander(p, e.randi_range(4, 6), e)
		var w := e.randf_range(5.0, 7.0)
		_ribbon(L, pts, w + 2.4, Color(_c("encre_vive"), 0.4), Vector2(0.8, 1.4))
		_ribbon(L, pts, w, _c("ruisselet"))
		for j in range(1, pts.size() - 2, 2):
			var a: Vector2 = pts[j].lerp(pts[j + 1], 0.2) + Vector2(-0.8, -w * 0.15)
			var b: Vector2 = pts[j].lerp(pts[j + 1], 0.65) + Vector2(-0.8, -w * 0.15)
			L._line(a, b, 0.9, Color(_c("ruisselet_reflet"), 0.55))
		# Mousse en coussinets sur les berges.
		for j in range(1, pts.size() - 1):
			if e.randf() < 0.55:
				var d: Vector2 = (pts[j] - pts[j - 1]).normalized().orthogonal() * (w * 0.6 + 2.5) * (1.0 if e.randf() < 0.5 else -1.0)
				var q: Vector2 = pts[j] + d
				L._oval(q, 3.2, 2.0, _c("mousse"), 6)
				L._oval(q + Vector2(-0.8, -0.7), 1.4, 0.9, _c("mousse_claire"), 5)
		return true
	# Tapis de mousse : des coussins serrés, éclairés en haut à gauche.
	for j in e.randi_range(5, 9):
		var q := p + Vector2(e.randf_range(-16, 16), e.randf_range(-8, 8))
		var r := e.randf_range(2.4, 4.6)
		L._oval(q + Vector2(0.7, 0.9), r, r * 0.62, Color(_c("encre_vive"), 0.4), 6)
		L._oval(q, r, r * 0.62, _c("mousse"), 6)
		L._oval(q + Vector2(-r * 0.3, -r * 0.25), r * 0.45, r * 0.28, _c("mousse_claire"), 5)
	return true


## Crosse de fougère sèche : une tige courbe qui s'enroule sur elle-même.
static func _crosier(L, p: Vector2, h: float, col: Color, e: RandomNumberGenerator) -> void:
	var lean := e.randf_range(-0.35, 0.35)
	var top := p + Vector2(lean * h, -h)
	L._polyline(PackedVector2Array([p, p.lerp(top, 0.5) + Vector2(lean * h * 0.2, 0), top]), maxf(1.0, h * 0.1), col)
	var c := top + Vector2(h * 0.14 * signf(lean + 0.01), h * 0.05)
	L._oval(c, h * 0.18, h * 0.16, col, 7)
	L._oval(c, h * 0.07, h * 0.06, Color(_c("encre_morte"), 0.8), 5)


## Fronde de fougère : une nervure qui retombe, des folioles de part et d'autre.
static func _frond(L, p: Vector2, l: float, a: float, col: Color, light: Color) -> void:
	var d := Vector2.from_angle(a)
	var tip := p + d * l + Vector2(0, l * 0.18)
	var mid := p + d * l * 0.5
	L._polyline(PackedVector2Array([p, mid, tip]), maxf(0.8, l * 0.06), col)
	for k in 4:
		var u := 0.25 + 0.18 * k
		var q := p.lerp(tip, u)
		var w := l * 0.24 * (1.0 - u * 0.7)
		var nn := d.orthogonal()
		L._leaf(q, (nn + d * 0.4).angle(), w, col)
		L._leaf(q, (-nn + d * 0.4).angle(), w, light if k % 2 == 0 else col)


## Un objet d'une grappe de la terre morte (couche 3) ; big : 1 pour le plus grand, 0,45-0,8 sinon ;
## kind : 0 touffes, 1 cailloux, 2 cendre (choisi une fois par grappe) ; pal : L._p["fletri"].
static func dead_item(L, p: Vector2, big: float, kind: int, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	if kind == 0:
		# Crosses de fougère sèches, deux ou trois serrées.
		for j in 1 + e.randi() % 2:
			_crosier(L, p + Vector2((j - 0.5) * 4.0, 0), (8.0 + 6.0 * big) * e.randf_range(0.8, 1.1), _c("crosse").darkened(0.1 * j), e)
		return true
	if kind == 1:
		# Caillou mouillé, une tache de lichen terne sur le dessus.
		var rx := 2.6 + 4.0 * big
		L._pebble(p, rx, pal["pierre"])
		if rx > 4.5:
			L._oval(p + Vector2(rx * 0.15, -rx * 0.3), rx * 0.4, rx * 0.16, Color(_c("crosse"), 0.6), 5)
		return true
	# Flaque croupie : eau trouble, bord de vase, un reflet gris.
	var r := 4.0 + 5.0 * big
	L._oval(p + Vector2(0.6, 0.9), r * 1.15, r * 0.6, Color(_c("vase"), 0.7), 8)
	L._oval(p, r, r * 0.48, pal["eau"] if pal.has("eau") else Art.mc("seve", "fletri", "eau"), 8)
	L._line(p + Vector2(-r * 0.5, -r * 0.15), p + Vector2(-r * 0.05, -r * 0.2), 0.8, Color(Art.mc("seve", "fletri", "eau_reflet"), 0.6))
	return true


## Un objet d'une grappe de la terre ravivée (couche 3) ; k dans [0, 1) : < 0,55 touffe, < 0,85 fleur,
## sinon caillou ou baie ; pal : L._p["ravive"].
static func alive_item(L, p: Vector2, big: float, k: float, pal: Dictionary, e: RandomNumberGenerator) -> bool:
	if k < 0.55:
		# Petite fougère : trois à cinq frondes en éventail.
		var n := 3 + e.randi() % 3
		var l := (9.0 + 7.0 * big)
		for j in n:
			var a := PI + PI * (0.15 + 0.7 * j / maxf(1.0, n - 1.0)) + e.randf_range(-0.1, 0.1)
			_frond(L, p, l * e.randf_range(0.8, 1.05), a, _c("fronde") if j % 2 == 0 else _c("fronde").darkened(0.12), _c("fronde_claire"))
		return true
	if k < 0.85:
		# Coussin de mousse piqué de myosotis d'eau.
		var r := 4.0 + 3.5 * big
		L._oval(p + Vector2(0.8, 1.0), r, r * 0.6, Color(_c("encre_vive"), 0.4), 7)
		L._oval(p, r, r * 0.6, _c("mousse"), 7)
		L._oval(p + Vector2(-r * 0.3, -r * 0.2), r * 0.5, r * 0.3, _c("mousse_claire"), 6)
		for j in 2 + e.randi() % 2:
			var q := p + Vector2(e.randf_range(-r, r) * 0.7, e.randf_range(-r, r) * 0.35 - 1.0)
			L._flower(q, 1.3 + 0.7 * big, pal["fleur"], pal["fleur_coeur"])
		return true
	# Gouttes de rosée : une perle claire posée sur une feuille ronde (ou une flaque claire, pour le grand).
	if big > 0.9:
		var r := 5.5
		L._oval(p + Vector2(0.6, 0.9), r * 1.2, r * 0.62, Color(_c("encre_vive"), 0.45), 8)
		L._oval(p, r, r * 0.5, _c("ruisselet"), 8)
		L._line(p + Vector2(-r * 0.55, -r * 0.12), p + Vector2(-r * 0.1, -r * 0.2), 0.9, Color(_c("ruisselet_reflet"), 0.8))
		return true
	L._leaf(p + Vector2(-3, 0), -0.25, 6.0 + 3.0 * big, _c("fronde"))
	L._oval(p + Vector2(0.5, -1.0), 1.4 + big, 1.2 + big * 0.8, _c("goutte"), 6)
	return true


## Une fleur du bord de vie, juste derrière le front, en p (rayon r) : un myosotis d'eau, deux feuilles.
static func flower(L, p: Vector2, r: float, pal: Dictionary, _e: RandomNumberGenerator) -> bool:
	L._leaf(p + Vector2(0, r * 1.4), PI * 1.15, r * 1.8, _c("fronde"))
	L._leaf(p + Vector2(0, r * 1.4), -PI * 0.15, r * 1.6, _c("fronde_claire"))
	L._flower(p, r * 0.85, pal["ravive"]["fleur"], pal["ravive"]["fleur_coeur"])
	return true
