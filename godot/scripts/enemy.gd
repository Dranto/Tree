## Les Flétris : créatures de cendre qui traquent le Porte-Graine.
## Les sortes d'ennemis sont décrites dans res://data/enemies.json (statistiques, comportement,
## région, résistances) ; le comportement lui-même est écrit ici :
##   chase   : poursuit le joueur (Flétri, Cendreux, Colosse, Rejeton)
##   shooter : garde ses distances et tire une épine, annoncée par une visée visible (Tireur d'épines)
##   charger : s'arrête, annonce un couloir au sol, puis charge en ligne droite (Chargeur)
##   nest    : immobile, fait naître des Rejetons après avoir enflé (Nid de ronces)
##   kite    : fuit le joueur trop proche, puis s'arrête et crache un éventail de cendre (Cracheur de cendre)
##   guard   : avance derrière les autres et réduit les dégâts de ses voisins (Gardien d'écorce)
##   bomber  : poursuit le joueur ; à sa mort, il éclate après une annonce au sol (Boursouflé)
## Élites : un ennemi tiré au hasard reçoit un ou deux modificateurs (« affixes », section
## « elites » de difficulty.json) : plus de vie, une aura et une couronne magenta, un signe par
## modificateur et un nom au-dessus de lui.
## Dessin : la silhouette de chaque sorte est dans fletri_art.gd (charte graphique).
extends Node2D

const Content = preload("res://scripts/content.gd")
const Thorn = preload("res://scripts/enemy_thorn.gd")
const Difficulty = preload("res://scripts/difficulty.gd")
const Blast = preload("res://scripts/enemy_blast.gd")
const FletriArt = preload("res://scripts/fletri_art.gd")
const Remains = preload("res://scripts/enemy_remains.gd")
const DrawBatch = preload("res://scripts/draw_batch.gd")

## Sortes d'ennemis, dans l'ordre de enemies.json (les trois premières sont les Flétris d'origine).
static var KINDS: Array = Content._load("enemies").get("kinds", [])
## Indice de chaque sorte par identifiant.
static var KIND_INDEX: Dictionary = _index_kinds()
## Réglages des élites et de leurs modificateurs (section « elites » de difficulty.json).
static var ELITES: Dictionary = Content._load("difficulty").get("elites", {})
const BEHAVIORS := ["chase", "shooter", "charger", "nest", "kite", "guard", "bomber"]

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
## Gardien d'écorce proche : part des dégâts ignorée, et secondes restantes de la protection.
var guard_cut := 0.0
var guard_time := 0.0
var guard_from := Vector2.ZERO

## --- Élite ---
var elite := false
## Modificateurs de l'élite (clés de « elites.affixes »), contrat partagé avec le butin et les objectifs.
var affixes: Array[String] = []
var elite_name := ""
## Multiplicateur des temps de recharge (« rapide »).
var cd_mult := 1.0
var enraged := false
## Bouclier d'écorce : absorbe les dégâts avant la vie, se reforme après un temps sans coup.
var shield := 0.0
var max_shield := 0.0
var shield_wait := 0.0
## Attaque d'un modificateur (« epines », « invocateur ») : annonce en cours et recharges.
var aff_state := ""
var aff_t := 0.0
var aff_cd: Dictionary = {}


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
		if not str(k.get("behavior", "")) in BEHAVIORS:
			errors.append("enemies.json, %s : comportement inconnu « %s »" % [id, k.get("behavior", "")])
		if float(k.get("radius", 0.0)) > MAX_RADIUS:
			errors.append("enemies.json, %s : rayon supérieur à MAX_RADIUS (%d)" % [id, MAX_RADIUS])
		if k.get("behavior", "") == "nest" and not KIND_INDEX.has(str(k.get("spawn", ""))):
			errors.append("enemies.json, %s : sorte à faire naître inconnue « %s »" % [id, k.get("spawn", "")])
	for id in ELITES.get("excluded", []):
		if not KIND_INDEX.has(id):
			errors.append("enemies.json, élites : sorte exclue inconnue « %s »" % id)
	var known := ["rapide", "enrage", "ecorce", "epines", "invocateur"]
	for a in ELITES.get("affixes", {}):
		if not a in known:
			errors.append("enemies.json, élites : modificateur sans code « %s »" % a)
		elif not ELITES["affixes"][a].has("name"):
			errors.append("enemies.json, élites : modificateur « %s » sans nom" % a)
	var inv: Dictionary = ELITES.get("affixes", {}).get("invocateur", {})
	if not inv.is_empty() and not KIND_INDEX.has(str(inv.get("spawn", ""))):
		errors.append("enemies.json, élites : sorte invoquée inconnue « %s »" % inv.get("spawn", ""))
	var spawn: Dictionary = Content._load("enemies").get("spawn", {}).duplicate()
	spawn["ordinaires"] = Content._load("enemies").get("ordinary", {})
	for reg in spawn:
		for field in ["kinds", "min_level", "max_alive"]:
			for id in spawn[reg].get(field, {}):
				if not KIND_INDEX.has(id):
					errors.append("enemies.json, apparitions de %s (%s) : sorte inconnue « %s »" % [reg, field, id])
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
	# Teinte du corps (charte) : sert aussi aux éclats de sa mort (fx.death).
	color = FletriArt.body_color(kind_id)
	t = randf() * 10.0
	# Les attaques ne partent pas toutes en même temps.
	cd = float(data.get("cooldown", 0.0)) * randf_range(0.4, 1.0)
	strafe = 1.0 if randf() < 0.5 else -1.0


