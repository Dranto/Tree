## Flaques de vase toxique du marais de Spore (répandues par le Traîne-vase, enemy_behaviors/puddler.gd).
## Un seul nœud par scène de jeu, au sol sous les personnages (Puddles.of(main)), qui tient et
## dessine toutes les flaques : elles ne coûtent qu'un nœud et un dessin, redessiné une vingtaine de
## fois par seconde tant qu'il y en a.
##
## Une flaque blesse le Porte-Graine qui s'y tient : un coup toutes les TICK secondes (l'esquive et
## l'invulnérabilité après un coup comptent). Elle ne blesse pas les Flétris.
## Charte (§ 6) : une zone qui blesse porte le rouge du danger en contour, sur la vase violette du poison.
extends Node2D

const MAX := 28
const TICK := 0.5
## Montée et disparition d'une flaque (secondes).
const GROW := 0.25
const FADE := 0.9
const REDRAW := 1.0 / 20.0

var main
## {pos, r, life, age, dps, owner (identifiant de l'ennemi), seed}
var puddles: Array = []
var _tick := 0.0
var _clock := 0.0
var t := 0.0


## Le calque des flaques de cette scène de jeu, créé au premier besoin sous les personnages.
static func of(m) -> Node2D:
	if m.has_meta("flaques") and is_instance_valid(m.get_meta("flaques")):
		return m.get_meta("flaques")
	var n = load("res://scripts/marsh_puddles.gd").new()
	n.main = m
	m.set_meta("flaques", n)
	var under = m.get("actors_layer")
	if under != null and under.get_parent() == m:
		m.add_child(n)
		m.move_child(n, under.get_index())
	else:
		m.add_child(n)
	return n


func add(owner_e, pos: Vector2, r: float, life: float, dps: float, per_owner := 4) -> void:
	var id: int = owner_e.get_instance_id() if owner_e != null else 0
	var mine := puddles.filter(func(p): return p["owner"] == id)
	if mine.size() >= per_owner:
		puddles.erase(mine[0])
	if puddles.size() >= MAX:
		puddles.pop_front()
	puddles.append({"pos": pos, "r": r, "life": life, "age": 0.0, "dps": dps, "owner": id, "seed": randi() % 997})
	queue_redraw()


## La flaque blesse-t-elle en ce point ? (robots, tests)
func hurts_at(pos: Vector2, margin := 0.0) -> bool:
	for p in puddles:
		if _active(p) and pos.distance_to(p["pos"]) < p["r"] + margin:
			return true
	return false


func _active(p: Dictionary) -> bool:
	return p["age"] >= GROW and p["life"] - p["age"] > FADE * 0.5


func _physics_process(delta: float) -> void:
	if puddles.is_empty():
		return
	for p in puddles:
		p["age"] += delta
	puddles = puddles.filter(func(p): return p["age"] < p["life"])
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	var pl = main.player
	if pl == null or pl.hp <= 0.0:
		return
	var worst := 0.0
	for p in puddles:
		if _active(p) and pl.position.distance_to(p["pos"]) < p["r"] + pl.radius * 0.3:
			worst = maxf(worst, p["dps"])
	if worst > 0.0:
		pl.take_hit(worst * TICK, null)


func _process(delta: float) -> void:
	t += delta
	if puddles.is_empty():
		if _clock >= 0.0:
			_clock = -1.0
			queue_redraw()
		return
	_clock -= delta
	if _clock <= 0.0:
		_clock = REDRAW
		queue_redraw()


## Contour bosselé d'une flaque (fixe pour une flaque donnée).
static func blob(pos: Vector2, r: float, sd: int, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var w := 1.0 + 0.09 * sin(a * 3.0 + sd) + 0.05 * sin(a * 5.0 + sd * 1.7)
		pts.append(pos + Vector2(cos(a), sin(a) * 0.86) * r * w)
	return pts


func _draw() -> void:
	var mud := Art.ec("poison", "sombre").lerp(Art.c("sol_mort"), 0.3)
	var rim := Art.ec("poison")
	var bubble := Art.ec("poison", "clair")
	var danger := Art.c("danger")
	for p in puddles:
		var age: float = p["age"]
		var left: float = p["life"] - age
		var k := Anim.ease_out(clampf(age / GROW, 0.0, 1.0)) * clampf(left / FADE, 0.0, 1.0)
		if k <= 0.01:
			continue
		var r: float = p["r"] * (0.4 + 0.6 * k)
		var pos: Vector2 = p["pos"]
		var sd: int = p["seed"]
		var shape := blob(pos, r, sd)
		draw_colored_polygon(shape, Color(mud.darkened(0.15), 0.72 * k))
		draw_colored_polygon(blob(pos + Vector2(-0.12, -0.14) * r, r * 0.7, sd + 3, 14), Color(rim.darkened(0.45), 0.35 * k))
		# Reflet clair en haut à gauche (lumière de la charte).
		draw_colored_polygon(Art.ellipse(pos + Vector2(-0.35, -0.38) * r, r * 0.22, r * 0.09, 10), Color(bubble, 0.35 * k))
		var closed := shape.duplicate()
		closed.append(shape[0])
		draw_polyline(closed, Color(danger, 0.6 * k), Art.TRAIT_FIN, true)
		# Bulles qui crèvent à la surface.
		for i in 3:
			var u := fposmod(t * 0.9 + i / 3.0 + sd * 0.01, 1.0)
			var q := pos + Vector2(cos(sd + i * 2.1), sin(sd + i * 2.1) * 0.8) * r * 0.5
			draw_arc(q, 1.5 + 3.5 * u, 0.0, TAU, 10, Color(bubble, (1.0 - u) * 0.8 * k), Art.TRAIT_FIN, true)
