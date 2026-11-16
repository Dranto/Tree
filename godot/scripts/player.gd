## Le Porte-Graine : déplacement, tir de graines, esquive et compétences actives.
extends Node2D

const DASH_SPEED := 950.0
const DASH_TIME := 0.16
## Barre de compétences : MAX_SLOTS emplacements, dont Game.stats["skill_slots"] débloqués.
const MAX_SLOTS := 6
## « Se battre chez soi » : bonus des compétences de Ronce sur une terre ravivée de sa région.
const HOME_BONUS := 0.15
const HOME_LIFE := 0.45
## Statistique de dégâts de chaque famille d'attaque (champ « tags » de skills.json).
const TAG_STATS := {"corps_a_corps": "melee_damage", "projectile": "projectile_damage", "zone": "area_damage"}
const Content = preload("res://scripts/content.gd")

var main
var radius := 14.0
var hp := 100.0
var fire_cd := 0.0
var dash_cd := 0.0
var dash_time := 0.0
var dash_dir := Vector2.RIGHT
var invuln := 0.0
var still_time := 0.0
var hurt_flash := 0.0
var aim := Vector2.RIGHT
var aim_point := Vector2.ZERO
## Réglages des compétences actives, lus dans res://data/skills.json.
var skills: Dictionary = Content.skills()
var skill_cd: Dictionary = {}
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


## Animation seulement (marche, lanterne, feuilles, états) : suit la fréquence d'affichage.
func _process(delta: float) -> void:
	t += delta
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
	for k in cds:
		cds[k] = maxf(0.0, cds[k] - delta)

	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	aim_point = get_global_mouse_position()
	var want_attack := Input.is_action_pressed("attack")
	var want_dash := Input.is_action_just_pressed("dash")
	var want := {}
	for i in bar.size():
		if bar[i] != "" and Input.is_action_just_pressed("slot_%d" % (i + 1)):
			want[bar[i]] = true
	if main.autotest:
		var bot: Dictionary = main.bot_input(self)
		mv = bot["move"]
		aim_point = bot["aim"]
		want_attack = true
		want_dash = bot["dash"]
		# Le robot essaie toutes les compétences acquises, même sans emplacement.
		for k in skills:
			want[k] = true
	var to_aim := aim_point - global_position
	if to_aim.length() > 1.0:
		aim = to_aim.normalized()

	if want_dash and dash_cd <= 0.0:
		dash_dir = mv.normalized() if mv.length() > 0.1 else aim
		dash_time = DASH_TIME
		dash_cd = s["dash_cd"]
		invuln = maxf(invuln, DASH_TIME + 0.08)
		Sfx.play("esquive")
		Game.fire("dash", {"main": main})

	if dash_time > 0.0:
		dash_time -= delta
		position += dash_dir * DASH_SPEED * delta
	else:
		position += mv * s["move_speed"] * delta
	var h: float = main.world_half
	position = position.clamp(Vector2(-h, -h), Vector2(h, h))

	still_time = still_time + delta if mv.length() < 0.1 else 0.0
	Game.set_state("immobile", still_time)
	s = Game.stats

	# La terre vivante soigne : régénération triplée sur l'herbe.
	var regen: float = s["regen"]
	if main.ground.life_at(position) > 0.45:
		regen *= 3.0
	heal(regen * delta)

	if want_attack and fire_cd <= 0.0:
		_shoot(s)
		fire_cd = 1.0 / s["fire_rate"]

	for k in want:
		if Game.has_key(k) and cds.get(k, 1.0) <= 0.0:
			cast(k, s)


## Lance une compétence (sa recharge est remise à plein).
func cast(id: String, s: Dictionary) -> void:
	skill_cd[id] = maxf(0.05, float(skill(id)["cooldown"]))
	cds[id] = skill_cd[id]
	cast_anim = CAST_ANIM
	cast_col = Art.ec(Art.ELEMENT_DE_COMPETENCE.get(id, "seve"))
	match id:
		"nova": _cast_nova(s)
		"cloud": _cast_cloud(s)
		"bloom": _cast_bloom(s)
		"fouet": _cast_fouet(s)
		"racines": _cast_racines(s)
		"volee": _cast_volee(s)
		"saignee": _cast_saignee(s)
		_: push_warning("Compétence sans comportement : " + id)


func current_damage() -> float:
	return Game.stats["damage"]


## Dégâts d'une compétence : dégâts de base × facteur de la compétence × statistiques de ses
## familles (corps à corps, projectile, zone) × bonus « se battre chez soi » pour Ronce.
func skill_damage(id: String) -> float:
	return current_damage() * float(skill(id).get("damage", 1.0)) * skill_multiplier(id)


