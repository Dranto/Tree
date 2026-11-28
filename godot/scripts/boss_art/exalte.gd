## Dessin commun de la phase exaltée des boss de région (NG+, jalon 14) : une couronne de flammes
## d'encre bordées de braise autour du corps, qui bat sur les temps de la musique du boss
## (BossBase.loop_pulse), et des cendres qui montent. Encre plus marquée, braise = ennemi : la même
## grammaire que les Flétris (charte), lisible en daltonisme par la forme (flammes noires) autant
## que par la couleur. Dessiné en direct, au-dessus de la teinte du boss (quelques polygones).
extends RefCounted

const Ink = preload("res://scripts/creature_art/ink.gd")

const TONGUES := 9


## at : centre du corps (coordonnées du canevas) ; r : rayon du corps ; k : apparition (0 → 1) ;
## pulse : battement (1 sur le temps) ; t : temps.
static func aura(c: CanvasItem, at: Vector2, r: float, k: float, pulse: float, t: float) -> void:
	if k <= 0.0:
		return
	var braise := Art.bc("braise")
	var encre := Ink.encre()
	var beat := 1.0 + 0.12 * pulse
	Ink.halo(c, at, r * 1.9 * beat * k, braise, 0.8 + 0.8 * pulse)
	# Flammes d'encre : des langues qui sortent du bord du corps et ondulent, plus hautes au-dessus.
	for i in TONGUES:
		var a := -PI * 0.5 + (i - (TONGUES - 1) / 2.0) * (PI * 1.5 / TONGUES)
		var up := 1.0 - absf(a + PI * 0.5) / PI
		var len := r * (0.55 + 0.6 * up) * beat * k * (0.85 + 0.15 * sin(t * 5.0 + i * 1.9))
		var base := at + Vector2.from_angle(a) * r * 0.78
		var sway := 0.35 * sin(t * 3.1 + i * 2.3)
		var dir := Vector2.from_angle(lerpf(a, -PI * 0.5, 0.55) + sway * 0.4)
		var tip := base + dir * len
		var n := dir.orthogonal() * r * 0.13 * k
		var mid := base.lerp(tip, 0.5) + n * sway
		var flame := PackedVector2Array([base - n, mid - n * 0.5, tip, mid + n * 0.5, base + n])
		c.draw_colored_polygon(flame, Color(encre, 0.85 * k))
		c.draw_polyline(PackedVector2Array([base - n, mid - n * 0.5, tip, mid + n * 0.5, base + n]), Color(braise, (0.55 + 0.45 * pulse) * k), 1.6, true)
	# Cendres qui montent, braise au cœur.
	for i in 10:
		var u := fposmod(t * 0.45 + i / 10.0, 1.0)
		var x := sin(i * 2.7) * r * 0.9 + sin(t * 2.0 + i) * 6.0
		var q := at + Vector2(x, -r * 0.4 - u * r * 1.8)
		var col := braise.lerp(encre, u)
		c.draw_circle(q, (2.6 - 1.6 * u) * k, Color(col, (1.0 - u) * k))
