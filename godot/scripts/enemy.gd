## Les Flétris : créatures de cendre qui traquent le Porte-Graine.
## Les sortes d'ennemis sont décrites dans res://data/enemies.json (statistiques, comportement,
## région, résistances) ; le comportement lui-même est écrit ici :
##   chase   : poursuit le joueur (Flétri, Cendreux, Colosse, Rejeton)
##   shooter : garde ses distances et tire une épine, annoncée par une visée visible (Tireur d'épines)
##   charger : s'arrête, annonce un couloir au sol, puis charge en ligne droite (Chargeur)
##   nest    : immobile, fait naître des Rejetons après avoir enflé (Nid de ronces)
extends Node2D

const Content = preload("res://scripts/content.gd")
const Thorn = preload("res://scripts/enemy_thorn.gd")
const Difficulty = preload("res://scripts/difficulty.gd")

## Sortes d'ennemis, dans l'ordre de enemies.json (les trois premières sont les Flétris d'origine).
static var KINDS: Array = Content._load("enemies").get("kinds", [])
## Indice de chaque sorte par identifiant.
static var KIND_INDEX: Dictionary = _index_kinds()

## Rayon du plus gros ennemi (Nid de ronces) : marge des recherches dans la grille spatiale.
## validate_kinds() vérifie qu'aucune sorte ne le dépasse.
const MAX_RADIUS := 26.0

var main
## Rang dans main.enemies au dernier pas de jeu (sert à ne traiter chaque paire qu'une fois).
var index := -1
var kind := 0
var kind_id := "fletri"
var behavior := "chase"
var region := ""
var data: Dictionary = {}
var power := 1.0
var hp := 30.0
var max_hp := 30.0
var speed := 85.0
var damage := 10.0
## Facteur des dégâts (menace et choix de difficulté), appliqué aussi aux charges et aux épines tirées.
var damage_scale := 1.0
var radius := 14.0
var xp_value := 3.0
var color := Color.GRAY
## Part des dégâts ignorée par branche de l'arbre (ex. {"ronce": 0.25}), voir main.branch_factor().
var resist: Dictionary = {}
## Immobile : les autres ennemis ne le poussent pas (Nid).
var anchored := false
var poison_dps := 0.0
var poison_time := 0.0
## Saignement : jusqu'à BLEED_MAX_STACKS piqûres, chacune [dégâts par seconde, secondes restantes].
## Les dégâts tombent par à-coups toutes les BLEED_TICK secondes (évènement « on_bleed_tick »).
const BLEED_MAX_STACKS := 5
const BLEED_TICK := 0.5
var bleed_stacks: Array = []
var bleed_clock := 0.0
## Enraciné : immobile tant que root_time > 0 (il frappe toujours au contact).
var root_time := 0.0
var hit_flash := 0.0
var dead := false
var t := 0.0
## Comportement : "" (déplacement), "windup" (attaque annoncée), "charge", "recover".
var state := ""
var state_t := 0.0
var cd := 0.0
## Direction verrouillée au début de l'annonce (charge, tir).
var attack_dir := Vector2.RIGHT
var travelled := 0.0
var strafe := 1.0
var young: Array = []


static func _index_kinds() -> Dictionary:
	var out := {}
	for i in KINDS.size():
		out[str(KINDS[i].get("id", ""))] = i
	return out


static func kind_index(id: String) -> int:
	return KIND_INDEX.get(id, -1)


## Erreurs de enemies.json (appelée par check_data.gd).
static func validate_kinds() -> PackedStringArray:
	var errors := PackedStringArray()
	var behaviors := ["chase", "shooter", "charger", "nest"]
	if KINDS.size() < 3:
		errors.append("enemies.json : il faut au moins les trois Flétris d'origine")
	var seen := {}
	for k in KINDS:
		var id := str(k.get("id", ""))
		if id == "" or seen.has(id):
			errors.append("enemies.json : identifiant absent ou en double « %s »" % id)
		seen[id] = true
		for f in ["name", "hp", "speed", "damage", "radius", "xp", "color"]:
			if not k.has(f):
				errors.append("enemies.json, %s : champ « %s » manquant" % [id, f])
		if not str(k.get("behavior", "")) in behaviors:
			errors.append("enemies.json, %s : comportement inconnu « %s »" % [id, k.get("behavior", "")])
		if float(k.get("radius", 0.0)) > MAX_RADIUS:
			errors.append("enemies.json, %s : rayon supérieur à MAX_RADIUS (%d)" % [id, MAX_RADIUS])
		if k.get("behavior", "") == "nest" and not KIND_INDEX.has(str(k.get("spawn", ""))):
			errors.append("enemies.json, %s : sorte à faire naître inconnue « %s »" % [id, k.get("spawn", "")])
	var spawn: Dictionary = Content._load("enemies").get("spawn", {})
	for reg in spawn:
		for id in spawn[reg].get("kinds", {}):
			if not KIND_INDEX.has(id):
				errors.append("enemies.json, apparitions de %s : sorte inconnue « %s »" % [reg, id])
	return errors


