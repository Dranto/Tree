## Actions que les effets déclenchés peuvent lancer (champ « do » dans res://data/).
## Chaque action reçoit ses paramètres « p » (l'effet tel qu'écrit dans les données) et le
## contexte « ctx » de l'évènement : ctx["main"] (scène de jeu), ctx["stats"], et selon
## l'évènement ctx["enemy"] ou ctx["base"]. Elle renvoie true si elle prend l'évènement en charge.
## Pour ajouter une action : l'écrire ici et la déclarer dans Content.ACTIONS.
extends RefCounted


static func run(action: String, p: Dictionary, ctx: Dictionary) -> bool:
	match action:
		"reduce_cooldown":
			return _reduce_cooldown(p, ctx)
		"spread_poison":
			return _spread_poison(p, ctx)
		"explode":
			return _explode(p, ctx)
		"survive":
			return _survive(p, ctx)
		"apply_status":
			return _apply_status(p, ctx)
		"heal":
			return _heal(p, ctx)
		"burst":
			return _burst(p, ctx)
		"status_area":
			return _status_area(p, ctx)
		"attack_salvo":
			return _attack_salvo(p, ctx)
	push_warning("Action d'effet inconnue : " + action)
	return false


## Réduit la recharge de l'esquive (« dash ») ou d'une compétence.
static func _reduce_cooldown(p: Dictionary, ctx: Dictionary) -> bool:
	var player = ctx["main"].player
	if p["target"] == "dash":
		player.dash_cd = maxf(0.0, player.dash_cd - p["value"])
	elif player.cds.has(p["target"]):
		player.cds[p["target"]] = maxf(0.0, player.cds[p["target"]] - p["value"])
	return true


## L'ennemi vaincu transmet son poison aux ennemis proches.
static func _spread_poison(p: Dictionary, ctx: Dictionary) -> bool:
	var main = ctx["main"]
	var e = ctx["enemy"]
	var radius: float = p["radius"]
	main.fx.ring(e.position, 10.0, radius, 0.4, Color(p.get("color", "#ffffff")), 4.0)
	for other in main.enemies_near(e.position, radius, false):
		if other != e:
			other.apply_poison(e.poison_dps, p["duration"])
	return true


## Le coup touche aussi les ennemis proches, pour une fraction de ses dégâts.
static func _explode(p: Dictionary, ctx: Dictionary) -> bool:
	var main = ctx["main"]
	var e = ctx["enemy"]
	var radius: float = p["radius"] * ctx["stats"]["area"]
	main.fx.ring(e.position, 10.0, radius, 0.3, Color(p.get("color", "#ffffff")), 4.0)
	for other in main.enemies_near(e.position, radius, false):
		if other != e and not other.dead:
			main.player_hit_enemy(other, ctx["base"] * p["factor"], false)
	return true


## Le joueur survit à un coup mortel.
static func _survive(p: Dictionary, ctx: Dictionary) -> bool:
	var main = ctx["main"]
	var player = main.player
	player.hp = p["hp"]
	player.invuln = p.get("invuln", 0.0)
	if p.has("label"):
		main.fx.text(player.position + Vector2(0, -50), p["label"], Color(p.get("color", "#ffffff")), 22, 1.5)
	return true


## Pose un état sur l'ennemi de l'évènement : « saignement » (value = dégâts par seconde) ou
## « enracine ». Avec "scale": "base", value est une fraction des dégâts du coup (ctx["base"]).
## Les durées suivent bleed_duration / root_duration du joueur.
static func _apply_status(p: Dictionary, ctx: Dictionary) -> bool:
	var e = ctx.get("enemy")
	if e == null or not is_instance_valid(e) or e.dead:
		return false
	var value: float = p["value"]
	if p.get("scale", "") == "base":
		value *= float(ctx.get("base", 0.0))
	var duration: float = p["duration"]
	var s: Dictionary = ctx["stats"]
	if p["status"] == "saignement":
		duration *= s.get("bleed_duration", 1.0)
	elif p["status"] == "enracine":
		duration *= s.get("root_duration", 1.0)
	e.apply_status(p["status"], value, duration)
	return true


## Soigne le joueur d'une fraction de sa vie maximale.
static func _heal(p: Dictionary, ctx: Dictionary) -> bool:
	var main = ctx["main"]
	main.player.heal(ctx["stats"]["max_hp"] * p["value"])
	return true


## Centre d'une action de zone : le joueur (« at »: "player", par défaut) ou l'ennemi de l'évènement.
static func _center(p: Dictionary, ctx: Dictionary):
	if p.get("at", "player") == "enemy":
		var e = ctx.get("enemy")
		if e == null or not is_instance_valid(e):
			return null
		return e.position
	return ctx["main"].player.position


## Onde d'épines : blesse les ennemis autour du centre pour « factor » × les dégâts du joueur
## (× dégâts de zone, rayon × taille des zones). C'est un coup de Ronce.
static func _burst(p: Dictionary, ctx: Dictionary) -> bool:
	var at = _center(p, ctx)
	if at == null:
		return false
	var main = ctx["main"]
	var s: Dictionary = ctx["stats"]
	var radius: float = p["radius"] * s.get("area", 1.0)
	main.fx.ring(at, 12.0, radius, 0.3, Color(p.get("color", "#ffffff")), 4.0)
	var dmg: float = s.get("damage", 0.0) * p["factor"] * s.get("area_damage", 1.0)
	var source = ctx.get("enemy")
	for other in main.enemies_near(at, radius):
		if other != source and not other.dead:
			main.player_hit_enemy(other, dmg, false, "ronce")
	return true


## Pose un état (« enracine », « saignement ») sur les ennemis autour du centre. Avec "scale": "damage",
## value est une fraction des dégâts du joueur. Durées multipliées comme pour apply_status.
static func _status_area(p: Dictionary, ctx: Dictionary) -> bool:
	var at = _center(p, ctx)
	if at == null:
		return false
	var main = ctx["main"]
	var s: Dictionary = ctx["stats"]
	var radius: float = p["radius"] * s.get("area", 1.0)
	var value: float = p["value"]
	if p.get("scale", "") == "damage":
		value *= s.get("damage", 0.0)
	var duration: float = p["duration"]
	if p["status"] == "saignement":
		duration *= s.get("bleed_duration", 1.0)
	elif p["status"] == "enracine":
		duration *= s.get("root_duration", 1.0)
	main.fx.ring(at, radius * 0.2, radius, 0.45, Color(p.get("color", "#ffffff")), 5.0)
	for e in main.enemies_near(at, radius):
		if not e.dead:
			e.apply_status(p["status"], value, duration)
	return true


## Salve de l'attaque de base tout autour du joueur, avec sa forme et ses modificateurs actuels
## (attack.gd) : « count » directions.
static func _attack_salvo(p: Dictionary, ctx: Dictionary) -> bool:
	var main = ctx["main"]
	if main == null or not "player" in main or main.player == null or not "attack_rt" in main.player:
		return false
	load("res://scripts/attack.gd").salvo(main.player, int(p["count"]))
	return true