## Multiplicateur des familles d'attaque de la compétence et du bonus « se battre chez soi ».
func skill_multiplier(id: String) -> float:
	var k: Dictionary = skill(id)
	var s: Dictionary = Game.stats
	var m := 1.0
	for tag in k.get("tags", []):
		m *= float(s.get(TAG_STATS.get(tag, ""), 1.0))
	if k.get("branch", "") == "ronce" and fighting_at_home():
		m *= 1.0 + HOME_BONUS
	return m


## Vrai sur une terre ravivée de la région de Ronce (main.region_at, fourni avec la région ;
## sans elle, jamais).
func fighting_at_home() -> bool:
	if not main.has_method("region_at"):
		return false
	return main.region_at(position) == "ronce" and main.ground.life_at(position) > HOME_LIFE


func _shoot(s: Dictionary) -> void:
	Sfx.play("tir")
	var n: int = s["projectiles"]
	var spread := 0.14
	for i in n:
		var a := aim.angle() + (i - (n - 1) / 2.0) * spread
		var dir := Vector2.from_angle(a)
		main.spawn_projectile(position + dir * 18.0, dir * 640.0, current_damage() * s["projectile_damage"], s["pierce"], s["projectile_size"])
	shoot_anim = SHOOT_ANIM
	_sig("graine_depart", {"pos": position + aim * radius * 1.5, "dir": aim})


func _cast_nova(s: Dictionary) -> void:
	var k: Dictionary = skill("nova")
	var r: float = k["radius"] * s["area"]
	Sfx.play("nova")
	_sig("nova", {"pos": position, "r": r})
	main.fx.shake(0.25)
	main.damage_area(position, r, skill_damage("nova"), k["knockback"], "ronce")


func _cast_cloud(s: Dictionary) -> void:
	var k: Dictionary = skill("cloud")
	var target := aim_point
	var off := target - position
	if off.length() > k["range"]:
		target = position + off.normalized() * k["range"]
	var per_factor := current_damage() * skill_multiplier("cloud")
	Sfx.play("nuage")
	main.fx.cloud(target, k["radius"] * s["area"], k["duration"], per_factor * (k["damage"] + s["poison"]))
	if "skill_fx" in main and main.skill_fx != null:
		main.fx.clouds[-1]["dessin"] = "skill_fx"   # le nuage est dessiné par sa signature
	_sig("cloud", {"pos": target, "r": k["radius"] * s["area"], "dur": float(k["duration"])})


func _cast_bloom(s: Dictionary) -> void:
	var k: Dictionary = skill("bloom")
	Sfx.play("floraison")
	heal(s["max_hp"] * k["heal"])
	var r: float = k["radius"] * s["area"]
	_sig("bloom", {"pos": position, "r": r, "follow": self})
	main.fx.shake(0.3)
	main.damage_area(position, r, skill_damage("bloom"), k["knockback"])
	main.ground.paint(position, r, k["life"])
	main.flora.spawn_patch(position, r * 0.8, 10, Color(k["color"]))


## Fouet : arc devant le joueur. Chaque ennemi touché saigne et déclenche « melee_hit ».
func _cast_fouet(s: Dictionary) -> void:
	Sfx.play("fouet")
	var k: Dictionary = skill("fouet")
	var reach: float = k["range"] * s["area"]
	var half_arc: float = k["arc"] / 2.0
	_sig("fouet", {"pos": position, "dir": aim, "r": reach, "arc": float(k["arc"]), "follow": self})
	var base := skill_damage("fouet")
	for e in main.enemies_near(position, reach):
		var d: Vector2 = e.position - position
		if d.length() > 1.0 and absf(aim.angle_to(d)) > half_arc + e.radius / maxf(d.length(), 1.0):
			continue
		main.player_hit_enemy(e, base, true, "ronce")
		if e.dead:
			continue
		e.apply_status("saignement", base * k["bleed"], k["bleed_duration"] * s["bleed_duration"])
		if d.length() > 0.1:
			e.position += d.normalized() * k["knockback"]
		main.on_melee_hit(e, base)


## Racines : à l'endroit visé, blessent et immobilisent les ennemis de la zone.
func _cast_racines(s: Dictionary) -> void:
	Sfx.play("racines")
	var k: Dictionary = skill("racines")
	var target := aim_point
	var off := target - position
	if off.length() > k["range"]:
		target = position + off.normalized() * k["range"]
	var r: float = k["radius"] * s["area"]
	var hold: float = minf(float(k["root_duration"]) * s["root_duration"], 3.0)
	_sig("racines", {"pos": target, "r": r, "dur": 0.3 + hold + 0.35, "seed": int(t * 1000.0) + 1})
	var base := skill_damage("racines")
	main.root_hit_base = base
	for e in main.enemies_near(target, r):
		main.player_hit_enemy(e, base, true, "ronce")
		if not e.dead:
			e.apply_status("enracine", 1.0, k["root_duration"] * s["root_duration"])
	main.root_hit_base = 0.0


