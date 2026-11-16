## Écran de l'Arbre de vie : déplacement, zoom, apprentissage et oubli des nœuds.
## Le jeu est en pause tant que l'arbre est ouvert.
##
## Le dessin est réparti en couches pour ne pas tout redessiner à chaque image :
## - le fond (ce nœud) : un aplat opaque, redessiné seulement au changement de taille ;
## - l'ambiance (_ambient) : pollen de sève qui monte doucement, en coordonnées de l'écran ;
## - la couche fixe (_world) : anneaux, liens, nœuds et icônes, dessinés en coordonnées de l'arbre.
##   Se déplacer ne fait que changer sa position ; elle n'est redessinée qu'au zoom ou quand l'arbre change ;
## - la couche animée (_anim, enfant de _world) : pulsation des nœuds disponibles et survol ;
## - la couche de vie (_life, enfant de _world) : sève, éclosions, halos qui respirent, braises, onde d'ouverture ;
## Le dessin lui-même (médaillons, fond, animations) est dans tree_art.gd, selon la charte (Art, Anim).
## - les libellés (_labels) : noms des branches et des nœuds, en taille fixe à l'écran, placés sans chevauchement ;
## - l'interface (_overlay) : en-tête et infobulle.
extends Control

## Ouverture (true) ou fermeture (false) de l'arbre.
signal toggled(open: bool)

