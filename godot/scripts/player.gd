## Le Porte-Graine : déplacement, attaque de base automatique, esquive et compétences actives.
extends Node2D

const DASH_SPEED := 950.0
const DASH_TIME := 0.16
## Ébloui (éclair d'un Miroitier ou de la Phalène de verre, région d'Aube) : il marche moins vite.
const DAZZLE_SLOW := 0.65
## Barre de compétences : MAX_SLOTS emplacements, dont Game.stats["skill_slots"] débloqués.
## Les deux premiers sont les compétences principales (clics gauche et droit, Settings.MOUSE_SLOTS),
## les suivants les secondaires (A E R F). Commandes : Settings.slot_action(i).
const MAX_SLOTS := 6
## Changement de cible : une autre cible doit être nettement plus près du curseur (ou du héros)
## pour prendre la place de la cible actuelle, sinon le repère sauterait d'un ennemi à l'autre.
const TARGET_STICK := 0.75
## Recherche de la cible : tous les TARGET_EVERY pas, et à chaque tir sur une cible.
const TARGET_EVERY := 6
## « Se battre chez soi » : bonus des compétences de Ronce sur une terre ravivée de sa région.
const HOME_BONUS := 0.15
const HOME_LIFE := 0.45
## Statistique de dégâts de chaque famille d'attaque (champ « tags » de skills.json).
const TAG_STATS := {"corps_a_corps": "melee_damage", "projectile": "projectile_damage", "zone": "area_damage"}
const Content = preload("res://scripts/content.gd")
const Difficulty = preload("res://scripts/difficulty.gd")
## Attaque de base : forme et modificateurs donnés par l'arbre (attack.gd, data/attack.json).
const AttackScript = preload("res://scripts/attack.gd")
const Regions = preload("res://scripts/regions.gd")
## Une compétence par fichier : scripts/skills/<id>.gd (classe Skill).
const SKILLS_DIR := "res://scripts/skills/"
## Déplacement à la souris (Settings.move_mode).
## « curseur » : zone morte autour du héros (il s'arrête quand la souris est tout près), puis la
## vitesse monte jusqu'au plein régime FOLLOW_FULL pixels plus loin.
const FOLLOW_DEAD := 46.0
const FOLLOW_FULL := 70.0
## « moba » : distance d'arrivée, et abandon de la destination quand le héros bute (buisson, arène).
const ARRIVE := 1.0
const STUCK_TIME := 0.35
## Manette : le stick droit pousse le point visé entre PAD_AIM_NEAR et PAD_AIM_FAR pixels du héros
## (là où tombent les compétences posées au sol) ; lâché, la visée se pose sur la cible automatique.
const PAD_AIM_NEAR := 200.0
const PAD_AIM_FAR := 440.0

var main
var radius := 14.0
var hp := 100.0
var fire_cd := 0.0
## État de tir de l'attaque de base (compteur d'attaques, tirs en file), tenu par attack.gd.
var attack_rt: Dictionary = {}
var dash_cd := 0.0
var dash_time := 0.0
var dash_dir := Vector2.RIGHT
var invuln := 0.0
var still_time := 0.0
## Secondes passées à bouger sans s'arrêter (état « en_mouvement » des conditions).
var move_time := 0.0
## Ancrage (Racine) : secondes d'enracinement restantes, et part de la vitesse gardée pendant ce
## temps (0 : le héros ne marche plus). L'esquive arrache les racines (scripts/skills/ancrage.gd).
var rooted := 0.0
var rooted_walk := 0.0
## Aubier (Racine) : bouclier d'écorce laissé par les coups de l'attaque (attack.gd › _bark), bu
## après l'armure, le cocon et le bouclier d'écorce.
var bark := 0.0
var hurt_flash := 0.0
## Coups reçus punis (data/difficulty.json › punish) : secondes d'étourdissement restantes (vitesse
## réduite) et de soin bloqué restantes.
var stagger := 0.0
var heal_block := 0.0
## Secondes d'éblouissement restantes (apply_dazzle). Côté ennemis, l'état « ebloui » est autre chose.
var dazzle := 0.0
## Direction et point visés par les compétences (le curseur ; pour le robot, sa cible).
var aim := Vector2.RIGHT
var aim_point := Vector2.ZERO
## Attaque automatique : cible actuelle (voir auto_target), direction du dernier tir et temps
## depuis ce tir (le héros regarde sa cible un instant après chaque tir).
var target = null
var shot_dir := Vector2.RIGHT
var since_shot := 10.0
var _target_tick := 0
## Commandes de la barre reçues dans le monde (pas sur l'interface) : emplacements pressés
## depuis le dernier pas, et emplacements tenus (la compétence repart dès qu'elle est prête).
var _pressed := {}
var _held := {}
## Destination du mode « moba » (clic droit) et son repère au sol (move_marker.gd).
var has_dest := false
var dest := Vector2.ZERO
## Nombre de clics droits posés (le repère rejoue son « ping » à chaque nouveau clic).
var dest_clicks := 0
## Clic droit tenu dans le monde (pas sur l'interface) : la destination suit le curseur.
var _right_held := false
var _stuck := 0.0
var _expected := 0.0
var _step_start := Vector2.ZERO
## La souris a bougé dans la fenêtre depuis qu'elle y est entrée : sans cela, le héros ne la
## suit pas (pas de course vers une position périmée au lancement, ni souris hors de la fenêtre).
var mouse_live := false
## Bancs de test sans écran : position de souris imposée (dans le monde), à la place de la vraie.
var test_mouse = null
## Manette : stick droit poussé ce pas (la cible automatique se cherche alors près du point visé), et
## dernière direction visée ou marchée (visée par défaut quand rien n'est à portée).
var pad_aiming := false
var _pad_dir := Vector2.RIGHT
## Réglages des compétences actives, lus dans res://data/skills.json.
var skills: Dictionary = Content.skills()
var skill_cd: Dictionary = {}
## Objets Skill déjà chargés (id -> Skill, ou null sans fichier).
var _skill_objects: Dictionary = {}
var cds: Dictionary = {}
## Compétence de chaque emplacement de la barre ("" = vide), gardée dans Game.flags (voir sync_bar).
var bar: Array = []
var t := 0.0

