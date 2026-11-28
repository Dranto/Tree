## Vague de flétrissure du début d'un cycle (New Game+, jalon 14 W). Au toucher du fruit de la graine,
## la scène de jeu est rechargée (cycles.gd, tâche N) avec le drapeau Cycles.wave_pending() : le monde
## se montre d'abord tel que la fin l'a laissé (toute la terre ravivée, les régions apaisées, la teinte
## du cycle d'avant), puis un front part de la graine et le fane en passant : la terre reprend son état
## du nouveau cycle, les arbres perdent leurs feuilles, la terre apaisée redevient flétrie et la teinte du
## nouveau cycle (cycle_tint.gd) gagne le monde, avec un liseré d'encre et de la cendre sur le front.
## L'oasis de la graine reste verte. Pendant la vague, aucun Flétri n'apparaît ; à la fin, le drapeau
## tombe (Cycles.end_wave). Une partie quittée pendant la vague la rejoue au chargement.
##
## Hors vague : la teinte du cycle en cours est posée sur tout le monde dès l'entrée en jeu.
## Aucun texte, aucun écran : seulement le monde.
extends Node

const CycleTint = preload("res://scripts/cycle_tint.gd")
const Regions = preload("res://scripts/regions.gd")
const Flora = preload("res://scripts/flora.gd")

## Vitesse du front (px du monde par s) : il passe le bord du monde (≈ 4 100 px) en ≈ 6 s.
const SPEED := 700.0
## Le front ralentit au départ (comme une encre qui s'étale) : distance où il atteint sa pleine vitesse.
const EASE_IN := 600.0
## Largeur du fondu de la teinte derrière le front (px du monde).
const BAND := 520.0
## L'oasis de la graine (main.gd la peint sur 260 px) : la vague ne la fane pas.
const OASIS := 300.0
## Rayon où la vague s'arrête : au-delà des coins du monde.
const END_RADIUS := Regions.WORLD_HALF * 1.5
## Pas du front pour la carte de vie et le décor (px) : la carte n'est touchée que tous les STEP px.
const STEP := 60.0

var main
## Cycle dont la vague passe (0 : pas de vague).
var cycle := 0
var active := false
## Rayon du front (px du monde).
var radius := 0.0
var t := 0.0
var _done_r := 0.0
var _from := Vector4.ZERO
var _to := Vector4.ZERO
var _ash := Color()
## Purification de chaque région après la vague (l'état du nouveau cycle) ; régions déjà fanées.
var _purified_target := {}
var _region_done := {}
var _rng := RandomNumberGenerator.new()
## Le front attend la fin de l'écran de chargement (world_preload.gd).
var _waiting := false


func _ready() -> void:
	_rng.seed = 7331
	name = "CycleWave" # i18n: non
	var pending: int = Cycles.wave_pending()
	if pending >= 2:
		prepare(pending)
	else:
		CycleTint.apply(Cycles.current())
	if not Game.cycle_started.is_connected(_on_cycle_started):
		Game.cycle_started.connect(_on_cycle_started)


func _exit_tree() -> void:
	# Écran titre, autre partie : la teinte revient à celle de la première aventure.
	CycleTint.clear()
	if main != null and is_instance_valid(main) and main.get("ground") != null and active:
		main.ground.wither_target = PackedByteArray()


## Signal du fruit (après le rechargement) : le front part dès la fin de l'écran de chargement.
func _on_cycle_started(n: int) -> void:
	if cycle != n and n >= 2:
		prepare(n)


## Monde montré « encore vert » avant le passage du front du cycle n.
func prepare(n: int) -> void:
	cycle = n
	_from = CycleTint.grade(n - 1)
	_to = CycleTint.grade(n)
	_ash = CycleTint.ash_color(n)
	radius = 0.0
	_done_r = 0.0
	t = 0.0
	_region_done = {}
	_purified_target = {}
	CycleTint.set_state(_from, _to, Vector2.ZERO, 0.0, BAND, _ash)
	if main == null or not is_instance_valid(main) or main.get("ground") == null:
		return
	var g = main.ground
	if g.wither_target.is_empty():
		g.wither_begin(g.data.duplicate())
	for id in Regions.ids():
		_purified_target[id] = g.purified_of(id)
		g.set_purified(id, 1.0)
	main.spawn_paused = true
	# Le front part quand le monde est prêt (signal Game.cycle_started, ou ici à l'image suivante).
	_waiting = true


## Le front part de la graine.
func start() -> void:
	if cycle < 2 or active:
		return
	active = true
	_waiting = false
	t = 0.0
	if main != null and is_instance_valid(main):
		if main.get("screen_fx") != null:
			main.screen_fx.glow(_ash.darkened(0.4), 0.45, 2.5)
	Sfx.play("cycle_fane")


