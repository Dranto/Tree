## Écran de l'Arbre de vie : déplacement, zoom, apprentissage et oubli des nœuds.
## Le jeu est en pause tant que l'arbre est ouvert.
extends Control

const SkillTree = preload("res://scripts/skill_tree.gd")

const RADIUS := {"root": 26.0, "small": 11.0, "notable": 18.0, "keystone": 26.0}
const KIND_LABEL := {"root": "Origine", "small": "Nœud", "notable": "Nœud notable", "keystone": "Nœud clé"}

var cam := Vector2.ZERO
var zoom := 0.55
var dragging := false
var drag_moved := 0.0
var hover := -1
var mouse := Vector2.ZERO
var font: Font
var t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	focus_mode = Control.FOCUS_NONE
	font = ThemeDB.fallback_font
	Game.tree_changed.connect(queue_redraw)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tree"):
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	dragging = false
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		t += delta
		queue_redraw()


func to_tree(p: Vector2) -> Vector2:
	return (p - size / 2.0) / zoom + cam


func pick(p: Vector2) -> int:
	var tp := to_tree(p)
	var best := -1
	var bd := INF
	for n in Game.tree.nodes:
		var r: float = RADIUS[n["type"]] + 4.0 / zoom
		var d := tp.distance_squared_to(n["pos"])
		if d < r * r and d < bd:
			bd = d
			best = n["id"]
	return best


func zoom_at(p: Vector2, factor: float) -> void:
	var before := to_tree(p)
	zoom = clampf(zoom * factor, 0.15, 2.5)
	cam = before - (p - size / 2.0) / zoom


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
						Game.allocate(id)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			var id := pick(mb.position)
			if id >= 0:
				Game.refund(id)
		queue_redraw()
		return
	var mm := event as InputEventMouseMotion
	if mm:
		mouse = mm.position
		if dragging:
			drag_moved += mm.relative.length()
			cam -= mm.relative / zoom
		hover = pick(mouse)
		queue_redraw()


func _state(id: int) -> String:
	if Game.allocated.has(id):
		return "owned"
	for m in Game.tree.nodes[id]["neighbors"]:
		if Game.allocated.has(m):
			return "available"
	return "locked"


