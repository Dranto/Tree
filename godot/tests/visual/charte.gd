## Planche de la charte graphique : palette, éléments (et leur rendu pour trois formes de daltonisme),
## toutes les icônes, les trois formes d'annonce de danger, une silhouette par rôle (en couleur et
## en noir sur blanc) et la règle d'une action (anticipation, impact, retour).
## Tout vient de art.gd et anim.gd : la planche montre exactement ce que le jeu utilisera.
## Capturée par le banc visuel (scénario « charte », image charte.png).
extends Node2D

var view := Vector2(1600, 900)
var font: Font
var font_bold: Font

const L := 24.0          ## marge gauche
const R := 816.0         ## début de la colonne de droite
const COL_W := 760.0
const DALTO_ABR := {"protanopie": "P", "deuteranopie": "D", "tritanopie": "T"}


func _ready() -> void:
	var ui = load("res://scripts/ui_theme.gd")
	font = ui.font()
	font_bold = ui.font(true)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Art.c("decor").darkened(0.2))
	_text(Vector2(L, 30), "Charte graphique · Ronce", 22, Art.c("texte"), true)
	_text(Vector2(L + 300, 30), "Le fond est sourd · ce qui sert est clair et chaud · ce qui fait mal est saturé et contrasté", 13, Art.c("texte_doux"))
	_palette(Vector2(L, 62))
	_elements(Vector2(L, 262))
	_annonces(Vector2(L, 614))
	_icones(Vector2(R, 62))
	_silhouettes(Vector2(R, 370))
	_action(Vector2(R, 668))


# --- Sections ---

func _palette(o: Vector2) -> void:
	_title(o, "Palette par rôle")
	var y := o.y + 16
	for g in Art.GROUPES:
		_text(Vector2(o.x, y + 15), g[0], 11, Art.c("texte_doux"))
		var x := o.x + 104
		for role in g[1]:
			var col: Color = Art.c(role)
			if col.a < 1.0:
				_checker(Rect2(x, y + 2, 20, 20))
			draw_rect(Rect2(x, y + 2, 20, 20), col)
			draw_rect(Rect2(x, y + 2, 20, 20), Color(1, 1, 1, 0.18), false, 1.0)
			_text(Vector2(x + 26, y + 16), role, 11, Art.c("texte"))
			x += 128
		y += 24


func _elements(o: Vector2) -> void:
	_title(o, "Éléments · couleur, motif, icône, état")
	_text(Vector2(o.x + 290, o.y), "en bas : vus en protanopie (P), deutéranopie (D), tritanopie (T)", 11, Art.c("texte_doux"))
	var w := 126.0
	for i in Art.ELEMENT_IDS.size():
		var id: String = Art.ELEMENT_IDS[i]
		var e: Dictionary = Art.ELEMENTS[id]
		var x := o.x + i * w
		var cx := x + (w - 8) / 2.0
		var y := o.y + 18
		draw_rect(Rect2(x, y, w - 8, 322), Color(Art.c("panneau"), 0.7))
		# Icône sur un disque sombre
		draw_circle(Vector2(cx, y + 38), 30, Art.c("contour"))
		Art.icon(self, id, Rect2(cx - 26, y + 12, 52, 52))
		_text_c(Vector2(cx, y + 90), e["nom"], 15, e["couleur"].lerp(Color.WHITE, 0.25), w - 8, true)
		draw_multiline_string(font, Vector2(x + 6, y + 108), e["sens"], HORIZONTAL_ALIGNMENT_CENTER, w - 20, 10, 3, Art.c("texte_doux"))
		# Trois teintes
		for k in 3:
			var v: String = ["sombre", "couleur", "clair"][k]
			draw_rect(Rect2(x + 10 + k * 36, y + 148, 34, 12), e[v])
		# Motif
		Art.motif(self, id, Rect2(x + 8, y + 166, w - 24, 54), 0.4)
		# État sur un Flétri (corps neutre)
		var body := Vector2(cx, y + 246)
		Art.shadow(self, body, 16)
		draw_circle(body, 16, Art.c("ennemi"))
		draw_arc(body, 16, 0, TAU, 24, Art.c("ennemi_contour"), Art.TRAIT_FIN, true)
		Art.status(self, id, body, 16, 0.35)
		# Daltonismes
		var k2 := 0
		for kind in Art.DALTONISMES:
			var r := Rect2(x + 6 + k2 * 38, y + 274, 34, 34)
			draw_rect(r, Art.c("contour"))
			draw_rect(Rect2(r.position, Vector2(34, 6)), Art.simulate(e["couleur"], kind))
			Art.icon(self, id, Rect2(r.position + Vector2(5, 8), Vector2(24, 24)), Art.simulate(e["couleur"], kind))
			_text_c(Vector2(r.get_center().x, y + 318), DALTO_ABR[kind], 9, Art.c("texte_doux"), 34)
			k2 += 1