## k : indice dans KINDS ou identifiant (« tireur »).
func setup(k, p: float) -> void:
	kind = k if k is int else kind_index(str(k))
	data = KINDS[kind]
	kind_id = data["id"]
	behavior = data.get("behavior", "chase")
	region = data.get("region", "")
	resist = data.get("resist", {})
	anchored = behavior == "nest"
	# Mise à l'échelle selon la menace (main.threat) et le choix de difficulté des options.
	power = p
	damage_scale = Difficulty.damage_factor(p) * Difficulty.damage_mult()
	max_hp = data["hp"] * Difficulty.hp_factor(p) * Difficulty.hp_mult()
	hp = max_hp
	speed = data["speed"] * Difficulty.speed_factor(p)
	damage = data["damage"] * damage_scale
	radius = data["radius"]
	xp_value = data["xp"] * Difficulty.xp_factor(p)
	color = Color(data["color"])
	t = randf() * 10.0
	# Les attaques ne partent pas toutes en même temps.
	cd = float(data.get("cooldown", 0.0)) * randf_range(0.4, 1.0)
	strafe = 1.0 if randf() < 0.5 else -1.0


## Animation seulement (ondulation de la silhouette) : suit la fréquence d'affichage.
func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Logique à pas fixe : comportement, contact avec le joueur, poison.
func _physics_process(delta: float) -> void:
	if dead:
		return
	hit_flash -= delta
	var p = main.player
	var to: Vector2 = p.position - position
	var dist := to.length()
	var dir := to / dist if dist > 1.0 else Vector2.ZERO
	# La terre vivante ralentit les Flétris.
	var slow := 0.6 if main.ground.life_at(position) > 0.45 else 1.0
	if root_time > 0.0:
		# Enraciné : immobile (le tir et la charge sont suspendus), il frappe toujours au contact.
		root_time -= delta
	else:
		match behavior:
			"shooter":
				_shooter(delta, dir, dist, slow)
			"charger":
				_charger(delta, dir, dist, slow)
			"nest":
				_nest(delta, dist)
			_:
				position += dir * speed * slow * delta
	var hit := damage
	if state == "charge":
		hit = float(data.get("charge_damage", damage)) * damage_scale
	if dist < radius + p.radius:
		p.take_hit(hit, self)
	if poison_time > 0.0:
		poison_time -= delta
		take_damage(poison_dps * delta, false, true)
	if not bleed_stacks.is_empty():
		_bleed_step(delta)


## Saignement : fait avancer les piqûres et inflige leurs dégâts toutes les BLEED_TICK secondes.
func _bleed_step(delta: float) -> void:
	bleed_clock += delta
	if bleed_clock < BLEED_TICK:
		return
	var step := bleed_clock
	bleed_clock = 0.0
	var dps := 0.0
	for st in bleed_stacks:
		dps += st[0] * minf(step, st[1]) / step
		st[1] -= step
	bleed_stacks = bleed_stacks.filter(func(st): return st[1] > 0.0)
	var amount := dps * step
	if amount <= 0.0:
		return
	take_damage(amount, false, true)
	if main.has_method("on_bleed_tick"):
		main.on_bleed_tick(self, amount)