func _draw() -> void:
	var tree = Game.tree
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.045, 0.04, 0.95))
	UiAudit.begin("arbre")
	var tx := Transform2D(0.0, Vector2(zoom, zoom), 0.0, size / 2.0 - cam * zoom)

	draw_set_transform(size / 2.0 - cam * zoom, 0.0, Vector2(zoom, zoom))
	for r in range(1, SkillTree.RINGS + 1):
		draw_arc(Vector2.ZERO, r * SkillTree.RING_GAP, 0.0, TAU, 128, Color(1, 1, 1, 0.035), 1.0 / zoom)

	var states := {}
	for n in tree.nodes:
		states[n["id"]] = _state(n["id"])

	var dim := PackedVector2Array()
	var half := PackedVector2Array()
	for e in tree.edges:
		var a: Dictionary = tree.nodes[e.x]
		var b: Dictionary = tree.nodes[e.y]
		var oa: bool = states[e.x] == "owned"
		var ob: bool = states[e.y] == "owned"
		if oa and ob:
			var bi: int = b["branch"] if b["branch"] >= 0 else a["branch"]
			draw_line(a["pos"], b["pos"], tree.branch_color(bi), 6.0)
		elif oa or ob:
			half.append(a["pos"])
			half.append(b["pos"])
		else:
			dim.append(a["pos"])
			dim.append(b["pos"])
	if dim.size() > 0:
		draw_multiline(dim, Color(0.5, 0.55, 0.5, 0.18), 2.0)
	if half.size() > 0:
		draw_multiline(half, Color(0.85, 0.9, 0.85, 0.45), 3.0)

	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	var can_buy := Game.points > 0
	for n in tree.nodes:
		var st: String = states[n["id"]]
		var p: Vector2 = n["pos"]
		var r: float = RADIUS[n["type"]]
		var col: Color = tree.branch_color(n["branch"])
		var fill := Color(0.08, 0.1, 0.09)
		var stroke := col
		var width := 2.0
		if st == "owned":
			draw_circle(p, r * 1.8, Color(col.r, col.g, col.b, 0.18))
			fill = col
			stroke = Color(1, 1, 1, 0.7)
		elif st == "available":
			stroke = Color(col.r, col.g, col.b, 0.5 + 0.5 * pulse if can_buy else 0.5)
			width = 4.0 if can_buy else 2.0
		else:
			stroke = Color(col.r, col.g, col.b, 0.18)
		if n["type"] == "keystone":
			var pts := PackedVector2Array([p + Vector2(0, -r * 1.15), p + Vector2(r, 0), p + Vector2(0, r * 1.15), p + Vector2(-r, 0)])
			draw_colored_polygon(pts, fill)
			pts.append(pts[0])
			draw_polyline(pts, stroke, width + 1.0)
		else:
			draw_circle(p, r, fill)
			draw_arc(p, r, 0.0, TAU, 32, stroke, width if n["type"] == "small" else width + 1.0)
			if n["type"] == "notable":
				draw_circle(p, r * 0.4, Color(1, 1, 1, 0.75) if st == "owned" else Color(col.r, col.g, col.b, 0.4))
		if n["type"] == "keystone" or n["type"] == "root":
			var label_col := Color(1, 1, 1, 0.9) if st == "owned" else Color(0.85, 0.9, 0.85, 0.55)
			UiAudit.draw_text(self, "arbre", font, p + Vector2(-150, r + 22), n["name"], HORIZONTAL_ALIGNMENT_CENTER, 300, 16, label_col, tx)
		if n["id"] == hover:
			draw_arc(p, r + 6.0, 0.0, TAU, 32, Color.WHITE, 2.0 / zoom)

	# Noms des branches au bord de l'arbre
	var sector := TAU / SkillTree.BRANCHES.size()
	for bi in SkillTree.BRANCHES.size():
		var a := (bi + 0.5) * sector - PI / 2.0
		var pos := Vector2.from_angle(a) * (SkillTree.RINGS + 1.3) * SkillTree.RING_GAP
		UiAudit.draw_text(self, "arbre", font, pos + Vector2(-200, 0), SkillTree.BRANCHES[bi]["name"], HORIZONTAL_ALIGNMENT_CENTER, 400, 44, tree.branch_color(bi), tx, "", true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# En-tête
	draw_rect(Rect2(0, 0, size.x, 64), Color(0.05, 0.07, 0.06, 0.9))
	UiAudit.draw_text(self, "arbre", font, Vector2(24, 30), "Arbre de vie", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e9e2c8"), Transform2D.IDENTITY, "entete", true)
	var pts_col := Color("f2d06b") if Game.points > 0 else Color(0.7, 0.75, 0.7)
	UiAudit.draw_text(self, "arbre", font, Vector2(24, 54), "%d point(s) à placer  ·  Niveau %d  ·  %d / %d nœuds" % [Game.points, Game.level, Game.allocated.size(), tree.nodes.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, pts_col, Transform2D.IDENTITY, "entete", true)
	UiAudit.draw_text(self, "arbre", font, Vector2(0, 30), "Clic : apprendre   ·   Clic droit : oublier   ·   Glisser : se déplacer   ·   Molette : zoom   ·   Tab / Échap : fermer", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24, 14, Color(0.7, 0.78, 0.72), Transform2D.IDENTITY, "entete", true)
	UiAudit.draw_text(self, "arbre", font, Vector2(0, 52), "Chaque nœud appris ravive la région du monde située dans sa direction.", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 24, 14, Color(0.6, 0.8, 0.6), Transform2D.IDENTITY, "entete", true)

	if hover >= 0:
		_draw_tooltip(tree.nodes[hover], states[hover])


func _draw_tooltip(n: Dictionary, st: String) -> void:
	var tree = Game.tree
	var lines: Array = []
	var bname: String = SkillTree.BRANCHES[n["branch"]]["name"] if n["branch"] >= 0 else ""
	lines.append([n["name"], 18, tree.branch_color(n["branch"])])
	var sub: String = KIND_LABEL[n["type"]]
	if bname != "":
		sub += " · " + bname + " · anneau %d" % n["ring"]
	lines.append([sub, 13, Color(0.65, 0.72, 0.68)])
	for d in SkillTree.describe(n):
		lines.append(["• " + d, 14, Color(0.92, 0.95, 0.92)])
	if st == "owned":
		var ok: bool = Game.can_refund(n["id"])
		lines.append(["Appris" + ("  ·  clic droit pour l'oublier" if ok else ""), 13, Color("7fd36b")])
	elif st == "available":
		if Game.points > 0:
			lines.append(["Clic pour apprendre (1 point)", 13, Color("f2d06b")])
		else:
			lines.append(["Pas de point disponible : monte de niveau", 13, Color("e0675e")])
	else:
		lines.append(["Apprends d'abord un nœud voisin", 13, Color(0.6, 0.6, 0.6)])

	var w := 0.0
	var h := 16.0
	for l in lines:
		w = maxf(w, font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, l[1]).x)
		h += l[1] + 8.0
	w += 28.0
	var pos := mouse + Vector2(18, 18)
	if pos.x + w > size.x - 8.0:
		pos.x = mouse.x - w - 18.0
	if pos.y + h > size.y - 8.0:
		pos.y = mouse.y - h - 18.0
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.06, 0.08, 0.07, 0.96))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.6, 0.8, 0.6, 0.3), false, 1.0)
	var y := pos.y + 8.0
	for l in lines:
		y += l[1] + 4.0
		UiAudit.draw_text(self, "arbre", font, Vector2(pos.x + 14, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, l[1], l[2], Transform2D.IDENTITY, "infobulle")
		y += 4.0