## Sorte qui peut devenir une élite (ni le Nid, ni ses Rejetons, ni une élite déjà faite).
func can_be_elite() -> bool:
	return not elite and not kind_id in ELITES.get("excluded", [])


## Modificateurs que cette sorte peut recevoir (le Gardien d'écorce n'a pas de bouclier d'écorce en plus).
func allowed_affixes() -> Array:
	var out := []
	for a in ELITES.get("affixes", {}):
		if not a in data.get("no_affix", []):
			out.append(a)
	return out


## Fait de cet ennemi une élite avec ces modificateurs. À appeler après setup().
func make_elite(list: Array) -> void:
	elite = true
	affixes.clear()
	var cfg: Dictionary = ELITES.get("affixes", {})
	var adjectives := PackedStringArray()
	for a in list:
		if cfg.has(a) and not a in affixes:
			affixes.append(a)
			adjectives.append(str(cfg[a]["name"]))
	elite_name = str(data["name"]) + " " + " et ".join(adjectives)
	max_hp *= float(ELITES.get("hp", 3.0))
	hp = max_hp
	damage *= float(ELITES.get("damage", 1.25))
	radius = minf(MAX_RADIUS, radius * float(ELITES.get("radius", 1.2)))
	xp_value *= float(ELITES.get("xp", 5.0))
	if "rapide" in affixes:
		speed *= float(cfg["rapide"].get("speed", 1.4))
		cd_mult = float(cfg["rapide"].get("cooldown", 0.7))
		cd *= cd_mult
	if "ecorce" in affixes:
		max_shield = max_hp * float(cfg["ecorce"].get("shield", 0.5))
		shield = max_shield
	for a in ["epines", "invocateur"]:
		if a in affixes:
			aff_cd[a] = float(cfg[a]["cooldown"]) * randf_range(0.5, 1.0)


## Animation seulement (marche, regard, éclairs) : suit la fréquence d'affichage.
func _process(delta: float) -> void:
	t += delta
	_animate(delta)
	_redraw_parts(delta)


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
			"kite":
				_kite(delta, dir, dist, slow)
			"guard":
				_guard(dir, dist, slow, delta)
			_:
				position += dir * speed * slow * delta
		if elite:
			_elite_step(delta, dist)
	if guard_time > 0.0:
		guard_time -= delta
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
			cd = float(data["cooldown"]) * cd_mult
			var th = Thorn.new()
			th.main = main
			th.position = position + attack_dir * (radius + 6.0)
			th.vel = attack_dir * float(data["shot_speed"])
			th.damage = float(data["shot_damage"]) * damage_scale
			th.life = data["shot_life"]
			main.projectiles_layer.add_child(th)
			strike_t = 0.0
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
	cd = float(data["cooldown"]) * cd_mult


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


