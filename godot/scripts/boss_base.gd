## Socle commun des boss de région (classe BossBase). Un boss est un script
## boss_<région>.gd « extends BossBase », nommé dans « boss › script » du fichier de sa région, qui ne
## décrit que ses attaques, ses phases et son dessin. Le socle gère :
##   - la vie (selon le niveau du joueur et la difficulté), les dégâts reçus, le poison, le
##     saignement, l'enracinement et les petits invoqués (minions) ;
##   - les phases (phase_limits, phase_for) ;
##   - l'entrée en scène (intro), les pauses entre phases (transition), la mort (dying) ;
##   - la fin du combat : l'arène (boss_arena.gd) pose le drapeau <région>_boss_vaincu, donne la
##     récompense de data/rewards.json et lance la séquence « région purifiée ».
##
## À écrire dans le boss (méthodes à remplacer) :
##   - _setup() : régler les nombres du socle ci-dessous (appelé avant la vie et les calques) ;
##   - _fight_step(delta) : ses attaques, une fois l'intro et les transitions passées (le boss
##     change lui-même de phase, avec phase_for) ;
##   - _projectiles_step(delta) : ce qu'il a tiré et qui vole encore (appelé à chaque pas) ;
##   - _clear_attacks() : tout effacer à sa mort ;
##   - _draw(), draw_marks(c) (annonces au sol, coordonnées monde) et draw_overlay(c) (projectiles,
##     au-dessus) : chaque coup est annoncé avec Art.telegraph (charte, § 6) ;
##   - danger_time(pos) et bot_ring(arena_radius) : aident les robots à esquiver ;
##   - draw_sleeper(arena) et draw_victory(arena) (statiques) : le boss endormi et ce qui pousse à sa
##     place une fois vaincu, dessinés par l'arène.
##
## Il respecte l'interface d'un ennemi (position, radius, dead, take_damage, apply_poison,
## apply_status) et s'inscrit dans main.enemies ; trop gros pour la grille spatiale, il est aussi
## dans main.big_enemies (voir main.enemies_near).
class_name BossBase
extends Node2D

const Difficulty = preload("res://scripts/difficulty.gd")
const FletriArt = preload("res://scripts/fletri_art.gd")

# --- Nombres du socle (à régler dans _setup) ---
var body_radius := 70.0
var intro_time := 1.4
var death_time := 1.6
## Vie : base_hp + hp_per_level par niveau du joueur au début du combat.
var base_hp := 600.0
var hp_per_level := 200.0
## Les dégâts montent de damage_per_level par niveau du joueur.
var damage_per_level := 0.03
var contact_damage := 16.0
## Parts de vie où commencent les phases 2, 3…
var phase_limits: Array = [0.66, 0.33]
## Enraciné, il prépare ses attaques plus lentement (rooted_cadence), puis y résiste un moment.
var rooted_cadence := 0.55
var root_immunity := 6.0
var bleed_stacks := 5

var main
var arena
## Région du boss (celle de son arène).
var region := ""
## Rang dans main.enemies (voir main._rebuild_grid).
var index := -1
var radius := 70.0
var dead := false
var hp := 600.0
var max_hp := 600.0
var xp_value := 60.0
var poison_dps := 0.0
var poison_time := 0.0
var hit_flash := 0.0
## États posés par les compétences : nom -> {"value", "time", "stacks"}.
var statuses: Dictionary = {}
var root_immune := 0.0
## Il ne bouge pas : sa position est rétablie à chaque pas (reculs des coups, séparation).
var anchor := Vector2.ZERO
## Interface d'ennemi : enraciné, aucune résistance de région, comportement propre.
var anchored := true
var resist := {}
var behavior := "boss"
## Teinte des éclats de sa mort (fx.death).
var color := Color("3a2a2c")
var damage_scale := 1.0
var phase := 1
var t := 0.0
var intro := 1.4
var transition := 0.0
var dying := 0.0
## Petits qu'il a fait naître (tués avec lui).
var minions: Array = []
## Figé par les tests visuels : la logique ne tourne plus, la pose reste affichée.
var frozen := false
var marks: Node2D
var overlay: Node2D


