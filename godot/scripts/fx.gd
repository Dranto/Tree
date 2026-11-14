## Effets visuels éphémères (ondes, textes flottants) et nuages de spores.
extends Node2D

var main
var rings: Array = []
var texts: Array = []
var clouds: Array = []
var font: Font
## Vrai si la dernière image dessinait quelque chose (pour l'effacer une fois tout fini).
var drawn_something := false


func _ready() -> void:
	font = ThemeDB.fallback_font


func ring(pos: Vector2, r0: float, r1: float, dur: float, color: Color, width := 4.0) -> void:
	rings.append({"pos": pos, "r0": r0, "r1": r1, "t": 0.0, "dur": dur, "color": color, "width": width})


func text(pos: Vector2, s: String, color: Color, size := 18, dur := 1.0) -> void:
	texts.append({"pos": pos, "s": s, "t": 0.0, "dur": dur, "color": color, "size": size})


func cloud(pos: Vector2, radius: float, dur: float, dps: float) -> void:
	clouds.append({"pos": pos, "radius": radius, "t": 0.0, "dur": dur, "dps": dps})


## Ondes et textes : purement visuels, ils suivent la fréquence d'affichage.
func _process(delta: float) -> void:
	for list in [rings, texts]:
		for e in list:
			e["t"] += delta
	rings = rings.filter(func(e): return e["t"] < e["dur"])
	texts = texts.filter(func(e): return e["t"] < e["dur"])
	# Redessiné tant qu'il y a un effet, puis une dernière fois pour effacer le dernier.
	var busy := not (rings.is_empty() and texts.is_empty() and clouds.is_empty())
	if busy or drawn_something:
		queue_redraw()
	drawn_something = busy


## Nuages de spores : ils infligent des dégâts, donc avancent à pas fixe (grille spatiale).
func _physics_process(delta: float) -> void:
	for c in clouds:
		c["t"] += delta
	clouds = clouds.filter(func(e): return e["t"] < e["dur"])
	for c in clouds:
		for e in main.enemies_near(c["pos"], c["radius"]):
			if not e.dead:
				e.take_damage(c["dps"] * delta, false, true)
				e.apply_poison(c["dps"] * 0.3, 1.0)


func _draw() -> void:
	for c in clouds:
		var k: float = c["t"] / c["dur"]
		var a := 0.22 * (1.0 - k * k)
		draw_circle(c["pos"], c["radius"], Color(0.55, 0.35, 0.75, a))
		draw_arc(c["pos"], c["radius"], 0.0, TAU, 48, Color(0.7, 0.5, 0.9, a * 2.0), 2.0)
	for e in rings:
		var k: float = e["t"] / e["dur"]
		var col: Color = e["color"]
		col.a *= 1.0 - k
		draw_arc(e["pos"], lerpf(e["r0"], e["r1"], k), 0.0, TAU, 56, col, e["width"])
	for e in texts:
		var k: float = e["t"] / e["dur"]
		var col: Color = e["color"]
		col.a = 1.0 - k * k
		var p: Vector2 = e["pos"] + Vector2(-200, -30.0 * k)
		draw_string(font, p, e["s"], HORIZONTAL_ALIGNMENT_CENTER, 400, e["size"], col)