func _process(delta: float) -> void:
	if _waiting and not active:
		# Vague rejouée au chargement (pas de signal) : elle part une fois l'écran de chargement fini.
		if main == null or not is_instance_valid(main) or main.get("world_preload") == null or not is_instance_valid(main.world_preload) or main.world_preload.done:
			start()
		return
	if not active:
		return
	step(delta)


## Avance la vague de « delta » secondes (tests, captures : step(1.5)).
func step(delta: float) -> void:
	if not active:
		return
	t += delta
	# Départ lent puis pleine vitesse.
	var lin := t * SPEED
	radius = lin if lin >= EASE_IN else EASE_IN * pow(lin / EASE_IN, 1.6)
	CycleTint.set_state(_from, _to, Vector2.ZERO, radius, BAND, _ash)
	_advance()
	_particles()
	if radius >= END_RADIUS + BAND:
		finish()


## Le front fane ce qu'il a passé : terre, arbres, régions.
func _advance() -> void:
	if main == null or not is_instance_valid(main) or main.get("ground") == null:
		return
	var r := radius - BAND * 0.5
	if r < _done_r + STEP and radius < END_RADIUS:
		return
	var g = main.ground
	var lo := maxf(_done_r, OASIS)
	if r > lo:
		g.wither_ring(Vector2.ZERO, lo, r)
		_wither_trees(lo, r)
	_done_r = maxf(_done_r, r)
	for id in Regions.ids():
		if _region_done.has(id):
			continue
		# Une région s'éteint quand le front a passé son centre.
		if Regions.center(id).length() <= r:
			_region_done[id] = true
			g.set_purified(id, float(_purified_target.get(id, 0.0)))


## Les arbres de l'anneau dont la terre n'est plus vivante perdent leurs feuilles.
func _wither_trees(r_in: float, r_out: float) -> void:
	var flora = main.get("flora")
	if flora == null:
		return
	var i2 := r_in * r_in
	var o2 := r_out * r_out
	for tr in flora.trees:
		if not is_instance_valid(tr) or not tr.alive:
			continue
		var d2: float = tr.position.length_squared()
		if d2 <= i2 or d2 > o2:
			continue
		if main.ground.life_at(tr.position) <= Flora.ALIVE:
			tr.alive = false
			tr.leaf = 0.0
			tr.set_process(false)
			tr.queue_redraw()


## Cendre et feuilles mortes sur le front, là où la caméra le voit.
func _particles() -> void:
	if Settings.reduce_effects or main == null or not is_instance_valid(main) or main.get("fx") == null or main.get("player") == null:
		return
	var view_c: Vector2 = main.player.position
	var dist := view_c.length()
	# Arc du front visible à l'écran (≈ 1 100 px autour du héros).
	if absf(dist - radius) > 1100.0 or radius < 40.0:
		return
	var half := PI if radius < 1100.0 else asin(clampf(1100.0 / radius, 0.0, 1.0))
	var base := view_c.angle() if dist > 1.0 else 0.0
	for i in 4:
		var a := base + _rng.randf_range(-half, half)
		var dir := Vector2.from_angle(a)
		var p := dir * (radius - _rng.randf_range(0.0, BAND * 0.4))
		var grey := _ash.darkened(_rng.randf_range(0.1, 0.45))
		if i % 2 == 0:
			main.fx.glow_mote(p, dir * _rng.randf_range(20.0, 60.0) + Vector2(0.0, -40.0), _rng.randf_range(1.2, 2.0), _rng.randf_range(2.2, 3.6), Color(grey, 0.85))
		else:
			main.fx.petal(p, dir * _rng.randf_range(40.0, 110.0) + Vector2(0.0, 30.0), _rng.randf_range(1.6, 2.4), _rng.randf_range(5.0, 8.0), Color(grey.lerp(Color(0.42, 0.33, 0.2), 0.5), 0.9))


## La vague est passée : monde du nouveau cycle partout, Flétris de retour, drapeau levé.
func finish() -> void:
	active = false
	_waiting = false
	radius = CycleTint.EVERYWHERE
	CycleTint.apply(cycle)
	if main != null and is_instance_valid(main) and main.get("ground") != null:
		var g = main.ground
		g.wither_end()
		_wither_trees(OASIS, INF)
		for id in Regions.ids():
			g.set_purified(id, float(_purified_target.get(id, g.purified_of(id))))
		if not main.in_boss_fight():
			main.spawn_paused = false
	Cycles.end_wave()
	if main != null and is_instance_valid(main) and main.has_method("request_autosave"):
		main.request_autosave()
