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
## « elites » de enemies.json) : plus de vie, un liseré doré et un nom au-dessus de lui.
extends Node2D

const Content = preload("res://scripts/content.gd")
const Thorn = preload("res://scripts/enemy_thorn.gd")
const Difficulty = preload("res://scripts/difficulty.gd")
const Blast = preload("res://scripts/enemy_blast.gd")

## Sortes d'ennemis, dans l'ordre de enemies.json (les trois premières sont les Flétris d'origine).
static var KINDS: Array = Content._load("enemies").get("kinds", [])
## Indice de chaque sorte par identifiant.
static var KIND_INDEX: Dictionary = _index_kinds()
## Réglages des élites et de leurs modificateurs (section « elites » de enemies.json).
static var ELITES: Dictionary = Content._load("enemies").get("elites", {})
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
	color = Color(data["color"])
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
			main.fx.ring(position, radius, radius * 3.0, 0.4, Color(1.0, 0.35, 0.2, 0.9), 4.0)
			main.fx.text(position + Vector2(0, -radius - 30), "Enragé !", Color("ff7a5a"), 16, 1.0)
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
	if not dot:
		hit_flash = 0.08
		main.fx.impact(position, shown, crit, radius)
	if hp <= 0.0:
		dead = true
		if behavior == "bomber":
			_burst()
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
	if enraged:
		c = c.lerp(Color("c0301e"), 0.35)
	var dir: Vector2 = (main.player.position - position).normalized()
	if elite:
		_draw_elite_under()
	match behavior:
		"shooter":
			_draw_shooter(c, dir)
		"charger":
			_draw_charger(c, dir)
		"nest":
			_draw_nest(c)
		"kite":
			_draw_kite(c, dir)
		"guard":
			_draw_guard(c, dir)
		"bomber":
			_draw_bomber(c, dir)
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
	if guard_time > 0.0:
		_draw_guarded()
	if elite:
		_draw_elite_over()
	if hp < max_hp or (max_shield > 0.0 and shield < max_shield):
		var w := radius * 2.0
		draw_rect(Rect2(-radius, -radius - 9, w, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-radius, -radius - 9, w * clampf(hp / max_hp, 0.0, 1.0), 3), Color("e0675e"))
		if max_shield > 0.0 and shield > 0.0:
			draw_rect(Rect2(-radius, -radius - 12, w * clampf(shield / max_shield, 0.0, 1.0), 2), Color("e2c48a"))


## Sous la silhouette d'une élite : halo doré et, pendant l'annonce d'un modificateur, son signal.
func _draw_elite_under() -> void:
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	draw_circle(Vector2.ZERO, radius * 1.55, Color(1.0, 0.8, 0.35, 0.10 + 0.06 * pulse))
	var k := affix_ratio()
	if aff_state == "epines":
		# Annonce : les épines de la couronne sortent tout autour, de plus en plus longues.
		_draw_spikes(radius, int(ELITES["affixes"]["epines"].get("count", 10)), Color("e8d6b0"), 0.3 + 0.9 * k)
		draw_arc(Vector2.ZERO, radius * (1.4 + 1.2 * k), 0.0, TAU, 32, Color(1.0, 0.85, 0.6, 0.25 + 0.4 * k), 2.0)
	elif aff_state == "invocateur":
		# Annonce : un cercle violet se referme au sol.
		var col := Color("b48cff")
		draw_arc(Vector2.ZERO, radius * (2.6 - 1.2 * k), 0.0, TAU, 32, Color(col, 0.3 + 0.5 * k), 3.0)
		for i in 3:
			var a := TAU * i / 3.0 + t * 2.0
			draw_circle(Vector2.from_angle(a) * radius * (2.6 - 1.2 * k), 3.0, col)


## Par-dessus une élite : liseré doré, bouclier d'écorce, pastilles des modificateurs et nom.
func _draw_elite_over() -> void:
	var gold := Color("f2c75a")
	draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 36, Color(0.1, 0.06, 0.02, 0.6), 4.5)
	draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 36, gold, 2.2)
	if max_shield > 0.0 and shield > 0.0:
		# Plaques d'écorce autour du corps, d'autant plus nombreuses que le bouclier est plein.
		var plates := int(ceil(8.0 * shield / max_shield))
		var bark := Color("a07a48")
		for i in plates:
			var a0 := TAU * i / 8.0 - PI / 2.0 + 0.08
			draw_arc(Vector2.ZERO, radius + 8.5, a0, a0 + TAU / 8.0 - 0.16, 6, bark.darkened(0.35), 6.0)
			draw_arc(Vector2.ZERO, radius + 8.5, a0, a0 + TAU / 8.0 - 0.16, 6, bark, 3.5)
	var cfg: Dictionary = ELITES.get("affixes", {})
	for i in affixes.size():
		var at := Vector2((i - (affixes.size() - 1) / 2.0) * 10.0, radius + 11.0)
		draw_circle(at, 4.2, Color(0.08, 0.05, 0.03, 0.8))
		draw_circle(at, 3.0, Color(cfg[affixes[i]].get("color", "#ffffff")))
	var font := ThemeDB.fallback_font
	var size := 13
	var w := font.get_string_size(elite_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-w / 2.0, -radius - 18.0)
	draw_string(font, at + Vector2(1, 1), elite_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.85))
	draw_string(font, at, elite_name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, gold.lightened(0.25))


