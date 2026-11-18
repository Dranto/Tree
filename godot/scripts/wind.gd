## Rafales de vent d'une région (« wind » dans data/regions/<id>.json : les hauts plateaux de Vent).
## Posé par le décor de la région (decor_plateau.gd), comme enfant de flora : il est dessiné sous les
## personnages, au-dessus du sol.
##
## Cycle : calme (de calm[0] à calm[1] secondes), annonce (« warn » : les traînées se lèvent et
## s'orientent, la rafale arrive), rafale (« gust » secondes, force qui monte vite puis retombe).
## Pendant une rafale, dans la région :
##   - le joueur est poussé dans le sens du vent (player_push px/s au plus fort ; pas pendant
##     l'esquive, ni pendant un combat de boss) ;
##   - les projectiles en vol (les siens et ceux des Flétris) sont déviés (projectile_push px/s²).
## Tout est multiplié par Settings.wind (options : de 0, coupées, à 1) et par l'appartenance du joueur
## à la région (Regions.weight). Le vent ne pousse pas les Flétris.
##
## Dessin : quelques dizaines de traînées claires (élément vent, motif « rafales ») qui filent
## dans le sens du vent autour de la caméra, en un seul appel de rendu ; rien hors de la région.
extends Node2D

const Regions = preload("res://scripts/regions.gd")
const DrawBatch = preload("res://scripts/draw_batch.gd")

## Le vent de la région où il souffle (une seule région à vent pour l'instant) : le boss et les
## tests le lisent. null sans région à vent.
static var active = null

var main
var region := ""
var cfg: Dictionary = {}
## "calme", "annonce" ou "rafale", et le temps restant dans l'état.
var state := "calme"
var timer := 3.0
## Force de la rafale en cours (0 → 1), sans les réglages ni la position du joueur.
var strength := 0.0
## Direction du vent dominant, et celle de la rafale en cours (le dominant, un peu tourné).
var base_dir := Vector2.RIGHT
var dir := Vector2.RIGHT
## Appartenance du joueur à la région (0 dehors, 1 dedans).
var here := 0.0
var t := 0.0
var rng := RandomNumberGenerator.new()
## Traînées : [décalage le long du vent, décalage en travers, longueur, vitesse, phase].
var _streaks: Array = []
var _drawn := false
static var _batch = DrawBatch.new()


func _ready() -> void:
	active = self
	rng.seed = hash(region + "_vent")
	base_dir = Vector2.from_angle(Regions.angle_of(region) + float(cfg.get("angle", 0.0)))
	dir = base_dir
	timer = _calm()
	for i in int(cfg.get("streaks", 26)):
		_streaks.append([rng.randf(), rng.randf(), rng.randf_range(50.0, 130.0), rng.randf_range(0.8, 1.25), rng.randf() * TAU])


func _exit_tree() -> void:
	if active == self:
		active = null


func _calm() -> float:
	var c: Array = cfg.get("calm", [5.0, 9.0])
	return rng.randf_range(float(c[0]), float(c[1]))


## Avancée de l'annonce (0 → 1), 0 hors annonce.
func warn_ratio() -> float:
	if state != "annonce":
		return 0.0
	return 1.0 - clampf(timer / maxf(0.01, float(cfg.get("warn", 1.2))), 0.0, 1.0)


## Force de la rafale : monte en un quart de sa durée, puis retombe doucement.
func _envelope() -> float:
	if state != "rafale":
		return 0.0
	var k := 1.0 - clampf(timer / maxf(0.01, float(cfg.get("gust", 2.6))), 0.0, 1.0)
	return Anim.ease_out(k / 0.25) if k < 0.25 else 1.0 - Anim.ease_in((k - 0.25) / 0.75)


## Force du vent en pos (px/s pour le joueur au plus fort), réglages compris.
func push_at(pos: Vector2) -> Vector2:
	return dir * float(cfg.get("player_push", 70.0)) * strength * Settings.wind * Regions.weight(pos, region)


