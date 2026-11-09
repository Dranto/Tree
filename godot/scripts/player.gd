## Le Porte-Graine : déplacement, tir de graines, esquive et compétences actives.
extends Node2D

const DASH_SPEED := 950.0
const DASH_TIME := 0.16
const SKILL_CD := {"nova": 6.0, "cloud": 9.0, "bloom": 18.0}

var main
var radius := 14.0
var hp := 100.0
var fire_cd := 0.0
var dash_cd := 0.0
var dash_time := 0.0
var dash_dir := Vector2.RIGHT
var invuln := 0.0
var still_time := 0.0
var immortal_cd := 0.0
var hurt_flash := 0.0
var aim := Vector2.RIGHT
var aim_point := Vector2.ZERO
var skill_cd: Dictionary = SKILL_CD
var cds := {"nova": 0.0, "cloud": 0.0, "bloom": 0.0}
var t := 0.0


func _ready() -> void:
	hp = Game.stats["max_hp"]
	Game.stats_changed.connect(func(): hp = minf(hp, Game.stats["max_hp"]))


func _process(delta: float) -> void:
	var s: Dictionary = Game.stats
	t += delta
	fire_cd -= delta
	dash_cd -= delta
	invuln -= delta
	immortal_cd -= delta
	hurt_flash -= delta
	for k in cds:
		cds[k] = maxf(0.0, cds[k] - delta)

	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	aim_point = get_global_mouse_position()
	var want_attack := Input.is_action_pressed("attack")
	var want_dash := Input.is_action_just_pressed("dash")
	var want := {
		"nova": Input.is_action_just_pressed("skill_nova"),
		"cloud": Input.is_action_just_pressed("skill_cloud"),
		"bloom": Input.is_action_just_pressed("skill_bloom"),
	}
	if main.autotest:
		var bot: Dictionary = main.bot_input(self)
		mv = bot["move"]
		aim_point = bot["aim"]
		want_attack = true
		want_dash = bot["dash"]
		for k in want:
			want[k] = true
	var to_aim := aim_point - global_position
	if to_aim.length() > 1.0:
		aim = to_aim.normalized()

	if want_dash and dash_cd <= 0.0:
		dash_dir = mv.normalized() if mv.length() > 0.1 else aim
		dash_time = DASH_TIME
		dash_cd = s["dash_cd"]
		invuln = maxf(invuln, DASH_TIME + 0.08)

	if dash_time > 0.0:
		dash_time -= delta
		position += dash_dir * DASH_SPEED * delta
	else:
		position += mv * s["move_speed"] * delta
	var h: float = main.world_half
	position = position.clamp(Vector2(-h, -h), Vector2(h, h))

	still_time = still_time + delta if mv.length() < 0.1 else 0.0

	# La terre vivante soigne : régénération triplée sur l'herbe.
	var regen: float = s["regen"]
	if main.ground.life_at(position) > 0.45:
		regen *= 3.0
	heal(regen * delta)

	if want_attack and fire_cd <= 0.0:
		_shoot(s)
		fire_cd = 1.0 / s["fire_rate"]

	if Game.has_key("nova") and want["nova"] and cds["nova"] <= 0.0:
		_cast_nova(s)
	if Game.has_key("cloud") and want["cloud"] and cds["cloud"] <= 0.0:
		_cast_cloud(s)
	if Game.has_key("bloom") and want["bloom"] and cds["bloom"] <= 0.0:
		_cast_bloom(s)

	queue_redraw()


func current_damage() -> float:
	var d: float = Game.stats["damage"]
	if Game.has_key("enracine") and still_time > 0.5:
		d *= 1.4
	return d


func _shoot(s: Dictionary) -> void:
	var n: int = s["projectiles"]
	var spread := 0.14
	var big := Game.has_key("lumiere_lente")
	for i in n:
		var a := aim.angle() + (i - (n - 1) / 2.0) * spread
		var dir := Vector2.from_angle(a)
		main.spawn_projectile(position + dir * 18.0, dir * 640.0, current_damage(), s["pierce"], big)


