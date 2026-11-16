## Planche de la charte graphique : palette, éléments (et leur rendu pour trois formes de daltonisme),
## toutes les icônes, les trois formes d'annonce de danger, une silhouette par rôle (en couleur et
## en noir sur blanc) et la règle d'une action (anticipation, impact, retour).
## Tout vient de art.gd et anim.gd : la planche montre exactement ce que le jeu utilisera.
## Capturée par le banc visuel (scénario « charte », image charte.png).
extends Node2D

var view := Vector2(1600, 900)
## "planche" : la charte sur une page ; "details" : personnages et objets en grand.
var page := "planche"
## Temps de l'animation (s). Toutes les animations de la planche bouclent sur PERIODE.
var t := 0.0
## Intensité de l'éclair « coup reçu » appliqué aux figures (0 à 1).
var _flash := 0.0
## Charge du tir du Tireur (0 à 1), pour sa pointe qui rougeoie.
var tir_charge := 0.0
const PERIODE := 2.4
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
	if page == "details":
		_details()
		return
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
		Art.icon_badge(self, id, Rect2(cx - 32, y + 6, 64, 64))
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
			Art.icon_badge(self, id, Rect2(x + 4, y - 2, 44, 44))
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


# --- Page « détails » : personnages et objets en grand ---

func _details() -> void:
	_text(Vector2(L, 30), "Charte graphique · personnages et objets en détail", 22, Art.c("texte"), true)
	_text(Vector2(L + 560, 30), "volume : lumière en haut à gauche · ombre portée · tout bouge en boucle de %.1f s" % PERIODE, 13, Art.c("texte_doux"))
	var cw := (view.x - 2 * L) / 6.0
	var cells := [
		["Héros · repos", "hero_repos"], ["Héros · lancer", "hero_lancer"], ["Héros · coup reçu", "hero_touche"],
		["Flétri · repos", "fletri_repos"], ["Flétri · attaque", "fletri_attaque"], ["Flétri · saignant", "fletri_saignant"],
		["Tireur d'épines · tir", "tireur"], ["Colosse · frappe au sol", "colosse"], ["Élite", "elite"],
		["Sanctuaire · en cours", "sanct_eteint"], ["Sanctuaire ravivé", "sanct_ravive"], ["Butin", "butin"],
	]
	for i in cells.size():
		var col := i % 6
		var row := i / 6
		var r := Rect2(L + col * cw, 54 + row * 332, cw - 10, 318)
		_ground(r, i + row, cells[i][1] == "sanct_ravive")
		_scene(cells[i][1], r)
		_text_c(Vector2(r.get_center().x, r.position.y + 22), cells[i][0], 13, Art.c("texte"), cw, true)
	# Médaillons des compétences, tels qu'ils iront dans la barre, avec leur recharge.
	var y := 54 + 2 * 332 + 6
	_text(Vector2(L, y + 30), "Médaillons de compétence", 13, Art.c("or"), true)
	_text(Vector2(L, y + 48), "recharge en arc, éclat quand c'est prêt", 10, Art.c("texte_doux"))
	var x := L + 230
	var ids: Array = Art.ICONES["competences"]
	for i in ids.size():
		var rect := Rect2(x, y, 64, 64)
		var f := _u(i / float(ids.size()))   # avancement de la recharge
		var ready := f > 0.75
		var pop := Anim.pop(clampf((f - 0.75) / 0.12, 0.0, 1.0)) if ready else 1.0
		var grow := rect.grow(4.0 * (pop - 1.0) * 8.0) if ready else rect
		Art.icon_badge(self, ids[i], grow)
		if not ready:
			_cooldown(rect.get_center(), 30.0, f / 0.75)
		else:
			var k := clampf((f - 0.75) / 0.25, 0.0, 1.0)
			draw_arc(rect.get_center(), 34.0 + 10.0 * k, 0, TAU, 40, Color(Art.icon_color(ids[i]).lightened(0.4), 1.0 - k), 3.0, true)
		_text_c(Vector2(x + 32, y + 82), Art.NOM_ICONE[ids[i]], 10, Art.c("texte_doux"), 120)
		x += 132


## Voile de recharge : secteur sombre qui se retire dans le sens des aiguilles d'une montre.
func _cooldown(c: Vector2, r: float, done: float) -> void:
	var pts := PackedVector2Array([c])
	var start := -PI / 2.0 + TAU * clampf(done, 0.0, 1.0)
	var n := 24
	for i in n + 1:
		pts.append(c + Vector2.from_angle(start + (TAU * (1.0 - done)) * i / n) * r)
	if pts.size() >= 3 and done < 0.999:
		draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	draw_arc(c, r + 1.0, -PI / 2.0, start, 32, Color(1, 1, 1, 0.7), 2.0, true)


