## Galerie : chaque type d'ennemi (dans quatre états) et chaque effet de fx.gd côte à côte,
## sur un fond uni, pour être capturés et comparés par le banc de tests visuels.
## Les ennemis et les effets sont les vrais (enemy.gd, fx.gd), figés à un instant précis.
extends Node2D

const EnemyScript = preload("res://scripts/enemy.gd")
const FxScript = preload("res://scripts/fx.gd")

const STATES := ["normal", "blessé", "touché", "empoisonné"]

var view := Vector2(1600, 900)


## Faux « main » et faux joueur : juste ce que lisent enemy._draw et fx.
class PlayerStub:
	var position := Vector2(4000, 300)
	var radius := 14.0


class MainStub:
	var player := PlayerStub.new()
	var enemies: Array = []

	## La galerie fige la logique ; ces réponses neutres évitent toute erreur si elle tourne quand même.
	func enemies_near(_center: Vector2, _radius: float, _touch_body := true) -> Array:
		return []


func _ready() -> void:
	var stub := MainStub.new()
	for k in EnemyScript.KINDS.size():
		for s in STATES.size():
			var e = EnemyScript.new()
			e.main = stub
			e.setup(k, 1.0)
			e.t = 0.0
			match s:
				1:
					e.hp = e.max_hp * 0.4
				2:
					e.hit_flash = 1.0
				3:
					e.poison_time = 1.0
			e.scale = Vector2(2, 2)
			e.position = Vector2(300 + s * 330, 160 + k * 130)
			add_child(e)
			e.set_process(false)
			e.set_physics_process(false)

	var fx = FxScript.new()
	fx.main = stub
	add_child(fx)
	fx.set_process(false)
	fx.set_physics_process(false)
	for i in 3:
		fx.ring(Vector2(250 + i * 200, 640), 20.0, 90.0, 1.0, Color("f2d06b"), 4.0)
		fx.rings[-1]["t"] = 0.15 + 0.3 * i
	fx.text(Vector2(950, 640), "42", Color("f2d06b"), 18, 0.6)
	fx.texts[-1]["t"] = 0.2
	fx.text(Vector2(1100, 640), "Niveau 3", Color("e9e2c8"), 24, 1.0)
	fx.texts[-1]["t"] = 0.5
	fx.cloud(Vector2(1350, 640), 90.0, 4.0, 10.0)
	fx.clouds[-1]["t"] = 1.0
	# Chiffres de dégâts (normal, critique) et particules figées à un instant : étincelles, cendres, pétales.
	fx.text(Vector2(950, 700), "17", Color("f4efd8"), 15, 0.7)
	fx.texts[-1]["t"] = 0.15
	fx.text(Vector2(1100, 700), "96", Color("ffd45a"), 24, 0.95)
	fx.texts[-1]["t"] = 0.2
	for i in 8:
		var a := TAU * i / 8.0
		fx.particles.append({"kind": 0, "pos": Vector2(300, 760) + Vector2.from_angle(a) * 26.0, "vel": Vector2.from_angle(a) * 200.0,
			"t": 0.1, "dur": 0.3, "size": 2.0, "color": Color("ffe08a"), "rot": 0.0, "drag": 6.0, "spin": 0.0, "ph": 0.0})
		fx.particles.append({"kind": 1, "pos": Vector2(520, 760) + Vector2.from_angle(a) * (14.0 + i * 3.0), "vel": Vector2.ZERO,
			"t": 0.3, "dur": 1.5, "size": 2.6, "color": Color("9a8f8a") if i % 4 else Color("ff9a4a"), "rot": 0.0, "drag": 1.8, "spin": 0.0, "ph": 0.0})
		fx.particles.append({"kind": 2, "pos": Vector2(740, 760) + Vector2.from_angle(a) * (14.0 + i * 3.0), "vel": Vector2.ZERO,
			"t": 0.4, "dur": 1.3, "size": 4.0, "color": Color("f6b8c8") if i % 2 else Color("f2d06b"), "rot": a * 1.3, "drag": 1.6, "spin": 0.0, "ph": 0.0})
	fx.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.12, 0.15, 0.12))
	var font := ThemeDB.fallback_font
	for s in STATES.size():
		draw_string(font, Vector2(300 + s * 330 - 60, 40), STATES[s], HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color.WHITE)
	for k in EnemyScript.KINDS.size():
		draw_string(font, Vector2(20, 168 + k * 130), ["Flétri", "Cendreux", "Colosse"][k], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(font, Vector2(20, 560), "Effets (ondes, textes, nuage de spores, étincelles, cendres, pétales)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