func _cast_nova(s: Dictionary) -> void:
	cds["nova"] = SKILL_CD["nova"]
	var r: float = 170.0 * s["area"]
	main.fx.ring(position, 20.0, r, 0.4, Color("e0675e"), 8.0)
	main.damage_area(position, r, current_damage() * 2.5, 70.0)


func _cast_cloud(s: Dictionary) -> void:
	cds["cloud"] = SKILL_CD["cloud"]
	var target := aim_point
	var off := target - position
	if off.length() > 420.0:
		target = position + off.normalized() * 420.0
	main.fx.cloud(target, 120.0 * s["area"], 5.0, current_damage() * (1.2 + s["poison"]))


func _cast_bloom(s: Dictionary) -> void:
	cds["bloom"] = SKILL_CD["bloom"]
	heal(s["max_hp"] * 0.35)
	var r: float = 150.0 * s["area"]
	main.fx.ring(position, 20.0, r, 0.6, Color("7fd36b"), 8.0)
	main.damage_area(position, r, current_damage() * 0.5, 110.0)
	main.ground.paint(position, r, 0.8)
	main.flora.spawn_patch(position, r * 0.8, 10, Color("7fd36b"))


func heal(v: float) -> void:
	hp = minf(Game.stats["max_hp"], hp + v)


func take_hit(amount: float, source) -> void:
	if invuln > 0.0 or hp <= 0.0:
		return
	var s: Dictionary = Game.stats
	var armor: float = s["armor"]
	if Game.has_key("enracine") and still_time > 0.5:
		armor = minf(0.85, armor + 0.2)
	hp -= amount * (1.0 - armor)
	hurt_flash = 0.15
	invuln = 0.35
	if s["thorns"] > 0.0 and is_instance_valid(source) and not source.dead:
		source.take_damage(s["thorns"], false)
	if hp <= 0.0:
		if Game.has_key("immortel") and immortal_cd <= 0.0:
			hp = 1.0
			invuln = 2.0
			immortal_cd = 60.0
			main.fx.text(position + Vector2(0, -50), "Graine immortelle !", Color("7fd36b"), 22, 1.5)
		else:
			main.player_died()


func respawn() -> void:
	position = Vector2.ZERO
	hp = Game.stats["max_hp"]
	invuln = 2.0


func _draw() -> void:
	# Halo de vie
	var glow := Color(0.5, 0.9, 0.45, 0.10 + 0.04 * sin(t * 3.0))
	draw_circle(Vector2.ZERO, radius * 2.6, glow)
	if dash_time > 0.0:
		for i in 4:
			draw_circle(-dash_dir * (i + 1) * 12.0, radius * (0.9 - i * 0.15), Color(0.8, 1.0, 0.8, 0.25 - i * 0.05))
	var body := Color("e9e2c8")
	if hurt_flash > 0.0:
		body = Color("ff8a7a")
	elif invuln > 0.0 and int(t * 20.0) % 2 == 0:
		body = Color(0.9, 0.9, 0.8, 0.6)
	# Cape à capuche (forme en goutte) orientée vers la visée
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		var r := radius * (1.0 + 0.35 * maxf(0.0, -cos(a)))
		pts.append(Vector2.from_angle(a + aim.angle()) * r)
	draw_colored_polygon(pts, Color("3f6b3a"))
	draw_circle(Vector2.ZERO, radius * 0.75, body)
	# La graine tenue en main
	var seed_pos := aim * (radius + 8.0)
	draw_circle(seed_pos, 5.0, Color("b6f28a"))
	draw_circle(seed_pos, 9.0, Color(0.7, 1.0, 0.5, 0.25))
	# Barre de vie
	var ratio: float = clampf(hp / Game.stats["max_hp"], 0.0, 1.0)
	draw_rect(Rect2(-20, radius + 10, 40, 4), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-20, radius + 10, 40 * ratio, 4), Color("7fd36b"))