## Volée d'épines : un éventail d'épines perforantes, chacune fait saigner ce qu'elle touche.
func _cast_volee(s: Dictionary) -> void:
	Sfx.play("volee")
	var k: Dictionary = skill("volee")
	var n: int = maxi(1, int(k["count"]))
	var spread: float = k["spread"]
	var dmg := skill_damage("volee")
	_sig("volee", {"pos": position, "dir": aim, "spread": spread, "count": n})
	for i in n:
		var a: float = aim.angle()
		if n > 1:
			a += (i / float(n - 1) - 0.5) * spread
		var dir := Vector2.from_angle(a)
		var pr = main.spawn_projectile(position + dir * 18.0, dir * float(k["speed"]), dmg, int(k["pierce"]) + int(s["pierce"]), s["projectile_size"])
		pr.thorn = true
		pr.color = Color(k["color"])
		pr.bleed = float(k["bleed"])
		pr.bleed_duration = float(k["bleed_duration"]) * s["bleed_duration"]


## Saignée : chaque ennemi proche qui saigne voit ses saignements éclater d'un coup
## (burst × dégâts restants) ; une part de ces dégâts soigne le joueur.
func _cast_saignee(s: Dictionary) -> void:
	Sfx.play("saignee")
	var k: Dictionary = skill("saignee")
	var r: float = k["radius"] * s["area"]
	var hit := skill_damage("saignee")
	# Le multiplicateur des dégâts de zone et le bonus « chez soi » s'appliquent aussi à l'éclatement.
	var mult: float = float(k["burst"]) * skill_multiplier("saignee")
	var total := 0.0
	var bled: Array = []
	for e in main.enemies_near(position, r):
		# L'éclatement est un coup de Ronce : les ennemis du roncier y résistent aussi.
		var amount: float = e.burst_bleed(mult) * main.branch_factor(e, "ronce")
		if amount > 0.0:
			if bled.size() < 12:
				bled.append(e.position)
			e.take_damage(amount, false)
			total += amount
			main.on_bleed_tick(e, amount)
		if not e.dead:
			main.player_hit_enemy(e, hit, true, "ronce")
	_sig("saignee", {"pos": position, "r": r, "targets": bled, "follow": self})
	if total > 0.0:
		heal(total * float(k["heal"]))


func heal(v: float) -> void:
	hp = minf(Game.stats["max_hp"], hp + v)


func take_hit(amount: float, source) -> void:
	if invuln > 0.0 or hp <= 0.0:
		return
	var s: Dictionary = Game.stats
	var taken: float = amount * (1.0 - s["armor"])
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
	Game.fire("hurt", {"main": main, "base": amount})
	if s["thorns"] > 0.0 and is_instance_valid(source) and not source.dead:
		source.take_damage(s["thorns"] * main.branch_factor(source, "ronce"), false)
	if hp <= 0.0:
		if not Game.fire("lethal_hit", {"main": main}):
			main.player_died()


func respawn(at := Vector2.ZERO) -> void:
	# Il se fane là où il est tombé, puis renaît en pousse au sanctuaire.
	_sig("chute", {"pos": position, "facing": aim.angle()})
	position = at
	_last_pos = at
	reborn = 0.0
	leaves.clear()
	hp = Game.stats["max_hp"]
	invuln = 2.0


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
	if dash_time > 0.0:
		# Silhouettes fantômes de l'élan.
		for i in 3:
			var q := -dash_dir * (i + 1) * 13.0
			draw_circle(q, radius * (0.85 - i * 0.18), Color(Art.ec("seve"), 0.22 - i * 0.06))
	HeroArt.draw(self, Vector2.ZERO, radius, aim.angle(), pose())
	# Barre de vie : fine, sous les pieds, cachée quand la vie est pleine.
	var ratio: float = clampf(hp / Game.stats["max_hp"], 0.0, 1.0)
	if ratio < 0.999 and reborn >= 1.0:
		var w := 36.0
		var y := radius + 14.0
		draw_rect(Rect2(-w / 2.0 - 1.0, y - 1.0, w + 2.0, 6.0), Art.c("contour"))
		draw_rect(Rect2(-w / 2.0, y, w * ratio, 4.0), Art.c("danger") if ratio < LOW_HP else Art.c("accent"))
		draw_rect(Rect2(-w / 2.0, y, w * ratio, 1.5), Color(1, 1, 1, 0.25))
