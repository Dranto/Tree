## Registre d'audit de l'interface (tests visuels). Les écrans y déclarent les rectangles de texte
## qu'ils dessinent ; le banc de tests vérifie ensuite qu'aucun texte ne sort de l'écran et
## qu'aucun libellé n'en recouvre un autre. Inactif (coût nul) hors des tests : `enabled` vaut false.
##
## Usage depuis un écran dessiné à la main :
##   UiAudit.begin("arbre")                        # au début du _draw
##   UiAudit.draw_text(self, "arbre", font, pos, "Texte", HORIZONTAL_ALIGNMENT_CENTER, 300, 16, color)
## Pour des nœuds Control (Label, Button…) : UiAudit.scan_controls("hud", racine).
extends Node

var enabled := false
var screens: Dictionary = {}


func begin(screen: String) -> void:
	if enabled:
		screens[screen] = []


## Déclare un rectangle de texte (en coordonnées de l'écran). `layer` sépare les couches qui
## peuvent légitimement se superposer (ex. « infobulle » au-dessus du reste).
## `required` : le texte doit être visible à l'écran à l'ouverture (noms de branches, en-têtes) ;
## un texte non requis qui est entièrement hors de l'écran n'est pas un défaut (nœud lointain).
## `color` : couleur du texte, pour le contrôle du contraste (alpha 0 : inconnue, pas de contrôle) ;
## `halo` : le texte a un halo sombre (contour), lisible sur tout fond.
func text(screen: String, rect: Rect2, label: String, layer := "", required := false, color := Color(0, 0, 0, 0), halo := false) -> void:
	if not enabled:
		return
	if not screens.has(screen):
		screens[screen] = []
	screens[screen].append({"rect": rect, "label": label, "layer": layer, "required": required, "color": color, "halo": halo})


## Rectangle réel d'un draw_string (selon l'alignement), transformé par `xform` si l'écran
## dessine dans un repère décalé/zoomé. Ne dessine rien.
func text_at(screen: String, font: Font, pos: Vector2, s: String, align: int, width: float, fs: int, xform := Transform2D.IDENTITY, layer := "", required := false) -> void:
	if not enabled:
		return
	var sz := font.get_string_size(s, align, width, fs)
	var x := pos.x
	if width > 0.0:
		if align == HORIZONTAL_ALIGNMENT_CENTER:
			x += (width - sz.x) / 2.0
		elif align == HORIZONTAL_ALIGNMENT_RIGHT:
			x += width - sz.x
	var r := Rect2(x, pos.y - font.get_ascent(fs), sz.x, sz.y)
	text(screen, xform * r, s, layer, required)


## draw_string + déclaration, pour les écrans dessinés à la main.
func draw_text(item: CanvasItem, screen: String, font: Font, pos: Vector2, s: String, align: int, width: float, fs: int, color: Color, xform := Transform2D.IDENTITY, layer := "", required := false) -> void:
	# Halo sombre (voir UiTheme.draw_text) : le texte reste lisible quel que soit le fond.
	item.draw_string_outline(font, pos, s, align, width, fs, 5, Color(0.055, 0.04, 0.025, 0.88 * color.a))
	item.draw_string(font, pos, s, align, width, fs, color)
	text_at(screen, font, pos, s, align, width, fs, xform, layer, required)
	# Dessiné avec son halo : lisible sur tout fond.


## Déclare tous les Label, Button et RichTextLabel visibles sous `root`.
func scan_controls(screen: String, root: Node) -> void:
	if not enabled:
		return
	for c in root.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		var s := ""
		var col := Color(0, 0, 0, 0)
		var halo := false
		if ctl is Label:
			s = (ctl as Label).text
			col = ctl.get_theme_color("font_color", "Label")
			halo = ctl.get_theme_constant("outline_size", "Label") >= 3 and ctl.get_theme_color("font_outline_color", "Label").a > 0.5
		elif ctl is Button:
			s = (ctl as Button).text
			var b := ctl as Button
			var state := "font_disabled_color" if b.disabled else ("font_focus_color" if b.has_focus() else "font_color")
			col = ctl.get_theme_color(state, ctl.get_class())
			if b.disabled:
				col = Color(0, 0, 0, 0)   # un bouton grisé est volontairement terne
		elif ctl is RichTextLabel:
			s = (ctl as RichTextLabel).get_parsed_text()
		if s != "":
			# Un texte dans une zone qui défile n'est audité que pour sa partie visible.
			var r := ctl.get_global_rect()
			var p: Node = ctl.get_parent()
			while p is Control:
				if (p as Control).clip_contents:
					r = r.intersection((p as Control).get_global_rect())
				p = p.get_parent()
			if r.size.x < 1.0 or r.size.y < 1.0:
				continue
			col.a *= _alpha(ctl)
			text(screen, r, s, "controles", false, col, halo)