## Cracheur de cendre : fuit le joueur trop proche, puis s'arrête et crache un éventail de cendre.
func _kite(delta: float, dir: Vector2, dist: float, slow: float) -> void:
	cd -= delta
	if state == "windup":
		state_t -= delta
		if state_t <= 0.0:
			state = ""
			cd = float(data["cooldown"]) * cd_mult
			var n := int(data.get("shots", 3))
			var spread := float(data.get("spread", 0.3))
			for i in n:
				var a := attack_dir.angle() + (i - (n - 1) / 2.0) * spread
				_shoot(Vector2.from_angle(a), float(data["shot_speed"]), float(data["shot_damage"]), float(data["shot_life"]), "cendre")
			strike_t = 0.0
		return
	if cd <= 0.0 and dist < float(data["range"]) and dist > float(data["keep_min"]) * 0.7:
		state = "windup"
		state_t = data["windup"]
		attack_dir = dir
		return
	var mv := Vector2.ZERO
	if dist < float(data["keep_min"]):
		mv = -dir * float(data.get("flee", 1.3))
	elif dist > float(data["keep_max"]):
		mv = dir
	else:
		mv = dir.orthogonal() * strafe * 0.45
	position += mv * speed * slow * delta


## Gardien d'écorce : avance sans se jeter sur le joueur et protège les ennemis autour de lui.
func _guard(dir: Vector2, dist: float, slow: float, delta: float) -> void:
	if dist > float(data.get("keep_back", 0.0)):
		position += dir * speed * slow * delta
	var cut := float(data.get("guard", 0.5))
	for e in main.enemies_near(position, float(data.get("aura", 160.0)), false):
		if e != self and not e.dead and "guard_cut" in e and e.behavior != "guard":
			e.guard_cut = cut
			e.guard_time = 0.25
			e.guard_from = position


## Tire une épine (ou une boule de cendre) depuis le bord de la silhouette.
func _shoot(d: Vector2, spd: float, dmg: float, life: float, look := "") -> void:
	var th = Thorn.new()
	th.main = main
	th.position = position + d * (radius + 6.0)
	th.vel = d * spd
	th.damage = dmg * damage_scale
	th.life = life
	th.look = look
	main.projectiles_layer.add_child(th)


## Modificateurs d'élite actifs à chaque pas : rage, bouclier, couronne d'épines, invocation.
func _elite_step(delta: float, dist: float) -> void:
	var cfg: Dictionary = ELITES["affixes"]
	if "enrage" in affixes and not enraged and hp < max_hp * float(cfg["enrage"].get("below", 0.5)):
		enraged = true
		speed *= float(cfg["enrage"].get("speed", 1.3))
		damage *= float(cfg["enrage"].get("damage", 1.5))
		if main.get("fx") != null:
			main.fx.ring(position, radius, radius * 3.0, 0.4, Art.ec("cendre"), 4.0)
			main.fx.text(position + Vector2(0, -radius - 30), "Enragé !", Art.ec("cendre", "clair"), 16, 1.0)
	if max_shield > 0.0:
		shield_wait -= delta
		if shield_wait <= 0.0 and shield < max_shield:
			shield = minf(max_shield, shield + max_shield * float(cfg["ecorce"].get("regen", 0.25)) * delta)
	if aff_state != "":
		aff_t -= delta
		if aff_t <= 0.0:
			_affix_attack(aff_state)
			aff_state = ""
		return
	for a in aff_cd:
		aff_cd[a] -= delta
		if aff_cd[a] <= 0.0 and dist < 900.0:
			if a == "invocateur":
				young = young.filter(func(y): return is_instance_valid(y) and not y.dead)
				if young.size() >= int(cfg[a].get("max_young", 4)):
					aff_cd[a] = 1.0
					continue
			aff_state = a
			aff_t = float(cfg[a].get("windup", 0.7))
			aff_cd[a] = float(cfg[a]["cooldown"]) * cd_mult
			return


