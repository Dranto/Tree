## Haie d'épines (compétence « haie ») : un mur temporaire qui bloque et blesse les Flétris.
## Le mur est un segment épais posé en travers de la visée : les ennemis qui s'y enfoncent
## sont repoussés du côté d'où ils viennent, et ceux qui le touchent sont blessés par à-coups.
extends Node2D

var main
## Demi-longueur du mur et demi-épaisseur, en pixels du monde.
var half_length := 140.0
var half_thickness := 11.0
## Direction du mur (le long du segment) ; la normale pointe vers l'extérieur, loin du joueur.
var along := Vector2.RIGHT
var duration := 6.0
var life := 6.0
## Dégâts par à-coup (déjà multipliés par les statistiques du joueur) et intervalle entre deux.
var damage := 10.0
var tick := 0.5
var tick_clock := 0.0
var color := Color("8f5fc0")
var t := 0.0
var seed_offset := 0.0


func _ready() -> void:
	rotation = along.angle()
	seed_offset = randf() * 10.0


## Animation seulement (pousse et flétrissement du mur).
func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Logique à pas fixe : bloque les Flétris et les blesse.
func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	tick_clock += delta
	var hurt := tick_clock >= tick
	if hurt:
		tick_clock -= tick
	var normal := along.orthogonal()
	for e in main.enemies_near(position, half_length + half_thickness, true):
		if e.dead:
			continue
		var rel: Vector2 = e.position - position
		var u := rel.dot(along)
		if absf(u) > half_length + e.radius * 0.5:
			continue
		var v := rel.dot(normal)
		var reach: float = half_thickness + e.radius
		if absf(v) >= reach:
			continue
		# Repoussé du côté où se trouve déjà son centre : il ne traverse pas.
		var side := 1.0 if v >= 0.0 else -1.0
		e.position += normal * side * (reach - absf(v))
		if hurt:
			main.player_hit_enemy(e, damage)


func _draw() -> void:
	# Pousse en 0,25 s, flétrit pendant la dernière seconde.
	var grow := clampf((duration - life) / 0.25, 0.0, 1.0)
	var fade := clampf(life, 0.0, 1.0)
	var c := Color(color, 0.95 * fade)
	var dark := Color(color.darkened(0.45), 0.95 * fade)
	var hl := half_length * grow
	draw_rect(Rect2(-hl, -half_thickness * 0.55, hl * 2.0, half_thickness * 1.1), dark)
	# Tiges entrelacées et épines.
	var n := int(half_length / 9.0)
	for i in n:
		var x := -hl + (i + 0.5) * hl * 2.0 / n
		var wob := sin(i * 1.7 + seed_offset) * half_thickness * 0.5
		draw_line(Vector2(x - 6.0, -wob), Vector2(x + 6.0, wob), c, 3.0)
		var spike := half_thickness * (1.0 + 0.35 * sin(i * 2.3 + seed_offset))
		var dir := 1.0 if i % 2 == 0 else -1.0
		draw_line(Vector2(x, 0), Vector2(x + 3.0, dir * spike), c.lightened(0.15), 2.0)
	if grow >= 1.0 and fade > 0.5:
		for i in 4:
			var x := -hl * 0.75 + i * hl * 0.5
			draw_circle(Vector2(x, sin(i + seed_offset) * 4.0), 3.0, Color("d94a5a", fade))
