## Galerie : chaque type d'ennemi (dans quatre états) et chaque effet de fx.gd côte à côte,
## sur un fond uni, pour être capturés et comparés par le banc de tests visuels.
## Les ennemis et les effets sont les vrais (enemy.gd, fx.gd), figés à un instant précis.
## page = "roncier" : les ennemis du roncier (dont leurs attaques annoncées), l'épine tirée,
## les ronces et les buissons d'épines, morts puis vivants.
## page = "varies" : les nouveaux Flétris (Cracheur de cendre, Gardien d'écorce et ses protégés,
## Boursouflé et sa poche de spores) et les élites, une par modificateur, puis une à deux modificateurs.
## page = "silhouettes" : chaque sorte en noir sur blanc puis en couleur, la mort d'un Flétri (cendre,
## puis la pousse de vie) et chaque attaque annoncée puis frappée.
extends Node2D

const EnemyScript = preload("res://scripts/enemy.gd")
const FxScript = preload("res://scripts/fx.gd")
const FloraScript = preload("res://scripts/flora.gd")
const ThornScript = preload("res://scripts/enemy_thorn.gd")
const BlastScript = preload("res://scripts/enemy_blast.gd")
const RemainsScript = preload("res://scripts/enemy_remains.gd")
const FletriArt = preload("res://scripts/fletri_art.gd")
## Toutes les sortes, dans l'ordre de la planche des silhouettes.
const ALL_KINDS := ["fletri", "cendreux", "colosse", "rejeton", "cracheur", "tireur", "gardien", "boursoufle", "chargeur", "nid"]
const SIL_X0 := 100
const SIL_DX := 155
## Instants de la mort d'un Flétri (secondes depuis le coup fatal).
const DEATH_TIMES := [0.05, 0.2, 0.36, 0.5, 0.7, 0.95]

const STATES := ["normal", "blessé", "touché", "empoisonné", "saignant ×3", "enraciné"]
const COL_X := 200
const COL_W := 240
## Les trois Flétris d'origine (les premières sortes de enemies.json).
const BASE_KINDS := 3
const RONCIER := ["tireur", "chargeur", "nid", "rejeton"]
const RONCIER_STATES := ["normal", "blessé", "touché", "attaque annoncée"]
const RONCIER_X := [260, 500, 740, 1000]
const VARIES_STATES := ["normal", "blessé", "touché", "attaque annoncée"]
const VARIES_X := [260, 470, 680, 900]
## Élites de la galerie : [sorte, modificateurs, préparation].
const ELITES := [
	["fletri", ["rapide"], ""],
	["colosse", ["enrage"], "enrage"],
	["fletri", ["ecorce"], "ecorce"],
	["tireur", ["epines"], "epines"],
	["cendreux", ["invocateur"], "invocateur"],
	["chargeur", ["rapide", "epines"], ""],
]

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
	if page == "varies":
		_ready_varies()
		return
	if page == "silhouettes":
		_ready_silhouettes()
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


func _enemy(stub, kind, pos: Vector2, sc: float):
	var e = EnemyScript.new()
	e.main = stub
	e.setup(kind, 1.0)
	e.t = 0.0
	e.attack_dir = Vector2.RIGHT
	e.scale = Vector2(sc, sc)
	e.position = pos
	add_child(e)
	e.set_process(false)
	e.set_physics_process(false)
	return e


func _ready_varies() -> void:
	var stub := MainStub.new()
	var kinds := ["cracheur", "boursoufle"]
	for k in kinds.size():
		for s in VARIES_STATES.size():
			if kinds[k] == "boursoufle" and s == 3:
				continue
			var e = _enemy(stub, kinds[k], Vector2(VARIES_X[s], 120 + k * 130), 1.6 if s < 3 else 1.0)
			match s:
				1:
					e.hp = e.max_hp * 0.4
				2:
					e.hit_flash = 1.0
				3:
					e.state = "windup"
					e.state_t = float(e.data["windup"]) * 0.35
	# Le Boursouflé vient d'éclater : sa poche de spores s'annonce au sol.
	var b = BlastScript.new()
	b.position = Vector2(VARIES_X[3], 250)
	b.t = b.delay * 0.6
	add_child(b)
	b.set_process(false)
	b.set_physics_process(false)
	b.queue_redraw()
	# Boule de cendre en vol.
	var th = ThornScript.new()
	th.vel = Vector2.RIGHT
	th.look = "cendre"
	th.position = Vector2(1110, 120)
	th.scale = Vector2(2, 2)
	add_child(th)
	th.set_physics_process(false)
	# Gardien d'écorce et deux Flétris qu'il protège.
	var g = _enemy(stub, "gardien", Vector2(1330, 200), 1.0)
	for off in [Vector2(-110, 50), Vector2(95, 70)]:
		var f = _enemy(stub, "fletri", g.position + off, 1.0)
		f.guard_time = 1.0
		f.guard_cut = 0.5
		f.guard_from = g.position
	# Élites, une par modificateur, puis une élite à deux modificateurs.
	for i in ELITES.size():
		var spec: Array = ELITES[i]
		var e = _enemy(stub, spec[0], Vector2.ZERO, 1.3)
		e.position = Vector2(200 + (i % 3) * 300 + (0 if i < 3 else 150), 500 + int(i / 3) * 230)
		e.make_elite(spec[1])
		match spec[2]:
			"enrage":
				e.hp = e.max_hp * 0.35
				e.enraged = true
			"ecorce":
				e.shield = e.max_shield * 0.6
			"epines":
				e.aff_state = "epines"
				e.aff_t = 0.3
			"invocateur":
				e.aff_state = "invocateur"
				e.aff_t = 0.4