## États posés par les compétences et les effets (contrat partagé avec l'arbre et le boss) :
##   « saignement » : value = dégâts par seconde pendant duration, cumulable BLEED_MAX_STACKS fois
##                    (au-delà, la piqûre la plus faible est remplacée si la nouvelle est plus forte) ;
##   « enracine »   : immobilisé pendant duration (value ignorée).
func apply_status(status: String, value: float, duration: float) -> void:
	if dead or duration <= 0.0:
		return
	match status:
		"saignement":
			if value <= 0.0:
				return
			if bleed_stacks.size() < BLEED_MAX_STACKS:
				bleed_stacks.append([value, duration])
			else:
				var weakest := 0
				for i in bleed_stacks.size():
					if bleed_stacks[i][0] < bleed_stacks[weakest][0]:
						weakest = i
				if value >= bleed_stacks[weakest][0]:
					bleed_stacks[weakest] = [value, duration]
		"enracine":
			var fresh := root_time <= 0.0
			root_time = maxf(root_time, duration)
			if fresh and main.has_method("on_enemy_rooted"):
				main.on_enemy_rooted(self)
		_:
			push_warning("État d'ennemi inconnu : " + status)


## Saignée : consomme tous les saignements et renvoie mult × les dégâts qu'ils auraient
## encore infligés (à appliquer par l'appelant).
func burst_bleed(mult: float) -> float:
	var left := 0.0
	for st in bleed_stacks:
		left += st[0] * maxf(0.0, st[1])
	bleed_stacks = []
	bleed_clock = 0.0
	return left * mult


func is_bleeding() -> bool:
	return not bleed_stacks.is_empty()


func _shooter(delta: float, dir: Vector2, dist: float, slow: float) -> void:
	cd -= delta
	if state == "windup":
		state_t -= delta
		if state_t <= 0.0:
			state = ""
			cd = data["cooldown"]
			var th = Thorn.new()
			th.main = main
			th.position = position + attack_dir * (radius + 6.0)
			th.vel = attack_dir * float(data["shot_speed"])
			th.damage = float(data["shot_damage"]) * damage_scale
			th.life = data["shot_life"]
			main.projectiles_layer.add_child(th)
		return
	if cd <= 0.0 and dist < float(data["range"]):
		state = "windup"
		state_t = data["windup"]
		attack_dir = dir
		return
	var mv := Vector2.ZERO
	if dist > float(data["keep_max"]):
		mv = dir
	elif dist < float(data["keep_min"]):
		mv = -dir
	else:
		mv = dir.orthogonal() * strafe * 0.6
	position += mv * speed * slow * delta


func _charger(delta: float, dir: Vector2, dist: float, slow: float) -> void:
	cd -= delta
	match state:
		"windup":
			state_t -= delta
			if state_t <= 0.0:
				state = "charge"
				travelled = 0.0
		"charge":
			var step: float = float(data["charge_speed"]) * delta
			var before := position
			position += attack_dir * step
			travelled += step
			# Un buisson d'épines arrête la charge net (et l'étourdit un peu plus longtemps).
			var pushed: Vector2 = main.flora.push_out(position, radius) if main.flora else position
			if pushed.distance_squared_to(position) > 0.5:
				position = pushed
				_end_charge(1.6)
			elif travelled >= float(data["charge_dist"]) or before == position:
				_end_charge(1.0)
		"recover":
			state_t -= delta
			if state_t <= 0.0:
				state = ""
		_:
			if cd <= 0.0 and dist < float(data["range"]):
				state = "windup"
				state_t = data["windup"]
				attack_dir = dir
			else:
				position += dir * speed * slow * delta


func _end_charge(factor: float) -> void:
	state = "recover"
	state_t = float(data["recover"]) * factor
	cd = data["cooldown"]


func _nest(delta: float, dist: float) -> void:
	young = young.filter(func(y): return is_instance_valid(y) and not y.dead)
	if state == "windup":
		state_t -= delta
		if state_t <= 0.0:
			state = ""
			cd = data["cooldown"]
			var a := randf() * TAU
			main.spawn_enemy_kind(data["spawn"], position + Vector2.from_angle(a) * (radius + 12.0), power, self)
		return
	cd -= delta
	if cd <= 0.0 and dist < float(data["range"]) and young.size() < int(data["max_young"]):
		state = "windup"
		state_t = data["windup"]


## Progression de l'annonce en cours, de 0 (début) à 1 (l'attaque part).
func windup_ratio() -> float:
	if state != "windup":
		return 0.0
	return clampf(1.0 - state_t / maxf(0.01, float(data.get("windup", 1.0))), 0.0, 1.0)


func apply_poison(dps: float, duration: float) -> void:
	poison_dps = maxf(poison_dps if poison_time > 0.0 else 0.0, dps)
	poison_time = maxf(poison_time, duration)


