## Planche du monde de Ronce (tâche E du jalon 5) : chaque lieu dans chaque état, et le décor
## mort, en train de reverdir puis vivant. Ce sont les vrais nœuds du jeu (sanctuary.gd, altar.gd,
## heart.gd, lost_sap.gd, flora.gd), figés à un instant précis, sur des pastilles de sol.
## Capturée par le banc visuel (scénario « monde », capture « galerie_monde »).
extends Node2D

const SanctuaryScript = preload("res://scripts/sanctuary.gd")
const AltarScript = preload("res://scripts/altar.gd")
const HeartScript = preload("res://scripts/heart.gd")
const LostSapScript = preload("res://scripts/lost_sap.gd")
const FloraScript = preload("res://scripts/flora.gd")

## Instant figé des animations (secondes).
const T := 1.3

var view := Vector2(1600, 900)
## Pastilles de sol : [rect, vivant].
var _tiles: Array = []
## Libellés : [position, texte, taille].
var _labels: Array = []


## Autel de galerie : on impose sa visibilité au lieu de la calculer d'après le joueur.
class GalleryAltar extends "res://scripts/altar.gd":
	var vis := 1.0

	func visibility() -> float:
		return vis


class PlayerStub extends Node2D:
	var radius := 14.0


## Faux « main » : juste ce que lisent les lieux quand ils sont figés.
class MainStub extends Node2D:
	var player: Node2D
	var actors_layer: Node2D
	var hud: Node
	var flora = null
	var benchmark := false


func _ready() -> void:
	var stub := MainStub.new()
	stub.player = PlayerStub.new()
	stub.player.position = Vector2(1.0e6, 1.0e6)
	stub.add_child(stub.player)
	var holder := Node.new()
	stub.hud = Node.new()
	holder.add_child(stub.hud)
	stub.add_child(holder)
	stub.visible = false
	add_child(stub)

	# Ligne 1 : sanctuaires, autels, secret.
	_title(Vector2(30, 34), "Sanctuaire : éteint, en cours, ravivé", 18)
	for i in 3:
		var p := Vector2(150 + i * 230, 200)
		_tile(Rect2(p - Vector2(108, 130), Vector2(216, 230)), i == 2)
		var s = SanctuaryScript.new()
		s.main = stub
		s.setup({"id": "galerie_%d" % i, "name": "", "region": "", "dist": 0.0, "angle": 0.0})
		s.frozen = true
		s.t = T
		Game.flags["sanctuaire_galerie_%d" % i] = i == 2
		s.progress = [0.0, SanctuaryScript.LIGHT_TIME * 0.55, SanctuaryScript.LIGHT_TIME][i]
		s.position = p
		add_child(s)
		s.set_process(false)
		s.set_physics_process(false)
	_title(Vector2(760, 34), "Autel : éteint, en cours, ravivé", 18)
	for i in 3:
		var p := Vector2(840 + i * 175, 200)
		_tile(Rect2(p - Vector2(84, 130), Vector2(168, 230)), i == 2)
		_altar(stub, "autel", p, i)
	_title(Vector2(1370, 34), "Secret", 18)
	for i in 3:
		var p := Vector2(1420 + (i % 2) * 110, 140 + (i / 2) * 120)
		if i == 2:
			p = Vector2(1475, 270)
		_altar(stub, "secret", p, i)

	# Ligne 2 : le Cœur dans ses trois états, la sève perdue.
	_title(Vector2(30, 362), "Cœur de flétrissure : en sommeil, siège, purifié", 18)
	for i in 3:
		var p := Vector2(160 + i * 295, 535)
		_tile(Rect2(p - Vector2(142, 145), Vector2(284, 290)), i == 2)
		var box := Node2D.new()
		box.position = p + Vector2(0, 10)
		box.scale = Vector2(0.55, 0.55)
		add_child(box)
		stub.actors_layer = box
		var h = HeartScript.new()
		h.main = stub
		box.add_child(h)
		h.position = -h.center
		h.body.position = Vector2.ZERO
		h.frozen = true
		h.t = T
		h.state = ["fletri", "siege", "purifie"][i]
		h.progress = [0.0, h.hold_time * 0.45, h.hold_time][i]
		h.set_process(false)
		h.set_physics_process(false)
		h.queue_redraw()
		h.body.queue_redraw()
	_title(Vector2(905, 362), "Sève perdue", 18)
	_tile(Rect2(Vector2(905, 390), Vector2(130, 290)), false)
	var sap = LostSapScript.new()
	sap.main = stub
	sap.t = T
	sap.position = Vector2(970, 600)
	add_child(sap)
	sap.set_process(false)
	sap.set_physics_process(false)

	# Décor : mort, en train de reverdir (vague de vie), vivant.
	_title(Vector2(1060, 362), "Décor : mort, reverdit, vivant", 18)
	var decor := [
		[FloraScript.DecorTree, 1.1, 1050.0, 470.0],
		[FloraScript.DecorBramble, 0.9, 1050.0, 570.0],
		[FloraScript.DecorBush, 1.2, 1050.0, 650.0],
	]
	for i in 3:
		_tile(Rect2(Vector2(1050 + i * 180, 390), Vector2(170, 290)), i == 2)
	for d in decor:
		for i in 3:
			var t = d[0].new()
			t.size = d[1]
			t.tree_seed = 4242
			t.alive = i > 0
			t.leaf = [1.0, 0.55, 1.0][i]
			t.position = Vector2(d[2] + 85 + i * 180, d[3])
			add_child(t)
			t.set_process(false)

	# Ligne 3 : points de repère du roncier, morts puis vivants.
	_title(Vector2(30, 702), "Points de repère du roncier (grand arbre mort, ruine, rocher fendu) : morts, puis vivants", 18)
	var kinds := ["grand_arbre", "ruine", "rocher"]
	for j in kinds.size():
		for i in 2:
			var x := 150 + (j * 2 + i) * 255
			_tile(Rect2(Vector2(x - 120, 726), Vector2(240, 166)), i == 1)
			var l := FloraScript.DecorLandmark.new()
			l.kind = kinds[j]
			l.size = 0.62 if kinds[j] == "grand_arbre" else 0.85
			l.tree_seed = hash(kinds[j])
			l.alive = i == 1
			l.leaf = 1.0
			l.position = Vector2(x, 858)
			add_child(l)
			l.set_process(false)


func _altar(stub, kind: String, p: Vector2, i: int) -> void:
	var a := GalleryAltar.new()
	a.main = stub
	a.kind = kind
	a.id = "galerie_%s_%d" % [kind, i]
	a.data = {}
	a.t = T
	a.position = p
	add_child(a)
	a.active = i == 2
	a.progress = AltarScript.HOLD[kind] * 0.5 if i == 1 else (AltarScript.HOLD[kind] if i == 2 else 0.0)
	a.set_process(false)
	a.set_physics_process(false)
	a.queue_redraw()


func _tile(rect: Rect2, alive: bool) -> void:
	_tiles.append([rect, alive])


func _title(p: Vector2, text: String, sz: int) -> void:
	_labels.append([p, text, sz])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Art.c("sol_mort").darkened(0.45))
	for e in _tiles:
		var r: Rect2 = e[0]
		draw_rect(r, Art.c("sol_vivant") if e[1] else Art.c("sol_mort"))
	var font := ThemeDB.fallback_font
	for l in _labels:
		draw_string(font, l[0], l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, l[2], Art.c("texte"))
