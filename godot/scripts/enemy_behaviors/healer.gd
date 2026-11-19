## Souche gorgée (vallée de Sève) : lente et lourde, elle reste un peu en retrait (« keep_back »)
## et soigne les Flétris autour d'elle : elle se gonfle de sève (« windup », un cercle vert au sol,
## pas rouge : ce n'est pas un coup), puis rend à chacun « heal » de sa vie dans « aura ». Elle frappe
## au contact. La tuer d'abord, ou tirer les autres hors de son cercle.
## Une Souche ne soigne ni elle-même ni une autre Souche : plusieurs Souches réunies se soignaient
## sans fin et devenaient intuables en début de partie, jusque dans les régions voisines.
extends EnemyBehavior


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	if e.state == "windup":
		e.state_t -= delta
		if e.state_t <= 0.0:
			e.state = ""
			e.cd = float(data["cooldown"]) * e.cd_mult
			e.strike_t = 0.0
			mend(e)
		return
	if e.cd <= 0.0 and wounded_near(e) > 0:
		e.state = "windup"
		e.state_t = data["windup"]
		return
	if dist > float(data.get("keep_back", 0.0)):
		e.position += dir * e.speed * slow * delta


## Vrai si la Souche peut soigner cet ennemi : ni boss, ni Souche (elle comprise).
static func mendable(o) -> bool:
	return not o.dead and "max_hp" in o and o.get("behavior") != "boss" and o.get("behavior") != "healer"


## Flétris blessés dans son cercle.
func wounded_near(e) -> int:
	var n := 0
	for o in e.main.enemies_near(e.position, float(e.data["aura"]), false):
		if mendable(o) and o.hp < o.max_hp * 0.95:
			n += 1
	return n


## Rend « heal » de leur vie aux Flétris du cercle.
func mend(e) -> void:
	var part := float(e.data.get("heal", 0.3))
	var n := 0
	for o in e.main.enemies_near(e.position, float(e.data["aura"]), false):
		if not mendable(o):
			continue
		o.hp = minf(o.max_hp, o.hp + o.max_hp * part)
		n += 1
	if e.main.get("fx") != null:
		e.main.fx.ring(e.position, e.radius, float(e.data["aura"]), 0.5, Color(Art.ec("seve", "clair"), 0.75), 4.0)
	e.set_meta("soignes", n)


func draw_attack(e, k: float, hit: float) -> void:
	var r := float(e.data["aura"])
	var col := Art.ec("seve", "clair")
	if e.state == "windup":
		# Un soin, pas un coup : un cercle vert qui se resserre, jamais le rouge des annonces.
		e.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(col, 0.2 + 0.4 * k), Art.TRAIT, true)
		e.draw_arc(Vector2.ZERO, r * (1.0 - 0.7 * k), 0.0, TAU, 40, Color(col, 0.6 * k), Art.TRAIT_FIN, true)
	elif hit >= 0.0:
		e.draw_arc(Vector2.ZERO, r * hit, 0.0, TAU, 48, Color(col, 0.7 * (1.0 - hit)), Art.TRAIT, true)
