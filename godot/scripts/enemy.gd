## Les Flétris : créatures de cendre qui traquent le Porte-Graine.
## 0 = Flétri (standard), 1 = Cendreux (rapide et fragile), 2 = Colosse (lent et massif).
extends Node2D

const KINDS := [
	{"hp": 30.0, "speed": 85.0, "damage": 10.0, "radius": 14.0, "xp": 3.0, "color": "6d6470"},
	{"hp": 14.0, "speed": 150.0, "damage": 6.0, "radius": 10.0, "xp": 2.0, "color": "8a7a6a"},
	{"hp": 130.0, "speed": 52.0, "damage": 22.0, "radius": 25.0, "xp": 12.0, "color": "4e4656"},
]

## Rayon du plus gros Flétri (Colosse) : marge des recherches dans la grille spatiale.
const MAX_RADIUS := 25.0

var main
## Rang dans main.enemies au dernier pas de jeu (sert à ne traiter chaque paire qu'une fois).
var index := -1
var kind := 0
var hp := 30.0
var max_hp := 30.0
var speed := 85.0
var damage := 10.0
var radius := 14.0
var xp_value := 3.0
var color := Color.GRAY
var poison_dps := 0.0
var poison_time := 0.0
var hit_flash := 0.0
var dead := false
var t := 0.0


func setup(k: int, power: float) -> void:
	kind = k
	var d: Dictionary = KINDS[k]
	max_hp = d["hp"] * power
	hp = max_hp
	speed = d["speed"] * (1.0 + 0.04 * (power - 1.0))
	damage = d["damage"] * (1.0 + 0.5 * (power - 1.0))
	radius = d["radius"]
	xp_value = d["xp"] * (0.8 + 0.2 * power)
	color = Color(d["color"])
	t = randf() * 10.0


## Animation seulement (ondulation de la silhouette) : suit la fréquence d'affichage.
func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Logique à pas fixe : poursuite, contact avec le joueur, poison.
func _physics_process(delta: float) -> void:
	if dead:
		return
	hit_flash -= delta
	var p = main.player
	var to: Vector2 = p.position - position
	var dist := to.length()
	var sp := speed
	# La terre vivante ralentit les Flétris.
	if main.ground.life_at(position) > 0.45:
		sp *= 0.6
	if dist > 1.0:
		position += to / dist * sp * delta
	if dist < radius + p.radius:
		p.take_hit(damage, self)
	if poison_time > 0.0:
		poison_time -= delta
		take_damage(poison_dps * delta, false, true)


func apply_poison(dps: float, duration: float) -> void:
	poison_dps = maxf(poison_dps if poison_time > 0.0 else 0.0, dps)
	poison_time = maxf(poison_time, duration)


func take_damage(amount: float, crit: bool, dot := false) -> void:
	if dead:
		return
	hp -= amount
	if not dot:
		hit_flash = 0.08
		if crit:
			main.fx.text(position + Vector2(0, -radius - 10), str(roundi(amount)), Color("f2d06b"), 18, 0.6)
	if hp <= 0.0:
		dead = true
		main.on_enemy_killed(self)
		queue_free()


func _draw() -> void:
	var c := color
	if hit_flash > 0.0:
		c = Color.WHITE
	elif poison_time > 0.0:
		c = c.lerp(Color("8f5fc0"), 0.4)
	# Silhouette irrégulière de cendre
	var pts := PackedVector2Array()
	var n := 14
	for i in n:
		var a := TAU * i / n
		var wobble := 1.0 + 0.12 * sin(a * 3.0 + t * 4.0) + 0.08 * sin(a * 5.0 - t * 2.0)
		pts.append(Vector2.from_angle(a) * radius * wobble)
	draw_colored_polygon(pts, c)
	# Braises (yeux) tournées vers le joueur
	var dir: Vector2 = (main.player.position - position).normalized()
	var side := dir.orthogonal() * radius * 0.3
	var eye := dir * radius * 0.45
	draw_circle(eye + side, radius * 0.13, Color("ff9a4a"))
	draw_circle(eye - side, radius * 0.13, Color("ff9a4a"))
	if hp < max_hp:
		var w := radius * 2.0
		draw_rect(Rect2(-radius, -radius - 9, w, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-radius, -radius - 9, w * clampf(hp / max_hp, 0.0, 1.0), 3), Color("e0675e"))