# --- Animation (dessin seulement, voir HeroArt) ---
## Phase du pas, part de marche (0 → 1) et direction du déplacement, lues sur la position.
var step := 0.0
var walk := 0.0
var move_dir := Vector2.ZERO
var _last_pos := Vector2.ZERO
## Lancer de compétence : temps restant et couleur de l'élément.
var cast_anim := 0.0
var cast_col := Color(0, 0, 0, 0)
## Tir de graine (recul de la lanterne), coup reçu, renaissance.
var shoot_anim := 0.0
var hurt_anim := 0.0
var reborn := 1.0
## « Se battre chez soi », relu quatre fois par seconde.
var home := false
var _home_check := 0.0
## Feuilles semées par l'esquive et arrachées par les coups (positions dans le monde).
var leaves: Array = []
## Tirage des feuilles : à part, pour ne jamais toucher au hasard du jeu.
var _leaf_rng := RandomNumberGenerator.new()
const CAST_ANIM := 0.32
const SHOOT_ANIM := 0.12
const HURT_ANIM := 0.4
const REBIRTH_TIME := 1.1
const LOW_HP := 0.3


func _ready() -> void:
	for k in skills:
		cds[k] = 0.0
		skill_cd[k] = float(skills[k]["cooldown"])
	hp = Game.stats["max_hp"]
	Game.stats_changed.connect(func(): hp = minf(hp, Game.stats["max_hp"]))
	Game.tree_changed.connect(sync_bar)
	sync_bar()


## Réglages d'une compétence au moment du lancer, mutations de l'arbre comprises
## (Game.skill, fourni par le moteur des nœuds ; sinon les réglages de skills.json).
func skill(id: String) -> Dictionary:
	if Game.has_method("skill"):
		return Game.skill(id)
	return skills[id]


# --- Barre de compétences ---

## Nombre d'emplacements débloqués (4 au départ, jusqu'à 6 avec la statistique skill_slots).
static func unlocked_slots() -> int:
	return clampi(int(Game.stats.get("skill_slots", 4)), 1, MAX_SLOTS)


## Remet la barre d'accord avec les compétences acquises. La barre est rangée dans
## Game.flags["barre"] (texte « nova,fouet,,… ») : elle suit la sauvegarde sans en changer le format.
## Une compétence perdue libère sa place ; une compétence nouvelle prend la première place libre.
func sync_bar() -> void:
	var saved: PackedStringArray = str(Game.flags.get("barre", "")).split(",")
	var open := unlocked_slots()
	bar = []
	var placed := {}
	for i in MAX_SLOTS:
		var id := saved[i] if i < saved.size() else ""
		if i >= open or id == "" or not skills.has(id) or not Game.has_key(id) or placed.has(id):
			id = ""
		bar.append(id)
		if id != "":
			placed[id] = true
	for id in skills:
		if Game.has_key(id) and not placed.has(id):
			var free := bar.find("")
			if free < 0 or free >= open:
				break
			bar[free] = id
			placed[id] = true
	Game.flags["barre"] = ",".join(bar)


## Compétences acquises qui ne sont sur aucun emplacement.
func unbarred_skills() -> Array:
	var out: Array = []
	for id in skills:
		if Game.has_key(id) and not bar.has(id):
			out.append(id)
	return out