## Une case animée de la planche de détail.
func _scene(kind: String, r: Rect2) -> void:
	var c := r.get_center() + Vector2(0, -10)
	var u := _u()
	_flash = 0.0
	tir_charge = 0.0
	match kind:
		"hero_repos":
			_at(c, Vector2.ONE * Anim.breathe(t, 0.035))
			_role("joueur", Vector2.ZERO, false, 3.0, 0.0)
			_reset()
		"hero_lancer":
			# Anticipation, lancer, la graine file et éclate au bout de la case.
			var sq := Anim.squash(clampf(u / 0.45, 0.0, 1.0), 0.7)
			_at(c + Vector2(-40, 0), Vector2(sq.y, sq.x))
			_role("joueur", Vector2.ZERO, false, 3.0, 0.0, "lancer" if u > 0.12 and u < 0.35 else "")
			_reset()
			if u >= 0.22 and u < 0.62:
				var k := Anim.ease_out((u - 0.22) / 0.4)
				var a := c + Vector2(30 + 70 * k, 0)
				for j in 8:
					draw_circle(a - Vector2(j * 7, 0), 9.0 - j, Color(Art.ec("seve"), 0.6 - j * 0.07))
				Art.glow(self, a, 26, "seve")
				draw_circle(a, 7, Art.ec("seve", "clair"))
			elif u >= 0.62 and u < 0.9:
				var k := (u - 0.62) / 0.28
				var a := c + Vector2(100, 0)
				draw_arc(a, 8 + 30 * Anim.ease_out(k), 0, TAU, 28, Color(Art.ec("seve", "clair"), 1.0 - k), 3.0, true)
				for j in 6:
					var d := Vector2.from_angle(j * TAU / 6.0 + 0.3)
					_leaf(a + d * (6 + 26 * Anim.ease_out(k)), 5.0, d.angle(), Color(Art.ec("seve"), 1.0 - k))
		"hero_touche":
			var hit := 0.15
			var k := (u - hit) / 0.35
			_flash = Anim.flash(k) if k >= 0.0 and k <= 1.0 else 0.0
			var kb := Vector2(-18 * Anim.flash(k), 0) if k >= 0.0 and k <= 1.0 else Vector2.ZERO
			var sq := Anim.squash(clampf(k + Anim.SQUASH_ANTICIPATION, 0.0, 1.0), 0.8) if k >= 0.0 and k <= 1.0 else Vector2.ONE
			_at(c + kb, sq)
			_role("joueur", Vector2.ZERO, false, 3.0, 0.0, "touche")
			_reset()
			# Deux feuilles arrachées qui tombent en tournoyant.
			if k >= 0.0:
				for j in 2:
					var fk := clampf(k * 0.8, 0.0, 1.0)
					var q := c + Vector2(-60 - 25 * j, -20 + 30 * j) + Vector2(sin(fk * 6.0 + j) * 12, 60 * fk)
					_leaf(q, 8.0, fk * 5.0 + j, Color(Art.c("joueur_accent").darkened(0.3), 1.0 - fk))
		"fletri_repos":
			_at(c, Vector2(1.0 + 0.03 * _w(), 1.0 - 0.03 * _w()), 0.04 * _w(1.0, 0.25))
			_role("melee", Vector2.ZERO, false, 3.0)
			_reset()
		"fletri_attaque":
			var forme := {"type": "cone", "centre": c + Vector2(-10, 0), "direction": 0.0, "ouverture": 1.0, "rayon": 112.0}
			var prog := clampf(u / 0.55, 0.0, 1.0)
			var frappe := (u - 0.55) / 0.25 if u >= 0.55 and u < 0.8 else -1.0
			if u < 0.8:
				Art.telegraph(self, forme, prog, frappe, t)
			var sq := Anim.squash(clampf(u / 0.8, 0.0, 1.0))
			var lunge := Vector2(30 * Anim.flash((u - 0.55) / 0.3), 0) if u >= 0.55 and u < 0.85 else Vector2.ZERO
			_at(c + Vector2(-50, 0) + lunge, sq)
			_role("melee", Vector2.ZERO, false, 2.6, 0.0, "anticipation" if u < 0.6 else "")
			_reset()
		"fletri_saignant":
			# Un sursaut à chaque goutte de saignement.
			var tick := fposmod(u * 3.0, 1.0)
			var shake := Vector2(sin(tick * 40.0) * 5.0 * Anim.flash(tick * 4.0), 0)
			_at(c + shake, Vector2.ONE)
			_role("melee", Vector2.ZERO, false, 3.0, 0.0, "saignant")
			_reset()
			if tick < 0.3:
				_text_c(c + Vector2(40, -60 - 40 * tick), "%d" % (4 + int(u * 3.0)), 18, Art.ec("saignement", "clair").lerp(Color.WHITE, 0.3), 60, true)
		"tireur":
			# Il vise (ligne d'annonce), la pointe rougeoie, il tire, recule, l'épine file.
			var aim := clampf(u / 0.5, 0.0, 1.0)
			tir_charge = aim if u < 0.5 else maxf(0.0, 1.0 - (u - 0.5) * 6.0)
			var recoil := Vector2(-16 * Anim.flash((u - 0.5) / 0.25), 0) if u >= 0.5 and u < 0.75 else Vector2.ZERO
			if u < 0.55:
				Art.telegraph(self, {"type": "ligne", "de": c + Vector2(10, 0), "a": c + Vector2(r.size.x / 2.0 - 14, 0), "largeur": 10.0}, aim, (u - 0.5) / 0.05 if u >= 0.5 else -1.0, t)
			_at(c + Vector2(-60, 0) + recoil, Vector2.ONE)
			_role("tireur", Vector2.ZERO, false, 2.2)
			_reset()
			if u >= 0.5 and u < 0.8:
				var k := (u - 0.5) / 0.3
				var a := c + Vector2(10 + 90 * k, 0)
				_spike_vol(a, Vector2.RIGHT, 22, Art.ec("epine", "clair"))
				draw_line(a - Vector2(30, 0), a, Color(Art.ec("epine"), 0.4), 2.0, true)
		"colosse":
			# Il se soulève, l'annonce circulaire se remplit, il s'écrase : éclair, onde de poussière.
			var forme := {"type": "cercle", "centre": c + Vector2(0, 10), "rayon": 104.0}
			var prog := clampf(u / 0.6, 0.0, 1.0)
			if u < 0.8:
				Art.telegraph(self, forme, prog, (u - 0.6) / 0.2 if u >= 0.6 else -1.0, t)
			if u >= 0.6:
				var k := (u - 0.6) / 0.4
				draw_arc(c + Vector2(0, 10), 50 + 60 * Anim.ease_out(k), 0, TAU, 48, Color(Art.c("brume").lightened(0.3), 0.8 * (1.0 - k)), 6.0 * (1.0 - k) + 1.0, true)
			var lift := -14.0 * Anim.ease_in_out(prog) if u < 0.6 else -14.0 * (1.0 - clampf((u - 0.6) / 0.05, 0.0, 1.0))
			var sq := Anim.squash(clampf((u - 0.45) / 0.5, 0.0, 1.0), 0.8) if u > 0.45 else Vector2.ONE * (1.0 + 0.05 * prog)
			_at(c + Vector2(0, lift), Vector2(sq.y, sq.x))
			_role("lourd", Vector2.ZERO, false, 2.2)
			_reset()
		"elite":
			_at(c, Vector2.ONE * Anim.breathe(t, 0.03))
			_role("elite", Vector2.ZERO, false, 2.6)
			_reset()
		"sanct_eteint":
			_role("interactif", c, false, 2.6, 0.0, "eteint")
		"sanct_ravive":
			_role("interactif", c, false, 2.6, 0.0, "ravive")
		"butin":
			_role("butin", c + Vector2(-30, -40), false, 3.0)
			_essence(c + Vector2(55, 55), 18.0)
			_seve_perdue(c + Vector2(-45, 80), 16.0)
			_text_c(Vector2(c.x - 30, c.y + 22), "greffe", 10, Art.c("texte_doux"), 80)
			_text_c(Vector2(c.x + 55, c.y + 100), "essence", 10, Art.c("texte_doux"), 80)
			_text_c(Vector2(c.x - 45, c.y + 128), "sève perdue", 10, Art.c("texte_doux"), 90)