## Annonces au sol (sous les personnages) et projectiles (au-dessus) : dessinés en coordonnées monde.
class Layer extends Node2D:
	var boss
	var above := false

	func _draw() -> void:
		if above:
			boss.draw_overlay(self)
		else:
			boss.draw_marks(self)


func _init() -> void:
	_setup()
	radius = body_radius
	intro = intro_time
	hp = base_hp
	max_hp = base_hp


func _ready() -> void:
	anchor = position
	# Le choix de difficulté des options (Facile / Normal / Difficile) vaut aussi pour les boss.
	max_hp = (base_hp + hp_per_level * Game.level) * Difficulty.hp_mult()
	hp = max_hp
	damage_scale = (1.0 + damage_per_level * (Game.level - 1)) * Difficulty.damage_mult()
	xp_value = 40.0 + 12.0 * Game.level
	marks = Layer.new()
	marks.boss = self
	arena.add_child(marks)
	overlay = Layer.new()
	overlay.boss = self
	overlay.above = true
	main.projectiles_layer.add_child(overlay)


func _exit_tree() -> void:
	main.big_enemies.erase(self)
	for n in [marks, overlay]:
		if is_instance_valid(n):
			n.queue_free()


func _process(delta: float) -> void:
	if frozen:
		return
	t += delta
	redraw()


func redraw() -> void:
	queue_redraw()
	marks.queue_redraw()
	overlay.queue_redraw()


func phase_for(ratio: float) -> int:
	for i in phase_limits.size():
		if ratio > float(phase_limits[i]):
			return i + 1
	return phase_limits.size() + 1


func _physics_process(delta: float) -> void:
	if frozen:
		return
	position = anchor
	hit_flash -= delta
	root_immune -= delta
	if dead:
		dying += delta
		if dying >= death_time:
			queue_free()
		return
	_tick_statuses(delta)
	if dead:
		return
	_projectiles_step(delta)
	minions = minions.filter(func(e): return is_instance_valid(e) and not e.dead and not e.is_queued_for_deletion())
	var p = main.player
	if p.position.distance_to(anchor) < radius + p.radius:
		p.take_hit(contact_damage * damage_scale, self)
	if intro > 0.0:
		intro -= delta
		return
	if transition > 0.0:
		transition -= delta
		return
	_fight_step(delta)


# --- À écrire dans chaque boss ---

## Règle les nombres du socle (body_radius, base_hp, phase_limits…).
func _setup() -> void:
	pass


## Attaques du boss, une fois l'intro et les transitions passées.
func _fight_step(_delta: float) -> void:
	pass


## Projectiles et pièges du boss encore actifs.
func _projectiles_step(_delta: float) -> void:
	pass


## Efface les attaques en cours (à la mort du boss).
func _clear_attacks() -> void:
	pass


func draw_marks(_c: CanvasItem) -> void:
	pass


func draw_overlay(_c: CanvasItem) -> void:
	pass


## Temps avant qu'une attaque annoncée ou en cours touche ce point (INF si rien ne le menace).
## Sert aux robots pour choisir où se tenir.
func danger_time(pos: Vector2, margin := 26.0) -> float:
	return 0.0 if pos.distance_to(anchor) < radius + margin + 20.0 else INF


## Distance au centre de l'arène où le robot tourne autour du boss.
func bot_ring(arena_radius: float) -> float:
	return minf(250.0, arena_radius - 60.0)


## Le boss endormi, au centre de l'arène, tant que le combat n'a pas lieu (coordonnées de l'arène).
static func draw_sleeper(a: Node2D) -> void:
	a.draw_circle(a.center, 40.0, Art.c("ennemi").darkened(0.4))
	if a.state == "ouverte":
		a.draw_circle(a.center, 12.0, Color(Art.ec("cendre"), 0.45 + 0.35 * sin(a.t * 2.0)))