## Change la compétence d'un emplacement débloqué : elle prend la place de la première
## compétence acquise restée sans emplacement (celle qui était là redevient sans emplacement).
func cycle_slot(i: int) -> void:
	if i < 0 or i >= unlocked_slots():
		return
	var choices: Array = unbarred_skills()
	if choices.is_empty():
		return
	bar[i] = choices[0]
	Game.flags["barre"] = ",".join(bar)


## Échange les compétences de deux emplacements débloqués (glisser-déposer dans la barre).
func swap_slots(i: int, j: int) -> void:
	var open := unlocked_slots()
	if i == j or i < 0 or j < 0 or i >= open or j >= open:
		return
	var tmp: String = bar[i]
	bar[i] = bar[j]
	bar[j] = tmp
	Game.flags["barre"] = ",".join(bar)


## Commandes reçues dans le monde (les clics sur l'interface n'arrivent pas ici) : compétences
## de la barre, et clic droit du mode « moba » (nouvelle destination).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_live = true
		return
	for i in MAX_SLOTS:
		var action := Settings.slot_action(i)
		if InputMap.has_action(action) and event.is_action_pressed(action):
			_pressed[i] = true
			_held[i] = true
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_RIGHT:
		return
	if not mb.pressed:
		_right_held = false
		return
	mouse_live = true
	if Settings.move_mode != "moba" or main == null or main.autotest:
		return
	_right_held = true
	set_destination(mouse_world(), true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		mouse_live = false
		_right_held = false
		_held.clear()


## Lance l'emplacement i comme si sa commande venait d'être pressée (tests, raccourcis).
func trigger_slot(i: int) -> void:
	_pressed[i] = true


## Compétences voulues ce pas : emplacements pressés, ou tenus et dont la commande l'est encore.
func _wanted_skills() -> Dictionary:
	var want := {}
	for i in bar.size():
		var action := Settings.slot_action(i)
		var down := InputMap.has_action(action) and Input.is_action_pressed(action)
		if _held.has(i) and not down:
			_held.erase(i)
		if bar[i] != "" and (_pressed.has(i) or _held.has(i)):
			want[bar[i]] = true
	_pressed.clear()
	return want


func mouse_world() -> Vector2:
	return test_mouse if test_mouse != null else get_global_mouse_position()


## Pose la destination du mode « moba » (bornée au monde). click : nouveau clic (le repère pulse).
func set_destination(p: Vector2, click := false) -> void:
	var h: float = main.world_half if main != null else 1.0e9
	# Sous la graine (arène de la finale, hors du carré du monde), la destination reste dans l'arène.
	dest = main.clamp_to_world(p) if main != null and main.has_method("clamp_to_world") else p.clamp(Vector2(-h, -h), Vector2(h, h))
	has_dest = true
	_stuck = 0.0
	if click:
		dest_clicks += 1


func clear_destination() -> void:
	has_dest = false
	_right_held = false


## Mode « moba » : le héros qui n'avance presque plus vers sa destination (repoussé par un
## buisson, le mur de l'arène ou le bord du monde) l'abandonne au lieu de piétiner.
func _watch_stuck(delta: float) -> void:
	var moved := position.distance_to(_step_start)
	_step_start = position
	if not has_dest or _expected < 0.5:
		_stuck = 0.0
		return
	_stuck = _stuck + delta if moved < _expected * 0.35 else 0.0
	if _stuck >= STUCK_TIME:
		clear_destination()


## Direction de marche (longueur 0 à 1) voulue par la souris selon le mode de déplacement.
## Le clavier reste prioritaire : une touche de direction tenue annule la destination.
func mouse_move(keys: Vector2, delta: float) -> Vector2:
	if keys.length() > 0.1:
		if has_dest:
			clear_destination()
		return keys
	match Settings.move_mode:
		"curseur":
			if not mouse_live or Settings.pad_active():
				return Vector2.ZERO
			var off := aim_point - global_position
			var d := off.length()
			if d <= FOLLOW_DEAD:
				return Vector2.ZERO
			return off / d * clampf((d - FOLLOW_DEAD) / FOLLOW_FULL, 0.0, 1.0)
		"moba":
			if _right_held:
				if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
					set_destination(aim_point)
				else:
					_right_held = false
			if not has_dest:
				return Vector2.ZERO
			var off := dest - global_position
			var d := off.length()
			if d <= ARRIVE:
				clear_destination()
				return Vector2.ZERO
			# Dernier pas raccourci pour s'arrêter pile sur la destination.
			var step_len: float = maxf(Game.stats["move_speed"] * delta, 0.001)
			return off / d * minf(1.0, d / step_len)
	return keys


## Animation seulement (marche, lanterne, feuilles, états) : suit la fréquence d'affichage.
func _process(delta: float) -> void:
	t += delta
	since_shot += delta
	cast_anim = maxf(0.0, cast_anim - delta)
	shoot_anim = maxf(0.0, shoot_anim - delta)
	hurt_anim = maxf(0.0, hurt_anim - delta)
	reborn = minf(1.0, reborn + delta / REBIRTH_TIME)
	# Marche : la vitesse réelle (esquive comprise) fait avancer le pas.
	var moved := position - _last_pos
	_last_pos = position
	var speed := moved.length() / maxf(delta, 0.0001)
	if speed > 2000.0:
		speed = 0.0   # téléportation (renaissance) : pas un pas
	var target := clampf(speed / maxf(Game.stats.get("move_speed", 220.0), 1.0), 0.0, 1.0)
	walk = lerpf(walk, target, clampf(delta * 12.0, 0.0, 1.0))
	if speed > 1.0 and speed <= 2000.0:
		move_dir = moved.normalized()
		step += moved.length() / (radius * 1.6)
	_home_check -= delta
	if _home_check <= 0.0 and main != null:
		_home_check = 0.25
		home = fighting_at_home()
		_progress_states()
	# Feuilles : tombent en tournoyant, s'effacent.
	if dash_time > 0.0 and fposmod(t, 0.03) < delta:
		_leaf(position - dash_dir * radius * 0.6, -dash_dir * 60.0, 0.6, Art.c("joueur_accent").darkened(0.3))
	for l in leaves:
		l["t"] += delta
		l["pos"] += l["vel"] * delta
		l["vel"] = l["vel"] * maxf(0.0, 1.0 - 3.0 * delta) + Vector2(sin(l["t"] * 6.0 + l["ph"]) * 50.0, 30.0) * delta
		l["rot"] += l["spin"] * delta
	leaves = leaves.filter(func(l): return l["t"] < l["dur"])
	queue_redraw()


func _leaf(pos: Vector2, vel: Vector2, dur: float, col: Color) -> void:
	if leaves.size() >= 24:
		return
	leaves.append({"pos": pos, "vel": vel + Vector2.from_angle(_leaf_rng.randf() * TAU) * 30.0, "t": 0.0, "dur": dur, "col": col,
		"rot": _leaf_rng.randf() * TAU, "spin": _leaf_rng.randf_range(-6.0, 6.0), "ph": _leaf_rng.randf() * TAU})


## Signature visuelle d'une attaque (skill_fx.gd), si le jeu en a une (pas dans les bancs sans dessin).
func _sig(id: String, data := {}) -> void:
	if main != null and "skill_fx" in main and main.skill_fx != null:
		main.skill_fx.play(id, data)


## Logique à pas fixe : déplacement, tir, esquive et compétences.
func _physics_process(delta: float) -> void:
	var s: Dictionary = Game.stats
	fire_cd -= delta
	dash_cd -= delta
	invuln -= delta
	hurt_flash -= delta
	dazzle = maxf(0.0, dazzle - delta)
	stagger = maxf(0.0, stagger - delta)
	heal_block = maxf(0.0, heal_block - delta)
	for k in cds:
		cds[k] = maxf(0.0, cds[k] - delta)

	_watch_stuck(delta)
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	aim_point = mouse_world()
	pad_aiming = false
	if Settings.pad_active() and test_mouse == null and not main.autotest:
		aim_point = pad_aim_point(mv)
	var want_dash := Input.is_action_just_pressed("dash")
	var want := _wanted_skills()
	if not main.autotest:
		mv = mouse_move(mv, delta)
	if main.autotest:
		var bot: Dictionary = main.bot_input(self)
		mv = bot["move"]
		aim_point = bot["aim"]
		want_dash = bot["dash"]
		want.clear()
		# Le robot essaie toutes les compétences acquises, même sans emplacement.
		for k in skills:
			want[k] = true
	var to_aim := aim_point - global_position
	if to_aim.length() > 1.0:
		aim = to_aim.normalized()

	# Enraciné : le héros ne marche plus (ou à « rooted_walk » de sa vitesse) ; l'esquive arrache les racines.
	if rooted > 0.0:
		rooted -= delta
		if want_dash and dash_cd <= 0.0:
			uproot()
		else:
			mv *= rooted_walk

	if want_dash and dash_cd <= 0.0:
		# Au clavier, l'esquive suit la direction de marche ; à la souris, elle part vers le curseur.
		var keyboard: bool = main.autotest or Settings.move_mode == "clavier" or Settings.pad_active() or Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.1
		dash_dir = mv.normalized() if keyboard and mv.length() > 0.1 else aim
		if has_dest:
			clear_destination()
		dash_time = DASH_TIME
		dash_cd = s["dash_cd"]
		invuln = maxf(invuln, DASH_TIME + 0.08)
		Sfx.play("esquive")
		_sig("esquive", {"pos": position, "dir": dash_dir, "facing": facing().angle(), "dash": DASH_TIME, "follow": self})
		Game.fire("dash", {"main": main})

	if dash_time > 0.0:
		dash_time -= delta
		position += dash_dir * DASH_SPEED * delta
	else:
		position += mv * s["move_speed"] * (DAZZLE_SLOW if dazzle > 0.0 else 1.0) * stagger_slow() * delta
	if main.has_method("clamp_to_world"):
		position = main.clamp_to_world(position)
	else:
		var h: float = main.world_half
		position = position.clamp(Vector2(-h, -h), Vector2(h, h))
	_expected = 0.0 if dash_time > 0.0 else mv.length() * s["move_speed"] * delta

	still_time = still_time + delta if mv.length() < 0.1 else 0.0
	move_time = 0.0 if still_time > 0.0 else move_time + delta
	Game.set_state("immobile", still_time)
	# États lus par les conditions des frontières hybrides (Sève et Vent).
	Game.set_state("en_mouvement", move_time)
	var cocoon = _skill_objects.get("cocon")
	Game.set_state("sous_cocon", 1.0 if cocoon != null and is_instance_valid(cocoon) and cocoon.shield > 0.0 else 0.0)
	# États de Racine : enraciné (Ancrage), sous un bouclier d'écorce.
	Game.set_state("enracine", 1.0 if rooted > 0.0 else 0.0)
	var bark_skill = _skill_objects.get("ecorce")
	Game.set_state("sous_ecorce", 1.0 if bark_skill != null and bark_skill.shield > 0.0 else 0.0)
	# Nœuds originaux (jalon 11) : sous la moitié de la vie.
	Game.set_state("vie_basse", 1.0 if hp <= 0.5 * s["max_hp"] else 0.0)
	s = Game.stats

	# La terre vivante soigne : régénération triplée sur l'herbe.
	var regen: float = s["regen"]
	if main.ground.life_at(position) > 0.45:
		regen *= 3.0
	heal(regen * delta)

	# Attaque automatique : même chemin pour le joueur et le robot.
	if target != null and (not is_instance_valid(target) or target.dead):
		target = null
	_target_tick -= 1
	if _target_tick <= 0 or (fire_cd <= 0.0 and target != null):
		_target_tick = TARGET_EVERY
		target = auto_target()
	AttackScript.step(self, delta)
	if fire_cd <= 0.0:
		# Mode « curseur » : la visée suit la souris (pas de cible) ; sinon, la cible automatique.
		var shot := {}
		if Settings.aim_mode == "curseur" and not main.autotest:
			shot = AttackScript.fire(self, null)
		elif target != null:
			shot = AttackScript.fire(self, target)
		if not shot.is_empty():
			fire_cd = AttackScript.interval(s)
			shot_dir = shot["dir"]   # le héros se tourne vers son tir (_facing)
			since_shot = 0.0

	for k in want:
		if Game.has_key(k) and cds.get(k, 1.0) <= 0.0:
			cast(k, s)
	_tick_skills(delta)


## Lance une compétence (sa recharge est remise à plein).
func cast(id: String, s: Dictionary) -> void:
	skill_cd[id] = maxf(0.05, float(skill(id)["cooldown"]))
	cds[id] = skill_cd[id]
	cast_anim = CAST_ANIM
	cast_col = Art.ec(Art.ELEMENT_DE_COMPETENCE.get(id, "seve"))
	var obj = skill_object(id)
	if obj != null:
		obj.cast(self, s)
	# Son choisi par les données (skills.json › « sound »), pour les compétences dont le script n'en joue pas.
	var snd := str(skill(id).get("sound", ""))
	if snd != "":
		Sfx.play(snd, position)


## Registre des compétences : l'objet Skill de scripts/skills/<id>.gd, chargé la première fois.
## null (et un avertissement) si la compétence n'a pas de fichier.
func skill_object(id: String):
	if not _skill_objects.has(id):
		var path := SKILLS_DIR + id + ".gd"
		var obj = null
		if ResourceLoader.exists(path):
			obj = load(path).new()
			obj.id = id
			obj.player = self
		else:
			push_warning("Compétence sans comportement : " + id)
		_skill_objects[id] = obj
	return _skill_objects[id]


## Fait avancer d'un pas les compétences déjà chargées (Skill.tick) : celles qu'on a lancées, et
## celles dont un effet a fait naître quelque chose (une tornade semée par une greffe de Vent).
func _tick_skills(delta: float) -> void:
	for k in _skill_objects.keys():
		var obj = _skill_objects[k]
		if obj != null:
			obj.tick(delta)


func current_damage() -> float:
	return Game.stats["damage"]


## Dégâts d'une compétence : dégâts de base × facteur de la compétence × statistiques de ses
## familles (corps à corps, projectile, zone) × bonus « se battre chez soi ».
func skill_damage(id: String) -> float:
	return current_damage() * float(skill(id).get("damage", 1.0)) * skill_multiplier(id)


## Multiplicateur des familles d'attaque de la compétence et du bonus « se battre chez soi ».
func skill_multiplier(id: String) -> float:
	var k: Dictionary = skill(id)
	var s: Dictionary = Game.stats
	var m := 1.0
	for tag in k.get("tags", []):
		m *= float(s.get(TAG_STATS.get(tag, ""), 1.0))
	if fighting_at_home(str(k.get("branch", ""))):
		m *= 1.0 + HOME_BONUS
	return m


## Vrai sur une terre ravivée de la région de cette branche de l'arbre (main.region_at ; sans
## scène de jeu, jamais) : chaque branche se bat mieux chez elle.
## États lus par les nœuds originaux (jalon 11), relus quatre fois par seconde : terre vivante ou
## flétrie sous les pieds, greffes posées dans la couronne, Cœurs purifiés dans tout le monde.
func _progress_states() -> void:
	if main.get("ground") != null and main.ground.has_method("life_at"):
		var life: float = main.ground.life_at(position)
		Game.set_state("terre_vive", 1.0 if life > HOME_LIFE else 0.0)
		Game.set_state("terre_fletrie", 1.0 if life < 0.15 else 0.0)
	Game.set_state("greffes", float(Game.placed_grafts().size()))
	var hearts := 0
	for id in Regions.ids():
		hearts += Regions.hearts_done(id, Game.flags)
	Game.set_state("coeurs_purifies", float(hearts))


func fighting_at_home(branch := "ronce") -> bool:
	if branch == "" or not main.has_method("region_at"):
		return false
	var reg: String = main.region_at(position)
	return reg != "" and Regions.branch_of(reg) == branch and main.ground.life_at(position) > HOME_LIFE


## Portée de l'attaque automatique : celle de la forme d'attaque actuelle (Attack.reach,
## 704 px pour la graine, bien moins pour le fouet).
func attack_range() -> float:
	return AttackScript.reach()


## L'ennemi visé par l'attaque de base, ou null : parmi les ennemis à portée, le plus proche du
## curseur (pour le robot, de son point visé) ; à défaut de curseur (souris pas encore bougée
## dans la fenêtre), le plus proche du héros. La cible actuelle reste visée tant qu'une autre
## n'est pas nettement plus proche (TARGET_STICK).
func auto_target():
	if main == null:
		return null
	var cursor_known: bool = main.autotest or test_mouse != null or (pad_aiming if Settings.pad_active() else mouse_live)
	var from: Vector2 = aim_point if cursor_known else global_position
	var best = null
	var best_d := INF
	var keep := INF
	for e in main.enemies_near(global_position, attack_range()):
		if e.dead or (e.has_method("hidden") and e.hidden()):
			continue
		var d: float = e.position.distance_squared_to(from)
		if e == target:
			keep = d
		if d < best_d:
			best_d = d
			best = e
	if keep < INF and best_d >= keep * TARGET_STICK * TARGET_STICK:
		return target
	return best


## Point visé à la manette (mv : stick gauche) : le stick droit le pousse autour du héros ; lâché, il
## se pose sur la cible automatique, à défaut devant le héros (dernière direction visée ou marchée).
func pad_aim_point(mv: Vector2) -> Vector2:
	var r := Settings.stick("aim")
	if r.length() > 0.0:
		pad_aiming = true
		_pad_dir = r.normalized()
		return global_position + _pad_dir * lerpf(PAD_AIM_NEAR, PAD_AIM_FAR, clampf(r.length(), 0.0, 1.0))
	if target != null and is_instance_valid(target) and not target.dead:
		return target.position
	if mv.length() > 0.1:
		_pad_dir = mv.normalized()
	return global_position + _pad_dir * PAD_AIM_NEAR


## Ébloui « dur » secondes : il marche moins vite (DAZZLE_SLOW) et l'écran blanchit, puis revient.
func apply_dazzle(dur: float) -> void:
	dazzle = maxf(dazzle, dur)
	if main != null and main.get("screen_fx") != null:
		main.screen_fx.fade(Color(1.0, 0.97, 0.86), 0.6, 0.0, dur)


## Soigne le héros. Un coup reçu bloque le soin un instant (« heal_block ») ; « force » (sanctuaire,
## montée de niveau) passe outre.
func heal(v: float, force := false) -> void:
	if heal_block > 0.0 and not force:
		return
	hp = minf(Game.stats["max_hp"], hp + v)


## Part de vitesse gardée pendant l'étourdissement d'un coup reçu (1 = pas étourdi).
func stagger_slow() -> float:
	return float(Difficulty.punish().get("stagger_speed", 1.0)) if stagger > 0.0 else 1.0


## Multiplicateur des dégâts reçus : monte avec le niveau et les Cœurs purifiés.
func _punish_damage_mult(pz: Dictionary) -> float:
	return 1.0 + float(pz.get("damage_per_level", 0.0)) * (Game.level - 1) \
		+ float(pz.get("damage_per_heart", 0.0)) * main.hearts_purified()


## Un vrai coup (pas une brûlure) : étourdit s'il est gros, recule, fait perdre de la sève et
## bloque le soin. Retour visuel et sonore dans fx.player_punished.
func _punish(taken: float, source, pz: Dictionary) -> void:
	var s: Dictionary = Game.stats
	var frac: float = taken / maxf(s["max_hp"], 1.0)
	# Un coup mortel a sa propre règle (la sève tombe au sol, player_died).
	if hp <= 0.0 or frac < float(pz.get("min_frac", 0.0)):
		return
	var boss_k := 1.0
	if source is Object and is_instance_valid(source) and source.get("phase") != null:
		boss_k = float(pz.get("boss", 1.0))
	var stunned: bool = frac * boss_k >= float(pz.get("stagger_min", 1.0)) and dash_time <= 0.0
	if stunned:
		stagger = maxf(stagger, float(pz.get("stagger", 0.0)))
		if source is Object and is_instance_valid(source) and "position" in source:
			var away: Vector2 = (position - source.position).normalized()
			position += away * float(pz.get("recoil", 0.0))
	var lost := 0.0
	var loss := float(pz.get("sap_loss", 0.0)) * boss_k
	if loss > 0.0 and Game.xp > 0.0:
		lost = minf(Game.xp, Game.xp_to_next() * loss)
		Game.xp -= lost
	var block := float(pz.get("heal_block", 0.0))
	if block > 0.0:
		heal_block = maxf(heal_block, block)
	main.fx.player_punished(position, stunned, lost, block > 0.0)


func take_hit(amount: float, source) -> void:
	if invuln > 0.0 or hp <= 0.0:
		return
	var s: Dictionary = Game.stats
	var armor: float = s["armor"]
	# Perce-armure (Scarabée perce-écorce, Ancien pétrifié) : une part de l'armure est ignorée.
	if source is Object and is_instance_valid(source):
		var pierce = source.get("armor_pierce")
		if pierce != null:
			armor *= 1.0 - clampf(float(pierce), 0.0, 1.0)
	var pz: Dictionary = Difficulty.punish()
	var taken: float = amount * (1.0 - armor) * _punish_damage_mult(pz)
	# Cocon de sève : le bouclier boit le coup d'abord (scripts/skills/cocon.gd).
	var cocoon = _skill_objects.get("cocon")
	if cocoon != null and cocoon.shield > 0.0:
		taken = cocoon.absorb(taken, source)
		if taken <= 0.0:
			invuln = 0.2
			return
	# Bouclier d'écorce, puis Aubier (Racine) : l'écorce boit ce qui reste du coup.
	taken = _bark_absorb(taken, source)
	if taken <= 0.0:
		invuln = 0.2
		return
	hp -= taken
	hurt_flash = 0.15
	hurt_anim = HURT_ANIM
	# Deux feuilles de la cape arrachées par le coup.
	var away := aim
	if is_instance_valid(source) and "position" in source:
		away = (position - source.position).normalized()
	for i in 2:
		_leaf(position - aim * radius * 0.8, away * 90.0 + Vector2(0, -40.0), 0.8, Art.c("joueur_accent").darkened(0.3))
	Sfx.play("degats")
	invuln = 0.35
	main.fx.player_hurt(taken / maxf(s["max_hp"], 1.0), taken, position)
	_punish(taken, source, pz)
	Game.fire("hurt", {"main": main, "base": amount})
	if s["thorns"] > 0.0 and is_instance_valid(source) and not source.dead:
		source.take_damage(s["thorns"] * main.branch_factor(source, "ronce"), false)
	if hp <= 0.0:
		if not Game.fire("lethal_hit", {"main": main}):
			main.player_died()


## Écorce (Racine) : le bouclier d'écorce (scripts/skills/ecorce.gd) boit le coup, puis la
## réserve « bark » de l'Aubier. Renvoie ce qui passe.
func _bark_absorb(taken: float, source) -> float:
	var shell = _skill_objects.get("ecorce")
	if shell != null and shell.shield > 0.0:
		taken = shell.absorb(taken, source)
	if bark > 0.0 and taken > 0.0:
		var took := minf(bark, taken)
		bark -= took
		taken -= took
	return taken


## Ancrage (Racine) : le héros prend racine « dur » secondes ; « walk » : part de sa vitesse gardée.
func take_root(dur: float, walk := 0.0) -> void:
	rooted = maxf(rooted, dur)
	rooted_walk = clampf(walk, 0.0, 1.0)


## Arrache les racines de l'Ancrage (esquive, mort).
func uproot() -> void:
	if rooted <= 0.0:
		return
	rooted = 0.0
	var anchor = _skill_objects.get("ancrage")
	if anchor != null:
		anchor.release()


func respawn(at := Vector2.ZERO) -> void:
	# Il se fane là où il est tombé, puis renaît en pousse au sanctuaire.
	_sig("chute", {"pos": position, "facing": aim.angle()})
	uproot()
	bark = 0.0
	position = at
	_last_pos = at
	_step_start = at
	clear_destination()
	reborn = 0.0
	leaves.clear()
	hp = Game.stats["max_hp"]
	invuln = 2.0


## Regard du héros : vers sa cible juste après un tir automatique, sinon vers le curseur
## (le lancer d'une compétence reprend aussitôt le curseur).
func facing() -> Vector2:
	if since_shot < 0.45 and cast_anim <= 0.0:
		return shot_dir
	return aim


## Pose actuelle du héros pour HeroArt (états lus sur le jeu, sans le modifier).
func pose() -> Dictionary:
	var ratio: float = clampf(hp / maxf(Game.stats["max_hp"], 1.0), 0.0, 1.0)
	var sq := Vector2.ONE
	if hurt_anim > 0.0:
		var k := 1.0 - hurt_anim / HURT_ANIM
		sq = Anim.squash(clampf(Anim.SQUASH_ANTICIPATION + k * (1.0 - Anim.SQUASH_ANTICIPATION), 0.0, 1.0), 0.8)
	elif cast_anim > 0.0:
		sq = Anim.squash(1.0 - cast_anim / CAST_ANIM, 0.7)
	return {
		"t": t, "walk": walk, "step": step, "move": move_dir, "squash": sq,
		"hurt": Anim.flash(1.0 - hurt_anim / HURT_ANIM) if hurt_anim > 0.0 else 0.0,
		"cast": cast_anim / CAST_ANIM, "cast_col": cast_col,
		"shoot": shoot_anim / SHOOT_ANIM,
		"low": clampf((LOW_HP - ratio) / LOW_HP * 2.0, 0.0, 1.0) if ratio < LOW_HP and hp > 0.0 else 0.0,
		# Le voile n'apparaît que pour une vraie protection (renaissance, bonus), pas pour le
		# court répit qui suit chaque coup ou esquive.
		"invuln": clampf((invuln - 0.45) * 2.0, 0.0, 1.0),
		"home": home, "appear": reborn,
		"dash": clampf(dash_time / DASH_TIME, 0.0, 1.0),
	}


func _draw() -> void:
	# Feuilles semées (esquive, coups) : sous le héros, dans le repère du monde.
	for l in leaves:
		var k: float = l["t"] / l["dur"]
		var q: Vector2 = l["pos"] - position
		var a: float = l["rot"]
		var w := 0.35 + 0.65 * absf(sin(a))
		var pts := HeroArt.leaf_pts(q, 5.0, a)
		for i in pts.size():
			pts[i] = q + (pts[i] - q) * Vector2(1.0, w).rotated(0.0)
		draw_colored_polygon(pts, Color(l["col"], 1.0 - k * k))
	# L'élan de l'esquive (traînée, images rémanentes) est dessiné par sa signature (skill_fx.gd).
	HeroArt.draw(self, Vector2.ZERO, radius, facing().angle(), pose())
	if pad_aiming:
		# Visée au stick droit : un petit chevron d'or au point visé, sans masquer le jeu.
		var q := aim_point - position
		var d := q.normalized()
		var side := d.orthogonal() * 7.0
		var ink := Color(Art.c("or"), 0.8)
		draw_polyline(PackedVector2Array([q - d * 6.0 + side, q, q - d * 6.0 - side]), ink, 2.0, true)
		draw_arc(q, 11.0, 0.0, TAU, 20, Color(ink, 0.35), 1.2, true)
	if dazzle > 0.0:
		# Ébloui : des rais de lumière tournent autour de sa tête.
		var head := Vector2(0, -radius * 1.6)
		for i in 4:
			var a := t * 3.0 + i * TAU / 4.0
			var d := Vector2.from_angle(a)
			draw_line(head + d * radius * 0.35, head + d * radius * 0.8, Color(1.0, 0.95, 0.7, minf(1.0, dazzle * 2.0)), Art.TRAIT_FIN, true)
	# Barre de vie : fine, sous les pieds, cachée quand la vie est pleine.
	var ratio: float = clampf(hp / Game.stats["max_hp"], 0.0, 1.0)
	if ratio < 0.999 and reborn >= 1.0:
		var w := 36.0
		var y := radius + 14.0
		draw_rect(Rect2(-w / 2.0 - 1.0, y - 1.0, w + 2.0, 6.0), Art.c("contour"))
		draw_rect(Rect2(-w / 2.0, y, w * ratio, 4.0), Art.c("danger") if ratio < LOW_HP else Art.c("accent"))
		draw_rect(Rect2(-w / 2.0, y, w * ratio, 1.5), Color(1, 1, 1, 0.25))