func _affix_attack(a: String) -> void:
	var c: Dictionary = ELITES["affixes"][a]
	match a:
		"epines":
			var n := int(c.get("count", 10))
			var phase := randf() * TAU
			for i in n:
				_shoot(Vector2.from_angle(phase + TAU * i / n), float(c["shot_speed"]), float(c["shot_damage"]), float(c["shot_life"]))
			strike_t = 0.0
		"invocateur":
			for i in int(c.get("count", 2)):
				var at := position + Vector2.from_angle(randf() * TAU) * (radius + 16.0)
				main.spawn_enemy_kind(c["spawn"], at, power, self)


## Progression de l'annonce d'un modificateur d'élite, de 0 à 1.
func affix_ratio() -> float:
	if aff_state == "":
		return 0.0
	var w := float(ELITES["affixes"][aff_state].get("windup", 0.7))
	return clampf(1.0 - aff_t / maxf(0.01, w), 0.0, 1.0)


func apply_poison(dps: float, duration: float) -> void:
	poison_dps = maxf(poison_dps if poison_time > 0.0 else 0.0, dps)
	poison_time = maxf(poison_time, duration)


func take_damage(amount: float, crit: bool, dot := false) -> void:
	if dead:
		return
	if guard_time > 0.0:
		amount *= 1.0 - guard_cut
	var shown := amount
	if max_shield > 0.0:
		shield_wait = float(ELITES["affixes"]["ecorce"].get("regen_delay", 4.0))
		var soak := minf(shield, amount)
		shield -= soak
		amount -= soak
	hp -= amount
	if _over:
		_over.queue_redraw()
	if not dot:
		hit_flash = 0.08
		main.fx.impact(position, shown, crit, radius)
	if hp <= 0.0:
		dead = true
		if behavior == "bomber":
			_burst()
		_leave_remains()
		main.on_enemy_killed(self)
		queue_free()


## Boursouflé : laisse une poche de spores qui éclate après une annonce au sol.
func _burst() -> void:
	var b = Blast.new()
	b.main = main
	b.position = position
	b.radius = float(data.get("blast_radius", 90.0))
	b.delay = float(data.get("blast_delay", 0.9))
	b.damage = float(data.get("blast_damage", 20.0)) * damage_scale
	b.enemy_damage = float(data.get("blast_enemy_damage", 50.0)) * power
	b.color = color
	main.projectiles_layer.call_deferred("add_child", b)


# --- Animation (apparence seulement : rien ici ne change le jeu) ---

## Direction du regard (lissée), phase de la marche et part de la pleine course.
var face := Vector2.RIGHT
var walk := 0.0
var moving := 0.0
var _last_pos := Vector2.INF
## Temps depuis le dernier coup parti (tir, crachat, couronne d'épines), -1 sinon : éclair de la frappe.
var strike_t := -1.0
const STRIKE_TIME := 0.22


func _animate(delta: float) -> void:
	if _last_pos == Vector2.INF:
		_last_pos = position
	var moved := minf(position.distance_to(_last_pos), speed * delta * 2.0)
	_last_pos = position
	var v := moved / maxf(delta, 0.001)
	moving = lerpf(moving, clampf(v / maxf(speed, 1.0), 0.0, 1.0), 1.0 - exp(-8.0 * delta))
	walk += v * delta / maxf(radius * 0.9, 4.0)
	face = face.slerp(_target_face(), 1.0 - exp(-12.0 * delta)).normalized()
	if strike_t >= 0.0:
		strike_t += delta
		if strike_t > STRIKE_TIME:
			strike_t = -1.0


func _target_face() -> Vector2:
	if state != "":
		return attack_dir
	if main == null or main.player == null:
		return face
	var to: Vector2 = main.player.position - position
	return to.normalized() if to.length() > 1.0 else face


## Mort : la silhouette tombe en cendre, puis une pousse de vie sort à sa place (enemy_remains.gd).
func _leave_remains() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var r = Remains.new()
	r.kind_id = kind_id
	r.radius = radius
	r.face = face
	r.elite = elite
	r.position = position
	parent.call_deferred("add_child", r)


# --- Dessin ---