const SkillTree = preload("res://scripts/skill_tree.gd")
const TreePanels = preload("res://scripts/tree_panels.gd")
const TreeGrafts = preload("res://scripts/tree_grafts.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const TreeArt = preload("res://scripts/tree_art.gd")

const Effects = preload("res://scripts/effects.gd")
const Content = preload("res://scripts/content.gd")

const RADIUS := {
	"root": 26.0, "small": 11.0, "notable": 18.0, "keystone": 26.0,
	"skill": 23.0, "mutation": 20.0, "mastery": 19.0, "graft": 17.0, "withered": 18.0,
}
const KIND_LABEL := {
	"root": "Origine", "small": "Nœud", "notable": "Nœud notable", "keystone": "Nœud clé",
	"skill": "Compétence", "mutation": "Mutation", "mastery": "Maîtrise", "graft": "Emplacement de greffe", "withered": "Nœud flétri",
}
## Couleurs de la cendre qui couvre un nœud flétri tant qu'il n'est pas libéré.
const ASH := Color(0.56, 0.55, 0.52)
const ASH_DARK := Color(0.17, 0.17, 0.165)
const LOCK_COLOR := Color("e0675e")

const BG := Color(0.03, 0.045, 0.04)
const HEADER_H := 64.0
## Hauteur de la barre d'outils sous l'en-tête (recherche, plan, résumé : tree_panels.gd),
## que l'arbre cadré et ses libellés ne doivent pas recouvrir.
const TOOLBAR_H := 46.0
## Marge entre le bord de l'écran (ou l'en-tête) et tout ce qui est dessiné.
const MARGIN := 14.0
const ZOOM_MAX := 2.5
## Le zoom minimal laisse un peu de marge autour de la vue d'ensemble.
const ZOOM_MIN_FACTOR := 0.85

## Niveaux de détail selon le zoom.
## Vue d'ensemble (zoom < LOD_ALL) : branches, nœuds clés, notables, et seulement les petits nœuds appris ou disponibles.
## Zoom moyen : tous les nœuds. Zoom proche (zoom >= LOD_CLOSE) : icônes et noms des notables.
const LOD_OVERVIEW := 0
const LOD_MEDIUM := 1
const LOD_CLOSE := 2
const LOD_ALL := 0.32
const LOD_NEAR := 0.8

## Taille minimale à l'écran (en pixels) des nœuds importants, pour qu'ils restent visibles dézoomés.
const MIN_SCREEN_RADIUS := {
	"root": 9.0, "keystone": 8.0, "notable": 5.0, "small": 0.0,
	"skill": 7.0, "mutation": 6.0, "mastery": 6.0, "graft": 5.0, "withered": 5.0,
}

## Taille des textes (pixels à l'écran, quel que soit le zoom).
const FONT_BRANCH := 30
const FONT_KEYSTONE := 15
const FONT_NOTABLE := 13
const FONT_ROOT := 15
const TOOLTIP_MAX_W := 380.0

var cam := Vector2.ZERO:
	set(v):
		cam = v.limit_length(_extent()) if Game.tree != null else v
		_view_changed(false)
var zoom := 0.55:
	set(v):
		zoom = clampf(v, min_zoom if min_zoom > 0.0 else 0.05, ZOOM_MAX)
		_view_changed(true)
var hover := -1:
	set(v):
		if v == hover:
			return
		hover = v
		_hover_since = 0.0
		if is_node_ready():
			_anim.queue_redraw()
			_overlay.queue_redraw()
var mouse := Vector2.ZERO:
	set(v):
		mouse = v
		if is_node_ready() and hover >= 0:
			_overlay.queue_redraw()
var min_zoom := 0.0
var dragging := false
var drag_moved := 0.0
var font: Font
var t := 0.0
## Outils de planification (recherche, chemins, plan, résumé) : voir tree_panels.gd.
var panels
## Inventaire des greffes (tree_grafts.gd), en bas à gauche.
var grafts_panel

## Rectangles (à l'écran) des textes dessinés par la couche des libellés, pour les contrôles automatiques.
var label_rects: Array[Rect2] = []

## Faux pour sauter l'onde d'ouverture (bancs de captures qui photographient l'arbre juste après l'ouverture).
var play_intro := true
var _ambient: Control
var _world: Node2D
var _anim: Node2D
var _life: Node2D
var _labels: Control
var _overlay: Control
var _states := {}
var _available: Array = []
## Icône de chaque nœud (TreeArt.icon_of), calculée une fois.
var _icons := {}
## Temps écoulé depuis l'ouverture de l'arbre (onde de sève) et depuis le dernier changement de survol.
var _intro := INF
var _hover_since := INF
## Cernes de croissance du fond, calculés une fois.
var _rings: Array = []
## Nœuds appris et nœuds flétris couverts de cendre : ceux que la couche de vie anime.
var _owned_ids: Array = []
var _ashen_ids: Array = []
var _extent_cache := -1.0
## true tant que le joueur n'a ni zoomé ni bougé : la vue se recadre si la fenêtre change de taille.
var _fitted := false
var _opened_once := false
var _lod := -1
var _can_buy := false
## Nœuds appris dont le choix (maîtrise, mutation) reste à faire : ils pulsent.
var _pending: Array = []
## Raison du verrou des nœuds à règle (flétri, mutation sans compétence, incompatible).
var _locks := {}
## Fenêtre de choix d'une maîtrise ou d'une mutation (nœuds Control), et nœuds qui attendent la leur.
var _choice: Control = null
var _choice_id := -1
var _choice_queue: Array = []
## Liens courbes : points de chaque lien (CURVE_SEGS + 1 points), calculés une fois par arbre.
const CURVE_SEGS := 8
## Courbure d'un lien, en part de sa longueur.
const CURVE_BEND := 0.15
var _curves: Array = []
var _curve_tree = null
## Liens appris, avec le sens de la sève (de l'origine vers l'extérieur) : [indice du lien, inversé, phase].
var _sap: Array = []
## Nœuds en train d'éclore : identifiant → temps écoulé.
var _blooms := {}
const BLOOM_DUR := 0.95


class Layer extends Node2D:
	var ui
	var kind := "world"
	func _draw() -> void:
		match kind:
			"world":
				ui._draw_world(self)
			"anim":
				ui._draw_anim(self)
			_:
				ui._draw_life(self)


class Overlay extends Control:
	var ui
	var kind := ""
	func _draw() -> void:
		if kind == "labels":
			ui._draw_labels(self)
		elif kind == "ambient":
			ui._draw_ambient(self)
		else:
			ui._draw_overlay(self)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	focus_mode = Control.FOCUS_NONE
	font = ThemeDB.fallback_font
	_rings = TreeArt.growth_rings(SkillTree.RINGS, SkillTree.RING_GAP)
	_ambient = _make_overlay("ambient")
	_world = Layer.new()
	_world.ui = self
	add_child(_world)
	_anim = Layer.new()
	_anim.ui = self
	_anim.kind = "anim"
	_world.add_child(_anim)
	# La sève et l'éclosion ont leur propre couche : elles bougent à chaque image, le reste de l'animation non.
	_life = Layer.new()
	_life.ui = self
	_life.kind = "life"
	_world.add_child(_life)
	_labels = _make_overlay("labels")
	_overlay = _make_overlay("overlay")
	# Les outils passent au-dessus des couches dessinées, pour recevoir les clics de leurs boutons.
	panels = TreePanels.new()
	panels.ui = self
	add_child(panels)
	grafts_panel = TreeGrafts.new()
	grafts_panel.ui = self
	add_child(grafts_panel)
	Game.tree_changed.connect(_on_tree_changed)
	Game.node_allocated.connect(_on_node_allocated)
	resized.connect(_on_resized)


func _make_overlay(kind: String) -> Control:
	var c := Overlay.new()
	c.ui = self
	c.kind = kind
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func _input(event: InputEvent) -> void:
	if _choice != null:
		# Tab ou Échap ferment la fenêtre de choix (le choix reste à faire), pas l'arbre.
		if event.is_action_pressed("toggle_tree") or event.is_action_pressed("ui_cancel"):
			_choice_queue.clear()
			close_choice(false)
			get_viewport().set_input_as_handled()
		return
	if panels.captures_keys():
		return
	if event.is_action_pressed("toggle_tree"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_choice_queue.clear()
	close_choice(false)
	visible = not visible
	get_tree().paused = visible
	dragging = false
	if visible:
		_refresh_states()
		min_zoom = fit_zoom() * ZOOM_MIN_FACTOR
		# Première ouverture : l'arbre entier tient à l'écran. Ensuite, la vue reste où le joueur l'a laissée.
		if not _opened_once:
			_opened_once = true
			fit_view()
		else:
			zoom = zoom
		_intro = 0.0 if play_intro and not Settings.reduce_effects else INF
		_world.modulate.a = 1.0
		_redraw_all()
	toggled.emit(visible)


## Cadre la vue pour que l'arbre entier et les noms des branches tiennent à l'écran.
func fit_view() -> void:
	min_zoom = fit_zoom() * ZOOM_MIN_FACTOR
	zoom = fit_zoom()
	cam = Vector2.ZERO
	_fitted = true


func _on_resized() -> void:
	if not visible or size.x <= 0.0:
		return
	min_zoom = fit_zoom() * ZOOM_MIN_FACTOR
	if _fitted:
		fit_view()
	else:
		zoom = zoom
	_redraw_all()


func _on_tree_changed() -> void:
	_refresh_states()
	_redraw_all()


## Un nœud vient d'être appris : il éclôt (petite animation), si l'arbre est à l'écran.
func _redraw_all() -> void:
	if not is_node_ready():
		return
	queue_redraw()
	_ambient.queue_redraw()
	_world.queue_redraw()
	_anim.queue_redraw()
	_life.queue_redraw()
	_labels.queue_redraw()
	_overlay.queue_redraw()


func _view_changed(zoom_changed: bool) -> void:
	if not is_node_ready():
		return
	_world.position = size / 2.0 - cam * zoom
	_world.scale = Vector2(zoom, zoom)
	# La couche fixe ne se redessine pas quand on se déplace, seulement quand le zoom change
	# (épaisseurs à l'écran, taille minimale des nœuds, niveau de détail).
	if zoom_changed:
		_lod = lod()
		_world.queue_redraw()
		_anim.queue_redraw()
		_life.queue_redraw()
	_labels.queue_redraw()
	_overlay.queue_redraw()


func _process(delta: float) -> void:
	# Les couches fixes ne bougent pas ; l'ambiance, la couche animée et la couche de vie
	# (petites, et limitées à ce qui est à l'écran) sont redessinées à chaque image.
	if not visible:
		return
	t += delta
	_hover_since += delta
	for id in _blooms.keys():
		_blooms[id] += delta
		if _blooms[id] >= BLOOM_DUR:
			_blooms.erase(id)
	if _intro < TreeArt.INTRO_DUR:
		_intro += delta
		# L'arbre se dévoile derrière l'onde de sève.
		_world.modulate.a = lerpf(0.35, 1.0, Anim.ease_out(minf(_intro / (TreeArt.INTRO_DUR * 0.6), 1.0)))
	if not Settings.reduce_effects:
		_ambient.queue_redraw()
	_anim.queue_redraw()
	_life.queue_redraw()


# --- Géométrie ---

func lod() -> int:
	if zoom < LOD_ALL:
		return LOD_OVERVIEW
	if zoom >= LOD_NEAR:
		return LOD_CLOSE
	return LOD_MEDIUM


func to_tree(p: Vector2) -> Vector2:
	return (p - size / 2.0) / zoom + cam


func to_screen(p: Vector2) -> Vector2:
	return (p - cam) * zoom + size / 2.0


## Rayon de l'arbre (centre au bord du nœud le plus éloigné), en coordonnées de l'arbre.
func _extent() -> float:
	if _extent_cache < 0.0:
		_extent_cache = 0.0
		for n in Game.tree.nodes:
			_extent_cache = maxf(_extent_cache, n["pos"].length() + RADIUS[n["type"]])
	return _extent_cache


## Zone de l'écran où l'arbre et les libellés peuvent être dessinés (sous l'en-tête, avec une marge).
func _view_area() -> Rect2:
	var top := HEADER_H + TOOLBAR_H
	return Rect2(MARGIN, top + MARGIN, size.x - 2.0 * MARGIN, size.y - top - 2.0 * MARGIN)


## Rayon d'un nœud tel que dessiné : les nœuds importants gardent une taille minimale à l'écran.
func _radius(n: Dictionary, z: float) -> float:
	return maxf(RADIUS[n["type"]], MIN_SCREEN_RADIUS[n["type"]] / z)


## Un nœud est-il dessiné à ce niveau de détail ? En vue d'ensemble, les petits nœuds verrouillés sont cachés.
func _shown(n: Dictionary, level: int) -> bool:
	return level != LOD_OVERVIEW or n["type"] != "small" or _states.get(n["id"], "locked") != "locked"


## Rectangle à l'écran du nom d'une branche, posé juste à l'extérieur de l'arbre dans sa direction.
func _branch_label_rect(bi: int, z: float, c: Vector2) -> Rect2:
	var sector := TAU / SkillTree.BRANCHES.size()
	var d := Vector2.from_angle((bi + 0.5) * sector - PI / 2.0)
	var anchor := (d * _extent() - c) * z + size / 2.0 + d * 12.0
	var s := _text_size(SkillTree.BRANCHES[bi]["name"], FONT_BRANCH)
	return Rect2(anchor - Vector2(s.x * (1.0 - d.x) / 2.0, s.y * (1.0 - d.y) / 2.0), s)


func _text_size(text: String, fs: int) -> Vector2:
	return Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, font.get_height(fs))


## Plus grand zoom pour lequel l'arbre entier et les six noms de branches tiennent dans l'écran.
func fit_zoom() -> float:
	if size.x <= 0.0 or size.y <= 0.0:
		return 0.3
	var area := _view_area()
	var z := ZOOM_MAX
	while z > 0.02:
		var rr := _extent() * z
		var c := size / 2.0
		var ok := c.x - rr >= area.position.x and c.x + rr <= area.end.x and c.y - rr >= area.position.y and c.y + rr <= area.end.y
		if ok:
			for bi in SkillTree.BRANCHES.size():
				if not area.encloses(_branch_label_rect(bi, z, Vector2.ZERO)):
					ok = false
					break
		if ok:
			return z
		z *= 0.98
	return z


func pick(p: Vector2) -> int:
	var tp := to_tree(p)
	var level := lod()
	var best := -1
	var bd := INF
	for n in Game.tree.nodes:
		if not _shown(n, level):
			continue
		var r: float = _radius(n, zoom) + 4.0 / zoom
		var d := tp.distance_squared_to(n["pos"])
		if d < r * r and d < bd:
			bd = d
			best = n["id"]
	return best


func zoom_at(p: Vector2, factor: float) -> void:
	var before := to_tree(p)
	zoom = zoom * factor
	cam = before - (p - size / 2.0) / zoom
	_fitted = false


# --- Entrées ---

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(mb.position, 1.15)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(mb.position, 1.0 / 1.15)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				dragging = true
				drag_moved = 0.0
			else:
				dragging = false
				if drag_moved < 6.0:
					var id := pick(mb.position)
					if id >= 0:
						click(id)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			var id := pick(mb.position)
			if id >= 0:
				panels.right_click(id)
		hover = pick(mb.position)
		return
	var mm := event as InputEventMouseMotion
	if mm:
		mouse = mm.position
		if dragging:
			drag_moved += mm.relative.length()
			if mm.relative != Vector2.ZERO:
				cam -= mm.relative / zoom
				_fitted = false
		hover = pick(mouse)


## Glisser-déposer d'une greffe de l'inventaire : le nœud survolé montre l'aperçu de la greffe.
func _can_drop_data(at: Vector2, data) -> bool:
	if not (data is Dictionary and data.has("graft")):
		return false
	mouse = at
	hover = pick(at)
	return true


func _drop_data(at: Vector2, data) -> void:
	grafts_panel.drop_on(pick(at), str(data["graft"]))


# --- États ---

func _state(id: int) -> String:
	if Game.allocated.has(id):
		return "owned"
	if Game.lock_reason(id) != "":
		return "locked"
	for m in Game.tree.nodes[id]["neighbors"]:
		if Game.allocated.has(m):
			return "available"
	return "locked"


func _refresh_states() -> void:
	_states = {}
	_available = []
	_pending = []
	_locks = {}
	_owned_ids = []
	_ashen_ids = []
	for n in Game.tree.nodes:
		var id: int = n["id"]
		var st := _state(id)
		_states[id] = st
		if st == "owned" and n["type"] != "root":
			_owned_ids.append(id)
		if _ashen(n):
			_ashen_ids.append(id)
		if st == "available":
			_available.append(id)
		elif st == "owned":
			if Game.needs_choice(id):
				_pending.append(id)
		else:
			var why: String = Game.lock_reason(id)
			if why != "":
				_locks[id] = why
	_can_buy = Game.points > 0
	_ensure_curves()
	_sap = []
	var edges: Array = Game.tree.edges
	for i in edges.size():
		var e: Vector2i = edges[i]
		if _states[e.x] == "owned" and _states[e.y] == "owned":
			var na: Dictionary = Game.tree.nodes[e.x]
			var nb: Dictionary = Game.tree.nodes[e.y]
			_sap.append([i, na["pos"].length_squared() > nb["pos"].length_squared(), fposmod(float(i) * 0.6180339, 1.0)])


## Vrai si le nœud est un nœud flétri encore couvert de cendre.
func _ashen(n: Dictionary) -> bool:
	return n["type"] == "withered" and not Game.flags.get(n["requires_flag"], false)


# --- Clics et fenêtre de choix ---

## Clic sur un nœud : apprendre (par les outils de l'arbre), ou ouvrir le choix d'un nœud appris.
func click(id: int) -> void:
	var n: Dictionary = Game.tree.nodes[id]
	if Game.allocated.has(id):
		if not n["choices"].is_empty():
			if n["type"] == "mutation" and Game.choice_index(id) >= 0:
				panels.say("Une mutation est définitive : oublie ce nœud (clic droit) pour en choisir une autre.")
			else:
				open_choice(id)
		elif n["type"] == "graft":
			grafts_panel.click_slot(id)
		return
	# Une greffe tenue se pose aussi dans un emplacement pas encore appris.
	if n["type"] == "graft" and grafts_panel.held != "":
		grafts_panel.click_slot(id)
		return
	if not panels.plan_mode:
		# Un nœud à règle (flétri, mutation sans sa compétence, incompatible) dit pourquoi il résiste.
		var set: Dictionary = Game.allocated.duplicate()
		for step in panels.planner.path_to(id):
			var why: String = Game.lock_reason(step, set)
			if why != "":
				panels.say(why if step == id else "Ce chemin passe par « %s ». %s" % [Game.tree.nodes[step]["name"], why])
				return
			set[step] = true
	panels.click(id)


func _on_node_allocated(node: Dictionary) -> void:
	if visible:
		_blooms[node["id"]] = 0.0
	if visible and not node["choices"].is_empty() and Game.choice_index(node["id"]) < 0:
		_choice_queue.append(node["id"])
		_next_choice.call_deferred()


func _next_choice() -> void:
	while _choice == null and not _choice_queue.is_empty():
		var id: int = _choice_queue.pop_front()
		if visible and Game.needs_choice(id):
			open_choice(id)


## Ouvre la fenêtre de choix d'une maîtrise ou d'une mutation apprise.
func open_choice(id: int) -> void:
	close_choice(false)
	var n: Dictionary = Game.tree.nodes[id]
	if n["choices"].is_empty() or not Game.allocated.has(id):
		return
	_choice_id = id
	hover = -1
	var current: int = Game.choice_index(id)
	_choice = Control.new()
	_choice.theme = UiTheme.make()
	_choice.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_choice)
	_choice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = n["name"]
	title.add_theme_font_override("font", UiTheme.font(true))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Game.tree.branch_color(n["branch"]))
	box.add_child(title)
	var sub := Label.new()
	if n["type"] == "mutation":
		sub.text = "Choisis comment « %s » se transforme. Le choix tient tant que ce nœud reste appris." % Content.skills().get(n["mutates"], {}).get("name", n["mutates"])
	else:
		sub.text = "Choisis un bonus. Tu pourras en changer quand tu veux, sans rien dépenser."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(560, 0)
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.7, 0.78, 0.72))
	box.add_child(sub)
	var first: Button = null
	for i in n["choices"].size():
		var ch: Dictionary = n["choices"][i]
		var b := Button.new()
		var lines := PackedStringArray([str(ch.get("name", "")) + ("   (choix actuel)" if i == current else "")])
		for e in ch.get("effects", []):
			var line := Effects.describe(e)
			if line != "":
				lines.append(line)
		b.text = "\n".join(lines)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(560, 0)
		b.add_theme_font_size_override("font_size", 17)
		if i == current:
			b.add_theme_color_override("font_color", UiTheme.GOLD)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_pick_choice.bind(i))
		box.add_child(b)
		if first == null or i == current:
			first = b
	var later := Button.new()
	later.text = "Fermer" if current >= 0 else "Plus tard"
	later.add_theme_font_size_override("font_size", 15)
	later.size_flags_horizontal = Control.SIZE_SHRINK_END
	later.pressed.connect(func():
		_choice_queue.clear()
		close_choice(false))
	box.add_child(later)
	if first != null:
		first.grab_focus.call_deferred()
	panel.resized.connect(_overlay.queue_redraw)
	_overlay.queue_redraw()


