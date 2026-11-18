## Boss minimal de la région factice des tests (tests/regions/essai.json) : un rond qui annonce
## une onde autour de lui toutes les deux secondes, et deux phases. Montre le moins qu'un boss
## doit écrire au-dessus de BossBase (scripts/boss_base.gd).
extends BossBase

const WAVE_EVERY := 2.0
const WAVE_RADIUS := 200.0
const WAVE_WARN := 0.6

var _next := WAVE_EVERY
## Temps restant avant que l'onde annoncée frappe (< 0 : aucune annonce).
var _warn := -1.0


func _setup() -> void:
	body_radius = 50.0
	base_hp = 300.0
	hp_per_level = 50.0
	phase_limits = [0.5]


func _fight_step(delta: float) -> void:
	var ph := phase_for(hp / max_hp)
	if ph != phase:
		phase = ph
		transition = 0.5
		return
	if _warn >= 0.0:
		_warn -= delta
		if _warn < 0.0 and main.player.position.distance_to(anchor) < WAVE_RADIUS:
			main.player.take_hit(10.0 * damage_scale, self)
		return
	_next -= delta * cadence()
	if _next <= 0.0:
		_next = WAVE_EVERY / phase
		_warn = WAVE_WARN


func _clear_attacks() -> void:
	_warn = -1.0


func danger_time(pos: Vector2, margin := 26.0) -> float:
	if _warn >= 0.0 and pos.distance_to(anchor) < WAVE_RADIUS + margin:
		return _warn
	return super.danger_time(pos, margin)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, _color(Art.ec("vent", "sombre")))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, _color(Art.ec("vent")), Art.TRAIT, true)


func draw_marks(c: CanvasItem) -> void:
	if _warn >= 0.0:
		Art.telegraph(c, {"type": "cercle", "centre": anchor, "rayon": WAVE_RADIUS}, 1.0 - _warn / WAVE_WARN, -1.0, t)