func _annonces(o: Vector2) -> void:
	_title(o, "Annonce d'une attaque · une seule grammaire")
	var stages := [["annonce 25 %", 0.25, -1.0], ["annonce 70 %", 0.7, -1.0], ["dernier quart : clignote", 0.9, -1.0], ["frappe : éclair", 1.0, 0.15]]
	var cw := 188.0
	var ch := 70.0
	var y0 := o.y + 26
	for s in stages.size():
		_text_c(Vector2(o.x + s * cw + cw / 2.0, y0 - 2), stages[s][0], 10, Art.c("texte_doux"), cw)
	for row in 3:
		for s in stages.size():
			var r := Rect2(o.x + s * cw, y0 + 4 + row * (ch + 4), cw - 6, ch)
			draw_rect(r, Art.c("sol_mort"))
			var c := r.get_center()
			var forme := {}
			match row:
				0:
					forme = {"type": "cercle", "centre": c, "rayon": 27.0}
				1:
					forme = {"type": "cone", "centre": c + Vector2(-50, 0), "direction": 0.0, "ouverture": 0.7, "rayon": 100.0}
				2:
					forme = {"type": "ligne", "de": c + Vector2(-80, 6), "a": c + Vector2(80, -6), "largeur": 18.0}
			Art.telegraph(self, forme, stages[s][1], stages[s][2], 0.0)


func _icones(o: Vector2) -> void:
	_title(o, "Icônes · les mêmes partout (barre, arbre, infobulles, journal, ramassage)")
	var y := o.y + 18
	var names := {"elements": "Éléments", "competences": "Compétences", "statistiques": "Statistiques", "monde": "Monde"}
	for g in Art.ICONES:
		_text(Vector2(o.x, y + 24), names[g], 11, Art.c("texte_doux"))
		var x := o.x + 82
		for id in Art.ICONES[g]:
			draw_circle(Vector2(x + 26, y + 20), 20, Art.c("contour"))
			Art.icon(self, id, Rect2(x + 8, y + 2, 36, 36))
			var label: String = Art.NOM_ICONE.get(id, Art.ELEMENTS[id]["nom"] if Art.ELEMENTS.has(id) else id)
			draw_multiline_string(font, Vector2(x - 2, y + 51), label, HORIZONTAL_ALIGNMENT_CENTER, 56, 9, 2, Art.c("texte_doux"))
			x += 56
		y += 70