## Pose transmise au dessin de la silhouette (fletri_art.gd).
func pose() -> Dictionary:
	var o := {"walk": walk, "moving": moving, "state": state, "k": windup_ratio()}
	if hit_flash > 0.0:
		o["flash"] = clampf(hit_flash / 0.08, 0.0, 1.0)
	if strike_t >= 0.0:
		o["strike"] = strike_t / STRIKE_TIME
	if enraged:
		o["tint"] = Color(Art.ec("cendre"), 0.28)
	elif poison_time > 0.0:
		o["tint"] = Color(Art.ec("poison"), 0.3)
	elif not bleed_stacks.is_empty():
		o["tint"] = Color(Art.ec("saignement", "clair"), 0.22)
	return o


## Couches : le sol (ombre, aura, annonce, dessous de l'élite) est dessiné par l'ennemi lui-même ;
## la silhouette et ce qui la recouvre (états, signes d'élite, barre de vie) par deux enfants.
## La silhouette n'est redessinée qu'une douzaine de fois par seconde, et pas hors de l'écran (plus souvent pendant une action) ;
## entre deux dessins, elle tourne avec le regard. 120 Flétris restent ainsi aussi légers qu'avant.
class Part extends Node2D:
	var e
	var top := false

	func _draw() -> void:
		if top:
			e._draw_over(self)
		else:
			e._draw_body(self)


const BODY_PERIOD := 1.0 / 12.0
var _body: Part
var _over: Part
var _body_face := Vector2.RIGHT
var _body_clock := 0.0


func _ready() -> void:
	_body = Part.new()
	_body.e = self
	add_child(_body)
	_over = Part.new()
	_over.e = self
	_over.top = true
	add_child(_over)
	_body_clock = randf() * BODY_PERIOD
	_body_face = face if is_processing() else _target_face()


## Redessine ce qui bouge, et seulement cela (appelé par _process).
func _redraw_parts(delta: float) -> void:
	var busy := state != "" or hit_flash > 0.0 or strike_t >= 0.0 or aff_state != ""
	if busy or behavior == "guard" or elite:
		queue_redraw()
	_body_clock -= delta
	var turn := absf(angle_difference(_body_face.angle(), face.angle()))
	if (busy or turn > 0.3 or _body_clock <= 0.0) and _on_screen():
		_body_clock += BODY_PERIOD
		if _body_clock < 0.0:
			_body_clock = BODY_PERIOD
		_body_face = face
		_body.queue_redraw()
	_body.rotation = angle_difference(_body_face.angle(), face.angle())
	var knock := -face * radius * 0.18 * clampf(hit_flash / 0.08, 0.0, 1.0)
	_body.position = knock
	_over.position = knock
	if elite or guard_time > 0.0 or root_time > 0.0 or poison_time > 0.0 or not bleed_stacks.is_empty() or _over_dirty:
		_over_dirty = root_time > 0.0 or poison_time > 0.0 or not bleed_stacks.is_empty() or guard_time > 0.0
		_over.queue_redraw()


## Hors de l'écran (avec une marge), la silhouette n'est pas redessinée.
func _on_screen() -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var view := vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	return view.grow(radius * 3.0 + 40.0).has_point(global_position)


## Vrai tant qu'un état visible vient de finir : un dernier dessin l'efface.
var _over_dirty := false


func _draw() -> void:
	var f := face if is_processing() else _target_face()
	if behavior == "guard":
		_draw_guard_aura()
	_draw_attack(f)
	if elite:
		_draw_elite_under(f)


## Lot de triangles partagé : la silhouette entière part en un seul appel de rendu.
static var _batch = DrawBatch.new()

func _draw_body(ci: CanvasItem) -> void:
	var f := _body_face if is_processing() else _target_face()
	# L'ombre tourne avec la silhouette entre deux dessins : on la garde ronde et centrée.
	var sr := radius * (1.15 if behavior == "nest" else 1.0)
	_batch.draw_colored_polygon(Art.ellipse(Vector2(0, sr * Art.OMBRE_DECALAGE * 0.5), sr * 1.05, sr * 0.75, 14), Art.c("ombre"))
	FletriArt.draw(_batch, kind_id, Vector2.ZERO, radius, f, t, pose())
	_batch.flush(ci)


