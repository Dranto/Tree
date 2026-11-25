## Socle commun des boss de région (classe BossBase). Un boss est un script
## boss_<région>.gd « extends BossBase », nommé dans « boss › script » du fichier de sa région, qui ne
## décrit que ses attaques, ses phases et son dessin. Le socle gère :
##   - la vie (selon le niveau du joueur et la difficulté), les dégâts reçus, le poison, le
##     saignement, l'enracinement et les petits invoqués (minions) ;
##   - les phases (phase_limits, phase_for) ;
##   - l'entrée en scène (intro), les pauses entre phases (transition), la mort (dying) ;
##   - la fin du combat : l'arène (boss_arena.gd) pose le drapeau <région>_boss_vaincu, donne la
##     récompense de « boss › reward » et lance la séquence « région purifiée ».
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
const RegionAudio = preload("res://scripts/region_audio.gd")

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
var max_bleed_stacks := 5

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
## Part de l'armure du joueur ignorée par le coup en cours (player.take_hit), 0 d'ordinaire.
var armor_pierce := 0.0
var behavior := "boss"
## Teinte des éclats de sa mort (fx.death).
var color := Color("3a2a2c")
var damage_scale := 1.0
var phase := 1
## Dernière phase vue : un changement joue le son « phase » de la région.
var _last_phase := 1
var t := 0.0
var intro := 1.4
var transition := 0.0
var dying := 0.0
## Petits qu'il a fait naître (tués avec lui).
var minions: Array = []
## Combat calé sur le morceau du boss (boss_sync.gd, posé par l'arène) ; null : pas de morceau.
## Il fixe la fin de l'intro (le premier temps de la première boucle) et des transitions (la fin du
## drop) ; le boss n'y frappe pas et n'y prend pas de dégâts.
var sync = null
## Vrai tant que le boss attendait la musique au pas précédent (la reprise éclate à sa fin).
var _music_wait := false
## Charge pendant l'attente de la musique (invocation, pont avant chaque phase) : 0 au début de
## l'attente, 1 au retour de la batterie ; -1 hors attente. Elle suit la mesure, pas le temps du jeu.
var charge := -1.0
var _charge_total := 0.0
## Dernière impulsion de charge jouée (numéro de subdivision depuis le début du morceau).
var _charge_hit := -1
## Rotation accumulée de ce qui tourne autour de lui pendant la charge (de plus en plus vite).
var charge_spin := 0.0
## Hasard propre aux étincelles (ne touche pas au hasard du jeu).
var _charge_rng := RandomNumberGenerator.new()
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
	max_hp = (base_hp + hp_per_level * Game.level) * Difficulty.boss_hp_factor(region) * Difficulty.hp_mult()
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
	_last_phase = phase
	_region_sound("eveil")


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
	if phase != _last_phase:
		_last_phase = phase
		_region_sound("phase")
		_eclat("phase")
		main.fx.boss_phase(position, radius)
		if sync != null:
			sync.phase(phase)
	_projectiles_step(delta)
	minions = minions.filter(func(e): return is_instance_valid(e) and not e.dead and not e.is_queued_for_deletion())
	var p = main.player
	if p.position.distance_to(anchor) < radius + p.radius:
		p.take_hit(contact_damage * damage_scale, self)
	if sync != null:
		_follow_music(delta)
	if intro > 0.0:
		intro -= delta
		return
	if transition > 0.0:
		transition -= delta
		return
	_fight_step(delta)


## La musique tient l'intro et les transitions : elles durent jusqu'au premier temps de la boucle.
func _follow_music(delta := 0.0) -> void:
	var waiting: bool = sync.waiting()
	if waiting and sync.stage == "intro":
		intro = sync.left()
	elif waiting and sync.stage == "drop":
		transition = sync.left()
	elif _music_wait:
		# La batterie revient : le combat reprend d'un coup.
		intro = 0.0
		transition = 0.0
		charge = -1.0
		_music_resume()
	if waiting:
		_charge_step(delta)
	_music_wait = waiting


# --- Charge sur le pont de la musique ---
# Pendant toute l'attente, le boss charge sa forme suivante : des impulsions calées sur la grille du
# morceau, de plus en plus serrées (blanches, noires, croches, doubles croches sur la dernière mesure),
# l'énergie qui afflue vers lui de plus en plus vite, la secousse qui monte ; sur le dernier temps il
# déborde ; au retour de la batterie, tout éclate (_music_resume).

## Énergie de la charge (0 → 1), qui accélère vers la fin ; 0 hors attente.
func charge_energy() -> float:
	return pow(charge, 2.2) if charge > 0.0 else 0.0


## Temps (au sens musical) d'ici le retour de la batterie.
func charge_beats_left() -> float:
	if sync == null:
		return 0.0
	return sync.left() / (sync.bar / float(sync.beats))


