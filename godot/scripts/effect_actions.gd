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