func choice_open() -> bool:
	return _choice != null


func _pick_choice(index: int) -> void:
	var id := _choice_id
	var name_of: String = Game.tree.nodes[id]["choices"][index].get("name", "")
	if Game.set_choice(id, index):
		panels.say("%s : %s" % [Game.tree.nodes[id]["name"], name_of])
		var scene := get_tree().current_scene if is_inside_tree() else null
		if scene != null and scene.has_method("request_autosave"):
			scene.request_autosave()
	close_choice()


func close_choice(next := true) -> void:
	if _choice != null:
		_choice.queue_free()
		_choice = null
		_choice_id = -1
		if is_node_ready():
			_overlay.queue_redraw()
	if next:
		_next_choice()


## Icône d'un nœud (la même que partout ailleurs : Art.icon), calculée une fois par arbre.
func icon_of(n: Dictionary) -> String:
	if not _icons.has(n["id"]):
		_icons[n["id"]] = TreeArt.icon_of(n)
	return _icons[n["id"]]


# --- Couche fixe ---

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)


## Pollen de sève (couche d'ambiance, en coordonnées de l'écran).
func _draw_ambient(c: CanvasItem) -> void:
	if not Settings.reduce_effects:
		TreeArt.motes(c, size, t)


## Calcule la courbe de chaque lien : une courbe de Bézier dont le milieu est écarté de côté,
## du côté (stable) que choisit l'identifiant du lien, pour que l'arbre ait l'air de branches.
func _ensure_curves() -> void:
	var tree = Game.tree
	if _curve_tree == tree and _curves.size() == tree.edges.size():
		return
	_curve_tree = tree
	_curves = []
	_icons = {}
	for e in tree.edges:
		var a: Vector2 = tree.nodes[e.x]["pos"]
		var b: Vector2 = tree.nodes[e.y]["pos"]
		var d := b - a
		var side := 1.0 if ((e.x * 73856093) ^ (e.y * 19349663)) & 8 != 0 else -1.0
		var ctrl := (a + b) * 0.5 + d.orthogonal() * CURVE_BEND * side
		var pts := PackedVector2Array()
		for i in CURVE_SEGS + 1:
			var k := float(i) / CURVE_SEGS
			pts.append(a.lerp(ctrl, k).lerp(ctrl.lerp(b, k), k))
		_curves.append(pts)