func _draw_over(ci: CanvasItem) -> void:
	# États : le motif de l'élément de chaque effet (charte, § 3).
	if root_time > 0.0:
		Art.status(ci, "racine", Vector2.ZERO, radius, t)
	if poison_time > 0.0:
		Art.status(ci, "poison", Vector2.ZERO, radius, t)
	if not bleed_stacks.is_empty():
		Art.status(ci, "saignement", Vector2.ZERO, radius, t * 1.25)
		# Une goutte par piqûre, en arc au-dessus de la tête.
		for i in bleed_stacks.size():
			var a := -PI / 2.0 + (i - (bleed_stacks.size() - 1) / 2.0) * 0.4
			Art._drop(ci, Vector2.from_angle(a) * radius * 1.15, maxf(1.8, radius * 0.11), Art.ec("saignement", "clair"))
	if guard_time > 0.0:
		_draw_guarded(ci)
	if elite:
		_draw_elite_over(ci)
	_draw_bar(ci)


## Barre de vie (et bouclier d'écorce) : seulement quand il est entamé.
func _draw_bar(ci: CanvasItem) -> void:
	if hp >= max_hp and (max_shield <= 0.0 or shield >= max_shield):
		return
	var w := maxf(radius * 2.0, 22.0)
	var y := -radius - (radius * 0.95 + 14.0 if elite else 11.0)
	ci.draw_rect(Rect2(-w / 2.0 - 1.0, y - 1.0, w + 2.0, 5.0), Color(Art.c("contour"), 0.85))
	ci.draw_rect(Rect2(-w / 2.0, y, w * clampf(hp / max_hp, 0.0, 1.0), 3.0), Art.c("danger"))
	if max_shield > 0.0 and shield > 0.0:
		ci.draw_rect(Rect2(-w / 2.0, y - 4.0, w * clampf(shield / max_shield, 0.0, 1.0), 2.5), Art.ec("racine", "clair"))


## Annonce de l'attaque en cours, puis éclair de la frappe : toujours Art.telegraph (charte, § 6).
func _draw_attack(f: Vector2) -> void:
	var k := windup_ratio()
	var hit := strike_t / STRIKE_TIME if strike_t >= 0.0 else -1.0
	match behavior:
		"shooter":
			if state == "windup" or hit >= 0.0:
				var reach := minf(float(data["range"]), 440.0)
				Art.telegraph(self, {"type": "ligne", "de": attack_dir * (radius + 4.0), "a": attack_dir * reach, "largeur": 10.0}, k, hit, t)
		"kite":
			if state == "windup" or hit >= 0.0:
				var n := int(data.get("shots", 3))
				var spread := float(data.get("spread", 0.3))
				Art.telegraph(self, {"type": "cone", "centre": attack_dir * radius * 0.5, "direction": attack_dir.angle(), "ouverture": spread * (n - 1) + 0.22, "rayon": 240.0}, k, hit, t)
		"charger":
			var ln := float(data["charge_dist"])
			if state == "windup":
				Art.telegraph(self, {"type": "ligne", "de": Vector2.ZERO, "a": attack_dir * ln, "largeur": radius * 2.0}, k, -1.0, t)
			elif state == "charge":
				var from := -attack_dir * travelled
				Art.telegraph(self, {"type": "ligne", "de": from, "a": from + attack_dir * ln, "largeur": radius * 2.0}, 1.0, travelled / ln, t)
	if elite and aff_state == "epines":
		Art.telegraph(self, {"type": "cercle", "centre": Vector2.ZERO, "rayon": radius * 2.8}, affix_ratio(), -1.0, t)
	elif elite and hit >= 0.0 and behavior in ["chase", "guard", "charger", "bomber"] and "epines" in affixes:
		Art.telegraph(self, {"type": "cercle", "centre": Vector2.ZERO, "rayon": radius * 2.8}, 1.0, hit, t)


## Aura du Gardien d'écorce : un cercle de racines au sol, deux nœuds qui en font le tour.
func _draw_guard_aura() -> void:
	var aura := float(data.get("aura", 160.0))
	var col := Art.ec("racine")
	draw_arc(Vector2.ZERO, aura, 0.0, TAU, 64, Color(col, 0.16), Art.TRAIT, true)
	for i in 2:
		var a := t * 0.4 + i * PI
		draw_arc(Vector2.ZERO, aura, a, a + 0.7, 10, Color(col, 0.45), Art.TRAIT, true)
		draw_circle(Vector2.from_angle(a + 0.7) * aura, 3.5, Color(Art.ec("racine", "clair"), 0.6))