## Impulsions par temps à cet instant : 0,5 (blanches) loin du drop, puis 1, 2, et 4 sur la
## dernière mesure.
func charge_rate() -> float:
	var lb := charge_beats_left()
	if lb > 8.0:
		return 0.5
	if lb > 4.0:
		return 1.0
	if lb > 2.0:
		return 2.0
	return 4.0


## Battement de la charge (1 sur l'impulsion, retombe à 0 avant la suivante).
func charge_pulse() -> float:
	if charge < 0.0 or sync == null:
		return 0.0
	return pow(1.0 - fposmod(sync.bars_now() * sync.beats * charge_rate(), 1.0), 3.0)


## Débordement du dernier temps (0 → 1 sur le dernier temps avant la batterie).
func charge_overflow() -> float:
	if charge < 0.0:
		return 0.0
	return clampf(1.0 - charge_beats_left(), 0.0, 1.0)


## Tremblement du corps (en pixels, local) : il grandit avec l'énergie et explose sur le dernier temps.
func charge_jitter() -> Vector2:
	var e := charge_energy()
	if e <= 0.0:
		return Vector2.ZERO
	var amp := radius * (0.012 * e + 0.03 * e * charge_pulse() + 0.05 * charge_overflow())
	return Vector2(sin(t * 71.0) + 0.6 * sin(t * 113.0), cos(t * 83.0) + 0.6 * sin(t * 59.0)) * amp


func _charge_step(delta: float) -> void:
	var left: float = sync.left()
	if charge < 0.0 or left > _charge_total:
		_charge_total = left
		_charge_hit = -1
		# La caméra glisse vers lui pendant toute la charge, et revient au héros après l'éclat.
		if main.get("moments") != null and left > 0.5:
			main.moments.focus(anchor + Vector2(0, -radius * 0.45), left + 0.9, left / (left + 0.9), 0.6, 300.0)
	charge = clampf(1.0 - left / maxf(_charge_total, 0.001), 0.0, 1.0)
	var e := charge_energy()
	charge_spin += delta * lerpf(0.25, 4.0, e)
	var rate := charge_rate()
	var hit := int(floor(sync.bars_now() * sync.beats * rate + 0.0001) * (4.0 / rate))
	if hit != _charge_hit and _charge_total > 0.0:
		var first := _charge_hit < 0
		_charge_hit = hit
		if not first:
			_charge_impulse(e, rate)


## Une impulsion de charge (sur la grille) : l'énergie est aspirée vers lui, la secousse monte.
## Chaque boss peut l'enrichir (sa couleur, ses formes).
func _charge_impulse(e: float, rate: float) -> void:
	var col := _charge_color()
	main.fx.shake(0.03 + 0.2 * e)
	if Settings.reduce_effects:
		return
	# Anneau qui se referme sur lui (l'inverse d'une onde de choc) : de plus en plus vite.
	main.fx.ring(anchor, radius * (6.5 - 2.5 * e), radius * 0.7, clampf(0.55 / rate, 0.12, 0.6), Color(col, 0.35 + 0.55 * e), 2.0 + 6.0 * e)
	# Étincelles aspirées depuis le bord de l'arène.
	var n := 3 + int(16.0 * e)
	for i in n:
		var a := _charge_rng.randf() * TAU
		var d := radius * _charge_rng.randf_range(3.5, 6.5)
		var from := anchor + Vector2.from_angle(a) * d
		var dur := _charge_rng.randf_range(0.28, 0.45)
		main.fx.mote(from, (anchor - from) / dur, dur, _charge_rng.randf_range(2.0, 3.5 + 3.0 * e), Color(col, 0.9))
	# La dernière mesure : la caméra se resserre sur chaque coup.
	if rate >= 4.0 and main.get("moments") != null:
		main.moments.zoom_pulse(0.25 + 0.35 * e, 0.2)
	# Le bord de l'écran s'allume sur chaque temps fort.
	if rate <= 1.0 or e > 0.6:
		main.screen_fx.glow(col, (0.08 + 0.35 * e) * (1.0 if rate <= 1.0 else 0.5), clampf(0.6 / rate, 0.12, 0.5))


## Couleur de l'énergie qu'il charge.
func _charge_color() -> Color:
	return Art.c("danger_eclair")