## Accélération des projectiles en pos (px/s²), réglages compris (plumes du boss, wind.gd ne les voit pas).
func accel_at(pos: Vector2) -> Vector2:
	return dir * float(cfg.get("projectile_push", 110.0)) * strength * Settings.wind * Regions.weight(pos, region)


## Logique à pas fixe : cycle des rafales, poussée du joueur et des projectiles.
func _physics_process(delta: float) -> void:
	t += delta
	timer -= delta
	if timer <= 0.0:
		match state:
			"calme":
				state = "annonce"
				timer = float(cfg.get("warn", 1.2))
				dir = base_dir.rotated(rng.randf_range(-0.35, 0.35))
			"annonce":
				state = "rafale"
				timer = float(cfg.get("gust", 2.6))
			_:
				state = "calme"
				timer = _calm()
	strength = _envelope()
	if main == null or main.player == null:
		return
	var p = main.player
	here = Regions.weight(p.position, region)
	var f: float = strength * here * Settings.wind
	if f <= 0.001:
		return
	# Dans l'arène, le boss a son propre vent : la rafale ne pousse pas le joueur contre le mur.
	if p.dash_time <= 0.0 and not main.in_boss_fight():
		p.position += dir * float(cfg.get("player_push", 70.0)) * f * delta
	var accel: Vector2 = dir * float(cfg.get("projectile_push", 110.0)) * f * delta
	for n in main.projectiles_layer.get_children():
		if "vel" in n:
			n.vel += accel


func _process(_delta: float) -> void:
	# Redessiné seulement dans la région (et une fois en sortant, pour effacer).
	if here > 0.01 or _drawn:
		queue_redraw()


func _draw() -> void:
	_drawn = here > 0.01
	if not _drawn:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var view := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	var center := view.get_center()
	var span := view.size.length() + 200.0
	var across := dir.orthogonal()
	var warn := warn_ratio()
	# Au calme, quelques traînées à peine visibles ; elles se lèvent pendant l'annonce.
	var calm_alpha := 0.07 if not Settings.reduce_effects else 0.0
	var alpha := (calm_alpha + 0.2 * warn + 0.45 * strength) * here
	if alpha <= 0.005:
		return
	var speed := 140.0 + 120.0 * warn + 420.0 * strength
	var col := Art.ec("vent", "clair")
	var shown := _streaks.size() if not Settings.reduce_effects else _streaks.size() / 3
	for i in shown:
		var s: Array = _streaks[i]
		var u := fposmod(float(s[0]) * span + t * speed * float(s[3]), span) - span / 2.0
		var v := (float(s[1]) - 0.5) * span
		var p := center + dir * u + across * v
		var len := float(s[2]) * (0.6 + 0.5 * warn + 0.7 * strength)
		# Fondu aux deux bouts du parcours : les traînées naissent et s'effacent sans saut.
		var edge := clampf(minf(u + span / 2.0, span / 2.0 - u) / 160.0, 0.0, 1.0)
		var a := alpha * edge * (0.55 + 0.45 * sin(t * 1.7 + float(s[4])))
		if a <= 0.01:
			continue
		var pts := PackedVector2Array()
		for j in 5:
			var k := j / 4.0
			pts.append(p + dir * len * (k - 0.5) + across * sin(k * PI + t * 2.0 + float(s[4])) * 3.0)
		_batch.draw_polyline(pts, Color(col, a), Art.TRAIT_FIN)
		# Une boucle au bout d'une traînée sur trois : le motif « rafales » de la charte.
		if i % 3 == 0:
			var end: Vector2 = pts[4]
			var r := len * 0.12
			var a0 := dir.angle() - PI / 2.0
			_batch.draw_arc(end - across * r, r, a0, a0 + PI * 1.5, 8, Color(col, a), Art.TRAIT_FIN)
	_batch.flush(self)