## Ajoute à `out` les segments d'un lien, deux points par segment, avec un point sur `step`.
func _curve_segments(out: PackedVector2Array, idx: int, step: int) -> void:
	var pts: PackedVector2Array = _curves[idx]
	var i := 0
	while i < CURVE_SEGS:
		out.append(pts[i])
		out.append(pts[mini(i + step, CURVE_SEGS)])
		i += step


## Point d'un lien à la position k (0 à 1), du côté `reversed` ou non.
func _curve_at(idx: int, k: float, reversed: bool) -> Vector2:
	var pts: PackedVector2Array = _curves[idx]
	if reversed:
		k = 1.0 - k
	var f := clampf(k, 0.0, 1.0) * CURVE_SEGS
	var i := mini(int(f), CURVE_SEGS - 1)
	return pts[i].lerp(pts[i + 1], f - i)


func _draw_world(c: CanvasItem) -> void:
	var tree = Game.tree
	var z := zoom
	var level := lod()
	var colors: Array = []
	for bi in SkillTree.BRANCHES.size():
		colors.append(tree.branch_color(bi))
	TreeArt.background(c, _extent(), colors, _rings, z)

	# Liens courbes : épaisseur minimale d'un pixel à l'écran pour rester visibles dézoomés.
	# Moins de segments par lien quand on est loin (la courbure n'y est pas visible).
	_ensure_curves()
	var step := 4 if level != LOD_CLOSE else 2
	var dim := PackedVector2Array()
	# Liens qui partent d'un nœud appris : teintés de leur branche (un lot par branche).
	var half := {}
	var owned_w := maxf(6.0, 2.5 / z)
	var edges: Array = tree.edges
	for i in edges.size():
		var e: Vector2i = edges[i]
		var oa: bool = _states[e.x] == "owned"
		var ob: bool = _states[e.y] == "owned"
		if oa and ob:
			continue
		if oa or ob:
			var bi := _edge_branch(e)
			if not half.has(bi):
				half[bi] = PackedVector2Array()
			_curve_segments(half[bi], i, step)
		else:
			_curve_segments(dim, i, step)
	if dim.size() > 0:
		c.draw_multiline(dim, Color(Art.c("brume").lightened(0.15), 0.3 if level == LOD_OVERVIEW else 0.26), maxf(2.0, 1.0 / z))
	for bi in half:
		var hc: Color = tree.branch_color(bi).lerp(Art.c("texte"), 0.35)
		c.draw_multiline(half[bi], Color(hc, 0.55), maxf(3.0, 1.5 / z))
	# Branches apprises : écorce sombre dessous, cœur coloré, filet de lumière dessus, feuilles de près.
	for entry in _sap:
		var i: int = entry[0]
		var col: Color = tree.branch_color(_edge_branch(edges[i]))
		var line := PackedVector2Array()
		var pts: PackedVector2Array = _curves[i]
		for j in range(0, CURVE_SEGS + 1, step):
			line.append(pts[j])
		c.draw_polyline(line, Color(Art.c("contour"), 0.85), owned_w * 1.8)
		c.draw_polyline(line, col.darkened(0.25), owned_w * 1.15)
		c.draw_polyline(line, col, owned_w * 0.75)
		c.draw_polyline(line, Color(1, 1, 1, 0.28), owned_w * 0.22)
		if level == LOD_CLOSE:
			TreeArt.link_leaves(c, pts, col, owned_w * 0.9, i)

	var w := 1.0 / z
	# Ombres, volume, anneaux intérieurs et reflets seulement de près : le zoom reste fluide.
	var detail := level == LOD_CLOSE
	for n in tree.nodes:
		if not _shown(n, level):
			continue
		var st: String = _states[n["id"]]
		var p: Vector2 = n["pos"]
		var r := _radius(n, z)
		var col: Color = tree.branch_color(n["branch"])
		var kind: String = n["type"]
		if kind == "small":
			TreeArt.pearl(c, p, r, st, col, w, detail)
			continue
		if kind == "root":
			TreeArt.seed_node(c, p, r, col, w, detail)
			continue
		var ashen := _ashen(n)
		var shape := shape_points(kind, p, r)
		var ring_w := maxf(2.0, 1.2 * w) + w
		if ashen:
			# Cendre : médaillon gris, quel que soit l'état.
			TreeArt.medallion(c, shape, p, r, "locked", Art.c("brume").lightened(0.25), w, detail, ring_w)
		elif kind == "graft" and st == "owned":
			# Un emplacement reste creux : c'est la greffe qui le remplit.
			TreeArt.medallion(c, shape, p, r, "available", col, w, detail, ring_w)
		else:
			TreeArt.medallion(c, shape, p, r, st, col, w, detail, ring_w)
		if kind == "keystone" and detail:
			# Nœud clé : une seconde couronne autour du losange.
			var crown := shape_points(kind, p, r * 1.28)
			crown.append(crown[0])
			c.draw_polyline(crown, Color(col, 0.55 if st != "locked" else 0.22), maxf(1.5, w))
		var ic := Color(0.06, 0.08, 0.07, 0.9) if st == "owned" else Color(col.r, col.g, col.b, 0.9 if st == "available" else 0.55)
		match kind:
			"notable", "keystone", "skill":
				if level == LOD_CLOSE:
					TreeArt.node_icon(c, icon_of(n), p, r * (0.66 if kind == "notable" else 0.6), st, col)
				elif kind == "notable":
					c.draw_circle(p, r * 0.36, col.lerp(Color.WHITE, 0.6) if st == "owned" else Color(col, 0.45))
			"mutation":
				if level != LOD_OVERVIEW:
					_draw_fork(c, p + Vector2(0, r * 0.12), r * 0.42, ic, maxf(r * 0.11, 1.2 * w))
			"mastery":
				if level != LOD_OVERVIEW:
					_draw_mastery_dots(c, n, p, r, st, ic, w)
			"graft":
				_draw_graft(c, n, p, r, st, col, w, level)
			"withered":
				if ashen:
					_draw_ash(c, n, p, r, w)
				elif level == LOD_CLOSE:
					TreeArt.node_icon(c, icon_of(n), p, r * 0.66, st, col)
				else:
					c.draw_circle(p, r * 0.36, col.lerp(Color.WHITE, 0.6) if st == "owned" else Color(col, 0.45))