func take_damage(amount: float, crit: bool, dot := false) -> void:
	if dead:
		return
	hp -= amount
	if not dot:
		hit_flash = 0.08
		main.fx.impact(position, amount, crit, radius)
	if hp <= 0.0:
		dead = true
		main.on_enemy_killed(self)
		queue_free()


# --- Dessin ---

func _draw() -> void:
	var c := color
	if hit_flash > 0.0:
		c = Color.WHITE
	elif poison_time > 0.0:
		c = c.lerp(Color("8f5fc0"), 0.4)
	elif not bleed_stacks.is_empty():
		c = c.lerp(Color("b02a2a"), 0.3)
	# Enraciné : des racines brunes sortent du sol et enserrent la base de la silhouette.
	if root_time > 0.0:
		var rc := Color("8a6438")
		draw_arc(Vector2(0, radius * 0.55), radius + 6.0, 0.0, TAU, 20, Color(rc, 0.55), 3.0)
		for i in 6:
			var a := TAU * i / 6.0 + 0.4
			var base := Vector2.from_angle(a) * (radius + 8.0)
			var tip := Vector2.from_angle(a + 0.6) * radius * 0.6
			draw_line(base, tip, rc, maxf(2.5, radius * 0.18))
			draw_circle(base, maxf(2.5, radius * 0.14), rc.darkened(0.3))
	# Ombre au sol : une ellipse sombre sous la silhouette.
	draw_set_transform(Vector2(0, radius * 0.7), 0.0, Vector2(1.0, 0.36))
	draw_circle(Vector2.ZERO, radius * 1.05, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var dir: Vector2 = (main.player.position - position).normalized()
	match behavior:
		"shooter":
			_draw_shooter(c, dir)
		"charger":
			_draw_charger(c, dir)
		"nest":
			_draw_nest(c)
		_:
			_draw_blob(c, radius)
			if region != "":
				_draw_spikes(radius, 6, Color("2a1a18"), 0.45)
			_draw_eyes(dir, radius)
	# Saignement : une goutte rouge par piqûre, en arc au-dessus de la tête.
	for i in bleed_stacks.size():
		var a := -PI / 2.0 + (i - (bleed_stacks.size() - 1) / 2.0) * 0.45
		var at := Vector2.from_angle(a) * radius * 0.95
		draw_circle(at, maxf(1.8, radius * 0.11), Color("e0302a"))
		draw_line(at, at + Vector2(0, -radius * 0.18), Color("e0302a"), maxf(1.2, radius * 0.07))
	if hp < max_hp:
		var w := radius * 2.0
		draw_rect(Rect2(-radius, -radius - 9, w, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-radius, -radius - 9, w * clampf(hp / max_hp, 0.0, 1.0), 3), Color("e0675e"))


## Silhouette irrégulière de cendre.
func _draw_blob(c: Color, r: float, offset := Vector2.ZERO) -> void:
	var pts := PackedVector2Array()
	var n := 14
	for i in n:
		var a := TAU * i / n
		var wobble := 1.0 + 0.12 * sin(a * 3.0 + t * 4.0) + 0.08 * sin(a * 5.0 - t * 2.0)
		pts.append(offset + Vector2.from_angle(a) * r * wobble)
	draw_colored_polygon(pts, c)


## Braises (yeux) tournées vers le joueur.
func _draw_eyes(dir: Vector2, r: float, offset := Vector2.ZERO) -> void:
	var side := dir.orthogonal() * r * 0.3
	var eye := offset + dir * r * 0.45
	draw_circle(eye + side, r * 0.13, Color("ff9a4a"))
	draw_circle(eye - side, r * 0.13, Color("ff9a4a"))


## Épines plantées autour de la silhouette (marque des ennemis du roncier).
func _draw_spikes(r: float, n: int, col: Color, length: float, phase := 0.0) -> void:
	for i in n:
		var a := TAU * i / n + phase
		var base := Vector2.from_angle(a) * r * 0.85
		var tip := Vector2.from_angle(a) * r * (1.0 + length)
		var side := Vector2.from_angle(a).orthogonal() * r * 0.14
		draw_colored_polygon(PackedVector2Array([base + side, tip, base - side]), col)


func _draw_shooter(c: Color, dir: Vector2) -> void:
	var aim := attack_dir if state == "windup" else dir
	var k := windup_ratio()
	if state == "windup":
		# Annonce : une ligne pointillée montre la trajectoire de l'épine, de plus en plus vive.
		var col := Color(1.0, 0.45, 0.3, 0.25 + 0.5 * k)
		var reach := 120.0 + 260.0 * k
		var seg := 14.0
		var d := radius + 8.0
		while d < reach:
			draw_line(aim * d, aim * minf(reach, d + seg * 0.6), col, 2.0)
			d += seg
	# Carquois d'épines sur le dos.
	for i in 5:
		var a := aim.angle() + PI + (i - 2) * 0.32
		var base := Vector2.from_angle(a) * radius * 0.6
		var tip := Vector2.from_angle(a) * radius * 1.65
		draw_line(base, tip, Color("2a1a18"), 3.0)
	_draw_blob(c, radius)
	# L'épine prête à partir pousse à l'avant pendant l'annonce.
	var front := aim * radius * 0.9
	var grow := radius * (0.4 + 1.1 * k)
	var side := aim.orthogonal() * radius * 0.22
	draw_colored_polygon(PackedVector2Array([front + side, front + aim * grow, front - side]), Color("e8d6b0") if k > 0.0 else Color("3a2420"))
	_draw_eyes(aim, radius)


func _draw_charger(c: Color, dir: Vector2) -> void:
	var facing := attack_dir if state != "" else dir
	if state == "windup":
		# Annonce : le couloir de la charge se remplit au sol.
		var k := windup_ratio()
		var ln: float = float(data["charge_dist"])
		var side := facing.orthogonal() * radius
		var col := Color(0.85, 0.2, 0.15, 0.10 + 0.12 * k)
		draw_colored_polygon(PackedVector2Array([side, side + facing * ln, -side + facing * ln, -side]), col)
		draw_colored_polygon(PackedVector2Array([side, side + facing * ln * k, -side + facing * ln * k, -side]), Color(0.95, 0.3, 0.2, 0.18 + 0.2 * k))
		draw_line(side + facing * ln, -side + facing * ln, Color(1.0, 0.4, 0.3, 0.6), 2.0)
	var shake := Vector2.ZERO
	if state == "windup":
		shake = facing.orthogonal() * sin(t * 60.0) * 2.0
	elif state == "recover":
		c = c.lerp(Color("2a2024"), 0.35)
	# Corps allongé dans la direction de la charge.
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		var v := Vector2(cos(a) * 1.25, sin(a) * 0.85) * radius * (1.0 + 0.06 * sin(a * 4.0 + t * 5.0))
		pts.append(shake + v.rotated(facing.angle()))
	draw_colored_polygon(pts, c)
	# Cornes de ronce à l'avant.
	for s in [-1.0, 1.0]:
		var base: Vector2 = shake + facing * radius * 0.9 + facing.orthogonal() * s * radius * 0.45
		var tip: Vector2 = base + (facing * 1.0 + facing.orthogonal() * s * 0.5).normalized() * radius * 0.8
		draw_line(base, tip, Color("d9c7a0"), 4.0)
	# Épines sur l'échine.
	for i in 4:
		var b: Vector2 = shake - facing * radius * (0.6 - i * 0.35)
		draw_line(b, b - facing.orthogonal() * radius * 0.7, Color("2a1a18"), 2.5)
		draw_line(b, b + facing.orthogonal() * radius * 0.7, Color("2a1a18"), 2.5)
	_draw_eyes(facing, radius, shake + facing * radius * 0.3)


func _draw_nest(c: Color) -> void:
	var k := windup_ratio()
	# Monticule de ronces emmêlées.
	draw_circle(Vector2.ZERO, radius * 1.15, Color(0.1, 0.06, 0.05, 0.45))
	_draw_blob(c, radius)
	for i in 7:
		var a := TAU * i / 7.0 + 0.4
		var center := Vector2.from_angle(a) * radius * 0.45
		draw_arc(center, radius * 0.55, a + 1.2, a + 4.2, 10, Color("2a1a18"), 3.0)
	_draw_spikes(radius, 9, Color("2a1a18"), 0.35, 0.2)
	# Cœur qui enfle avant de faire naître un Rejeton.
	var core := radius * (0.32 + 0.25 * k + 0.04 * sin(t * 3.0))
	draw_circle(Vector2.ZERO, core * 1.6, Color(1.0, 0.45, 0.25, 0.15 + 0.35 * k))
	draw_circle(Vector2.ZERO, core, Color("ff9a4a").lerp(Color("fff0b0"), k))