func _at(pos: Vector2, scale_: Vector2, rot := 0.0) -> void:
	draw_set_transform(pos, rot, scale_)


func _reset() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _leaf(p: Vector2, l: float, a: float, col: Color) -> void:
	draw_colored_polygon(_leaf_pts(p, l, a), col)


## Un carré de sol mort (ou ravivé) avec un peu de texture : cailloux, fissures fines, touffes.
func _ground(r: Rect2, seed_: int, vivant := false) -> void:
	draw_rect(r, Art.c("sol_vivant") if vivant else Art.c("sol_mort"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + seed_
	var crack := Color(Art.c("decor"), 0.45)
	for i in 3:
		var q := r.position + Vector2(rng.randf_range(20, r.size.x - 20), rng.randf_range(40, r.size.y - 20))
		var line := PackedVector2Array([q])
		for j in 4:
			q += Vector2(rng.randf_range(-22, 22), rng.randf_range(-14, 14))
			q = q.clamp(r.position + Vector2(4, 4), r.end - Vector2(4, 4))
			line.append(q)
		draw_polyline(line, crack, 1.2, true)
	for i in 14:
		var q := r.position + Vector2(rng.randf_range(8, r.size.x - 8), rng.randf_range(34, r.size.y - 8))
		var s := rng.randf_range(1.5, 4.0)
		draw_colored_polygon(Art.ellipse(q, s * 1.3, s, 8), Color(Art.c("brume"), 0.35))
		draw_circle(q + Vector2(-s * 0.3, -s * 0.3), s * 0.4, Color(Art.c("brume").lightened(0.3), 0.3))
	if vivant:
		for i in 8:
			var q := r.position + Vector2(rng.randf_range(10, r.size.x - 10), rng.randf_range(40, r.size.y - 10))
			for j in 3:
				draw_line(q, q + Vector2((j - 1) * 3, -7), Art.c("decor_vivant").lightened(0.2), 1.4, true)

# --- Silhouettes d'exemple (référence pour la vague 2) ---

## Dessine un rôle centré en p. mono : silhouette noire pleine, sans détail (test de lecture).
## etat : variante d'exemple ("" repos, "lancer", "touche", "anticipation", "saignant", "eteint", "ravive").
func _role(role: String, p: Vector2, mono: bool, scale := 1.0, facing := 0.0, etat := "") -> void:
	var k := scale
	var black := Color.BLACK
	match role:
		"joueur":
			_hero(p, 15.0 * k, mono, facing, etat)
		"melee":
			_fletri(p, 18.0 * k, mono, etat)
		"tireur":
			_tireur(p, 16.0 * k, mono)
		"lourd":
			_lourd(p, 27.0 * k, mono)
		"elite":
			var r := 18.0 * k
			if not mono:
				draw_circle(p, r * 1.75, Color(Art.c("elite"), 0.07))
				draw_circle(p, r * 1.4, Color(Art.c("elite"), 0.09))
				for i in 10:
					var a: float = i * TAU / 10.0 + 0.2 + TAU / 10.0 * _u()
					draw_arc(p, r * 1.6, a, a + 0.38, 6, Color(Art.c("elite"), 0.75), Art.TRAIT_FIN, true)
			# Couronne de pointes, en volume (une moitié éclairée, une moitié dans l'ombre).
			for i in 5:
				var d := Vector2.from_angle(-PI / 2.0 + (i - 2) * 0.42)
				var len := r * (0.85 if i == 2 else 0.7)
				if mono:
					_spike(p + d * r * 0.8, d, len, black)
				else:
					_spike_vol(p + d * r * 0.8, d, len, Art.c("elite"))
			_fletri(p, r, mono, etat)
			if not mono:
				# Gemme de corruption au front
				var g := p + Vector2(r * 0.05, -r * 0.55)
				draw_colored_polygon(PackedVector2Array([g + Vector2(0, -r * 0.16), g + Vector2(r * 0.12, 0), g + Vector2(0, r * 0.16), g + Vector2(-r * 0.12, 0)]), Art.c("elite"))
				draw_circle(g, r * (0.2 + 0.06 * _w(2.0)), Color(Art.c("elite"), 0.25))
				draw_circle(g + Vector2(-r * 0.03, -r * 0.04), r * 0.04, Color.WHITE)
		"interactif":
			_sanctuaire(p, 26.0 * k, mono, etat != "eteint")
		"butin":
			_greffe(p, 12.0 * k, mono)


## Le Porte-Graine : corps rond, capuche de feuilles, cape de trois feuilles, graine-lanterne devant.
func _hero(p: Vector2, r: float, mono: bool, facing: float, etat: String) -> void:
	var d := Vector2.from_angle(facing)
	var n := d.orthogonal()
	var black := Color.BLACK
	var leaf_col := Art.c("joueur_accent").darkened(0.3)
	if not mono:
		Art.shadow(self, p, r * 1.1)
	# Cape : trois feuilles dans le dos, nervurées.
	for side in [-1, 0, 1]:
		var a: float = facing + PI + side * 0.62 + 0.09 * _w(1.0, side * 0.18)
		var c := p + Vector2.from_angle(a) * r * (1.05 if side == 0 else 0.95)
		var lf := _leaf_pts(c, r * (0.78 if side == 0 else 0.66), a)
		if mono:
			draw_colored_polygon(lf, black)
		else:
			Art.volume(self, lf, leaf_col.darkened(0.08 * absf(side)), 0.6)
			draw_line(c - Vector2.from_angle(a) * r * 0.5, c + Vector2.from_angle(a) * r * 0.55, leaf_col.darkened(0.45), maxf(r * 0.05, 1.0), true)
			Art.outline(self, lf, Art.c("contour"), maxf(r * 0.06, 1.2))
	# Corps
	if mono:
		draw_circle(p, r, black)
	else:
		Art.volume_circle(self, p, r, Art.c("joueur"))
		draw_arc(p, r, 0, TAU, 32, Art.c("contour"), maxf(r * 0.12, Art.TRAIT_FIN), true)
	# Capuche de feuillage : couvre l'arrière du crâne (un croissant), avec une pousse au sommet.
	var hood := PackedVector2Array()
	for i in 17:
		var a: float = facing + PI / 2.0 + 0.25 + i * (PI - 0.5) / 16.0
		hood.append(p + Vector2.from_angle(a) * r * 1.04)
	for i in range(16, -1, -1):
		var a: float = facing + PI / 2.0 + 0.25 + i * (PI - 0.5) / 16.0
		hood.append(p - d * r * 0.12 + Vector2.from_angle(a) * r * 0.62)
	if mono:
		draw_colored_polygon(hood, black)
	else:
		Art.volume(self, hood, Art.c("accent").darkened(0.15), 0.7)
		for i in 4:
			var a: float = facing + PI / 2.0 + 0.6 + i * 0.62
			draw_line(p + Vector2.from_angle(a) * r * 0.66, p + Vector2.from_angle(a) * r * 0.98, Art.c("accent").darkened(0.5), maxf(r * 0.045, 0.8), true)
		Art.outline(self, hood, Art.c("contour"), maxf(r * 0.06, 1.2))
		var sprout := _leaf_pts(p - d * r * 0.55 - n * r * 0.1, r * 0.32, facing + PI + 0.5)
		Art.volume(self, sprout, Art.c("accent"), 0.8)
		Art.outline(self, sprout, Art.c("contour"), maxf(r * 0.04, 1.0))
		# Visage : deux yeux et une joue claire.
		for sgn in [-1, 1]:
			draw_circle(p + d * r * 0.5 + n * sgn * r * 0.26, r * 0.1, Art.c("contour"))
			draw_circle(p + d * r * 0.5 + n * sgn * r * 0.26 + Vector2(-r * 0.03, -r * 0.03), r * 0.035, Color.WHITE)
		draw_arc(p + d * r * 0.62, r * 0.12, facing - 0.9, facing + 0.9, 8, Art.c("contour").lightened(0.2), maxf(r * 0.04, 0.8), true)
	# Graine-lanterne
	var seed_p := p + d * r * 1.4
	var big := etat == "lancer"
	if mono:
		draw_circle(seed_p, r * 0.3, black)
	else:
		Art.glow(self, seed_p, r * (1.3 if big else 0.75) * (1.0 + 0.1 * _w(2.0)), "seve")
		# Lucioles qui tournent autour de la lanterne.
		for i in 3:
			var m := seed_p + Vector2.from_angle(TAU * (_u() + i / 3.0)) * r * (0.6 + 0.08 * _w(3.0, i * 0.3))
			draw_circle(m, maxf(r * 0.05, 0.8), Color(Art.ec("seve", "clair"), 0.5 + 0.4 * _w(2.0, i * 0.33)))
		draw_colored_polygon(Art.ellipse(seed_p, r * 0.3, r * 0.22, 14), Art.ec("seve", "sombre").lightened(0.2))
		draw_circle(seed_p + Vector2(-r * 0.06, -r * 0.06), r * 0.13, Art.ec("seve", "clair"))
		if big:
			for i in 5:
				var a: float = facing + (i - 2) * 0.35
				draw_line(seed_p + Vector2.from_angle(a) * r * 0.55, seed_p + Vector2.from_angle(a) * r * 0.95, Color(Art.ec("seve"), 0.8), maxf(r * 0.06, 1.0), true)
		var fl := _flash if etat == "touche" else 0.0
		if fl > 0.0:
			draw_circle(p, r * 1.02, Color(Art.c("danger_eclair"), 0.75 * fl))
			draw_arc(p, r * (1.1 + 0.5 * (1.0 - fl)), 0, TAU, 32, Color(Art.c("danger"), 0.9 * fl), maxf(r * 0.08, 1.5), true)


## Le Flétri de mêlée : écorce anguleuse et fendue, veines de braise, yeux fendus, griffes d'os.
func _fletri(p: Vector2, r: float, mono: bool, etat := "") -> void:
	var black := Color.BLACK
	var pts := _jagged(p, r, [1.0, 0.72, 1.05, 0.8, 0.95, 0.68, 1.0, 0.85], 0.2)
	if not mono:
		Art.shadow(self, p, r)
	for sgn in [-1, 1]:
		var cl := p + Vector2(r * 0.82, sgn * r * 0.48)
		if mono:
			_spike(cl, Vector2(1, sgn * 0.4).normalized(), r * 0.55, black)
		else:
			_spike_vol(cl, Vector2(1, sgn * 0.4).normalized(), r * 0.55, Art.ec("epine", "clair").darkened(0.15))
	if mono:
		draw_colored_polygon(pts, black)
		return
	var body := Art.c("ennemi")
	if _flash > 0.0 and etat == "touche":
		body = body.lerp(Color.WHITE, 0.8 * _flash)
	Art.volume(self, pts, body)
	# Grain de l'écorce : petits traits et un nœud.
	var grain := body.darkened(0.3)
	for gq in [[Vector2(0.15, 0.3), Vector2(0.45, 0.42)], [Vector2(0.05, 0.55), Vector2(0.3, 0.62)], [Vector2(-0.5, 0.05), Vector2(-0.7, 0.12)], [Vector2(0.3, -0.62), Vector2(0.5, -0.5)]]:
		draw_line(p + gq[0] * r, p + gq[1] * r, grain, maxf(r * 0.04, 0.8), true)
	draw_arc(p + Vector2(-0.15, 0.45) * r, r * 0.09, 0, TAU, 10, grain, maxf(r * 0.04, 0.8), true)
	# Lichen mort, en taches pâles.
	for lq in [Vector2(-0.55, -0.45), Vector2(-0.62, 0.32), Vector2(0.55, 0.2)]:
		draw_circle(p + lq * r, r * 0.06, Color(Art.c("brume").lightened(0.2), 0.55))
	# Fentes de l'écorce, avec la braise qui couve dedans.
	var w := maxf(r * 0.07, 1.0)
	for crack in [[Vector2(-0.1, -0.05), Vector2(-0.45, -0.35), Vector2(-0.62, -0.28)], [Vector2(-0.1, -0.05), Vector2(-0.3, 0.35), Vector2(-0.55, 0.5)], [Vector2(-0.1, -0.05), Vector2(0.1, -0.5)]]:
		var line := PackedVector2Array()
		for q in crack:
			line.append(p + q * r)
		draw_polyline(line, body.darkened(0.6), w * 1.8, true)
		var flick := 0.8 + 0.2 * _w(3.0, line[1].x * 0.01)
		draw_polyline(line, Color(Art.ec("cendre"), (0.85 if etat == "anticipation" else 0.5) * flick), w * 0.7, true)
	Art.outline(self, pts, Art.c("ennemi_contour"), maxf(r * 0.1, Art.TRAIT_FIN))
	# Yeux
	var eye_a := (0.6 if etat == "anticipation" else 0.25) * (0.85 + 0.15 * _w(2.0))
	for sgn in [-1, 1]:
		var e := p + Vector2(r * 0.38, sgn * r * 0.27)
		draw_circle(e, r * 0.16, Color(Art.c("ennemi_oeil"), eye_a))
		_slit(e, r * 0.13, sgn)
	# Flocons de cendre
	# Flocons de cendre qui s'élèvent et s'éteignent.
	for i in 3:
		var k := _u(i / 3.0)
		var q := p + Vector2(-r * (0.3 + 0.3 * i) + sin(TAU * k + i) * r * 0.15, -r * (0.8 + 0.9 * k))
		draw_colored_polygon(PackedVector2Array([q + Vector2(0, -r * 0.07), q + Vector2(r * 0.05, 0), q + Vector2(0, r * 0.07), q + Vector2(-r * 0.05, 0)]), Color(Art.c("brume").lightened(0.3), 0.8 * sin(PI * k)))
	if etat == "saignant":
		Art.status(self, "saignement", p, r, t * 1.25)


## Le Tireur d'épines : corps effilé, piquants dans le dos, canon-épine cerclé, un œil.
func _tireur(p: Vector2, r: float, mono: bool) -> void:
	var black := Color.BLACK
	var pts := PackedVector2Array([p + Vector2(-r, -r * 0.7), p + Vector2(r * 0.5, -r * 0.55), p + Vector2(r * 0.8, 0), p + Vector2(r * 0.5, r * 0.55), p + Vector2(-r, r * 0.7), p + Vector2(-r * 0.6, 0)])
	if not mono:
		Art.shadow(self, p, r)
	for i in 3:
		var base := p + Vector2(-r * (0.55 + i * 0.12), (i - 1) * r * 0.45)
		if mono:
			_spike(base, Vector2(-1, (i - 1) * 0.5).normalized(), r * 0.6, black)
		else:
			_spike_vol(base, Vector2(-1, (i - 1) * 0.5).normalized(), r * 0.6, Art.c("ennemi_contour").darkened(0.35))
	if mono:
		draw_colored_polygon(pts, black)
		_spike(p + Vector2(r * 0.6, 0), Vector2.RIGHT, r * 1.3, black)
		return
	Art.volume(self, pts, Art.c("ennemi"))
	_spike_vol(p + Vector2(r * 0.55, 0), Vector2.RIGHT, r * 1.35, Art.ec("epine", "clair").darkened(0.15))
	for i in 2:
		var x := p.x + r * (0.75 + i * 0.28)
		draw_line(Vector2(x, p.y - r * (0.22 - i * 0.05)), Vector2(x, p.y + r * (0.22 - i * 0.05)), Art.c("ennemi").darkened(0.4), maxf(r * 0.08, 1.0), true)
	Art.outline(self, pts, Art.c("ennemi_contour"), maxf(r * 0.1, Art.TRAIT_FIN))
	draw_circle(p + Vector2(r * 0.05, 0), r * 0.32, Color(Art.c("ennemi_oeil"), 0.3 + 0.15 * _w(2.0)))
	draw_circle(p + Vector2(r * 0.05, 0), r * 0.18, Art.c("ennemi_oeil"))
	draw_circle(p + Vector2(r * 0.1, 0), r * 0.07, Art.c("contour"))
	draw_circle(p + Vector2(r * 1.95, 0), r * (0.1 + tir_charge * 0.25), Color(Art.ec("cendre"), 0.35 * tir_charge))
	draw_circle(p + Vector2(r * 1.95, 0), r * (0.1 + tir_charge * 0.08), Art.ec("cendre", "clair"))


## Le Colosse : bloc d'écorce à plaques, fentes de braise, petits yeux, trait fort.
func _lourd(p: Vector2, r: float, mono: bool) -> void:
	var pts := _jagged(p, r, [1.0, 0.9, 1.0, 0.92, 1.0, 0.9], 0.0)
	if mono:
		draw_colored_polygon(pts, Color.BLACK)
		return
	Art.shadow(self, p, r)
	var body := Art.c("ennemi").darkened(0.12)
	draw_colored_polygon(pts, body.darkened(0.45))
	# Plaques d'écorce, chacune en volume, séparées par des fentes où couve la braise.
	var plates := [
		[Vector2(-0.82, -0.3), Vector2(-0.3, -0.78), Vector2(0.35, -0.72), Vector2(0.15, -0.2), Vector2(-0.45, 0.0)],
		[Vector2(0.25, -0.62), Vector2(0.82, -0.3), Vector2(0.85, 0.3), Vector2(0.3, 0.2), Vector2(0.22, -0.12)],
		[Vector2(-0.82, 0.1), Vector2(-0.4, 0.12), Vector2(0.2, 0.32), Vector2(0.25, 0.75), Vector2(-0.45, 0.75)],
		[Vector2(0.35, 0.32), Vector2(0.82, 0.38), Vector2(0.45, 0.78), Vector2(0.32, 0.72)],
	]
	for pl in plates:
		var poly := PackedVector2Array()
		for q in pl:
			poly.append(p + q * r)
		Art.volume(self, poly, body.lightened(0.05), 0.7)
	draw_polyline(PackedVector2Array([p + Vector2(-0.5, -0.05) * r, p + Vector2(0.18, -0.16) * r, p + Vector2(0.26, 0.26) * r, p + Vector2(-0.4, 0.06) * r]), Color(Art.ec("cendre"), 0.55), maxf(r * 0.04, 1.0), true)
	Art.outline(self, pts, Art.c("ennemi_contour"), maxf(r * 0.12, Art.TRAIT_FORT))
	for sgn in [-1, 1]:
		var e := p + Vector2(r * 0.55, sgn * r * 0.14)
		draw_circle(e, r * 0.1, Color(Art.c("ennemi_oeil"), 0.3))
		_slit(e, r * 0.08, sgn)


## Un sanctuaire : cercle de pierres levées gravées, socle central et sa graine.
func _sanctuaire(p: Vector2, r: float, mono: bool, lit: bool) -> void:
	if not mono:
		draw_circle(p, r * 1.2, Color(Art.c("decor_vivant") if lit else Art.c("decor"), 0.35))
		draw_arc(p, r * 1.0, 0, TAU, 40, Color(Art.c("interactif"), 0.35 if lit else 0.15), maxf(r * 0.04, 1.0), true)
		draw_arc(p, r * 0.55, 0, TAU, 32, Color(Art.c("interactif"), 0.3 if lit else 0.12), maxf(r * 0.03, 1.0), true)
		if lit:
			draw_arc(p, r * 1.32, -PI / 2.0, -PI / 2.0 + TAU, 48, Art.c("butin"), maxf(r * 0.06, Art.TRAIT), true)
		else:
			var fill := 0.15 + 0.8 * Anim.ease_in_out(_u())
			draw_arc(p, r * 1.32, 0, TAU, 48, Color(Art.c("contour"), 0.4), maxf(r * 0.06, Art.TRAIT), true)
			draw_arc(p, r * 1.32, -PI / 2.0, -PI / 2.0 + TAU * fill, 40, Color(Art.c("butin"), 0.85), maxf(r * 0.06, Art.TRAIT), true)
			draw_circle(p + Vector2.from_angle(-PI / 2.0 + TAU * fill) * r * 1.32, maxf(r * 0.07, 2.0), Art.c("butin").lightened(0.4))
	var stone_col := Art.c("interactif") if lit else Art.c("interactif").darkened(0.35)
	for i in 6:
		var a: float = i * TAU / 6.0 + 0.3
		var q := p + Vector2.from_angle(a) * r * 0.85
		var stone := PackedVector2Array([q + Vector2(-0.17, 0.2) * r, q + Vector2(-0.15, -0.16) * r, q + Vector2(0, -0.27) * r, q + Vector2(0.15, -0.17) * r, q + Vector2(0.17, 0.2) * r])
		if mono:
			draw_colored_polygon(stone, Color.BLACK)
			continue
		Art.shadow(self, q + Vector2(0, r * 0.05), r * 0.16)
		Art.volume(self, stone, stone_col, 0.8)
		Art.outline(self, stone, Art.c("contour"), maxf(r * 0.04, 1.0))
		var pulse := 0.5 + 0.5 * sin(TAU * (_u() - i / 6.0))
		var rune := Color(Art.ec("seve").lerp(Art.ec("seve", "clair"), pulse), 0.6 + 0.4 * pulse) if lit else Color(Art.c("contour"), 0.5)
		if lit:
			draw_circle(q + Vector2(0, -0.04) * r, r * 0.16, Color(Art.ec("seve"), 0.18 * pulse))
		draw_line(q + Vector2(0, -0.14) * r, q + Vector2(0, 0.08) * r, rune, maxf(r * 0.035, 1.0), true)
		draw_line(q + Vector2(-0.07, -0.04) * r, q + Vector2(0.07, -0.1) * r, rune, maxf(r * 0.03, 1.0), true)
	if mono:
		draw_circle(p, r * 0.22, Color.BLACK)
		return
	Art.volume_circle(self, p, r * 0.24, stone_col.darkened(0.1), 0.6)
	if lit:
		Art.glow(self, p, r * 0.5 * (1.0 + 0.12 * _w(2.0)), "seve")
		# Étincelles de sève qui montent du socle.
		for i in 5:
			var k := _u(i / 5.0)
			var q := p + Vector2(sin(i * 2.3 + TAU * k) * r * 0.25, -r * 1.2 * k)
			draw_circle(q, maxf(r * 0.035, 1.0), Color(Art.ec("seve", "clair"), sin(PI * k)))
	else:
		draw_circle(p, r * 0.08, Art.ec("seve", "sombre").lerp(Art.ec("seve"), 0.5 * _u()))


## Une greffe au sol : feuille d'or nervurée, tige, éclat ; avec une essence et une sève perdue à côté.
func _greffe(p: Vector2, r: float, mono: bool) -> void:
	var bob := Vector2(0, -r * (0.35 + 0.15 * _w()))
	var lf := _leaf_pts(p + bob, r * 1.1, -PI / 4.0 + 0.06 * _w(1.0, 0.25))
	if mono:
		draw_colored_polygon(lf, Color.BLACK)
		return
	Art.shadow(self, p + Vector2(0, r * 0.3), r * 0.8)
	draw_circle(p + bob, r * 1.7, Color(Art.c("butin"), 0.08))
	draw_circle(p + bob, r * 1.25, Color(Art.c("butin"), 0.1))
	var d := Vector2.from_angle(-PI / 4.0)
	draw_line(p + bob - d * r * 1.05, p + bob - d * r * 1.55, Art.c("butin").darkened(0.5), maxf(r * 0.12, 1.2), true)
	Art.volume(self, lf, Art.c("butin"))
	draw_line(p + bob - d * r * 1.0, p + bob + d * r * 0.95, Art.c("butin").darkened(0.45), maxf(r * 0.07, 1.0), true)
	for i in 3:
		var base := p + bob + d * r * (-0.5 + i * 0.45)
		for sgn in [-1, 1]:
			draw_line(base, base + d * r * 0.3 + d.orthogonal() * sgn * r * 0.35, Art.c("butin").darkened(0.35), maxf(r * 0.05, 0.8), true)
	Art.outline(self, lf, Art.c("contour"), maxf(r * 0.08, 1.2))
	_sparkle(p + bob + Vector2(r * 0.95, -r * 0.95), r * 0.5 * (0.6 + 0.4 * absf(_w(2.0))), TAU / 8.0 * _u())


## Pointe en volume : moitié claire, moitié sombre.
func _spike_vol(base: Vector2, d: Vector2, len: float, col: Color) -> void:
	var n := d.orthogonal()
	var tip := base + d * len
	draw_colored_polygon(PackedVector2Array([base + n * len * 0.25, tip, base]), col.lightened(0.15))
	draw_colored_polygon(PackedVector2Array([base, tip, base - n * len * 0.25]), col.darkened(0.3))


## Essence de vie : gemme taillée de sève.
func _essence(p: Vector2, r: float) -> void:
	p += Vector2(0, r * 0.2 * _w(1.0, 0.4))
	Art.glow(self, p, r * 1.8, "seve")
	var top := p + Vector2(0, -r)
	var bot := p + Vector2(0, r)
	var lft := p + Vector2(-r * 0.62, 0)
	var rgt := p + Vector2(r * 0.62, 0)
	var mid := p + Vector2(-r * 0.1, -r * 0.1)
	var c := Art.ec("seve")
	mid += Vector2(r * 0.18 * _w(), 0)
	draw_colored_polygon(PackedVector2Array([top, mid, lft]), c.lightened(0.4))
	draw_colored_polygon(PackedVector2Array([top, rgt, mid]), c)
	draw_colored_polygon(PackedVector2Array([lft, mid, bot]), c.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([mid, rgt, bot]), c.darkened(0.45))
	Art.outline(self, PackedVector2Array([top, rgt, bot, lft]), Art.ec("seve", "sombre"), maxf(r * 0.08, 1.0))


## Sève perdue : grosse goutte de sève qui palpite, avec sa lueur.
func _seve_perdue(p: Vector2, r: float) -> void:
	r *= 1.0 + 0.07 * _w(2.0)
	Art.glow(self, p, r * 2.0 * (1.0 + 0.15 * _w(2.0)), "seve")
	var pts := PackedVector2Array()
	for i in 24:
		var a: float = i * TAU / 24.0
		var q := Vector2(cos(a), sin(a)) * r
		if q.y < 0:
			q.x *= 1.0 + q.y / r * 0.85
			q.y *= 1.7
		pts.append(p + q)
	Art.volume(self, pts, Art.ec("seve").darkened(0.15))
	Art.outline(self, pts, Art.ec("seve", "sombre"), maxf(r * 0.08, 1.0))
	draw_circle(p + Vector2(-r * 0.32, -r * 0.1), r * 0.14, Color.WHITE)


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
	draw_line(p + Vector2(-s, -side * s * 0.6), p + Vector2(s, side * s * 0.2), Art.c("ennemi_oeil"), clampf(s * 0.45, 1.6, 5.0), true)


## Éclat à quatre branches fines (qui tourne avec rot).
func _sparkle(p: Vector2, s: float, rot := 0.0) -> void:
	var col := Art.c("butin").lerp(Color.WHITE, 0.6)
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(p + Vector2.from_angle(rot + i * TAU / 8.0) * s * (1.0 if i % 2 == 0 else 0.18))
	draw_colored_polygon(pts, col)
	draw_circle(p, s * 0.18, Color.WHITE)


## Onde qui boucle sur la période : sin(2π (t / PERIODE × n + phase)).
func _w(n := 1.0, phase := 0.0) -> float:
	return sin(TAU * (t / PERIODE * n + phase))


## Avancement dans la boucle, de 0 à 1.
func _u(phase := 0.0) -> float:
	return fposmod(t / PERIODE + phase, 1.0)


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
