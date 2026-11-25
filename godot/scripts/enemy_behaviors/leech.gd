## Sangsue de vase (vallée de Sève) : rampe vers le joueur, marque un court couloir au sol
## (« windup ») puis s'y jette (« charge_speed » sur « charge_dist ») et se remet (« recover »).
## Elle boit la vie : chaque coup qu'elle porte au joueur (contact ou bond, « charge_damage ») lui
## rend « drain » fois les dégâts en vie, et elle enfle (meta « bu », lue par son dessin). La tuer
## vite, ou ne pas la laisser toucher : sinon elle tient longtemps.
## Un obstacle du décor arrête son bond.
extends EnemyBehavior

## Durée pendant laquelle la sangsue reste gonflée après avoir bu (secondes).
const GORGED := 1.2


func step(e, delta: float, dir: Vector2, dist: float, slow: float) -> void:
	var data: Dictionary = e.data
	e.cd -= delta
	var p = e.main.player
	# Le contact de ce pas touchera le joueur (enemy.gd frappe juste après) : elle boit.
	if dist < e.radius + p.radius and p.invuln <= 0.0 and p.hp > 0.0:
		var hit: float = e.damage
		if e.state == "charge":
			hit = float(data.get("charge_damage", e.damage)) * e.damage_scale
		drink(e, hit)
	match e.state:
		"windup":
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = "charge"
				e.travelled = 0.0
		"charge":
			var step_len: float = float(data["charge_speed"]) * delta
			e.position += e.attack_dir * step_len
			e.travelled += step_len
			var pushed: Vector2 = e.main.flora.push_out(e.position, e.radius) if e.main.get("flora") else e.position
			if pushed.distance_squared_to(e.position) > 0.5 or e.travelled >= float(data["charge_dist"]):
				e.position = pushed
				e.state = "recover"
				e.state_t = float(data["recover"])
				e.cd = float(data["cooldown"]) * e.cd_mult
		"recover":
			e.state_t -= delta
			if e.state_t <= 0.0:
				e.state = ""
		_:
			if e.cd <= 0.0 and dist < float(data["range"]) and dist > e.radius * 2.0:
				e.state = "windup"
				e.state_t = data["windup"]
				e.attack_dir = dir
				return
			# Elle ondule en rampant (un léger écart de côté, au rythme de sa marche).
			var wiggle: Vector2 = dir.orthogonal() * sin(e.t * 7.0) * 0.35
			e.position += (dir + wiggle).normalized() * e.speed * slow * delta


## Boit la vie : rend « drain » fois les dégâts portés, sans dépasser la vie de départ.
func drink(e, hit: float) -> void:
	var gain := hit * float(e.data.get("drain", 1.0))
	e.hp = minf(e.max_hp, e.hp + gain)
	e.set_meta("bu", e.t)
	e.strike_t = 0.0
	if e.main.get("fx") != null and gain >= 1.0:
		e.main.fx.text(e.position + Vector2(0, -e.radius * 2.4), "+%d" % roundi(gain), Art.ec("seve", "clair"), 13, 0.6)


## Gonflée d'avoir bu (de 1 juste après, à 0).
static func gorged(e) -> float:
	if not e.has_meta("bu"):
		return 0.0
	return clampf(1.0 - (e.t - float(e.get_meta("bu"))) / GORGED, 0.0, 1.0)


func draw_attack(e, k: float, _hit: float) -> void:
	var ln := float(e.data["charge_dist"])
	if e.state == "windup":
		Art.telegraph(e.gc, {"type": "ligne", "de": Vector2.ZERO, "a": e.attack_dir * ln, "largeur": e.radius * 2.0}, k, -1.0, e.t)
	elif e.state == "charge":
		var from: Vector2 = -e.attack_dir * e.travelled
		Art.telegraph(e.gc, {"type": "ligne", "de": from, "a": from + e.attack_dir * ln, "largeur": e.radius * 2.0}, 1.0, e.travelled / ln, e.t)


## Gonflée d'avoir bu : son dessin enfle (« gorged », de 1 à 0).
func pose(e, o: Dictionary) -> void:
	var g := gorged(e)
	if g > 0.0:
		o["gorged"] = g
		o["live"] = true