func _ready_silhouettes() -> void:
	var stub := MainStub.new()
	for i in ALL_KINDS.size():
		_enemy(stub, ALL_KINDS[i], Vector2(SIL_X0 + i * SIL_DX, 262), 1.5)
	# Mort d'un Flétri : la silhouette s'éteint et s'effrite, puis une pousse de vie sort du sol.
	for i in DEATH_TIMES.size():
		var r = RemainsScript.new()
		r.kind_id = "fletri"
		r.radius = 14.0
		r.t = DEATH_TIMES[i]
		r.scale = Vector2(2, 2)
		r.position = Vector2(140 + i * 140, 465)
		add_child(r)
		r.set_process(false)
		r.queue_redraw()
	# Attaques : annoncée (aux deux tiers), puis frappée. Échelle réduite pour que tout tienne.
	var sc := 0.62
	var tir = _enemy(stub, "tireur", Vector2(50, 600), sc)
	tir.state = "windup"
	tir.state_t = float(tir.data["windup"]) * 0.35
	tir = _enemy(stub, "tireur", Vector2(400, 600), sc)
	tir.strike_t = tir.STRIKE_TIME * 0.3
	var cr = _enemy(stub, "cracheur", Vector2(60, 700), sc)
	cr.state = "windup"
	cr.state_t = float(cr.data["windup"]) * 0.35
	cr = _enemy(stub, "cracheur", Vector2(400, 700), sc)
	cr.strike_t = cr.STRIKE_TIME * 0.3
	var ch = _enemy(stub, "chargeur", Vector2(60, 810), sc)
	ch.state = "windup"
	ch.state_t = float(ch.data["windup"]) * 0.35
	ch = _enemy(stub, "chargeur", Vector2(560, 810), sc)
	ch.state = "charge"
	ch.travelled = 220.0
	for j in 2:
		var b = BlastScript.new()
		b.position = Vector2(900 + j * 200, 640)
		b.scale = Vector2(0.8, 0.8)
		b.t = b.delay * 0.65 if j == 0 else b.delay + 0.06
		b.done = j == 1
		add_child(b)
		b.set_process(false)
		b.set_physics_process(false)
		b.queue_redraw()
	for j in 2:
		var e = _enemy(stub, "fletri", Vector2(1340 + j * 160, 640), 0.8)
		e.make_elite(["epines"])
		if j == 0:
			e.aff_state = "epines"
			e.aff_t = 0.25
		else:
			e.strike_t = e.STRIKE_TIME * 0.3
	var nid = _enemy(stub, "nid", Vector2(960, 810), 1.0)
	nid.state = "windup"
	nid.state_t = float(nid.data["windup"]) * 0.15


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
	if page == "silhouettes":
		_draw_silhouettes(font)
		return
	if page == "varies":
		for s in VARIES_STATES.size():
			draw_string(font, Vector2(VARIES_X[s] - 90, 40), VARIES_STATES[s], HORIZONTAL_ALIGNMENT_CENTER, 180, 18, Color.WHITE)
		draw_string(font, Vector2(20, 128), "Cracheur", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		draw_string(font, Vector2(20, 258), "Boursouflé", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		draw_string(font, Vector2(1040, 40), "Boule de cendre, Gardien d'écorce et ses protégés", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		draw_string(font, Vector2(20, 380), "Élites : rapide, enragé, cuirassé d'écorce, épineux, invocateur, deux modificateurs", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		return
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
	draw_string(font, Vector2(20, 560), "Effets (ondes, textes, nuage de spores, étincelles, cendres, pétales)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func _draw_silhouettes(font: Font) -> void:
	draw_string(font, Vector2(20, 34), "Silhouettes en noir sur blanc : chaque sorte se reconnaît à sa forme", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_rect(Rect2(20, 50, view.x - 40, 130), Color("f4f0e6"))
	for i in ALL_KINDS.size():
		var x: float = SIL_X0 + i * SIL_DX
		FletriArt.draw(self, ALL_KINDS[i], Vector2(x, 115), EnemyScript.KINDS[EnemyScript.kind_index(ALL_KINDS[i])]["radius"] * 1.5, Vector2.RIGHT, 0.0, {"mono": true})
		var nm: String = EnemyScript.KINDS[EnemyScript.kind_index(ALL_KINDS[i])]["name"]
		draw_string(font, Vector2(x - 75, 335), nm, HORIZONTAL_ALIGNMENT_CENTER, 150, 14, Color.WHITE)
	draw_string(font, Vector2(20, 395), "Mort : la silhouette tombe en cendre, puis la vie reprend à sa place", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(font, Vector2(20, 560), "Attaques : annoncée, puis frappée (même grammaire pour tous)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(font, Vector2(880, 560), "Poche du Boursouflé · élite épineuse · Nid qui enfante", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