## Renvoie les défauts de l'écran : liste de {"key", "msg"}. La clé est stable d'une exécution
## à l'autre (sert à la liste des défauts connus).
## `strict` : vérifie aussi les textes requis (désactivé pour une vue volontairement zoomée).
func check(screen: String, bounds: Rect2, strict := true) -> Array:
	var issues: Array = []
	var items: Array = screens.get(screen, [])
	for it in items:
		var r: Rect2 = it["rect"]
		if not bounds.grow(0.5).encloses(r):
			if r.intersects(bounds):
				if not strict and it["layer"] != "infobulle" and it["layer"] != "entete":
					continue   # vue zoomée : un libellé de nœud peut légitimement toucher le bord
				issues.append({"key": "%s|coupe|%s" % [screen, it["label"]],
					"msg": "« %s » est coupé par le bord de l'écran (%s pour un écran %s)" % [it["label"], _fmt(r), _fmt(bounds)]})
			elif strict and it["required"]:
				issues.append({"key": "%s|hors-ecran|%s" % [screen, it["label"]],
					"msg": "« %s » est entièrement hors de l'écran (%s pour un écran %s)" % [it["label"], _fmt(r), _fmt(bounds)]})
	for i in items.size():
		for j in range(i + 1, items.size()):
			var a: Dictionary = items[i]
			var b: Dictionary = items[j]
			if a["layer"] != b["layer"]:
				continue
			var inter: Rect2 = (a["rect"] as Rect2).intersection(b["rect"])
			if inter.size.x > 1.0 and inter.size.y > 1.0:
				var names := [a["label"], b["label"]]
				names.sort()
				issues.append({"key": "%s|chevauchement|%s|%s" % [screen, names[0], names[1]],
					"msg": "« %s » recouvre « %s » (%d×%d px)" % [a["label"], b["label"], inter.size.x, inter.size.y]})
	return issues


## Opacité cumulée d'un Control (modulate de lui-même et de ses parents).
func _alpha(ctl: CanvasItem) -> float:
	var a := 1.0
	var n: Node = ctl
	while n is CanvasItem:
		a *= (n as CanvasItem).modulate.a * (n as CanvasItem).self_modulate.a
		n = n.get_parent()
	return a


## Contraste des textes déclarés sur la capture `img` (même repère que les rectangles) :
## le fond est la luminance médiane du rectangle du texte (le texte en couvre moins de la
## moitié) ; un texte sans halo doit atteindre un rapport de contraste de MIN_CONTRAST
## (WCAG, 3:1 pour du texte d'interface). Renvoie des défauts {"key", "msg"}.
const MIN_CONTRAST := 3.0

## `view` : taille de la vue (repère des rectangles) ; la capture peut être plus grande ou plus
## petite (étirement « canvas_items »).
func check_contrast(screen: String, img: Image, view: Vector2) -> Array:
	var issues: Array = []
	var bounds := Rect2(Vector2.ZERO, Vector2(img.get_width(), img.get_height()))
	var k := bounds.size / view
	for it in screens.get(screen, []):
		var col: Color = it["color"]
		if col.a < 0.05 or it["halo"]:
			continue
		var lr: Rect2 = it["rect"]
		var r: Rect2 = Rect2(lr.position * k, lr.size * k).intersection(bounds)
		if r.size.x < 2.0 or r.size.y < 2.0:
			continue
		# Environ 150 points répartis sur le rectangle : assez pour la médiane, et rapide.
		var lums: Array = []
		var step := maxi(1, int(sqrt(r.size.x * r.size.y / 150.0)))
		for y in range(int(r.position.y), int(r.end.y), step):
			for x in range(int(r.position.x), int(r.end.x), step):
				lums.append(_lum(img.get_pixel(x, y)))
		if lums.is_empty():
			continue
		lums.sort()
		var bg: float = lums[lums.size() / 2]
		# Couleur réelle du texte : sa couleur fondue sur le fond selon son opacité.
		var fg := lerpf(bg, _lum(col), col.a)
		var ratio := (maxf(fg, bg) + 0.05) / (minf(fg, bg) + 0.05)
		if ratio < MIN_CONTRAST:
			issues.append({"key": "%s|contraste|%s" % [screen, it["label"]],
				"msg": "« %s » manque de contraste : %.1f:1 (minimum %.1f:1)" % [it["label"], ratio, MIN_CONTRAST]})
	return issues


static func _lum(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


func _fmt(r: Rect2) -> String:
	return "%d,%d %d×%d" % [r.position.x, r.position.y, r.size.x, r.size.y]