## Ce qui pousse à la place du boss une fois vaincu.
static func draw_victory(a: Node2D) -> void:
	a.draw_circle(a.center, 50.0, Art.c("decor_vivant"))


# --- Interface d'un ennemi ---

func take_damage(amount: float, crit: bool, dot := false) -> void:
	if dead:
		return
	hp -= amount
	if not dot:
		hit_flash = 0.08
		if crit:
			main.fx.text(position + Vector2(0, -radius * 2.0), str(roundi(amount)), Color("f2d06b"), 20, 0.6)
	if hp <= 0.0:
		_die()


func apply_poison(dps: float, duration: float) -> void:
	poison_dps = maxf(poison_dps if poison_time > 0.0 else 0.0, dps)
	poison_time = maxf(poison_time, duration)


## États posés par les compétences. « saignement » : dégâts par seconde, cumulable bleed_stacks
## fois. « enracine » : il est déjà enraciné, mais prépare ses attaques plus lentement tant que
## l'état dure, puis y résiste root_immunity secondes.
func apply_status(status: String, value: float, duration: float) -> void:
	if dead:
		return
	match status:
		"saignement":
			var s: Dictionary = statuses.get(status, {"value": 0.0, "time": 0.0, "stacks": 0})
			s["value"] = maxf(s["value"], value)
			s["time"] = maxf(s["time"], duration)
			s["stacks"] = mini(bleed_stacks, int(s["stacks"]) + 1)
			statuses[status] = s
		"enracine":
			if root_immune > 0.0 or statuses.has(status):
				return
			statuses[status] = {"value": value, "time": minf(duration, 3.0), "stacks": 1}
			main.fx.text(position + Vector2(0, -radius * 2.0), "Entravée", Color("9af07a"), 18, 0.8)
		_:
			statuses[status] = {"value": value, "time": duration, "stacks": 1}


## Saignée : fait éclater le saignement d'un coup (même contrat que enemy.gd). Renvoie les dégâts
## que le saignement aurait encore faits, multipliés par « mult », et retire l'état.
func burst_bleed(mult: float) -> float:
	var s: Dictionary = statuses.get("saignement", {})
	if s.is_empty():
		return 0.0
	statuses.erase("saignement")
	return float(s["value"]) * int(s["stacks"]) * maxf(0.0, float(s["time"])) * mult


func is_bleeding() -> bool:
	return statuses.has("saignement")


## Préparation ralentie tant qu'il est enraciné.
func cadence() -> float:
	return rooted_cadence if statuses.has("enracine") else 1.0


func _tick_statuses(delta: float) -> void:
	if poison_time > 0.0:
		poison_time -= delta
		take_damage(poison_dps * delta, false, true)
	for status in statuses.keys():
		var s: Dictionary = statuses[status]
		s["time"] -= delta
		if status == "saignement" and not dead:
			take_damage(s["value"] * s["stacks"] * delta, false, true)
		if s["time"] <= 0.0:
			statuses.erase(status)
			if status == "enracine":
				root_immune = root_immunity


func _die() -> void:
	dead = true
	dying = 0.0
	hp = 0.0
	_clear_attacks()
	main.big_enemies.erase(self)
	for e in minions:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(e.hp + 1.0, false)
	main.on_enemy_killed(self)
	arena.boss_defeated()


## Couleur d'une partie du corps : éclair du coup reçu, poison, puis cendre pendant la mort.
func _color(base: Color) -> Color:
	var c := base
	if hit_flash > 0.0:
		c = c.lerp(Art.c("danger_eclair"), 0.6)
	if poison_time > 0.0:
		c = c.lerp(Art.ec("poison"), 0.3)
	if dead:
		c = c.lerp(FletriArt.ash_color(), Anim.ease_out(clampf(dying / death_time * 1.4, 0.0, 1.0)))
	return c