## Branche d'un lien : celle de son nœud extérieur (l'origine n'a pas de branche).
func _edge_branch(e: Vector2i) -> int:
	var b: int = Game.tree.nodes[e.y]["branch"]
	return b if b >= 0 else Game.tree.nodes[e.x]["branch"]


## Contour d'un nœud selon son type (vide = cercle) : losange pour un nœud clé, hexagone pour une
## compétence, triangle pour une mutation, carré pour une maîtrise.
func shape_points(kind: String, p: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match kind:
		"keystone":
			pts = PackedVector2Array([p + Vector2(0, -r * 1.15), p + Vector2(r, 0), p + Vector2(0, r * 1.15), p + Vector2(-r, 0)])
		"skill":
			for i in 6:
				pts.append(p + Vector2.from_angle(i * TAU / 6.0 - PI / 2.0) * r * 1.08)
		"mutation":
			for i in 3:
				pts.append(p + Vector2(0, r * 0.12) + Vector2.from_angle(i * TAU / 3.0 - PI / 2.0) * r * 1.3)
		"mastery":
			var h := r * 0.9
			pts = PackedVector2Array([p + Vector2(-h, -h), p + Vector2(h, -h), p + Vector2(h, h), p + Vector2(-h, h)])
	return pts


## Mutation : un rameau qui se divise en deux.
func _draw_fork(c: CanvasItem, p: Vector2, s: float, col: Color, lw: float) -> void:
	c.draw_line(p + Vector2(0, s), p, col, lw)
	c.draw_line(p, p + Vector2(-s * 0.8, -s * 0.9), col, lw)
	c.draw_line(p, p + Vector2(s * 0.8, -s * 0.9), col, lw)


## Maîtrise : un point par choix, celui qui est choisi est plein.
func _draw_mastery_dots(c: CanvasItem, n: Dictionary, p: Vector2, r: float, st: String, col: Color, w: float) -> void:
	var count: int = n["choices"].size()
	var chosen: int = Game.choice_index(n["id"]) if st == "owned" else -1
	var gap := r * 0.52
	for i in count:
		var q := p + Vector2((i - (count - 1) / 2.0) * gap, 0)
		if i == chosen:
			c.draw_circle(q, r * 0.2, col)
		else:
			c.draw_arc(q, r * 0.15, 0.0, TAU, 12, col, maxf(r * 0.07, w))


## Emplacement de greffe : un anneau creux marqué d'une croix, ou une feuille dorée quand une greffe est posée.
func _draw_graft(c: CanvasItem, n: Dictionary, p: Vector2, r: float, st: String, col: Color, w: float, level: int) -> void:
	var a := 0.9 if st == "owned" else (0.75 if st == "available" else 0.4)
	c.draw_arc(p, r * 0.68, 0.0, TAU, 24, Color(col.r, col.g, col.b, a * 0.6), maxf(r * 0.08, w))
	var gid := Game.graft_of(n["id"])
	if gid != "":
		# La greffe posée, avec sa forme et sa couleur (les mêmes qu'au sol et dans l'inventaire).
		var g: Dictionary = Content.grafts().get(gid, {})
		c.draw_circle(p, r * 0.56, Color(0.23, 0.16, 0.1, a))
		TreeGrafts.GraftPickup.draw_shape(c, str(g.get("shape", "feuille")), p, r * 0.42, Color(Color(str(g.get("color", "#f2d06b"))), a))
	elif level != LOD_OVERVIEW:
		var s := r * 0.32
		var lw := maxf(r * 0.12, 1.2 * w)
		c.draw_line(p + Vector2(-s, 0), p + Vector2(s, 0), Color(col.r, col.g, col.b, a), lw)
		c.draw_line(p + Vector2(0, -s), p + Vector2(0, s), Color(col.r, col.g, col.b, a), lw)


## Nœud flétri : fissures et flocons de cendre, toujours aux mêmes endroits pour un nœud donné.
func _draw_ash(c: CanvasItem, n: Dictionary, p: Vector2, r: float, w: float) -> void:
	var lw := maxf(r * 0.09, w)
	var crack := Color(ASH, 0.85)
	c.draw_polyline(PackedVector2Array([p + Vector2(-r * 0.15, -r * 0.8), p + Vector2(r * 0.1, -r * 0.3), p + Vector2(-r * 0.2, r * 0.1), p + Vector2(r * 0.05, r * 0.75)]), crack, lw)
	c.draw_line(p + Vector2(r * 0.1, -r * 0.3), p + Vector2(r * 0.6, -r * 0.1), crack, lw)
	c.draw_line(p + Vector2(-r * 0.2, r * 0.1), p + Vector2(-r * 0.65, r * 0.35), crack, lw)
	var h: int = absi(hash(n["uid"]))
	for i in 7:
		var a := (h % 1000) / 1000.0 * TAU + i * 0.9
		var d := r * (1.25 + 0.35 * ((h >> (i * 3)) & 7) / 7.0)
		c.draw_circle(p + Vector2.from_angle(a) * d, r * (0.07 + 0.05 * ((h >> (i * 2)) & 3) / 3.0), Color(ASH, 0.55))


# --- Couche animée ---

func _draw_anim(c: CanvasItem) -> void:
	var tree = Game.tree
	var w := 1.0 / zoom
	var view := _tree_view(40.0 / zoom)
	if _can_buy:
		var level := lod()
		for id in _available:
			var n: Dictionary = tree.nodes[id]
			if not _shown(n, level) or not view.has_point(n["pos"]):
				continue
			var r := _radius(n, zoom) * (1.3 if n["type"] == "mutation" else 1.0)
			TreeArt.invite(c, n["pos"], r, tree.branch_color(n["branch"]), t, w, id * 0.7)
	# Un choix reste à faire sur ces nœuds appris : anneau doré qui pulse.
	if not _pending.is_empty():
		var beat := 0.5 + 0.5 * sin(t * 5.0)
		for id in _pending:
			var n: Dictionary = tree.nodes[id]
			var rr := _radius(n, zoom) * 1.35 + maxf(3.0, 3.0 * w)
			c.draw_arc(n["pos"], rr, 0.0, TAU, 32, Color(UiTheme.GOLD, 0.4 + 0.6 * beat), maxf(3.0, 2.0 * w))
			var a := t * 1.2
			c.draw_arc(n["pos"], rr + maxf(5.0, 5.0 * w), a, a + PI * 0.6, 12, Color(UiTheme.GOLD, 0.5), maxf(2.0, 1.4 * w))
			c.draw_arc(n["pos"], rr + maxf(5.0, 5.0 * w), a + PI, a + PI * 1.6, 12, Color(UiTheme.GOLD, 0.5), maxf(2.0, 1.4 * w))
	if hover >= 0:
		var n: Dictionary = tree.nodes[hover]
		TreeArt.hover_mark(c, n["pos"], _radius(n, zoom), tree.branch_color(n["branch"]), t, _hover_since, w)
	# Plan, chemin vers le nœud survolé et résultats de la recherche.
	panels.draw_overlay(c)


## Partie de l'arbre visible à l'écran (coordonnées de l'arbre), agrandie de margin.
func _tree_view(margin: float) -> Rect2:
	return Rect2(to_tree(Vector2.ZERO), size / zoom).grow(margin)


func _draw_life(c: CanvasItem) -> void:
	var tree = Game.tree
	var level := lod()
	var view := _tree_view(60.0 / zoom)
	# La graine d'origine rayonne.
	var root: Dictionary = tree.nodes[0]
	if view.has_point(root["pos"]):
		TreeArt.seed_rays(c, root["pos"], _radius(root, zoom), tree.branch_color(-1), t)
	# Les nœuds appris respirent ; les nœuds flétris couverts de cendre fument.
	for id in _owned_ids:
		var n: Dictionary = tree.nodes[id]
		if view.has_point(n["pos"]):
			TreeArt.owned_halo(c, n["pos"], _radius(n, zoom), tree.branch_color(n["branch"]), t, id * 1.3)
	if level != LOD_OVERVIEW:
		for id in _ashen_ids:
			var n: Dictionary = tree.nodes[id]
			if view.has_point(n["pos"]):
				TreeArt.embers(c, n["pos"], _radius(n, zoom), t, id)
	_draw_sap(c)
	_draw_blooms(c)
	# Ouverture : une onde de sève part de la graine et parcourt l'arbre.
	if _intro < TreeArt.INTRO_DUR:
		var k := _intro / TreeArt.INTRO_DUR
		var rr := _extent() * 1.05 * Anim.ease_out(k)
		var col := Art.ec("seve", "clair")
		c.draw_arc(Vector2.ZERO, rr, 0.0, TAU, 96, Color(col, 0.45 * (1.0 - k)), maxf(4.0, 14.0 * (1.0 - k)) / zoom)
		c.draw_arc(Vector2.ZERO, rr * 0.9, 0.0, TAU, 96, Color(col, 0.15 * (1.0 - k)), maxf(8.0, 40.0 * (1.0 - k)) / zoom)


## Sève : de petites lueurs qui circulent le long des liens appris, de l'origine vers l'extérieur.
func _draw_sap(c: CanvasItem) -> void:
	if _sap.is_empty():
		return
	var tree = Game.tree
	var base := maxf(6.0, 2.5 / zoom)
	var view := _tree_view(base * 4.0)
	for entry in _sap:
		var i: int = entry[0]
		var reversed: bool = entry[1]
		# Un passage dure environ 2 s, suivi d'une pause : les lueurs ne forment pas un défilé régulier.
		var u := fposmod(t * 0.5 + entry[2] * 1.7, 1.7)
		if u > 1.0:
			continue
		var head := _curve_at(i, u, reversed)
		if not view.has_point(head):
			continue
		var col: Color = tree.branch_color(_edge_branch(tree.edges[i])).lerp(Color.WHITE, 0.55)
		var fade := sin(u * PI)
		var tail := _curve_at(i, maxf(u - 0.18, 0.0), reversed)
		var mid := _curve_at(i, maxf(u - 0.09, 0.0), reversed)
		c.draw_line(tail, mid, Color(col, 0.25 * fade), base * 0.4)
		c.draw_line(mid, head, Color(col, 0.55 * fade), base * 0.55)
		c.draw_circle(head, base * 1.25, Color(col, 0.18 * fade))
		c.draw_circle(head, base * 0.5, Color(col, 0.95 * fade))
		c.draw_circle(head, base * 0.22, Color(1, 1, 1, fade))


## Éclosion d'un nœud appris (TreeArt.bloom).
func _draw_blooms(c: CanvasItem) -> void:
	var tree = Game.tree
	for id in _blooms:
		var n: Dictionary = tree.nodes[id]
		var petals := 6 if n["type"] == "small" else (8 if n["type"] == "notable" else 10)
		TreeArt.bloom(c, n["pos"], _radius(n, zoom), tree.branch_color(n["branch"]), _blooms[id] / BLOOM_DUR, petals, 1.0 / zoom, id)


# --- Libellés ---

## Place les libellés visibles sans chevauchement. Chaque entrée : [rect, texte, taille, couleur].
## Ordre de priorité : noms des branches, origine, nœuds clés, puis notables (zoom proche seulement).
## Un libellé essaie quatre places autour de son nœud (dessous, dessus, droite, gauche), puis plus loin ;
## s'il n'en trouve aucune dans l'écran et libre, il n'est pas dessiné.
func layout_labels() -> Array:
	var out: Array = []
	var area := _view_area()
	var placed: Array[Rect2] = []
	var tree = Game.tree
	for bi in SkillTree.BRANCHES.size():
		var rect := _branch_label_rect(bi, zoom, cam)
		if area.encloses(rect) and not _hits(rect, placed):
			placed.append(rect)
			out.append([rect, SkillTree.BRANCHES[bi]["name"], FONT_BRANCH, tree.branch_color(bi)])

	var level := lod()
	var cands: Array = []
	# Les disques des nœuds importants à l'écran sont des obstacles : aucun texte ne les recouvre.
	var discs: Array[Rect2] = []
	# Les petits nœuds appris ou disponibles (ceux sur lesquels on clique) aussi.
	for n in tree.nodes:
		if n["type"] == "small" and _states.get(n["id"], "locked") == "locked":
			continue
		var sp := to_screen(n["pos"])
		var sr := _radius(n, zoom) * zoom
		if not area.grow(sr).has_point(sp):
			continue
		discs.append(Rect2(sp - Vector2(sr, sr), Vector2(sr, sr) * 2.0))
		if n["type"] == "small":
			continue
		if not n["type"] in ["root", "keystone", "skill"] and level != LOD_CLOSE:
			continue
		if n["name"] == "":
			continue
		var prio: int = {"root": 0, "keystone": 1, "skill": 1}.get(n["type"], 2)
		cands.append([prio, n, sp, sr])
	cands.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else a[1]["id"] < b[1]["id"])

	for cand in cands:
		var n: Dictionary = cand[1]
		var sp: Vector2 = cand[2]
		var sr: float = cand[3]
		var fs: int = {"root": FONT_ROOT, "keystone": FONT_KEYSTONE, "skill": FONT_KEYSTONE}.get(n["type"], FONT_NOTABLE)
		var ts := _text_size(n["name"], fs)
		# Quatre places collées au nœud, puis les mêmes un peu plus loin (autour de l'origine, très entourée).
		var tries := []
		for gap in [4.0, 4.0 + maxf(14.0, sr * 1.5)]:
			tries.append_array([
				Vector2(sp.x - ts.x / 2.0, sp.y + sr + gap),
				Vector2(sp.x - ts.x / 2.0, sp.y - sr - gap - ts.y),
				Vector2(sp.x + sr + gap + 2.0, sp.y - ts.y / 2.0),
				Vector2(sp.x - sr - gap - 2.0 - ts.x, sp.y - ts.y / 2.0),
			])
		for pos in tries:
			var rect := Rect2(pos, ts)
			if not area.encloses(rect) or _hits(rect, placed) or _hits(rect.grow(-1.0), discs):
				continue
			placed.append(rect)
			var st: String = _states.get(n["id"], "locked")
			var col := Color(0.85, 0.9, 0.85, 0.75)
			if n["type"] == "root":
				col = UiTheme.GOLD
			elif st == "owned":
				col = Color(1, 1, 1, 0.95)
			elif not n["type"] in ["keystone", "skill"]:
				col = Color(0.8, 0.85, 0.8, 0.7)
			out.append([rect, n["name"], fs, col])
			break
	return out