## Protégé par un Gardien d'écorce : une racine le relie au gardien, une plaque d'écorce le couvre.
func _draw_guarded(ci: CanvasItem) -> void:
	var bark := Art.ec("racine", "clair")
	var to := guard_from - position
	if to.length() > radius + 4.0:
		ci.draw_line(to.normalized() * radius, to * 0.5, Color(Art.ec("racine"), 0.4), Art.TRAIT_FIN, true)
	var dir := to.normalized() if to.length() > 1.0 else Vector2.UP
	var a := dir.angle() + PI
	ci.draw_arc(Vector2.ZERO, radius + 4.0, a - 0.9, a + 0.9, 12, Art.ec("racine", "sombre"), Art.TRAIT_FORT, true)
	ci.draw_arc(Vector2.ZERO, radius + 4.0, a - 0.8, a + 0.8, 12, bark, Art.TRAIT_FIN, true)


## Couleur du signe d'un modificateur : celle de son élément (charte), sinon la sienne.
const AFFIX_ELEMENT := {"enrage": "cendre", "ecorce": "racine", "epines": "epine", "invocateur": "poison"}

func _affix_color(a: String) -> Color:
	if AFFIX_ELEMENT.has(a):
		return Art.ec(AFFIX_ELEMENT[a])
	return Color(ELITES.get("affixes", {}).get(a, {}).get("color", "#ffffff"))


## Sous une élite : aura magenta en tirets qui tournent, couronne de pointes, signes des modificateurs.
func _draw_elite_under(f: Vector2) -> void:
	var r := radius
	var col := Art.c("elite")
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	draw_circle(Vector2.ZERO, r * 1.75, Color(col, 0.06 + 0.03 * pulse))
	draw_circle(Vector2.ZERO, r * 1.38, Color(col, 0.09))
	for i in 10:
		var a := i * TAU / 10.0 + t * 0.5
		draw_arc(Vector2.ZERO, r * 1.6, a, a + 0.36, 6, Color(col, 0.7), Art.TRAIT_FIN, true)
	if "rapide" in affixes:
		# Traînées de vitesse derrière lui.
		var c := _affix_color("rapide")
		for i in 3:
			var u := fposmod(t * 2.2 + i / 3.0, 1.0)
			var side := f.orthogonal() * r * (i - 1) * 0.55
			var from := -f * r * (1.0 + 0.4 * u) + side
			draw_line(from, from - f * r * (0.6 + 0.6 * (1.0 - u)), Color(c, 0.75 * (1.0 - u)), Art.TRAIT, true)
	if "epines" in affixes:
		# Couronne d'épines d'os, qui s'allongent pendant l'annonce.
		var k := affix_ratio()
		var n := int(ELITES["affixes"]["epines"].get("count", 10))
		for i in n:
			var d := Vector2.from_angle(i * TAU / n + t * 0.3)
			FletriArt._spike(self, Transform2D(), d * r * 0.95, d, r * (0.3 + 0.8 * k), Art.ec("epine", "clair"), {})
	if "invocateur" in affixes:
		var c := _affix_color("invocateur")
		var k := affix_ratio()
		var ring := r * (1.7 - 0.5 * k)
		if aff_state == "invocateur":
			# Cercle d'invocation qui se referme (ce n'est pas un coup : pas de rouge).
			draw_arc(Vector2.ZERO, r * (2.8 - 1.1 * k), 0.0, TAU, 40, Color(c, 0.3 + 0.5 * k), Art.TRAIT, true)
		for i in 3:
			var a := t * 1.8 + i * TAU / 3.0
			var q := Vector2.from_angle(a) * ring
			draw_circle(q, r * 0.16, Color(c, 0.3))
			draw_arc(q, r * 0.12, 0.0, TAU, 10, Art.ec("poison", "clair"), Art.TRAIT_FIN, true)
	# Couronne de pointes : la marque des élites (moitié éclairée, moitié dans l'ombre).
	for i in 5:
		var d := Vector2.from_angle(-PI / 2.0 + (i - 2) * 0.42)
		FletriArt._spike(self, Transform2D(), d * r * 0.78, d, r * (0.85 if i == 2 else 0.68), col, {})


