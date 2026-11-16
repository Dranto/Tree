## Autel caché et secret d'une région (data/rewards.json) : des ruines couvertes de cendre qu'on
## devine en s'approchant. Le joueur s'y tient quelques secondes pour le raviver : un point d'arbre
## (Game.grant_points, une seule fois) et une greffe qui tombe au sol (main.drop_graft).
##
## Drapeaux (Game.flags) : « <kind>_<id>_vu » quand le joueur l'a aperçu (carte de la tâche E),
## « <kind>_<id> » une fois ravivé. kind vaut « autel » ou « secret ».
## Un secret n'apparaît qu'à courte distance, presque invisible : une lueur dans la cendre.
extends Node2D

const Content = preload("res://scripts/content.gd")
const Regions = preload("res://scripts/regions.gd")
const Prompt = preload("res://scripts/prompt.gd")

## Distance où un autel commence à se dessiner, et où il est entièrement visible.
const REVEAL := {"autel": 520.0, "secret": 230.0}
const CLEAR := {"autel": 300.0, "secret": 110.0}
## Rayon où se tenir et temps à y passer pour le raviver.
const ZONE := 70.0
const HOLD := {"autel": 1.5, "secret": 2.5}

var main
var kind := "autel"
var data: Dictionary = {}
var id := ""
var active := false
var progress := 0.0
var seen := 0.0
var t := 0.0
var _was_near := false


## Crée les autels et secrets de rewards.json et les ajoute sous « parent ».
static func spawn_all(m, parent: Node) -> Array:
	var out: Array = []
	var r := Content.rewards()
	for pair in [["autel", r.get("altars", [])], ["secret", r.get("secrets", [])]]:
		for a in pair[1]:
			if not str(a.get("region", "")) in Regions.REGIONS:
				continue
			var n = load("res://scripts/altar.gd").new()
			n.main = m
			n.kind = pair[0]
			n.data = a
			n.id = str(a["id"])
			n.position = position_of(a, m)
			parent.add_child(n)
			out.append(n)
	return out


## Position dans le monde : distance à la graine et écart au milieu du secteur, hors des buissons.
static func position_of(a: Dictionary, m = null) -> Vector2:
	var ang: float = Regions.angle_of(str(a["region"])) + float(a.get("side", 0.0)) * Regions.half_width()
	var p := Vector2.from_angle(ang) * float(a["dist"])
	var h := 2800.0
	p = p.clamp(Vector2(-h, -h), Vector2(h, h))
	if m != null and m.flora != null:
		p = m.flora.push_out(p, ZONE)
	return p


func flag() -> String:
	return "%s_%s" % [kind, id]


func _ready() -> void:
	# Groupes lus par la carte et les objectifs (tâche E) : nœuds avec une propriété « id ».
	add_to_group(kind)
	active = Game.flags.get(flag(), false)
	seen = 1.0 if active or Game.flags.get(flag() + "_vu", false) else 0.0


## Animation seulement.
func _process(delta: float) -> void:
	t += delta
	if visibility() > 0.0 or _was_near:
		queue_redraw()
	_was_near = visibility() > 0.0


## Part de visibilité (0 à 1) selon la distance au joueur ; un autel déjà vu reste discret mais visible.
func visibility() -> float:
	if main == null or main.player == null:
		return 0.0
	var d: float = main.player.position.distance_to(position)
	var v := 1.0 - smoothstep(CLEAR[kind], REVEAL[kind], d)
	if kind == "autel" and seen > 0.0:
		v = maxf(v, 0.55)
	return v


## Logique à pas fixe : découverte, puis ravivement en restant dans la zone.
func _physics_process(delta: float) -> void:
	if main == null or main.player == null:
		return
	var d: float = main.player.position.distance_to(position)
	if seen <= 0.0 and d < CLEAR[kind]:
		seen = 1.0
		Game.flags[flag() + "_vu"] = true
		if kind == "secret":
			main.hud.banner("Quelque chose brille sous la cendre…")
	if active:
		return
	if d < ZONE:
		progress += delta
		if progress >= HOLD[kind]:
			activate()
	else:
		progress = maxf(0.0, progress - delta * 2.0)