func _hits(r: Rect2, rects: Array[Rect2]) -> bool:
	for o in rects:
		if r.intersects(o):
			return true
	return false


func _draw_labels(c: CanvasItem) -> void:
	label_rects.clear()
	for l in layout_labels():
		var rect: Rect2 = l[0]
		var base := Vector2(rect.position.x, rect.position.y + font.get_ascent(l[2]))
		c.draw_string_outline(font, base, l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, l[2], maxi(3, int(l[2] / 4.0)), Color(BG, 0.9))
		c.draw_string(font, base, l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, l[2], l[3])
		label_rects.append(rect)
	_audit_texts()


# --- En-tête et infobulle ---

func _draw_overlay(c: CanvasItem) -> void:
	var tree = Game.tree
	c.draw_rect(Rect2(0, 0, size.x, HEADER_H), Color(0.05, 0.07, 0.06))
	c.draw_line(Vector2(0, HEADER_H), Vector2(size.x, HEADER_H), Color(0.6, 0.8, 0.6, 0.15), 1.0)
	c.draw_string(font, Vector2(24, 30), "Arbre de vie", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiTheme.INK)
	var pts_col := UiTheme.GOLD if Game.points > 0 else Color(0.7, 0.75, 0.7)
	c.draw_string(font, Vector2(24, 54), "%d point(s) à placer  ·  Niveau %d  ·  %d / %d nœuds" % [Game.points, Game.level, Game.allocated.size(), tree.nodes.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, pts_col)
	c.draw_string(font, Vector2(0, 30), "Clic : apprendre (un nœud ou tout un chemin)   ·   Clic droit : oublier   ·   Glisser : se déplacer   ·   Molette : zoom   ·   Tab / Échap : fermer", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24, 14, Color(0.7, 0.78, 0.72))
	c.draw_string(font, Vector2(0, 52), "Chaque nœud appris ravive la région du monde située dans sa direction.", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24, 14, Color(0.6, 0.8, 0.6))
	if hover >= 0:
		_draw_tooltip(c, tree.nodes[hover], _states.get(hover, _state(hover)))
	_audit_texts()


## Déclare au registre d'audit des tests visuels (UiAudit) tous les textes de l'écran :
## libellés placés, en-tête et infobulle. Reconstruit en entier à chaque appel, car les
## libellés et l'en-tête sont dessinés par deux couches différentes. Sans effet hors des tests.
func _audit_texts() -> void:
	if not UiAudit.enabled:
		return
	UiAudit.begin("arbre")
	var branch_names := {}
	for b in SkillTree.BRANCHES:
		branch_names[b["name"]] = true
	for l in layout_labels():
		UiAudit.text("arbre", l[0], l[1], "", branch_names.has(l[1]) and l[2] == FONT_BRANCH)
	var tree = Game.tree
	UiAudit.text_at("arbre", font, Vector2(24, 30), "Arbre de vie", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Transform2D.IDENTITY, "entete", true)
	UiAudit.text_at("arbre", font, Vector2(24, 54), "%d point(s) à placer  ·  Niveau %d  ·  %d / %d nœuds" % [Game.points, Game.level, Game.allocated.size(), tree.nodes.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Transform2D.IDENTITY, "entete", true)
	UiAudit.text_at("arbre", font, Vector2(0, 30), "Clic : apprendre (un nœud ou tout un chemin)   ·   Clic droit : oublier   ·   Glisser : se déplacer   ·   Molette : zoom   ·   Tab / Échap : fermer", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24, 14, Transform2D.IDENTITY, "entete", true)
	UiAudit.text_at("arbre", font, Vector2(0, 52), "Chaque nœud appris ravive la région du monde située dans sa direction.", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24, 14, Transform2D.IDENTITY, "entete", true)
	if hover >= 0:
		var lines := tooltip_lines(tree.nodes[hover], _states.get(hover, _state(hover)))
		var rect := tooltip_rect(lines)
		var y := rect.position.y + 8.0
		for l in lines:
			y += l[1] + 4.0
			UiAudit.text_at("arbre", font, Vector2(rect.position.x + 14, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, l[1], Transform2D.IDENTITY, "infobulle")
			y += 4.0
	# Fenêtre de choix d'une maîtrise ou d'une mutation (nœuds Control).
	if _choice != null:
		UiAudit.scan_controls("arbre", _choice)
	if grafts_panel != null and grafts_panel.visible:
		UiAudit.scan_controls("arbre", grafts_panel)


## Lignes de l'infobulle d'un nœud : [texte, taille, couleur], déjà coupées à la largeur maximale.
func tooltip_lines(n: Dictionary, st: String) -> Array:
	var tree = Game.tree
	var raw: Array = []
	var bname: String = SkillTree.BRANCHES[n["branch"]]["name"] if n["branch"] >= 0 else ""
	raw.append([n["name"], 18, tree.branch_color(n["branch"])])
	var sub: String = KIND_LABEL[n["type"]]
	if bname != "":
		sub += " · " + bname + " · anneau %d" % n["ring"]
	var dim := Color(0.65, 0.72, 0.68)
	var ink := Color(0.92, 0.95, 0.92)
	raw.append([sub, 13, dim])
	for e in n["effects"]:
		var line := Effects.describe(e)
		if line != "":
			raw.append(["• " + line, 14, ink])
	if n["desc"] != "":
		raw.append(["• " + n["desc"], 14, ink])
	var id: int = n["id"]
	# Maîtrise ou mutation : tous les choix, celui qui est fait en doré.
	if not n["choices"].is_empty():
		var chosen: int = Game.choice_index(id) if st == "owned" else -1
		if n["type"] == "mutation":
			raw.append(["Transforme « %s » : un seul choix" % Content.skills().get(n["mutates"], {}).get("name", n["mutates"]), 13, dim])
		else:
			raw.append(["Un bonus à choisir, modifiable à tout moment", 13, dim])
		for i in n["choices"].size():
			var ch: Dictionary = n["choices"][i]
			var text := "› %s : %s" % [ch.get("name", ""), SkillTree.describe_effects(ch.get("effects", []))]
			raw.append([text + ("  (choisi)" if i == chosen else ""), 14, UiTheme.GOLD if i == chosen else (ink if chosen < 0 else dim)])
		if st == "owned" and chosen < 0:
			raw.append(["Clic pour faire ton choix", 13, UiTheme.GOLD])
		elif st == "owned" and n["type"] == "mastery":
			raw.append(["Clic pour changer de bonus", 13, UiTheme.GOLD])
	if n["type"] == "graft":
		var g = Content.grafts().get(Game.graft_of(id))
		if g is Dictionary:
			raw.append(["Greffe : " + str(g.get("name", "")), 14, UiTheme.GOLD])
			for e in g.get("effects", []):
				var line := Effects.describe(e)
				if line != "":
					raw.append(["• " + line, 14, ink])
		else:
			raw.append(["• Emplacement vide : reçoit une greffe trouvée dans le monde.", 14, ink])
		raw.append_array(grafts_panel.tooltip_lines(n))
		if grafts_panel.held == "" and g is Dictionary and st == "owned":
			raw.append(["Clic pour retirer la greffe", 13, UiTheme.GOLD])
	# Grappe écrite à la main : avancement et bonus de grappe complète.
	if n["cluster"] != "" and tree.clusters.has(n["cluster"]):
		var cl: Dictionary = tree.clusters[n["cluster"]]
		var prog: Array = Game.cluster_progress(n["cluster"])
		raw.append(["Grappe « %s » : %d / %d nœuds" % [cl["name"], prog[0], prog[1]], 13, dim])
		if not cl["effects"].is_empty():
			raw.append(["Grappe complète : " + SkillTree.describe_effects(cl["effects"]), 13, UiTheme.GOLD if prog[0] == prog[1] else dim])
	# Résonance de la branche : le prochain palier.
	if n["branch"] >= 0:
		var tiers = SkillTree.BRANCHES[n["branch"]].get("resonance", [])
		if tiers is Array and not tiers.is_empty():
			var count: int = Game.branch_count(n["branch"])
			var next := {}
			for tier in tiers:
				if count < int(tier.get("count", 0)):
					next = tier
					break
			if next.is_empty():
				raw.append(["Résonance de %s : tous les paliers atteints (%d nœuds)" % [bname, count], 13, UiTheme.GOLD])
			else:
				raw.append(["Résonance de %s : %d / %d nœuds, puis %s" % [bname, count, int(next["count"]), SkillTree.describe_effects(next.get("effects", []))], 13, dim])
	if st != "owned" and _locks.has(id):
		raw.append([_locks[id], 13, LOCK_COLOR])
	else:
		raw.append_array(panels.tooltip_lines(n, st))
	var maxw := minf(TOOLTIP_MAX_W, size.x - 2.0 * MARGIN - 28.0)
	var lines: Array = []
	for l in raw:
		for part in _wrap(l[0], l[1], maxw):
			lines.append([part, l[1], l[2]])
	return lines


## Coupe un texte en lignes qui tiennent dans max_w (les puces sont alignées sous le texte).
func _wrap(text: String, fs: int, max_w: float) -> PackedStringArray:
	var out := PackedStringArray()
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
		out.append(text)
		return out
	var indent := "   " if text.begins_with("• ") else ""
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
			out.append(line)
			line = indent + word
		else:
			line = next
	if line != "":
		out.append(line)
	return out


## Rectangle de l'infobulle : à côté de la souris, retourné si besoin, et toujours dans l'écran.
func tooltip_rect(lines: Array) -> Rect2:
	var w := 0.0
	var h := 16.0
	for l in lines:
		w = maxf(w, font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, l[1]).x)
		h += l[1] + 8.0
	w += 28.0
	var pos := mouse + Vector2(18, 18)
	if pos.x + w > size.x - MARGIN:
		pos.x = mouse.x - w - 18.0
	if pos.y + h > size.y - MARGIN:
		pos.y = mouse.y - h - 18.0
	pos.x = clampf(pos.x, MARGIN, maxf(MARGIN, size.x - MARGIN - w))
	pos.y = clampf(pos.y, HEADER_H + 6.0, maxf(HEADER_H + 6.0, size.y - MARGIN - h))
	return Rect2(pos, Vector2(w, h))


func _draw_tooltip(c: CanvasItem, n: Dictionary, st: String) -> void:
	var lines := tooltip_lines(n, st)
	var rect := tooltip_rect(lines)
	c.draw_rect(rect, Color(0.06, 0.08, 0.07))
	c.draw_rect(rect, Color(0.6, 0.8, 0.6, 0.35), false, 1.0)
	var y := rect.position.y + 8.0
	for l in lines:
		y += l[1] + 4.0
		c.draw_string(font, Vector2(rect.position.x + 14, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, l[1], l[2])
		y += 4.0