func _silhouettes(o: Vector2) -> void:
	_title(o, "Formes par rôle · rond = allié, anguleux = Flétri, pointu = danger")
	var roles := [["Héros", "joueur"], ["Mêlée", "melee"], ["Tireur", "tireur"], ["Lourd", "lourd"], ["Élite", "elite"], ["Interactif", "interactif"], ["Butin", "butin"]]
	var w := COL_W / roles.size()
	var ground := Rect2(o.x, o.y + 14, COL_W, 150)
	draw_rect(ground, Art.c("sol_mort"))
	# Un peu de décor sourd derrière, pour juger la hiérarchie.
	for i in 9:
		var p := ground.position + Vector2(40 + i * 86, 30 + (i % 3) * 44)
		draw_line(p, p + Vector2(10, -24), Art.c("decor"), 3.0, true)
		draw_line(p + Vector2(5, -12), p + Vector2(18, -18), Art.c("decor"), 2.0, true)
	var white := Rect2(o.x, o.y + 196, COL_W, 74)
	draw_rect(white, Color.WHITE)
	for i in roles.size():
		var cx := o.x + w * (i + 0.5)
		_role(roles[i][1], Vector2(cx, ground.position.y + 80), false)
		_text_c(Vector2(cx, o.y + 186), roles[i][0], 12, Art.c("texte"), w, true)
		draw_set_transform(Vector2(cx, white.get_center().y + 6), 0.0, Vector2(0.62, 0.62))
		_role(roles[i][1], Vector2.ZERO, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_text(Vector2(o.x + 6, white.end.y - 6), "en noir sur blanc", 9, Color(0, 0, 0, 0.5))


func _action(o: Vector2) -> void:
	_title(o, "Une action · anticipation, annonce, impact, retour")
	var frames := [
		["repos", 0.0, -1.0, -1.0],
		["anticipation", 0.3, 0.25, -1.0],
		["annonce", Anim.SQUASH_ANTICIPATION, 0.9, -1.0],
		["impact", Anim.SQUASH_IMPACT, 1.0, 0.1],
		["retour", 0.75, 1.0, 0.6],
		["repos", 1.0, -1.0, -1.0],
	]
	var w := COL_W / frames.size()
	var y := o.y + 16
	for i in frames.size():
		var r := Rect2(o.x + i * w, y, w - 6, 132)
		draw_rect(r, Art.c("sol_mort"))
		var p := r.position + Vector2(36, 76)
		var f: Array = frames[i]
		if f[2] >= 0.0:
			var forme := {"type": "cone", "centre": p + Vector2(14, 0), "direction": 0.0, "ouverture": 1.0, "rayon": 76.0}
			Art.telegraph(self, forme, f[2], f[3], 0.0)
		# Le héros visé, dans la zone
		_role("joueur", p + Vector2(76, 2), false, 0.55, PI)
		var sq := Anim.squash(f[1])
		draw_set_transform(p, 0.0, sq)
		_role("melee", Vector2.ZERO, false, 0.85)
		if f[0] == "impact":
			draw_circle(Vector2.ZERO, 17, Color(Art.c("danger_eclair"), Anim.flash(0.1) * 0.7))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_text_c(Vector2(r.get_center().x, r.end.y - 8), f[0], 11, Art.c("texte"), w)
	var d := Anim.DUREE
	_text(Vector2(o.x, y + 158), "Durées types : anticipation %d ms · impact %d ms · retour %d ms · éclair %d ms · apparition %d ms · annonce ≥ %d ms" % [
		d["anticipation"] * 1000, d["impact"] * 1000, d["retour"] * 1000, d["eclair"] * 1000, d["apparition"] * 1000, d["annonce_min"] * 1000], 11, Art.c("texte_doux"))
	_text(Vector2(o.x, y + 178), "Couches : sol < décor bas < interactif < acteurs < projectiles < effets < décor haut < interface", 11, Art.c("texte_doux"))
	_text(Vector2(o.x, y + 198), "Traits : fin %.1f px (détails) · standard %.1f px (acteurs) · fort %.1f px (lourds, boss, frappe)" % [Art.TRAIT_FIN, Art.TRAIT, Art.TRAIT_FORT], 11, Art.c("texte_doux"))


# --- Silhouettes d'exemple (référence pour la vague 2) ---

## Dessine un rôle centré en p. mono : silhouette noire pleine, sans détail (test de lecture).
func _role(role: String, p: Vector2, mono: bool, scale := 1.0, facing := 0.0) -> void:
	var k := scale
	var black := Color.BLACK
	match role:
		"joueur":
			var r := 15.0 * k
			if not mono:
				Art.shadow(self, p, r)
			var d := Vector2.from_angle(facing)
			# Corps rond, deux feuilles en cape dans le dos, une graine lumineuse devant (la visée).
			for side in [-1, 1]:
				var a: float = facing + PI + side * 0.55
				var leaf := _leaf_pts(p + Vector2.from_angle(a) * r * 1.15, r * 0.7, a)
				draw_colored_polygon(leaf, black if mono else Art.c("joueur_accent").darkened(0.2))
				if not mono:
					Art.outline(self, leaf, Art.c("contour"), Art.TRAIT_FIN)
			draw_circle(p, r, black if mono else Art.c("joueur"))
			draw_circle(p + d * r * 1.15, r * 0.3, black if mono else Art.c("joueur_accent"))
			if not mono:
				draw_arc(p, r, 0, TAU, 28, Art.c("contour"), Art.TRAIT, true)
				draw_circle(p + d * r * 0.4, r * 0.16, Art.c("contour"))
		"melee":
			var r := 18.0 * k
			var pts := _jagged(p, r, [1.0, 0.72, 1.05, 0.8, 0.95, 0.68, 1.0, 0.85], 0.2)
			if not mono:
				Art.shadow(self, p, r)
			draw_colored_polygon(pts, black if mono else Art.c("ennemi"))
			for s in [-1, 1]:
				var cl := p + Vector2(r * 0.85, s * r * 0.5)
				_spike(cl, Vector2(1, s * 0.4).normalized(), r * 0.5, black if mono else Art.c("ennemi_contour"))
			if not mono:
				Art.outline(self, pts, Art.c("ennemi_contour"), Art.TRAIT)
				for s in [-1, 1]:
					_slit(p + Vector2(r * 0.35, s * r * 0.28), r * 0.2, s)
		"tireur":
			var r := 16.0 * k
			var pts := PackedVector2Array([p + Vector2(-r, -r * 0.7), p + Vector2(r * 0.5, -r * 0.55), p + Vector2(r * 0.8, 0), p + Vector2(r * 0.5, r * 0.55), p + Vector2(-r, r * 0.7), p + Vector2(-r * 0.6, 0)])
			if not mono:
				Art.shadow(self, p, r)
			draw_colored_polygon(pts, black if mono else Art.c("ennemi"))
			_spike(p + Vector2(r * 0.6, 0), Vector2.RIGHT, r * 1.3, black if mono else Art.c("ennemi_contour"))
			if not mono:
				Art.outline(self, pts, Art.c("ennemi_contour"), Art.TRAIT)
				draw_circle(p + Vector2(r * 0.1, 0), r * 0.2, Art.c("ennemi_oeil"))
		"lourd":
			var r := 27.0 * k
			var pts := _jagged(p, r, [1.0, 0.9, 1.0, 0.92, 1.0, 0.9], 0.0)
			if not mono:
				Art.shadow(self, p, r)
			draw_colored_polygon(pts, black if mono else Art.c("ennemi").darkened(0.15))
			if not mono:
				# Plaques d'écorce
				draw_line(p + Vector2(-r * 0.6, -r * 0.3), p + Vector2(r * 0.2, -r * 0.55), Art.c("ennemi_contour").darkened(0.35), Art.TRAIT)
				draw_line(p + Vector2(-r * 0.7, r * 0.3), p + Vector2(r * 0.1, r * 0.55), Art.c("ennemi_contour").darkened(0.35), Art.TRAIT)
				Art.outline(self, pts, Art.c("ennemi_contour"), Art.TRAIT_FORT)
				for s in [-1, 1]:
					_slit(p + Vector2(r * 0.45, s * r * 0.2), r * 0.13, s)
		"elite":
			var r := 18.0 * k
			if not mono:
				draw_circle(p, r * 1.7, Color(Art.c("elite"), 0.12))
				for i in 8:
					var a := i * TAU / 8.0
					draw_arc(p, r * 1.55, a, a + 0.45, 6, Color(Art.c("elite"), 0.7), Art.TRAIT_FIN, true)
			# Couronne de pointes
			for i in 5:
				var d := Vector2.from_angle(-PI / 2.0 + (i - 2) * 0.42)
				_spike(p + d * r * 0.8, d, r * 0.75, black if mono else Art.c("elite"))
			_role("melee", p, mono, k)
		"interactif":
			var r := 26.0 * k
			if not mono:
				draw_circle(p, r, Color(Art.c("interactif"), 0.10))
				draw_arc(p, r * 1.15, -PI / 2.0, -PI / 2.0 + TAU * 0.62, 32, Art.c("interactif"), Art.TRAIT, true)
				Art.glow(self, p, r * 0.6, "seve")
			for i in 6:
				var q := p + Vector2.from_angle(i * TAU / 6.0 + 0.3) * r * 0.85
				var stone := Art.ellipse(q, r * 0.17, r * 0.23, 10)
				draw_colored_polygon(stone, black if mono else Art.c("interactif"))
				if not mono:
					Art.outline(self, stone, Art.c("contour"), Art.TRAIT_FIN)
			if mono:
				draw_circle(p, r * 0.2, black)
		"butin":
			var r := 12.0 * k
			var bob := Vector2(0, -r * 0.35)
			if not mono:
				Art.shadow(self, p + Vector2(0, r * 0.3), r * 0.8)
				draw_circle(p + bob, r * 1.6, Color(Art.c("butin"), 0.15))
			var leaf := _leaf_pts(p + bob, r * 1.1, -PI / 4.0)
			draw_colored_polygon(leaf, black if mono else Art.c("butin"))
			if not mono:
				Art.outline(self, leaf, Art.c("contour"), Art.TRAIT_FIN)
				_sparkle(p + bob + Vector2(r * 0.9, -r * 0.9), r * 0.5)


func _jagged(p: Vector2, r: float, radii: Array, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in radii.size():
		pts.append(p + Vector2.from_angle(rot + i * TAU / radii.size()) * r * radii[i])
	return pts


func _leaf_pts(p: Vector2, l: float, a: float) -> PackedVector2Array:
	var d := Vector2.from_angle(a)
	var n := d.orthogonal()
	var pts := PackedVector2Array()
	for i in 9:
		var k := i / 8.0
		pts.append(p + d * l * (2.0 * k - 1.0) + n * l * 0.5 * sin(k * PI))
	for i in range(7, 0, -1):
		var k := i / 8.0
		pts.append(p + d * l * (2.0 * k - 1.0) - n * l * 0.5 * sin(k * PI))
	return pts


func _spike(base: Vector2, d: Vector2, len: float, col: Color) -> void:
	var n := d.orthogonal()
	draw_colored_polygon(PackedVector2Array([base + n * len * 0.25, base + d * len, base - n * len * 0.25]), col)


## Œil fendu des Flétris : un trait oblique de braise.
func _slit(p: Vector2, s: float, side: int) -> void:
	draw_line(p + Vector2(-s, -side * s * 0.6), p + Vector2(s, side * s * 0.2), Art.c("ennemi_oeil"), maxf(s * 0.7, 2.0), true)


func _sparkle(p: Vector2, s: float) -> void:
	var col := Art.c("butin").lerp(Color.WHITE, 0.6)
	draw_line(p + Vector2(-s, 0), p + Vector2(s, 0), col, 1.5, true)
	draw_line(p + Vector2(0, -s), p + Vector2(0, s), col, 1.5, true)


# --- Texte et petits outils ---

func _title(o: Vector2, s: String) -> void:
	_text(o, s, 14, Art.c("or"), true)


func _text(pos: Vector2, s: String, size: int, col: Color, bold := false) -> void:
	draw_string(font_bold if bold else font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_c(center: Vector2, s: String, size: int, col: Color, width: float, bold := false) -> void:
	draw_string(font_bold if bold else font, Vector2(center.x - width / 2.0, center.y), s, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)


func _checker(r: Rect2) -> void:
	for j in 2:
		for i in 2:
			draw_rect(Rect2(r.position + Vector2(i, j) * r.size / 2.0, r.size / 2.0), Color(0.8, 0.8, 0.8) if (i + j) % 2 == 0 else Color(0.5, 0.5, 0.5))