## Ravive l'autel : point d'arbre, greffe au sol, vague de vie.
func activate() -> void:
	if active:
		return
	active = true
	progress = HOLD[kind]
	Game.flags[flag()] = true
	Game.flags[flag() + "_vu"] = true
	Game.grant_points(int(data.get("points", 1)), kind, flag())
	var g := str(data.get("graft", ""))
	if g == "":
		g = Game.roll_graft(kind)
	if g != "" and not Game.has_graft(g):
		main.drop_graft(position + Vector2(0, 46), g)
	Sfx.play("coeur", position)
	main.revive(position, 160.0, Color("f2d06b"), 0.8)
	main.fx.ring(position, 20.0, 180.0, 0.8, Color("f2d06b"), 5.0)
	main.fx.pickup(position, "seve", 12, main.player.position)
	main.screen_fx.glow(Art.c("or"), 0.3, 1.0)
	main.request_autosave()
	queue_redraw()


func _draw() -> void:
	var v := visibility()
	if v <= 0.01:
		return
	if kind == "secret" and not active:
		_draw_secret(v)
		return
	var stone := Color(0.42, 0.4, 0.37, v)
	var stone_dark := Color(0.22, 0.21, 0.2, v)
	var glow := Color(0.95, 0.82, 0.42, v)
	# Dalle hexagonale et ombre.
	var slab := PackedVector2Array()
	for i in 6:
		slab.append(Vector2.from_angle(TAU * i / 6.0) * Vector2(52, 30))
	draw_colored_polygon(slab, stone_dark)
	draw_polyline(slab + PackedVector2Array([slab[0]]), Color(stone, v * 0.8), 2.0)
	# Deux pierres dressées, l'une penchée.
	draw_colored_polygon(PackedVector2Array([Vector2(-40, 0), Vector2(-34, -46), Vector2(-24, -50), Vector2(-22, 2)]), stone)
	draw_colored_polygon(PackedVector2Array([Vector2(24, 2), Vector2(30, -38), Vector2(40, -36), Vector2(42, 4)]), stone)
	# Vasque centrale.
	draw_set_transform(Vector2(0, -6), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 18.0, stone)
	draw_circle(Vector2.ZERO, 12.0, stone_dark)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if active:
		# Ravivé : une pousse dorée et une lueur douce.
		draw_circle(Vector2(0, -8), 26.0, Color(glow, v * (0.18 + 0.06 * sin(t * 2.0))))
		draw_line(Vector2(0, -6), Vector2(0, -30), Color(0.5, 0.85, 0.4, v), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -24), Vector2(-12, -32), Vector2(-2, -36)]), Color(0.55, 0.9, 0.45, v))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -28), Vector2(12, -38), Vector2(3, -40)]), Color(0.55, 0.9, 0.45, v))
		draw_circle(Vector2(0, -32), 4.0, glow)
	else:
		# Braise éteinte qui palpite, et cercle de cendre à fouler.
		draw_circle(Vector2(0, -6), 5.0 + sin(t * 3.0), Color(0.9, 0.5, 0.3, v * 0.6))
		draw_arc(Vector2.ZERO, ZONE, 0.0, TAU, 40, Color(0.75, 0.72, 0.65, v * 0.25), 2.0, true)
		var dist: float = main.player.position.distance_to(position)
		Prompt.draw(self, ZONE, progress / HOLD[kind], t, Prompt.nearness(dist, ZONE) * v, glow)


## Secret encore enfoui : quelques étincelles dans la cendre, qui grandissent quand on s'y tient.
func _draw_secret(v: float) -> void:
	var glow := Color(0.98, 0.88, 0.5, v)
	for i in 5:
		var a := TAU * i / 5.0 + t * 0.4
		var r := 10.0 + 8.0 * sin(t * 1.7 + i)
		draw_circle(Vector2.from_angle(a) * r, 1.6 + 0.8 * sin(t * 5.0 + i * 2.0), Color(glow, v * 0.7))
	draw_circle(Vector2.ZERO, 6.0, Color(glow, v * (0.25 + 0.15 * sin(t * 3.0))))
	var dist: float = main.player.position.distance_to(position)
	Prompt.draw(self, 30.0, progress / HOLD[kind], t, Prompt.nearness(dist, 30.0) * v, glow)