## Le combat (re)prend sur le premier temps de la boucle : tout ce qu'il a chargé éclate d'un coup.
## Chaque boss peut l'enrichir.
func _music_resume() -> void:
	var col := _charge_color()
	main.fx.shake(1.0)
	main.fx.screen_flash(Color(1.0, 0.97, 0.9), 0.75, 0.45)
	if main.get("moments") != null:
		main.moments.impact_frame(1.0, [self], "encre")
		main.moments.zoom_pulse(1.0, 0.7)
	main.screen_fx.glow(col, 0.6, 0.9)
	if Settings.reduce_effects:
		return
	main.fx.ring(anchor, radius, radius * 5.5, 0.55, Color(Art.ec("cendre", "clair"), 0.85), 7.0)
	main.fx.ring(anchor, radius * 0.5, radius * 9.0, 0.8, Color(1.0, 0.97, 0.9, 0.9), 14.0)
	main.fx.ring(anchor, radius * 0.8, radius * 7.0, 1.1, Color(col, 0.7), 5.0)
	main.fx.star(anchor, radius * 3.4, 16, Color(1.0, 0.97, 0.9), 0.45)
	for i in 48:
		var a := TAU * i / 48.0 + _charge_rng.randf_range(-0.06, 0.06)
		var v := Vector2.from_angle(a) * _charge_rng.randf_range(420.0, 900.0)
		main.fx.mote(anchor + Vector2.from_angle(a) * radius * 0.6, v, _charge_rng.randf_range(0.5, 0.9), _charge_rng.randf_range(3.0, 6.0), Color(col if i % 2 == 0 else Color(1.0, 0.95, 0.85), 0.95))


## Vrai tant que le boss attend la musique (arrivée, transformation) : invulnérable.
func music_waiting() -> bool:
	return sync != null and sync.waiting()


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
	if dead or music_waiting():
		return
	hp -= amount
	if not dot:
		hit_flash = 0.08
		# Éclats sur le bord du corps tourné vers le Porte-Graine (data/feel.json, comme les Flétris).
		var to: Vector2 = main.player.position - position if main.player != null else Vector2.DOWN
		var at := position + (to.normalized() if to.length() > 1.0 else Vector2.DOWN) * radius * 0.8
		var heavy: bool = amount >= max_hp * main.fx.feel("heavy", "boss_frac", 0.04)
		main.fx.impact(at, amount, crit, 18.0, "", heavy, true)
	if hp <= 0.0:
		_die()


func apply_poison(dps: float, duration: float) -> void:
	poison_dps = maxf(poison_dps if poison_time > 0.0 else 0.0, dps)
	poison_time = maxf(poison_time, duration)


## États posés par les compétences. « saignement » : dégâts par seconde, cumulable max_bleed_stacks
## fois. « ebloui » : chance de critique en plus contre lui (moitié de value, 2 s au plus).
## « enracine » : il est déjà enraciné, mais prépare ses attaques plus lentement tant que
## l'état dure, puis y résiste root_immunity secondes.
func apply_status(status: String, value: float, duration: float) -> void:
	if dead:
		return
	match status:
		"saignement":
			var s: Dictionary = statuses.get(status, {"value": 0.0, "time": 0.0, "stacks": 0})
			s["value"] = maxf(s["value"], value)
			s["time"] = maxf(s["time"], duration)
			s["stacks"] = mini(max_bleed_stacks, int(s["stacks"]) + 1)
			statuses[status] = s
		"enracine":
			# Un boss qui déclare « var no_root := true » (l'Ancien pétrifié) ne se laisse pas entraver.
			if root_immune > 0.0 or statuses.has(status) or get("no_root") == true:
				return
			statuses[status] = {"value": value, "time": minf(duration, 3.0), "stacks": 1}
			main.fx.text(position + Vector2(0, -radius * 2.0), Loc.t("Entravée"), Color("9af07a"), 18, 0.8)
		"ebloui":
			# Ébloui (Aube) : moitié moins de critiques en plus qu'un Flétri, 2 s au plus (main.dazzle_of).
			var s: Dictionary = statuses.get(status, {"value": 0.0, "time": 0.0, "stacks": 1})
			s["value"] = maxf(float(s["value"]), value * 0.5)
			s["time"] = maxf(float(s["time"]), minf(duration, 2.0))
			statuses[status] = s
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


## Joue un des sons du boss de sa région (data/audio.json › boss : « eveil », « phase », « mort »), s'il y en a.
func _region_sound(key: String) -> void:
	var snd := RegionAudio.boss_sound(region, key)
	if snd != "":
		Sfx.play(snd, anchor)


func _die() -> void:
	if sync != null:
		sync.stop()
	_region_sound("mort")
	dead = true
	dying = 0.0
	hp = 0.0
	_clear_attacks()
	main.big_enemies.erase(self)
	for e in minions:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(e.hp + 1.0, false)
	main.on_enemy_killed(self)
	_eclat("die")
	main.fx.boss_kill(position, radius)
	arena.boss_defeated()


## Moment signature de l'arène (boss_eclat.gd : « phase », « die »), purement visuel.
func _eclat(what: String) -> void:
	var e = arena.get("eclat") if arena != null else null
	if e != null:
		e.call(what, self)


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
