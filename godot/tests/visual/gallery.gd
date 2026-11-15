## Galerie : chaque type d'ennemi (dans quatre états) et chaque effet de fx.gd côte à côte,
## sur un fond uni, pour être capturés et comparés par le banc de tests visuels.
## Les ennemis et les effets sont les vrais (enemy.gd, fx.gd), figés à un instant précis.
## page = "roncier" : les ennemis du roncier (dont leurs attaques annoncées), l'épine tirée,
## les ronces et les buissons d'épines, morts puis vivants.
extends Node2D

const EnemyScript = preload("res://scripts/enemy.gd")
const FxScript = preload("res://scripts/fx.gd")
const FloraScript = preload("res://scripts/flora.gd")
const ThornScript = preload("res://scripts/enemy_thorn.gd")

const STATES := ["normal", "blessé", "touché", "empoisonné", "saignant ×3", "enraciné"]
const COL_X := 200
const COL_W := 240
## Les trois Flétris d'origine (les premières sortes de enemies.json).
const BASE_KINDS := 3
const RONCIER := ["tireur", "chargeur", "nid", "rejeton"]
const RONCIER_STATES := ["normal", "blessé", "touché", "attaque annoncée"]
const RONCIER_X := [260, 500, 740, 1000]

var view := Vector2(1600, 900)
var page := "fletris"


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
	if page == "roncier":
		_ready_roncier()
		return
	var stub := MainStub.new()
	for k in BASE_KINDS:
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
				4:
					for i in 3:
						e.apply_status("saignement", 2.0, 3.0)
				5:
					e.apply_status("enracine", 1.0, 2.0)
			e.scale = Vector2(2, 2)
			e.position = Vector2(COL_X + s * COL_W, 160 + k * 130)
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
	fx.queue_redraw()


func _ready_roncier() -> void:
	var stub := MainStub.new()
	for k in RONCIER.size():
		for s in RONCIER_STATES.size():
			var e = EnemyScript.new()
			e.main = stub
			e.setup(RONCIER[k], 1.0)
			e.t = 0.0
			e.attack_dir = Vector2.RIGHT
			match s:
				1:
					e.hp = e.max_hp * 0.4
				2:
					e.hit_flash = 1.0
				3:
					if e.behavior in ["shooter", "charger", "nest"]:
						e.state = "windup"
						e.state_t = float(e.data["windup"]) * 0.35
			# Le joueur fictif est loin à droite : tous regardent vers la droite. L'attaque annoncée
			# reste à l'échelle 1, pour que la visée et le couloir de charge tiennent dans l'image.
			e.scale = Vector2(1.6, 1.6) if s < 3 else Vector2.ONE
			e.position = Vector2(RONCIER_X[s], 120 + k * 120)
			add_child(e)
			e.set_process(false)
			e.set_physics_process(false)
	# Une épine en vol, puis les ronces et les buissons, morts et vivants.
	var th = ThornScript.new()
	th.vel = Vector2.RIGHT
	th.position = Vector2(220, 690)
	th.scale = Vector2(2, 2)
	add_child(th)
	th.set_physics_process(false)
	var decor := [
		[FloraScript.DecorBramble, false, Vector2(480, 780)],
		[FloraScript.DecorBramble, true, Vector2(700, 780)],
		[FloraScript.DecorBush, false, Vector2(960, 780)],
		[FloraScript.DecorBush, true, Vector2(1180, 780)],
		[FloraScript.DecorTree, true, Vector2(1400, 780)],
	]
	for d in decor:
		var t = d[0].new()
		t.size = 1.6
		t.tree_seed = 12345
		t.alive = d[1]
		t.position = d[2]
		add_child(t)
	# Un arbre à mi-pousse (vague de vie en cours).
	var growing = get_child(get_child_count() - 1)
	growing.leaf = 0.3


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.12, 0.15, 0.12))
	var font := ThemeDB.fallback_font
	if page == "roncier":
		for s in RONCIER_STATES.size():
			draw_string(font, Vector2(RONCIER_X[s] - 90, 40), RONCIER_STATES[s], HORIZONTAL_ALIGNMENT_CENTER, 180, 18, Color.WHITE)
		for k in RONCIER.size():
			draw_string(font, Vector2(20, 128 + k * 120), EnemyScript.KINDS[EnemyScript.kind_index(RONCIER[k])]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		draw_string(font, Vector2(20, 610), "Épine tirée, ronces et buissons d'épines (morts, vivants), arbre qui reverdit", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		return
	for s in STATES.size():
		draw_string(font, Vector2(COL_X + s * COL_W - 60, 40), STATES[s], HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color.WHITE)
	for k in BASE_KINDS:
		draw_string(font, Vector2(16, 168 + k * 130), ["Flétri", "Cendreux", "Colosse"][k], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(font, Vector2(20, 560), "Effets (ondes, textes flottants, nuage de spores)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
