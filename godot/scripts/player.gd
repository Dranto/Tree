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
## Dernier coup de fouet, pour le dessin de l'arc (secondes restantes, direction).
var whip_time := 0.0
var whip_dir := Vector2.RIGHT
var t := 0.0


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


## Animation seulement (halo, clignotement, arc du fouet) : suit la fréquence d'affichage.
func _process(delta: float) -> void:
	t += delta
	whip_time -= delta
	queue_redraw()


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


func _cast_nova(s: Dictionary) -> void:
	var k: Dictionary = skill("nova")
	var r: float = k["radius"] * s["area"]
	Sfx.play("nova")
	main.fx.ring(position, 20.0, r, 0.4, Color(k["color"]), 8.0)
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


func _cast_bloom(s: Dictionary) -> void:
	var k: Dictionary = skill("bloom")
	Sfx.play("floraison")
	heal(s["max_hp"] * k["heal"])
	var r: float = k["radius"] * s["area"]
	main.fx.ring(position, 20.0, r, 0.6, Color(k["color"]), 8.0)
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
	whip_time = 0.18
	whip_dir = aim
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
	var col := Color(k["color"])
	main.fx.ring(target, r * 0.2, r, 0.5, col, 6.0)
	main.fx.ring(target, r * 0.9, r, 0.9, col.darkened(0.3), 3.0)
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
	var col := Color(k["color"])
	main.fx.ring(position, r, 30.0, 0.35, col, 6.0)
	var hit := skill_damage("saignee")
	# Le multiplicateur des dégâts de zone et le bonus « chez soi » s'appliquent aussi à l'éclatement.
	var mult: float = float(k["burst"]) * skill_multiplier("saignee")
	var total := 0.0
	for e in main.enemies_near(position, r):
		# L'éclatement est un coup de Ronce : les ennemis du roncier y résistent aussi.
		var amount: float = e.burst_bleed(mult) * main.branch_factor(e, "ronce")
		if amount > 0.0:
			main.fx.ring(e.position, e.radius, e.radius * 2.2, 0.3, col.lightened(0.2), 4.0)
			e.take_damage(amount, false)
			total += amount
			main.on_bleed_tick(e, amount)
		if not e.dead:
			main.player_hit_enemy(e, hit, true, "ronce")
	if total > 0.0:
		heal(total * float(k["heal"]))


func heal(v: float) -> void:
	hp = minf(Game.stats["max_hp"], hp + v)


func take_hit(amount: float, source) -> void:
	if invuln > 0.0 or hp <= 0.0:
		return
	var s: Dictionary = Game.stats
	hp -= amount * (1.0 - s["armor"])
	hurt_flash = 0.15
	Sfx.play("degats")
	invuln = 0.35
	main.fx.player_hurt()
	Game.fire("hurt", {"main": main, "base": amount})
	if s["thorns"] > 0.0 and is_instance_valid(source) and not source.dead:
		source.take_damage(s["thorns"] * main.branch_factor(source, "ronce"), false)
	if hp <= 0.0:
		if not Game.fire("lethal_hit", {"main": main}):
			main.player_died()


func respawn(at := Vector2.ZERO) -> void:
	position = at
	hp = Game.stats["max_hp"]
	invuln = 2.0


func _draw() -> void:
	# Ombre au sol
	draw_set_transform(Vector2(0, radius * 0.75), 0.0, Vector2(1.0, 0.36))
	draw_circle(Vector2.ZERO, radius * 1.15, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
	# Arc du fouet : une traînée d'épines qui balaie devant le joueur.
	if whip_time > 0.0:
		var k: Dictionary = skill("fouet")
		var reach: float = k["range"] * Game.stats.get("area", 1.0)
		var arc: float = k["arc"]
		var a0 := whip_dir.angle() - arc / 2.0
		var sweep := 1.0 - whip_time / 0.18
		var a1 := a0 + arc * clampf(sweep * 1.4, 0.0, 1.0)
		var col := Color(Color(k["color"]).lightened(0.25), clampf(whip_time / 0.12, 0.0, 1.0))
		draw_arc(Vector2.ZERO, reach * 0.92, a0, a1, 24, col, 7.0)
		draw_arc(Vector2.ZERO, reach * 0.7, a0, a1, 18, Color(col, col.a * 0.5), 3.0)
	# Barre de vie
	var ratio: float = clampf(hp / Game.stats["max_hp"], 0.0, 1.0)
	draw_rect(Rect2(-20, radius + 10, 40, 4), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-20, radius + 10, 40 * ratio, 4), Color("7fd36b"))