## Par-dessus une élite : gemme de corruption, flammes de la rage, plaques d'écorce, signes, nom.
func _draw_elite_over(ci: CanvasItem) -> void:
	var r := radius
	var col := Art.c("elite")
	var g := Vector2(r * 0.05, -r * 0.55)
	ci.draw_circle(g, r * (0.22 + 0.05 * sin(t * 4.0)), Color(col, 0.25))
	ci.draw_colored_polygon(PackedVector2Array([g + Vector2(0, -r * 0.17), g + Vector2(r * 0.12, 0), g + Vector2(0, r * 0.17), g + Vector2(-r * 0.12, 0)]), col)
	ci.draw_circle(g + Vector2(-r * 0.03, -r * 0.05), maxf(r * 0.04, 1.0), Color.WHITE)
	if "enrage" in affixes:
		# Braises qui s'envolent : quelques-unes au calme, une gerbe une fois enragé.
		var n := 7 if enraged else 3
		for i in n:
			var u := fposmod(t * (1.4 if enraged else 0.8) + i / float(n), 1.0)
			var q := Vector2(sin(i * 2.3 + t * 2.0) * r * 0.8, -r * (0.2 + 1.5 * u))
			FletriArt._flake(ci, q, r * 0.09 * (1.0 - 0.5 * u), Color(Art.ec("cendre", "clair") if i % 2 else Art.ec("cendre"), 1.0 - u))
	if max_shield > 0.0 and shield > 0.0:
		# Plaques d'écorce autour du corps, d'autant plus nombreuses que le bouclier est plein.
		var plates := int(ceil(8.0 * shield / max_shield))
		for i in plates:
			var a0 := TAU * i / 8.0 - PI / 2.0 + 0.1
			ci.draw_arc(Vector2.ZERO, r + 7.0, a0, a0 + TAU / 8.0 - 0.2, 6, Art.ec("racine", "sombre"), 7.0, true)
			ci.draw_arc(Vector2.ZERO, r + 7.5, a0 + 0.04, a0 + TAU / 8.0 - 0.24, 6, Art.ec("racine"), 3.5, true)
			ci.draw_arc(Vector2.ZERO, r + 9.0, a0 + 0.1, a0 + TAU / 16.0, 4, Art.ec("racine", "clair"), 1.2, true)
	# Signes des modificateurs : un médaillon par modificateur sous la silhouette.
	var s := 11.0
	for i in affixes.size():
		var a: String = affixes[i]
		var at := Vector2((i - (affixes.size() - 1) / 2.0) * (s * 2.0 + 3.0), r + s + 5.0)
		var c := _affix_color(a)
		ci.draw_circle(at, s, Art.c("contour"))
		ci.draw_circle(at, s - 1.5, c.darkened(0.75))
		ci.draw_arc(at, s - 1.0, 0.0, TAU, 20, c, Art.TRAIT_FIN, true)
		if AFFIX_ELEMENT.has(a):
			Art.icon(ci, AFFIX_ELEMENT[a], Rect2(at - Vector2(s, s) * 0.75, Vector2(s, s) * 1.5), c)
		else:
			# « Rapide » : deux chevrons.
			for j in 2:
				var x := at.x - s * 0.35 + j * s * 0.4
				ci.draw_polyline(PackedVector2Array([Vector2(x - s * 0.2, at.y - s * 0.38), Vector2(x + s * 0.18, at.y), Vector2(x - s * 0.2, at.y + s * 0.38)]), c, Art.TRAIT, true)
	var font := ThemeDB.fallback_font
	var size := 12
	var w := font.get_string_size(elite_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(-w / 2.0, -r - (r * 0.95 + 14.0) - 7.0)
	ci.draw_string_outline(font, pos, elite_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(Art.c("contour"), 0.9))
	ci.draw_string(font, pos, elite_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col.lerp(Color.WHITE, 0.55))