## Protégé par un Gardien d'écorce : un trait d'écorce le relie au gardien et une plaque le couvre.
func _draw_guarded() -> void:
	var bark := Color("c9a46a")
	var to := guard_from - position
	if to.length() > radius + 4.0:
		draw_line(to.normalized() * radius, to * 0.5, Color(bark, 0.35), 2.0)
	var face := to.normalized() if to.length() > 1.0 else Vector2.UP
	var a := face.angle() + PI
	draw_arc(Vector2.ZERO, radius + 3.0, a - 0.9, a + 0.9, 10, Color(bark, 0.85), 3.0)


func _draw_kite(c: Color, dir: Vector2) -> void:
	var aim := attack_dir if state == "windup" else dir
	var k := windup_ratio()
	if state == "windup":
		# Annonce : l'éventail des trois tirs s'allume au sol.
		var n := int(data.get("shots", 3))
		var spread := float(data.get("spread", 0.3))
		for i in n:
			var d := Vector2.from_angle(aim.angle() + (i - (n - 1) / 2.0) * spread)
			draw_line(d * (radius + 6.0), d * (radius + 60.0 + 140.0 * k), Color(1.0, 0.6, 0.3, 0.2 + 0.45 * k), 2.0)
	# Corps maigre et voûté, gorge gonflée de braises pendant l'annonce.
	_draw_blob(c, radius)
	# Museau en entonnoir tourné vers la cible, braise au fond qui grossit pendant l'annonce.
	var side := aim.orthogonal() * radius * 0.42
	var mouth := aim * radius * 1.45
	draw_colored_polygon(PackedVector2Array([aim * radius * 0.4 + side, mouth + side * 0.75, mouth - side * 0.75, aim * radius * 0.4 - side]), c.darkened(0.25))
	draw_circle(mouth, radius * 0.3, Color("2a1e1a"))
	draw_circle(mouth, radius * (0.14 + 0.2 * k), Color("ff9a4a").lerp(Color("fff0b0"), k))
	# Fumerolles sur le dos.
	for i in 3:
		var a := aim.angle() + PI + (i - 1) * 0.6
		var b := Vector2.from_angle(a) * radius * 0.8
		var rise := 0.5 + 0.5 * sin(t * 3.0 + i)
		draw_circle(b + Vector2(0, -4.0 * rise), radius * (0.18 + 0.08 * rise), Color(0.55, 0.5, 0.48, 0.55))
	_draw_eyes(aim, radius)


func _draw_guard(c: Color, dir: Vector2) -> void:
	# Aura : le cercle de protection au sol.
	var aura := float(data.get("aura", 160.0))
	var bark := Color("c9a46a")
	draw_arc(Vector2.ZERO, aura, 0.0, TAU, 48, Color(bark, 0.16), 3.0)
	draw_arc(Vector2.ZERO, aura, t * 0.4, t * 0.4 + 0.7, 8, Color(bark, 0.4), 3.0)
	draw_arc(Vector2.ZERO, aura, t * 0.4 + PI, t * 0.4 + PI + 0.7, 8, Color(bark, 0.4), 3.0)
	# Corps trapu couvert de plaques d'écorce.
	_draw_blob(c, radius)
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var center := Vector2.from_angle(a) * radius * 0.55
		draw_arc(center, radius * 0.38, a - 1.1, a + 1.1, 8, bark.darkened(0.2), 4.0)
	# Écu d'écorce tenu face au joueur.
	var front := dir * radius * 0.95
	var side := dir.orthogonal() * radius * 0.7
	draw_colored_polygon(PackedVector2Array([front + side, front + dir * radius * 0.35, front - side, front - dir * radius * 0.2]), bark)
	draw_line(front + side * 0.8, front - side * 0.8, bark.darkened(0.4), 2.0)
	_draw_eyes(dir, radius, -dir * radius * 0.15)


func _draw_bomber(c: Color, dir: Vector2) -> void:
	# Corps gonflé qui palpite, couvert de pustules de spores.
	var swell := 1.0 + 0.06 * sin(t * 5.0)
	_draw_blob(c, radius * swell)
	for i in 7:
		var a := TAU * i / 7.0 + 0.5
		var at := Vector2.from_angle(a) * radius * (0.45 + 0.25 * (i % 2)) * swell
		var glow := 0.5 + 0.5 * sin(t * 4.0 + i * 1.7)
		draw_circle(at, radius * 0.17, Color("c8d86a").darkened(0.3))
		draw_circle(at, radius * 0.1, Color(0.85, 0.95, 0.45, 0.6 + 0.4 * glow))
	_draw_eyes(dir, radius * 0.8, dir * radius * 0.25)


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
