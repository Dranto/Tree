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
func text(screen: String, rect: Rect2, label: String, layer := "", required := false) -> void:
	if not enabled:
		return
	if not screens.has(screen):
		screens[screen] = []
	screens[screen].append({"rect": rect, "label": label, "layer": layer, "required": required})


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
	item.draw_string(font, pos, s, align, width, fs, color)
	text_at(screen, font, pos, s, align, width, fs, xform, layer, required)


## Déclare tous les Label, Button et RichTextLabel visibles sous `root`.
func scan_controls(screen: String, root: Node) -> void:
	if not enabled:
		return
	for c in root.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		var s := ""
		if ctl is Label:
			s = (ctl as Label).text
		elif ctl is Button:
			s = (ctl as Button).text
		elif ctl is RichTextLabel:
			s = (ctl as RichTextLabel).get_parsed_text()
		if s != "":
			text(screen, ctl.get_global_rect(), s, "controles")


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


func _fmt(r: Rect2) -> String:
	return "%d,%d %d×%d" % [r.position.x, r.position.y, r.size.x, r.size.y]
